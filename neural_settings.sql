-- ====================================================================
-- Table: NEURAL_SETTINGS
-- Description: Stores default parameter values used for SVM models
--              in Oracle Data Mining, based on official Oracle
--              documentation (DBMS_DATA_MINING).
-- ====================================================================

-- Create the table
CREATE TABLE neural_settings (
    setting_name   VARCHAR2(50),
    setting_value  VARCHAR2(50),
    note           VARCHAR2(200)
);

-- Insert default settings from Oracle documentation
INSERT INTO neural_settings (setting_name, setting_value, note) VALUES 
('SVMS_CONV_TOLERANCE', '0.01', 'Default value from Oracle DBMS_DATA_MINING documentation');

INSERT INTO neural_settings (setting_name, setting_value, note) VALUES 
('SVMS_KERNEL_FUNCTION', 'SVMS_GAUSSIAN', 'Default value from Oracle DBMS_DATA_MINING documentation');

INSERT INTO neural_settings (setting_name, setting_value, note) VALUES 
('SVMS_EPSILON', '0.01', 'Default value from Oracle DBMS_DATA_MINING documentation');

-- Commit changes
COMMIT;

--Documentation available here: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DATA_MINING.html#GUID-7010593E-C323-4DFC-8468-D85CE41A0C3C