// +build mage

// Run some verification tests on the newly-built Docker image.
package main

import (
	// mage:import
	dry "github.com/cloudreach/container-base-terratest/dry"
)

// Default is the default target when `mage` is executed without specifying one.
var Default = dry.Full
