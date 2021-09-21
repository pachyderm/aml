variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "East US"
}

variable "existing_resource_group_name" {
  description = "Use an existing named resource group (if not set, will create a new resource group)"
  type        = string
  default     = ""
}

variable "existing_workspace_name" {
  description = "Use an existing AzureML workspace name (if not set, will create a new AzureML workspace)"
  type        = string
  default     = ""
}

variable "pachyderm_syncer_mode" {
  description = "Whether you want the syncer to create File datasets (`files`, matches all files, for unstructured data) or Tabular datasets with json lines format (`jsonl`, matches `**/*.jsonl` and aggregates into a single table - in which case all json lines files in a given Pachyderm repo must have compatible schemas)"
  type        = string
  default     = "files"
}

variable "skip_pachyderm_deploy" {
  description = "If you have an existing Pachyderm cluster, then set this to any value to skip deploying Pachyderm"
  type        = string
  default     = ""

}

variable "syncer_image_resource_group" {
  description = "Name of the resource group in which the Packer image will be created"
  type        = string
  default     = "resources-aml"
}

variable "syncer_image_name" {
  description = "Name of the Packer image"
  type        = string
  default     = "syncer-image"
}
