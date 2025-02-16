# main.py
import os
import subprocess
from fastapi import FastAPI, HTTPException, Header, Depends, Request
from pydantic import BaseModel

# For rate limiting
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from langchain_ollama import OllamaLLM
import uvicorn


# Model: llama3.3:70b-instruct-q3_K_M
# llm = OllamaLLM(model="llama3.3:70b-instruct-q3_K_M")

# Model: deepseek-r1:70b-llama-distill-q4_K_M
llm = OllamaLLM(model="deepseek-r1:70b-llama-distill-q4_K_M")

# Define the API key (it can be overridden by an environment variable)
API_KEY = os.environ.get("API_KEY", "1234")

# Create the FastAPI app
app = FastAPI()

# Set up the rate limiter: here we use the remote address (IP) as the key.
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# Attach the rate limit error handler
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Define a simple pydantic model for the input request
class QueryRequest(BaseModel):
    prompt: str

# Dependency to verify API key from the header
def verify_api_key(x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return x_api_key

# The endpoint is rate-limited to 5 requests per minute per client IP
@app.post("/query")
@limiter.limit("5/minute")
async def query_endpoint(request: Request, query: QueryRequest, 
                         api_key: str = Depends(verify_api_key)):
    prompt = query.prompt
    try:
        # Call Ollama to run the Llama 3.1 7B model with the provided prompt.
        # The following command assumes that the Ollama CLI is installed and available in the PATH.
        # Adjust the command and its arguments if necessary.
        response = llm.invoke(prompt)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Add health check endpoint at root path
@app.get("/")
async def health_check():
    return {"status": "healthy", "service": "llm-chat"}

# Increase the worker count for FastAPI
worker_count = 6  # Leave 2 cores for model inference

if __name__ == "__main__":
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        workers=worker_count,
        loop="uvloop",        # Faster event loop
        http="httptools",     # Faster HTTP
        limit_concurrency=32, # Balanced for long-context processing
        backlog=8192          # Large connection queue
    )
