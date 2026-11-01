variable "name" {
  description = "Name prefix for all network resources (e.g. hotel-bookings-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be /16../20 so it can be split into /20 subnets per tier."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix length of /20 or larger (e.g. 10.10.0.0/16)."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. ALB and RDS subnet groups need at least two."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 4
    error_message = "Provide between 2 and 4 availability zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, dev) instead of one per AZ (highly available, prod)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Ship VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention for the VPC flow log group."
  type        = number
  default     = 30
}
