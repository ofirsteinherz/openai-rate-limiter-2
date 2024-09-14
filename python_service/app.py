import logging
from fastapi import FastAPI, Request
from tokencost import calculate_prompt_cost, calculate_completion_cost

app = FastAPI()

# Configure logging to show debug messages
logging.basicConfig(level=logging.DEBUG)

@app.post("/calculate_tokens/")
async def calculate_tokens(request: Request):
    body = await request.json()
    logging.debug(f"Request body: {body}")
    
    messages = body.get("messages", [])
    model = body.get("model", "gpt-4o")
    request_type = body.get("type")  # either "prompt" or "completion"
    
    # Ensure request has a type
    if request_type not in ["prompt", "completion"]:
        logging.error("Invalid type provided. Must be 'prompt' or 'completion'")
        return {"error": "Invalid type. Must be 'prompt' or 'completion'."}
    
    if not messages:
        logging.error("No messages provided in request")
        return {"error": "No messages provided"}

    try:
        total_tokens = 0

        # Calculate cost based on type
        if request_type == "prompt":
            logging.debug(f"Calculating prompt cost for {len(messages)} messages")
            prompt_cost = calculate_prompt_cost(messages, model=model)
            logging.debug(f"Prompt cost: {prompt_cost} tokens")

        elif request_type == "completion":
            logging.debug(f"Calculating completion cost for {len(messages)} messages")
            completion_cost = calculate_completion_cost(messages, model=model)
            logging.debug(f"Completion cost: {completion_cost} tokens")

        # Log the total token usage
        total_tokens = prompt_cost + completion_cost
        logging.debug(f"Total tokens used: {total_tokens}")
        return {"tokens": total_tokens}

    except Exception as e:
        logging.error(f"Error during token calculation: {e}")
        return {"error": str(e)}