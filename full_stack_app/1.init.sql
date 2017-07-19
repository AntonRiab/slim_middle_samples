/*
 * Copyright (C) Anton Riabchevskiy (AntonRiab)
 * All rights reserved.
 * Tested on PostgreSQL 9.6
 **************************************************************************************************
 * <IDENTIFICATION>
 */

DROP FUNCTION IF EXISTS trg_1_identification() CASCADE;
CREATE OR REPLACE FUNCTION trg_1_identification() RETURNS trigger AS $$
BEGIN
    IF NEW.s_id IS NULL THEN
	    NEW.s_id=nextval(TG_TABLE_NAME||'_s_id_seq');
    END IF;
    NEW.s_cusr=current_user;
    NEW.s_tmc=current_timestamp;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
 * </IDENTIFICATION>
 **************************************************************************************************
 * <LOG_LOGIC>
 */

CREATE OR REPLACE FUNCTION trg_4_jrl() RETURNS trigger AS $$
DECLARE
    update_result    INTEGER := NULL;
    target_tb        TEXT :='rst_'||substring(TG_TABLE_NAME from 5);
BEGIN
--key::text,value::text
    DROP TABLE IF EXISTS not_null_values;
    CREATE TEMP TABLE not_null_values AS
        SELECT key,value from each(hstore(NEW)) AS tmp0
	     INNER JOIN 
	     information_schema.columns
	     ON information_schema.columns.column_name=tmp0.key
	     WHERE tmp0.key NOT LIKE 's_%'
	       AND (tmp0.value IS NOT NULL OR tmp0.value::boolean = true)
	       AND information_schema.columns.table_schema = TG_TABLE_SCHEMA
	       AND information_schema.columns.table_name   = TG_TABLE_NAME;

    IF (SELECT count(*) FROM not_null_values WHERE key = 'p_trid') IS NOT NULL THEN	
	EXECUTE (WITH keys AS (
	             SELECT string_agg(key||'=$1.'||key, ',') AS key from not_null_values 
                    WHERE key <> 'p_trid')
		     SELECT format('UPDATE %s SET %s WHERE %s.s_id=$1.p_trid', target_tb, keys.key, target_tb)
		     FROM keys) 
        USING NEW;
    END IF;

    GET DIAGNOSTICS update_result = ROW_COUNT;
    IF (SELECT count(*) FROM not_null_values WHERE key = 'p_trid') IS NULL OR update_result=0 THEN
	    NEW.p_trid=NULL;

        EXECUTE format('INSERT INTO %s (%s) VALUES (%s) RETURNING s_id', 
                       target_tb, 
                       (SELECT string_agg(key, ',') from not_null_values WHERE key <> 'p_trid'), 
                       (SELECT string_agg('$1.'||key, ',') from not_null_values WHERE key <> 'p_trid'))
		USING NEW;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
 * </LOG_LOGIC>
 **************************************************************************************************
 * <TASKS_SAMPLES>
 */

DROP TABLE IF EXISTS rst_tasks_samples CASCADE;
CREATE TABLE rst_tasks_samples (
    s_id     SERIAL,
    title    TEXT,
    isDone   BOOLEAN,
    _destroy BOOLEAN,
    UNIQUE (s_id)
);

DROP TABLE IF EXISTS jrl_tasks_samples CASCADE;
CREATE TABLE jrl_tasks_samples (
    s_id        SERIAL,
    s_cusr      TEXT,
    s_tmc       TEXT,
    p_trid     INTEGER,

    title    TEXT,
    isDone   BOOLEAN,
    _destroy BOOLEAN
);

DROP TRIGGER IF EXISTS trg_1_identification ON jrl_tasks_samples;
CREATE TRIGGER trg_1_identification BEFORE INSERT OR UPDATE ON jrl_tasks_samples
    FOR EACH ROW EXECUTE PROCEDURE trg_1_identification();

DROP TRIGGER IF EXISTS trg_4_jrl ON jrl_tasks_samples;
CREATE TRIGGER trg_4_jrl BEFORE INSERT OR UPDATE ON jrl_tasks_samples
    FOR EACH ROW EXECUTE PROCEDURE trg_4_jrl();

/*
 * </TASKS_SAMPLES>
 **************************************************************************************************
 * <IMPORT_JSON>
 */
DROP FUNCTION IF EXISTS import_vt_json(filename TEXT, target_table TEXT);
CREATE OR REPLACE FUNCTION import_vt_json(filename TEXT, target_table TEXT)
RETURNS void AS $$
BEGIN
    EXECUTE format(
        'INSERT INTO %I SELECT * FROM 
            json_populate_recordset(null::%I, 
                convert_from(pg_read_binary_file(%L), ''UTF-8'')::json)', 
        target_table, target_table, filename);
END;
$$ LANGUAGE plpgsql;

/*
 * </TASKS_SAMPLES>
 **************************************************************************************************
 * <IMPORT_JSON>
 */
DROP FUNCTION IF EXISTS import_vt_json(filename TEXT, target_table TEXT);
CREATE OR REPLACE FUNCTION import_vt_json(filename TEXT, target_table TEXT)
RETURNS void AS $$
BEGIN
    EXECUTE format(
        'INSERT INTO %I SELECT * FROM 
            json_populate_recordset(null::%I, 
                convert_from(pg_read_binary_file(%L), ''UTF-8'')::json)', 
        target_table, target_table, filename);
END;
$$ LANGUAGE plpgsql;

/*
 * </IMPORT_JSON>
 */
