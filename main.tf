terraform {
  cloud {
    organization = "ferronn-dev"
    workspaces {
      name = "www"
    }
  }
}

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

resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "terraform"
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
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
      template[0].metadata[0].labels,
      template[0].spec[0].containers[0].image,
    ]
  }
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
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
      "serviceAccount:715563492971@cloudbuild.gserviceaccount.com",
    ]
    role = "roles/cloudbuild.builds.builder"
  }
  binding {
    members = [
      "serviceAccount:service-715563492971@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
    role = "roles/cloudbuild.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/editor"
  }
  binding {
    members = [
      "serviceAccount:715563492971@cloudbuild.gserviceaccount.com",
    ]
    role = "roles/iam.serviceAccountUser"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/iam.securityAdmin"
  }
  binding {
    members = [
      "serviceAccount:715563492971@cloudbuild.gserviceaccount.com",
    ]
    role = "roles/run.admin"
  }
  binding {
    members = [
      "serviceAccount:service-715563492971@serverless-robot-prod.iam.gserviceaccount.com",
    ]
    role = "roles/run.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/storage.admin"
  }
}

resource "google_project_iam_policy" "project" {
  project     = local.project
  policy_data = data.google_iam_policy.project.policy_data
}

resource "google_project_default_service_accounts" "project" {
  project = local.project
  action  = "DISABLE"
}
