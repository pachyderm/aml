// Syncer VM image

variable "subscription_id" {
  type = string
}

variable "sig_resource_group" {
  type    = string
  default = "packer"
}

variable "sig_name" {
  type    = string
  default = "gallery"
}

variable "sig_image_name" {
  type    = string
  default = "aml_pachyderm"
}

variable "sig_image_version" {
  type    = string
  default = "0.0.1"
}

variable "sig_replication_regions" {
  type    = list(string)
  default = ["Canada Central", "East US", "UK South", "West Europe"]
}

source "azure-arm" "ubuntu" {
  subscription_id = "${var.subscription_id}"

  shared_image_gallery_destination {
    subscription         = "${var.subscription_id}"
    resource_group       = "${var.sig_resource_group}"
    gallery_name         = "${var.sig_name}"
    image_name           = "${var.sig_image_name}"
    image_version        = "${var.sig_image_version}"
    replication_regions  = "${var.sig_replication_regions}"
    storage_account_type = "Standard_LRS"
  }
  managed_image_name                = "syncer-image"
  managed_image_resource_group_name = "${var.sig_resource_group}" // TODO should this be the same RG as SIG?

  location        = "UK South"
  vm_size         = "Standard_D2s_v3"
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts-gen2"

  azure_tags = {
    dept = "Engineering"
    task = "Image deployment"
  }
}

build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "file" {
    sources     = ["deploy_pachyderm.sh", "start.sh", "../syncer/sync.py"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    execute_command =  "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "setup.sh"
  }

  // Deprovision Azure VM and removes Packer user
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
