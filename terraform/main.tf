# Create Resource Group
resource "azurerm_resource_group" "iot_resource_group" {
  name     = var.resource_group_name
  location = var.location
}

###########

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = "iot-telemetry-namespace"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  sku                 = "Standard"
}

# Event Hub
resource "azurerm_eventhub" "eventhub" {
  name                = "iot-telemetry-eventhub"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  partition_count     = 2
  message_retention   = 1
}

# Event Hub Authorization Rule
resource "azurerm_eventhub_authorization_rule" "eventhub_send_rule" {
  name                = "eventhub-send-rule"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  eventhub_name       = azurerm_eventhub.eventhub.name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  listen              = false
  send                = true
  manage              = false
}
resource "azurerm_eventhub_consumer_group" "eventhub_consumer_group" {
  name                = "eventthub-consumer-group"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  eventhub_name       = azurerm_eventhub.eventhub.name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
}

###########

# IoT Hub
resource "azurerm_iothub" "iot_hub" {
  name                = "iot-telemetry-hub"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  sku {
    name     = "S1"
    capacity = 1
  }

  endpoint {
    type                       = "AzureIotHub.StorageContainer"
    connection_string          = azurerm_storage_account.iot_storage_account.primary_blob_connection_string
    name                       = "telemetry-archive"
    batch_frequency_in_seconds = 60
    max_chunk_size_in_bytes    = 10485760
    container_name             = azurerm_storage_container.iot_storage_container_telemetry_raw.name
    encoding                   = "JSON"
    file_name_format           = "{iothub}/{YYYY}/{MM}/{DD}/{HH}/{mm}_{partition}"
  }
  endpoint {
    type              = "AzureIotHub.EventHub"
    connection_string = azurerm_eventhub_authorization_rule.eventhub_send_rule.primary_connection_string
    name              = "eventhub-stream"
  }
  route {
    name           = "telemetry-to-storage"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["telemetry-archive"]
    enabled        = true
  }
  route {
    name           = "telemetry-to-eventhub"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["eventhub-stream"]
    enabled        = true
  }

  enrichment {
    key            = "tenant"
    value          = "$twin.tags.Tenant"
    endpoint_names = ["telemetry-archive"]
  }

  cloud_to_device {
    max_delivery_count = 30
    default_ttl        = "PT1H"
    feedback {
      time_to_live       = "PT1H10M"
      max_delivery_count = 15
      lock_duration      = "PT30S"
    }
  }

  tags = {
    environment = "development"
  }
}

resource "azurerm_iothub_dps" "iot_dps" {
  name                = "telemetry-iot-dps"
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  location            = azurerm_resource_group.iot_resource_group.location
  allocation_policy   = "GeoLatency"

  sku {
    name     = "S1"
    capacity = "1"
  }

  linked_hub {
    connection_string = azurerm_iothub_shared_access_policy.iothub_shared_access_policy.primary_connection_string
    location          = azurerm_iothub.iot_hub.location
  }
}

resource "azurerm_iothub_shared_access_policy" "iothub_shared_access_policy" {
  name                = "iothub-shared-access-policy"
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  iothub_name         = azurerm_iothub.iot_hub.name

  registry_read  = true
  registry_write = true
  service_connect = true
  device_connect = true
}

locals {
  cert_path    = "intermediate"
}
resource "local_file" "create_cert_file" {
  content  = var.iot_dps_intermediate_cert
  filename = local.cert_path
}

resource "null_resource" "create-dps-certificate-device-enrollement" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      az login --service-principal -u  $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID
      az extension add --name azure-iot
      az iot dps enrollment-group create --cp $CERT_PATH -g $RESOURCE_GROUP --dps-name $DPS_NAME --enrollment-id $ENROLLMENT_ID
    EOT
    environment = {
      CLIENT_ID      = var.client_id
      TENANT_ID      = var.tenant_id
      CLIENT_SECRET  = var.client_secret
      RESOURCE_GROUP = var.resource_group_name
      DPS_NAME       = azurerm_iothub_dps.iot_dps.name
      ENROLLMENT_ID  = "${azurerm_iothub_dps.iot_dps.name}-device-enrollement-group"
      CERT_PATH      = local.cert_path
    }
  }

  depends_on = [local_file.create_cert_file]
}


resource "null_resource" "create-dps-symmetric-device-enrollment" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      az login --service-principal -u  $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID
      az extension add --name azure-iot
      az iot dps enrollment create --enrollment-id $ENROLLMENT_ID --dps-name $DPS_NAME -g $RESOURCE_GROUP --auth-type key --provisioning-status enabled --attestation-type symmetricKey  --primary-key $PRIMARY_KEY --secondary-key $SECONDARY_KEY
    EOT
    environment = {
      CLIENT_ID      = var.client_id
      TENANT_ID      = var.tenant_id
      CLIENT_SECRET  = var.client_secret
      RESOURCE_GROUP = var.resource_group_name
      DPS_NAME       = azurerm_iothub_dps.iot_dps.name
      ENROLLMENT_ID  = "device001"
      PRIMARY_KEY    = "${var.primary_key}"
      SECONDARY_KEY  = "${var.secondary_key}"
    }
  }

  depends_on = [azurerm_iothub_dps.iot_dps]
}


# # IoT Hub Consumer Group
resource "azurerm_iothub_consumer_group" "iot_hub_consumer_group" {
  iothub_name           = azurerm_iothub.iot_hub.name
  name                  = "iotthub-consumer-group"
  eventhub_endpoint_name = "events"
  resource_group_name   = azurerm_resource_group.iot_resource_group.name
}

# Storage Account for telemetry data
resource "azurerm_storage_account" "iot_storage_account" {
  name                     = "iottelemetrysa"
  resource_group_name      = azurerm_resource_group.iot_resource_group.name
  location                 = azurerm_resource_group.iot_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Storage Container
resource "azurerm_storage_container" "iot_storage_container_analytics_processed" {
  name                  = "telemetry-data-processed"
  storage_account_name  = azurerm_storage_account.iot_storage_account.name
  container_access_type = "private"
}
resource "azurerm_storage_container" "iot_storage_container_telemetry_raw" {
  name                  = "telemetry-data-raw"
  storage_account_name  = azurerm_storage_account.iot_storage_account.name
  container_access_type = "private"
}

# Stream Analytics Job
resource "azurerm_stream_analytics_job" "stream_analytics_job" {
  name                = "iot-telemetry-stream-analytics-job"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  compatibility_level = "1.2"
  data_locale                              = "en-GB"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 1

  transformation_query = <<QUERY
    SELECT
    event.timestamp AS Timestamp,
    event.patientId AS PatientId,
    event.deviceType AS DeviceType,

    CASE
        WHEN event.biometricData.heartRate >= 40 AND event.biometricData.heartRate <= 180
        THEN event.biometricData.heartRate
        ELSE NULL
    END AS HeartRate,

    CASE
        WHEN event.biometricData.pulse >= 40 AND event.biometricData.pulse <= 180
        THEN event.biometricData.pulse
        ELSE NULL
    END AS Pulse,

    CASE
        WHEN event.biometricData.temperature >= 35 AND event.biometricData.temperature <= 42
        THEN event.biometricData.temperature
        ELSE NULL
    END AS Temperature,

    CASE
        WHEN event.biometricData.steps >= 0
        THEN event.biometricData.steps
        ELSE 0
    END AS Steps,

    CASE
        WHEN event.biometricData.stressLevel BETWEEN 1 AND 10
        THEN event.biometricData.stressLevel
        ELSE NULL
    END AS StressLevel,

    CASE
        WHEN event.biometricData.bloodOxygen BETWEEN 90 AND 100
        THEN event.biometricData.bloodOxygen
        ELSE NULL
    END AS BloodOxygen,

    CASE
        WHEN event.biometricData.bloodPressure.systolic BETWEEN 90 AND 180
        THEN event.biometricData.bloodPressure.systolic
        ELSE NULL
    END AS SystolicBloodPressure,

    CASE
        WHEN event.biometricData.bloodPressure.diastolic BETWEEN 60 AND 120
        THEN event.biometricData.bloodPressure.diastolic
        ELSE NULL
    END AS DiastolicBloodPressure,

    CASE
        WHEN event.gaitData.gaitSpeed BETWEEN 0 AND 10
        THEN event.gaitData.gaitSpeed
        ELSE NULL
    END AS GaitSpeed,

    CASE
        WHEN event.gaitData.cadence BETWEEN 60 AND 200
        THEN event.gaitData.cadence
        ELSE NULL
    END AS Cadence,

    CASE
        WHEN event.gaitData.strideLength BETWEEN 0.5 AND 2
        THEN event.gaitData.strideLength
        ELSE NULL
    END AS StrideLength,

    CASE
        WHEN event.gaitData.footAngle BETWEEN -30 AND 30
        THEN event.gaitData.footAngle
        ELSE NULL
    END AS FootAngle,

    CASE
        WHEN event.gaitData.stepTime BETWEEN 0 AND 2
        THEN event.gaitData.stepTime
        ELSE NULL
    END AS StepTime,

    CASE
        WHEN event.gaitData.stanceTime BETWEEN 0 AND 2
        THEN event.gaitData.stanceTime
        ELSE NULL
    END AS StanceTime,

    CASE
        WHEN event.gaitData.swingTime BETWEEN 0 AND 2
        THEN event.gaitData.swingTime
        ELSE NULL
    END AS SwingTime,

    CASE
        WHEN event.gaitData.doubleSupportTime BETWEEN 0 AND 2
        THEN event.gaitData.doubleSupportTime
        ELSE NULL
    END AS DoubleSupportTime,

    CASE
        WHEN event.deviceStatus.batteryLevel BETWEEN 0 AND 100
        THEN event.deviceStatus.batteryLevel
        ELSE NULL
    END AS BatteryLevel,

    event.deviceStatus.realTimeMode AS RealTimeMode,
    event.deviceStatus.sensorStatus AS SensorStatus,

    event.prostheticData.prostheticId AS ProstheticId,

    CASE
        WHEN event.prostheticData.pressureLevel BETWEEN 0 AND 10
        THEN event.prostheticData.pressureLevel
        ELSE NULL
    END AS PressureLevel,

    event.prostheticData.alignmentStatus AS AlignmentStatus,

    CASE
        WHEN event.prostheticData.vibrationLevel BETWEEN 0 AND 1
        THEN event.prostheticData.vibrationLevel
        ELSE NULL
    END AS VibrationLevel
INTO
    [output-to-storage]
FROM
    [input-from-eventhub] AS event
WHERE
    event.deviceType IN ('smartwatch', 'prosthetic')
    AND event.patientId IS NOT NULL
    AND event.timestamp IS NOT NULL;
  QUERY
}




resource "azurerm_stream_analytics_stream_input_iothub" "input_from_iothub" {
  name                         = "input-from-iothub"
  stream_analytics_job_name    = azurerm_stream_analytics_job.stream_analytics_job.name
  resource_group_name          = azurerm_stream_analytics_job.stream_analytics_job.resource_group_name
  endpoint                     = "messages/events"
  eventhub_consumer_group_name = azurerm_eventhub_consumer_group.eventhub_consumer_group.name
  iothub_namespace             = azurerm_iothub.iot_hub.name
  shared_access_policy_key     = azurerm_iothub.iot_hub.shared_access_policy[0].primary_key
  shared_access_policy_name    = "iothubowner"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# Stream Analytics Input from Event Hub
resource "azurerm_stream_analytics_stream_input_eventhub" "eventhub_input" {
  name                     = "input-from-eventhub"
  stream_analytics_job_name = azurerm_stream_analytics_job.stream_analytics_job.name
  resource_group_name       = azurerm_resource_group.iot_resource_group.name
  eventhub_name             = azurerm_eventhub.eventhub.name
  servicebus_namespace      = azurerm_eventhub_namespace.eventhub_namespace.name

  eventhub_consumer_group_name = azurerm_eventhub_consumer_group.eventhub_consumer_group.name
  shared_access_policy_key     = azurerm_eventhub_namespace.eventhub_namespace.default_primary_key
  shared_access_policy_name    = "RootManageSharedAccessKey"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# Stream Analytics Output to Blob Storage
resource "azurerm_stream_analytics_output_blob" "output_to_storage" {
  name                     = "output-to-storage"
  stream_analytics_job_name = azurerm_stream_analytics_job.stream_analytics_job.name
  resource_group_name       = azurerm_resource_group.iot_resource_group.name
  storage_account_name      = azurerm_storage_account.iot_storage_account.name
  storage_account_key       = azurerm_storage_account.iot_storage_account.primary_access_key
  storage_container_name    = azurerm_storage_container.iot_storage_container_analytics_processed.name
  path_pattern              = "/{date}/{time}/" #"{iothub}/{partition}_{YYYY}_{MM}_{DD}_{HH}_{mm}"
  date_format               = "yyyy/MM/dd"
  time_format               = "HH"
  blob_write_mode           = "Append"

  serialization {
    type            = "Csv"
    encoding        = "UTF8"
    field_delimiter = ","
  }
}


# resource "azurerm_stream_analytics_output_powerbi" "output_to_powerbi" {
#   name                     = "powerbi-output"
#   stream_analytics_job_id = azurerm_stream_analytics_job.stream_analytics_job.id
#   resource_group_name       = azurerm_resource_group.iot_resource_group.name
#
#   group_id      = "00000000-0000-0000-0000-000000000000"
#   dataset = "iot-dataset"
#   table    = "iot-stream_table"
#   group_name              = "group-name"
#   #token_user_principal_name =
#   #token_user_display_name=
# }

# Application Insights
resource "azurerm_application_insights" "application_insights" {
  name                = "telemetry-app-insights"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  application_type    = "web"
}

# Key Vault
resource "azurerm_key_vault" "key_vault" {
  name                = "iot-telemetry-kv"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
}

# Azure ML Workspace
resource "azurerm_machine_learning_workspace" "ml_workspace" {
  name                    = "telemetry-ml-workspace"
  location                = azurerm_resource_group.iot_resource_group.location
  resource_group_name     = azurerm_resource_group.iot_resource_group.name
  application_insights_id = azurerm_application_insights.application_insights.id
  key_vault_id            = azurerm_key_vault.key_vault.id
  storage_account_id      = azurerm_storage_account.iot_storage_account.id

  identity {
    type = "SystemAssigned"
  }
}

# # Azure Machine Learning Dataset
# resource "azurerm_machine_learning_datastore_blobstorage" "iot_dataset_raw" {
#   name                = "iot-dataset-raw"
#   workspace_id      = azurerm_machine_learning_workspace.ml_workspace.id
#   storage_container_id = azurerm_storage_container.iot_storage_container_telemetry_raw.id
#   account_key = ""
# }
#
# # Azure Machine Learning Dataset
# resource "azurerm_machine_learning_datastore_blobstorage" "iot_dataset_processed" {
#   name                = "iot-dataset-processed"
#   workspace_id     = azurerm_machine_learning_workspace.ml_workspace.id
#   account_key = ""
#   storage_container_id = azurerm_storage_container.iot_storage_container_telemetry_raw.id
# }


resource "azurerm_machine_learning_compute_instance" "ml_compute_instance" {
  name                = "ml-compute-inst"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml_workspace.id
  virtual_machine_size                = "Standard_D11_v2"

  identity {
    type = "SystemAssigned"
  }
  authorization_type            = "personal"
  ssh {
    public_key = var.ssk_key_ml_cluster
  }
}


resource "azurerm_machine_learning_compute_cluster" "ml_compute_cluster" {
  name                = "ml-compute-cluster"
  location            = azurerm_machine_learning_workspace.ml_workspace.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml_workspace.id
  vm_size                = "Standard_D11_v2"
  vm_priority                   = "Dedicated"
  scale_settings {
    min_node_count = 0
    max_node_count = 1
    scale_down_nodes_after_idle_duration = "PT30S"
  }

  identity {
    type = "SystemAssigned"
  }
}

##------------------

# ADF
resource "azurerm_data_factory" "iot-etl-adf" {
  name                = "iot-etl-data-factory"
  location            = azurerm_resource_group.iot_resource_group.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "IoTStorageAccountLinkService" {
  name                = "iot-blob-storage"
  data_factory_id   = azurerm_data_factory.iot-etl-adf.id

  connection_string = format("DefaultEndpointsProtocol=https;AccountName=%s;AccountKey=%s;EndpointSuffix=core.windows.net",
    azurerm_storage_account.iot_storage_account.name,
    azurerm_storage_account.iot_storage_account.primary_access_key
  )
 }

# Generate a random username
resource "random_string" "sql_admin_username" {
  length  = 10
  special = false
  upper   = false
}

# Generate a random password
resource "random_password" "sql_admin_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+-="
}

resource "azurerm_mssql_server" "iot_hist_sql_server" {
  name                         = "iot-sql-server-${random_string.sql_admin_username.result}"
  resource_group_name          = azurerm_resource_group.iot_resource_group.name
  location                     = azurerm_resource_group.iot_resource_group.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  administrator_login          = random_string.sql_admin_username.result
  administrator_login_password = random_password.sql_admin_password.result
}
resource "azurerm_mssql_database" "iot_hist_sql_database" {
  name         = "iot-db"
  server_id    = azurerm_mssql_server.iot_hist_sql_server.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}



resource "azurerm_data_factory_linked_service_sql_server" "iot_sqldb_linked_service" {
  name                 = "iot-sqldb-linked-service"
  data_factory_id      = azurerm_data_factory.iot-etl-adf.id
  connection_string    = <<-EOF
    Server=tcp:${azurerm_mssql_server.iot_hist_sql_server.fully_qualified_domain_name},1433;
    Initial Catalog=${azurerm_mssql_database.iot_hist_sql_database.name};
    User ID=${random_string.sql_admin_username.result};
    Password=${random_password.sql_admin_password.result};
    Encrypt=true;
    Connection Timeout=30;
  EOF
}