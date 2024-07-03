terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.5.0"
    }
    oci = {
      source  = "oracle/oci"
      version = ">=5.40.0"
    }
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    templatefile("${path.module}/templates/controlplane.yaml.tpl", {
      endpoint_ipv4 = local.endpoint
      allowSchedulingOnControlPlanes = var.allowSchedulingOnControlPlanes
    })
  ]
}

data "talos_machine_configuration" "worker" {
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    templatefile("${path.module}/templates/worker.yaml.tpl", {})
  ]
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

resource "oci_core_instance" "controlplane" {
  count          = var.controlplane_count
  compartment_id = var.compartment_id
  shape          = var.shape
  display_name   = "instance-talos-${var.cluster_name}-${count.index}"
  shape_config {
    memory_in_gbs = var.memory
    ocpus         = var.ocpus
  }

  availability_domain = data.oci_identity_availability_domains.this.availability_domains[count.index % length(data.oci_identity_availability_domains.this.availability_domains)].name

  source_details {
    source_id   = var.image
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_ipv6ip    = var.ipv6_enabled
    private_ip       = cidrhost(oci_core_subnet.this.cidr_block, 11 + count.index)
    assign_public_ip = true
  }

  launch_options {
    network_type = "PARAVIRTUALIZED"
  }

  metadata = {
    user_data = base64encode(yamlencode(yamldecode(data.talos_machine_configuration.controlplane.machine_configuration)))
  }
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [oci_core_instance.controlplane[0].private_ip]
  endpoints            = [local.endpoint]
}

# Fails because the public ipv4 is not part of the cert SAN. OCI doesn't have this connected to the VM
# resource "talos_machine_configuration_apply" "controlplane" {
#   count = var.controlplane_count

#   client_configuration        = talos_machine_secrets.this.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
#   node                        = oci_core_instance.controlplane[count.index].private_ip
#   endpoint                    = oci_core_instance.controlplane[count.index].public_ip
# }

resource "talos_machine_bootstrap" "this" {
  node                 = oci_core_instance.controlplane[0].private_ip
  endpoint             = local.endpoint
  depends_on           = [oci_network_load_balancer_backend.controlplane, oci_network_load_balancer_backend.talos] # , talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
}


data "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.endpoint
}

output "kubeconfig" {
  value = data.talos_cluster_kubeconfig.this.kubeconfig_raw
}
