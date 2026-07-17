terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "zero-idle-worker-architecture"
  region  = "us-central1"
}

# 1. Inbound Storage Bucket (Raw Materials)
resource "google_storage_bucket" "input_bucket" {
  name          = "zero-idle-input-bucket"
  location      = "US" # Multi-region matching our working trigger setup
  force_destroy = true

  uniform_bucket_level_access = true
}

# 2. Outbound Storage Bucket (Finished Goods)
resource "google_storage_bucket" "output_bucket" {
  name          = "zero-idle-output-bucket"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

# 3. Private Artifact Registry Repository
resource "google_artifact_registry_repository" "worker_repo" {
  location      = "us-central1"
  repository_id = "worker-repo"
  description   = "Docker repository for zero-idle workers"
  format        = "DOCKER"
}

# 4. Cloud Run Worker Service (Configured to Scale to Zero)
resource "google_cloud_run_v2_service" "pdf_worker" {
  name     = "pdf-worker-service"
  location = "us-central1"

  template {
    scaling {
      min_instance_count = 0 # Scale to Zero!
      max_instance_count = 5
    }
    containers {
      image = "us-central1-docker.pkg.dev/zero-idle-worker-architecture/worker-repo/worker-image:v2"
      ports {
        container_port = 8080
      }
    }
  }
}

# Allow unauthenticated invocations so Eventarc can securely call the endpoint
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.pdf_worker.location
  service  = google_cloud_run_v2_service.pdf_worker.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# 5. Eventarc Conveyor Trigger
resource "google_eventarc_trigger" "pdf_trigger" {
  name     = "pdf-automation-trigger"
  location = "us" 

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.input_bucket.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.pdf_worker.name
      region  = google_cloud_run_v2_service.pdf_worker.location
    }
  }

  service_account = "38997368175-compute@developer.gserviceaccount.com"

  depends_on = [google_storage_bucket.input_bucket]
}