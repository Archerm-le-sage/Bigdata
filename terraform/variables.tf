variable "credentials_file" {
  description = "Path to GCP service account JSON (absolute path)"
  type        = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "network_name" {
  type    = string
  default = "spark-network"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "master_machine_type" { default = "e2-medium" }
variable "worker_machine_type" { default = "e2-small" }
variable "worker_count" { default = 2 }

variable "ssh_public_key_path" {
  type = string
  description = "Path to public SSH key to inject into project metadata (e.g. ~/.ssh/id_rsa.pub)"
}

variable "ubuntu_image" {
  description = "Ubuntu image used for Spark nodes"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}
