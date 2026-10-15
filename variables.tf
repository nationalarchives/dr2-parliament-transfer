variable "layer_version_arn" {
  description = "ARN of the existing ImageMagick Lambda layer version."
  type        = string
}

variable "ctd_kms_key_arn" {
  description = "ARN of the KMS key used by the existing CTD processing bucket."
  type        = string
}

variable "dr2_importer_role_arn" {
  description = "ARN of the DR2 importer role granted read access to the transfer bucket."
  type        = string
}

variable "dr2_transfer_role_arn" {
  description = "ARN of the DR2 transfer role granted write access to the transfer bucket."
  type        = string
}
