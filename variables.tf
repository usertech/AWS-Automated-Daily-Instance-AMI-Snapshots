variable "stage" {}
variable "region" {}

variable "retention_time" {
  default     = "14"
  description = "Is the number of days you want to keep the backups for (e.g. `14`)"
}

variable "dry_run" {
  default = "false"
}

variable "key_to_tag_on" {
  default = "AWSAUtomatedDailySnapshots"
}

variable "limit_to_regions" {
  default = ""
}

variable "backup_schedule" {
  default     = "cron(00 19 * * ? *)"
  description = "The scheduling expression. (e.g. cron(0 20 * * ? *) or rate(5 minutes)"
}
