from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import shutil
import logging
from transcribe import transcribe_audio, analyze_sentiment
from DB.database import SessionLocal, Entry
from DB.database import init_db

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize database
try:
    init_db()
    logger.info("Database initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize database: {e}")
    raise

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# File validation constants
ALLOWED_AUDIO_EXTENSIONS = {'.m4a', '.mp3', '.wav', '.flac', '.ogg', '.aac', '.wma', '.mp4', '.mpeg', '.mpga', '.webm'}
MAX_FILE_SIZE_MB = 25  # OpenAI Whisper limit is 25MB
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

app = FastAPI(title="EchoVault API", description="EchoVault API", version="0.0.1")

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # CHANGE THIS IN PRODUCTION
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get('/health')
def health():
    return {"status": "Dara Backend Is Working"}


def validate_audio_file(audio: UploadFile) -> tuple[bool, str]:
    """Validate audio file type and size. Returns (is_valid, error_message)"""
    # Check filename
    if not audio.filename:
        return False, "No filename provided"
    
    # Check file extension
    ext = os.path.splitext(audio.filename)[1].lower()
    if ext not in ALLOWED_AUDIO_EXTENSIONS:
        return False, f"Invalid file type. Only audio files are allowed: {', '.join(ALLOWED_AUDIO_EXTENSIONS)}"
    
    # Check file size (if available)
    if hasattr(audio, 'size') and audio.size:
        if audio.size > MAX_FILE_SIZE_BYTES:
            return False, f"File size exceeds maximum limit of {MAX_FILE_SIZE_MB}MB"
    
    return True, ""


@app.post('/upload')
async def upload(audio: UploadFile = File(...)):
    """Simple file upload endpoint without AI processing"""
    try:
        # Validate file
        is_valid, error_msg = validate_audio_file(audio)
        if not is_valid:
            return JSONResponse(
                content={"error": error_msg},
                status_code=400
            )
        
        # Generate unique filename
        file_id = str(uuid.uuid4())
        ext = os.path.splitext(audio.filename)[1].lower() or ".m4a"
        saved_name = f"{file_id}{ext}"
        save_path = os.path.join(UPLOAD_DIR, saved_name)

        # Save file with error handling
        try:
            with open(save_path, "wb") as f:
                shutil.copyfileobj(audio.file, f)
            logger.info(f"File uploaded successfully: {saved_name}")
        except IOError as e:
            logger.error(f"Failed to save file {saved_name}: {e}")
            return JSONResponse(
                content={"error": "Failed to save uploaded file"},
                status_code=500
            )

        return JSONResponse(
            content={
                "file_id": file_id,
                "filename": saved_name,
                "url": f"/uploads/{saved_name}",
            },
            status_code=200
        )
    
    except Exception as e:
        logger.error(f"Unexpected error in upload endpoint: {e}")
        return JSONResponse(
            content={"error": "An unexpected error occurred during file upload"},
            status_code=500
        )


@app.post("/upload_audio")
async def upload_audio(audio: UploadFile = File(...)):
    """Upload audio file with AI transcription and sentiment analysis"""
    db = None
    save_path = None
    
    try:
        # Validate file
        is_valid, error_msg = validate_audio_file(audio)
        if not is_valid:
            return JSONResponse(
                content={"error": error_msg},
                status_code=400
            )
        
        # Generate unique filename
        file_id = str(uuid.uuid4())
        ext = os.path.splitext(audio.filename)[1].lower() or ".m4a"
        saved_name = f"{file_id}{ext}"
        save_path = os.path.join(UPLOAD_DIR, saved_name)

        # Save file with error handling
        try:
            with open(save_path, "wb") as buffer:
                shutil.copyfileobj(audio.file, buffer)
            logger.info(f"Audio file saved: {saved_name}")
        except IOError as e:
            logger.error(f"Failed to save audio file {saved_name}: {e}")
            return JSONResponse(
                content={"error": "Failed to save uploaded file"},
                status_code=500
            )

        # AI Step 1: Transcribe Audio
        try:
            transcript = await transcribe_audio(save_path)
            logger.info(f"Audio transcribed successfully: {file_id}")
        except Exception as e:
            logger.error(f"Transcription failed for {saved_name}: {e}")
            # Clean up the uploaded file
            if os.path.exists(save_path):
                os.remove(save_path)
            return JSONResponse(
                content={"error": "Audio transcription failed. Please ensure the file is a valid audio file."},
                status_code=500
            )

        # AI Step 2: Analyze Sentiment
        try:
            polarity, sentiment_label = analyze_sentiment(transcript)
            logger.info(f"Sentiment analyzed: {sentiment_label} ({polarity})")
        except Exception as e:
            logger.error(f"Sentiment analysis failed for {file_id}: {e}")
            return JSONResponse(
                content={"error": "Sentiment analysis failed"},
                status_code=500
            )

        # Save to Database with proper session management
        try:
            db = SessionLocal()
            entry = Entry(
                id=file_id,
                filename=saved_name,
                transcript=transcript,
                polarity=polarity,
                sentiment_label=sentiment_label,
            )
            db.add(entry)
            db.commit()
            logger.info(f"Entry saved to database: {file_id}")
        except Exception as e:
            logger.error(f"Database operation failed for {file_id}: {e}")
            if db:
                db.rollback()
            return JSONResponse(
                content={"error": "Database operation failed"},
                status_code=500
            )
        finally:
            if db:
                db.close()

        # Return Response to client frontend
        return JSONResponse(
            content={
                "file_id": file_id,
                "filename": saved_name,
                "url": f"/uploads/{saved_name}",
                "transcript": transcript,
                "polarity": round(polarity, 2),
                "sentiment_label": sentiment_label,
            },
            status_code=200
        )
    
    except Exception as e:
        logger.error(f"Unexpected error in upload_audio endpoint: {e}")
        # Clean up on unexpected errors
        if save_path and os.path.exists(save_path):
            try:
                os.remove(save_path)
            except:
                pass
        if db:
            try:
                db.close()
            except:
                pass
        return JSONResponse(
            content={"error": "An unexpected error occurred during audio processing"},
            status_code=500
        )