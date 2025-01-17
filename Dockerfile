ARG  ARCH="amd64"
ARG  OS="linux"
FROM quay.io/prometheus/golang-builder AS builder

ADD .   /go/src/github.com/merdzikdominik/sql_exporter
WORKDIR /go/src/github.com/merdzikdominik/sql_exporter

RUN make

FROM        quay.io/prometheus/busybox-${OS}-${ARCH}:latest
LABEL       maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
COPY        --from=builder /go/src/github.com/merdzik/sql_exporter/sql_exporter  /bin/sql_exporter

EXPOSE      9399
USER        nobody
ENTRYPOINT  [ "/bin/sql_exporter" ]
