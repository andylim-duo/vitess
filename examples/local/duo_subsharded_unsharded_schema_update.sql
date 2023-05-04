-- This file contains all the schema updates for the Users & Devices service.
-- These updates are for setting up sequence tables that will be used for
-- the auto-increment fields in the sharded tables

-- Setup the sequence table for the user table auto_increment id.
CREATE TABLE IF NOT EXISTS user_seq (id bigint(20), next_id bigint(20), cache bigint(20), primary key(id)) COMMENT 'vitess_sequence';
INSERT INTO user_seq (id, next_id, cache) VALUES (0, 1, 3);

-- Setup the sequence table for the customer table auto_increment id.
CREATE TABLE IF NOT EXISTS cust_seq (id bigint(20), next_id bigint(20), cache bigint(20), primary key(id)) COMMENT 'vitess_sequence';
INSERT INTO cust_seq (id, next_id, cache) VALUES (0, 1, 3);

