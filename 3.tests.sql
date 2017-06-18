/*
 * Copyright (C) Anton Riabchevskiy (AntonRiab)
 * All rights reserved.
 * Tested on PostgreSQL 9.6
 **************************************************************************************************
 * <REFERENCE_SIMPLE_TABLE>
 */

DROP TABLE IF EXISTS positive_reference_simple_data;
CREATE TABLE positive_reference_simple_data AS 
SELECT * from (VALUES(0, 'zero'), 
                     (1, 'one'),
                     (2, 'two'),
                     (3, 'three'),
                     (4, 'four'),
                     (5, 'five')) AS t(s_id, data0);

DROP FUNCTION IF EXISTS test_reference(TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION test_reference(test_table TEXT, reference_table TEXT, except_col TEXT)
RETURNS void AS $$
DECLARE
    result INTEGER;
BEGIN
    EXECUTE (
        WITH join_cols AS (  --
            SELECT string_agg('tt.'||a.attname||'=rtt.'||a.attname, ' AND ') AS agg
            FROM  pg_attribute a
            LEFT JOIN pg_class c ON c.oid = a.attrelid
            LEFT JOIN pg_type t ON t.oid = a.atttypid
            WHERE a.attnum > 0
                AND a.attname NOT similar to '%('||CASE WHEN except_col='' THEN '.'
                                                   ELSE except_col END ||')%'
                AND c.relname = reference_table --'log_data'
            )
        SELECT format('
            WITH 
            count_ref AS (
                SELECT count(*) AS cr FROM %s),
            compare AS (SELECT count(*) AS cc FROM %s AS tt
                        LEFT JOIN %s AS rtt
                        ON %s)
            SELECT CASE WHEN count_ref.cr=compare.cc THEN 1 
                   ELSE 0
                   END FROM count_ref, compare', reference_table, 
                                                 test_table,
                                                 reference_table,
                                                 agg
        )
        FROM join_cols
    ) INTO result;

    IF result=0 THEN
        RAISE EXCEPTION 'COMPARE ERROR % AND ref %', test_table, reference_table;
    END IF;
    RAISE NOTICE 'COMPARE OK % AND ref %', test_table, reference_table;
END;
$$ LANGUAGE plpgsql;

/*
 * </REFERENCE_SIMPLE_TABLE>
 **************************************************************************************************
 * <FIXED_TABLE_TEST>
 */

TRUNCATE TABLE simple_data;
COPY simple_data FROM '/var/lib/postgresql/9.6/main/import/data.csv' 
    WITH DELIMITER as ';' null as '';
SELECT import_json_to_simple_data('import/data.json');
SELECT import_xml_to_simple_data('import/data.xml');
--SELECT * FROM simple_data;

SELECT test_reference('simple_data', 'positive_reference_simple_data', '');

/*
 * </FIXED_TABLE_TEST>
 **************************************************************************************************
 * <VARIOUS_TABLE>
 */

TRUNCATE TABLE simple_data;
COPY simple_data FROM '/var/lib/postgresql/9.6/main/import/data.csv' 
    WITH DELIMITER as ';' null as '';
SELECT import_vt_json('import/data.json', 'simple_data');
SELECT import_vt_xml('import/data.xml', 'simple_data');
--SELECT * FROM simple_data;

SELECT test_reference('simple_data', 'positive_reference_simple_data', '');

/*
 * </VARIOUS_TABLE>
 **************************************************************************************************
 * <JOURNAL_TEST>
 */

TRUNCATE TABLE jrl_data;
TRUNCATE TABLE rst_data;
ALTER SEQUENCE jrl_data_s_id_seq RESTART WITH 1;
ALTER SEQUENCE rst_data_s_id_seq RESTART WITH 1;

INSERT INTO jrl_data (data0, data1) VALUES ('first', 'one');
INSERT INTO jrl_data (p_trid, data1) VALUES ((SELECT s_id FROM rst_data limit 1), 'second');
INSERT INTO jrl_data (p_trid, data1) VALUES ('1000000', 'million');
--SELECT * FROM rst_data;

DROP TABLE IF EXISTS positive_reference_rst_data;
CREATE TABLE positive_reference_rst_data AS 
SELECT * from (VALUES(1, 'first', 'second'), 
                     (2, '', 'million')
                     ) AS t(s_id, data0, data1);

SELECT test_reference('rst_data', 'positive_reference_rst_data', '');

/*
 * </JOURNAL_TEST>
 **************************************************************************************************
 * <LOG_TEST>
 */

TRUNCATE TABLE log_data;
ALTER SEQUENCE log_data_s_id_seq RESTART WITH 1;

INSERT INTO log_data (data0) VALUES ('first');
INSERT INTO log_data (pc_trid, data1) VALUES ((SELECT s_id FROM log_data limit 1), 'second');

DROP TABLE IF EXISTS positive_reference_log_data;
CREATE TABLE positive_reference_log_data AS 
SELECT * from (VALUES(1, '', 'first', ''), 
                     (2, '', 'first', 'second')
                     ) AS t(s_id, pc_trid, data0, data1);

SELECT test_reference('log_data', 'positive_reference_log_data', 's_cusr|pc_trid|s_tmc');

/*
 * </LOG_TEST>
 **************************************************************************************************
 * <TEST_FUNCTION_NEGATIVE>
 */

DROP TABLE IF EXISTS negative_reference_simple_data;
CREATE TABLE negative_reference_simple_data AS 
SELECT * from (VALUES(0, 'zero'), 
                     (1, 'one'),
                     (5, 'five')) AS t(s_id, data0);

SELECT test_reference('simple_data', 'negative_reference_simple_data', '');

/*
 * <TEST_FUNCTION_NEGATIVE>
 */
