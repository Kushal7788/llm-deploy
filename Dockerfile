# Dockerfile
FROM python:3.11-slim

# Install required Linux packages and curl (if needed for installing Ollama)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install Ollama CLI
RUN curl -fsSL https://ollama.com/install.sh | sh

WORKDIR /app

# Copy dependency lists and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY main.py .

# Create a startup script
COPY start.sh .
RUN chmod +x start.sh

# Expose the FastAPI port
EXPOSE 8000

# Use the startup script instead of directly running uvicorn
CMD ["./start.sh"]
