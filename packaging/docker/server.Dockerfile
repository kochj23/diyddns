# syntax=docker/dockerfile:1
# diyddns-server container image. Built by the container-server job in
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
      -o /out/diyddns-server ./cmd/diyddns-server \
 && mkdir -p /data

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /out/diyddns-server /diyddns-server
# The runtime image has no shell, so the /data volume mount point is created
# in the builder and copied in owned by the nonroot user (store.Open does
# not create its parent directory).
COPY --from=builder --chown=65532:65532 /data /data

USER 65532:65532

EXPOSE 8080
ENTRYPOINT ["/diyddns-server"]
CMD ["serve"]
