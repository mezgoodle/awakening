import json
import os

import google.cloud.firestore
import google.generativeai as genai


def generate_skills() -> None:
    """
    Основна функція для генерації навичок та завантаження їх у Firestore.
    """
    print("--- Skill Generation Script Started ---")

    # 1. Ініціалізація клієнтів
    # ------------------------------------
    try:
        service_account_path = os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", "service_account.json"
        )
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = service_account_path
        db = google.cloud.firestore.Client()
        print("Firestore Client Initialized.")

        # Ініціалізація Gemini API
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            print("Error: GEMINI_API_KEY not found in .env file!")
            return
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        print("Gemini API Initialized.")

    except (ValueError, ImportError, google.cloud.exceptions.GoogleCloudError) as e:
        print(f"Error during initialization: {e}")
        return

    # 2. Формування "Майстер-Промпту"
    # ------------------------------------
    prompt = """
    Згенеруй JSON-масив, що містить 15 унікальних навичок для RPG-гри в стилі "Solo Leveling".
    Кожен об'єкт в масиві має представляти одну навичку і мати наступну структуру:
    - "id": унікальний рядок в стилі "type_name_level", наприклад, "passive_toughness_1".
    - "name": назва навички українською, наприклад, "Фізична Закалка I".
    - "description": короткий опис ефекту навички українською.
    - "skillType": рядок, одне зі значень: "passive", "activeBuff".
    - "levelRequirement": число, мінімальний рівень гравця для вивчення (від 5 до 40).
    - "skillPointCost": число, вартість вивчення (1 або 2).
    - "statRequirements": об'єкт JSON з вимогами до характеристик. Ключ - назва стату (strength, agility, intelligence, perception, stamina), значення - число. Може бути порожнім.
    - "effects": об'єкт JSON з ефектами. Ключ - тип ефекту, значення - число. Типи ефектів: addStrength, addStamina, multiplyMaxHp, multiplyMaxMp, multiplyXpGain.
    - "mpCost": число, вартість в MP (тільки для "activeBuff", 10-50). Для "passive" має бути null.
    - "durationSeconds": число, тривалість бафу в секундах (тільки для "activeBuff", 300-1200). Для "passive" має бути null.
    - "cooldownSeconds": число, час перезарядки в секундах (тільки для "activeBuff", 1800-7200). Для "passive" має бути null.

    Створи різноманітні навички: 10 пасивних та 5 активних бафів.
    Назви мають бути епічними та відповідати стилю.
    Надай відповідь ТІЛЬКИ у вигляді валідного JSON-масиву, без жодних коментарів або пояснень.
    """

    # 3. Виконання Запиту та Запис в Firestore
    # ------------------------------------
    try:
        print("\nGenerating skills with Gemini... Please wait.")
        response = model.generate_content(prompt)

        # Очищення відповіді від можливих маркдаун-тегів
        cleaned_response = (
            response.text.strip().replace("```json", "").replace("```", "").strip()
        )

        # Парсимо JSON
        skills_data = json.loads(cleaned_response)

        if not isinstance(skills_data, list):
            print("Error: Gemini did not return a JSON array.")
            return

        print(f"Successfully generated {len(skills_data)} skills.")

        # Отримуємо посилання на колекцію
        skills_collection_ref = db.collection("skills")

        # Використовуємо WriteBatch для ефективного запису
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

        # Виконуємо всі операції запису
        batch.commit()

        print(
            f"\nSuccessfully uploaded {added_count} skills to Firestore collection 'skills'."
        )

    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from Gemini response: {e}")
        print("--- Gemini Response ---")
        print(response.text)
        print("-----------------------")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    generate_skills()
    print("\n--- Script Finished ---")
