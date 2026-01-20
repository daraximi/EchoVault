from _curses import echo
from sqlalchemy import Column, String, Float, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
import datetime
from dotenv import load_dotenv
load_dotenv()
import os
import psycopg2

DATABASE_URL = os.getenv("LOCAL_DATABASE_URL")

engine = create_engine(
    DATABASE_URL,
    pool_size= 5, 
    max_overflow= 10,
    echo= False)
SessionLocal = sessionmaker(bind=engine)

Base = declarative_base()

class Entry(Base):
    __tablename__ = "entries"

    id = Column(String, primary_key=True)          # UUID from your upload
    filename = Column(String, nullable=False)
    transcript = Column(Text, nullable=False)
    polarity = Column(Float, nullable=False)
    sentiment_label = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

def init_db():
    Base.metadata.create_all(bind=engine)