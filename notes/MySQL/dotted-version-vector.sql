SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE-READ;

START TRANSACTION;

CREATE TABLE IF NOT EXISTS t (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    logicalClock    JSON,
    deleted         BOOLEAN DEFAULT FALSE,

    INDEX           (deleted)
);

CREATE TABLE IF NOT EXISTS t__sibling (
    id              BIGINT UNSIGNED NOT NULL,
    name            VARCHAR(200) NOT NULL,
    logicalClock    JSON,
    deleted         BOOLEAN DEFAULT FALSE,

    INDEX           (deleted)
);

DROP TRIGGER IF EXISTS t__initLogicalClock;
DROP TRIGGER IF EXISTS t__reconcile;
DROP FUNCTION IF EXISTS current_gtid_source_id;
DROP FUNCTION IF EXISTS vv_descend;
DROP FUNCTION IF EXISTS vv_merge;
DROP FUNCTION IF EXISTS vv_increment;

DELIMITER $$

CREATE FUNCTION current_gtid_source_id ()
RETURNS CHAR(36) DETERMINISTIC
RETURN IF(@@SESSION.gtid_next = 'AUTOMATIC',
          @@server_uuid,
          SUBSTRING_INDEX(@@SESSION.gtid_next, ':', 1)) $$

CREATE FUNCTION vv_descend (v1 JSON, v2 JSON)
RETURNS BOOLEAN DETERMINISTIC
BEGIN
END $$

CREATE FUNCTION vv_merge (v1 JSON, v2 JSON)
RETURNS JSON DETERMINISTIC
BEGIN
END $$

CREATE FUNCTION vv_increment (v JSON, server CHAR(36))
RETURNS JSON DETERMINISTIC
BEGIN
END $$

CREATE TRIGGER t__initLogicalClock BEFORE INSERT ON t FOR EACH ROW
BEGIN
    IF NEW.logicalClock IS NULL THEN
        SET NEW.logicalClock = CONCAT('{"format": 1, "hasSibling": false, "versionVector": {"',
                                      current_gtid_source_id(),
                                      '": 1}}');
    END IF;
END $$

CREATE TRIGGER t__reconcile BEFORE UPDATE ON t FOR EACH ROW
BEGIN
    DECLARE old_format, new_format INTEGER;
    DECLARE old_hasSibling, new_hasSibling BOOLEAN;
    DECLARE old_vv, new_vv JSON;
    DECLARE source_id CHAR(36);

    -- check transaction isolation level
    IF @@SESSION.tx_isolation <> 'REPEATABLE-READ' AND @@SESSION.tx_isolation <> 'SERIALIZABLE' THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Transaction isolation level isn\'t REPEATABLE-READ or SERIALIZABLE';
    END IF;

    -- check data schema of logical clock
    SET old_format = JSON_EXTRACT(OLD.logicalClock, '$.format'),
        new_format = JSON_EXTRACT(NEW.logicalClock, '$.format'),
        old_hasSibling = JSON_EXTRACT(OLD.logicalClock, '$.hasSibling'),
        new_hasSibling = JSON_EXTRACT(NEW.logicalClock, '$.hasSibling'),
        old_vv = JSON_EXTRACT(OLD.logicalClock, '$.versionVector'),
        new_vv = JSON_EXTRACT(NEW.logicalClock, '$.versionVector');

    IF old_format IS NULL OR new_format IS NULL OR old_format <> 1 OR new_format <> 1 THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "format" in logical clock';
    END IF;

    IF old_hasSibling IS NULL OR new_hasSibling IS NULL THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "hasSibling" in logical clock';
    END IF;

    IF old_vv IS NULL OR new_vv IS NULL OR JSON_TYPE(old_vv) <> 'OBJECT' OR JSON_TYPE(new_vv) <> 'OBJECT' THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "versionVector" in logical clock';
    END IF;

    -- check conflicts
    SET source_id = current_gtid_source_id();
    IF @@server_id = source_id THEN     -- on master
        IF new_hasSibling OR NOT vv_descend(new_vv, old_vv) THEN
            SIGNAL SQLSTATE '55001'
                SET MESSAGE_TEXT = 'Must reconcile conflicted values';
        END IF;

        IF old_hasSibling THEN
            UPDATE t__sibling SET deleted = TRUE WHERE id = @NEW.id AND deleted = FALSE;
        END IF;

        SET NEW.logicalClock = JSON_SET(NEW.logicalClock,
                                        '$.versionVector',
                                        vv_increment(vv_merge(old_vv, new_vv), source_id));

    ELSE    -- on slave

        IF vv_descend(new_vv, old_vv) THEN
            IF old_hasSibling THEN
                UPDATE t__sibling SET deleted = TRUE WHERE id = @NEW.id AND deleted = FALSE;
            END IF;

            SET NEW.hasSibling = FALSE,
                NEW.logicalClock = JSON_SET(NEW.logicalClock,
                                            '$.versionVector',
                                            vv_increment(vv_merge(old_vv, new_vv), source_id));

        ELSE

            IF old_hasSibling THEN
                UPDATE t__sibling SET deleted = TRUE WHERE id = @NEW.id AND deleted = FALSE AND
                    vv_descend(new_vv, JSON_EXTRACT(logicalClock, '$.versionVector');
            END IF;

            INSERT INTO t__sibling SELECT * FROM t WHERE id = @NEW.id;

            SET NEW.hasSibling = TRUE,
                NEW.logicalClock = JSON_SET(NEW.logicalClock,
                                            '$.versionVector',
                                            vv_increment(vv_merge(old_vv, new_vv), source_id));

        END IF;
    END IF;
END $$

DELIMITER ;

COMMIT;

