
# Carbon Footprint & Savings Advisor

## Infrastructure Overview

The infrastructure is managed using Terraform and hosted on Microsoft Azure.

The project uses:
- Azure Resource Group to organise resources
- Azure Linux App Service to host the application
- Azure SQL Database to store application data
- Azure Key Vault to securely store database credentials
- Managed Identity for secure access to Key Vault
- GitHub Actions for CI/CD

## Architecture

Frontend and Python Backend → Azure App Service → Azure SQL Database

Azure App Service uses Managed Identity to access secrets stored in Azure Key Vault.

## Infrastructure Deployment

The Azure infrastructure has been successfully deployed using Terraform.

To manage infrastructure:

1. Authenticate to Azure.
2. Navigate to the `infra` directory.
3. Run `terraform init`.
4. Run `terraform plan`.
5. Run `terraform apply`.

Database credentials must be supplied securely and must never be committed to GitHub.

## CI/CD Pipeline

GitHub Actions is configured to:

- Check Terraform formatting
- Validate Terraform configuration
- Authenticate to Azure using federated credentials
- Deploy application code to Azure App Service from the `dev` branch

Terraform validation runs on `feature/infrastructure` and `dev`.

## Current Status

Completed:
- Azure infrastructure deployed
- SQL Database and Key Vault configured
- Managed Identity and permissions configured
- GitHub Actions Terraform validation tested successfully

Pending:
- Merge infrastructure changes into `dev`
- Complete backend integration
- Test automated application deployment
- Verify database connectivity
