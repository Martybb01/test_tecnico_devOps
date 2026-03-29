# creiamo un bus custom per isolarci dagli eventi AWS di sistema + archivio x audit a 30gg

resource "aws_cloudwatch_event_bus" "order_events" {
  name = "order-events"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_archive" "order_events" {
  name             = "order-events-archive"
  event_source_arn = aws_cloudwatch_event_bus.order_events.arn
  retention_days   = 30

  event_pattern = jsonencode({
    source = [{ "prefix" = "myapp" }] # archivio tutti gli eventi
  })
}

# anche se gli eventi non matchano lo schema non vengono rifiutati,
resource "aws_schemas_registry" "order_events" {
  name        = "order-events-registry"
  description = "Schema registry per gli eventi del dominio ordini"
}

resource "aws_schemas_schema" "order_created" {
  name          = "myapp.orders@OrderCreated"
  registry_name = aws_schemas_registry.order_events.name
  type          = "OpenApi3"
  description   = "Schema definito per l'evento di order-processor"

  content = jsonencode({
    openapi = "3.0.0"
  	info    = { title = "OrderCreated", version = "1.0.0" }
  	components = {
      schemas = {
      	OrderCreated = {
          type     = "object"
          required = ["orderId", "customerId", "amount", "timestamp"]
          properties = {
            orderId    = { type = "string" }
            customerId = { type = "string" }
            amount     = { type = "number" }
            timestamp  = { type = "string" }
          }
      	}
      }
  	}
  })
}

output "event_bus_name" {
  description = "Nome del custom event bus"
  value       = aws_cloudwatch_event_bus.order_events.name
}

output "event_bus_arn" {
  description = "ARN del custom event bus"
  value       = aws_cloudwatch_event_bus.order_events.arn
}
