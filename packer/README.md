# Syncer VM and Azure Marketplace

We use HashiCorp Packer to build a hardened Azure VM image, then publish to [Azure Marketplace]() via [Microsoft Partner Center]().

At a high level, the way this works is

1. Use Packer to build an Azure VM image
1. Go to [our Microsoft Partner Center page](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/bb37438-c75e-4024-8a25-ba35a3f51663/overview), and create a new VM offering based on the new image published
1. Wait for Microsoft to approve the offer (<3 business days)
1. Once approved, you should eventually see an Azure Marketplace preview like [this](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/pachyderminc1585170006545.pachyderm_aml_enablement-preview?tab=Overview&flightCodes=47bdffae-aa2f-4fd6-8f28-f7d784850ee1)
1. Now you can update [syncer.tf](https://github.com/pachyderm/aml/blob/main/terraform/syncer.tf#L81) with the new version

When we are ready to offer this VM to our customers, we can click *Publish* on the Partner Center. Then drop the `-preview` in [syncer.tf](https://github.com/pachyderm/aml/blob/main/terraform/syncer.tf#L79).
## How to build the image

Requirements

* [Install Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli) 1.5+

To build a new version:

1. Update [version](https://github.com/pachyderm/aml/blob/main/packer/syncer.pkr.hcl#L24)
1. Run
   ```
   PKR_VAR_subscription_id='my-subscription-id' packer build -force syncer.pkr.hcl
   ```
   > Note: if you are running packer for the first time, you need to authenticate packer with Azure

   > the -force flag is to override the existitng syncer-image in Azure

##  How to use the image

We want to use the VM image we just built directly, without waiting for Microsoft to approve and publish the preview VM on the marketplace.
To do that, you need to remove references to the marketplace VM image, and instead use `source_image_id `, then point it to the resource you just created.

It will look something like:

```hcl
data "azurerm_shared_image_version" "syncer_image" {
  name                = "0.0.1"  // Change this to the new version
  image_name          = "aml_pachyderm"
  gallery_name        = "gallery"
  resource_group_name = "packer"
}

resource "azurerm_linux_virtual_machine" "syncer" {
    ...
    
    source_image_id = data.azurerm_shared_image_version.syncer_image.id

    ...
}
```

> Check out https://github.com/pachyderm/aml/blob/terraform-custom-syncer/terraform/syncer.tf#L84 for a full example

Reference:
- [Azure compute gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [How to use Packer with Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer)

