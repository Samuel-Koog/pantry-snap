"""
FastAPI backend for Pantry Plan app.
Storage: pantry_db.json in the backend directory.
"""

import json
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "pantry_db.json"

app = FastAPI(title="Pantry Plan API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Models ---


class PantryItem(BaseModel):
    id: int
    name: str
    quantity: int
    unit: str
    expiry_date: str = Field(..., description="Date as YYYY-MM-DD")


class PantryItemCreate(BaseModel):
    name: str
    quantity: int
    unit: str
    expiry_date: str = Field(..., description="Date as YYYY-MM-DD")


# --- Storage ---


def _load_db() -> list[dict]:
    if not DB_PATH.exists():
        return []
    with open(DB_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else []


def _save_db(items: list[dict]) -> None:
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2)


def _next_id(items: list[dict]) -> int:
    if not items:
        return 1
    return max(item["id"] for item in items) + 1


# --- Endpoints ---


@app.get("/pantry/", response_model=list[PantryItem])
def get_pantry() -> list[PantryItem]:
    """Return all pantry items."""
    rows = _load_db()
    return [PantryItem(**row) for row in rows]


@app.post("/pantry/", response_model=PantryItem, status_code=201)
def post_pantry(item: PantryItemCreate) -> PantryItem:
    """Accept and save a new pantry item. ID is assigned by the server."""
    items = _load_db()
    new_id = _next_id(items)
    new_item = PantryItem(
        id=new_id,
        name=item.name,
        quantity=item.quantity,
        unit=item.unit,
        expiry_date=item.expiry_date,
    )
    items.append(new_item.model_dump())
    _save_db(items)
    return new_item
