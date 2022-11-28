locals {
  project = "www-ferronn-dev"
  region  = "us-central1"
  zone    = "us-central1-c"
}

provider "google" {
  project = local.project
  region  = local.region
  zone    = local.zone
}

resource "google_storage_bucket" "static" {
  name                        = "static.ferronn.dev"
  location                    = "US"
  uniform_bucket_level_access = true
}

data "google_iam_policy" "storage-static" {
  binding {
    role    = "roles/storage.objectViewer"
    members = ["allUsers"]
  }
}

resource "google_storage_bucket_iam_policy" "static" {
  bucket      = google_storage_bucket.static.name
  policy_data = data.google_iam_policy.storage-static.policy_data
}

resource "google_container_registry" "registry" {
  project = local.project
}

data "google_iam_policy" "registry" {}

resource "google_storage_bucket_iam_policy" "registry" {
  bucket      = google_container_registry.registry.id
  policy_data = data.google_iam_policy.registry.policy_data
}

data "google_container_registry_image" "nginx" {
  name = "nginx"
}

resource "google_service_account" "nginx-runner" {
  account_id   = "nginx-runner"
  display_name = "nginx-runner"
}

resource "google_cloud_run_service" "nginx" {
  name     = "nginx"
  location = local.region
  lifecycle {
    ignore_changes = [
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
        "client.knative.dev/user-image"    = data.google_container_registry_image.nginx.image_url
      }
    }
    spec {
      container_concurrency = 80
      service_account_name  = google_service_account.nginx-runner.email
      timeout_seconds       = 300
      containers {
        args    = []
        command = []
        image   = data.google_container_registry_image.nginx.image_url
        ports {
          container_port = 8080
          name           = "http1"
        }
        resources {
          limits = {
            "cpu"    = "1000m"
            "memory" = "256Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloud_run_domain_mapping" "nginx" {
  name     = "ferronn.dev"
  location = local.region
  metadata {
    namespace = local.project
  }
  spec {
    route_name = google_cloud_run_service.nginx.name
  }
}

data "google_iam_policy" "run-nginx" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "nginx" {
  policy_data = data.google_iam_policy.run-nginx.policy_data
  service     = google_cloud_run_service.nginx.name
}

data "google_iam_policy" "project" {
  binding {
    members = [
      "serviceAccount:service-715563492971@serverless-robot-prod.iam.gserviceaccount.com",
    ]
    role = "roles/run.serviceAgent"
  }
}

resource "google_project_iam_policy" "project" {
  project     = local.project
  policy_data = data.google_iam_policy.project.policy_data
}
