variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "West Europe"
}

variable "existing_resource_group_name" {
  description = "Use an existing named resource group (if not set, will create a new resource group)"
  type = string
  default = ""
}

variable "existing_workspace_name" {
  description = "Use an existing AzureML workspace name (if not set, will create a new AzureML workspace)"
  type = string
  default = ""
}
