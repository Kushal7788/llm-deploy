#!/bin/bash

# Default values
DEFAULT_MODEL="deepseek-r1:70b-llama-distill-q4_K_M"
DEFAULT_API_KEY="1234"

# Parse command line arguments
MODEL_NAME=${1:-$DEFAULT_MODEL}
API_KEY=${2:-$DEFAULT_API_KEY}

check_and_install_packages() {
    echo "Checking necessary packages..."
    
    # Check if packages are already installed
    PACKAGES="python3.11 python3-venv htop iftop sysstat nvtop tmux"
    MISSING_PACKAGES=""
    
    for pkg in $PACKAGES; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done
    
    if [ ! -z "$MISSING_PACKAGES" ]; then
        echo "Installing missing packages:$MISSING_PACKAGES"
        sudo apt update
        sudo apt install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt update
        sudo apt install -y $MISSING_PACKAGES
    else
        echo "All required packages are already installed."
    fi
    
    # Check and install NVIDIA drivers if needed
    if ! command -v nvidia-smi &> /dev/null; then
        echo "Installing NVIDIA drivers..."
        sudo apt install -y nvidia-driver-525 nvidia-utils-525
        sudo apt install -y nvidia-cuda-toolkit
    fi
}

setup_virtual_environment() {
    echo "Checking Python virtual environment..."
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
        echo "Virtual environment created!"
    else
        echo "Virtual environment already exists."
    fi
    
    source venv/bin/activate
    
    # Install Python dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        echo "Installing Python packages..."
        pip install -r requirements.txt
    fi
}

optimize_system() {
    echo "Applying system optimizations..."
    # Increase system limits
    sudo sysctl -w vm.max_map_count=1048576
    sudo sysctl -w net.core.somaxconn=65535
    sudo sysctl -w net.ipv4.tcp_max_syn_backlog=8192
    
    # Optimize CPU governor
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    
    # Configure transparent hugepages
    echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
    
    # Set NVIDIA GPU settings
    sudo nvidia-smi --gpu-reset
    sudo nvidia-smi -pm 1
    sudo nvidia-smi --auto-boost-default=0
    sudo nvidia-smi -ac 5001,1590
    
    # Optimize memory allocation
    export MALLOC_TRIM_THRESHOLD_=131072
    export MALLOC_MMAP_THRESHOLD_=131072
    export GOGC=100
}

install_ollama() {
    if ! command -v ollama &> /dev/null; then
        echo "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "Ollama is already installed."
    fi
}

setup_monitoring() {
    if ! tmux has-session -t llm-chat 2>/dev/null; then
        echo "Creating tmux session..."
        # Create new tmux session with name llm-chat
        tmux new-session -d -s llm-chat -n monitoring
        
        # Split the window for monitoring
        tmux split-window -h -t llm-chat:monitoring
        tmux split-window -v -t llm-chat:monitoring
        
        # Send commands to each pane
        tmux send-keys -t llm-chat:monitoring.0 'nvidia-smi -l 1' C-m
        tmux send-keys -t llm-chat:monitoring.1 'htop' C-m
        tmux send-keys -t llm-chat:monitoring.2 'iostat -x 1' C-m
        
        # Create new window for ollama with the specified model
        tmux new-window -t llm-chat -n ollama
        tmux send-keys -t llm-chat:ollama "OLLAMA_HOST=0.0.0.0 OLLAMA_ORIGINS=\"*\" ollama serve" C-m
        
        echo "Tmux session 'llm-chat' created. Attach with: tmux attach-session -t llm-chat"
    else
        echo "Tmux session 'llm-chat' already exists."
    fi
}

start_server() {
    echo "Starting LLM Chat Server..."
    
    # Wait for Ollama to initialize
    echo "Waiting for Ollama to initialize..."
    sleep 10
    
    # Check if model is available
    if ! ollama list | grep -q "$MODEL_NAME"; then
        echo "Pulling $MODEL_NAME model... This may take a few minutes..."
        ollama pull "$MODEL_NAME"
        echo "Model pull completed!"
    fi
    
    # Start the FastAPI server with the model name and API key
    echo "Starting FastAPI server..."
    MODEL_NAME="$MODEL_NAME" API_KEY="$API_KEY" python -m uvicorn main:app \
        --host 0.0.0.0 \
        --port 8000 \
        --workers 8 \
        --loop uvloop \
        --http httptools \
        --limit-concurrency 32 \
        --backlog 2048 \
        --log-level info
}

cleanup() {
    echo "Shutting down server..."
    tmux kill-session -t llm-chat
}

show_usage() {
    echo "Usage: $0 [model_name] [api_key]"
    echo "  model_name: Name of the Ollama model to use (default: $DEFAULT_MODEL)"
    echo "  api_key: API key for authentication (default: $DEFAULT_API_KEY)"
    echo ""
    echo "Example:"
    echo "  $0 llama2:7b-chat my-secret-key"
}

main() {
    # Show parameters being used
    echo "Using model: $MODEL_NAME"
    echo "Using API key: $API_KEY"
    
    check_and_install_packages
    setup_virtual_environment
    optimize_system
    install_ollama
    setup_monitoring
    start_server
}

# Set up cleanup on script exit
trap cleanup EXIT

# Show help if --help or -h is passed
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Run main function
main
