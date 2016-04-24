SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE-READ;

START TRANSACTION;

DROP TABLE t;

CREATE TABLE t (
    id              SERIAL,
    name            VARCHAR(200) NOT NULL,
    logicalClock    JSON
);

CREATE TRIGGER t__initLogicalClock BEFORE INSERT ON t FOR EACH ROW
    SET NEW.logicalClock = CONCAT('{"format": 1, "hasSibling": false, "versionVector": {"',
                                  IF(@@SESSION.gtid_next = 'AUTOMATIC',
                                     @@server_uuid,
                                     SUBSTRING_INDEX(@@SESSION.gtid_next, ':', 1)),
                                  '": 1}}');

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
END

COMMIT;

