# Build Syncer VM image with Packer

Requirement

* [Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli) 1.5+

To build the image, just run:

```
export PKR_VAR_subscription_id='my-subscription-id'

packer build syncer.pkr.hcl
```
