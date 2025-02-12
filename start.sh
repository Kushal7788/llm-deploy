#!/bin/bash

echo "Starting Ollama server..."
# Start Ollama in the foreground to see logs
ollama serve &
OLLAMA_PID=$!

echo "Waiting for Ollama server to initialize..."
sleep 10

# Pull the model and wait for it to complete
echo "Pulling llama3.1 model... This may take a few minutes..."
ollama pull llama3.1
echo "Model pull completed successfully!"

echo "Starting FastAPI server..."
# Start the FastAPI server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 

# Keep the script running and maintain Ollama in background
wait $OLLAMA_PID 