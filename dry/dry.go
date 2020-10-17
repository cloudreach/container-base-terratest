package dry

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
)

// Full runs Clean, Format, Unit and Integration in sequence.
func Full() {
	mg.Deps(Unit)
	mg.Deps(Integration)
}

// LoginSandbox tries using the Azure CLI to log in to the sandbox.
func LoginSandbox() error {
	// Poll the Azure CLI for any pre-existing account information.
	showCmd := "az account show 2>&1"
	show, errShow := sh.Output("sh", "-c", showCmd)

	// Check to see if we are already logged in, interactively or otherwise.
	if errShow == nil && strings.Contains(show, `"state": "Enabled"`) {
		fmt.Println("The Azure CLI shows that we are already logged in.")
		return nil
	}

	// Is the error simply that we are not logged in, or something else?
	if errShow != nil && show != "ERROR: Please run 'az login' to setup account." {
		return fmt.Errorf("'%s' returned an error:\n%v\n%v", showCmd, show, errShow)
	}

	return fmt.Errorf("unable to log in to the sandbox")
}

// SelectSandbox finds the GUID of the correct Azure lab subscription to provision test resources in, and sets it as
// the default subscription to use in the Azure CLI's current context.
func SelectSandbox() error {
	_, clientOk := os.LookupEnv("ARM_CLIENT_ID")
	_, secretOk := os.LookupEnv("ARM_CLIENT_SECRET")
	_, subIDOk := os.LookupEnv("ARM_SUBSCRIPTION_ID")
	_, tenantOk := os.LookupEnv("ARM_TENANT_ID")

	// Our build process should have set these variables in our environment.
	if clientOk && secretOk && subIDOk && tenantOk {
		fmt.Println("We can access the sandbox using the provided environment variables.")
		return nil
	}

	mg.Deps(LoginSandbox)

	fmt.Println("Looking up sandbox subscription...")

	rawLabID, errAz := sh.Output("sh", "-c",
		`az account list 2>/dev/null | jq -r '.[] | select( .name | contains("NAME") ) | .id'`) //TODO
	if errAz != nil {
		return errAz
	}

	sandboxID := uuid.MustParse(strings.TrimSpace(rawLabID)).String()

	fmt.Println("Selecting sandbox subscription...")
	return sh.Run("az", "account", "set", fmt.Sprintf("--subscription=%s", sandboxID))
}

const testDir = "./test/"

// Unit runs unit tests. Can target a specific test(s) with 'go test's -run arg by passing in the 'MAGE_TARGET_UT' env
// var, for example:
// $ MAGE_TARGET_UT="^TestUT_Foo$" mage -v
func Unit() error {
	if testExists, errTest := testSubDirectoryExists(); errTest != nil {
		return errTest
	} else if !testExists {
		return nil
	}
	mg.Deps(Clean)
	mg.Deps(Format)
	mg.Deps(SelectSandbox)

	args := []string{"test", "-failfast", testDir, "-run"}
	if target, exists := os.LookupEnv("MAGE_TARGET_UT"); exists {
		args = append(args, target)
	} else {
		args = append(args, "^TestUT_")
	}

	if mg.Verbose() {
		args = append(args, "-v")
	}

	fmt.Printf("Running unit tests... (args: %v)\n", args)
	return sh.RunV("go", args...)
}

// Integration runs integration tests, with the timeout increased from the 10 minute default to 60 minutes. Can target
// a specific test(s) with 'go test's -run arg by passing in the 'MAGE_TARGET_IT' env var, for example:
// $ MAGE_TARGET_IT="^TestIT_Bar$" mage -v
func Integration() error {
	if testExists, errTest := testSubDirectoryExists(); errTest != nil {
		return errTest
	} else if !testExists {
		return nil
	}
	mg.Deps(Clean)
	mg.Deps(Format)
	mg.Deps(SelectSandbox)

	args := []string{"test", "-failfast", "-timeout", "60m", testDir, "-run"}
	if target, exists := os.LookupEnv("MAGE_TARGET_IT"); exists {
		args = append(args, target)
	} else {
		args = append(args, "^TestIT_")
	}

	if mg.Verbose() {
		args = append(args, "-v")
	}

	fmt.Printf("Running integration tests... (args: %v)\n", args)
	return sh.RunV("go", args...)
}

// Format formats both Terraform code and Go code.
func Format() error {
	fmt.Println("Formatting...")
	if err := sh.Run("terraform", "fmt", "."); err != nil {
		return err
	}
	if testExists, errTest := testSubDirectoryExists(); errTest != nil {
		return errTest
	} else if !testExists {
		return nil
	}
	return sh.Run("go", "fmt", testDir)
}

func testSubDirectoryExists() (bool, error) {
	_, err := os.Stat(testDir)
	if os.IsNotExist(err) {
		fmt.Printf("Test directory '%s' does not exist.\n", testDir)
		return false, nil
	}
	if err != nil {
		return false, mg.Fatalf(1, "error checking for '%s' sub-directory: %s", testDir, err)
	}
	return true, nil
}

// Clean removes temporary build and test files.
func Clean() error {
	fmt.Println("Cleaning...")
	return filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == "vendor" {
			return filepath.SkipDir
		}
		if info.IsDir() && info.Name() == ".terraform" {
			os.RemoveAll(path)
			fmt.Printf("Removed '%v'\n", path)
			return filepath.SkipDir
		}
		if !info.IsDir() && (info.Name() == "terraform.tfstate" ||
			info.Name() == "terraform.tfplan" ||
			info.Name() == "terraform.tfstate.backup") {

			os.Remove(path)
			fmt.Printf("Removed '%v'\n", path)
		}
		if !info.IsDir() &&
			strings.HasPrefix(info.Name(), "coverage.") &&
			strings.HasSuffix(info.Name(), ".out") {

			os.Remove(path)
			fmt.Printf("Removed '%v'\n", path)
		}
		return nil
	})
}

// Cover will (re)run the Go tests, analyse coverage, and open the generated report.
func Cover() error {
	if testExists, errTest := testSubDirectoryExists(); errTest != nil {
		return errTest
	} else if !testExists {
		return nil
	}
	mg.Deps(Clean)
	mg.Deps(Format)
	mg.Deps(SelectSandbox)

	fmt.Println("Running tests and generating coverage report...")
	now := time.Now().Format(time.RFC3339)
	coverFile := fmt.Sprintf("coverage.%s.out", now)
	runArgs := []string{"test", testDir, fmt.Sprintf("-coverprofile=%s", coverFile)}

	if errTest := sh.Run("go", runArgs...); errTest != nil {
		return fmt.Errorf("error running 'go %s': %s",
			strings.Join(runArgs, " "),
			errTest)
	}

	return sh.Run("go", "tool", "cover", fmt.Sprintf("-html=%s", coverFile))
}
