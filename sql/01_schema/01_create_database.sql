-- Create the project database (safe to run more than once)
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

CREATE DATABASE IF NOT EXISTS telecom_rebate
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE telecom_rebate;

SELECT DATABASE() AS current_database;