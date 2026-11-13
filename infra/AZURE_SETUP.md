# Azure Infrastructure Setup

## Overview

The Carbon Advisor infrastructure is managed using Terraform and hosted on Microsoft Azure.

## Azure Resources

The following resources have been deployed:

- Resource Group: `rg-carbon-advisor-dev`
- Linux App Service: `app-carbon-advisor-dev-1005371`
- App Service Plan: `asp-carbon-advisor-dev`
- Azure SQL Database: `carbon-advisor-db`
- Azure Key Vault: `kv-carbon-dev-1005371`

The App Service hosts the application and connects to Azure SQL Database.

## Security and Database Configuration

- Managed Identity is enabled for the App Service.
- Database credentials are stored in Azure Key Vault.
- App Service has permission to retrieve secrets from Key Vault.
- Database connection settings are configured in App Service.
- SQL firewall access is configured for development.

The SQL firewall configuration must be reviewed and restricted before production use.

## Terraform

The infrastructure is defined in:

- `main.tf`: Resource Group, App Service and hosting configuration
- `database.tf`: SQL Server, database and firewall configuration
- `keyvault.tf`: Key Vault and access permissions

To deploy infrastructure:

1. Authenticate to Azure.
2. Navigate to the `infra` directory.
3. Run `terraform init`.
4. Run `terraform plan`.
5. Run `terraform apply`.

Never commit database passwords, Terraform state files or credentials to GitHub.

## CI/CD Pipeline

GitHub Actions is configured to:

- Check Terraform formatting
- Validate Terraform configuration
- Authenticate to Azure using federated credentials
- Deploy application code to Azure App Service from the `dev` branch

Terraform validation runs on `feature/infrastructure` and `dev`.

## Current Status

Completed:
- Azure infrastructure deployed successfully
- SQL Database and Key Vault configured
- Managed Identity and permissions configured
- GitHub Actions validation tested successfully
- Deployment workflow configured

Pending:
- Complete backend integration
- Test automated application deployment
- Verify database connectivity
