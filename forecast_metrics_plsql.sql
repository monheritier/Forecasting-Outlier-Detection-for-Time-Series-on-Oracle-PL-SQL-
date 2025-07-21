
-- Calculates MAPE, Pearson Correlation, and Min/Max Normalized Error from the forecast_outliers table
SET SERVEROUTPUT ON;
DECLARE
    v_mape NUMBER := 0;
    v_corr NUMBER := 0;
    v_min_max_error NUMBER := 0;
    v_cnt NUMBER := 0;

    CURSOR c_data IS
        SELECT actual_value, predicted_value
        FROM forecast_outliers
        WHERE actual_value IS NOT NULL
          AND predicted_value IS NOT NULL
          AND actual_value <> 0;

    v_actual forecast_outliers.actual_value%TYPE;
    v_predicted forecast_outliers.predicted_value%TYPE;

    -- For correlation
    v_sum_actual NUMBER := 0;
    v_sum_predicted NUMBER := 0;
    v_sum_actual_sq NUMBER := 0;
    v_sum_predicted_sq NUMBER := 0;
    v_sum_product NUMBER := 0;

    -- For MAPE and Min/Max
    v_mape_sum NUMBER := 0;
    v_min_max_sum NUMBER := 0;
BEGIN
    FOR r IN c_data LOOP
        v_actual := r.actual_value;
        v_predicted := r.predicted_value;

        -- MAPE
        v_mape_sum := v_mape_sum + ABS(v_actual - v_predicted) / ABS(v_actual);

        -- Min/Max Error
        v_min_max_sum := v_min_max_sum + (ABS(v_actual - v_predicted) / GREATEST(ABS(v_actual), ABS(v_predicted)));

        -- Correlation components
        v_sum_actual := v_sum_actual + v_actual;
        v_sum_predicted := v_sum_predicted + v_predicted;
        v_sum_actual_sq := v_sum_actual_sq + POWER(v_actual, 2);
        v_sum_predicted_sq := v_sum_predicted_sq + POWER(v_predicted, 2);
        v_sum_product := v_sum_product + (v_actual * v_predicted);

        v_cnt := v_cnt + 1;
    END LOOP;

    IF v_cnt > 0 THEN
        v_mape := (v_mape_sum / v_cnt) * 100;
        v_min_max_error := v_min_max_sum / v_cnt;

        v_corr := (v_cnt * v_sum_product - v_sum_actual * v_sum_predicted) /
                  (SQRT(v_cnt * v_sum_actual_sq - POWER(v_sum_actual, 2)) *
                   SQRT(v_cnt * v_sum_predicted_sq - POWER(v_sum_predicted, 2)));
    END IF;

    DBMS_OUTPUT.PUT_LINE('MAPE: ' || ROUND(v_mape, 2) || '%');
    DBMS_OUTPUT.PUT_LINE('Min/Max Normalized Error: ' || ROUND(v_min_max_error, 4));
    DBMS_OUTPUT.PUT_LINE('Correlation: ' || ROUND(v_corr, 4));
END;
/

