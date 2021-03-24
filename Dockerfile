FROM golang:1.16.0-alpine3.13 as base
RUN adduser -u 1000 -D goblocks \
  && mkdir /app \
  && chown -R goblocks:goblocks /app
WORKDIR /app
USER goblocks
COPY --chown=goblocks:goblocks ./go.mod ./go.sum ./
RUN go mod download

# stage dev
FROM base as dev
RUN go get github.com/cespare/reflex
CMD ["reflex", "-d", "none", "-c", "reflex.conf"]

# stage source
FROM base as source
COPY --chown=goblocks:goblocks . .

# stage build
FROM source as build
ENV CGO_ENABLED=0
ENV GOARCH=amd64
ENV GOOS=linux
RUN go build \
  -a -ldflags '-s -w -extldflags "-static"' \
  goblocks.go

# stage test
FROM source as test 
ENV CGO_ENABLED=0
ENV GOARCH=amd64
ENV GOOS=linux
RUN go test
CMD ["go", "test"]

# stage nancy
FROM source as nancy
ARG NANCY_VERSION=v1.0.0
RUN wget -O ./nancy \
    https://github.com/sonatype-nexus-community/nancy/releases/download/${NANCY_VERSION}/nancy-linux.amd64-${NANCY_VERSION} \
  && chmod +x ./nancy
CMD go list -json -m all | ./nancy sleuth

# stage runtime
FROM alpine:3.13 as runtime
LABEL maintainer="Carlos Remuzzi carlosremuzzi@gmail.com"
LABEL org.label-schema.description="goblocks"
LABEL org.label-schema.name="goblocks"
LABEL org.label-schema.schema-version="1.0"
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /app/goblocks /usr/bin/goblocks
USER goblocks
CMD ["goblocks"]
