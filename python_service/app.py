from fastapi import FastAPI, Request
from tokencost import calculate_prompt_cost, calculate_completion_cost

app = FastAPI()

@app.post("/calculate_tokens/")
async def calculate_tokens(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    model = body.get("model", "gpt-3.5-turbo")
    max_tokens = body.get("max_tokens", 0)

    if not messages:
        return {"error": "No messages provided"}

    try:
        # Calculate prompt cost
        prompt_cost = calculate_prompt_cost(messages, model=model)
        # Calculate completion cost
        completion_cost = calculate_completion_cost(max_tokens, model=model)
        # Total tokens
        total_tokens = prompt_cost.tokens + completion_cost.tokens
        return {"tokens": total_tokens}
    except Exception as e:
        return {"error": str(e)}
