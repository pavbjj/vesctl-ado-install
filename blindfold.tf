# Create vesconfig
resource "local_file" "vesconfig" {
  filename = "${path.module}/../../scripts/.vesconfig"
  content  = <<EOT
server-urls: ${var.url}
p12-bundle: ${var.api_p12_file}
EOT
}

# Module to encrypt/Blindfold the public and private key
module "shell_blindfold_cert" {
  for_each       = { for cert in var.certificates : cert.name => cert }
  source         = "Invicton-Labs/shell-data/external"
  command_unix   = "../../scripts/blindfold.sh ${each.value.cert} ${each.value.key}"
  fail_on_stderr = true
  depends_on = [local_file.vesconfig]
}

# Local to parse Blindfolded JSON
locals {
  parsed_outputs = {
    for name, mod in module.shell_blindfold_cert :
    name => sensitive(jsondecode(mod.stdout))
  }
}

# ** Left for potential future use **
# Extract CN from certifcate and replace '.' with '-' so it's XC naming convention compliant
data "external" "get_certificate_cn" {
  for_each = { for cert in var.certificates : cert.name => cert }
  program = [
    "bash", "-c",
    "echo \"{\\\"certificate_cn\\\": \\\"$(openssl x509 -noout -subject -in ${each.value.cert} 2>/dev/null | sed -n 's/.*CN=\\([^/]*\\).*/\\1/p')\\\"}\""
  ]
}

# Main resource to upload certficates to XC
resource "volterra_certificate" "ssl_certficate" {
  for_each        = { for cert in var.certificates : cert.name => cert }
  # ** Left for potential future use **
  # name            = replace(data.external.get_certificate_cn[each.key].result["certificate_cn"], ".", "-")
  name            = format("sdr-crt-%s-%s-tf", var.app_name, each.value.name)
  namespace       = var.namespace
  description     = var.description
  certificate_url = local.parsed_outputs[each.key].cert
  certificate_chain {
    name = var.intermediate_cert
    namespace = var.intermediate_namespace
  }
  private_key {
    blindfold_secret_info {
      decryption_provider = ""
      store_provider      = ""
      location            = local.parsed_outputs[each.key].blindfold
    }
  }
}
