-- ============================================================
-- PaatoDev Macdonald - SQL base
-- Compatible con ESX + oxmysql
-- ============================================================

-- 1) Job en ESX
INSERT IGNORE INTO jobs (name, label) VALUES
('mcdonald', 'Macdonald');

INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES
('mcdonald', 0, 'recruit', 'Aprendiz', 250, '{}', '{}'),
('mcdonald', 1, 'cook', 'Cocinero', 350, '{}', '{}'),
('mcdonald', 2, 'cashier', 'Cajero', 400, '{}', '{}'),
('mcdonald', 3, 'manager', 'Manager', 600, '{}', '{}'),
('mcdonald', 4, 'boss', 'Jefe', 900, '{}', '{}');

-- 2) Sociedad y stock para el recurso
CREATE TABLE IF NOT EXISTS paatodev_macdonald_society (
    job_name VARCHAR(64) NOT NULL,
    balance INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (job_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS paatodev_macdonald_stock (
    job_name VARCHAR(64) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT NOT NULL DEFAULT 0,
    PRIMARY KEY (job_name, item_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS paatodev_macdonald_orders (
    id INT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    customer_identifier VARCHAR(80) NOT NULL,
    customer_name VARCHAR(90) NOT NULL,
    recipe_key VARCHAR(60) NOT NULL,
    recipe_label VARCHAR(90) NOT NULL,
    output_item VARCHAR(64) NOT NULL,
    output_count INT NOT NULL DEFAULT 1,
    quantity INT NOT NULL DEFAULT 1,
    total_price INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    assigned_identifier VARCHAR(80) DEFAULT NULL,
    assigned_name VARCHAR(90) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_job_status (job_name, status),
    INDEX idx_customer_status (customer_identifier, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO paatodev_macdonald_society (job_name, balance) VALUES
('mcdonald', 0);
