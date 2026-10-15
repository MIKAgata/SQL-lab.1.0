-- ======================================================================
-- CYBERLAB DATABASE INITIALIZATION SCRIPT (PostgreSQL)
-- SQL Injection to Root Privilege Escalation Lab
-- ======================================================================

DROP TABLE IF EXISTS app_users CASCADE;
DROP TABLE IF EXISTS challenge_flags CASCADE;
DROP TABLE IF EXISTS system_credentials CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- 1. Product Categories Table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

-- 2. Products Catalog Table (5 columns for UNION injection mapping)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE
);

-- 3. Challenge Flags Table (Target for Stage 2 enumeration)
CREATE TABLE challenge_flags (
    id SERIAL PRIMARY KEY,
    stage VARCHAR(50) NOT NULL,
    flag_value VARCHAR(100) NOT NULL
);

-- 4. System Credentials Table (Target for Stage 2 credential dumping)
CREATE TABLE system_credentials (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    credential_value VARCHAR(100) NOT NULL,
    purpose VARCHAR(100) NOT NULL
);

-- 5. Web Portal Users Table (Target for Stage 1 login authentication bypass)
CREATE TABLE app_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'user'
);

-- ----------------------------------------------------------------------
-- Seed Data: Categories
-- ----------------------------------------------------------------------
INSERT INTO categories (id, name, description) VALUES
(1, 'Network Hardware', 'Enterprise routers, managed switches, and optical interconnects'),
(2, 'Security Appliances', 'Hardware firewalls, cryptotokens, and secure console gateways'),
(3, 'Server Components', 'High-density rack servers, memory modules, and enterprise storage');

-- ----------------------------------------------------------------------
-- Seed Data: Products
-- ----------------------------------------------------------------------
INSERT INTO products (name, description, price, category_id) VALUES
('Gigabit Managed Switch 24-Port', 'Layer 2/3 enterprise switch with 802.1Q VLAN support', 299.99, 1),
('Enterprise Wireless AP Wi-Fi 6', 'Dual-band 4x4 MU-MIMO 802.11ax access point', 189.50, 1),
('Fiber SFP+ Transceiver 10Gbps', '10GBASE-SR 850nm multi-mode optical transceiver module', 45.00, 1),
('Next-Gen Hardware Firewall', 'Unified Threat Management appliance with DPI and VPN throughput', 599.00, 2),
('FIPS 140-2 Cryptographic HSM USB', 'Hardware Security Module with tamper-evident secure element', 89.99, 2),
('Out-of-Band Serial Console 8-Port', 'Secure remote console terminal server for data center racks', 349.00, 2),
('ECC Registered DDR4 32GB RAM', 'Server memory module 3200MHz CL22 with error-correcting code', 115.00, 3),
('Enterprise U.2 NVMe SSD 1.92TB', 'PCIe Gen4 enterprise endurance drive with power-loss protection', 249.99, 3),
('Redundant Server PSU 800W Platinum', '80 PLUS Platinum high-efficiency hot-swappable power supply', 135.00, 3);

-- ----------------------------------------------------------------------
-- Seed Data: Challenge Flags
-- ----------------------------------------------------------------------
INSERT INTO challenge_flags (stage, flag_value) VALUES
('database_enumeration', 'FLAG{DATABASE_ENUMERATION}');



-- ----------------------------------------------------------------------
-- Seed Data: System Credentials
-- ----------------------------------------------------------------------
INSERT INTO system_credentials (username, credential_value, purpose) VALUES
('student', 'student_ctf_p4ssw0rd!', 'Linux SSH Shell Access'),
('db_admin', 'p0stgr3s_adm1n_loc4l!', 'Database Internal Administration'),
('backup_operator', 'b4ckup_0p3rat0r_99!', 'Automated Backup Routine');

-- ----------------------------------------------------------------------
-- Seed Data: Web Application Users
-- ----------------------------------------------------------------------
INSERT INTO app_users (username, password, role) VALUES
('admin', 'Adm1n_Unbr3akabl3_K3y_2026!#', 'administrator'),
('analyst', 'AnalystP@ssw0rd987', 'staff');
