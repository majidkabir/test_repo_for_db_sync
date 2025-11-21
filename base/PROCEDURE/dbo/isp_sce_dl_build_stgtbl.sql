SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: isp_SCE_DL_BUILD_STGTBL                             */    
/* Creation Date: 06 Nov 2020                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Create or Alter Staging Table                                */    
/*                                                                       */    
/* Called By:  SCE Data Loader                                           */    
/*                                                                       */    
/* PVCS Version: -                                                       */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 06-Nov-2020  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
CREATE PROC [dbo].[isp_SCE_DL_BUILD_STGTBL] (   
    @b_Debug            INT               = 0  
   ,@c_POSTTBLName      NVARCHAR(400)     = ''
   ,@b_Success          INT               = 0    OUTPUT    
   ,@n_ErrNo            INT               = 0    OUTPUT    
   ,@c_ErrMsg           NVARCHAR(250)     = ''   OUTPUT      
)    
AS     
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF     
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL ON  
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON
   SET ANSI_PADDING ON 
  
   /*********************************************/    
   /* Variables Declaration (Start)             */    
   /*********************************************/    
   DECLARE @n_Continue     INT            = 1
         , @n_StartCnt     INT            = @@TRANCOUNT
         , @table_name     SYSNAME        = REPLACE(REPLACE(@c_POSTTBLName, '[', ''),']','')
         , @c_STGTBLName   SYSNAME        = ''
         , @c_STGTBLName1  SYSNAME        = ''
         , @object_id      INT            = 0
         , @FixObject      NVARCHAR(MAX)  = ''
         , @FixPrimaryKey  NVARCHAR(1000) = ''
         , @IndexKey       NVARCHAR(1000) = ''
         , @PrimaryKeyName NVARCHAR(300)  = ''
         , @SQL            VARCHAR(MAX)   = ''
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/   

   IF ISNULL(RTRIM(@table_name), '') = ''
   BEGIN
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = N'11000'  
      SET @c_ErrMsg = N'Target table name cannot be empty. (isp_SCE_DL_BUILD_STGTBL)'
      GOTO QUIT
   END

   IF NOT EXISTS(SELECT 1 FROM sys.objects o WITH (NOLOCK)
                 JOIN sys.schemas s WITH (NOLOCK) 
                 ON o.[schema_id] = s.[schema_id]
                 WHERE s.name + '.' + o.name = @table_name
                 AND o.[type] = 'U'
                 AND o.is_ms_shipped = 0)
   BEGIN
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = N'11001'  
      SET @c_ErrMsg = N'Target table name not found! (isp_SCE_DL_BUILD_STGTBL)'
      GOTO QUIT
   END

   SELECT @PrimaryKeyName = 'PK_' + o.name + '_STG'
        , @c_STGTBLName = '[' + s.name + '].[' + o.name + '_STG]'
        , @c_STGTBLName1 = o.name + '_STG'
        , @object_id = o.[object_id]
   FROM sys.objects o WITH (NOLOCK)
   JOIN sys.schemas s WITH (NOLOCK) 
   ON o.[schema_id] = s.[schema_id]
   WHERE s.name + '.' + o.name = @table_name
   AND o.[type] = 'U'
   AND o.is_ms_shipped = 0

   BEGIN TRY
      IF NOT EXISTS (SELECT 1 
                 FROM INFORMATION_SCHEMA.TABLES WITH (NOLOCK)
                 WHERE '[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']' = @c_STGTBLName)
      BEGIN
         SET @FixObject = CHAR(9) + '  [RowRefNo] INT IDENTITY(1,1) NOT NULL '               
             + CHAR(13) + CHAR(9) + ', [STG_BatchNo] INT NOT NULL '                          
             + CHAR(13) + CHAR(9) + ', [STG_SeqNo] INT NOT NULL '                                   
             + CHAR(13) + CHAR(9) + ', [STG_Status] NVARCHAR(1) NOT NULL DEFAULT (''0'')'    
             + CHAR(13) + CHAR(9) + ', [STG_ErrMsg] NVARCHAR(250) NOT NULL DEFAULT ('''')'
             + CHAR(13) + CHAR(9) + ', [STG_AddDate] DATETIME NOT NULL DEFAULT (getdate())'
             + CHAR(13)

         SET @FixPrimaryKey = CHAR(9) + ', CONSTRAINT [' + @PrimaryKeyName + '] PRIMARY KEY ([RowRefNo] ASC)) '
         SET @IndexKey = ' CREATE INDEX [' + @c_STGTBLName1 + '_Idx01] ON ' + @c_STGTBLName + '(STG_BatchNo) '
                       + ' CREATE INDEX [' + @c_STGTBLName1 + '_Idx02] ON ' + @c_STGTBLName + '(STG_BatchNo,STG_SeqNo) '
                       --+ ' CREATE INDEX [' + @c_STGTBLName1 + '_Idx03] ON ' + @c_STGTBLName + '(STG_BatchNo,STG_Status) '

         ;WITH index_column AS 
         ( SELECT  ic.[object_id]
                 , ic.index_id
                 , ic.is_descending_key
                 , ic.is_included_column
                 , c.name
             FROM sys.index_columns ic WITH (NOLOCK)
             JOIN sys.columns c WITH (NOLOCK) ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
             WHERE ic.[object_id] = @object_id)
         , fk_columns AS 
         ( SELECT  k.constraint_object_id
                 , cname = c.name
                 , rcname = rc.name
             FROM sys.foreign_key_columns k WITH (NOLOCK)
             JOIN sys.columns rc WITH (NOLOCK) ON rc.[object_id] = k.referenced_object_id AND rc.column_id = k.referenced_column_id 
             JOIN sys.columns c WITH (NOLOCK) ON c.[object_id] = k.parent_object_id AND c.column_id = k.parent_column_id
             WHERE k.parent_object_id = @object_id
         )
         SELECT @SQL = 'CREATE TABLE ' + @c_STGTBLName + CHAR(13) + '(' + CHAR(13) + @FixObject + STUFF((
             SELECT CHAR(9) + ', [' + c.name + '] ' + 
                 CASE WHEN c.is_computed = 1
                     THEN 'AS ' + cc.[definition] 
                     ELSE UPPER(tp.name) + 
                         CASE WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text')
                                THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
                              WHEN tp.name IN ('nvarchar', 'nchar', 'ntext')
                                THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
                              WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') 
                                THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
                              WHEN tp.name = 'decimal' 
                                THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                             ELSE ''
                         END +
                         --CASE WHEN c.collation_name IS NOT NULL THEN ' COLLATE ' + c.collation_name ELSE '' END +
                         ' NULL ' +
                         --CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END +
                         CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT' + dc.[definition] ELSE '' END + 
                         CASE WHEN ic.is_identity = 1 THEN ' IDENTITY(' + CAST(ISNULL(ic.seed_value, '0') AS CHAR(1)) + ',' + CAST(ISNULL(ic.increment_value, '1') AS CHAR(1)) + ')' ELSE '' END 
                 END + CHAR(13)
             FROM sys.columns c WITH (NOLOCK)
             JOIN sys.types tp WITH (NOLOCK) ON c.user_type_id = tp.user_type_id
             LEFT JOIN sys.computed_columns cc WITH (NOLOCK) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
             LEFT JOIN sys.default_constraints dc WITH (NOLOCK) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
             LEFT JOIN sys.identity_columns ic WITH (NOLOCK) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
             WHERE c.[object_id] = @object_id
              AND (ic.is_identity <> 1 OR ic.is_identity IS NULL OR ic.is_identity = 0)
             ORDER BY c.column_id
             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, CHAR(9) + '')
             + @FixPrimaryKey
             + @IndexKey

             /*Other constraint features*/
             ----Construct primary Key function
             --+ ISNULL((SELECT CHAR(9) + ', CONSTRAINT [' + k.name + '] PRIMARY KEY (' + 
             --                (SELECT STUFF((
             --                     SELECT ', [' + c.name + '] ' + CASE WHEN ic.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END
             --                     FROM sys.index_columns ic WITH (NOLOCK)
             --                     JOIN sys.columns c WITH (NOLOCK) ON c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
             --                     WHERE ic.is_included_column = 0
             --                         AND ic.[object_id] = k.parent_object_id 
             --                         AND ic.index_id = k.unique_index_id     
             --                         AND (c.is_identity <> 1 OR c.is_identity IS NULL OR c.is_identity = 0)
             --                     FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''))
             --        + ')' + CHAR(13)
             --        FROM sys.key_constraints k WITH (NOLOCK)
             --        WHERE k.parent_object_id = @object_id 
             --            AND k.[type] = 'PK'), '') + ')'  + CHAR(13)
         
         
         
             ----Construct Foreign Key Function
             --+ ISNULL((SELECT (
             --    SELECT CHAR(13) +
             --         'ALTER TABLE ' + @c_STGTBLName + ' WITH' 
             --        + CASE WHEN fk.is_not_trusted = 1 
             --            THEN ' NOCHECK' 
             --            ELSE ' CHECK' 
             --          END + 
             --          ' ADD CONSTRAINT [' + fk.name  + '] FOREIGN KEY(' 
             --          + STUFF((
             --            SELECT ', [' + k.cname + ']'
             --            FROM fk_columns k
             --            WHERE k.constraint_object_id = fk.[object_id]
             --            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
             --           + ')' +
             --          ' REFERENCES [' + SCHEMA_NAME(ro.[schema_id]) + '].[' + ro.name + '] ('
             --          + STUFF((
             --            SELECT ', [' + k.rcname + ']'
             --            FROM fk_columns k
             --            WHERE k.constraint_object_id = fk.[object_id]
             --            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
             --           + ')'
             --        + CASE 
             --            WHEN fk.delete_referential_action = 1 THEN ' ON DELETE CASCADE' 
             --            WHEN fk.delete_referential_action = 2 THEN ' ON DELETE SET NULL'
             --            WHEN fk.delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT' 
             --            ELSE '' 
             --          END
             --        + CASE 
             --            WHEN fk.update_referential_action = 1 THEN ' ON UPDATE CASCADE'
             --            WHEN fk.update_referential_action = 2 THEN ' ON UPDATE SET NULL'
             --            WHEN fk.update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT'  
             --            ELSE '' 
             --          END 
             --        + CHAR(13) + 'ALTER TABLE ' + @c_STGTBLName + ' CHECK CONSTRAINT [' + fk.name  + ']' + CHAR(13)
             --    FROM sys.foreign_keys fk WITH (NOLOCK)
             --    JOIN sys.objects ro WITH (NOLOCK) ON ro.[object_id] = fk.referenced_object_id
             --    WHERE fk.parent_object_id = @object_id
             --    FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)')), '')
         
             ----Create Unique Key
            --+ ISNULL(((SELECT
            --      CHAR(13) + 'CREATE' + CASE WHEN i.is_unique = 1 THEN ' UNIQUE' ELSE '' END 
            --             + ' NONCLUSTERED INDEX [' + i.name + '] ON ' + @c_STGTBLName + ' (' +
            --             STUFF((
            --             SELECT ', [' + c.name + ']' + CASE WHEN c.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
            --             FROM index_column c
            --             WHERE c.is_included_column = 0
            --                 AND c.index_id = i.index_id
            --             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')'  
            --             + ISNULL(CHAR(13) + 'INCLUDE (' + 
            --                 STUFF((
            --                 SELECT ', [' + c.name + ']'
            --                 FROM index_column c
            --                 WHERE c.is_included_column = 1
            --                     AND c.index_id = i.index_id
            --                 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')', '')  + CHAR(13)
            --     FROM sys.indexes i WITH (NOLOCK)
            --     WHERE i.[object_id] = @object_id
            --         AND i.is_primary_key = 0
            --         AND i.[type] = 2
            --     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
            -- ), '')
         /*Other constraint features*/
         IF @b_Debug = 1
         BEGIN
            PRINT @SQL
         END
      END
      ELSE
      BEGIN
         DECLARE @c_DropCons NVARCHAR(MAX) = ''
               , @c_DropCols NVARCHAR(MAX) = ''
               , @c_AddCols  NVARCHAR(MAX) = ''
               , @n_POSTID   INT           = 0
               , @n_STGID    INT           = 0
               , @c_ColName  NVARCHAR(500) = ''
               , @c_DataType NVARCHAR(200) = ''
               , @c_Nullable NVARCHAR(50)  = ''
               , @c_DefVal   NVARCHAR(200) = ''
               , @c_ConName  NVARCHAR(500) = ''

         DECLARE @t_POSTTBL TABLE (
            ID             INT IDENTITY(1,1) NOT NULL
           ,ColumnName     NVARCHAR(500) NOT NULL DEFAULT ''
           ,DataType       NVARCHAR(200) NOT NULL DEFAULT ''
           ,Nullable       NVARCHAR(50) NOT NULL DEFAULT ''
           ,DefaultVal     NVARCHAR(200) NOT NULL DEFAULT ''
           ,ConstraintName NVARCHAR(500) NULL DEFAULT ''
         )
         
         DECLARE @t_STGTBL TABLE (
            ID             INT IDENTITY(1,1) NOT NULL
           ,ColumnName     NVARCHAR(500) NOT NULL DEFAULT ''
           ,DataType       NVARCHAR(200) NOT NULL DEFAULT ''
           ,Nullable       NVARCHAR(50) NOT NULL DEFAULT ''
           ,DefaultVal     NVARCHAR(200) NOT NULL DEFAULT ''
           ,ConstraintName NVARCHAR(500) NULL DEFAULT ''
         )
       
         INSERT INTO @t_POSTTBL(ColumnName, DataType, Nullable, DefaultVal, ConstraintName)
         SELECT c.[name] AS ColumnName, CASE WHEN c.is_computed = 1 THEN 'AS ' + cc.[definition] 
                  ELSE UPPER(tp.name) + 
                        CASE WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('nvarchar', 'nchar', 'ntext')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') 
                           THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
                        WHEN tp.name = 'decimal' 
                           THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                        ELSE ''
                        END
                  END AS DataType
               ,CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END AS Nullable
               ,CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT ' + dc.[definition] ELSE '' END  AS DefaultVal
               ,dc.[name] AS ConstraintName
         FROM sys.columns c WITH (NOLOCK)
         JOIN sys.types tp WITH (NOLOCK) ON c.user_type_id = tp.user_type_id
         LEFT JOIN sys.computed_columns cc WITH (NOLOCK) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
         LEFT JOIN sys.default_constraints dc WITH (NOLOCK) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
         LEFT JOIN sys.identity_columns ic WITH (NOLOCK) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
         WHERE c.[object_id] = OBJECT_ID(@c_POSTTBLName)
         AND (ic.is_identity <> 1 OR ic.is_identity IS NULL OR ic.is_identity = 0)
         ORDER BY c.column_id

         INSERT INTO @t_STGTBL(ColumnName, DataType, Nullable, DefaultVal, ConstraintName)
         SELECT c.[name] AS ColumnName, CASE WHEN c.is_computed = 1 THEN 'AS ' + cc.[definition] 
                  ELSE UPPER(tp.name) + 
                        CASE WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('nvarchar', 'nchar', 'ntext')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') 
                           THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
                        WHEN tp.name = 'decimal' 
                           THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                        ELSE ''
                        END
                  END AS DataType
               ,CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END AS Nullable
               ,CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT ' + dc.[definition] ELSE '' END  AS DefaultVal
               ,dc.[name] AS ConstraintName
         FROM sys.columns c WITH (NOLOCK)
         JOIN sys.types tp WITH (NOLOCK) ON c.user_type_id = tp.user_type_id
         LEFT JOIN sys.computed_columns cc WITH (NOLOCK) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
         LEFT JOIN sys.default_constraints dc WITH (NOLOCK) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
         LEFT JOIN sys.identity_columns ic WITH (NOLOCK) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
         WHERE c.[object_id] = OBJECT_ID(@c_STGTBLName)
         AND (ic.is_identity <> 1 OR ic.is_identity IS NULL OR ic.is_identity = 0)
         ORDER BY c.column_id

         DECLARE C_CHECKING CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ID, ColumnName, DataType, Nullable, DefaultVal, ConstraintName FROM @t_POSTTBL 
         ORDER BY ID ASC
         
         OPEN C_CHECKING
         FETCH NEXT FROM C_CHECKING INTO @n_POSTID, @c_ColName, @c_DataType, @c_Nullable, @c_DefVal, @c_ConName
         
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SET @n_STGID = 0
            DELETE FROM @t_STGTBL WHERE ID IN (1,2,3,4,5)
            SELECT @n_STGID=ID FROM @t_STGTBL 
                      WHERE ColumnName = @c_ColName
                      AND DataType = @c_DataType
                      --AND Nullable = @c_Nullable
                      AND DefaultVal = @c_DefVal

            IF @n_STGID <> 0
            BEGIN
               DELETE FROM @t_POSTTBL WHERE ID = @n_POSTID
               DELETE FROM @t_STGTBL WHERE ID = @n_STGID
            END   
         FETCH NEXT FROM C_CHECKING INTO @n_POSTID, @c_ColName, @c_DataType, @c_Nullable, @c_DefVal, @c_ConName
         END
         CLOSE C_CHECKING
         DEALLOCATE C_CHECKING

         SELECT @c_DropCons=STRING_AGG(ConstraintName, ',')
         FROM @t_STGTBL
         WHERE ConstraintName IS NOT NULL
         AND ConstraintName <> ''
         
         SELECT @c_DropCols=STRING_AGG(ColumnName, ',')
         FROM @t_STGTBL
         WHERE ColumnName IS NOT NULL
         AND ColumnName <> ''
         
         SELECT @c_AddCols = STUFF((SELECT ',' + ColumnName + ' ' + DataType + ' ' + Nullable + ' ' 
                              + CASE WHEN ISNULL(RTRIM(DefaultVal),'') <> ''
                                     THEN DefaultVal
                                     ELSE ''
                                 END
                                FROM @t_POSTTBL
                                ORDER BY ID ASC
                                FOR XML PATH('')), 1, 1, '')
         
         IF @b_Debug =1
         BEGIN
            PRINT @c_AddCols
         END 

         IF ISNULL(RTRIM(@c_DropCons), '') <> '' 
          
         BEGIN
            SET @SQL += ' ALTER TABLE ' + @c_STGTBLName
                        + ' DROP CONSTRAINT ' + @c_DropCons                 
         END
         IF ISNULL(RTRIM(@c_DropCols), '') <> ''
         BEGIN
            SET @SQL += ' ALTER TABLE ' + @c_STGTBLName
                        + ' DROP COLUMN ' + @c_DropCols
         END
         IF ISNULL(RTRIM(@c_AddCols), '') <> ''
         BEGIN
            SET @SQL += ' ALTER TABLE ' + @c_STGTBLName
                        + ' ADD ' + @c_AddCols
         END

         IF @b_Debug =1
         BEGIN
            PRINT @SQL
         END
      END

      EXEC(@SQL)

      IF EXISTS (SELECT 1 
                 FROM INFORMATION_SCHEMA.TABLES WITH (NOLOCK)
                 WHERE TABLE_SCHEMA = 'dbo'
                 AND   TABLE_NAME   = 'TBL_PURGECONFIG')
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM [dbo].[TBL_PURGECONFIG] WITH (NOLOCK)
                        WHERE TBLName = @c_STGTBLName) 
            AND ISNULL(RTRIM(@c_STGTBLName),'') <> '' 
         BEGIN
            INSERT INTO [dbo].[TBL_PURGECONFIG] (Item
                                               , TBLName
                                               , [Description]
                                               , Threshold
                                               , Date_Col
                                               , PurgeGroup)
                                          VALUES(@c_STGTBLName1
                                               , @c_STGTBLName
                                               , 'Purge ' + @c_STGTBLName1 + ' Table'
                                               , '14'
                                               , 'STG_AddDate'
                                               , 'RND')
         END
      END

   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = N'11002'  
      SET @c_ErrMsg = N'Unable to Create/Update Staging Table. ' + ERROR_MESSAGE() + '(isp_SCE_DL_BUILD_STGTBL)'
      GOTO QUIT
   END CATCH

QUIT:  
   IF @n_Continue=3  -- Error Occured - Process And Return          
   BEGIN          
      SELECT @b_success = 0          
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartCnt          
      BEGIN                   
         ROLLBACK TRAN          
      END          
      ELSE          
      BEGIN          
         WHILE @@TRANCOUNT > @n_StartCnt          
         BEGIN          
            COMMIT TRAN          
         END          
      END    
      RETURN          
   END          
   ELSE          
   BEGIN    
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''
      BEGIN    
         SELECT @b_Success = 0    
      END    
      ELSE    
      BEGIN     
         SELECT @b_Success = 1     
      END            
    
      WHILE @@TRANCOUNT > @n_StartCnt          
      BEGIN          
         COMMIT TRAN          
      END         
      RETURN    
   END    
   /***********************************************/    
   /* Std - Error Handling (End)                  */    
   /***********************************************/    
END  --End Procedure 

GO