# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.25.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "0.4.0"
    }
  }
}

provider "azapi" {

}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

locals {
  apps = [
    {
      app_name = "api-gateway",
      needs_identity = false
      is_public = true
      needs_custom_domain = true
    },
    {
      app_name = "admin-service",
      needs_identity = false
      is_public = true
      needs_custom_domain = false
    },
    {
      app_name = "customers-service",
      needs_identity = true
      is_public = false
      needs_custom_domain = false
    },
    {
      app_name = "visits-service",
      needs_identity = true
      is_public = false
      needs_custom_domain = false
    },
    {
      app_name = "vets-service",
      needs_identity = true
      is_public = false
      needs_custom_domain = false
    }
  ]
  microservices_env = {
    "SPRING_PROFILES_ACTIVE"     = "mysql"
  }
}

module "region" {
  source = "./modules/region"
  for_each = {for i, r in var.regions:  i => r}
  application_name = var.application_name
  location = each.value.location
  location-short = each.value.location-short

  dns_name = var.dns_name
  cert_name = var.cert_name
  use_self_signed_cert = var.use_self_signed_cert
  cert_path = var.cert_path
  cert_password = var.cert_password

  git_repo_uri = each.value.git_repo_uri
  git_repo_branch = each.value.git_repo_branch
  git_repo_username = each.value.git_repo_username
  git_repo_password = var.git_repo_passwords[index(var.regions, each.value)]
  apps = local.apps
  microservices_env = local.microservices_env
  afd_fdid = module.afd.afd_fdid
}

resource "azurerm_resource_group" "rg" {
  name = "${var.application_name}-shared"
  location = var.shared_location
}

module "afd" {
  source = "./modules/global_lb"
  app_name = var.application_name
  resource_group = azurerm_resource_group.rg.name
  dns_name = var.dns_name
  backends = [for i, r in var.regions : module.region[i].appgw_ip]
  cert_id = module.region[0].cert_id
  use_self_signed_cert = var.use_self_signed_cert
}
