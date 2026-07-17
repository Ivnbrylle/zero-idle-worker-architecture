# Zero-Idle Worker Architecture on GCP

An event-driven, cost-effective serverless pipeline built on Google Cloud Platform (GCP). The system automatically compiles high-fidelity PDF reports in response to raw file uploads to Google Cloud Storage (GCS). By leveraging **GCP Cloud Run**, the worker service scales down to **zero instances** when there are no active processing tasks, ensuring zero active compute costs during idle periods.

---

## 🏗️ Architecture Overview

The system utilizes an asynchronous, event-driven pattern to decouple file storage from document compilation:

```mermaid
graph TD
    User([User / System]) -->|Uploads Raw File| GCS_In([Input Bucket: zero-idle-input-bucket])
    GCS_In -->|Trigger: object.v1.finalized| Eventarc[Eventarc Trigger]
    Eventarc -->|HTTP POST Payload| CloudRun[Cloud Run: pdf-worker-service]
    CloudRun -->|1. Processes Payload & Compiles PDF| LocalPDF[/tmp/generated_report.pdf]
    CloudRun -->|2. Uploads Result| GCS_Out([Output Bucket: zero-idle-output-bucket])
```

1. **Upload**: A file (like [mock_data.txt](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/mock_data.txt)) is uploaded to `zero-idle-input-bucket`.
2. **Event Trigger**: GCP **Eventarc** intercepts the `google.cloud.storage.object.v1.finalized` event and constructs a Pub/Sub message envelope containing the event metadata.
3. **Execution**: Eventarc pushes the payload via an HTTP POST request to the `pdf-worker-service` hosted on **Cloud Run**. Cloud Run instantly provisions an instance (cold-start) to process the task.
4. **Compilation**: The FastAPI container decodes the message, extracts the raw contents, compiles a PDF using **ReportLab**, and writes it locally.
5. **Storage**: The finalized PDF is pushed into `zero-idle-output-bucket` for permanent storage.
6. **Scale-to-Zero**: Once processing completes and idle timeout is reached, Cloud Run tears down the container instance, reducing active compute costs to absolute zero.

---

## 📂 Project Structure

*   [src/main.py](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/src/main.py) — The FastAPI worker application that parses Eventarc/PubSub events, compiles PDFs with ReportLab, and uploads them back to GCS.
*   [src/Dockerfile](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/src/Dockerfile) — A clean, production-grade multi-stage Dockerfile that compiles Python packages in a build layer and runs them in a minimal runner layer.
*   [src/requirements.txt](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/src/requirements.txt) — Python dependencies required by the FastAPI worker.
*   [terraform/main.tf](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/terraform/main.tf) — Declarative infrastructure code to provision Artifact Registry, Storage Buckets, Cloud Run, IAM bindings, and the Eventarc trigger.
*   [mock_data.txt](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/mock_data.txt) — Example input data payload file for testing.

---

## 🛠️ Prerequisites

To deploy and run this architecture, you need:
1. A **GCP Project** with billing enabled.
2. The **Google Cloud SDK** (`gcloud`) installed and authenticated.
3. **Docker** installed locally.
4. **Terraform** (>= 1.0) installed locally.

---

## 🚀 Deployment Guide

### Step 1: GCP Authentication & Configurations
Ensure your local `gcloud` CLI is logged in and configured to use your target GCP Project ID (e.g., `zero-idle-worker-architecture`):
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project zero-idle-worker-architecture
```

### Step 2: Configure & Enable Required GCP APIs
Enable the necessary GCP APIs for Artifact Registry, Cloud Run, Eventarc, and Pub/Sub:
```bash
gcloud services enable \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    eventarc.googleapis.com \
    pubsub.googleapis.com \
    storage.googleapis.com
```

### Step 3: Build & Push the Docker Image
1. Authenticate Docker with your region's GCP Artifact Registry:
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```
2. Build the multi-stage Docker container locally:
   ```bash
   docker build -t us-central1-docker.pkg.dev/zero-idle-worker-architecture/worker-repo/worker-image:v2 ./src
   ```
3. Push the image to your Artifact Registry:
   ```bash
   docker push us-central1-docker.pkg.dev/zero-idle-worker-architecture/worker-repo/worker-image:v2
   ```

> [!NOTE]
> Ensure that the project ID in your Docker tag matches the project configured in your [terraform/main.tf](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/terraform/main.tf) configuration.

### Step 4: Provision Infrastructure with Terraform
Navigate to the `terraform` directory, initialize the providers, and apply the configuration:
```bash
cd terraform
terraform init
terraform apply
```
Terraform will automatically set up the Input and Output storage buckets, create the Artifact Registry repo configuration, deploy the Cloud Run service, and configure Eventarc to orchestrate the pipeline.

---

## 🧪 Testing the Architecture

To verify that the end-to-end event-driven loop works correctly:

1. Upload the provided [mock_data.txt](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/mock_data.txt) to the input bucket:
   ```bash
   gcloud storage cp mock_data.txt gs://zero-idle-input-bucket/mock_data.txt
   ```
2. Monitor the Cloud Run logs to observe the worker spinning up and processing the event:
   ```bash
   gcloud beta run services logs tail pdf-worker-service --project zero-idle-worker-architecture --region us-central1
   ```
3. Inspect your output bucket to verify the compiled PDF was successfully written:
   ```bash
   gcloud storage ls gs://zero-idle-output-bucket/reports/
   ```

---

## 💻 Local Development & Mocking

For fast iteration cycles, you can run the FastAPI application locally and simulate Eventarc/PubSub push notifications.

### 1. Local Run
Install the dependencies from [src/requirements.txt](file:///C:/Users/rempi/OneDrive/Desktop/zero-idle-worker-architecture/src/requirements.txt) and start the Uvicorn server:
```bash
pip install -r src/requirements.txt
python src/main.py
```
By default, the server runs on port `8080`.

### 2. Mocking an Eventarc Event
You can send a mock POST request simulating Eventarc's webhook envelope using `curl`:
```bash
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "SW52b2ljZSBEYXRhOiBVc2VyIElEIDk5NDIsIEFtb3VudCAxNTAwLCBJdGVtczogQ2xvdWQgQ29uc3VsdGluZywgU3RhdHVzOiBQYWlk"
    }
  }'
```
*(The data string above is base64-encoded text: `"Invoice Data: User ID 9942, Amount 1500, Items: Cloud Consulting, Status: Paid"`)*.