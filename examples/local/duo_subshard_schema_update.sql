-- This file contains all the schema updates for the Users & Devices service.

-- Schema Base - Skipped for now. We'll have to think about how to keep track
-- of the schema revisions.

-- NOTE: All tables in the schema are destined for a sharded keyspace where
--       the primary shard key will be the customer_id and the secondary
--       sub-shard key will be user_id.

-- Setup customer table, which will not be in the sharded keyspace
CREATE TABLE IF NOT EXISTS `customers` (
    `customer_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    `akey` varchar(20) NOT NULL,
    PRIMARY KEY (`customer_id`),
    UNIQUE KEY akey_idx (`akey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Schema Up 1 - add user table
CREATE TABLE IF NOT EXISTS `users` (
    `customer_id` bigint(20) unsigned NOT NULL,
    `user_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    `ukey` varchar(20) NOT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`),
    UNIQUE KEY ukey_idx (`ukey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS `users_names` (
    `customer_id` bigint(20) unsigned NOT NULL,
    `user_id` bigint(20) unsigned NOT NULL,
    `name` varchar(128) NOT NULL,
    `position` tinyint(3) unsigned NOT NULL,
    `last_updated` TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `name_customer_id_unique` (`customer_id`,`name`),
    CONSTRAINT `users_names_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS `users_attributes` (
    `customer_id` bigint(20) unsigned NOT NULL,
    `user_id` bigint(20) unsigned NOT NULL,
    `attribute` varchar(256) NOT NULL,
    `value` mediumblob,
    `last_updated` TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `user_id_attribute_unique` (`user_id`,`attribute`),
    CONSTRAINT `users_attributes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS `users_status` (
    `customer_id` bigint(20) unsigned NOT NULL,
    `user_id` bigint(20) unsigned NOT NULL,
    `status` tinyint(3) unsigned NOT NULL,
    `last_updated` TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `user_id` (`user_id`),
    CONSTRAINT `users_status_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Schema 2 Update: user_status change
ALTER TABLE `users_status`
    ADD `deleted_date` TIMESTAMP NULL DEFAULT NULL,
    LOCK=NONE, ALGORITHM=INPLACE;

-- Schema 3 Update: users_names change
ALTER TABLE `users_names`
    ADD CONSTRAINT `position_user_id_unique` UNIQUE (user_id, position),
    LOCK=NONE, ALGORITHM=INPLACE;

-- Schema 4 Update: Modify timestamp columns
ALTER TABLE `users`
    MODIFY COLUMN `created` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6);

ALTER TABLE `users_attributes`
    MODIFY COLUMN `last_updated` TIMESTAMP(6) NOT NULL ON UPDATE CURRENT_TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6);

ALTER TABLE `users_names`
    MODIFY COLUMN `last_updated` TIMESTAMP(6) NOT NULL ON UPDATE CURRENT_TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6);

ALTER TABLE `users_status`
    MODIFY COLUMN `last_updated` TIMESTAMP(6) NOT NULL ON UPDATE CURRENT_TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6);

ALTER TABLE `users_status`
    MODIFY COLUMN `deleted_date` TIMESTAMP(6) NULL DEFAULT NULL;

-- Schema 5 Update
ALTER TABLE users
    ADD COLUMN `last_main_update_id` bigint(20) NOT NULL DEFAULT 0,
    ALGORITHM=INSTANT;

-- Schema 6 update
ALTER TABLE users
    ADD COLUMN `last_main_update_was_put` tinyint(1) NOT NULL DEFAULT 1,
    ALGORITHM=INSTANT;
