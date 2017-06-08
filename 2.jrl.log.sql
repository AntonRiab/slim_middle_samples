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
 * <IDENTIFICATION>
 **************************************************************************************************
 * <JOURNAL_LOGIC>
        --ONLY ONLY BEFORE, because AFTER does not put NEW in TABLE!!!
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
	       AND tmp0.key <> 'p_trid'
	       AND tmp0.value IS NOT NULL
	       AND information_schema.columns.table_schema = TG_TABLE_SCHEMA
	       AND information_schema.columns.table_name   = TG_TABLE_NAME;

    IF NEW.p_trid IS NOT NULL THEN
	EXECUTE (WITH keys AS (
	    SELECT (
	      string_agg((select key||'=$1.'||key from not_null_values), ','))
              AS key)
		SELECT format('UPDATE %s SET %s WHERE %s.s_id=$1.p_trid', target_tb, keys.key, target_tb)
		    FROM keys) 
        USING NEW;
    END IF;

    GET DIAGNOSTICS update_result = ROW_COUNT;
    IF NEW.p_trid IS NULL OR update_result=0 THEN
	    IF NEW.p_trid IS NOT NULL AND update_result=0 THEN
	        NEW.p_trid=NULL;
	    END IF;
    
        EXECUTE format('INSERT INTO %s (%s) VALUES (%s) RETURNING s_id', 
                       target_tb, 
                       (SELECT string_agg(key, ',') from not_null_values), 
                       (SELECT string_agg('$1.'||key, ',') from not_null_values))
		USING NEW;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
 * </JOURNAL_LOGIC>
 **************************************************************************************************
 * <LOG_LOGIC>
        --ONLY ONLY BEFORE, because AFTER does not put NEW in TABLE!!!
 */

CREATE OR REPLACE FUNCTION trg_4_log() RETURNS trigger AS $$
BEGIN
    IF NEW.pc_trid IS NOT NULL THEN
        EXECUTE (
        WITH
             str_arg AS (
		SELECT key AS key,
		       CASE WHEN value IS NOT NULL OR key LIKE 's_%' THEN key
		       ELSE NULL
		       END AS ekey,
		       CASE WHEN value IS NOT NULL OR key LIKE 's_%' THEN 't.'||key
		       ELSE TG_TABLE_NAME||'.'||key
		       END AS tkey,
		       CASE WHEN value IS NOT NULL OR key LIKE 's_%' THEN '$1.'||key
		       ELSE NULL
		       END AS value,
		       isc.ordinal_position
	        FROM each(hstore(NEW)) AS tmp0
		INNER JOIN information_schema.columns AS isc
		     ON isc.column_name=tmp0.key
		WHERE isc.table_schema = TG_TABLE_SCHEMA
		AND isc.table_name = TG_TABLE_NAME
		ORDER BY isc.ordinal_position)
	SELECT format('WITH upd AS (UPDATE %s SET pc_trid=%L WHERE s_id=%L)
	               SELECT %s FROM (VALUES(%s)) AS t(%s) 
	               LEFT JOIN %s ON t.pc_trid=%s.s_id',
	               TG_TABLE_NAME, NEW.s_id, NEW.pc_trid,
	               string_agg(tkey, ','), 
	               string_agg(value, ','), 
	               string_agg(ekey, ','),
	               TG_TABLE_NAME, TG_TABLE_NAME) 
	FROM str_arg
	) INTO NEW USING NEW;
	NEW.pc_trid=NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
 * </LOG_LOGIC>
 **************************************************************************************************
 * <TABLES_JOURNAL>
 */

--output/result table 1/2
DROP TABLE IF EXISTS rst_data CASCADE;
CREATE TABLE rst_data (
    s_id        SERIAL,
    data0       TEXT,
    data1       TEXT,
    UNIQUE (s_id)
);
COMMENT ON COLUMN rst_data.data0        IS 'Operating Data';
COMMENT ON COLUMN rst_data.data1        IS 'Operating Data';

--input/journal table 2/2
DROP TABLE IF EXISTS jrl_data CASCADE;
CREATE TABLE jrl_data (
    s_id        SERIAL,
    s_cusr      TEXT,
    s_tmc       TEXT,
    p_trid      INTEGER,

    data0       TEXT,
    data1       TEXT,
    UNIQUE (s_id)
);
DROP TRIGGER IF EXISTS trg_1_identification ON jrl_data;
CREATE TRIGGER trg_1_identification BEFORE INSERT OR UPDATE ON jrl_data
    FOR EACH ROW EXECUTE PROCEDURE trg_1_identification();

DROP TRIGGER IF EXISTS trg_4_jrl ON jrl_data;
CREATE TRIGGER trg_4_jrl BEFORE INSERT OR UPDATE ON jrl_data
    FOR EACH ROW EXECUTE PROCEDURE trg_4_jrl();

--Service variable with prefix s_, ingoring add value, it set from trigers
COMMENT ON COLUMN jrl_data.s_id        IS 'Service variable, Current ID of record';
COMMENT ON COLUMN jrl_data.s_cusr      IS 'Service variable, User name who created the record';
COMMENT ON COLUMN jrl_data.s_tmc       IS 'Service variable, Time when the record was created';
COMMENT ON COLUMN jrl_data.p_trid  
    IS 'Service variable, Target ID/Parent in RST_(result) table, if exists for modification';

/*
 * <TABLES_JOURNAL>
 **************************************************************************************************
 * <LOG_TABLE>
 */

--input/output log table 1/1
DROP TABLE IF EXISTS log_data CASCADE;
CREATE TABLE log_data (
    s_id        SERIAL,
    s_cusr      TEXT,
    s_tmc       TEXT,
    pc_trid     INTEGER,

    data0       TEXT,
    data1       TEXT,
    UNIQUE (s_id)
);
DROP TRIGGER IF EXISTS trg_1_identification ON log_data;
CREATE TRIGGER trg_1_identification BEFORE INSERT OR UPDATE ON log_data
    FOR EACH ROW EXECUTE PROCEDURE trg_1_identification();

DROP TRIGGER IF EXISTS trg_4_log ON log_data;
CREATE TRIGGER trg_4_log BEFORE INSERT ON log_data
    FOR EACH ROW EXECUTE PROCEDURE trg_4_log();

COMMENT ON COLUMN log_data.s_id        IS 'Service variable, Current ID of record';
COMMENT ON COLUMN log_data.s_cusr     IS 'Service variable, User name who created the record';
COMMENT ON COLUMN log_data.s_tmc      IS 'Service variable, Time when the record was created';
COMMENT ON COLUMN log_data.pc_trid      
    IS 'Service variable, Target ID(ParentIN/ChilrdenSAVE) in CURRENT table, if exists for modification';

/*
 * <LOG_TABLE>
 */

