
# Azure Resource Provisioning with Terraform

This guide outlines the steps for setting up Azure resources using Terraform. You'll create an Azure Service Principal, authenticate with the Azure CLI, and configure your environment to use the Service Principal for managing resources via Terraform.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed on your machine.
- [Terraform](https://www.terraform.io/downloads.html) installed on your machine.
- Access to an Azure subscription.

## Steps

### 1. Log in to Azure

Log in to your Azure account using the Azure CLI:

```bash
az login
```

This will open a browser window to authenticate your credentials. After successful login, your terminal will be ready to interact with Azure.

### 2. Create a Service Principal

Next, create a Service Principal (SP) with the role of `Contributor`. This allows Terraform to manage your Azure resources. Replace `<subscription-id>` with your actual Azure subscription ID.

```bash
az ad sp create-for-rbac --name terraform-sp --role Contributor --scopes /subscriptions/<subscription-id>
```

After executing this command, you will receive output similar to the following:

```json
{
  "appId": "",
  "displayName": "",
  "password": "",
  "tenant": ""
}
```

### 3. Set Environment Variables

Terraform uses environment variables for authentication. Use the output from the previous step to export the necessary environment variables. Replace the values with your specific `appId`, `password`, and `tenant`.

```bash
export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # appId
export ARM_CLIENT_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # password
export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # your subscription ID
export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # tenant id
```

You can add these environment variables to your `.bashrc`, `.zshrc`, or equivalent profile file for persistent use:

```bash
echo 'export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"' >> ~/.bashrc
echo 'export ARM_CLIENT_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"' >> ~/.bashrc
echo 'export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"' >> ~/.bashrc
echo 'export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Verify Terraform Authentication

To verify that Terraform can authenticate using the Service Principal, run the following Terraform command:

```bash
terraform init
```

Then, apply your configuration to create resources:

```bash
terraform apply
```

If everything is configured correctly, Terraform will use your Service Principal to authenticate with Azure and provision the resources as defined in your Terraform scripts.
