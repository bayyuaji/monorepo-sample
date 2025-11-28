package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
)

func main() {
	ctx := context.Background()

	shutdown, err := initOpenTelemetry(ctx)
	if err != nil {
		log.Fatalf("failed to initialize OpenTelemetry: %v", err)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := shutdown(ctx); err != nil {
			log.Printf("error during OTEL shutdown: %v", err)
		}
	}()

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		tracer := otel.Tracer("go-service")
		ctx, span := tracer.Start(r.Context(), "handle-root")
		defer span.End()

		span.SetAttributes(attribute.String("http.method", r.Method))
		span.SetAttributes(attribute.String("http.path", r.URL.Path))

		_, _ = w.Write([]byte("Hello from Go service with OTel!"))

		_ = ctx
	})

	port := getEnv("PORT", "8080")
	addr := ":" + port
	log.Printf("Go service listening on %s", addr)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

func initOpenTelemetry(ctx context.Context) (func(context.Context) error, error) {
	serviceName := getEnv("OTEL_SERVICE_NAME", "go-service")

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// -------- Trace exporter --------
	traceExporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithInsecure(), // endpoint diatur via OTEL_EXPORTER_OTLP_ENDPOINT
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tracerProvider)

	// -------- Metric exporter --------
	metricExporter, err := otlpmetrichttp.New(ctx,
		otlpmetrichttp.WithInsecure(), // endpoint diatur via OTEL_EXPORTER_OTLP_ENDPOINT
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create metric exporter: %w", err)
	}

	meterProvider := metric.NewMeterProvider(
		metric.WithReader(
			metric.NewPeriodicReader(
				metricExporter,
				metric.WithInterval(60*time.Second),
			),
		),
		metric.WithResource(res),
	)
	otel.SetMeterProvider(meterProvider)

	log.Printf("OpenTelemetry initialized for service=%s", serviceName)

	// shutdown function
	return func(ctx context.Context) error {
		var firstErr error
		if err := tracerProvider.Shutdown(ctx); err != nil {
			firstErr = err
		}
		if err := meterProvider.Shutdown(ctx); err != nil && firstErr == nil {
			firstErr = err
		}
		return firstErr
	}, nil
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

