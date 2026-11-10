# syntax=docker/dockerfile:1
# diyddns-client container image. Built by the container-client job in
# .github/workflows/ci-cd.yml for linux/amd64 and linux/arm64.

# Compile natively on the build platform and cross-compile via GOARCH,
# rather than running the Go toolchain under QEMU for arm64.
FROM --platform=$BUILDPLATFORM golang:1.25 AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=v0.0.0-dev
ARG COMMIT=""
ARG DATE=""

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Pure-Go build (modernc.org/sqlite), so the binary is static and needs no libc.
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath \
      -ldflags "-s -w \
        -X github.com/jacaudi/diyddns/internal/version.Version=${VERSION} \
        -X github.com/jacaudi/diyddns/internal/version.Commit=${COMMIT} \
        -X github.com/jacaudi/diyddns/internal/version.Date=${DATE}" \
      -o /out/diyddns-client ./cmd/diyddns-client \
 && mkdir -p /config

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /out/diyddns-client /diyddns-client
# Pre-create the credentials directory owned by nonroot; otherwise a volume
# mounted there is created root:root and saving credentials fails EACCES.
COPY --from=builder --chown=65532:65532 /config /home/nonroot/.config

USER 65532:65532

ENTRYPOINT ["/diyddns-client"]
CMD ["run"]
