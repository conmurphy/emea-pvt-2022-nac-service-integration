terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.1.0"
    }
    utils = {
      source  = "netascode/utils"
      version = ">= 0.1.2"
    }
  }
}

# provider "aci" {
#   username = "username"
#   password = "password"
#   url      = "https://apic.url"
#   insecure = true
#   retries  = 4
# }

locals {
  model = yamldecode(data.utils_yaml_merge.model.output)
}

data "utils_yaml_merge" "model" {
  input = concat([for file in fileset(path.module, "data/*.yaml") : file(file)], [file("${path.module}/defaults/defaults.yaml")])
}

module "fabric_policies" {
  source  = "netascode/nac-fabric-policies/aci"
  version = "0.3.0"

  model = local.model
}

module "access_policies" {
  source  = "netascode/nac-access-policies/aci"
  version = "0.3.0"

  model = local.model
}

module "interface_policies" {
  source  = "netascode/nac-interface-policies/aci"
  version = "0.3.1"

  for_each = { for node in   lookup(lookup(local.model.apic, "interface_policies", {}), "nodes", []) : node.id => node }
  model    = local.model
  node_id  = each.value.id

  depends_on = [module.access_policies]
}

module "tenant" {
  source  = "netascode/nac-tenant/aci"
  version = ">= 0.3.1"

  for_each    = toset([for tenant in lookup(local.model.apic, "tenants", {}) : tenant.name])
  model       = local.model
  tenant_name = each.value

  depends_on = [module.fabric_policies, module.interface_policies]
}


