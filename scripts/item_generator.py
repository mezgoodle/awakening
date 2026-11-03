import json
import os

import google.cloud.firestore
import google.generativeai as genai
from dotenv import load_dotenv


def generate_items():
    """
    Generate items using Gemini and upload them to Firestore.
    """
    print("--- Item Generation Script Started ---")

    try:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", "service_account.json"
        )
        db = google.cloud.firestore.Client()
        print("Firestore Client Initialized.")

        load_dotenv()
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            print("Error: GEMINI_API_KEY not found in .env file or environment!")
            return
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.5-flash-lite")
        print("Gemini API Initialized.")

    except Exception as e:
        print(f"Error during initialization: {e}")
        return

    prompt = """
    Generate a JSON array containing 10 unique items for a Solo Leveling styled RPG game in English.
    Each object in the array represents an item with the following structure:
    - "id": unique string formatted like "type_name_level", e.g., "potion_health_small".
    - "name": English item name.
    - "description": concise English description.
    - "type": string, one of: "potion", "key", "material", "collectible".
    - "iconPath": SVG icon path, e.g., "assets/icons/items/health-potion.svg".
    - "isStackable": boolean (true/false). Potions and materials should be true.
    - "effects": JSON object with effects when used. Key is effect type, value is number. Possible effect types: "restoreHp", "restoreMp", "restoreHpPercent", "restoreMpPercent". Empty object {} for keys and materials.

    Provide a diverse selection:
    - 3-4 potions (health, mana; small/medium/large).
    - 2-3 dungeon keys (e.g. E-Rank Gate Key, D-Rank Gate Key).
    - 2-3 crafting materials (e.g. "Magic Crystal", "Essence Stone").
    - 1-2 collectibles/trophies (e.g. "Shadow Wolf Fang").

    Output ONLY a valid JSON array, with no markdown code fences or comments.
    """

    try:
        print("\nGenerating items with Gemini... Please wait.")
        response = model.generate_content(prompt)

        cleaned_response = (
            response.text.strip().replace("```json", "").replace("```", "").strip()
        )
        items_data = json.loads(cleaned_response)

        if not isinstance(items_data, list):
            print("Error: Gemini did not return a JSON array.")
            return

        print(f"Successfully generated {len(items_data)} items.")

        items_collection_ref = db.collection("items")
        batch = db.batch()

        added_count = 0
        for item in items_data:
            if isinstance(item, dict) and "id" in item:
                item_id = item["id"]
                doc_ref = items_collection_ref.document(item_id)
                batch.set(doc_ref, item)
                added_count += 1

        batch.commit()
        print(f"\nSuccessfully uploaded {added_count} items to Firestore collection 'items'.")

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    generate_items()
    print("\n--- Script Finished ---")
