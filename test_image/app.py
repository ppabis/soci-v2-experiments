from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import os
import requests


app = FastAPI()
templates = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))


def _fetch_json(url: str):
    try:
        response = requests.get(url, timeout=2)
        response.raise_for_status()
        return response.json()
    except Exception as exc:  # broad but safe for surfacing error to UI
        return {"error": str(exc)}


@app.get("/", response_class=HTMLResponse)
async def read_metadata(request: Request):
    metadata_uri = os.getenv("ECS_CONTAINER_METADATA_URI_V4")
    execution_env = os.getenv("AWS_EXECUTION_ENV")

    container_metadata = {}
    task_metadata = {}

    if metadata_uri:
        base_uri = metadata_uri.rstrip("/")
        container_metadata = _fetch_json(base_uri) or {}
        task_metadata = _fetch_json(f"{base_uri}/task") or {}
    else:
        container_metadata = {"warning": "ECS_CONTAINER_METADATA_URI_V4 is not set in the environment."}

    return templates.TemplateResponse(
        "metadata.html",
        {
            "request": request,
            "execution_env": execution_env,
            "container_metadata": container_metadata,
            "task_metadata": task_metadata,
        },
    )


if __name__ == "__main__":
    # For local runs
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)


