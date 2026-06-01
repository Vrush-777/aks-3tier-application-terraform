-- PostgreSQL initialization script for Employee Management System
-- This script creates the necessary database schema and tables

-- Create employeess table (maintaining the original table name from application)
CREATE TABLE IF NOT EXISTS employeess (
    id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email_id VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_employeess_email_id ON employeess(email_id);

-- Create audit function for updated_at
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS employeess_update_timestamp ON employeess;
CREATE TRIGGER employeess_update_timestamp
BEFORE UPDATE ON employeess
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Insert sample data (optional)
INSERT INTO employeess (first_name, last_name, email_id) 
VALUES 
    ('John', 'Doe', 'john.doe@company.com'),
    ('Jane', 'Smith', 'jane.smith@company.com'),
    ('Bob', 'Johnson', 'bob.johnson@company.com')
ON CONFLICT (email_id) DO NOTHING;

-- Display created tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';
