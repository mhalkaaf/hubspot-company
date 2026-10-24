variable "image" {
  type = string
}

job "hubspot" {
  datacenters = ["dc1"]
  type        = "service"

  group "api" {
    count = 1
    network {
      mode = "host"
      port "http" {
        static = 5104
      }
    }
    task "app" {
      driver         = "docker"
      shutdown_delay = "5s"
      config {
        image        = var.image
        network_mode = "host"
        command      = "gunicorn"
        args         = ["--bind", "0.0.0.0:5104", "--workers", "1", "--threads", "2", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
        labels = {
          "assessment.logs" = "true"
          "service"         = "hubspot"
        }
      }
      env {
        FLASK_ENV          = "staging"
        ENVIRONMENT        = "staging"
        MAX_WORKER_THREADS = "2"
        THREAD_POOL_SIZE   = "4"
      }
      template {
        data        = "{{ key \"assessment/app-env\" }}"
        destination = "secrets/app.env"
        env         = true
      }
      service {
        provider = "consul"
        name     = "hubspot"
        port     = "http"
        tags     = ["prometheus"]
        check {
          name     = "ready"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }
      resources {
        cpu    = 400
        memory = 512
      }
      logs {
        max_files     = 2
        max_file_size = 5
      }
    }
  }
}
