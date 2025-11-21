SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_MoveData                                        */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: Richard Lim                                              */  
/*                                                                      */  
/* Purpose: - To move archived data back to live db.                    */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Modifications:                                                       */  
/* Date         Author    Ver.  Purposes                                */  
/* 13-Jan-2017  Leong     1.0   Remove Source DB record.                */  
/* 24-Jan-2018  Leong     1.1   Block PickDetail/Itrn move record.      */  
/* 20-Feb-2020  Leong     1.2   Make sure source db record ArchiveCop 9 */  
/*                              to bypass trigger checking.             */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_MoveData]  
     @c_SourceDB    NVARCHAR(30)  
   , @c_TargetDB    NVARCHAR(30)  
   , @c_TableSchema NVARCHAR(10)  
   , @c_TableName   NVARCHAR(50)  
   , @c_KeyColumn   NVARCHAR(50)  
   , @c_DocKey      NVARCHAR(50)  
   , @b_Debug       INT = 0  
AS  
   SET NOCOUNT ON  
   SET ANSI_NULLS ON  
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
  
  
IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'PickDetail'  
BEGIN  
   PRINT '----------------------------------------------------------'  
   PRINT 'ERROR! Not allow to move PickDetail record. (isp_MoveData)'  
   PRINT '----------------------------------------------------------'  
   GOTO QUIT  
END  
  
IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = '%liateDkciP%' -- Pass in from isp_MovePickDetail, Then allow to move PickDetail.  
BEGIN  
   SET @c_TableName = REVERSE(@c_TableName)  
   SET @c_TableName = REPLACE(@c_TableName,'%','')  
   SET @c_TableName = ISNULL(RTRIM(LTRIM(@c_TableName)),'')  
END  
  
IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'UCC' AND ISNULL(RTRIM(LTRIM(@c_KeyColumn)),'') = 'UCC_RowRef'  
BEGIN  
   PRINT '------------------------------------------------------------------'  
   PRINT 'ERROR! Not allow to move UCC by column UCC_RowRef. (isp_MoveData)'  
   PRINT '------------------------------------------------------------------'  
   GOTO QUIT  
END  
  
IF ISNULL(RTRIM(LTRIM(@c_SourceDB)),'') = ISNULL(RTRIM(LTRIM(@c_TargetDB)),'')  
BEGIN  
   PRINT '----------------------------------------------------'  
   PRINT 'ERROR! Same database is not allowed. (isp_MoveData)'  
   PRINT '----------------------------------------------------'  
   GOTO QUIT  
END  
  
SET @c_ColName = ''  
SET @c_DBTableName = @c_TargetDB + '.'+ @c_TableSchema + '.' + @c_TableName  
  
IF COL_LENGTH(@c_DBTableName, @c_KeyColumn) IS NULL  
BEGIN  
   PRINT '--------------------------------------------------'  
   PRINT 'ERROR! Table/Column does not exist. (isp_MoveData)'  
   PRINT 'Table: ' + ISNULL(RTRIM(@c_DBTableName),'')  
   PRINT 'Col  : ' + ISNULL(RTRIM(@c_KeyColumn),'')  
   PRINT '--------------------------------------------------'  
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
  
CREATE TABLE #SourceTbl (  
     Table_Catalog NVARCHAR(50)  NULL  
   , Table_Name    NVARCHAR(100) NULL  
   , Column_Name   NVARCHAR(100) NULL  
)  
  
/***********************************************  
Retrieve TargetDB Identity Column (Start)  
***********************************************/  
SET @n_SchemaId = SCHEMA_ID(@c_TableSchema)  
  
IF ISNULL(@n_SchemaId,'') <> ''  
BEGIN  
   SET @c_SQL = ''  
   SET @c_SQL = ('SELECT @n_ObjId = [Object_Id] FROM ' +  
                 QUOTENAME(@c_TargetDB, '[') + '.' + 'sys.all_objects ' +  
                 'WHERE Type = ''U'' ' +  
                 'AND Name = ''' + @c_TableName + ''' ' +  
                 'AND [Schema_Id] = @n_SchemaId ')  
  
   EXEC sp_executesql @c_SQL  
                    , N'@n_SchemaId INT, @n_ObjId INT OUTPUT'  
                    , @n_SchemaId, @n_ObjId OUTPUT  
  
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
/***********************************************  
Retrieve TargetDB Identity Column (End)  
***********************************************/  
  
SET @c_SQL = ''  
SET @c_SQL = ('SELECT Table_Catalog, Table_Name, Column_Name FROM ' +  
              QUOTENAME(@c_TargetDB, '[') + '.' + 'Information_Schema.Columns ' +  
              'WHERE Data_Type <> ''TimeStamp'' ' +  
              'AND Table_Schema = '''+ @c_TableSchema + ''' ' +  
              'AND Table_Name = '''+ @c_TableName + '''')  
  
INSERT INTO #TargetTbl (Table_Catalog, Table_Name, Column_Name)  
EXEC sp_executesql @c_SQL  
  
SET @c_SQL = ''  
SET @c_SQL = ('SELECT Table_Catalog, Table_Name, Column_Name FROM ' +  
              QUOTENAME(@c_SourceDB, '[') + '.' + 'Information_Schema.Columns ' +  
              'WHERE Data_Type <> ''TimeStamp'' ' +  
              'AND Table_Schema = '''+ @c_TableSchema + ''' ' +  
              'AND Table_Name = '''+ @c_TableName + '''')  
  
INSERT INTO #SourceTbl (Table_Catalog, Table_Name, Column_Name)  
EXEC sp_executesql @c_SQL  
  
  
IF EXISTS (SELECT 1 FROM #TargetTbl T  
           LEFT JOIN #SourceTbl S  
           ON (T.Table_Name = S.Table_Name AND T.Column_Name = S.Column_Name)  
           WHERE ISNULL(RTRIM(S.Column_Name),'') = '')  
BEGIN  
   PRINT '-------------------------------------------------------------'  
   PRINT 'ERROR! Target / Source Table Column Unmatched. (isp_MoveData)'  
   PRINT '-------------------------------------------------------------'  
  
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
                    'WHERE TrafficCop = ''9'' AND ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + ''''  
  
      SET @c_ExecArguments = N'@c_Exists NVARCHAR(1) OUTPUT'  
      EXEC sp_executesql @c_SQL  
                       , @c_ExecArguments  
                       , @c_Exists OUTPUT  
  
      IF @c_Exists = '0'  
      BEGIN  
         PRINT '----------------------------------------------------'  
         PRINT 'ERROR! Not allow to move ITRN record. (isp_MoveData)'  
         PRINT '----------------------------------------------------'  
         GOTO QUIT  
      END  
   END  
  
   /****************************************************  
   Make sure Source DB record is ArchiveCop = 9 (Start)  
   ****************************************************/  
   IF EXISTS (SELECT 1 FROM #SourceTbl WHERE Column_Name = 'ArchiveCop')  
   BEGIN  
      SET @c_Exists = '0'  
      SET @c_SQL = ''  
      SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +  
                    'FROM ' +  
                    QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +  
                    'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + '''' +  
                    ' AND ArchiveCop = ''9'' '  
  
      SET @c_ExecArguments = N'@c_Exists NVARCHAR(1) OUTPUT'  
  
      EXEC sp_executesql @c_SQL  
                       , @c_ExecArguments  
                       , @c_Exists OUTPUT  
  
      IF @c_Exists = '0' -- No record found in source db  
      BEGIN  
         PRINT '-----------------------------------------------------------------'  
         PRINT 'ERROR! Invalid archived record found in source db. (isp_MoveData)'  
         PRINT 'Database      : ' + ISNULL(RTRIM(@c_SourceDB),'')  
         PRINT 'Table/Col/Key : ' + ISNULL(RTRIM(@c_TableName),'') + ' / ' + ISNULL(RTRIM(@c_KeyColumn),'') + ' / ' + ISNULL(RTRIM(@c_DocKey),'')  
         PRINT '-----------------------------------------------------------------'  
         GOTO QUIT  
      END  
   END  
   /****************************************************  
   Make sure Source DB record is ArchiveCop = 9 (Start)  
   ****************************************************/  
  
   SET @c_Exists = '0'  
   SET @c_SQL = ''  
   SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +  
                 'FROM ' +  
                 QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +  
                 'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + ''''  
  
   SET @c_ExecArguments = N'@c_Exists NVARCHAR(1) OUTPUT'  
  
   EXEC sp_executesql @c_SQL  
                    , @c_ExecArguments  
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
      SET @c_SQL = ('INSERT INTO ' + QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' +  
                     QUOTENAME(@c_TableName, '[') +' ( '+ @c_ColName + ' ) ' + CHAR(13) +  
                    'SELECT ' + @c_ColName + CHAR(13) +  
                    'FROM ' +  
                    QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +  
                    'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + '''')  
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT @c_SQL '@c_SQL'  
      END  
  
      BEGIN TRAN  
      EXEC sp_executesql @c_SQL  
  
      ---------------------------------------------------------------------  
      SET @c_RecFound = '0'  
      SET @c_SQL = ''  
      SET @c_SQL = N'SELECT @c_RecFound = ''1'' ' + CHAR(13) +  
                    'FROM ' +  
                    QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') + ' WITH (NOLOCK) ' +  
                    'WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + ''''  
  
      SET @c_ExecArguments = N'@c_RecFound NVARCHAR(1) OUTPUT'  
      EXEC sp_executesql @c_SQL  
                       , @c_ExecArguments  
                       , @c_RecFound OUTPUT  
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT @c_RecFound '@c_RecFound', @c_KeyColumn '@c_KeyColumn', @c_DocKey '@c_DocKey'  
              , @c_TargetDB '@c_TargetDB', @c_TableName '@c_TableName'  
      END  
  
      IF @c_RecFound = '1' -- Then delete source db data  
      BEGIN  
         IF EXISTS (SELECT 1 FROM #TargetTbl WHERE Column_Name = 'ArchiveCop' AND Table_Catalog NOT LIKE '%ARCHIVE%')  
         BEGIN  
            SET @c_SQL = ''  
            SET @c_SQL = N'UPDATE ' +  
                           QUOTENAME(@c_TargetDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') +  
                          ' SET ArchiveCop = NULL' +  
                          ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + '''' +  
                          ' AND ArchiveCop = ''9'' '  
            EXEC sp_executesql @c_SQL  
         END  
  
         IF EXISTS (SELECT 1 FROM #SourceTbl WHERE Column_Name = 'ArchiveCop')  
         BEGIN  
            SET @c_SQL = ''  
            SET @c_SQL = N'DELETE ' +  
                           QUOTENAME(@c_SourceDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TableName, '[') +  
                          ' WHERE ' + QUOTENAME(@c_KeyColumn, '[') + ' = ' + '''' + @c_DocKey + '''' +  
                          ' AND ArchiveCop = ''9'' '  
            EXEC sp_executesql @c_SQL  
         END  
         ELSE  
         BEGIN  
            PRINT '-----------------------------------------------------------------'  
            PRINT 'WARNING! Source record remain unchanged.'  
            PRINT 'Please verify in both databases: (isp_MoveData)'  
            PRINT 'Databases     : ' + ISNULL(RTRIM(@c_SourceDB),'') + ' / ' + ISNULL(RTRIM(@c_TargetDB),'')  
            PRINT 'Table/Col/Key : ' + ISNULL(RTRIM(@c_TableName),'') + ' / ' + ISNULL(RTRIM(@c_KeyColumn),'') + ' / ' + ISNULL(RTRIM(@c_DocKey),'')  
            PRINT '-----------------------------------------------------------------'  
         END  
      END  
      ---------------------------------------------------------------------  
  
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
   ELSE  
   BEGIN  
      PRINT '----------------------------------------------------------------------------------'  
      PRINT 'ERROR! Record exist in Target DB: ' + ISNULL(RTRIM(@c_TargetDB),'') + ' | ' + ISNULL(RTRIM(@c_KeyColumn),'') + ': ' + ISNULL(RTRIM(@c_DocKey),'') + ' (isp_MoveData)'  
      PRINT '----------------------------------------------------------------------------------'  
      GOTO QUIT  
   END  
END  
QUIT:  

GO