# Pantry Plan API (FastAPI)

Local backend for the PantrySnap iOS app. Runs on **http://localhost:8000**.

## Quick start

On macOS, use a virtual environment (system Python is often externally managed):

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python run.py
```

Next time you open a terminal, activate the venv then run the server:

```bash
cd backend
source .venv/bin/activate
python run.py
```

Server starts on port 8000.

- **Swagger (on this Mac):** open **http://127.0.0.1:8000/docs** in your browser.
- **From another device (e.g. iPhone on same Wi‑Fi):** use this Mac's IP, e.g. **http://192.168.1.5:8000/docs**. Find the IP: **System Settings → Network → Wi‑Fi → Details**.

## Endpoints

- **GET /pantry/** — returns all pantry items (from `pantry_db.json`)
- **POST /pantry/** — add item (body: `name`, `quantity`, `unit`, `expiry_date` YYYY-MM-DD)

Data is stored in `backend/pantry_db.json`.
