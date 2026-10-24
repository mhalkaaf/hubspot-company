variable "image" { type = string }

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"
  group "web" {
    count = 1
    network {
      mode = "host"
      port "http" {
        static = 8080
        to     = 80
      }
    }
    task "nginx" {
      driver         = "docker"
      shutdown_delay = "5s"
      config {
        image = var.image
        ports = ["http"]
        // Docker bridge networking: host 8080 forwards to container 80.
      }
      service {
        provider = "consul"
        name     = "nginx-app"
        port     = "http"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
