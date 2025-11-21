SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_ReTriggerTransmitLog_MoveDataBYLine             */
/* Creation Date:09-Apr-2020                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: - To move archived data back to live db.                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 03-Nov-2021  CSCHONG   1.1   Devops Scripts combine                  */
/* 03-Nov-2021  CSCHONG   1.2   fix not allow move itrn (CS01)          */
/* 01-Mar-2022  CSCHONG   1.3   create index for temp table (CS02)      */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ReTriggerTransmitLog_MoveDataBYLine]
     @c_SourceDB    NVARCHAR(30)
   , @c_TargetDB    NVARCHAR(30)
   , @c_TableSchema NVARCHAR(10)
   , @c_TableName   NVARCHAR(50)
   , @c_KeyColumn   NVARCHAR(50)
   , @c_DocKey      NVARCHAR(50)
   , @c_KeyColumn1  NVARCHAR(50) = ''
   , @c_DocKey1     NVARCHAR(50) = ''
   , @c_KeyColumn2  NVARCHAR(50) = ''
   , @c_DocKey2     NVARCHAR(50) = ''
   , @c_KeyColumn3  NVARCHAR(50) = ''
   , @c_DocKey3     NVARCHAR(50) = ''
   , @b_Success     int           OUTPUT
   , @n_err         int           OUTPUT
   , @c_errmsg      NVARCHAR(250) OUTPUT
   , @b_Debug       INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_DBTableName   NVARCHAR(100)
      , @c_SQL           NVARCHAR(MAX)
      , @c_ColName       NVARCHAR(MAX)
      , @c_Exists        NVARCHAR(1)
      , @c_RecFound      NVARCHAR(1)
      , @c_ExecArguments NVARCHAR(MAX)
      , @n_SchemaId      INT
      , @n_ObjId         INT
      , @c_IdentityCol   NVARCHAR(50)
      , @n_continue      int 
      , @n_StartTCnt     INT 
      , @c_condition     NVARCHAR(500) = ''
      , @c_condition1    NVARCHAR(500) = ''
      , @c_condition2    NVARCHAR(500) = ''
      , @c_condition3    NVARCHAR(500) = ''
      , @c_FullSQL       NVARCHAR(MAX) = ''

     SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   
     SELECT @n_err = 0 , @c_errmsg = ''
 
 --While @@trancount < @n_StartTCnt
 --BEGIN TRAN

 --  WHILE @@TRANCOUNT > 0   
 --  BEGIN  
 --     COMMIT TRAN  
 --  END 

     IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'PickDetail'
     BEGIN
     
        SELECT @n_Continue = 3  
        SET @n_err = 700003
        SELECT @c_errmsg = 'ERROR. Not allow to move PickDetail record. (isp_ReTriggerTransmitLog_MoveDataBYLine)'
        
        GOTO QUIT
     END

     IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = '%liateDkciP%' -- Pass in from isp_MovePickDetail, Then allow to move PickDetail.
     BEGIN
        SET @c_TableName = REVERSE(@c_TableName)
        SET @c_TableName = REPLACE(@c_TableName,'%','')
        SET @c_TableName = ISNULL(RTRIM(LTRIM(@c_TableName)),'')
     END

     --IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'UCC' AND ISNULL(RTRIM(LTRIM(@c_KeyColumn)),'') = 'UCC_RowRef'
     --BEGIN
     
     --   SELECT @n_Continue = 3
     --   SET @n_err = 700004  
     --   SELECT @c_errmsg = 'ERROR. Not allow to move UCC by column UCC_RowRef. (isp_ReTriggerTransmitLog_MoveDataBYLine)'
     
     --   GOTO QUIT
     --END
     
     SET @c_ColName = ''
     SET @c_DBTableName = @c_TargetDB + '.'+ @c_TableSchema + '.' + @c_TableName

     IF COL_LENGTH(@c_DBTableName, @c_KeyColumn) IS NULL
     BEGIN
     
        SELECT @n_Continue = 3 
        SET @n_err = 700005 
        SELECT @c_errmsg = 'ERROR. Table/Column does not exist. (isp_ReTriggerTransmitLog_MoveDataBYLine)'
        
        GOTO QUIT
     END
     
     IF ISNULL(OBJECT_ID('tempdb..#TargetTbl'),'') <> ''
     BEGIN
        DROP TABLE #TargetTbl
     END
     
     IF ISNULL(OBJECT_ID('tempdb..#SourceTbl'),'') <> ''
     BEGIN
        DROP TABLE #SourceTbl
     END

     CREATE TABLE #TargetTbl (
          Table_Catalog NVARCHAR(50)  NULL
        , Table_Name    NVARCHAR(100) NULL
        , Column_Name   NVARCHAR(100) NULL
     )

    Create index IDX_TargetTbl ON #TargetTbl (Table_Name, Column_Name)     --CS02
     
     CREATE TABLE #SourceTbl (
          Table_Catalog NVARCHAR(50)  NULL
        , Table_Name    NVARCHAR(100) NULL
        , Column_Name   NVARCHAR(100) NULL
     )

    Create index IDX_SourceTbl ON #SourceTbl (Table_Name, Column_Name)     --CS02
       ------------------------------------------------
       -- Retrieve TargetDB Identity Column (Start)
       ------------------------------------------------
       SET @n_SchemaId = SCHEMA_ID(@c_TableSchema)
       
       IF ISNULL(@c_KeyColumn1,'') <> '' AND ISNULL(@c_DocKey1,'') <> ''
       BEGIN
        SET @c_condition =  ' AND ' + QUOTENAME(@c_KeyColumn1, '[') + ' =  @c_DocKey1 '
       END
       
       IF ISNULL(@c_KeyColumn2,'') <> '' AND ISNULL(@c_DocKey2,'') <> ''
       BEGIN
        SET @c_condition1 = ' AND ' + QUOTENAME(@c_KeyColumn2, '[') + ' =  @c_DocKey2 '
       END
       
       IF ISNULL(@c_KeyColumn3,'') <> '' AND ISNULL(@c_DocKey3,'') <> ''
       BEGIN
        SET @c_condition2 = ' AND ' + QUOTENAME(@c_KeyColumn3, '[') + ' =  @c_DocKey3 '
       END
       
       --IF ISNULL(@c_KeyColumn4,'') <> '' AND ISNULL(@c_DocKey4,'') <> ''
       --BEGIN
       -- SET @n_condition3 = 'AND QUOTENAME(@c_KeyColumn4, ''['') =  + @c_DocKey4 '
       --END

       IF ISNULL(@n_SchemaId,'') <> ''
       BEGIN
          SET @c_SQL = ''
          SET @c_SQL = ('SELECT @n_ObjId = [Object_Id] FROM ' +
                        QUOTENAME(@c_TargetDB, '[') + '.' + 'sys.all_objects ' +
                        'WHERE Type = ''U'' ' +
                        'AND Name =  @c_TableName ' +
                        'AND [Schema_Id] = @n_SchemaId ')
       
          EXEC sp_executesql @c_SQL
                           , N' @c_TableName NVARCHAR(30) ,@n_SchemaId INT, @n_ObjId INT OUTPUT'
                           , @c_TableName ,@n_SchemaId, @n_ObjId OUTPUT
       
          IF ISNULL(@n_ObjId,'') <> ''
          BEGIN
             SET @c_SQL = ''
             SET @c_SQL = ('SELECT @c_IdentityCol = [Name] FROM ' +
                           QUOTENAME(@c_TargetDB, '[') + '.' + 'sys.identity_columns ' +
                           'WHERE [Object_Id] = @n_ObjId ')
       
             EXEC sp_executesql @c_SQL
                              , N'@n_ObjId INT, @c_IdentityCol NVARCHAR(50) OUTPUT'
                              , @n_ObjId, @c_IdentityCol OUTPUT
          END
          ELSE
          BEGIN
             SET @c_IdentityCol = '' -- No Primary Key
          END
       END -- ISNULL(@n_SchemaId,'') <> ''

       IF @b_Debug = 1
       BEGIN
          SELECT @n_ObjId '@n_ObjId', @n_SchemaId '@n_SchemaId', @c_IdentityCol '@c_IdentityCol'
       END
       ------------------------------------------------
       -- Retrieve TargetDB Identity Column (End)
       ------------------------------------------------
       
       SET @c_SQL = ''
       SET @c_SQL = ('SELECT Table_Catalog, Table_Name, Column_Name FROM ' +
                     QUOTENAME(@c_TargetDB, '[') + '.' + 'Information_Schema.Columns ' +
                     'WHERE Data_Type <> ''TimeStamp'' ' +
                     'AND Table_Schema =  @c_TableSchema  ' +
                     'AND Table_Name =  @c_TableName ')
       
       INSERT INTO #TargetTbl (Table_Catalog, Table_Name, Column_Name)
       EXEC sp_executesql @c_SQL  
                        , N'@c_TableSchema NVARCHAR(10), @c_TableName NVARCHAR(30)'
                        , @c_TableSchema, @c_TableName 
       
       SET @c_SQL = ''
       SET @c_SQL = ('SELECT Table_Catalog, Table_Name, Column_Name FROM ' +
              QUOTENAME(@c_SourceDB, '[') + '.' + 'Information_Schema.Columns ' +
              'WHERE Data_Type <> ''TimeStamp'' ' +
              'AND Table_Schema =  @c_TableSchema  ' +
              'AND Table_Name =  @c_TableName ')

       INSERT INTO #SourceTbl (Table_Catalog, Table_Name, Column_Name)
       EXEC sp_executesql @c_SQL
                      , N'@c_TableSchema NVARCHAR(10), @c_TableName NVARCHAR(30)'
                        , @c_TableSchema, @c_TableName  
       
       
       IF EXISTS (SELECT 1 FROM #TargetTbl T
                  LEFT JOIN #SourceTbl S
                  ON (T.Table_Name = S.Table_Name AND T.Column_Name = S.Column_Name)
                  WHERE ISNULL(RTRIM(S.Column_Name),'') = '')
       BEGIN
          
          SELECT @n_Continue = 3  
          SET @n_err = 700006
          SELECT @c_errmsg =  'ERROR. Target / Source Table Column Unmatched. (isp_ReTriggerTransmitLog_MoveDataBYLine)'
       
          SELECT T.*, S.* FROM #TargetTbl T
          LEFT JOIN #SourceTbl S
          ON (T.Table_Name = S.Table_Name AND T.Column_Name = S.Column_Name)
          WHERE ISNULL(RTRIM(S.Column_Name),'') = ''
       
          GOTO QUIT
       END
       ELSE
       BEGIN
          IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'Itrn' -- ntrItrnAdd: TrafficCop 9
          BEGIN
             SET @c_Exists = '0'
             SET @c_SQL = ''
             SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +
                           'FROM ' +
                            QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +
                           'WHERE TrafficCop = ''9'' AND ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey '
       
             SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_Exists NVARCHAR(1) OUTPUT'
             EXEC sp_executesql @c_SQL
                              , @c_ExecArguments
                              , @c_DocKey
                              , @c_Exists OUTPUT
       
             IF @c_Exists = '0'
             BEGIN
                
              --CS01 START    
             --SELECT @n_Continue = 3   
             --SET @n_err = 700007   
             --SELECT @c_errmsg = 'ERROR. Not allow to move ITRN record. (isp_ReTriggerTransmitLog_MoveData)'  
          
                --GOTO QUIT  
                    BEGIN TRAN
                    SET @c_SQL = ''  
                    SET @c_SQL = N'UPDATE ' +  
                                    QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') +  
                                   ' SET TrafficCop = ''9'' ' + CHAR(13) +
                                   ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey '  
  
  
                         IF @b_Debug = 1  
                         BEGIN  
                           SELECT @c_SQL '@c_SQL'  
                         END  
                        --EXEC sp_executesql @c_SQL    
                        SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50)'  
                        EXEC sp_executesql @c_SQL  
                                         , @c_ExecArguments  
                                         , @c_DocKey  


                           IF @@ERROR = 0   
                           BEGIN  
                              COMMIT TRAN  
                           END  
                           ELSE  
                           BEGIN  
                              ROLLBACK TRAN  
                              GOTO QUIT  
                           END
             END
          END
       
          SET @c_Exists = '0'
          SET @c_SQL = ''
          SET @c_FullSQL  = ''
          SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +
                        'FROM ' +
                        QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +
                         ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey '
       
         SET @c_FullSQL = @c_SQL + CHAR(13) + @c_condition + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3   
       
         SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_DocKey1 NVARCHAR(50), ' +
                                 '@c_DocKey2 NVARCHAR(50),@c_DocKey3 NVARCHAR(50),' +
                                 '@c_Exists NVARCHAR(1) OUTPUT'
       
         EXEC sp_executesql  @c_FullSQL
                           , @c_ExecArguments
                           , @c_DocKey
                           , @c_DocKey1
                           , @c_DocKey2
                           , @c_DocKey3
                           , @c_Exists OUTPUT
       
          IF @c_Exists = '0' -- No record found in target db
          BEGIN
             SELECT @c_ColName = COALESCE (@c_ColName + ', ', '') + QUOTENAME(LTRIM(RTRIM(Column_Name)), '[')
             FROM #TargetTbl WITH (NOLOCK)
             WHERE Column_Name <> ISNULL(RTRIM(@c_IdentityCol),'')
       
             IF LEFT(@c_ColName, 1) = ','
             BEGIN
                SELECT @c_ColName = RTRIM(LTRIM(SUBSTRING(@c_ColName, 2, LEN(@c_ColName))))
             END
       
             IF @b_Debug = 1
             BEGIN
                SELECT @c_ColName '@c_ColName'
             END
       
             SET @c_SQL = ''
             SET @c_FullSQL = ''
             SET @c_SQL = ('INSERT INTO ' + QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' +
                            QUOTENAME(@c_TableName, '[') +' ( '+ @c_ColName + ' ) ' + CHAR(13) +
                           'SELECT ' + @c_ColName + CHAR(13) +
                           'FROM ' +
                           QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +
                           ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey ')
                          -- 'WHERE QUOTENAME(@c_KeyColumn, ''['') =  @c_DocKey ')
             
           SET @c_FullSQL = @c_SQL + CHAR(13) + @c_condition + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3   
       
             IF @b_Debug = 1
             BEGIN
                 print 'insert'
                SELECT @c_FullSQL '@c_FullSQL'
                SELECT @c_KeyColumn '@c_KeyColumn', @c_DocKey '@c_DocKey',@c_KeyColumn1 '@c_KeyColumn1',@c_DocKey1 '@c_DocKey1',@c_KeyColumn2 '@c_KeyColumn2',
                       @c_DocKey2 '@c_DocKey2',@c_DocKey3 '@c_DocKey3'
             END
       
           -- BEGIN TRAN
            BEGIN TRY
            --EXEC sp_executesql @c_FullSQL 
              SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_DocKey1 NVARCHAR(50), ' +
                                      '@c_DocKey2 NVARCHAR(50),@c_DocKey3 NVARCHAR(50)'
       
              EXEC sp_executesql @c_FullSQL
                         , @c_ExecArguments
                         , @c_DocKey
                         , @c_DocKey1
                         , @c_DocKey2
                         , @c_DocKey3
            --COMMIT TRAN
            END TRY
            BEGIN CATCH    
                SET @c_ErrMsg = ERROR_MESSAGE()   
                SET @n_err= ERROR_NUMBER() 
                SET @n_continue = 3
                SET @b_Success = 0
                 
             --   ROLLBACK TRAN  
                GOTO QUIT    
            END CATCH    
             
                --IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'CARTONTRACK'
                --BEGIN
                --  SELECT TOP 10 * from CARTONTRACK (nolock)
                --  order by rowref desc
                --END

            --WHILE @@TRANCOUNT > 0   
          --   BEGIN  
          --      COMMIT TRAN  
          --   END  
                   
       
             SET @c_RecFound = '0'
             SET @c_SQL = ''
             SET @c_FullSQL = ''

             IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') NOT IN ('CARTONTRACK','PACKSERIALNO','UCC') -- ntrItrnAdd: TrafficCop 9
             BEGIN
             SET @c_SQL = N'SELECT @c_RecFound = ''1'' ' + CHAR(13) +
                           'FROM ' +
                           QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' +
                           'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey '
       
             --SET @c_ExecArguments = N'@c_KeyColumn NVARCHAR(50),@c_DocKey NVARCHAR(50),@c_RecFound NVARCHAR(1) OUTPUT'
             --EXEC sp_executesql @c_SQL
             --                 , @c_ExecArguments
             --                 , @c_RecFound OUTPUT
            END
            ELSE
            BEGIN
             SET @c_SQL = N'SELECT @c_RecFound = ''1'' ' + CHAR(13) +
                           'FROM ' +
                           QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' +
                           'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' <>  @c_DocKey '
            END
            SET @c_FullSQL = @c_SQL + CHAR(13) + @c_condition + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3   
            SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_DocKey1 NVARCHAR(50), ' +
                                     '@c_DocKey2 NVARCHAR(50),@c_DocKey3 NVARCHAR(50),' +
                                     '@c_RecFound NVARCHAR(1) OUTPUT'
       
         EXEC sp_executesql  @c_FullSQL
                           , @c_ExecArguments
                           , @c_DocKey
                           , @c_DocKey1
                           , @c_DocKey2
                           , @c_DocKey3
                           , @c_RecFound OUTPUT
       
       
             IF @b_Debug = 1
             BEGIN
                SELECT @c_FullSQL '@c_FullSQL',@c_RecFound '@c_RecFound'
             END
       
            BEGIN TRAN
             IF @c_RecFound = '1' -- Then delete source db data
             BEGIN
       
                SET @c_SQL = ''
                SET @c_FullSQL = ''
                SET @c_SQL = N'DELETE ' +
                               QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') +
                             ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' =  @c_DocKey '
       
                --EXEC sp_executesql @c_FullSQL 
                 --SET @c_ExecArguments = N'@c_KeyColumn NVARCHAR(50),@c_DocKey NVARCHAR(50)'
                --EXEC sp_executesql @c_SQL
                --                 , @c_ExecArguments
       
               SET @c_FullSQL = @c_SQL + CHAR(13) + @c_condition + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3 
       
                 IF @b_Debug = 1
                 BEGIN
                   print '55555'
                   SELECT @c_FullSQL '@c_FullSQL55555'
                END
                 
               --EXEC sp_executesql @c_FullSQL
               SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_DocKey1 NVARCHAR(50), ' +
                                      '@c_DocKey2 NVARCHAR(50),@c_DocKey3 NVARCHAR(50)' 
       
               EXEC sp_executesql  @c_FullSQL
                            , @c_ExecArguments
                            , @c_DocKey
                            , @c_DocKey1
                            , @c_DocKey2
                            , @c_DocKey3
       
             END
       
             IF @@ERROR = 0 
             BEGIN
                COMMIT TRAN
             END
             ELSE
             BEGIN
                ROLLBACK TRAN
                GOTO QUIT
             END
          END -- @c_Exists = '0'
       END
       QUIT:
       
        IF @n_continue=3  -- Error Occured - Process And Return
          BEGIN
             SET @b_success = 0
             IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
             BEGIN
                ROLLBACK TRAN
             END
             ELSE
             BEGIN
                WHILE @@TRANCOUNT > @n_StartTCnt
                BEGIN
                   COMMIT TRAN
                END
             END
             execute nsp_logerror @n_err, @c_errmsg, 'isp_ReTriggerTransmitLog_MoveDataBYLine'
             --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
             RETURN
          END
          ELSE
          BEGIN
             SET @b_success = 1
             WHILE @@TRANCOUNT > @n_StartTCnt
             BEGIN
                COMMIT TRAN
             END
             RETURN
          END
       

GO