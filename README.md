# SQL Exporter for Prometheus
[![Go](https://github.com/burningalchemist/sql_exporter/workflows/Go/badge.svg)](https://github.com/burningalchemist/sql_exporter/actions?query=workflow%3AGo) [![Go Report Card](https://goreportcard.com/badge/github.com/burningalchemist/sql_exporter)](https://goreportcard.com/report/github.com/burningalchemist/sql_exporter) [![Docker Pulls](https://img.shields.io/docker/pulls/burningalchemist/sql_exporter)](https://hub.docker.com/r/burningalchemist/sql_exporter) ![Downloads](https://img.shields.io/github/downloads/burningalchemist/sql_exporter/total) [![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/sql-exporter)](https://artifacthub.io/packages/helm/sql-exporter/sql-exporter)

## Overview

SQL Exporter is a configuration driven exporter that exposes metrics gathered from DBMSs, for use by the Prometheus
monitoring system. Out of the box, it provides support for the following databases and compatible interfaces:

- MySQL
- PostgreSQL
- Microsoft SQL Server
- Clickhouse
- Snowflake
- Vertica

In fact, any DBMS for which a Go driver is available may be monitored after rebuilding the binary with the DBMS driver
included.

The collected metrics and the queries that produce them are entirely configuration defined. SQL queries are grouped into
collectors -- logical groups of queries, e.g. *query stats* or *I/O stats*, mapped to the metrics they populate.
Collectors may be DBMS-specific (e.g. *MySQL InnoDB stats*) or custom, deployment specific (e.g. *pricing data
freshness*). This means you can quickly and easily set up custom collectors to measure data quality, whatever that might
mean in your specific case.

Per the Prometheus philosophy, scrapes are synchronous (metrics are collected on every `/metrics` poll) but, in order to
keep load at reasonable levels, minimum collection intervals may optionally be set per collector, producing cached
metrics when queried more frequently than the configured interval.

## Usage

If you wished to use this version of SQL Expoter you can either download the content of the repository as a `ZIP` file or directly `clone` the repository via `git` software.

## Build

Prerequisites:
- [Go Compiler](https://go.dev/doc/install)

When the `GO` is installed on the machine, and the content of the repo is placed in your desired location (e.g.: `C:\Users\YOUR_PROFILE\Projects\sql_exporter`), then you need to run following commands:
- go mod tidy (it ensures the all required packages are downloaded)
- go build -ldflags "-s -w" -o .build\windows-amd64\ .\cmd\sql_exporter\ (this specific command is necessary, since it creates sql_expoter executable binary within `.build\windows-amd64\` directory.)

If the build is completed, then it's halfway road to an end, since the only thing left is to assign the following details to `environment variables` (it can be also retrieved from the PasswordVault via CCP):
- ![Username](https://github.com/merdzikdominik/sql_exporter/blob/master/env_examples/username_env.png)
- ![Password](https://github.com/merdzikdominik/sql_exporter/blob/master/env_examples/password_env.png)
- ![Database](https://github.com/merdzikdominik/sql_exporter/blob/master/env_examples/hostport_env.png)
- ![Hostt & Port](https://github.com/merdzikdominik/sql_exporter/blob/master/env_examples/hostport_env.png)

## Configuration

SQL Exporter is deployed alongside the DB server it collects metrics from. If both the exporter and the DB
server are on the same host, they will share the same failure domain: they will usually be either both up and running
or both down. When the database is unreachable, `/metrics` responds with HTTP code 500 Internal Server Error, causing
Prometheus to record `up=0` for that scrape. Only metrics defined by collectors are exported on the `/metrics` endpoint.
SQL Exporter process metrics are exported at `/sql_exporter_metrics`.

The configuration examples listed here only cover the core elements. For a comprehensive and comprehensively documented
configuration file check out
[`documentation/sql_exporter.yml`](https://github.com/burningalchemist/sql_exporter/tree/master/documentation/sql_exporter.yml).

**`./sql_exporter.yml`**

```yaml
# Global settings and defaults.
global:
  # Subtracted from Prometheus' scrape_timeout to give us some headroom and prevent Prometheus from
  # timing out first.
  scrape_timeout_offset: 500ms
  # Minimum interval between collector runs: by default (0s) collectors are executed on every scrape.
  min_interval: 0s
  # Maximum number of open connections to any one target. Metric queries will run concurrently on
  # multiple connections.
  max_connections: 3
  # Maximum number of idle connections to any one target.
  max_idle_connections: 3
  # Maximum amount of time a connection may be reused to any one target. Infinite by default.
  max_connection_lifetime: 10m

# The target to monitor and the list of collectors to execute on it.
target:
  # Target name (optional). Setting this field enables extra metrics e.g. `up` and `scrape_duration` with
  # the `target` label that are always returned on a scrape.
  name: "prices_db"
  # This is the main part where the change takes place, the sensitive data are pre-configured within the sql.go file so the DSN doesn't contain any of the user information
  data_source_name: 'sqlserver://'

  # Collectors (referenced by name) to execute on the target.
  # Glob patterns are supported (see <https://pkg.go.dev/path/filepath#Match> for syntax).
  collectors: [pricing_data_freshness, pricing_*]

  # In case you need to connect to a backend that only responds to a limited set of commands (e.g. pgbouncer) or
  # a data warehouse you don't want to keep online all the time (due to the extra cost), you might want to disable `ping`
  # enable_ping: true

# Collector definition files.
# Glob patterns are supported (see <https://pkg.go.dev/path/filepath#Match> for syntax).
collector_files:
  - "*.collector.yml"
```

> [!NOTE]
> The `collectors` and `collector_files` configurations support [Glob pattern matching](https://pkg.go.dev/path/filepath#Match).
To match names with literal pattern terms in them, e.g. `collector_*1*`, these must be escaped: `collector_\*1\*`.

### Collectors

Collectors may be defined inline, in the exporter configuration file, under `collectors`, or they may be defined in
separate files and referenced in the exporter configuration by name, making them easy to share and reuse.

The collector definition below generates gauge metrics of the form `pricing_update_time{market="US"}`.

**`./pricing_data_freshness.collector.yml`**

```yaml
# This collector will be referenced in the exporter configuration as `pricing_data_freshness`.
collector_name: pricing_data_freshness

# A Prometheus metric with (optional) additional labels, value and labels populated from one query.
metrics:
  - metric_name: pricing_update_time
    type: gauge
    help: 'Time when prices for a market were last updated.'
    key_labels:
      # Populated from the `market` column of each row.
      - Market
    static_labels:
      # Arbitrary key/value pair
      portfolio: income
    values: [LastUpdateTime]
    # Static metric value (optional). Useful in case we are interested in string data (key_labels) only. It's mutually
    # exclusive with `values` field.
    # static_value: 1
    # Timestamp value (optional). Should point at the existing column containing valid timestamps to return a metric
    # with an explicit timestamp.
    # timestamp_value: CreatedAt
    query: |
      SELECT Market, max(UpdateTime) AS LastUpdateTime
      FROM MarketPrices
      GROUP BY Market
```

### Data Source Names (DSN)

The main difference compared to the original config file is that the DSN doesn't contain any of the sensitive data, so it looks like this:
`sqlserver://'

This exporter relies on `xo/dburl` package for parsing Data Source Names (DSN). The goal is to have a
unified way to specify DSNs across all supported databases. This can potentially affect your connection to certain
databases like MySQL, so you might want to adjust your connection string accordingly:

Powershell:

```powershell
New-Service -name "SqlExporterSvc" `
-BinaryPathName "%SQL_EXPORTER_PATH%\sql_exporter.exe --config.file %SQL_EXPORTER_PATH%\sql_exporter.yml" `
-StartupType Automatic `
-DisplayName "Prometheus SQL Exporter"
```

CMD:

```shell
sc.exe create SqlExporterSvc binPath= "%SQL_EXPORTER_PATH%\sql_exporter.exe --config.file %SQL_EXPORTER_PATH%\sql_exporter.yml" start= auto
```

`%SQL_EXPORTER_PATH%` is a path to the SQL Exporter binary executable. This document assumes that configuration files
are in the same location.

In case you need a more sophisticated setup (e.g. with logging, environment variables, etc), you might want to use [NSSM](https://nssm.cc/) or
[WinSW](https://github.com/winsw/winsw). Please consult their documentation for more details.

</details>

<details>
<summary>TLS and Basic Authentication</summary>

SQL Exporter supports TLS and Basic Authentication. This enables better control of the various HTTP endpoints.

To use TLS and/or Basic Authentication, you need to pass a configuration file using the `--web.config.file` parameter.
The format of the file is described in the
[exporter-toolkit](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md) repository.

</details>

If you have an issue using sql_exporter, please check [Discussions](https://github.com/burningalchemist/sql_exporter/discussions) or
closed [Issues](https://github.com/burningalchemist/sql_exporter/issues?q=is%3Aissue+is%3Aclosed) first. Chances are
someone else has already encountered the same problem and there is a solution. If not, feel free to create a new
discussion.

## Why It Exists

SQL Exporter started off as an exporter for Microsoft SQL Server, for which no reliable exporters exist. But what is
the point of a configuration driven SQL exporter, if you're going to use it along with 2 more exporters with wholly
different world views and configurations, because you also have MySQL and PostgreSQL instances to monitor?

A couple of alternative database agnostic exporters are available:

- [justwatchcom/sql_exporter](https://github.com/justwatchcom/sql_exporter);
- [chop-dbhi/prometheus-sql](https://github.com/chop-dbhi/prometheus-sql).

However, they both do the collection at fixed intervals, independent of Prometheus scrapes. This is partly a
philosophical issue, but practical issues are not all that difficult to imagine:

- jitter;
- duplicate data points;
- collected but not scraped data points.

The control they provide over which labels get applied is limited, and the base label set spammy. And finally,
configurations are not easily reused without copy-pasting and editing across jobs and instances.

## Credits

This is a permanent fork of Database agnostic SQL exporter for [Prometheus](https://prometheus.io) created by
[@free](https://github.com/free/sql_exporter).

NOTE: This repo is created basing on [sqlalchemits's](https://github.com/burningalchemist/sql_exporter/tree/master) repo.
