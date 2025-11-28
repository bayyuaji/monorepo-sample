import express from "express";
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";
import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";
import { Resource } from "@opentelemetry/resources";

const app = express();
const PORT = process.env.PORT || 3000;

const OTEL_ENDPOINT =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  "http://otel-collector.monitoring.svc.cluster.local:4318";

const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || "node-service";

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
  }),
  // biarkan base URL dikontrol oleh OTEL_EXPORTER_OTLP_ENDPOINT
  traceExporter: new OTLPTraceExporter({
    url: `${OTEL_ENDPOINT}/v1/traces`,
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: `${OTEL_ENDPOINT}/v1/metrics`,
    }),
    exportIntervalMillis: 60000,
  }),
});

// --- OTel start (sinkron, tanpa .then) ---
try {
  sdk.start();
  console.log(
    `OTEL initialized → service=${SERVICE_NAME}, endpoint=${OTEL_ENDPOINT}`
  );
} catch (err) {
  console.error("Failed to start OpenTelemetry SDK", err);
  process.exit(1);
}

// --- HTTP routes ---
app.get("/", (req, res) => {
  res.send("Hello from Node service with OTel!");
});

app.get("/healthz", (req, res) => {
  res.status(200).send("ok");
});

app.listen(PORT, () => {
  console.log(`Node service running on port ${PORT}`);
});

