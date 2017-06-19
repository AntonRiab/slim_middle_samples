/*
 * Copyright (C) Anton Riabchevskiy (AntonRiab)
 * All rights reserved.
 * Tested on PostgreSQL 9.6
 **************************************************************************************************
 * <SIMPLES_DATA>
 */

DROP TABLE IF EXISTS simple_data CASCADE;
CREATE TABLE simple_data (
    s_id    SERIAL,
    data0   TEXT,
    UNIQUE (s_id)
);

/*
 * </SIMPLES_DATA>
 **************************************************************************************************
 * <CSV>
 ****COPY request can use only triger modification! 

COPY simple_data FROM '/var/lib/postgresql/9.6/main/import/data.csv' 
    WITH DELIMITER as ';' null as '';

 * </CSV>
 **************************************************************************************************
 * <IMPORT_TO_FIXED_TABLE_JSON>
 */

DROP FUNCTION IF EXISTS import_json_to_simple_data(TEXT);
CREATE OR REPLACE FUNCTION import_json_to_simple_data(filename TEXT)
RETURNS void AS $$
BEGIN
    INSERT INTO simple_data
    SELECT * FROM 
        json_populate_recordset(null::simple_data, 
            convert_from(pg_read_binary_file(filename), 'UTF-8')::json);
END;
$$ LANGUAGE plpgsql;

/*
 * </IMPORT_TO_FIXED_TABLE_JSON>
 **************************************************************************************************
 * <IMPORT_TO_FIXED_TABLE_XML>
 */

--import to tables with fixed cols names, fastest for computer, but not flexible
DROP FUNCTION IF EXISTS import_xml_to_simple_data(TEXT);
CREATE OR REPLACE FUNCTION import_xml_to_simple_data(filename TEXT)
RETURNS void AS $$
BEGIN
    INSERT INTO simple_data
    SELECT (xpath('//s_id/text()', myTempTable.myXmlColumn))[1]::text::integer AS s_id,
           (xpath('//data0/text()', myTempTable.myXmlColumn))[1]::text AS data0
    FROM unnest(xpath('/*/*', 
        XMLPARSE(DOCUMENT convert_from(pg_read_binary_file(filename), 'UTF-8')))) 
    AS myTempTable(myXmlColumn);
END;
$$ LANGUAGE plpgsql;

/*
 * </IMPORT_TO_FIXED_TABLE_XML>
 * <IMPORT_TO_VARIOUS_TABLE_JSON>
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
 * </IMPORT_TO_VARIOUS_TABLE_JSON>
 **************************************************************************************************
 * <IMPORT_TO_VARIOUS_TABLE_XML>
  import to various table, with hierarchy table_name/rows/cols
  slowest for computer, very flexible
  it have double read for xml file
      first to search all nodes names
      secod to read values
 */

DROP FUNCTION IF EXISTS import_vt_xml(TEXT, target_table TEXT);
CREATE OR REPLACE FUNCTION import_vt_xml(filename TEXT, target_table TEXT)
RETURNS void AS $$
DECLARE
    columns_name TEXT;
BEGIN
    columns_name := (
        WITH
            xml_file AS (
                SELECT * FROM unnest(xpath( 
                    '/*/*',
                    XMLPARSE(DOCUMENT convert_from(pg_read_binary_file(filename), 'UTF-8'))))
                    --XMLPARSE(DOCUMENT convert_from(pg_read_binary_file('import/data.xml'), 'UTF-8')))
        --read tags from file
            ), columns_name AS (
                SELECT DISTINCT (
                    xpath('name()', unnest(xpath('//*/*', myTempTable.myXmlColumn))))[1]::text AS cn
                 FROM xml_file AS myTempTable(myXmlColumn)
        --get target table cols name and type
            ), target_table_cols AS (  --
                SELECT a.attname, t.typname, a.attnum, cn.cn          
                FROM  pg_attribute a
                LEFT JOIN pg_class c ON c.oid = a.attrelid
                LEFT JOIN pg_type t ON t.oid = a.atttypid
                LEFT JOIN columns_name AS cn ON cn.cn=a.attname
                WHERE a.attnum > 0
                    AND c.relname = target_table --'log_data'
                ORDER BY a.attnum
        --prepare cols to output from xpath
           ), xpath_type_str AS (
	        SELECT CASE WHEN ttca.cn IS NULL THEN 'NULL AS '||ttca.attname 
	                    ELSE '((xpath(''/*/'||attname||'/text()'', myTempTable.myXmlColumn))[1]::text)::'
	                         ||typname||' AS '||attname
	               END 
	            AS xsc
	        FROM target_table_cols AS ttca
           )
          SELECT array_to_string(array_agg(xsc), ',') FROM xpath_type_str
    );
    --RAISE NOTICE '%',
    EXECUTE format('INSERT INTO %s SELECT %s FROM unnest(xpath( ''/*/*'',
             XMLPARSE(DOCUMENT convert_from(pg_read_binary_file(%L), ''UTF-8'')))) 
             AS myTempTable(myXmlColumn)', target_table, columns_name, filename);
END;
$$ LANGUAGE plpgsql;

/*
 * </IMPORT_TO_VARIOUS_TABLE_XML>
 **************************************************************************************************
 * <EXPORT>

--CSV
COPY simple_data TO STDOUT WITH DELIMITER as ';' null as '';
--JSON
SELECT '['||array_to_string(array_agg(row_to_json(simple_data)), ',')||']' FROM simple_data 
--XML
SELECT table_to_xml('simple_data', false, false, '');


 * </EXPORT>
 */

