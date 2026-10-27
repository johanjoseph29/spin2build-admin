import os
from dotenv import load_dotenv
from sqlalchemy import (create_engine, Column, Integer, String, Text, Boolean,
                        ForeignKey, UniqueConstraint, DateTime)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship
from sqlalchemy.sql import func

# Load .env file for configuration (e.g., admin password)
load_dotenv()

# SQLite database file path (created in the same directory as this script)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DB_PATH = os.path.join(BASE_DIR, 'spin2build.db')

engine = create_engine(f'sqlite:///{DB_PATH}', echo=False, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

class Admin(Base):
    __tablename__ = 'admins'
    id = Column(Integer, primary_key=True)
    # For simplicity we store a single password hash (plain text in this demo).
    password = Column(String(255), nullable=False)

class Team(Base):
    __tablename__ = 'teams'
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    code = Column(String(20), unique=True, nullable=False)  # access code
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    assignment = relationship('Assignment', back_populates='team', uselist=False)

class Topic(Base):
    __tablename__ = 'topics'
    id = Column(Integer, primary_key=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    # A topic is considered "available" when it has no row in assignments.
    __table_args__ = (UniqueConstraint('title', name='uq_topic_title'),)
    assignment = relationship('Assignment', back_populates='topic', uselist=False)

class Assignment(Base):
    __tablename__ = 'assignments'
    id = Column(Integer, primary_key=True)
    team_id = Column(Integer, ForeignKey('teams.id'), nullable=False, unique=True)
    topic_id = Column(Integer, ForeignKey('topics.id'), nullable=False, unique=True)
    assigned_at = Column(DateTime(timezone=True), server_default=func.now())
    team = relationship('Team', back_populates='assignment')
    topic = relationship('Topic', back_populates='assignment')

def init_db():
    """Create all tables and ensure a default admin exists."""
    Base.metadata.create_all(bind=engine)
    # Insert default admin if not present
    admin_password = os.getenv('ADMIN_PASSWORD', 'admin123')
    with SessionLocal() as db:
        if not db.query(Admin).first():
            admin = Admin(password=admin_password)
            db.add(admin)
            db.commit()

if __name__ == '__main__':
    init_db()
    print(f'Database initialized at {DB_PATH}')
