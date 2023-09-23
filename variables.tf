variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "key_name" {
  description = "Key pair name"
  type        = string
  default     = "lambda"
}

variable "public_key_file" {
  description = "Public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_file" {
  description = "Private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ami_name" {
  description = "AMI name"
  type        = string
  default     = "amzn-ami-hvm-2018.03.0.20220802.0-x86_64-gp2"
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.large"
}

variable "volume_size" {
  description = "EBS disk size"
  type        = string
  default     = "20"
}
