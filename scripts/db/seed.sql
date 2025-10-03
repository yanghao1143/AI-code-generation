-- nlp-spec-automation 种子数据（可重复执行，使用主键/唯一键去重）
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

START TRANSACTION;

-- Anchor
INSERT INTO `anchor` (id, name, level, created_at) VALUES
  (1, '主播A', 'S', NOW()),
  (2, '主播B', 'A', NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), level=VALUES(level);

-- Fan
INSERT INTO `fan` (id, name, gender, birthday, zodiac, created_at) VALUES
  (1, '小明', 'M', '1995-01-01', '摩羯', NOW()),
  (2, '小红', 'F', '1997-03-21', '白羊', NOW()),
  (3, '小刚', 'M', '1990-07-15', '巨蟹', NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), gender=VALUES(gender), birthday=VALUES(birthday), zodiac=VALUES(zodiac);

-- Tag（有唯一键 uq_tag_name）
INSERT INTO `tag` (id, name, created_at) VALUES
  (1, '忠实粉', NOW()),
  (2, '新关注', NOW()),
  (3, '高活跃', NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Topic
INSERT INTO `topic` (id, name, popularity, created_at) VALUES
  (1, '星座运势', 100, NOW()),
  (2, '情感建议', 80, NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), popularity=VALUES(popularity);

-- Fortune Service（code 唯一）
INSERT INTO `fortune_service` (id, code, name, input_schema, created_at) VALUES
  (1, 'daily_zodiac', '每日星座', '{"fields":["zodiac"]}', NOW()),
  (2, 'love_advice', '恋爱建议', '{"fields":["name","zodiac"]}', NOW())
ON DUPLICATE KEY UPDATE code=VALUES(code), name=VALUES(name), input_schema=VALUES(input_schema);

-- Script（话术模板）
INSERT INTO `script` (id, title, content, topic_id, created_at) VALUES
  (1, '星座开场白', '你好，我来看一下你的今日星座运势～', 1, NOW()),
  (2, '情感开场白', '你好，聊聊你的感情问题吧～', 2, NOW())
ON DUPLICATE KEY UPDATE title=VALUES(title), content=VALUES(content), topic_id=VALUES(topic_id);

-- Workflow（示例工作流）
INSERT INTO `workflow` (id, name, definition, created_at) VALUES
  (1, '占卜工作流', '{"steps":["collect","analyze","reply"]}', NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), definition=VALUES(definition);

-- Fan Tags（多对多）
INSERT INTO `fan_tags` (fan_id, tag_id, created_at) VALUES
  (1, 1, NOW()),
  (2, 2, NOW()),
  (3, 3, NOW())
ON DUPLICATE KEY UPDATE fan_id=fan_id, tag_id=tag_id;

-- Conversation（外键 anchor_id/fan_id）
INSERT INTO `conversation` (id, anchor_id, fan_id, content, created_at) VALUES
  (1, 1, 1, '主播A：你好，小明，今天星座运势不错！', NOW()),
  (2, 1, 2, '主播A：小红，适合开始新的计划～', NOW()),
  (3, 2, 3, '主播B：小刚，注意情绪稳定。', NOW())
ON DUPLICATE KEY UPDATE content=VALUES(content);

-- Fortune Record（外键 fan_id/service_id）
INSERT INTO `fortune_record` (id, fan_id, service_id, result, created_at) VALUES
  (1, 1, 1, '摩羯座今日指数：★★★★☆', NOW()),
  (2, 2, 2, '白羊座爱情建议：主动出击', NOW()),
  (3, 3, 1, '巨蟹座今日指数：★★★☆☆', NOW())
ON DUPLICATE KEY UPDATE result=VALUES(result);

COMMIT;

SET FOREIGN_KEY_CHECKS = 1;