# Build stage - Compilation
FROM golang:1.21-alpine AS builder

# Sécurité : utilisateur non-root
RUN adduser -D -s /bin/sh -u 1001 appuser

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o secure-app .

# Runtime stage - Image distroless
FROM gcr.io/distroless/static:nonroot

# Métadonnées de sécurité
LABEL maintainer="DevSecOps Team"
LABEL security.scan="required"
LABEL security.signature="cosign"

# Copie du binaire depuis le builder
COPY --from=builder /app/secure-app /secure-app

# Utilisateur non-root
USER 65532:65532

# Port non-privilégié
EXPOSE 8080

# Point d'entrée sécurisé
ENTRYPOINT ["/secure-app"]