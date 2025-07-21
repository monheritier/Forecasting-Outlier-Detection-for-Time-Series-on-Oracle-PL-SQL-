DECLARE
   v_group           VARCHAR2(20 CHAR);
   v_metric          VARCHAR2(50 CHAR);
   v_temp_table      VARCHAR2(100 CHAR);
   v_model_name      VARCHAR2(100 CHAR);
   v_sql             VARCHAR2(4000 CHAR);
   v_cnt             NUMBER;
BEGIN
   -- Clean up existing models
   FOR r IN (SELECT model_name FROM user_mining_models WHERE model_name LIKE 'MODEL_%')
   LOOP
      BEGIN
         DBMS_DATA_MINING.DROP_MODEL(r.model_name);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
   END LOOP;

   -- Drop temporary tables
   FOR r IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'TEMP_%')
   LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
   END LOOP;

   -- Drop final output table if it exists
   BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE forecast_outliers';
   EXCEPTION WHEN OTHERS THEN NULL;
   END;

   -- Create final output table
   EXECUTE IMMEDIATE '
      CREATE TABLE forecast_outliers (
         ts DATE,
         year_label VARCHAR2(20),
         period_label VARCHAR2(50),
         scenario VARCHAR2(100),
         metric VARCHAR2(50),
         data_group VARCHAR2(20),
         actual_value NUMBER,
         z_score NUMBER,
         predicted_value NUMBER,
         is_outlier VARCHAR2(1),
         delta NUMBER,
         delta_percent NUMBER
      )';

   -- Loop over group/metric combinations
   FOR r IN (SELECT DISTINCT data_group, metric FROM source_timeseries_data)
   LOOP
      v_group := r.data_group;
      v_metric := r.metric;
      v_temp_table := 'TEMP_' || v_metric || v_group;
      v_model_name := 'MODEL_' || v_metric || v_group;

      -- Create temporary data table
      EXECUTE IMMEDIATE '
         CREATE TABLE ' || v_temp_table || ' AS
         WITH ranked_data AS (
            SELECT 
               ts, 
               CAST(year_label AS VARCHAR2(20)) AS year_label,
               CAST(period_label AS VARCHAR2(50)) AS period_label,
               CAST(scenario AS VARCHAR2(100)) AS scenario,
               metric, 
               data_group, 
               TO_NUMBER(actual_value) AS actual_value,
               ROW_NUMBER() OVER (PARTITION BY ts ORDER BY NULL) AS rn
            FROM source_timeseries_data
            WHERE metric = ''' || v_metric || ''' 
              AND data_group = ''' || v_group || '''
              AND period_label NOT IN (''01_Jan'', ''07_Jul'')
         )
         SELECT 
            ts, year_label, period_label, scenario, metric, data_group,
            actual_value,
            ABS(ROUND((actual_value - AVG(actual_value) OVER()) / NULLIF(STDDEV(actual_value) OVER(), 0), 2)) AS z_score,
            CAST(NULL AS NUMBER) AS predicted_value,
            CAST(NULL AS VARCHAR2(1)) AS is_outlier,
            CAST(NULL AS NUMBER) AS delta,
            CAST(NULL AS NUMBER) AS delta_percent
         FROM ranked_data
         WHERE rn = 1';

      -- Insert 10 future periods (excluding certain months)
      DECLARE
         v_start_ts     DATE;
         v_new_ts       DATE;
         v_period       VARCHAR2(50);
         v_year         VARCHAR2(20);
         v_scenario     VARCHAR2(100);
         v_inserted     INTEGER := 0;
      BEGIN
         SELECT MAX(ts) INTO v_start_ts
         FROM source_timeseries_data
         WHERE metric = v_metric AND data_group = v_group AND actual_value IS NOT NULL;

         FOR i IN 1 .. 24 LOOP
            EXIT WHEN v_inserted = 10;
            v_new_ts := ADD_MONTHS(v_start_ts, i);
            v_period := TO_CHAR(v_new_ts, 'MM_Mon', 'NLS_DATE_LANGUAGE=ENGLISH');

            IF v_period IN ('01_Jan', '07_Jul') THEN CONTINUE; END IF;

            v_year := 'FY' || TO_CHAR(v_new_ts, 'YY');
            v_scenario := v_year || '-SCENARIO';

            v_sql := 'SELECT COUNT(*) FROM ' || v_temp_table || ' WHERE ts = :1';
            EXECUTE IMMEDIATE v_sql INTO v_cnt USING v_new_ts;

            IF v_cnt = 0 THEN
               v_sql := '
                  INSERT INTO ' || v_temp_table || '
                  (ts, year_label, period_label, scenario, metric, data_group, actual_value, z_score, predicted_value, is_outlier, delta, delta_percent)
                  VALUES (:1, :2, :3, :4, :5, :6, NULL, NULL, NULL, ''P'', NULL, NULL)';
               EXECUTE IMMEDIATE v_sql USING v_new_ts, v_year, v_period, v_scenario, v_metric, v_group;
               v_inserted := v_inserted + 1;
            END IF;
         END LOOP;
      END;

      -- Train model
      v_sql := '
         BEGIN
            DBMS_DATA_MINING.CREATE_MODEL(
               model_name => ''' || v_model_name || ''',
               mining_function => DBMS_DATA_MINING.REGRESSION,
               data_table_name => ''' || v_temp_table || ''',
               case_id_column_name => ''ts'',
               target_column_name => ''actual_value'',
               settings_table_name => ''neural_settings''
            );
         END;';
      EXECUTE IMMEDIATE v_sql;

      -- Predict values
      EXECUTE IMMEDIATE '
         MERGE INTO ' || v_temp_table || ' t
         USING (
            SELECT ts, ROUND(PREDICTION(' || v_model_name || ' USING *), 2) AS pred_val
            FROM ' || v_temp_table || '
         ) p
         ON (t.ts = p.ts)
         WHEN MATCHED THEN
            UPDATE SET predicted_value = p.pred_val';

      -- Recalculate z-score
      EXECUTE IMMEDIATE '
         UPDATE ' || v_temp_table || '
         SET z_score = CASE
            WHEN actual_value IS NOT NULL AND predicted_value IS NOT NULL AND predicted_value <> 0 THEN
               ROUND(ABS(actual_value - predicted_value) / ABS(predicted_value), 4)
            ELSE 0
         END';

      -- Calculate deltas
      EXECUTE IMMEDIATE '
         UPDATE ' || v_temp_table || '
         SET 
            delta = CASE 
               WHEN actual_value IS NOT NULL AND predicted_value IS NOT NULL THEN 
                  actual_value - predicted_value
               ELSE NULL 
            END,
            delta_percent = CASE 
               WHEN actual_value IS NOT NULL AND predicted_value IS NOT NULL AND actual_value <> 0 THEN 
                  ROUND(ABS(predicted_value - actual_value) / ABS(actual_value) * 100, 4)
               ELSE NULL 
            END';

      -- Flag outliers
      EXECUTE IMMEDIATE '
         UPDATE ' || v_temp_table || '
         SET is_outlier = CASE
            WHEN actual_value IS NULL THEN ''P''
            WHEN predicted_value IS NULL THEN NULL
            WHEN actual_value = 0 AND predicted_value = 0 THEN ''N''
            WHEN z_score < 1 THEN ''N''
            ELSE ''Y''
         END';

      -- Insert into final table
      EXECUTE IMMEDIATE '
         INSERT INTO forecast_outliers
         SELECT * FROM ' || v_temp_table;

      -- Cleanup
      BEGIN
         DBMS_DATA_MINING.DROP_MODEL(v_model_name);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;

      EXECUTE IMMEDIATE 'DROP TABLE ' || v_temp_table;

   END LOOP;
END;
