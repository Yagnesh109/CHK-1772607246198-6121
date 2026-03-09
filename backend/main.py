from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi import File, UploadFile

load_dotenv()

from services.medicine_service import get_medicine, get_medicine_by_barcode
from services.ocr_service import extract_medicine_details_from_image

app = FastAPI()

@app.get("/medicine")
def medicine(name: str):
    return get_medicine(name)

@app.get("/medicine/barcode")
def medicine_by_barcode(code: str):
    return get_medicine_by_barcode(code)

@app.post("/medicine/extract-ocr")
async def extract_medicine_ocr(file: UploadFile = File(...)):
    image_bytes = await file.read()
    if not image_bytes:
        return {"error": "Empty image file."}
    return extract_medicine_details_from_image(image_bytes, file.content_type)
