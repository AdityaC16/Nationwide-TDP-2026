variable "sql_admin_username" {
  type    = string
  default = "carbonadmin"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}
