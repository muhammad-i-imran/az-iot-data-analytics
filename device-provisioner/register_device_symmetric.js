'use strict';

const fs = require('fs');
const { Client, Message } = require('azure-iot-device');
const { ProvisioningDeviceClient } = require('azure-iot-provisioning-device');
const { SymmetricKeySecurityClient } = require('azure-iot-security-symmetric-key');
const Mqtt = require('azure-iot-device-mqtt').Mqtt;
const ProvisioningTransport = require('azure-iot-provisioning-device-mqtt').Mqtt;

const provisioningHost = process.env.PROVISIONING_HOST;
const idScope = process.env.ID_SCOPE;
const registrationId = process.env.REGISTRATION_ID;
const symmetricKey = process.env.SYMMETRIC_KEY;



const securityClient = new SymmetricKeySecurityClient(registrationId, symmetricKey);
const transport = new ProvisioningTransport();
const provisioningClient = ProvisioningDeviceClient.create(provisioningHost, idScope, transport, securityClient);

const registerDevice = () => {
  provisioningClient.register((err, result) => {
    if (err) {
      console.error("Error registering device:", err);
      return;
    }
    console.log('Registration succeeded');
    console.log('Assigned hub:', result.assignedHub);
    console.log('Device ID:', result.deviceId);

    const connectionString = createConnectionString(result.assignedHub, result.deviceId);
    sendTelemetry(connectionString);
  });
};

const createConnectionString = (assignedHub, deviceId) => {
  return `HostName=${assignedHub};DeviceId=${deviceId};SharedAccessKey=${symmetricKey}`;
};

 const sendTelemetry = (connectionString) => {
  const client = Client.fromConnectionString(connectionString, Mqtt);

  client.open((err) => {
    if (err) {
      console.error('Could not connect:', err.message);
      return;
    }
    console.log('Client connected');

    const message = createMessage();
    console.log('Sending message:', message.getData());

    client.sendEvent(message, (err) => {
      if (err) {
        console.error('Error sending message:', err.toString());
      } else {
        console.log('Message sent successfully');
      }
    });
  });
};

const createMessage = () => {
  const telemetryData = {
    test: 12345
  };
  return new Message(JSON.stringify(telemetryData));
};

registerDevice();
