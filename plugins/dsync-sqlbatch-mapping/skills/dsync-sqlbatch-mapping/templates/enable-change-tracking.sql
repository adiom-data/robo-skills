-- SQL Server Change Tracking Enablement Script Template
-- Replace {{DATABASE}} and add your tables to the @tables variable

USE {{DATABASE}};
GO

BEGIN
    -- 1. Enable Change Tracking at the Database Level
    IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
    BEGIN
        ALTER DATABASE {{DATABASE}}
        SET CHANGE_TRACKING = ON
        (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
        PRINT 'Change Tracking enabled for database: ' + DB_NAME();
    END
    ELSE
    BEGIN
        PRINT 'Change Tracking is already enabled for database: ' + DB_NAME();
    END

    -- 2. Enable Change Tracking for each Table
    -- Add all tables that need change tracking for your dsync mappings
    DECLARE @tables TABLE (SchemaName NVARCHAR(50), TableName NVARCHAR(100));
    INSERT INTO @tables (SchemaName, TableName) VALUES 
    -- Add your tables here:
    ('dbo', 'TableName1'),
    ('dbo', 'TableName2'),
    ('dbo', 'ChildTable');
    -- Example for AdventureWorks:
    -- ('Sales', 'Customer'),
    -- ('Sales', 'SalesOrderHeader'),
    -- ('Sales', 'SalesOrderDetail'),
    -- ('Person', 'Person'),
    -- ('Person', 'Address'),
    -- ('Production', 'Product'),
    -- ('Production', 'ProductReview');

    DECLARE @SchemaName NVARCHAR(50);
    DECLARE @TableName NVARCHAR(100);
    DECLARE @FullTableName NVARCHAR(200);
    DECLARE table_cursor CURSOR FOR SELECT SchemaName, TableName FROM @tables;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FullTableName = @SchemaName + '.' + @TableName;
        
        IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID(@FullTableName))
        BEGIN
            PRINT 'Enabling Change Tracking for table: ' + @FullTableName;
            DECLARE @sql NVARCHAR(MAX);
            SET @sql = 'ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + 
                       ' ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON)';
            EXEC sp_executesql @sql;
        END
        ELSE
        BEGIN
            PRINT 'Change Tracking is already enabled for table: ' + @FullTableName;
        END

        FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    PRINT '';
    PRINT 'Change Tracking setup complete.';
END
GO

-- Verify change tracking status
SELECT 
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    CASE WHEN ct.object_id IS NOT NULL THEN 'Enabled' ELSE 'Disabled' END AS ChangeTracking
FROM sys.tables t
LEFT JOIN sys.change_tracking_tables ct ON ct.object_id = t.object_id
WHERE t.is_ms_shipped = 0
ORDER BY SchemaName, TableName;
GO
