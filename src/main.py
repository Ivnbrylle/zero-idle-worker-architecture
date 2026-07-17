import os
import base64
from fastapi import FastAPI, Request
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from google.cloud import storage

app = FastAPI()

def upload_to_bucket(local_file_path, destination_blob_name):
    """Uploads a local file straight into the permanent storage bucket."""
    bucket_name = "zero-idle-output-bucket"
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(local_file_path)
    print(f"📦 Cloud Storage Link secured: gs://{bucket_name}/{destination_blob_name}")

@app.post("/")
async def process_task(request: Request):
    try:
        envelope = await request.json()
        message_data = "Default System Report Summary"
        
        # Parse out the data string sent from the event trigger
        if "message" in envelope and "data" in envelope["message"]:
            message_data = base64.b64decode(envelope["message"]["data"]).decode("utf-8")
        
        print(f"🚀 Processing Task Triggered By: {message_data}")

        # 1. Compile the high-fidelity PDF locally inside the worker instance
        pdf_path = "/tmp/generated_report.pdf"
        doc = SimpleDocTemplate(pdf_path, pagesize=letter)
        styles = getSampleStyleSheet()
        
        story = [
            Paragraph("<b>Zero-Idle Architecture Report</b>", styles["Title"]),
            Spacer(1, 20),
            Paragraph(f"<b>Payload Extracted:</b> {message_data}", styles["BodyText"]),
            Spacer(1, 10),
            Paragraph("This document was compiled asynchronously inside an isolated Docker container powered by GCP Cloud Run.", styles["BodyText"])
        ]
        doc.build(story)
        print(f"✅ PDF Successfully compiled locally inside container.")

        # 2. Push the completed product directly to your permanent output storage bucket
        cloud_filename = f"reports/generated_report_{os.environ.get('K_REVISION', 'local')}.pdf"
        upload_to_bucket(pdf_path, cloud_filename)

        return {"status": "success", "message": "Document compiled and stored permanently."}

    except Exception as e:
        print(f"❌ Error during processing: {str(e)}")
        return {"status": "error", "message": str(e)}, 500

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)