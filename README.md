# hackday_02_2019_jupyter


## Install the Azure CL

https://docs.microsoft.com/en-us/cli/azure/install-azure-cli


## Login 

```
az login
```

## Bring up a VM

```
az vm create --name cli-dsvm-6 \
--resource-group AzureNotebook-CeR-DEV-RG \
--image microsoft-dsvm:linux-data-science-vm-ubuntu:linuxdsvmubuntu:latest \
--admin-username dsvmadmin --admin-password <you password here> \
--size Standard_D2s_v3 \
--nsg Ubuntu-DSVM-nsg \
--ssh-key-value ~/.ssh/id_rsa.pub \
--custom-data ./simple_bash.sh
```

* `--nsg`: network security group
* `--custom-data`: a local script to be executed after the VM start
* `--ssh-key-value`: ssh key pairs used to login
