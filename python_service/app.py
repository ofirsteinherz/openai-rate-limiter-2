import logging
from fastapi import FastAPI, Request
import tiktoken

app = FastAPI()

# Configure logging to show debug messages
logging.basicConfig(level=logging.DEBUG)

# Load the tokenizer once during app startup
encoding = tiktoken.get_encoding("cl100k_base")

@app.post("/calculate_tokens/")
async def calculate_tokens(request: Request):
    body = await request.json()
    logging.debug(f"Request body: {body}")
    
    messages = body.get("messages", [])
    
    if not messages:
        logging.error("No messages provided in request")
        return {"error": "No messages provided"}

    try:
        # Calculate total tokens for all messages
        total_tokens = sum(len(encoding.encode(message)) for message in messages)

        logging.debug(f"Total tokens used: {total_tokens}")
        return {"tokens": total_tokens}

    except Exception as e:
        logging.error(f"Error during token calculation: {e}")
        return {"error": str(e)}