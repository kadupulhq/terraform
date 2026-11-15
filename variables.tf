# SPDX-FileCopyrightText: 2026 Thomas Vincent <thomasvincent@gmail.com>
# SPDX-License-Identifier: MIT

variable "organization" {
  description = "GitHub organisation these resources belong to."
  type        = string
  default     = "kadupulhq"
}

variable "maintainers" {
  description = "GitHub logins with admin on every repository."
  type        = list(string)
  default     = ["somethingwithproof"]
}
