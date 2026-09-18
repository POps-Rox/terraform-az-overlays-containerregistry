# Functional tests for the container registry overlay.
#
# These use mock_provider and module overrides, so they execute without Azure
# credentials and are safe to run on pull requests from forks.

mock_provider "azurerm" {
  mock_data "azurerm_virtual_network" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/anoa-eus-testacr-dev-rg/providers/Microsoft.Network/virtualNetworks/acr-vnet"
      name = "acr-vnet"
    }
  }

  mock_data "azurerm_subnet" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/anoa-eus-testacr-dev-rg/providers/Microsoft.Network/virtualNetworks/acr-vnet/subnets/acr-subnet"
      name = "acr-subnet"
    }
  }

  mock_data "azurerm_private_endpoint_connection" {
    defaults = {
      private_service_connection = [{
        private_ip_address = "10.0.100.4"
      }]
    }
  }
}
mock_provider "azapi" {}

mock_provider "popsrox" {
  mock_data "popsrox_resource_name" {
    defaults = {
      result = "anoaeustestacr"
    }
  }
}

override_module {
  target = module.mod_azure_region_lookup
  outputs = {
    location_cli   = "eastus"
    location_short = "eus"
  }
}

override_module {
  target = module.mod_container_registry_rg
  outputs = {
    resource_group_name     = "anoa-eus-testacr-dev-rg"
    resource_group_location = "eastus"
  }
}

override_resource {
  target = azurerm_container_registry.container_registry
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/anoa-eus-testacr-dev-rg/providers/Microsoft.ContainerRegistry/registries/anoaeustestacr"
  }
}

override_resource {
  target = azurerm_private_dns_zone.dns_zone
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/anoa-eus-testacr-dev-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
  }
}

variables {
  location                                 = "eastus"
  environment                              = "public"
  deploy_environment                       = "dev"
  org_name                                 = "anoa"
  workload_name                            = "testacr"
  create_container_registry_resource_group = true
  public_network_access_enabled            = true
  azure_services_bypass_allowed            = true
  sku                                      = "Standard"
}

run "generated_name_is_used_when_no_custom_name_given" {
  command = plan

  assert {
    condition     = azurerm_container_registry.container_registry.name == "anoaeustestacr"
    error_message = "Expected the generated popsrox_resource_name value when custom_name is unset, got: ${azurerm_container_registry.container_registry.name}"
  }
}

run "custom_name_overrides_generated_name" {
  command = plan

  variables {
    custom_name = "explicitacr"
  }

  assert {
    condition     = azurerm_container_registry.container_registry.name == "explicitacr"
    error_message = "custom_name must take precedence over the generated name, got: ${azurerm_container_registry.container_registry.name}"
  }
}

run "empty_custom_name_falls_through_to_generated_name" {
  command = plan

  variables {
    custom_name = ""
  }

  assert {
    condition     = azurerm_container_registry.container_registry.name == "anoaeustestacr"
    error_message = "An empty custom_name must fall through to the generated name, got: ${azurerm_container_registry.container_registry.name}"
  }
}

run "container_registry_uses_created_resource_group_outputs" {
  command = plan

  assert {
    condition     = azurerm_container_registry.container_registry.resource_group_name == "anoa-eus-testacr-dev-rg"
    error_message = "When create_container_registry_resource_group is true, the registry must use the resource group module output."
  }

  assert {
    condition     = azurerm_container_registry.container_registry.location == "eastus"
    error_message = "location must pass through the region lookup/resource group output to the registry."
  }
}

run "locks_are_not_created_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_management_lock.storage_account_level_lock) == 0
    error_message = "enable_resource_locks defaults to false, so no management lock should be planned."
  }
}

run "enabling_locks_creates_exactly_one_lock" {
  command = plan

  variables {
    enable_resource_locks = true
  }

  assert {
    condition     = length(azurerm_management_lock.storage_account_level_lock) == 1
    error_message = "enable_resource_locks = true must create exactly one management lock."
  }

  assert {
    condition     = azurerm_management_lock.storage_account_level_lock[0].name == "anoaeustestacr-CanNotDelete-lock"
    error_message = "Lock name must be derived from the container registry name and lock level."
  }

  assert {
    condition     = azurerm_management_lock.storage_account_level_lock[0].lock_level == "CanNotDelete"
    error_message = "lock_level should default to CanNotDelete."
  }
}

run "private_endpoint_resources_are_not_created_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.pep) == 0
    error_message = "enable_private_endpoint defaults to false, so no private endpoint should be planned."
  }

  assert {
    condition     = length(azurerm_private_dns_zone.dns_zone) == 0
    error_message = "enable_private_endpoint defaults to false, so no private DNS zone should be planned."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.vnet_link) == 0
    error_message = "enable_private_endpoint defaults to false, so no virtual network link should be planned."
  }
}

run "enabling_private_endpoint_creates_private_resources" {
  command = apply

  variables {
    enable_private_endpoint      = true
    virtual_network_name         = "acr-vnet"
    existing_private_subnet_name = "acr-subnet"
  }

  assert {
    condition     = length(azurerm_private_endpoint.pep) == 1
    error_message = "enable_private_endpoint = true with VNet/subnet names must create one private endpoint."
  }

  assert {
    condition     = length(azurerm_private_dns_zone.dns_zone) == 1
    error_message = "A managed private DNS zone should be created when no existing_private_dns_zone is provided."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.vnet_link) == 1
    error_message = "A managed private DNS zone should be linked to the VNet when private endpoint is enabled."
  }

  assert {
    condition     = azurerm_private_dns_zone_virtual_network_link.vnet_link[0].private_dns_zone_id == azurerm_private_dns_zone.dns_zone[0].id
    error_message = "The VNet link must use the private DNS zone id required by azurerm 5.x."
  }
}

run "caller_supplied_tags_are_merged_in" {
  command = plan

  variables {
    add_tags = {
      costCenter = "cc-1234"
    }
  }

  assert {
    condition     = azurerm_container_registry.container_registry.tags["costCenter"] == "cc-1234"
    error_message = "Tags passed via add_tags must appear on the container registry."
  }

  assert {
    condition     = azurerm_container_registry.container_registry.tags["environment"] == "public"
    error_message = "Default environment tags must be merged onto the container registry when default_tags_enabled is true."
  }
}

run "location_is_passed_through" {
  command = plan

  assert {
    condition     = azurerm_container_registry.container_registry.location == "eastus"
    error_message = "location input must be applied to the container registry through the resource group output."
  }
}
