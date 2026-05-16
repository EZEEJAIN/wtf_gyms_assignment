-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS lead_master (
  id         UUID SERIAL PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name    VARCHAR(100),
  phone        VARCHAR(20) UNIQUE,
  email        VARCHAR(100),
  source       VARCHAR(50) NOT NULL,
  status       VARCHAR(50),
  assigned_to  VARCHAR(100),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
);

