variable "prometheus_image" { type = string }
variable "grafana_image" { type = string }
variable "loki_image" { type = string }
variable "alloy_image" { type = string }
variable "node_image" { type = string }
variable "consul_exporter_image" { type = string }

job "monitoring" {
  datacenters = ["dc1"]
  type        = "service"

  group "tools" {
    count = 1
    network {
      mode = "host"
      port "prometheus" { static = 9090 }
      port "grafana" { static = 3000 }
      port "loki" { static = 3100 }
      port "alloy" { static = 12345 }
      port "node" { static = 9100 }
      port "consul_exporter" { static = 9107 }
    }

    task "prometheus" {
      driver = "docker"
      config {
        image        = var.prometheus_image
        network_mode = "host"
        args         = ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus", "--storage.tsdb.retention.time=6h", "--storage.tsdb.retention.size=300MB", "--web.listen-address=127.0.0.1:9090"]
        volumes      = ["/opt/assessment/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro", "/opt/assessment/data/prometheus:/prometheus"]
      }
      resources {
        cpu    = 200
        memory = 512
      }
    }

    task "grafana" {
      driver = "docker"
      config {
        image        = var.grafana_image
        network_mode = "host"
        volumes      = ["/opt/assessment/config/datasources.yml:/etc/grafana/provisioning/datasources/assessment.yml:ro", "/opt/assessment/data/grafana:/var/lib/grafana"]
      }
      env {
        GF_SERVER_HTTP_ADDR            = "127.0.0.1"
        GF_ANALYTICS_REPORTING_ENABLED = "false"
      }
      resources {
        cpu    = 150
        memory = 256
      }
    }

    task "loki" {
      driver = "docker"
      config {
        image        = var.loki_image
        network_mode = "host"
        args         = ["-config.file=/etc/loki/assessment.yml"]
        volumes      = ["/opt/assessment/config/loki.yml:/etc/loki/assessment.yml:ro", "/opt/assessment/data/loki:/loki"]
      }
      resources {
        cpu    = 200
        memory = 512
      }
    }

    task "alloy" {
      driver = "docker"
      user   = "0"
      config {
        image        = var.alloy_image
        network_mode = "host"
        args         = ["run", "--server.http.listen-addr=127.0.0.1:12345", "--storage.path=/var/lib/alloy", "/etc/alloy/config.alloy"]
        volumes      = ["/opt/assessment/config/config.alloy:/etc/alloy/config.alloy:ro", "/opt/assessment/data/alloy:/var/lib/alloy", "/var/run/docker.sock:/var/run/docker.sock:ro"]
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "node-exporter" {
      driver = "docker"
      config {
        image        = var.node_image
        network_mode = "host"
        pid_mode     = "host"
        args         = ["--path.rootfs=/host", "--web.listen-address=127.0.0.1:9100"]
        volumes      = ["/:/host:ro,rslave"]
      }
      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "consul-exporter" {
      driver = "docker"
      config {
        image        = var.consul_exporter_image
        network_mode = "host"
        args         = ["--consul.server=127.0.0.1:8500", "--web.listen-address=127.0.0.1:9107"]
      }
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
