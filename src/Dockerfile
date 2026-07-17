# --- Stage 1: Build & Compile Dependencies ---
FROM python:3.11-slim AS builder

WORKDIR /app

# Install system utilities needed to build certain Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Install packages into a local wheel directory to keep final image clean
RUN pip install --no-cache-dir --user -r requirements.txt


# --- Stage 2: Final Lean Runtime Image ---
FROM python:3.11-slim AS runner

WORKDIR /app

# Copy only the installed Python libraries from the builder stage
COPY --from=builder /root/.local /root/.local
COPY main.py .

# Ensure the system can see our copied python packages
ENV PATH=/root/.local/bin:$PATH
# Prevent Python from writing annoying .pyc files to disk
ENV PYTHONDONTWRITEBYTECODE=1
# Force stdout logging so errors appear immediately in cloud consoles
ENV PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["python", "main.py"]