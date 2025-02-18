# main.py
import os
import subprocess
import ssl
from typing import Optional
from fastapi import FastAPI, HTTPException, Header, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from langchain_ollama import OllamaLLM
import uvicorn

# Environment variables with defaults
MODEL_NAME = os.environ.get("MODEL_NAME", "deepseek-r1:70b-llama-distill-q4_K_M")
API_KEY = os.environ.get("API_KEY", "1234")
SSL_CERT = os.environ.get("SSL_CERT_PATH")
SSL_KEY = os.environ.get("SSL_KEY_PATH")
# Allow all hosts by default
ALLOWED_HOSTS = ["*"]  # Allow all hosts
CORS_ORIGINS = ["*"]   # Allow all origins
HTTP_PORT = int(os.environ.get("HTTP_PORT", "8000"))
HTTPS_PORT = int(os.environ.get("HTTPS_PORT", "8443"))
WORKERS = int(os.environ.get("WORKERS", "6"))
ENV = os.environ.get("ENVIRONMENT", "production")

# Initialize the LLM with the model from environment
llm = OllamaLLM(model=MODEL_NAME)

# Create the FastAPI app
app = FastAPI(
    title="LLM Chat API",
    description="Production-ready LLM Chat API with HTTP/HTTPS support",
    version="1.0.0",
    docs_url=None if ENV == "production" else "/docs",
    redoc_url=None if ENV == "production" else "/redoc"
)

# Add CORS middleware with more permissive settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Add trusted host middleware with all hosts allowed
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"]
)

# Set up the rate limiter
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

class QueryRequest(BaseModel):
    prompt: str

def verify_api_key(x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return x_api_key

@app.post("/query")
@limiter.limit("5/minute")
async def query_endpoint(
    request: Request, 
    query: QueryRequest, 
    api_key: str = Depends(verify_api_key)
):
    try:
        response = llm.invoke(query.prompt)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def health_check():
    return {
        "status": "healthy",
        "service": "llm-chat",
        "model": MODEL_NAME,
        "environment": ENV
    }

def run_server(ssl_context: Optional[ssl.SSLContext] = None, port: int = HTTP_PORT):
    """Run the server with the specified configuration"""
    uvicorn.run(
        app,
        host="0.0.0.0",  # Allow connections from all network interfaces
        port=port,
        ssl_certfile=SSL_CERT if ssl_context else None,
        ssl_keyfile=SSL_KEY if ssl_context else None,
        workers=WORKERS,
        loop="uvloop",
        http="httptools",
        limit_concurrency=32,
        backlog=2048,
        log_level="info" if ENV == "production" else "debug",
        access_log=ENV != "production",
        proxy_headers=True,
        forwarded_allow_ips="*",  # Trust forwarded IPs from all sources
    )

if __name__ == "__main__":
    # Create SSL context if certificates are provided
    ssl_context = None
    if SSL_CERT and SSL_KEY and os.path.exists(SSL_CERT) and os.path.exists(SSL_KEY):
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(SSL_CERT, SSL_KEY)
        
        # Run HTTPS server
        print(f"Starting HTTPS server on port {HTTPS_PORT}")
        run_server(ssl_context, HTTPS_PORT)
    else:
        # Run HTTP server
        print(f"Starting HTTP server on port {HTTP_PORT}")
        run_server()
