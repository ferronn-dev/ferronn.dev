provider "google" {
  project = "www-ferronn-dev"
  region  = "us-central1"
  zone    = "us-central1-c"
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

resource "google_cloud_run_service" "nginx" {
  name     = "nginx"
  location = "us-central1"
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"  = "100"
        "client.knative.dev/user-image"     = "gcr.io/www-ferronn-dev/nginx"
        "run.googleapis.com/client-name"    = "gcloud"
        "run.googleapis.com/client-version" = "321.0.0"
        "run.googleapis.com/sandbox"        = "gvisor"
      }
    }
    spec {
      container_concurrency = 80
      timeout_seconds       = 300
      containers {
        args    = []
        command = []
        image   = "gcr.io/www-ferronn-dev/nginx"
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
