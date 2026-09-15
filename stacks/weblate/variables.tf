variable "admin_ssh_cidr" {
  description = "Administrator IPv4 host allowed SSH. Update host UFW as well; cloud-init does not rerun on adoption."
  type        = string
  default     = "73.170.36.107/32"
  validation {
    condition     = can(cidrnetmask(var.admin_ssh_cidr)) && endswith(var.admin_ssh_cidr, "/32")
    error_message = "SSH must be limited to one valid IPv4 /32 administrator address."
  }
}
