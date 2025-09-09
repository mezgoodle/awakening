import json
import os

import google.cloud.firestore
import google.generativeai as genai
from dotenv import load_dotenv


def generate_items():
    """
    Функція для генерації предметів та завантаження їх у Firestore.
    """
    print("--- Item Generation Script Started ---")

    # 1. Ініціалізація клієнтів (Firestore та Gemini)
    # ------------------------------------
    try:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "service_account.json"
        db = google.cloud.firestore.Client()
        print("Firestore Client Initialized.")

        load_dotenv()
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            print("Error: GEMINI_API_KEY not found in .env file!")
            return
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        print("Gemini API Initialized.")

    except Exception as e:
        print(f"Error during initialization: {e}")
        return

    # 2. Формування "Майстер-Промпту" для предметів
    # ------------------------------------
    prompt = """
    Згенеруй JSON-масив, що містить 10 унікальних предметів для RPG-гри в стилі "Solo Leveling".
    Кожен об'єкт в масиві має представляти один предмет і мати наступну структуру:
    - "id": унікальний рядок в стилі "type_name_level", наприклад, "potion_health_small".
    - "name": назва предмету українською.
    - "description": короткий опис предмету українською.
    - "type": рядок, одне зі значень: "potion", "key", "material", "collectible".
    - "iconPath": рядок, шлях до іконки, наприклад, "assets/icons/items/health_potion.svg".
    - "isStackable": булеве значення (true/false). Зілля та матеріали мають бути true.
    - "effects": об'єкт JSON з ефектами при використанні. Ключ - тип ефекту, значення - число. Можливі типи: "restoreHp", "restoreMp". Для предметів без ефекту (ключі, матеріали) це має бути порожній об'єкт {}.

    Створи різноманітні предмети:
    - 3-4 зілля (здоров'я, мана; мале/середнє).
    - 2-3 ключі (для розломів/підземель різних рангів: E, D).
    - 2-3 матеріали (напр., "Магічний камінь", "Фрагмент есенції").
    - 1-2 колекційні предмети (напр., "Зуб вовка-тіні").

    Надай відповідь ТІЛЬКИ у вигляді валідного JSON-масиву, без жодних коментарів.
    Приклад одного елемента:
    {
      "id": "potion_health_small",
      "name": "Мале Зілля Здоров'я",
      "description": "Слабке зілля, що відновлює невелику кількість здоров'я.",
      "type": "potion",
      "iconPath": "assets/icons/items/health_potion.svg",
      "isStackable": true,
      "effects": { "restoreHp": 25.0 }
    }
    """

    # 3. Виконання Запиту та Запис в Firestore
    # ------------------------------------
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

        print(
            f"\nSuccessfully uploaded {added_count} items to Firestore collection 'items'."
        )

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    generate_items()
    print("\n--- Script Finished ---")
