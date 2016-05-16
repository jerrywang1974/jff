-- vi: ft=sql et ts=4 sts=4 sw=4

-- Purpose:
--      Use dotted version vector to store multiple concurrent updates
--      to rows to avoid silent data overwrite.
--
-- Customization:
--      s/SomeTable/YourTableName/gi
--      s/\bid\s*=\s*OLD\.id\b/Your-Primary-Keys-WHERE-Condition/gi
--
-- Author:
--      Yubao Liu <yubao.liu@yahoo.com>
--
-- Licence:
--      https://opensource.org/licenses/BSD-3-Clause
--
-- ChangeLog:
--      * 2016-05-16 v0.4   # remember to update SomeTable__dvv_version() below.


-- EXAMPLE: CREATE TABLE IF NOT EXISTS SomeTable (
-- EXAMPLE:     id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
-- EXAMPLE:     name            VARCHAR(200) NOT NULL,
-- EXAMPLE:     deleted         BOOLEAN NOT NULL DEFAULT FALSE, -- required by DVV
-- EXAMPLE:     logicalClock    JSON NOT NULL,                  -- required by DVV
-- EXAMPLE:
-- EXAMPLE:     INDEX           (deleted)
-- EXAMPLE: );
-- EXAMPLE:
-- EXAMPLE: -- same schema except no primary key
-- EXAMPLE: CREATE TABLE IF NOT EXISTS SomeTable__sibling (
-- EXAMPLE:     id              BIGINT UNSIGNED NOT NULL,
-- EXAMPLE:     name            VARCHAR(200) NOT NULL,
-- EXAMPLE:     deleted         BOOLEAN NOT NULL DEFAULT FALSE,
-- EXAMPLE:     logicalClock    JSON NOT NULL,
-- EXAMPLE:
-- EXAMPLE:     INDEX           (deleted)
-- EXAMPLE: );

DELIMITER //

CREATE TRIGGER SomeTable__fail_insert BEFORE INSERT ON SomeTable FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable' //

CREATE TRIGGER SomeTable__fail_update BEFORE UPDATE ON SomeTable FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable' //

CREATE TRIGGER SomeTable__fail_delete BEFORE DELETE ON SomeTable FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable' //

CREATE TRIGGER SomeTable__sibling__fail_insert BEFORE INSERT ON SomeTable__sibling FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable__sibling' //

CREATE TRIGGER SomeTable__sibling__fail_update BEFORE UPDATE ON SomeTable__sibling FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable__sibling' //

CREATE TRIGGER SomeTable__sibling__fail_delete BEFORE DELETE ON SomeTable__sibling FOR EACH ROW
    SIGNAL SQLSTATE '55002'
        SET MESSAGE_TEXT = 'Upgrading functions and triggers for SomeTable__sibling' //

DROP FUNCTION IF EXISTS SomeTable__dvv_version //
DROP TRIGGER IF EXISTS SomeTable__initLogicalClock //
DROP TRIGGER IF EXISTS SomeTable__reconcile //
DROP TRIGGER IF EXISTS SomeTable__protect_deletion //
DROP TRIGGER IF EXISTS SomeTable__sibling__protect_deletion //

CREATE FUNCTION SomeTable__dvv_version ()
RETURNS VARCHAR(100) DETERMINISTIC
RETURN '0.4' //

CREATE TRIGGER SomeTable__initLogicalClock BEFORE INSERT ON SomeTable FOR EACH ROW
BEGIN
    IF NEW.logicalClock IS NULL THEN
        SET NEW.logicalClock = CONCAT('{"format": 1, "hasSibling": false, "versionVector": {"',
                                      current_gtid_source_id(),
                                      '": 1}}');
    END IF;
END //

CREATE TRIGGER SomeTable__reconcile BEFORE UPDATE ON SomeTable FOR EACH ROW
BEGIN
    DECLARE old_format, new_format INTEGER;
    DECLARE old_hasSibling, new_hasSibling BOOLEAN;
    DECLARE old_vv, new_vv JSON;
    DECLARE source_id CHAR(36);

    -- check transaction isolation level
    IF @@SESSION.tx_isolation <> 'REPEATABLE-READ' AND @@SESSION.tx_isolation <> 'SERIALIZABLE' THEN
        SIGNAL SQLSTATE '55001'
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
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Invalid "format" in logical clock';
    END IF;

    IF old_hasSibling IS NULL OR new_hasSibling IS NULL THEN
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Invalid "hasSibling" in logical clock';
    END IF;

    IF old_vv IS NULL OR new_vv IS NULL OR
            JSON_TYPE(old_vv) <> 'OBJECT' OR JSON_TYPE(new_vv) <> 'OBJECT' OR
            JSON_DEPTH(old_vv) <> 2 OR JSON_DEPTH(new_vv) <> 2 THEN
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Invalid "versionVector" in logical clock';
    END IF;

    -- check whether logicalClock is missing by mistake in update clause,
    -- the ".dirty" member only exists during execution of update, it's
    -- never really stored to the row.
    IF JSON_CONTAINS_PATH(NEW.logicalClock, 'one', '$.dirty') IS FALSE THEN
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Member "dirty" not found in column "logicalClock"';
    END IF;

    -- check conflicts
    SET source_id = current_gtid_source_id();
    IF source_id = @@server_uuid THEN   -- on master
        IF new_hasSibling IS TRUE OR vv_descend(new_vv, old_vv) IS FALSE THEN
            SIGNAL SQLSTATE '55055'
                SET MESSAGE_TEXT = 'Must reconcile conflicted values';
        END IF;

        IF old_hasSibling IS TRUE THEN
            UPDATE SomeTable__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE;
        END IF;
    ELSE                                -- on slave
        IF vv_descend(new_vv, old_vv) IS TRUE THEN
            IF old_hasSibling IS TRUE THEN
                UPDATE SomeTable__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE;
            END IF;

            SET new_hasSibling = FALSE;
        ELSE
            IF old_hasSibling IS TRUE THEN
                UPDATE SomeTable__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE AND
                    vv_descend(new_vv, vv_dot(logicalClock)) IS TRUE;
            END IF;

            IF vv_descend(new_vv, vv_dot(OLD.logicalClock)) IS FALSE THEN
                INSERT INTO SomeTable__sibling SELECT * FROM SomeTable WHERE id = OLD.id;
            END IF;

            SET new_hasSibling = TRUE;
        END IF;
    END IF;

    -- calculate the final real NEW.logicalClock
    SET new_vv = IF(new_hasSibling IS TRUE,
                    vv_increment(vv_merge(old_vv, new_vv), source_id),
                    vv_increment(new_vv, source_id));

    SET NEW.logicalClock = JSON_SET(JSON_REMOVE(NEW.logicalClock, '$.dirty'),
                                    '$.hasSibling',
                                    CAST(new_hasSibling IS TRUE AS JSON),
                                    '$.versionVector',
                                    new_vv);

    IF JSON_LENGTH(new_vv) > 1 THEN
        SET NEW.logicalClock = JSON_SET(NEW.logicalClock,
                                        '$.dot',
                                        JSON_OBJECT(source_id,
                                                    JSON_EXTRACT(new_vv, CONCAT('$."', source_id, '"'))));
    ELSE
        -- implicitly $.dot is equal to $.versionVector.
        SET NEW.logicalClock = JSON_REMOVE(NEW.logicalClock, '$.dot');
    END IF;
END //

CREATE TRIGGER SomeTable__protect_deletion BEFORE DELETE ON SomeTable FOR EACH ROW
BEGIN
    IF current_gtid_source_id() = @@server_uuid AND (
            OLD.deleted IS FALSE OR
            @i_know_what_i_am_doing IS NULL OR
            @i_know_what_i_am_doing <> 'i really want to delete from SomeTable' ) THEN
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Do you know what you are doing?';
    END IF;
END //

CREATE TRIGGER SomeTable__sibling__protect_deletion BEFORE DELETE ON SomeTable__sibling FOR EACH ROW
BEGIN
    IF current_gtid_source_id() = @@server_uuid AND (
            OLD.deleted IS FALSE OR
            @i_know_what_i_am_doing IS NULL OR
            @i_know_what_i_am_doing <> 'i really want to delete from SomeTable__sibling' ) THEN
        SIGNAL SQLSTATE '55001'
            SET MESSAGE_TEXT = 'Do you know what you are doing?';
    END IF;
END //

DROP TRIGGER SomeTable__fail_insert //
DROP TRIGGER SomeTable__fail_update //
DROP TRIGGER SomeTable__fail_delete //
DROP TRIGGER SomeTable__sibling__fail_insert //
DROP TRIGGER SomeTable__sibling__fail_update //
DROP TRIGGER SomeTable__sibling__fail_delete //

DELIMITER ;

