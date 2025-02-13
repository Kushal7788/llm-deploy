#!/bin/bash

echo "Installing necessary packages..."
# Update package list
sudo apt update

# Install Python, pip, and other necessary tools
sudo apt install -y python3.11 python3.11-venv python3-pip htop iftop sysstat nvtop tmux

# Install NVIDIA drivers and CUDA toolkit if not already installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "Installing NVIDIA drivers..."
    sudo apt install -y nvidia-driver-525 nvidia-utils-525
    sudo apt install -y nvidia-cuda-toolkit
fi

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3.11 -m venv venv
    echo "Virtual environment created!"
fi

source venv/bin/activate

# Install Python dependencies
echo "Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Setting system optimizations..."
# Increase system limits
sudo sysctl -w vm.max_map_count=1048576
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=8192

# Optimize CPU governor
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Configure transparent hugepages for better memory performance
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# Set NVIDIA GPU to maximum performance mode
sudo nvidia-smi --gpu-reset
sudo nvidia-smi -pm 1  # Enable persistent mode
sudo nvidia-smi --auto-boost-default=0  # Disable auto boost
sudo nvidia-smi -ac 5001,1590  # Set max memory and graphics clocks

# Optimize memory allocation
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_MMAP_THRESHOLD_=131072
export GOGC=100

# Install Ollama if not already installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Start monitoring in new tmux sessions
if command -v tmux &> /dev/null; then
    # Create a new tmux session
    tmux new-session -d -s monitoring

    # Create and split windows for monitoring
    tmux split-window -h
    tmux split-window -v
    
    # Send commands to each pane
    tmux send-keys -t 0 'nvidia-smi -l 1' C-m  # GPU monitoring
    tmux send-keys -t 1 'htop' C-m             # CPU and memory monitoring
    tmux send-keys -t 2 'iostat -x 1' C-m      # I/O monitoring

    echo "Monitoring started in tmux session. Attach with: tmux attach-session -t monitoring"
fi

# Start Ollama with optimized settings
echo "Starting Ollama service..."
OLLAMA_HOST=0.0.0.0 OLLAMA_ORIGINS="*" ollama serve &

sleep 10

# Pull model with optimized settings
echo "Pulling llama3.1 model..."
ollama pull llama3.1

