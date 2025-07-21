
# 🔍 Time Series Forecasting & Outlier Detection in Oracle SQL

This repository contains a fully-automated **PL/SQL pipeline** for performing time series forecasting and outlier detection using **Oracle Data Mining (ODM)**. It is designed for execution directly within **Oracle Database** or **Oracle Cloud environments** that support the `DBMS_DATA_MINING` package.
Documentation available here: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DATA_MINING.html#GUID-7010593E-C323-4DFC-8468-D85CE41A0C3C

The solution is implemented entirely in **PL/SQL**, and supports dynamic model creation, data preparation, prediction, and result aggregation — all without relying on external scripts or tools.

---

## 📈 Key Features

- Automated **regression model training** for multiple time series
- Flexible outlier detection based on **z-score** and **delta thresholds**
- Dynamic generation and cleanup of **temporary tables and models**
- Supports **forecasting of future values** (e.g., next 10 months)
- Generalized structure ready for integration or extension

---

## 🧱 Data Requirements

Your Oracle Database must include:

- A source table named `source_timeseries_data`, containing at least:

| Column Name      | Type         | Description                    |
|------------------|--------------|--------------------------------|
| `ts`             | `DATE`       | Timestamp                      |
| `year_label`     | `VARCHAR2`   | Fiscal or calendar year label |
| `period_label`   | `VARCHAR2`   | Period (e.g., `03_Mar`)        |
| `scenario`       | `VARCHAR2`   | Scenario label                 |
| `metric`         | `VARCHAR2`   | Metric name                    |
| `data_group`     | `VARCHAR2`   | Group/category identifier      |
| `actual_value`   | `NUMBER`     | Observed value                 |

- A settings table named `neural_settings` to configure the Oracle Data Mining model. For example:

```sql
INSERT INTO neural_settings (setting_name, setting_value)
VALUES ('ALGO_NAME', 'ALGO_NEURAL_NETWORK');
```

---

## 📤 Output

The results are saved into a table named `forecast_outliers` with the following schema:

| Column Name        | Type         | Description                              |
|--------------------|--------------|------------------------------------------|
| `ts`               | DATE         | Timestamp                                |
| `year_label`       | VARCHAR2     | Year label                               |
| `period_label`     | VARCHAR2     | Period label                             |
| `scenario`         | VARCHAR2     | Scenario identifier                      |
| `metric`           | VARCHAR2     | Metric name                              |
| `data_group`       | VARCHAR2     | Data segment / group                     |
| `actual_value`     | NUMBER       | Real observed value                      |
| `z_score`          | NUMBER       | Standardized deviation from prediction   |
| `predicted_value`  | NUMBER       | Model prediction                         |
| `is_outlier`       | VARCHAR2(1)  | `Y` = Outlier, `N` = Normal, `P` = Predicted-only |
| `delta`            | NUMBER       | Absolute difference                      |
| `delta_percent`    | NUMBER       | Percentage difference vs actual value    |

---

## 🔁 Process Flow

1. **Clean** any previously existing models or temp tables (`MODEL_%`, `TEMP_%`)
2. Create an empty output table: `forecast_outliers`
3. For each unique `(metric, data_group)` combination:
   - Filter data from the source table (excluding anomalous months like `01_Jan` and `07_Jul`)
   - Create a **temporary working table** with historical data
   - Insert **10 forward-looking periods** (with missing values)
   - Train a **neural network regression model**
   - Predict values using the model
   - Calculate:
     - Z-scores
     - Absolute and relative deltas
     - Outlier flags (`Y`, `N`, `P`)
   - Insert results into the final output table
   - Drop temporary tables and model
4. Done — `forecast_outliers` holds all records

---

## ⚙️ Configuration

- You can customize:
  - The excluded periods (`01_Jan`, `07_Jul`)
  - The model parameters via the `neural_settings` table
  - Threshold logic for flagging outliers (`z_score < 1` is considered normal)

---
## 📊 Model Evaluation

To assess the accuracy and reliability of the forecasted values, the following metrics are recommended:

### 🔹 Mean Absolute Percentage Error (MAPE)
Indicates the average percent error between the actual and predicted values.

- **Formula:**  
  `MAPE = (1/n) * Σ ( |actual - predicted| / |actual| ) * 100`

- **Interpretation:**  
  | MAPE Range | Interpretation      |
  |------------|---------------------|
  | 0–10%      | Excellent accuracy  |
  | 10–20%     | Good                |
  | 20–50%     | Moderate            |
  | >50%       | Poor                |

### 🔹 Correlation (Pearson)
Measures how well the predicted values follow the trend of the actual data.

- **Formula:**  
  `CORR(actual, predicted)`

- **Interpretation:**
  - `+1`: Perfect positive correlation
  - `0`: No correlation
  - `-1`: Perfect negative correlation

### 🔹 Min/Max Normalized Error
Normalizes the absolute error against the max of actual and predicted values.

- **Formula:**  
  `Error_i = |actual - predicted| / MAX(|actual|, |predicted|)`

- **Interpretation:**
  - Values near **0**: Excellent precision
  - Values near **1**: Large discrepancies

You can calculate these metrics in a post-processing step using SQL or Python for better performance analysis.

---

## 📁 Project Structure

```
/oracle_timeseries_forecast/
│
├── anomaly_detection_final.sql         -- Generalized PL/SQL script
├── README.md                          -- This file
├── neural_settings_template.sql       -- Sample neural network config
├── source_timeseries_data_schema.sql  -- Sample schema for the input table
├── forecast_metrics_evaluation.sql  -- How to evaluate the model
```

---

## 💡 Use Cases

- Financial metric forecasting
- Sales anomaly detection
- Operational data monitoring
- Forecast validation or benchmarking

---

## 🔒 Safe & Autonomous

The code is designed to be **robust and self-contained**, handling:
- Missing data
- Existing table/model cleanup
- Future period generation with sanity checks

All heavy lifting is done in-database, keeping data local and secure.

---

## 📜 License

This project is released under the **MIT License** — free to use, fork, and adapt for your organization.

---

## 🧰 Want Help or Customization?

Open an issue or submit a pull request if you'd like to:
- Add parameterization
- Use different algorithms (e.g., SVM, decision tree)
- Export results to external systems

We welcome collaboration!
