### SQS Queues

locals {
  sqs_queues = {
    "gallupx-core" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-cron-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-debug-engine-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-engine-tasks" = {
      visibility_timeout_seconds = 900
    }
    "gallupx-event-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-fps-engine-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-notification-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-tick-tasks" = {
      visibility_timeout_seconds = 30
    }
    "gallupx-webhook-engine-tasks" = {
      visibility_timeout_seconds = 30
    }
  }
}

## Dead Letter Queues
resource "aws_sqs_queue" "deadletter" {
  for_each = local.sqs_queues

  name                       = "${var.res_prefix}-${each.key}-deadletter"
  message_retention_seconds  = 1209600
  max_message_size           = 262144
  visibility_timeout_seconds = 30
}

## Main Queues
resource "aws_sqs_queue" "main" {
  for_each = local.sqs_queues

  name                       = "${var.res_prefix}-${each.key}"
  message_retention_seconds  = 1209600
  max_message_size           = 262144
  visibility_timeout_seconds = each.value.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[each.key].arn
    maxReceiveCount     = 3
  })
}
