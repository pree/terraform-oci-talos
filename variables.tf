variable "compartment_id" {
  type = string
}

variable "defined_tags" {
  type    = map(string)
  default = null
}

variable "freeform_tags" {
  type    = map(string)
  default = null
}

variable "ipv6_enabled" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type = string
}

variable "vcn_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  type    = string
  default = "10.0.0.0/24"
}

variable "talos_version" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory" {
  type    = number
  default = 6
}

variable "image" {
  type    = string
}

variable "controlplane_count" {
  type    = number
  default = 3
}

variable "worker_count" {
  type    = number
  default = 0
}

variable "allowSchedulingOnControlPlanes" {
  type = bool
  default = false
}
