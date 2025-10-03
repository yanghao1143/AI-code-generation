-- nlp-spec-automation 初版 DDL（MySQL）
-- 说明：依据 .spec-workflow/specs/nlp-spec-automation/design.md 的实体与关系生成。
-- 字符集/引擎：utf8mb4 / InnoDB；后续可根据审阅结论补充长度/精度/唯一约束等细化。

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Anchor
CREATE TABLE IF NOT EXISTS `anchor` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `level` VARCHAR(255) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_anchor_level` (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fan
CREATE TABLE IF NOT EXISTS `fan` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `gender` VARCHAR(255) NULL,
  `birthday` VARCHAR(255) NULL,
  `zodiac` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tag
CREATE TABLE IF NOT EXISTS `tag` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_tag_name` (`name`),
  UNIQUE KEY `uq_tag_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Conversation
CREATE TABLE IF NOT EXISTS `conversation` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `anchor_id` BIGINT NOT NULL,
  `fan_id` BIGINT NOT NULL,
  `content` TEXT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conversation_anchor_fan_created` (`anchor_id`, `fan_id`, `created_at`),
  KEY `idx_conversation_created` (`created_at`),
  CONSTRAINT `fk_conversation_anchor` FOREIGN KEY (`anchor_id`)
    REFERENCES `anchor`(`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_conversation_fan` FOREIGN KEY (`fan_id`)
    REFERENCES `fan`(`id`) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FortuneService
CREATE TABLE IF NOT EXISTS `fortune_service` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `input_schema` TEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_fortune_service_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FortuneRecord
CREATE TABLE IF NOT EXISTS `fortune_record` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `fan_id` BIGINT NOT NULL,
  `service_id` BIGINT NOT NULL,
  `result` TEXT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_fortune_record_fan_created` (`fan_id`, `created_at`),
  KEY `idx_fortune_record_service` (`service_id`),
  KEY `idx_fortune_record_created` (`created_at`),
  CONSTRAINT `fk_fortune_record_fan` FOREIGN KEY (`fan_id`)
    REFERENCES `fan`(`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_fortune_record_service` FOREIGN KEY (`service_id`)
    REFERENCES `fortune_service`(`id`) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Topic
CREATE TABLE IF NOT EXISTS `topic` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `popularity` INT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_topic_popularity` (`popularity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Script
CREATE TABLE IF NOT EXISTS `script` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL,
  `content` TEXT NOT NULL,
  `topic_id` BIGINT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_script_topic` (`topic_id`),
  CONSTRAINT `fk_script_topic` FOREIGN KEY (`topic_id`)
    REFERENCES `topic`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Workflow
CREATE TABLE IF NOT EXISTS `workflow` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `definition` TEXT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Junction: fan_tags (Fan <-> Tag)
CREATE TABLE IF NOT EXISTS `fan_tags` (
  `fan_id` BIGINT NOT NULL,
  `tag_id` BIGINT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`fan_id`, `tag_id`),
  KEY `idx_fan_tags_tag` (`tag_id`),
  KEY `idx_fan_tags_fan` (`fan_id`),
  CONSTRAINT `fk_fan_tags_fan` FOREIGN KEY (`fan_id`)
    REFERENCES `fan`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_fan_tags_tag` FOREIGN KEY (`tag_id`)
    REFERENCES `tag`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;