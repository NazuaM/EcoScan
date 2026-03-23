import os
import base64
import json
import uvicorn
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq
from dotenv import load_dotenv

# 1. Load Environment Variables
load_dotenv()
api_key = os.getenv("GROQ_API_KEY")

# 2. Setup Groq Client
client = Groq(api_key=api_key)

# 3. Setup FastAPI
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- HELPER: NORMALIZER ---
def normalize_material(raw_material: str):
    """
    Converts 'Aluminum Can' -> 'metal'
    Converts 'Plastic Bottle' -> 'plastic'
    """
    m = raw_material.lower()
    if any(x in m for x in ["aluminum", "steel", "tin", "copper", "iron", "metal"]):
        return "metal"
    if any(x in m for x in ["plastic", "bottle", "jug", "pvc"]):
        return "plastic"
    if any(x in m for x in ["paper", "cardboard", "carton", "newspaper"]):
        return "paper"
    if "glass" in m:
        return "glass"
    return "other"

@app.post("/analyze")
async def analyze_trash(file: UploadFile = File(...)):
    print(f"📩 Received image: {file.filename}")
    
    image_bytes = await file.read()
    base64_image = base64.b64encode(image_bytes).decode('utf-8')

    prompt_text = """
    Analyze this image. Identify the item.
    Output ONLY valid JSON:
    {
        "item_name": "Short Name",
        "material": "Material",
        "state": "State",
        "quality": "Quality",
        "quantity": "Quantity",
        "recyclable": true/false,
        "action": "Short recommended action"
    }
    """

    try:
        response = client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt_text},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}},
                    ],
                }
            ],
            model="meta-llama/llama-4-scout-17b-16e-instruct", 
            temperature=0,
            max_tokens=500
        )

        content = response.choices[0].message.content
        clean_content = content.replace("```json", "").replace("```", "").strip()
        data = json.loads(clean_content)

        # --- 🛑 LOGIC FIX: OVERRIDES, NORMALIZATION & CONFIDENCE 🛑 ---
        
        full_text = (data.get("item_name", "") + " " + data.get("material", "")).lower()

        # Define Keyword Lists
        medical_keywords = ["pill", "tablet", "capsule", "blister", "medicine", "drug", "pharmacy", "medication", "syringe"]
        furniture_keywords = ["sofa", "chair", "couch", "furniture", "table", "mattress", "bed", "cabinet"]
        electronic_keywords = ["phone", "laptop", "computer", "electronic", "device", "keyboard", "mouse", "screen", "monitor", "wire", "cable", "circuit"]
        # NEW: Gross/Organic stuff
        trash_keywords = ["food", "organic", "waste", "leftover", "pizza", "diaper", "tissue", "napkin", "liquid", "sludge", "banana", "apple", "peel"]

        # 1. TRASH CHECK (Priority #1 - Safety First)
        if any(k in full_text for k in trash_keywords):
            data["material_category"] = "general_waste"
            data["recyclable"] = False
            data["material"] = "Organic/General Waste"
            data["action"] = "Dispose in general waste bin"
            data["confidence"] = "High"  # We are sure because of keywords
            print(f"✅ OVERRIDE: {data['item_name']} -> TRASH")

        # 2. MEDICINE CHECK
        elif any(k in full_text for k in medical_keywords):
            data["material_category"] = "medication"
            data["recyclable"] = True
            data["material"] = "Medication/Hazardous"
            data["confidence"] = "High"
            print(f"✅ OVERRIDE: {data['item_name']} -> MEDICATION")

        # 3. FURNITURE CHECK
        elif any(k in full_text for k in furniture_keywords):
            data["material_category"] = "furniture"
            data["recyclable"] = True
            data["material"] = "Furniture/Bulk Item"
            data["confidence"] = "High"
            print(f"✅ OVERRIDE: {data['item_name']} -> FURNITURE")

        # 4. ELECTRONICS CHECK
        elif any(k in full_text for k in electronic_keywords):
            data["material_category"] = "electronics"
            data["recyclable"] = True
            data["material"] = "E-Waste/Electronics"
            data["confidence"] = "High"
            print(f"✅ OVERRIDE: {data['item_name']} -> ELECTRONICS")

        # 5. STANDARD FALLBACK
        else:
            data["material_category"] = normalize_material(data.get("material", ""))
            data["confidence"] = "Medium" # Standard AI guess
            print(f"✅ Analysis Complete: {data['item_name']} -> {data['material_category']}")

        return data

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)