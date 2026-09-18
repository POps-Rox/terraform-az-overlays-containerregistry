# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################
# Global Configuration   ##
###########################

variable "environment" {
  description = "The Terraform backend environment e.g. public or usgovernment"
  type        = string
  default     = null
}

variable "location" {
  description = "The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  type        = string
}

variable "org_name" {
  description = "A name for the organization. It defaults to anoa."
  type        = string
  default     = "anoa"
}

variable "workload_name" {
  description = "A name for the workload. It defaults to acr."
  type        = string
  default     = "acr"
}

variable "deploy_environment" {
  description = "The environment to deploy. It defaults to dev."
  type        = string
  default     = "dev"
}

#######################
# RG Configuration   ##
#######################

variable "create_container_registry_resource_group" {
  description = "Controls if the resource group should be created. If set to false, the resource group name must be provided. Default is false."
  type        = bool
  default     = false
}

variable "custom_resource_group_name" {
  description = "The name of the custom resource group to create. If not set, the name will be generated using the `org_name`, `workload_name`, `deploy_environment` and `environment` variables."
  type        = string
  default     = null
}

variable "use_location_short_name" {
  description = "Use short location name for resources naming (ie eastus -> eus). Default is true. If set to false, the full cli location name will be used. if custom naming is set, this variable will be ignored."
  type        = bool
  default     = true
}

variable "existing_resource_group_name" {
  description = "The name of the existing resource group to use. If not set, the name will be generated using the `org_name`, `workload_name`, `deploy_environment` and `environment` variables."
  type        = string
  default     = null
}

#####################################
# Private Endpoint Configuration   ##
#####################################

variable "enable_private_endpoint" {
  description = "Manages a Private Endpoint to Azure Container Registry. Default is false."
  default     = false
}

variable "existing_private_dns_zone" {
  description = "Name of the existing private DNS zone"
  default     = null
}

variable "existing_private_subnet_name" {
  description = "Name of the existing private subnet for the private endpoint"
  default     = null
}

variable "virtual_network_name" {
  description = "Name of the virtual network for the private endpoint"
  default     = null
}

variable "existing_subnet_id" {
  description = "The resource id of existing subnet"
  default     = null
}

#######################################
# Container Registry Configuration   ##
#######################################

variable "sku" {
  description = "The SKU name of the the container registry. Possible values are `Classic` (which was previously `Basic`), `Basic`, `Standard` and `Premium`."
  type        = string
  default     = "Standard"
}

variable "admin_enabled" {
  description = "Whether the admin user is enabled. Disable this in production, default is false."
  type        = bool
  default     = false
}

variable "georeplication_locations" {
  description = <<DESC
  A list of Azure locations where the Ccontainer Registry should be geo-replicated. Only activated on Premium SKU.
  Supported properties are:
    location                  = string
    zone_redundancy_enabled   = bool
    regional_endpoint_enabled = bool
    tags                      = map(string)
  or this can be a list of `string` (each element is a location)
DESC
  type        = any
  default     = []
}

variable "georeplications" {
  description = <<DESC
  A list of Azure locations where the Ccontainer Registry should be geo-replicated. Only activated on Premium SKU.
  Supported properties are:
    location                        = string
    zone_redundancy_enabled         = bool
    global_endpoint_routing_enabled = bool
    regional_endpoint_enabled       = bool (deprecated; accepted for backwards compatibility)
DESC
  type = list(object({
    location                        = string
    zone_redundancy_enabled         = bool
    global_endpoint_routing_enabled = optional(bool)
    regional_endpoint_enabled       = optional(bool)
  }))
  default = []

  validation {
    condition     = alltrue([for replication in var.georeplications : replication.global_endpoint_routing_enabled != null || replication.regional_endpoint_enabled != null])
    error_message = "Each georeplications entry must set global_endpoint_routing_enabled. regional_endpoint_enabled remains accepted for backwards compatibility."
  }
}

variable "images_retention_enabled" {
  description = "Specifies whether images retention is enabled (Premium only)."
  type        = bool
  default     = false
}

variable "images_retention_days" {
  description = "Specifies the number of images retention days."
  type        = number
  default     = 90
}

variable "azure_services_bypass_allowed" {
  description = "Whether to allow trusted Azure services to access a network restricted Container Registry."
  type        = bool
  default     = false
}

variable "trust_policy_enabled" {
  description = "Specifies whether the trust policy is enabled (Premium only)."
  type        = bool
  default     = false
}

variable "network_rule_set" { # change this to match actual objects
  description = "Manage network rules for Azure Container Registries"
  type = object({
    default_action = optional(string)
    ip_rule = optional(list(object({
      ip_range = string
    })))
    virtual_network = optional(list(object({
      subnet_id = string
    })))
  })
  default = null
}

variable "retention_policy" {
  description = "Set a retention policy for untagged manifests"
  type = object({
    days    = optional(number)
    enabled = optional(bool)
  })
  default = null
}

variable "enable_content_trust" {
  description = "Boolean value to enable or disable Content trust in Azure Container Registry"
  default     = false
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned. This is required when `type` is set to `UserAssigned` or `SystemAssigned, UserAssigned`"
  default     = null
}

variable "encryption" {
  description = "Encrypt registry using a customer-managed key"
  type = object({
    key_vault_key_id   = string
    identity_client_id = string
  })
  default = null
}

variable "scope_map" {
  description = "Manages an Azure Container Registry scope map. Scope Maps are a preview feature only available in Premium SKU Container registries."
  type = map(object({
    actions = list(string)
  }))
  default = null
}

variable "container_registry_webhooks" {
  description = "Manages an Azure Container Registry Webhook"
  type = map(object({
    service_uri    = string
    actions        = list(string)
    status         = optional(string)
    scope          = string
    custom_headers = map(string)
  }))
  default = null
}


variable "public_network_access_enabled" {
  description = "Whether the Container Registry is accessible publicly."
  type        = bool
  default     = false
}

variable "data_endpoint_enabled" {
  description = "Whether to enable dedicated data endpoints for this Container Registry? (Only supported on resources with the Premium SKU)."
  default     = false
  type        = bool
}
