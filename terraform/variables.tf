variable "region" {
  description = "The AWS region to launch in"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "The name of the project"
  type        = string
  default     = "lgtm-tonystrawberry-codes"
}

variable "domain" {
  description = "The domain to use for the DNS zone"
  type        = string
  default     = "tonystrawberry.codes"
}

variable "tag" {
  description = "The tag to use for the Docker image"
  type        = string
}

variable "giphy_api_key" {
  description = "The Giphy API key"
  type        = string
}

variable "unsplash_api_key" {
  description = "The Unsplash API key"
  type        = string
}
