-- vi: ft=sql et ts=4 sts=4 sw=4

DELIMITER //

-- For production environment, these functions are versioned
-- by a suffix, so they mustn't exist.
--
-- DROP FUNCTION IF EXISTS current_gtid_source_id //
-- DROP FUNCTION IF EXISTS vv_descend //
-- DROP FUNCTION IF EXISTS vv_merge //
-- DROP FUNCTION IF EXISTS vv_increment //
-- DROP FUNCTION IF EXISTS vv_dot //

CREATE FUNCTION current_gtid_source_id ()
RETURNS CHAR(36) DETERMINISTIC
RETURN IF(@@SESSION.gtid_next = 'AUTOMATIC',
          @@server_uuid,
          SUBSTRING_INDEX(@@SESSION.gtid_next, ':', 1)) //

CREATE FUNCTION vv_descend (v1 JSON, v2 JSON)
RETURNS BOOLEAN DETERMINISTIC
BEGIN
    DECLARE servers JSON;
    DECLARE i, n, counter1, counter2 INTEGER;
    DECLARE path VARCHAR(100);

    SET servers = JSON_KEYS(v2);
    IF servers IS NULL THEN
        RETURN TRUE;
    END IF;

    SET n = JSON_LENGTH(servers),
        i = 0;

    WHILE i < n DO
        SET path = CONCAT('$.', JSON_EXTRACT(servers, CONCAT('$[', i, ']')));
        SET counter1 = JSON_EXTRACT(v1, path),
            counter2 = JSON_EXTRACT(v2, path);

        IF counter1 IS NULL OR counter1 < counter2 THEN
            RETURN FALSE;
        END IF;

        SET i = i + 1;
    END WHILE;

    RETURN TRUE;
END //

CREATE FUNCTION vv_merge (v1 JSON, v2 JSON)
RETURNS JSON DETERMINISTIC
BEGIN
    DECLARE v, servers, val JSON;
    DECLARE i, n, e1, e2 INTEGER;
    DECLARE path VARCHAR(100);

    SET v = JSON_MERGE(v1, v2);
    SET servers = JSON_KEYS(v);
    SET n = JSON_LENGTH(servers),
        i = 0;

    WHILE i < n DO
        SET path = CONCAT('$.', JSON_EXTRACT(servers, CONCAT('$[', i, ']')));
        SET val = JSON_EXTRACT(v, path);

        IF JSON_TYPE(val) = 'ARRAY' THEN
            SET e1 = JSON_EXTRACT(val, '$[0]'),
                e2 = JSON_EXTRACT(val, '$[1]');

            SET v = JSON_SET(v, path, IF(e1 > e2, e1, e2));
        END IF;

        SET i = i + 1;
    END WHILE;

    RETURN v;
END //

CREATE FUNCTION vv_increment (v JSON, server CHAR(36))
RETURNS JSON DETERMINISTIC
BEGIN
    DECLARE i INTEGER;
    DECLARE path VARCHAR(100);

    SET path = CONCAT('$."', server, '"');
    SET i = JSON_EXTRACT(v, path);

    RETURN JSON_SET(v, path, IF(i IS NULL, 1, i + 1));
END //

CREATE FUNCTION vv_dot (logicalClock JSON)
RETURNS JSON DETERMINISTIC
BEGIN
    DECLARE dot JSON;

    SET dot = JSON_EXTRACT(logicalClock, '$.dot');
    RETURN IF(dot IS NULL,
              JSON_EXTRACT(logicalClock, '$.versionVector'),
              dot);
END //

DELIMITER ;

