import requests
from os import getenv

OPENFDA_BASE_URL = getenv("OPENFDA_BASE_URL", "https://api.fda.gov/drug/label.json")
OPENFDA_API_KEY = getenv("OPENFDA_API_KEY")

def _format_medicine_response(result):
    openfda = result.get("openfda", {})
    return {
        "brand": openfda.get("brand_name", ["Unknown"])[0],
        "generic": openfda.get("generic_name", ["Unknown"])[0],
        "usage": result.get("indications_and_usage", ["Not available"])[0],
        "dosage": result.get("dosage_and_administration", ["Not available"])[0],
        "side_effects": result.get("adverse_reactions", ["Not available"])[0]
    }

def _barcode_candidates(raw_code):
    code = "".join(ch for ch in raw_code if ch.isdigit())
    candidates = set()

    if not code:
        return []

    # Original numeric code as-is.
    candidates.add(code)

    # Common UPC-A medicine packaging pattern:
    # 12-digit UPC => [number-system][10-digit NDC payload][check-digit]
    # Convert to possible 10-digit and 11-digit NDC-like candidates.
    if len(code) == 12:
        ndc10 = code[1:11]
        ndc11 = code[1:11].zfill(11)

        candidates.add(ndc10)
        candidates.add(ndc11)

        # Hyphenated possibilities (10-digit NDC segment patterns).
        if len(ndc10) == 10:
            candidates.add(f"{ndc10[0:4]}-{ndc10[4:8]}-{ndc10[8:10]}")
            candidates.add(f"{ndc10[0:5]}-{ndc10[5:8]}-{ndc10[8:10]}")
            candidates.add(f"{ndc10[0:5]}-{ndc10[5:9]}-{ndc10[9:10]}")

        # Standard 11-digit FDA style (5-4-2).
        if len(ndc11) == 11:
            candidates.add(f"{ndc11[0:5]}-{ndc11[5:9]}-{ndc11[9:11]}")

    # Also try 11-digit to hyphenated FDA format.
    if len(code) == 11:
        candidates.add(f"{code[0:5]}-{code[5:9]}-{code[9:11]}")

    return list(candidates)

def get_medicine(name):
    base_url = OPENFDA_BASE_URL
    search_terms = [
        f'openfda.generic_name:"{name}"',
        f'openfda.brand_name:"{name}"',
        f'openfda.substance_name:"{name}"'
    ]

    data = {}
    for search in search_terms:
        try:
            params = {"search": search, "limit": 1}
            if OPENFDA_API_KEY:
                params["api_key"] = OPENFDA_API_KEY
            r = requests.get(base_url, params=params, timeout=10)
            if r.status_code == 200:
                data = r.json()
                if "results" in data and data["results"]:
                    break
        except requests.RequestException:
            continue

    if "results" not in data or not data["results"]:
        return {"message": "Medicine not found"}

    result = data["results"][0]
    return _format_medicine_response(result)

def get_medicine_by_barcode(barcode):
    if not barcode:
        return {"message": "Barcode is required"}

    base_url = OPENFDA_BASE_URL
    candidates = _barcode_candidates(barcode.strip())
    if not candidates:
        return {"message": "Invalid barcode"}

    search_terms = []
    for code in candidates:
        search_terms.extend([
            f'openfda.product_ndc:"{code}"',
            f'openfda.package_ndc:"{code}"',
            f'openfda.spl_id:"{code}"'
        ])

    data = {}
    for search in search_terms:
        try:
            params = {"search": search, "limit": 1}
            if OPENFDA_API_KEY:
                params["api_key"] = OPENFDA_API_KEY
            r = requests.get(base_url, params=params, timeout=10)
            if r.status_code == 200:
                data = r.json()
                if "results" in data and data["results"]:
                    break
        except requests.RequestException:
            continue

    if "results" not in data or not data["results"]:
        return {"message": "Medicine not found for barcode"}

    result = data["results"][0]
    return _format_medicine_response(result)
