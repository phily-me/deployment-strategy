#!/usr/bin/env python3
"""
Main entry point for the hello service.
Used by the Dockerfile and can be run directly for development.
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "src.hello_svc.asgi:application",
        host="0.0.0.0",  # noqa: S104
        port=8000,
        reload=False,
    )
