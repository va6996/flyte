ARG FLYTE_CONSOLE_VERSION="latest"
FROM ghcr.io/flyteorg/flyteconsole-release:${FLYTE_CONSOLE_VERSION} AS flyteconsole


FROM --platform=${BUILDPLATFORM} golang:1.19.1-bullseye AS flytebuilder

ARG TARGETARCH
ENV GOARCH=${TARGETARCH}
ENV GOOS=linux

WORKDIR /flyteorg/build
COPY go.mod go.sum ./
RUN go mod download
COPY cmd cmd
COPY --from=flyteconsole /app/dist cmd/single/dist
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/root/go/pkg/mod \
    go build -tags console -v -o dist/flyte cmd/main.go


FROM debian:bullseye-slim

ARG FLYTE_VERSION=""

ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV DEBIAN_FRONTEND noninteractive
ENV FLYTE_VERSION=${FLYTE_VERSION}

# Install core packages
RUN apt-get update && apt-get install --no-install-recommends --yes \
        ca-certificates \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled executable into image
COPY --from=flytebuilder /flyteorg/build/dist/flyte /usr/local/bin/

# Set entrypoint
ENTRYPOINT [ "/usr/bin/tini", "-g", "--", "/usr/local/bin/flyte" ]