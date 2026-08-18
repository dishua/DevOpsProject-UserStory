CREATE DATABASE IF NOT EXISTS userstory
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE userstory;

CREATE TABLE IF NOT EXISTS projects (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    description VARCHAR(255),
    name        VARCHAR(255),
    PRIMARY KEY (id)
);

INSERT INTO projects (description, name) VALUES ('INIT.SQL', 'Project1');