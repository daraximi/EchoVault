from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import shutil

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI(title="EchoVault API", description="EchoVault API", version="0.0.1")

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # CHANGE THIS IN PRODUCTION
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get('/health')
def health():
    return {"status": "Dara Backend Is Working"}

@app.post('/upload')
async def upload(audio: UploadFile= File(...)):
    # Basic validation
    if not audio.filename:
        return JSONResponse({
            "error": "No filename provided",
            status_code:400
        })
    file_id = str(uuid.uuid4())
    ext = os.path.splitext(audio.filename)[1] or "m4a"
    saved_name = f"{file_id}{ext}"
    save_path = os.path.join(UPLOAD_DIR, saved_name)

    with open(save_path, "wb") as f:
        shutil.copyfileobj(audio.file, f)

    return JSONResponse(content={
        "file_id": file_id,
        "filename": saved_name,
        "url": f"/uploads/{saved_name}",
        "status_code": 200
    },
    status_code=200)