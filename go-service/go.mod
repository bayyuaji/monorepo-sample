module github.com/youruser/my-monorepo/go-service

go 1.22

require (
	go.opentelemetry.io/otel v1.28.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.28.0
	go.opentelemetry.io/otel/sdk/resource v1.28.0
	go.opentelemetry.io/otel/sdk/trace v1.28.0
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.53.0
)

