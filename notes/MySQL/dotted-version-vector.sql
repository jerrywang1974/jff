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

DELIMITER //
CREATE TRIGGER t__initLogicalClock BEFORE INSERT ON t FOR EACH ROW
BEGIN
    IF NEW.logicalClock IS NULL THEN
        SET NEW.logicalClock = CONCAT('{"format": 1, "hasSibling": false, "versionVector": {"',
                                      IF(@@SESSION.gtid_next = 'AUTOMATIC',
                                         @@server_uuid,
                                         SUBSTRING_INDEX(@@SESSION.gtid_next, ':', 1)),
                                      '": 1}}');
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER t__reconcile BEFORE UPDATE ON t FOR EACH ROW
BEGIN
    -- check format = 1
    -- check @@SESSION.tx_isolation is 'REPEATABLE-READ' or 'SERIALIZABLE'
    -- if new.logicalClock >= old.logicalClock
    --      increment new.logicalClock.versionVector for gtid_next's server_uuid
    --      if old.logicalClock.hasSibling
    --          mark siblings in t__sibling to be deleted
    --      new.logicalClock.hasSibling = false
    -- else
    --      if on-master
    --          fail
    --      prune old siblings in t__sibling when new.logicalClock >= sibling.logicalClock
    --      copy old into t__sibling
    --      new.logicalClock.versionVector = merge(old.logicalClock.versionVector, new.logicalClock.versionVector)
    --      increment new.logicalClock.versionVector for gtid_next's server_uuid
    --      new.logicalClock.hasSibling = true
END //
DELIMITER ;

COMMIT;

