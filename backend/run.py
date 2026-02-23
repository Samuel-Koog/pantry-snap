"""
Start the Pantry Plan API server on port 8000.
- On this Mac: open Swagger at http://127.0.0.1:8000/docs
- From another device on your network: use this Mac's IP, e.g. http://192.168.1.5:8000/docs
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",  # Listen on all interfaces so you can use your Mac's IP in browser or from iPhone
        port=8000,
        reload=True,
    )
