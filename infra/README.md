# Infrastructure

# Carbon Footprint & Savings Advisor

## Infrastructure Overview

The infrastructure is managed using Terraform and hosted on Microsoft Azure.

The application uses:

- Azure Resource Group to organise resources
- Azure Linux App Service to host the frontend and Python backend
- Azure SQL Database to store application data
- GitHub Actions for CI/CD

## Architecture

Frontend and Python backend -> Azure App Service -> Azure SQL Database

Both frontend and backend will be hosted together on one App Service.

## Deployment

1. Authenticate to the correct Azure subscription.
2. Navigate to the `infra` directory.
3. Run `terraform init`.
4. Run `terraform plan`.
5. Run `terraform apply`.
6. Configure secure database access.
7. Deploy the application using GitHub Actions.

The SQL administrator password must be provided securely and must not be committed to GitHub.

## CI/CD

GitHub Actions is configured to:

- Validate Terraform configuration
- Check Terraform formatting
- Deploy application code to Azure App Service

Deployment is triggered manually from the `main` branch.

## Current Status

Infrastructure configuration has been created and validated locally.

Azure resources have not yet been deployed. Deployment depends on Azure subscription access and the application code being ready.
