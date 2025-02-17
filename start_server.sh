#!/bin/bash

echo "Starting LLM Chat Server..."

# Check if virtual environment exists and activate it
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "Virtual environment not found. Please run setup first."
    exit 1
fi

# Check if Ollama is running, if not start it
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama service..."
    OLLAMA_HOST=0.0.0.0 OLLAMA_ORIGINS="*" ollama serve &
    echo "Waiting for Ollama to initialize..."
    sleep 10
fi

# # Check if model is available, if not pull it for llama3.3:70b-instruct-q3_K_M
# if ! ollama list | grep -q "llama3.3:70b-instruct-q3_K_M"; then
#     echo "Pulling llama3.3:70b-instruct-q3_K_M model... This may take a few minutes..."
#     ollama pull llama3.3:70b-instruct-q3_K_M
#     echo "Model pull completed!"
# fi

# Check if model is available, if not pull it for deepseek-r1:70b-llama-distill-q4_K_M
if ! ollama list | grep -q "deepseek-r1:70b-llama-distill-q4_K_M"; then
    echo "Pulling deepseek-r1:70b-llama-distill-q4_K_M model... This may take a few minutes..."
    ollama pull deepseek-r1:70b-llama-distill-q4_K_M
    echo "Model pull completed!"
fi

# Start monitoring in tmux if it's not already running
if ! tmux has-session -t monitoring 2>/dev/null; then
    echo "Starting monitoring session..."
    tmux new-session -d -s monitoring
    tmux split-window -h
    tmux split-window -v
    
    # Send commands to each pane
    tmux send-keys -t 0 'nvidia-smi -l 1' C-m
    tmux send-keys -t 1 'htop' C-m
    tmux send-keys -t 2 'nvidia-smi -l 1' C-m
    
    echo "Monitoring started in tmux session. Attach with: tmux attach-session -t monitoring"
fi

# Start the FastAPI server
echo "Starting FastAPI server..."
python -m uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 8 \
    --loop uvloop \
    --http httptools \
    --limit-concurrency 32 \
    --backlog 2048 \
    --log-level info

# If the server stops, cleanup background processes
cleanup() {
    echo "Shutting down server..."
    pkill -f ollama
    tmux kill-session -t monitoring
}

# Set up cleanup on script exit
trap cleanup EXIT 