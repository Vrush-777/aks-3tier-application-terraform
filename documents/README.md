# Terraform Infrastructure for AKS 3-Tier Application

This folder contains modular Terraform code for Azure infrastructure supporting a private AKS cluster with Application Gateway, ACR, PostgreSQL Flexible Server, managed identities, and private networking.

## Structure

- `modules/resource-group` - Resource group creation
- `modules/network` - Virtual network, AKS subnet, Application Gateway subnet, PostgreSQL delegated subnet, NSGs
- `modules/managed-identity` - User-assigned identities and role assignments
- `modules/acr` - Azure Container Registry with optional private endpoint
- `modules/postgres` - Azure PostgreSQL Flexible Server on a delegated subnet with private networking
- `modules/application-gateway` - Public Application Gateway configured for AGIC integration
- `modules/aks` - Private AKS cluster with Azure CNI, managed identity, and AGIC integration
- `environments/dev` - Development environment configuration and outputs

## Quick Start

1. Copy the example file:

   ```powershell
   cd terraform\environments\dev
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

2. Update `terraform.tfvars` with your Azure subscription, tenant, resource names, and passwords.

3. Initialize Terraform:

   ```powershell
   terraform init
   ```

4. Validate and plan:

   ```powershell
   terraform validate
   terraform plan -var-file=terraform.tfvars
   ```

5. Apply the deployment:

   ```powershell
   terraform apply -var-file=terraform.tfvars
   ```

## Outputs

The dev environment exports:

- `resource_group_id`, `resource_group_name`, `resource_group_location`
- `vnet_id`, `aks_subnet_id`, `appgw_subnet_id`, `postgres_subnet_id`
- `acr_id`, `acr_name`, `acr_login_server`
- `postgres_id`, `postgres_fqdn`, `postgres_connection_string`
- `appgw_id`, `appgw_name`, `appgw_public_ip`, `appgw_private_ip`
- `aks_id`, `aks_name`, `aks_fqdn`, `aks_private_fqdn`, `node_resource_group`
- `kube_config_raw`, `kube_config`
- Managed identity IDs for AKS, Application Gateway, and kubelet

## Notes

- The AKS cluster is configured for Azure CNI and a private endpoint.
- PostgreSQL Flexible Server is deployed to a dedicated delegated subnet with public network access disabled.
- Application Gateway is configured with a public frontend and optional private frontend for AGIC integration.
- ACR pull access is granted to the kubelet managed identity.
