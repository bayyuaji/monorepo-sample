const express = require("express");
const { NodeSDK } = require("@opentelemetry/sdk-node");
const { OTLPTraceExporter } = require("@opentelemetry/exporter-trace-otlp-http");
const { diag, DiagConsoleLogger, DiagLogLevel } = require("@opentelemetry/api");

diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.ERROR);

const otlpEndpoint =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  "http://otel-collector.demo-apps.svc.cluster.local:4318";

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: `${otlpEndpoint}/v1/traces`,
  }),
  serviceName: "node-service",
});

sdk.start().then(() => {
  const app = express();

  app.get("/", (req, res) => {
    res.send("Hello from Node service");
  });

  app.get("/healthz", (req, res) => {
    res.send("ok");
  });

  const port = 8080;
  app.listen(port, () => {
    console.log(`Node service listening on ${port}`);
  });
});

