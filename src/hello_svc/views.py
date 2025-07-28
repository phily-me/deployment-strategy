from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/info")
async def info():
    return {
        "service": "hello-svc",
        "version": "0.1.0",
        "description": "Hello World service with deployment strategy",
    }
