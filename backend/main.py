"""
FastAPI backend for Pantry Plan app.
Storage: pantry_db.json in the backend directory.
"""

import json
from pathlib import Path

from fastapi import FastAPI, HTTPException
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


def _normalize_row(row: dict) -> dict:
    """Ensure row has expiry_dates list (migrate from expiry_date if needed)."""
    if "expiry_dates" not in row and "expiry_date" in row:
        row = {**row, "expiry_dates": [row["expiry_date"]]}
    if "expiry_dates" not in row:
        row = {**row, "expiry_dates": []}
    return row


class PantryItem(BaseModel):
    id: int
    name: str
    quantity: int
    unit: str
    expiry_dates: list[str] = Field(default_factory=list, description="Dates as YYYY-MM-DD (one per added batch)")


class PantryItemCreate(BaseModel):
    name: str
    quantity: int
    unit: str
    expiry_date: str = Field(..., description="Date as YYYY-MM-DD")


class PantryItemUpdate(BaseModel):
    name: str | None = None
    quantity: int | None = None
    unit: str | None = None
    expiry_dates: list[str] | None = None


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
def get_pantry(q: str | None = None) -> list[PantryItem]:
    """Return all pantry items. If q is provided, filter by name (case-insensitive)."""
    rows = [_normalize_row(dict(r)) for r in _load_db()]
    if q is not None and q.strip():
        query = q.strip().lower()
        rows = [r for r in rows if query in r.get("name", "").lower()]
    return [PantryItem(**row) for row in rows]


def _find_by_name(items: list[dict], name: str) -> dict | None:
    name_lower = name.strip().lower()
    for r in items:
        if r.get("name", "").strip().lower() == name_lower:
            return r
    return None


@app.post("/pantry/", response_model=PantryItem, status_code=201)
def post_pantry(item: PantryItemCreate) -> PantryItem:
    """Accept a new item. If an item with the same name exists, merge: add quantity and append expiry_date to expiry_dates."""
    items = [_normalize_row(dict(r)) for r in _load_db()]
    existing = _find_by_name(items, item.name)

    if existing is not None:
        existing["quantity"] = existing.get("quantity", 0) + item.quantity
        dates = existing.get("expiry_dates") or []
        if item.expiry_date not in dates:
            dates.append(item.expiry_date)
        existing["expiry_dates"] = sorted(dates)
        _save_db(items)
        return PantryItem(**existing)

    new_id = _next_id(items)
    new_item = PantryItem(
        id=new_id,
        name=item.name.strip(),
        quantity=item.quantity,
        unit=item.unit,
        expiry_dates=[item.expiry_date],
    )
    items.append(new_item.model_dump())
    _save_db(items)
    return new_item


@app.put("/pantry/{item_id}/", response_model=PantryItem)
def put_pantry(item_id: int, body: PantryItemUpdate) -> PantryItem:
    """Update an existing item by id."""
    items = [_normalize_row(dict(r)) for r in _load_db()]
    for i, row in enumerate(items):
        if row.get("id") == item_id:
            if body.name is not None:
                items[i]["name"] = body.name.strip()
            if body.quantity is not None:
                items[i]["quantity"] = body.quantity
            if body.unit is not None:
                items[i]["unit"] = body.unit
            if body.expiry_dates is not None:
                items[i]["expiry_dates"] = sorted(body.expiry_dates)
            _save_db(items)
            return PantryItem(**items[i])
    raise HTTPException(status_code=404, detail="Item not found")
