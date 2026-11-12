
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
}

resource "azurerm_resource_group" "main" {
  name     = "rg-carbon-advisor-dev"
  location = "uksouth"
}

resource "azurerm_service_plan" "main" {
  name                = "asp-carbon-advisor-dev"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  os_type  = "Linux"
  sku_name = "B1"
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-carbon-advisor-dev-1005325"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  https_only = true

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DB_SERVER = azurerm_mssql_server.main.fully_qualified_domain_name
    DB_NAME   = azurerm_mssql_database.main.name
  }
}
