"""Nutrition score prediction API.

Serves the random forest model trained in linear_regression/multivariate.ipynb.

Routes:
    POST /predict  - predict the Nutri-Score nutrition points of one packaged food
    POST /retrain  - upload a CSV of new products, retrain the model and start using it
    GET  /docs     - Swagger UI

Run locally:  uvicorn prediction:app --reload
"""

import gc
import io
import time
from enum import Enum
from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ValidationError, model_validator
from sklearn.base import clone
from sklearn.metrics import mean_squared_error

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"
DATA_PATH = BASE_DIR / "food_nutrition_clean.csv"

TARGET = "nutrition_score"
FEATURES = ["food_group", "additives_n", "palm_oil_ingredients_n", "energy_kj", "fat_g",
            "saturated_fat_g", "carbohydrates_g", "sugars_g", "fiber_g", "proteins_g", "salt_g"]


class FoodGroup(str, Enum):
    beverages = "Beverages"
    cereals_and_potatoes = "Cereals and potatoes"
    composite_foods = "Composite foods"
    fat_and_sauces = "Fat and sauces"
    fish_meat_eggs = "Fish meat eggs"
    fruits_and_vegetables = "Fruits and vegetables"
    milk_and_dairy_products = "Milk and dairy products"
    salty_snacks = "Salty snacks"
    sugary_snacks = "Sugary snacks"


class FoodInput(BaseModel):
    # Values read from a food label. Nutrients are per 100 g (or 100 ml for drinks).
    # strict=True means a number sent as text (like "12") is rejected, not converted.
    # Energy stops at 3800 kJ because pure fat is about 3700 kJ per 100 g.
    food_group: FoodGroup = Field(description="Food group of the product")
    additives_n: int = Field(strict=True, ge=0, le=30, description="Number of additives (E-numbers)")
    palm_oil_ingredients_n: int = Field(strict=True, ge=0, le=5, description="Number of palm oil ingredients")
    energy_kj: float = Field(strict=True, ge=0, le=3800, description="Energy in kJ per 100 g")
    fat_g: float = Field(strict=True, ge=0, le=100, description="Total fat in g per 100 g")
    saturated_fat_g: float = Field(strict=True, ge=0, le=100, description="Saturated fat in g per 100 g")
    carbohydrates_g: float = Field(strict=True, ge=0, le=100, description="Carbohydrates in g per 100 g")
    sugars_g: float = Field(strict=True, ge=0, le=100, description="Sugars in g per 100 g")
    fiber_g: float = Field(strict=True, ge=0, le=100, description="Fibre in g per 100 g")
    proteins_g: float = Field(strict=True, ge=0, le=100, description="Protein in g per 100 g")
    salt_g: float = Field(strict=True, ge=0, le=100, description="Salt in g per 100 g")

    model_config = {
        "json_schema_extra": {
            "example": {
                "food_group": "Sugary snacks",
                "additives_n": 4,
                "palm_oil_ingredients_n": 1,
                "energy_kj": 2100.0,
                "fat_g": 25.0,
                "saturated_fat_g": 11.0,
                "carbohydrates_g": 62.0,
                "sugars_g": 35.0,
                "fiber_g": 2.5,
                "proteins_g": 6.0,
                "salt_g": 0.6,
            }
        }
    }

    # A part of something cannot be bigger than the whole.
    @model_validator(mode="after")
    def check_label(self):
        if self.saturated_fat_g > self.fat_g:
            raise ValueError("saturated_fat_g cannot be more than fat_g")
        if self.sugars_g > self.carbohydrates_g:
            raise ValueError("sugars_g cannot be more than carbohydrates_g")
        return self


class PredictionOutput(BaseModel):
    prediction: float = Field(description="Predicted nutrition score (lower is healthier)")
    grade: str = Field(description="Nutri-Score grade from A (healthiest) to E")
    additives_warning: bool = Field(description="True when the product has 5 or more additives")


def score_to_grade(score, food_group):
    # Official Nutri-Score bands. Drinks have stricter bands, and grade A is only for water.
    points = round(score)
    if food_group == "Beverages":
        if points <= 1:
            return "B"
        elif points <= 5:
            return "C"
        elif points <= 9:
            return "D"
        return "E"
    if points <= -1:
        return "A"
    elif points <= 2:
        return "B"
    elif points <= 10:
        return "C"
    elif points <= 18:
        return "D"
    return "E"


# Load the model and the training data from the repo when the server starts.
# /retrain replaces the model in memory, so /predict uses the new one straight away.
# Render's free plan loses files written at runtime when it restarts, which is accepted.
model = joblib.load(MODEL_PATH)
training_data = pd.read_csv(DATA_PATH, usecols=FEATURES + [TARGET])
last_retrained = None


def predict_nutrition_score(features):
    # Same idea as the function in the notebook, but it uses the model already
    # loaded in memory instead of reading the file on every request.
    row = pd.DataFrame([features])[FEATURES]
    return float(model.predict(row)[0])


app = FastAPI(
    title="Nutrition Score Prediction API",
    description=(
        "Predicts the Nutri-Score nutrition points of a packaged food from the values on its label, "
        "to help young urban Nigerians spot unhealthy ultra-processed products. "
        "Scores run from about -15 to 40, and lower is healthier."
    ),
    version="1.0.0",
)

# CORS only matters for websites: browsers block a page from calling an API on another
# domain unless the API allows that page's origin. The Flutter mobile app is not a browser,
# so it is not affected by these settings.
# - allow_origins: only my own Render URL (so the Swagger UI page works) and the local
#   Flutter web debug address. No "*", so other websites cannot call the API from a
#   visitor's browser and use up the free server.
# - allow_methods: only GET and POST, the only methods the API has.
# - allow_headers: only Content-Type and Accept, which is all a JSON request or a CSV
#   upload needs.
# - allow_credentials: False, because the API has no logins or cookies, so browsers
#   should never send them.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nutrition-score-api.onrender.com",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
    allow_credentials=False,
)


@app.get("/")
def home():
    return {
        "message": "Nutrition Score Prediction API. Open /docs to try it.",
        "trained_rows": len(training_data),
        "last_retrained": last_retrained,
    }


@app.post("/predict", response_model=PredictionOutput)
def predict(food: FoodInput):
    data = food.model_dump(mode="json")
    score = predict_nutrition_score(data)
    return PredictionOutput(
        prediction=round(score, 2),
        grade=score_to_grade(score, data["food_group"]),
        additives_warning=data["additives_n"] >= 5,
    )


@app.post("/retrain")
def retrain(file: UploadFile = File(description="CSV with the same columns as the training data")):
    # The best model is a random forest, which cannot keep learning from new rows on its own,
    # so it is refitted on the original data plus the uploaded rows with the same settings.
    global model, training_data, last_retrained

    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")
    try:
        new_data = pd.read_csv(io.BytesIO(file.file.read()))
    except Exception:
        raise HTTPException(status_code=400, detail="The file could not be read as a CSV.")

    missing = [col for col in FEATURES + [TARGET] if col not in new_data.columns]
    if missing:
        raise HTTPException(status_code=400, detail="Missing columns: " + ", ".join(missing))

    # Check every row with the same rules as /predict and skip the bad ones.
    good_rows = []
    for row in new_data[FEATURES + [TARGET]].to_dict("records"):
        try:
            FoodInput(**{col: row[col] for col in FEATURES})
        except ValidationError:
            continue
        if -15 <= row[TARGET] <= 40:
            good_rows.append(row)

    if not good_rows:
        raise HTTPException(status_code=400, detail="No valid rows in the file, so the model was not retrained.")
    good_rows = pd.DataFrame(good_rows)

    mse_before = mean_squared_error(good_rows[TARGET], model.predict(good_rows[FEATURES]))

    combined = pd.concat([training_data, good_rows], ignore_index=True)
    start = time.time()
    new_model = clone(model)  # same preprocessing and settings, but untrained
    # Build the trees one at a time. Render's free server has 512 MB of memory and only
    # 0.1 CPU, so training in parallel uses more memory without being any faster.
    new_model.set_params(model__n_jobs=1)
    new_model.fit(combined[FEATURES], combined[TARGET])
    seconds = time.time() - start

    mse_after = mean_squared_error(good_rows[TARGET], new_model.predict(good_rows[FEATURES]))

    # Switch to the new model. best_model.pkl in the repo is not overwritten,
    # so the server goes back to the notebook's model after a restart.
    model = new_model
    training_data = combined
    last_retrained = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    gc.collect()  # free the old model's memory straight away

    return {
        "message": "Model retrained and now used by /predict.",
        "rows_received": len(new_data),
        "rows_used": len(good_rows),
        "rows_skipped": len(new_data) - len(good_rows),
        "total_training_rows": len(combined),
        "training_seconds": round(seconds, 1),
        "mse_on_new_rows_before": round(float(mse_before), 3),
        "mse_on_new_rows_after": round(float(mse_after), 3),
    }
