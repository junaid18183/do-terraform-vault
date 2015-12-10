variable "role" { default="consul" }
variable "image" { default="ubuntu-14-04-x64" }
variable "count" { default=3 }
variable "region" { default="nyc2" }
variable "size" { default="1gb" }
variable "ssh_key_id" {}
variable "consul_encrypt_key" {}
variable "ca_file" {}
variable "consul_cert_file" {}
variable "consul_key_file" {}
