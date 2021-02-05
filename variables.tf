variable "profile_name" {
  type        = string
  description = "Profile name being used."
}

variable "region" {
  type        = string
  description = "Available AWS regions."
}

variable "account_id" {
  type        = string
  description = "AWS account with this infrastructure."
}

variable "iam_users" {
  type        = set(string)
  description = "List of users with access to this AWS account."
}

variable "iam_users_policies" {
  type = map(object({ 
    iam_user = string,
    policy = string}))
  description = "List of user-policy pairs to assign policies to users directly"
}
