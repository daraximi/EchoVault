import openai
from textblob import TextBlob
import os
from dotenv import load_dotenv
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")


def analyze_sentiment(text:str):
    blob = TextBlob(text)
    polarity = blob.sentiment.polarity
    
    if polarity >0.1:
        label = "Positive"
    elif polarity < -0.1:
        label = "Negative"
    else:
        label = "Neutral"
    return polarity, label

async def transcribe_audio(file_path: str)-> str:
    client = openai.OpenAI(api_key=OPENAI_API_KEY)
    with open(file_path, "rb") as audio_file:
        transcription = client.audio.transcriptions.create(
            model="whisper-1", 
            file=audio_file
        )
    return transcription.text
    