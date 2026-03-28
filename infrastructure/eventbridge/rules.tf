# Definisce le rules che fanno il routing degli eventi verso le Lambda.

# il flusso è: l'evento arriva sul bus, eventbridge confronta evento con event_pattern -->
# se matchano manda l'evento al target (lambda email-notifier). Se questo fallisce, viene applicata la retry_policy (2 max).
# Se falliscono tutti i retry, manda l'evento alla DLQ

resource "aws_cloudwatch_event_rule" "order_created" {
  name           = "order-created-rule"
  description    = "Matcha eventi OrderCreated e li manda all'email-notifier"
  event_bus_name = aws_cloudwatch_event_bus.order_events.name

  # devono corrispondere entrambi a quello che pubblica order-processor
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["OrderCreated"]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Il "target" collega la rule alla Lambda destinataria
resource "aws_cloudwatch_event_target" "email_notifier" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = aws_cloudwatch_event_bus.order_events.name
  arn            = var.email_notifier_arn

  retry_policy {
    maximum_retry_attempts       = 2  # avvengono con pause crescenti
    maximum_event_age_in_seconds = 3600  # 1 ora retention
  }

  dead_letter_config {
    arn = var.dlq_arn # dlq config
  }
}

# lambda che autorizza eventbridge a invocarla
resource "aws_lambda_permission" "allow_eventbridge_email" {
  statement_id  = "AllowEventBridgeInvokeEmail"
  action        = "lambda:InvokeFunction"
  function_name = var.email_notifier_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_created.arn
}


resource "aws_cloudwatch_event_rule" "data_sync_schedule" {
  name                = "data-sync-daily"
  description         = "Trigger giornaliero alle 2AM UTC per il data sync RDS → S3"
  event_bus_name      = "default"  # i cron usano il bus default, non custom
  schedule_expression = "cron(0 2 * * ? *)"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "data_sync" {
  rule = aws_cloudwatch_event_rule.data_sync_schedule.name
  arn  = var.data_sync_arn
}

resource "aws_lambda_permission" "allow_eventbridge_datasync" {
  statement_id  = "AllowEventBridgeInvokeDataSync"
  action        = "lambda:InvokeFunction"
  function_name = var.data_sync_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_sync_schedule.arn
}

# permette a eventbridge di scrivere nella coda quando la lambda fallisce
resource "aws_sqs_queue_policy" "dlq" {
  queue_url = var.dlq_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgeSendMessage"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = var.dlq_arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.order_created.arn
        }
      }
    }]
  })
}
