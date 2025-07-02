-- Получает данные указаной таблицы и создаёт из них INSERT запросы для добавления в такую же таблицу в другой БД

USE [Имя БД]; -- [test]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GenerateInsertStatements')
DROP PROCEDURE GenerateInsertStatements;
GO

-- Создаём процедуру
CREATE PROCEDURE GenerateInsertStatements
    @TableName NVARCHAR(128),
    @SchemaName NVARCHAR(128) = 'dbo'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Проверка существования таблицы
    IF NOT EXISTS (
        SELECT 1 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName
    )
    BEGIN
        SELECT 'Ошибка' AS Status, 'Таблица не существует' AS Message;
        RETURN;
    END
    
    -- Создаем временную таблицу для хранения результатов
    CREATE TABLE #InsertStatements (InsertStatement NVARCHAR(MAX));
    
    -- Получаем список столбцов с гарантией правильного формата
    DECLARE @ColumnList NVARCHAR(MAX) = '';
    
    SELECT @ColumnList = @ColumnList + 
           CASE WHEN @ColumnList = '' THEN '' ELSE ', ' END + 
           '[' + COLUMN_NAME + ']'
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName
    ORDER BY ORDINAL_POSITION;
    
    -- Формируем динамический SQL для генерации INSERT-запросов
    DECLARE @SQL NVARCHAR(MAX) = '
    INSERT INTO #InsertStatements
    SELECT ''INSERT INTO [' + @SchemaName + '].[' + @TableName + '] (' + @ColumnList + ') VALUES ('' + ';
    
    -- Добавляем обработку каждого столбца
    DECLARE @FirstColumn BIT = 1;
    DECLARE @ColumnName NVARCHAR(128);
    DECLARE @DataType NVARCHAR(128);
    
    DECLARE column_cursor CURSOR FOR
    SELECT COLUMN_NAME, DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName
    ORDER BY ORDINAL_POSITION;
    
    OPEN column_cursor;
    FETCH NEXT FROM column_cursor INTO @ColumnName, @DataType;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FirstColumn = 0
            SET @SQL = @SQL + ' + '', '' + ';
        
        SET @SQL = @SQL + 
            CASE 
                WHEN @DataType IN ('varchar', 'nvarchar', 'char', 'nchar', 'text', 'ntext', 'xml')
                    THEN 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE '''''''' + REPLACE(CAST([' + @ColumnName + '] AS NVARCHAR(MAX)), '''''''', '''''''''''') + '''''''' END'
WHEN @DataType IN ('date', 'datetime', 'datetime2', 'time')
    THEN 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE '''''''' + CONVERT(NVARCHAR(50), [' + @ColumnName + '], 121) + '''''''' END'
WHEN @DataType = 'smalldatetime'
    THEN 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE '''''''' + CONVERT(NVARCHAR(16), FORMAT([' + @ColumnName + '], ''yyyy-dd-MM HH:mm'')) + '''''''' END'
                WHEN @DataType = 'bit'
                    THEN 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE CASE WHEN [' + @ColumnName + '] = 1 THEN ''1'' ELSE ''0'' END END'
                WHEN @DataType = 'uniqueidentifier'
                    THEN 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE '''''''' + CAST([' + @ColumnName + '] AS NVARCHAR(50)) + '''''''' END'
                ELSE 'CASE WHEN [' + @ColumnName + '] IS NULL THEN ''NULL'' ELSE CAST([' + @ColumnName + '] AS NVARCHAR(MAX)) END'
            END;
        
        SET @FirstColumn = 0;
        FETCH NEXT FROM column_cursor INTO @ColumnName, @DataType;
    END;
    
    CLOSE column_cursor;
    DEALLOCATE column_cursor;
    
    -- Завершаем формирование SQL
    SET @SQL = @SQL + ' + '');'' FROM [' + @SchemaName + '].[' + @TableName + ']';
    
    -- Выполняем динамический SQL
    BEGIN TRY
        EXEC sp_executesql @SQL;
        
        -- Исправляем возможные проблемы с кавычками
        UPDATE #InsertStatements 
        SET InsertStatement = REPLACE(InsertStatement, '''''''NULL''''''', 'NULL');
        
         -- Возвращаем результаты
        SELECT InsertStatement 
        FROM #InsertStatements;
        
        SELECT 'Успешно' AS Status, 
               CASE 'INSERT-запросы сгенерированы' END AS Message,
               (SELECT COUNT(*) FROM #InsertStatements) AS [Количество запросов];
    END TRY
    BEGIN CATCH
        SELECT 'Ошибка' AS Status,
               ERROR_MESSAGE() AS Message,
               ERROR_LINE() AS ErrorLine;
    END CATCH
    
    -- Удаляем временную таблицу
    DROP TABLE #InsertStatements;
END;
GO

-- Выполняем процедуру
EXEC GenerateInsertStatements 
    @TableName = 'Таблица', -- 'TestTable'
    @SchemaName = 'Имя схемы'; -- 'dbo'
GO

-- Удаляем процедуру
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GenerateInsertStatements')
DROP PROCEDURE GenerateInsertStatements;
GO
