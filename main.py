import os
import base64
import json
import time
import uvicorn
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from groq import Groq
from dotenv import load_dotenv

# 1. Load Environment Variables
# Single shared environment file at workspace root.
load_dotenv(".env")
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

# ─────────────────────────────────────────────
# HELPER: MATERIAL NORMALIZER
# ─────────────────────────────────────────────
def normalize_material(raw_material: str):
    m = raw_material.lower()
    if any(x in m for x in ["aluminum", "steel", "tin", "copper", "iron", "metal"]):
        return "metal"
    if any(x in m for x in ["plastic", "bottle", "jug", "pvc"]):
        return "plastic"
    if any(x in m for x in ["paper", "cardboard", "carton", "newspaper"]):
        return "paper"
    if "glass" in m:
        return "glass"
    if any(x in m for x in ["wood", "timber", "plywood"]):
        return "wood"
    if any(x in m for x in ["fabric", "textile", "cloth", "cotton", "denim"]):
        return "textiles"
    return "other"


# ─────────────────────────────────────────────
# ENDPOINT 1: /analyze  (image → classification)
# ─────────────────────────────────────────────
@app.post("/analyze")
async def analyze_trash(file: UploadFile = File(...)):
    print(f"📩 Received image: {file.filename}")
    started_at = time.perf_counter()

    image_bytes = await file.read()
    base64_image = base64.b64encode(image_bytes).decode('utf-8')

    prompt_text = """
Return ONLY valid JSON (no markdown):
{
  "item_name": "short name",
  "material": "main material",
  "state": "clean/dirty/crushed/intact",
  "quality": "Good/Fair/Poor",
  "quantity": "short estimate",
  "recyclable": true,
  "action": "one short disposal tip",
  "upcyclable": false
}
Be concise.
"""

    try:
        response = client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt_text},
                        {"type": "image_url", "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}"
                        }},
                    ],
                }
            ],
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            temperature=0,
            max_tokens=220
        )

        content = response.choices[0].message.content
        clean_content = content.replace("```json", "").replace("```", "").strip()
        data = json.loads(clean_content)

        full_text = (data.get("item_name", "") + " " + data.get("material", "")).lower()

        # Override keyword lists
        medical_keywords   = ["pill", "tablet", "capsule", "blister", "medicine", "drug", "medication", "syringe"]
        furniture_keywords = ["sofa", "chair", "couch", "furniture", "table", "mattress", "bed", "cabinet"]
        electronic_keywords= ["phone", "laptop", "computer", "electronic", "device", "keyboard", "mouse",
                               "screen", "monitor", "wire", "cable", "circuit"]
        trash_keywords     = ["food", "organic", "waste", "leftover", "pizza", "diaper",
                               "used tissue", "toilet paper", "paper towel", "napkin",
                               "liquid", "sludge", "banana", "apple", "peel"]

        if "tissue box" in full_text or ("box" in full_text and "tissue" in full_text):
            data["material_category"] = "paper"
            data["recyclable"]        = True
            data["upcyclable"]        = True
            data["material"]          = "Paper/Cardboard"
            data["action"]            = "Flatten box and recycle with paper/cardboard"
            data["confidence"]        = "High"
        elif any(k in full_text for k in trash_keywords):
            data["material_category"] = "general_waste"
            data["recyclable"]        = False
            data["upcyclable"]        = False
            data["material"]          = "Organic/General Waste"
            data["action"]            = "Dispose in general waste bin"
            data["confidence"]        = "High"
        elif any(k in full_text for k in medical_keywords):
            data["material_category"] = "medication"
            data["recyclable"]        = True
            data["upcyclable"]        = False
            data["material"]          = "Medication/Hazardous"
            data["confidence"]        = "High"
        elif any(k in full_text for k in furniture_keywords):
            data["material_category"] = "furniture"
            data["recyclable"]        = True
            data["upcyclable"]        = True
            data["material"]          = "Furniture/Bulk Item"
            data["confidence"]        = "High"
        elif any(k in full_text for k in electronic_keywords):
            data["material_category"] = "electronics"
            data["recyclable"]        = True
            data["upcyclable"]        = False
            data["material"]          = "E-Waste/Electronics"
            data["confidence"]        = "High"
        else:
            data["material_category"] = normalize_material(data.get("material", ""))
            data["confidence"]        = "Medium"

        elapsed = time.perf_counter() - started_at
        print(f"✅ Analyzed: {data.get('item_name')} → {data.get('material_category')} in {elapsed:.2f}s")
        return data

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"error": str(e)}


# ─────────────────────────────────────────────
# ENDPOINT 2: /tutorial  (item → DIY tutorial)
# ─────────────────────────────────────────────
class TutorialRequest(BaseModel):
    item_name: str
    material: str
    state: str = "Unknown"
    quality: str = "Unknown"
    skill_level: str = "Beginner"       # Beginner / Intermediate / Advanced
    available_tools: list[str] = ["scissors", "glue"]


@app.post("/tutorial")
async def get_tutorial(req: TutorialRequest):
    print(f"📚 Tutorial request: {req.item_name} | skill={req.skill_level} | tools={req.available_tools}")

    tools_str = ", ".join(req.available_tools) if req.available_tools else "basic household tools"

    prompt = f"""
You are a creative sustainability expert who specializes in upcycling waste materials.

A user has scanned the following item:
- Item: {req.item_name}
- Material: {req.material}
- Condition: {req.state}
- Quality: {req.quality}
- Skill level: {req.skill_level}
- Available tools: {tools_str}

Generate ONE practical, creative upcycling DIY project suitable for their skill level and tools.

You MUST respond with ONLY valid JSON, no extra text, no markdown, exactly this structure:
{{
    "project_title": "Catchy name for the project",
    "difficulty": "Beginner / Intermediate / Advanced",
    "time_required": "e.g. 30 minutes",
    "materials_needed": ["item itself", "any extra materials needed"],
    "tools_needed": ["list of tools"],
    "steps": [
        {{"step": 1, "title": "Short title", "description": "Detailed instruction"}},
        {{"step": 2, "title": "Short title", "description": "Detailed instruction"}},
        {{"step": 3, "title": "Short title", "description": "Detailed instruction"}}
    ],
    "eco_impact": "One sentence on why this is good for the environment",
    "tips": ["Optional helpful tip 1", "Optional helpful tip 2"]
}}

Generate 4-6 clear steps. Be specific and practical. Tailor complexity to {req.skill_level} skill level.
"""

    try:
        response = client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            temperature=0.7,
            max_tokens=1200
        )

        content = response.choices[0].message.content
        clean_content = content.replace("```json", "").replace("```", "").strip()
        tutorial_data = json.loads(clean_content)

        print(f"✅ Tutorial generated: {tutorial_data.get('project_title')}")
        return tutorial_data

    except Exception as e:
        print(f"❌ Tutorial error: {e}")
        return {"error": str(e)}


# ─────────────────────────────────────────────
# ENDPOINT 3: /swap  (material → eco swap)
# ─────────────────────────────────────────────
class SwapRequest(BaseModel):
    item: str   # e.g. "plastic wrap", "styrofoam cup"


@app.post("/swap")
async def get_eco_swap(req: SwapRequest):
    print(f"🌿 Swap request: {req.item}")

    prompt = f"""
You are an eco-friendly product expert.
The user wants to replace: "{req.item}"

Respond with ONLY valid JSON, no extra text:
{{
    "original_item": "{req.item}",
    "swaps": [
        {{
            "name": "Eco-friendly alternative name",
            "reason": "Why it is better for the environment",
            "estimated_co2_saving": "e.g. ~30% less CO2",
            "where_to_buy": "General tip on where to find it"
        }}
    ]
}}

Provide 2-3 practical swap options. Be specific.
"""

    try:
        response = client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            temperature=0.5,
            max_tokens=600
        )

        content = response.choices[0].message.content
        clean_content = content.replace("```json", "").replace("```", "").strip()
        return json.loads(clean_content)

    except Exception as e:
        print(f"❌ Swap error: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
