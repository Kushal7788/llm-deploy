# Dockerfile
FROM python:3.11-slim

# Install required Linux packages and curl (if needed for installing Ollama)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# (Optional) Install Ollama CLI.
# Replace the URL and installation commands below with the official instructions.
RUN curl -fsSL https://ollama.com/install.sh | sh
RUN ollama serve
RUN ollama pull llama3.1

WORKDIR /app

# Copy dependency lists and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY main.py .



# Expose the FastAPI port
EXPOSE 8000

# Start the server using python -m uvicorn to ensure uvicorn is found.
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
