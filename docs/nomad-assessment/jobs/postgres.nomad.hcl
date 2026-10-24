job "postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "db" {
    count = 1
    network {
      mode = "host"
      port "db" {
        static = 5432
      }
    }
    task "postgres" {
      driver = "docker"
      config {
        image        = "postgres:15-alpine"
        network_mode = "host"
        args         = ["-c", "listen_addresses=127.0.0.1", "-c", "shared_buffers=64MB", "-c", "max_connections=50"]
        volumes      = ["/opt/assessment/data/postgres:/var/lib/postgresql/data"]
      }
      template {
        data        = "{{ key \"assessment/postgres-env\" }}"
        destination = "secrets/postgres.env"
        env         = true
      }
      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
