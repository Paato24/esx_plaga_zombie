CREATE TABLE IF NOT EXISTS `zombie_infections` (
    `identifier` VARCHAR(64) NOT NULL,
    `infected` TINYINT(1) NOT NULL DEFAULT 0,
    `stage` TINYINT(2) NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Opcional para inventario ESX clasico (items en base de datos):
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
-- ('antidoto_zombie', 'Antidoto zombie', 1);
