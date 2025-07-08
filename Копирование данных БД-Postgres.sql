-- Удаляем функцию
DROP FUNCTION IF EXISTS generate_insert_statements(text, text);

-- Из данных таблицы создаёт INSERT запросы для добавления в такую же таблицу другой БД
CREATE OR REPLACE FUNCTION generate_insert_statements(
    p_table_name text,
    p_schema_name text DEFAULT 'public'
)
RETURNS TABLE (insert_statement text) AS $$
DECLARE
    v_column_list text := '';
    v_sql text := '';
    v_column_record record;
    v_first_column boolean := true;
    v_table_exists boolean;
    v_status_message text;
BEGIN
    -- Проверяем указанную таблицу
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name = p_table_name 
          AND table_schema = p_schema_name
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
        RETURN;
    END IF;
    
    -- Получаем список солбцов
    FOR v_column_record IN 
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = p_table_name 
          AND table_schema = p_schema_name
        ORDER BY ordinal_position
    LOOP
        IF NOT v_first_column THEN
            v_column_list := v_column_list || ', ';
        END IF;
        v_column_list := v_column_list || quote_ident(v_column_record.column_name);
        v_first_column := false;
    END LOOP;
    
    -- Строим динамический SQL для INSERT запроса
    v_sql := 'SELECT ''INSERT INTO ' || quote_ident(p_schema_name) || '.' || quote_ident(p_table_name) || 
              ' (' || v_column_list || ') VALUES ('' || ';
    
    v_first_column := true;
    FOR v_column_record IN 
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = p_table_name 
          AND table_schema = p_schema_name
        ORDER BY ordinal_position
    LOOP
        IF NOT v_first_column THEN
            v_sql := v_sql || ' || '', '' || ';
        END IF;
        
        -- Определяем тип данных
        IF v_column_record.data_type IN ('character varying', 'text', 'character', 'char', 'xml') THEN
            v_sql := v_sql || 'CASE WHEN ' || quote_ident(v_column_record.column_name) || 
                     ' IS NULL THEN ''NULL'' ELSE quote_literal(' || 
                     quote_ident(v_column_record.column_name) || '::text) END';
        ELSIF v_column_record.data_type IN ('date', 'timestamp without time zone', 'timestamp with time zone', 'time without time zone', 'time with time zone') THEN
            v_sql := v_sql || 'CASE WHEN ' || quote_ident(v_column_record.column_name) || 
                     ' IS NULL THEN ''NULL'' ELSE quote_literal(' || 
                     quote_ident(v_column_record.column_name) || '::text) END';
        ELSIF v_column_record.data_type = 'boolean' THEN
            v_sql := v_sql || 'CASE WHEN ' || quote_ident(v_column_record.column_name) || 
                     ' IS NULL THEN ''NULL'' ELSE CASE WHEN ' || 
                     quote_ident(v_column_record.column_name) || ' THEN ''true'' ELSE ''false'' END END';
        ELSIF v_column_record.data_type = 'uuid' THEN
            v_sql := v_sql || 'CASE WHEN ' || quote_ident(v_column_record.column_name) || 
                     ' IS NULL THEN ''NULL'' ELSE quote_literal(' || 
                     quote_ident(v_column_record.column_name) || '::text) END';
        ELSE
            v_sql := v_sql || 'CASE WHEN ' || quote_ident(v_column_record.column_name) || 
                     ' IS NULL THEN ''NULL'' ELSE COALESCE(' || 
                     quote_ident(v_column_record.column_name) || '::text, ''NULL'') END';
        END IF;
        
        v_first_column := false;
    END LOOP;
    
    v_sql := v_sql || ' || '');'' FROM ' || quote_ident(p_schema_name) || '.' || quote_ident(p_table_name);
    
    v_status_message := 'Generating INSERT statements for ' || p_schema_name || '.' || p_table_name;
    RAISE NOTICE '%', v_status_message;
    
    RETURN QUERY EXECUTE v_sql;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating INSERT statements: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- Выводим результат
SELECT * FROM generate_insert_statements('Имя_таблицы', 'Имя_схемы');


-- Удаляем процедуру
DROP FUNCTION IF EXISTS generate_insert_statements(text, text);