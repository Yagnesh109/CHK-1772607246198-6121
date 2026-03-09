from fastapi import FastAPI
from dotenv import load_dotenv
from services.medicine_service import get_medicine, get_medicine_by_barcode

load_dotenv()

app = FastAPI()

@app.get("/medicine")
def medicine(name: str):
    return get_medicine(name)

@app.get("/medicine/barcode")
def medicine_by_barcode(code: str):
    return get_medicine_by_barcode(code)
