output "iot_hub_id" {
  value = azurerm_iothub.iot_hub.id
}

output "storage_account_id" {
  value = azurerm_storage_account.iot_storage_account.id
}

output "stream_analytics_job_id" {
  value = azurerm_stream_analytics_job.stream_analytics_job.id
}

output "ml_workspace_id" {
  value = azurerm_machine_learning_workspace.ml_workspace.id
}
