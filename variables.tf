variable "region" {
  description = "The AWS region to launch in"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "The name of the project"
  type        = string
  default     = "life-tonystrawberry-codes"
}

variable "domain" {
  description = "The domain to use for the DNS zone"
  type        = string
  default     = "tonystrawberry.codes"
}
