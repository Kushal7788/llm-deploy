#!/bin/bash

# System optimizations
echo "Setting system optimizations..."

# Increase system limits
sudo sysctl -w vm.max_map_count=1048576
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=8192

# Optimize CPU governor
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Configure transparent hugepages for better memory performance
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# Set GPU power mode to maximum performance (for AMD GPU)
sudo rocm-smi --setperflevel high
sudo rocm-smi --setfan 255

# Optimize memory allocation
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_MMAP_THRESHOLD_=131072
export GOGC=100

# Start Ollama with optimized settings
echo "Starting Ollama service..."
OLLAMA_HOST=0.0.0.0 OLLAMA_ORIGINS="*" ollama serve &

sleep 10

# Pull model with optimized settings
echo "Pulling model..."
ollama pull llama3.1

# Start the FastAPI server with proper worker configuration
echo "Starting FastAPI server..."
source venv/bin/activate  # Assuming you're using a virtual environment
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --loop uvloop --http httptools --limit-concurrency 32 --backlog 2048
