resource "azurerm_resource_group" "test" {
  name = "Verify-Docker-${var.name}-RG"

  location = "westeurope"

  tags = "${module.tags.tags}"
}
