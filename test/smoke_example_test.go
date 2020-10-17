package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/matryer/is"
)

func TestIT_Smoke(t *testing.T) {
	// Generate a random name to prevent a naming conflict
	uniqueID := random.UniqueId()

	// Specify the test case folder and "-var" options
	tfOptions := &terraform.Options{
		TerraformDir: "../examples/smoke",
		Vars: map[string]interface{}{
			"name": uniqueID,
		},
	}

	// Terraform init, apply, output, and destroy
	defer terraform.Destroy(t, tfOptions)
	terraform.InitAndApply(t, tfOptions)

	tfOutputs := terraform.OutputAll(t, tfOptions)
	t.Logf("Terraform outputs:\n%+v", tfOutputs)

	is := is.New(t)
	actual := tfOutputs["name"]
	expected := fmt.Sprintf("Verify-Docker-%s-RG", uniqueID)
	is.Equal(actual, expected) // RG name should match 'Verify-Docker-*-RG
}
