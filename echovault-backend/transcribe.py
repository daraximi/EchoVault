import openai
from textblob import TextBlob
import os
from dotenv import load_dotenv
import logging

load_dotenv()

logger = logging.getLogger(__name__)

# Validate OpenAI API key on module load
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    logger.error("OPENAI_API_KEY environment variable is not set")
    raise ValueError("OPENAI_API_KEY environment variable is required")


def analyze_sentiment(text: str) -> tuple[float, str]:
    """
    Analyze sentiment of text using TextBlob.
    Returns (polarity, sentiment_label)
    """
    if not text or not text.strip():
        logger.warning("Empty text provided for sentiment analysis")
        return 0.0, "Neutral"
    
    try:
        blob = TextBlob(text)
        polarity = blob.sentiment.polarity
        
        if polarity > 0.1:
            label = "Positive"
        elif polarity < -0.1:
            label = "Negative"
        else:
            label = "Neutral"
        
        return polarity, label
    except Exception as e:
        logger.error(f"Sentiment analysis error: {e}")
        raise Exception(f"Failed to analyze sentiment: {str(e)}")


async def transcribe_audio(file_path: str) -> str:
    """
    Transcribe audio file using OpenAI Whisper API.
    Raises exception if transcription fails.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Audio file not found: {file_path}")
    
    if os.path.getsize(file_path) == 0:
        raise ValueError("Audio file is empty")
    
    try:
        client = openai.OpenAI(api_key=OPENAI_API_KEY)
        with open(file_path, "rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file
            )
        
        if not transcription.text:
            logger.warning(f"Transcription returned empty text for {file_path}")
            return ""
        
        return transcription.text
    
    except openai.APIError as e:
        logger.error(f"OpenAI API error during transcription: {e}")
        raise Exception(f"OpenAI API error: {str(e)}")
    except openai.APIConnectionError as e:
        logger.error(f"OpenAI connection error: {e}")
        raise Exception("Failed to connect to OpenAI API. Please check your internet connection.")
    except openai.RateLimitError as e:
        logger.error(f"OpenAI rate limit exceeded: {e}")
        raise Exception("OpenAI API rate limit exceeded. Please try again later.")
    except openai.AuthenticationError as e:
        logger.error(f"OpenAI authentication error: {e}")
        raise Exception("OpenAI API authentication failed. Please check your API key.")
    except Exception as e:
        logger.error(f"Unexpected error during transcription: {e}")
        raise Exception(f"Audio transcription failed: {str(e)}")