output "resource_group_name" {
  description = "The name of the resource group for IoT Hub and other services."
  value       = azurerm_resource_group.iot_resource_group.name
}

output "iot_hub_name" {
  description = "The name of the IoT Hub."
  value       = azurerm_iothub.iot_hub.name
}

output "eventhub_namespace_name" {
  description = "The name of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.eventhub_namespace.name
}

output "eventhub_name" {
  description = "The name of the Event Hub."
  value       = azurerm_eventhub.eventhub.name
}

output "eventhub_send_rule_primary_key" {
  description = "The primary key for the Event Hub authorization send rule."
  value       = azurerm_eventhub_authorization_rule.eventhub_send_rule.primary_key
  sensitive   = true
}

output "eventhub_consumer_group_name" {
  description = "The name of the Event Hub consumer group."
  value       = azurerm_eventhub_consumer_group.eventhub_consumer_group.name
}

output "iot_hub_dps_name" {
  description = "The name of the IoT Hub Device Provisioning Service."
  value       = azurerm_iothub_dps.iot_dps.name
}

output "iot_hub_shared_access_policy_primary_key" {
  description = "The primary key for the IoT Hub shared access policy."
  value       = azurerm_iothub_shared_access_policy.iothub_shared_access_policy.primary_key
  sensitive   = true
}

output "storage_account_name" {
  description = "The name of the Storage Account for telemetry data."
  value       = azurerm_storage_account.iot_storage_account.name
}

output "telemetry_storage_container_raw_name" {
  description = "The name of the storage container for raw telemetry data."
  value       = azurerm_storage_container.iot_storage_container_telemetry_raw.name
}

output "telemetry_storage_container_processed_name" {
  description = "The name of the storage container for processed telemetry data."
  value       = azurerm_storage_container.iot_storage_container_analytics_processed.name
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key for Application Insights."
  value       = azurerm_application_insights.application_insights.instrumentation_key
  sensitive = true
}

output "key_vault_uri" {
  description = "The URI of the Key Vault."
  value       = azurerm_key_vault.key_vault.vault_uri
}

output "stream_analytics_job_name" {
  description = "The name of the Stream Analytics Job."
  value       = azurerm_stream_analytics_job.stream_analytics_job.name
}

output "stream_analytics_input_name" {
  description = "The name of the Stream Analytics input from Event Hub."
  value       = azurerm_stream_analytics_stream_input_eventhub.eventhub_input.name
}

output "stream_analytics_output_storage_name" {
  description = "The name of the Stream Analytics output to Blob Storage."
  value       = azurerm_stream_analytics_output_blob.output_to_storage.name
}

output "ml_workspace_name" {
  description = "The name of the Azure ML Workspace."
  value       = azurerm_machine_learning_workspace.ml_workspace.name
}

output "sql_admin_username" {
  description = "The admin username of the SQL database."
  value = random_string.sql_admin_username.result
}

output "sql_admin_password" {
  description = "The password of the admin user in SQL database."
  value = random_password.sql_admin_password.result
  sensitive = true
}
