locals {
  module_relpath = "${substr(path.module, length(path.cwd) + 1, -1)}"
  role_name      = "ec2-daily-snapshot-${var.stage}-${var.region}"
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = ""

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
      ]
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

data "aws_iam_policy_document" "ami_backup" {
  statement {
    actions = [
      "logs:*",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }

  statement {
    actions = [
      "ec2:CreateImage",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:DeleteSnapshot",
      "ec2:DeregisterImage",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
    ]

    resources = [
      "*",
    ]
  }
}

data "archive_file" "ami_backup" {
  type        = "zip"
  source_file = "${local.module_relpath}/handler.py"
  output_path = "${local.module_relpath}/handler.zip"
}

resource "aws_iam_role" "ami_backup" {
  name               = "${local.role_name}-lambdaRole"
  assume_role_policy = "${data.aws_iam_policy_document.default.json}"
}

resource "aws_iam_role_policy" "ami_backup" {
  name   = "${local.role_name}-lambda"
  role   = "${aws_iam_role.ami_backup.id}"
  policy = "${data.aws_iam_policy_document.ami_backup.json}"
}

resource "aws_lambda_function" "ami_backup" {
  filename         = "${data.archive_file.ami_backup.output_path}"
  function_name    = "${local.role_name}-execute_handler"
  description      = "Automatically backup EC2 instance (create AMI) and delete expired AMIs"
  role             = "${aws_iam_role.ami_backup.arn}"
  timeout          = 60
  handler          = "handler.lambda_handler"
  runtime          = "python3.6"
  source_code_hash = "${data.archive_file.ami_backup.output_base64sha256}"

  environment = {
    variables = {
      DEFAULT_RETENTION_TIME = "${var.retention_time}"
      DRY_RUN                = "${var.dry_run}"
      KEY_TO_TAG_ON          = "${var.key_to_tag_on}"
      LIMIT_TO_REGIONS       = "${var.limit_to_regions}"
    }
  }
}

resource "null_resource" "schedule" {
  triggers = {
    backup  = "${var.backup_schedule}"
  }
}

resource "aws_cloudwatch_event_rule" "ami_backup" {
  name                = "${local.role_name}"
  description         = "Schedule for AMI snapshot backups"
  schedule_expression = "${null_resource.schedule.triggers.backup}"
  depends_on          = ["null_resource.schedule"]
}


resource "aws_cloudwatch_event_target" "ami_backup" {
  rule      = "${aws_cloudwatch_event_rule.ami_backup.name}"
  target_id = "${local.role_name}"
  arn       = "${aws_lambda_function.ami_backup.arn}"
}

resource "aws_lambda_permission" "ami_backup" {
  statement_id  = "${local.role_name}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ami_backup.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ami_backup.arn}"
}
