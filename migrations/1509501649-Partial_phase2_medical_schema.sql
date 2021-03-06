-- Migration: Partial phase2 medical schema
-- Created at: 2017-11-01 10:00:49
-- ====  UP  ====

BEGIN;

CREATE TABLE IF NOT EXISTS `labor` (
  id INT AUTO_INCREMENT PRIMARY KEY,
  admittanceDate DATETIME NOT NULL,
  startLaborDate DATETIME NOT NULL,
  endLaborDate DATETIME NULL,
  falseLabor TINYINT NOT NULL DEFAULT 0,
  pos VARCHAR(10) NULL,
  fh INT NULL,
  fht INT NULL,
  systolic INT NULL,
  diastolic INT NULL,
  cr INT NULL,
  temp DECIMAL(4,1) NULL,
  comments VARCHAR(300),
  updatedBy INT NOT NULL,
  updatedAt DATETIME NOT NULL,
  supervisor INT NULL,
  pregnancy_id INT NOT NULL,
  FOREIGN KEY (pregnancy_id) REFERENCES pregnancy (id) ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY (updatedBy) REFERENCES user (id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE laborLog LIKE labor;
ALTER TABLE laborLog ADD COLUMN op CHAR(1) DEFAULT '';
ALTER TABLE laborLog ADD COLUMN replacedAt DATETIME NOT NULL;
ALTER TABLE laborLog MODIFY COLUMN id INT DEFAULT 0;
ALTER TABLE laborLog DROP PRIMARY KEY;
ALTER TABLE laborLog ADD PRIMARY KEY (id, replacedAt);

-- ---------------------------------------------------------------
-- Trigger: labor_after_insert
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS labor_after_insert;
CREATE TRIGGER labor_after_insert AFTER INSERT ON labor
FOR EACH ROW
BEGIN
  INSERT INTO laborLog
  (id, admittanceDate, startLaborDate, endLaborDate, falseLabor, pos, fh, fht, systolic, diastolic, cr, temp, comments, updatedBy, updatedAt, supervisor, pregnancy_id, op, replacedAt)
  VALUES (NEW.id, NEW.admittanceDate, NEW.startLaborDate, NEW.endLaborDate, NEW.falseLabor, NEW.pos, NEW.fh, NEW.fht, NEW.systolic, NEW.diastolic, NEW.cr, NEW.temp, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.pregnancy_id, "I", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: labor_after_update
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS labor_after_update;
CREATE TRIGGER labor_after_update AFTER UPDATE ON labor
FOR EACH ROW
BEGIN
  INSERT INTO laborLog
  (id, admittanceDate, startLaborDate, endLaborDate, falseLabor, pos, fh, fht, systolic, diastolic, cr, temp, comments, updatedBy, updatedAt, supervisor, pregnancy_id, op, replacedAt)
  VALUES (NEW.id, NEW.admittanceDate, NEW.startLaborDate, NEW.endLaborDate, NEW.falseLabor, NEW.pos, NEW.fh, NEW.fht, NEW.systolic, NEW.diastolic, NEW.cr, NEW.temp, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.pregnancy_id, "U", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: labor_after_delete
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS labor_after_delete;
CREATE TRIGGER labor_after_delete AFTER DELETE ON labor
FOR EACH ROW
BEGIN
  INSERT INTO laborLog
  (id, admittanceDate, startLaborDate, endLaborDate, falseLabor, pos, fh, fht, systolic, diastolic, cr, temp, comments, updatedBy, updatedAt, supervisor, pregnancy_id, op, replacedAt)
  VALUES (OLD.id, OLD.admittanceDate, OLD.startLaborDate, OLD.endLaborDate, OLD.falseLabor, OLD.pos, OLD.fh, OLD.fht, OLD.systolic, OLD.diastolic, OLD.cr, OLD.temp, OLD.comments, OLD.updatedBy, OLD.updatedAt, OLD.supervisor, OLD.pregnancy_id, "D", NOW());
END;$$
DELIMITER ;


CREATE TABLE IF NOT EXISTS `laborStage1` (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fullDialation DATETIME NULL,
  mobility VARCHAR(200) NULL,
  durationLatent INT NULL,
  durationActive INT NULL,
  comments VARCHAR(500) NULL,
  updatedBy INT NOT NULL,
  updatedAt DATETIME NOT NULL,
  supervisor INT NULL,
  labor_id INT NOT NULL,
  UNIQUE(labor_id),
  FOREIGN KEY (labor_id) REFERENCES labor (id) ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY (updatedBy) REFERENCES user (id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE laborStage1Log LIKE laborStage1;
ALTER TABLE laborStage1Log ADD COLUMN op CHAR(1) DEFAULT '';
ALTER TABLE laborStage1Log ADD COLUMN replacedAt DATETIME NOT NULL;
ALTER TABLE laborStage1Log MODIFY COLUMN id INT DEFAULT 0;
ALTER TABLE laborStage1Log DROP PRIMARY KEY;
ALTER TABLE laborStage1Log ADD PRIMARY KEY (id, replacedAt);
ALTER TABLE laborStage1Log DROP KEY labor_id;

-- ---------------------------------------------------------------
-- Trigger: laborStage1_after_insert
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage1_after_insert;
CREATE TRIGGER laborStage1_after_insert AFTER INSERT ON laborStage1
FOR EACH ROW
BEGIN
  INSERT INTO laborStage1Log
  (id, fullDialation, mobility, durationLatent, durationActive, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (NEW.id, NEW.fullDialation, NEW.mobility, NEW.durationLatent, NEW.durationActive, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.labor_id, "I", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: laborStage1_after_update
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage1_after_update;
CREATE TRIGGER laborStage1_after_update AFTER UPDATE ON laborStage1
FOR EACH ROW
BEGIN
  INSERT INTO laborStage1Log
  (id, fullDialation, mobility, durationLatent, durationActive, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (NEW.id, NEW.fullDialation, NEW.mobility, NEW.durationLatent, NEW.durationActive, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.labor_id, "U", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: laborStage1_after_delete
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage1_after_delete;
CREATE TRIGGER laborStage1_after_delete AFTER DELETE ON laborStage1
FOR EACH ROW
BEGIN
  INSERT INTO laborStage1Log
  (id, fullDialation, mobility, durationLatent, durationActive, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (OLD.id, OLD.fullDialation, OLD.mobility, OLD.durationLatent, OLD.durationActive, OLD.comments, OLD.updatedBy, OLD.updatedAt, OLD.supervisor, OLD.labor_id, "D", NOW());
END;$$
DELIMITER ;


CREATE TABLE IF NOT EXISTS `laborStage2` (
  id INT AUTO_INCREMENT PRIMARY KEY,
  birthDatetime DATETIME NULL,
  birthType VARCHAR(50) NULL,
  birthPosition VARCHAR(100) NULL,
  durationPushing INT NULL,
  birthPresentation VARCHAR(100) NULL,
  cordWrap BOOLEAN NULL,
  cordWrapType VARCHAR(50) NULL,
  deliveryType VARCHAR(100) NULL,
  shoulderDystocia BOOLEAN NULL,
  shoulderDystociaMinutes INT NULL,
  laceration BOOLEAN NULL,
  episiotomy BOOLEAN NULL,
  repair BOOLEAN NULL,
  degree VARCHAR(50) NULL,
  lacerationRepairedBy VARCHAR(100) NULL,
  birthEBL INT NULL,
  meconium VARCHAR(50) NULL,
  comments VARCHAR(500) NULL,
  updatedBy INT NOT NULL,
  updatedAt DATETIME NOT NULL,
  supervisor INT NULL,
  labor_id INT NOT NULL,
  UNIQUE(labor_id),
  FOREIGN KEY (labor_id) REFERENCES labor (id) ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY (updatedBy) REFERENCES user (id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE laborStage2Log LIKE laborStage2;
ALTER TABLE laborStage2Log ADD COLUMN op CHAR(1) DEFAULT '';
ALTER TABLE laborStage2Log ADD COLUMN replacedAt DATETIME NOT NULL;
ALTER TABLE laborStage2Log MODIFY COLUMN id INT DEFAULT 0;
ALTER TABLE laborStage2Log DROP PRIMARY KEY;
ALTER TABLE laborStage2Log ADD PRIMARY KEY (id, replacedAt);
ALTER TABLE laborStage2Log DROP KEY labor_id;

-- ---------------------------------------------------------------
-- Trigger: laborStage2_after_insert
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage2_after_insert;
CREATE TRIGGER laborStage2_after_insert AFTER INSERT ON laborStage2
FOR EACH ROW
BEGIN
  INSERT INTO laborStage2Log
  (id, birthDatetime, birthType, birthPosition, durationPushing, birthPresentation, cordWrap, cordWrapType, deliveryType, shoulderDystocia, shoulderDystociaMinutes, laceration, episiotomy, repair, degree, lacerationRepairedBy, birthEBL, meconium, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (NEW.id, NEW.birthDatetime, NEW.birthType, NEW.birthPosition, NEW.durationPushing, NEW.birthPresentation, NEW.cordWrap, NEW.cordWrapType, NEW.deliveryType, NEW.shoulderDystocia, NEW.shoulderDystociaMinutes, NEW.laceration, NEW.episiotomy, NEW.repair, NEW.degree, NEW.lacerationRepairedBy, NEW.birthEBL, NEW.meconium, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.labor_id, "I", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: laborStage2_after_update
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage2_after_update;
CREATE TRIGGER laborStage2_after_update AFTER UPDATE ON laborStage2
FOR EACH ROW
BEGIN
  INSERT INTO laborStage2Log
  (id, birthDatetime, birthType, birthPosition, durationPushing, birthPresentation, cordWrap, cordWrapType, deliveryType, shoulderDystocia, shoulderDystociaMinutes, laceration, episiotomy, repair, degree, lacerationRepairedBy, birthEBL, meconium, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (NEW.id, NEW.birthDatetime, NEW.birthType, NEW.birthPosition, NEW.durationPushing, NEW.birthPresentation, NEW.cordWrap, NEW.cordWrapType, NEW.deliveryType, NEW.shoulderDystocia, NEW.shoulderDystociaMinutes, NEW.laceration, NEW.episiotomy, NEW.repair, NEW.degree, NEW.lacerationRepairedBy, NEW.birthEBL, NEW.meconium, NEW.comments, NEW.updatedBy, NEW.updatedAt, NEW.supervisor, NEW.labor_id, "U", NOW());
END;$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Trigger: laborStage2_after_delete
-- ---------------------------------------------------------------
DELIMITER $$
DROP TRIGGER IF EXISTS laborStage2_after_delete;
CREATE TRIGGER laborStage2_after_delete AFTER DELETE ON laborStage2
FOR EACH ROW
BEGIN
  INSERT INTO laborStage2Log
  (id, birthDatetime, birthType, birthPosition, durationPushing, birthPresentation, cordWrap, cordWrapType, deliveryType, shoulderDystocia, shoulderDystociaMinutes, laceration, episiotomy, repair, degree, lacerationRepairedBy, birthEBL, meconium, comments, updatedBy, updatedAt, supervisor, labor_id, op, replacedAt)
  VALUES (OLD.id, OLD.birthDatetime, OLD.birthType, OLD.birthPosition, OLD.durationPushing, OLD.birthPresentation, OLD.cordWrap, OLD.cordWrapType, OLD.deliveryType, OLD.shoulderDystocia, OLD.shoulderDystociaMinutes, OLD.laceration, OLD.episiotomy, OLD.repair, OLD.degree, OLD.lacerationRepairedBy, OLD.birthEBL, OLD.meconium, OLD.comments, OLD.updatedBy, OLD.updatedAt, OLD.supervisor, OLD.labor_id, "D", NOW());
END;$$
DELIMITER ;

COMMIT;

-- ==== DOWN ====

BEGIN;

DROP TABLE laborStage2Log;
DROP TABLE laborStage2;
DROP TABLE laborStage1Log;
DROP TABLE laborStage1;
DROP TABLE laborLog;
DROP TABLE labor;

COMMIT;
