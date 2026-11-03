import json
import os

import google.cloud.firestore
import google.generativeai as genai
from dotenv import load_dotenv


def generate_skills() -> None:
    """
    Generate skills using Gemini and upload them to Firestore.
    """
    print("--- Skill Generation Script Started ---")

    try:
        service_account_path = os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", "service_account.json"
        )
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = service_account_path
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
    Generate a JSON array containing 15 unique skills for a Solo Leveling styled RPG game in English.
    Each object in the array represents a skill with the following structure:
    - "id": unique string, e.g. "passive_toughness_1".
    - "name": English skill name, e.g. "Physical Hardening I".
    - "description": English description of the skill effect.
    - "skillType": string, one of: "passive", "activeBuff".
    - "levelRequirement": integer (5 to 40).
    - "skillPointCost": integer (1 or 2).
    - "statRequirements": JSON object with required stats (strength, agility, intelligence, perception, stamina). Can be empty {}.
    - "effects": JSON object with effects. Key is effect type, value is number. Possible keys: addStrength, addAgility, addIntelligence, addPerception, addStamina, multiplyMaxHp, multiplyMaxMp, multiplyXpGain, reduceMpCost, reduceCooldown.
    - "mpCost": number (for activeBuff, 10-50). null for passive.
    - "durationSeconds": number (for activeBuff, 300-1200). null for passive.
    - "cooldownSeconds": number (for activeBuff, 1800-7200). null for passive.

    Generate 10 passive skills and 5 active buffs with epic names.
    Output ONLY a valid JSON array.
    """

    try:
        print("\nGenerating skills with Gemini... Please wait.")
        response = model.generate_content(prompt)

        cleaned_response = (
            response.text.strip().replace("```json", "").replace("```", "").strip()
        )
        skills_data = json.loads(cleaned_response)

        if not isinstance(skills_data, list):
            print("Error: Gemini did not return a JSON array.")
            return

        print(f"Successfully generated {len(skills_data)} skills.")

        skills_collection_ref = db.collection("skills")
        batch = db.batch()

        added_count = 0
        for skill in skills_data:
            if isinstance(skill, dict) and "id" in skill:
                skill_id = skill["id"]
                doc_ref = skills_collection_ref.document(skill_id)
                batch.set(doc_ref, skill)
                added_count += 1
            else:
                print(f"Skipping invalid skill data: {skill}")

        batch.commit()
        print(f"\nSuccessfully uploaded {added_count} skills to Firestore collection 'skills'.")

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    generate_skills()
    print("\n--- Script Finished ---")
