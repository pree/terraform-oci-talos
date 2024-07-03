locals {
  endpoint = oci_network_load_balancer_network_load_balancer.this.ip_addresses[index(oci_network_load_balancer_network_load_balancer.this.ip_addresses.*.is_public, true)].ip_address
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  display_name   = "vcn-talos-${var.cluster_name}"

  cidr_blocks    = [var.vcn_cidr_block]
  is_ipv6enabled = var.ipv6_enabled

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  display_name   = "ig-talos-${var.cluster_name}"

  vcn_id  = oci_core_vcn.this.id
  enabled = true

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "this" {
  compartment_id = var.compartment_id
  display_name   = "sl-talos-${var.cluster_name}"

  vcn_id = oci_core_vcn.this.id
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }
  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "all"
    stateless = false
  }

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "this" {
  compartment_id = var.compartment_id
  display_name   = "rt-talos-${var.cluster_name}"
  vcn_id         = oci_core_vcn.this.id

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "this" {
  compartment_id = var.compartment_id
  display_name   = "subnet-talos-${var.cluster_name}"

  vcn_id            = oci_core_vcn.this.id
  cidr_block        = var.subnet_cidr_block
  route_table_id    = oci_core_route_table.this.id
  security_list_ids = [oci_core_security_list.this.id]

  ipv6cidr_blocks = var.ipv6_enabled ? ["${split("/", oci_core_vcn.this.ipv6cidr_blocks[0])[0]}${split(".", split("/", oci_core_vcn.this.cidr_blocks[0])[0])[2]}/64"] : []

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_network_load_balancer_network_load_balancer" "this" {
  compartment_id = var.compartment_id
  display_name   = "lb-talos-${var.cluster_name}"
  subnet_id      = oci_core_subnet.this.id

  is_preserve_source_destination = false
  is_private                     = false
  nlb_ip_version                 = var.ipv6_enabled ? "IPV4_AND_IPV6" : "IPV4"

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

resource "oci_network_load_balancer_backend_set" "talos" {
  name                     = "talos"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id

  is_preserve_source = false
  policy             = "TWO_TUPLE"
  health_checker {
    protocol           = "TCP"
    port               = 50000
    interval_in_millis = 10000
  }
}

resource "oci_network_load_balancer_backend_set" "controlplane" {
  name                     = "controlplane"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id

  is_preserve_source = false
  policy             = "TWO_TUPLE"
  health_checker {
    protocol           = "HTTPS"
    port               = 6443
    interval_in_millis = 10000
    return_code        = 401
    url_path           = "/readyz"
  }
}

resource "oci_network_load_balancer_listener" "talos" {
  name                     = "talos"
  default_backend_set_name = oci_network_load_balancer_backend_set.talos.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id

  port     = 50000
  protocol = "TCP"
}

resource "oci_network_load_balancer_listener" "controlplane" {
  name                     = "controlplane"
  default_backend_set_name = oci_network_load_balancer_backend_set.controlplane.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id

  port     = 6443
  protocol = "TCP"
}

resource "oci_network_load_balancer_backend" "controlplane" {
  count = var.controlplane_count

  backend_set_name         = oci_network_load_balancer_backend_set.controlplane.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id
  port                     = 6443
  target_id                = oci_core_instance.controlplane[count.index].id
}

resource "oci_network_load_balancer_backend" "talos" {
  count = var.controlplane_count

  backend_set_name         = oci_network_load_balancer_backend_set.talos.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id
  port                     = 50000
  target_id                = oci_core_instance.controlplane[count.index].id
}

output "endpoint" {
  value = local.endpoint
}
