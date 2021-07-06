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

variable "pachyderm_syncer_mode" {
  description = "Whether you want the syncer to create File datasets (`files`, matches all files, for unstructured data) or Tabular datasets with json lines format (`jsonl`, matches `**/*.jsonl` and aggregates into a single table - in which case all json lines files in a given Pachyderm repo must have compatible schemas)"
  type = string
  default = "files"
}