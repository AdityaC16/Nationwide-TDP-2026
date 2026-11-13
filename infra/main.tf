terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-carbon-advisor-dev"
  location = "uksouth"
}

resource "azurerm_service_plan" "main" {
  name                = "asp-carbon-advisor-dev"
  location            = "ukwest"
  resource_group_name = azurerm_resource_group.main.name

  os_type  = "Linux"
  sku_name = "F1"
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-carbon-advisor-dev-1005371"
  location            = "ukwest"
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  https_only = true

  site_config {
    always_on = false

    application_stack {
      python_version = "3.11"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    DB_SERVER                      = azurerm_mssql_server.main.fully_qualified_domain_name
    DB_NAME                        = azurerm_mssql_database.main.name
    DB_USER                        = "carbonadmin"

    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.main.vault_uri}secrets/sql-admin-password/)"

    CLOUD_STORAGE_ENABLED      = "true"
    AZURE_KEY_VAULT_URL        = azurerm_key_vault.main.vault_uri
    AZURE_DATABASE_SECRET_NAME = "database-url"
  }
}
