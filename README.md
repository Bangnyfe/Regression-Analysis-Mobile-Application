# Nutrition Score Prediction

## Mission and problem
My mission is to promote healthier lifestyles in Nigeria by helping young urban Nigerians make informed food choices and rely less on ultra-processed food.
Packaged foods in Nigeria print a nutrition table but no overall health rating, so it is hard for shoppers to tell how unhealthy a product is.
This project predicts a product's Nutri-Score nutrition points (about -15 to 40, lower is healthier) from the values on its label.
A mobile app lets a shopper type in the label values and get the score and grade straight away.

## Dataset
Open Food Facts product data (Kaggle upload `openfoodfacts/world-food-facts`): https://www.kaggle.com/datasets/openfoodfacts/world-food-facts

Real, crowdsourced data from product labels: 356,027 products and 163 columns. After cleaning (rows with the target, all nutrients and a known food group, and no impossible values) it has 35,808 products. The target is `nutrition-score-fr_100g` and the features are the food group, number of additives, palm oil ingredients, energy and nutrients per 100 g (mix of numeric and categorical columns). The cleaned data is in `summative/API/food_nutrition_clean.csv`.

## API (Swagger UI)
https://nutrition-score-api.onrender.com/docs

The API runs on Render's free plan, so the first request after a quiet period can take up to a minute while the server wakes up.

## Video demo
YouTube:

## How to run the mobile app

**You need:** Flutter (3.x, stable channel) with the Android SDK, and either an Android phone or an Android emulator.

1. Clone the repository:
   ```bash
   git clone https://github.com/Bangnyfe/Regression-Analysis-Mobile-Application.git
   cd Regression-Analysis-Mobile-Application/summative/FlutterApp
   ```
2. Install the packages:
   ```bash
   flutter pub get
   ```
3. Connect a device:
   - **Phone:** turn on Developer options and USB debugging, then plug it in with a USB cable and allow the computer when asked.
   - **Emulator:** create one in Android Studio, or start an existing one with `flutter emulators --launch <emulator_id>`.
4. Check that Flutter can see the device:
   ```bash
   flutter devices
   ```
5. Run the app:
   ```bash
   flutter run
   ```
6. Fill in all 11 fields from a food label and press **Predict**. Example (a chocolate biscuit): food group `Sugary snacks`, additives `4`, palm oil ingredients `1`, energy `2100`, fat `25`, saturated fat `11`, carbohydrates `62`, sugars `35`, fibre `2.5`, protein `6`, salt `0.6`. The app shows the predicted score and Nutri-Score grade, or an error message if a value is missing, not a number or out of range.

## Project structure
```
summative/
|-- pyproject.toml, uv.lock        Python dependencies (managed with uv)
|-- linear_regression/
|   `-- multivariate.ipynb         data cleaning, EDA, 4 models, model comparison
|-- API/
|   |-- prediction.py              FastAPI app (/predict, /retrain, /docs)
|   |-- requirements.txt           exported from uv for Render
|   |-- best_model.pkl             saved random forest pipeline
|   |-- food_nutrition_clean.csv   cleaned training data (used by /retrain)
|   `-- retrain_sample.csv         300 held-back rows to test /retrain
`-- FlutterApp/                    Android app
```

To run the notebook or the API locally, install [uv](https://docs.astral.sh/uv/), then from the `summative` folder run `uv sync`. Start the API with `cd API` and `uv run uvicorn prediction:app --reload`, then open http://127.0.0.1:8000/docs.
