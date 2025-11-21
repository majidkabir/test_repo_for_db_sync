SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*************************************************************************/    
/* Stored Procedure: [isp_ExcelLoader_UpdateInsert]                      */    
/* Creation Date: 24 Oct 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Delete the Table records and re insert all the data          */    
/*                                                                       */    
/* Called By:  Excel Loader                                              */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 24-Oct-2019  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
CREATE PROC [dbo].[isp_ExcelLoader_UpdateInsert] (    
   @c_STGTableName   NVARCHAR(255)  = ''  
,  @c_POSTTableName  NVARCHAR(255)  = ''  
,  @c_PrimaryKey     NVARCHAR(2000) = ''  
,  @n_BatchNo        INT            = 0  
,  @n_Offset         INT            = 0
,  @n_Limit          INT            = 0
,  @b_Debug          INT            = 0    
,  @b_Success        INT            = 0    OUTPUT    
,  @n_ErrNo          INT            = 0    OUTPUT    
,  @c_ErrMsg         NVARCHAR(250)  = ''   OUTPUT    
) AS   
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF     
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL ON    
   SET ANSI_WARNINGS ON    
   SET ANSI_PADDING ON  
  
   /*********************************************/    
   /* Variables Declaration (Start)             */    
   /*********************************************/    
    
   DECLARE @n_Continue           INT            = 1
         , @n_StartCnt           INT            = @@TRANCOUNT
         , @c_Exec               NVARCHAR(MAX)  = ''
         , @c_Exec1              NVARCHAR(MAX)  = ''
         , @c_Exec2              NVARCHAR(MAX)  = ''
         , @c_Exec3              NVARCHAR(MAX)  = ''
         , @SQL                  NVARCHAR(MAX)  = ''
         , @SQL_Col              NVARCHAR(MAX)  = ''
         , @c_FParams            NVARCHAR(1000) = ''
         , @c_PKValues           NVARCHAR(250)  = ''
         , @n_FirstTime          BIT            = 0
         , @n_PKCount            INT            = 0
         , @c_WhereParams        NVARCHAR(2000) = '' 
         , @c_DeclareParams      NVARCHAR(2000) = '' 
         , @c_SubSQL             NVARCHAR(MAX)  = ''
         --, @c_SubWhereParams     NVARCHAR(2000) = '' 
         , @c_ExecParams         NVARCHAR(2000) = '' 
         , @c_ExecPK             NVARCHAR(1000) = '' 
         , @c_ExecArgument       NVARCHAR(MAX)  = ''
         , @n_RecordID           BIGINT         = 0
         --, @No                   INT            = 0
         --, @c_STGStatus          NVARCHAR(1)    = ''
         , @c_ExecInSQLWhere     NVARCHAR(1000) = ''  
         , @c_ChkNull            NVARCHAR(1000) = '' 
         , @n_ChkIdentity        INT            = 0
         , @c_TempName           NVARCHAR(255)  = ''
         , @c_TempPriKey         NVARCHAR(2000) = @c_PrimaryKey
   
   SET @b_Success = 1    
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
  
   IF @n_BatchNo <= 0   
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730001    
      SET @c_ErrMsg = 'Invalid Batch No. (isp_ExcelLoader_UpdateInsert)'    
      GOTO QUIT  
   END  
   
   IF ISNULL(RTRIM(@c_STGTableName), '') = '' OR ISNULL(RTRIM(@c_POSTTableName), '') = ''  
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730002  
      SET @c_ErrMsg = 'Staging or Post TableName Cannot be Null or Empty.(isp_ExcelLoader_UpdateInsert)'    
      GOTO QUIT  
   END  
   
   IF @n_Offset < 0 OR @n_Limit < 0  
   BEGIN  
      SET @SQL = 'SELECT @n_Count=COUNT(1) FROM ' + @c_STGTableName + ' WITH (NOLOCK) WHERE STG_BatchNo = @n_BatchNo'  
      EXEC sp_executesql @SQL, N'@n_BatchNo INT, @n_Count INT OUTPUT', @n_BatchNo, @n_Count = @n_Limit OUTPUT  
   
      SET @n_Offset =0  
   END  

   BEGIN TRANSACTION  

   BEGIN TRY  
      IF CHARINDEX(',', @c_PrimaryKey) <> 0  
      BEGIN  
         DECLARE CUR_PRMYKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(@c_PrimaryKey, ',')  
         OPEN CUR_PRMYKEY  
         FETCH FROM CUR_PRMYKEY INTO @c_PKValues  
   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @n_PKCount += 1  
   
            IF ISNULL(RTRIM(@c_FParams), '') = '' AND ISNULL(RTRIM(@c_WhereParams), '') = ''  
            BEGIN  
               SET @c_DeclareParams = N' @PK' +CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255) = '''''  
               --SET @c_FParams = N'@n_RecordID,@No, @c_STGStatus, @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_FParams = N'@n_RecordID, @c_STGStatus, @PK' + CAST(@n_PKCount AS NVARCHAR(2)) 
               SET @c_WhereParams = @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               --SET @c_SubWhereParams = N'ST.' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ExecParams = N'@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255)'  
               SET @c_ExecPK = N'@PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ExecInSQLWhere = N' @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ChkNull = N' ISNULL(RTRIM(@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + N'), '''') <> '''''  
            END  
            ELSE  
            BEGIN  
               SET @c_DeclareParams += CHAR(13) + CHAR(10) + N' , @PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255) = '''''   
               SET @c_FParams += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_WhereParams += N' AND ' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               --SET @c_SubWhereParams += N' AND ST.' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ExecParams += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255)'  
               SET @c_ExecPK += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ExecInSQLWhere += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
               SET @c_ChkNull += N' AND ISNULL(RTRIM(@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + N'), '''') <> '''''  
            END  
            FETCH FROM CUR_PRMYKEY INTO @c_PKValues  
         END  
         CLOSE CUR_PRMYKEY  
         DEALLOCATE CUR_PRMYKEY
      END  
      ELSE  
      BEGIN  
         SET @c_DeclareParams = N' @PK1' + CHAR(9) + N' NVARCHAR(255) = '''''  
         --SET @c_FParams = N'@n_RecordID,@No, @c_STGStatus, @PK1' 
         SET @c_FParams = N'@n_RecordID, @c_STGStatus, @PK1'
         SET @c_WhereParams = N' ' + @c_PrimaryKey + N' = @PK1'  
         --SET @c_SubWhereParams = N'ST.' + @c_PrimaryKey + N' = @PK1'  
         SET @c_ExecParams = N'@PK1' + CHAR(9) + N' NVARCHAR(255)'  
         SET @c_ExecPK = N'@PK1'  
         SET @c_ExecInSQLWhere = N' @PK1'  
         SET @c_ChkNull = N' ISNULL(RTRIM(@PK1), '''') <> '''''  
      END  
   
      --SET @SQL = N' SELECT @n_ChkIdentity=COUNT(1) FROM sys.columns c WITH (NOLOCK) ' +  
      --           N' INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id ' +  
      --           N' WHERE c.object_id = OBJECT_ID(@c_POSTTableName)' 
      
      -- SET @SQL = N' SELECT @n_ChkIdentity=MAX(column_id) FROM sys.columns c WITH (NOLOCK) ' +  
      --           N' INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id ' +  
      --           N' WHERE c.object_id = OBJECT_ID(@c_POSTTableName)'  
                    
      --EXEC sp_executesql @SQL, N'@c_POSTTableName NVARCHAR(255), @n_ChkIdentity INT OUTPUT'  
      --,@c_POSTTableName, @n_ChkIdentity = @n_ChkIdentity OUTPUT   

      SELECT @n_ChkIdentity=MAX(column_id) 
      FROM sys.columns c WITH (NOLOCK) 
      INNER JOIN sys.types t WITH (NOLOCK) 
      ON c.user_type_id = t.user_type_id 
      WHERE c.object_id = OBJECT_ID(@c_POSTTableName)

      SET @SQL_Col= (  
            SELECT CHAR(13)+CHAR(10)+CHAR(9)+'['+c.name+']'            
            + CASE WHEN c.column_id=@n_ChkIdentity  THEN '' ELSE ',' END  
            FROM sys.columns c WITH (NOLOCK)  
            INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id   
            WHERE c.object_id = OBJECT_ID(@c_POSTTableName) AND is_identity = 0  
            ORDER BY c.column_id  
            FOR XML PATH(''), TYPE  
      ).value('.','nvarchar(max)')  
   
      
        --DECLARE CUR_CAST_DATETIME CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      --SELECT c.[name] FROM sys.columns c WITH (NOLOCK)
      --INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id
      --WHERE c.object_id = OBJECT_ID(@c_POSTTableName)
      --AND c.[name] in (SELECT value FROM string_split(@c_PrimaryKey, ','))
      --AND t.[name] = 'datetime'

      --OPEN CUR_CAST_DATETIME  
      --FETCH FROM CUR_CAST_DATETIME INTO @c_TempName  

      --WHILE @@FETCH_STATUS <> -1  
      --BEGIN  
      --   IF ISNULL(RTRIM(@c_TempName), '') <> ''
      --   BEGIN
      --      SELECT @c_TempPriKey=STUFF((SELECT DISTINCT ',' + CASE WHEN ISNULL(RTRIM(value),'') = @c_TempName THEN 'CONVERT(NVARCHAR(255),'+ @c_TempName +',121)'
      --      ELSE value END
      --      FROM string_split(@c_TempPriKey, ',')
      --      FOR XML PATH('')),1,1,'')

      --      --PRINT @c_TempPriKey
      --   END
      --   FETCH FROM CUR_CAST_DATETIME INTO @c_TempName  
      --END
      --CLOSE CUR_CAST_DATETIME  
      --DEALLOCATE CUR_CAST_DATETIME

      SELECT @c_TempPriKey=STUFF((SELECT ',' +CASE WHEN ISNULL(RTRIM(t.[name]),'') = 'datetime'
      THEN 'CONVERT(NVARCHAR(255),'+ c.[name] +',121) AS [' + c.[name] + ']'
      ELSE c.[name]
      END
      FROM sys.columns c WITH (NOLOCK)
      INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id
      WHERE c.object_id = OBJECT_ID(@c_POSTTableName)
      AND c.[name] in (SELECT TRIM(value) FROM string_split(@c_PrimaryKey, ','))
      FOR XML PATH('')),1,1,'')



      SET @c_Exec1 = N' DECLARE ' + @c_DeclareParams + CHAR(13) + CHAR(10) +  
                 N' DECLARE @Count INT = 0' + CHAR(13) + CHAR(10) +  
                 N' DECLARE @InSubSQL NVARCHAR(MAX) = ''''' + CHAR(13) + CHAR(10) +  
                 N' DECLARE @c_SubSQL NVARCHAR(MAX) = ''''' + CHAR(13) + CHAR(10) +  
                 N' DECLARE @c_STGStatus NVARCHAR(3) = ''''' + CHAR(13) + CHAR(10) +  
                 N' DECLARE CUR_DYNAMIC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR' + CHAR(13) + CHAR(10) +  
                 --N' SELECT RecordID,[No],[STG_Status],' + @c_TempPriKey + CHAR(13) + CHAR(10) +   
                 N' SELECT RecordID,[STG_Status],' + @c_TempPriKey + CHAR(13) + CHAR(10) +   
                 N' FROM ' + @c_STGTableName + ' WITH (NOLOCK)' + CHAR(13) + CHAR(10) +   
                 N' WHERE STG_BatchNo = @n_BatchNo' + CHAR(13) + CHAR(10) +  --STG_Status IN (''0'',''1'') AND
                 N' ORDER BY [No] ASC' + CHAR(13) + CHAR(10) +  
                 N' OFFSET @n_Offset ROWS FETCH NEXT @n_Limit ROWS ONLY' +  CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +  
                 N' OPEN CUR_DYNAMIC ' +  CHAR(13) + CHAR(10) +  CHAR(13) + CHAR(10) +  
                 N' FETCH FROM CUR_DYNAMIC INTO ' + @c_FParams  + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +  
                 N' WHILE @@FETCH_STATUS <> -1 ' +  CHAR(13) + CHAR(10) +
                 N' BEGIN ' +  CHAR(13) + CHAR(10) + CHAR(9) +
                 N' IF ISNULL(RTRIM(@c_STGStatus),'''') IN (''0'', ''1'') ' +
                 N' BEGIN ' +
                 --N' IF ' + @c_ChkNull +  CHAR(13) + CHAR(10) + CHAR(9) +  
                 --N' BEGIN ' +  CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 N' SET @InSubSQL = N''SELECT @C=COUNT(1) FROM ' + @c_POSTTableName 
      SET @c_Exec2 = N' WITH (NOLOCK) WHERE '' +  @c_WhereParams + '''' ' +  CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 --N' PRINT @InSubSQL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 N' EXEC sp_ExecuteSQL @InSubSQL, N''' + @c_ExecParams + ', @C INT OUTPUT'', ' + @c_ExecInSQLWhere +   
                 N', @C=@Count OUTPUT' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 N' IF @Count > 0' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +CHAR(9) +  
                 N' BEGIN' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' PRINT @Count' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 --N'   SELECT @PK1,@PK2,@PK3,@PK4  '+
                 N' SET @c_SubSQL = ''''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +       
                 N' EXEC isp_ExcelLoader_Build_SQL_Update' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' @TargetTable = ''' + @c_POSTTableName + ''',' + CHAR(13) + CHAR(10)  + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' @SourceTable = ''' + @c_STGTableName  + ''',' + CHAR(13) + CHAR(10)  + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' @PrimaryKey  = ''' + @c_PrimaryKey    + ''',' + CHAR(13) + CHAR(10)  + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
                 N' @SQL = @c_SubSQL OUTPUT  ' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)  + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' SET @c_SubSQL += '' WHERE ST.RecordID=@n_SubRecordID''' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +
                 N' EXEC sp_ExecuteSQL @c_SubSQL, N''@n_SubRecordID BIGINT'', @n_RecordID ' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' SET @c_SubSQL += '' WHERE ST.STG_BatchNo = @n_BatNo AND [No] =@nNo AND ST.STG_Status IN (''''0'''',''''1'''')  AND ' + @c_SubWhereParams + '''' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
                 --N' PRINT @c_SubSQL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' EXEC sp_ExecuteSQL @c_SubSQL, N''@n_BatNo INT, @nNo INT,' + @c_ExecParams + ''', @n_BatchNo, @No, ' + @c_ExecPK  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +
                 --N'  SELECT @@ROWCOUNT  '+
                 N' SET @c_SubSQL = '''' ' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
                 N' UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK) ' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' SET STG_Status = ''9''' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' WHERE STG_Status IN (''0'',''1'') AND [No]=@No AND STG_BatchNo = @n_BatchNo AND ' + @c_WhereParams  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
                 N' WHERE RecordID=@n_RecordID ' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
                 N' END' + CHAR(13) + CHAR(10) + CHAR(9) +CHAR(9) +   
                 N' ELSE' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)  
      SET @c_Exec3 = N' BEGIN' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' INSERT INTO ' + @c_POSTTableName + '('+ @SQL_Col + ')' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' SELECT ' + @SQL_Col + ' FROM ' + @c_STGTableName + ' WITH (NOLOCK)'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' WHERE RecordID=@n_RecordID ' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' WHERE STG_Status IN (''0'',''1'') AND [No]=@No AND STG_BatchNo = @n_BatchNo AND ' + @c_WhereParams  + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK) ' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' SET STG_Status = ''9''' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' WHERE RecordID=@n_RecordID ' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --N' WHERE STG_Status IN (''0'',''1'') AND [No]=@No AND STG_BatchNo = @n_BatchNo AND ' + @c_WhereParams  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 N' END' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 N' END' + CHAR(13) + CHAR(10) + CHAR(9) +  
                 --N' END' + CHAR(13) + CHAR(10) + CHAR(9) +  
                 N' FETCH FROM CUR_DYNAMIC INTO ' + @c_FParams  + CHAR(13) + CHAR(10)+  
                 N' END' +  CHAR(13) + CHAR(10) +  
                 N' CLOSE CUR_DYNAMIC' + CHAR(13) + CHAR(10) +  
                 N' DEALLOCATE CUR_DYNAMIC'  
                     
      SET @c_ExecArgument = N' @n_BatchNo INT' +   
                            N',@n_Offset INT' +  
                            N',@n_Limit INT' +
                            N',@n_RecordID BIGINT' +  
                            --N',@No INT' +  
                            --N',@c_STGStatus NVARCHAR(1)'+  
                            N',@c_WhereParams NVARCHAR(2000)'  
                
      SET @c_Exec = CONCAT(@c_Exec1,@c_Exec2,@c_Exec3)
      IF @b_Debug = 1
      BEGIN
         PRINT @c_Exec1  
         PRINT @c_Exec2  
         PRINT @c_Exec3  
      END

      EXEC sp_executesql @c_Exec, @c_ExecArgument, @n_BatchNo, @n_Offset, @n_Limit, @n_RecordID, @c_WhereParams  --, @No, @c_STGStatus
                     
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = ERROR_NUMBER()  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_ExcelLoader_UpdateInsert)'
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_ExcelLoader_UpdateInsert]: Main TryCatch Error... @c_ErrMsg=' + @c_ErrMsg    
      END 
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
      IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
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
END

GO