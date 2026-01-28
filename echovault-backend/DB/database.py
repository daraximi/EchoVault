from sqlalchemy import Column, String, Float, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
import datetime
from dotenv import load_dotenv
import os
import logging

load_dotenv()

logger = logging.getLogger(__name__)

# Validate database URL
DATABASE_URL = os.getenv("LOCAL_DATABASE_URL")
if not DATABASE_URL:
    logger.error("LOCAL_DATABASE_URL environment variable is not set")
    raise ValueError("LOCAL_DATABASE_URL environment variable is required. Please check your .env file.")

try:
    engine = create_engine(
        DATABASE_URL,
        pool_size=5,
        max_overflow=10,
        echo=False
    )
    logger.info("Database engine created successfully")
except Exception as e:
    logger.error(f"Failed to create database engine: {e}")
    raise Exception(f"Database connection failed: {str(e)}")

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
    """Initialize database tables. Raises exception if table creation fails."""
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database tables: {e}")
        raise Exception(f"Database initialization failed: {str(e)}")