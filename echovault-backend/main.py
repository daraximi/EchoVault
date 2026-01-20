#from partd.core import filename
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import shutil
from transcribe import transcribe_audio, analyze_sentiment
from DB.database import SessionLocal, Entry
from DB.database import init_db
init_db()

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


@app.post("/upload_audio")
async def upload_audio(audio: UploadFile= File(...)):
    if not audio.filename:
        return JSONResponse({
            "error": "No filename provided",
            status_code:400
        })
    file_id = str(uuid.uuid4())

    ext = os.path.splitext(audio.filename)[1] or "m4a"
    saved_name = f"{file_id}{ext}"
    save_path = os.path.join(UPLOAD_DIR, saved_name)

    with open(save_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    #AI Step 1: Transcribe Audio
    transcript = await transcribe_audio(save_path)

    #AI Step 2: Analyze Sentiment
    polarity, sentiment_label = analyze_sentiment(transcript)

    # return JSONResponse(content={
    #     "file_id": file_id,
    #     "filename": saved_name,
    #     "url": f"/uploads/{saved_name}",
    #     "transcript": transcript,
    #     "polarity": polarity,
    #     "sentiment_label": sentiment_label,
    #     "status_code": 200
    # },
    # status_code=200)

    db = SessionLocal()
    entry = Entry(
        id = file_id,
        filename = saved_name,
        transcript= transcript,
        polarity = polarity,
        sentiment_label = sentiment_label,
    )
    db.add(entry)
    print("Added to DB")
    db.commit()
    db.close()

    return JSONResponse(content={
        "file_id": file_id,
        "filename": saved_name,
        "url": f"/uploads/{saved_name}",
        "transcript": transcript,
        "polarity":round(polarity, 2),
        "sentiment_label": sentiment_label,
        "status_code": 200
    },
    status_code=200)