variable "subscription_id" {
  description = "Azure subscription ID"
}

variable "client_id" {
  description = "Service Principal application ID"
}

variable "client_secret" {
  description = "Service Principal password"
}

variable "tenant_id" {
  description = "Azure tenant ID"
}

variable "resource_group_name" {
  description = "Name of the resource group"
 }

variable "location" {
  description = "Azure region"
  default     = "East US"
}

variable "ssk_key_ml_cluster" {
  description = "Azure SSH Key for AZ ML Cluster"
}

variable "iot_dps_intermediate_cert" {
  default = ""
  type        = string
}

variable "primary_key" {
  default = "Primary key for IoT DPS Symmetric key"
}
variable "secondary_key" {
  default = "Secondary key for IoT DPS Symmetric key"
}