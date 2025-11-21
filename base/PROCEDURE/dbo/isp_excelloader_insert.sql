SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*************************************************************************/      
/* Stored Procedure: [isp_ExcelLoader_Insert]                            */      
/* Creation Date: 24 Oct 2019                                            */      
/* Copyright: LFL                                                        */      
/* Written by: GHChan                                                    */      
/*                                                                       */      
/* Purpose: Just insert records into Tables                              */      
/*                                                                       */      
/* Called By:  Excel Loader                                              */      
/*                                                                       */      
/* PVCS Version: 1.0                                                     */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date         Author   Ver  Purposes                                   */      
/* 24-Oct-2019  GHChan   1.0  Initial Development                        */      
/*************************************************************************/      
CREATE PROC [dbo].[isp_ExcelLoader_Insert] (      
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
         , @SQL                  NVARCHAR(MAX)  = ''
         , @SQL1                 VARCHAR(MAX)  = ''
         , @SQL2                 VARCHAR(MAX)  = ''
         , @SQL3                 VARCHAR(MAX)  = ''
         , @SQL_Col              NVARCHAR(MAX)  = ''
         , @c_FParams            NVARCHAR(MAX) = ''
         --, @c_PKValues           NVARCHAR(250)  = ''
         --, @n_FirstTime          BIT            = 0
         --, @n_PKCount            INT            = 0
         --, @c_WhereParams        NVARCHAR(2000) = '' 
         , @c_DeclareParams      NVARCHAR(MAX) = '' 
         --, @c_SubSQL             NVARCHAR(MAX)  = ''
         --, @c_SubWhereParams     NVARCHAR(2000) = '' 
         --, @c_ExecParams         NVARCHAR(2000) = '' 
         --, @c_ExecPK             NVARCHAR(1000) = '' 
         , @c_ExecArgument       NVARCHAR(MAX)  = ''
         --, @No                   INT            = 0
         --, @c_STGStatus          NVARCHAR(1)    = ''
         --, @c_ExecInSQLWhere     NVARCHAR(1000) = ''  
         --, @c_ChkNull            NVARCHAR(1000) = '' 
         , @n_ChkIdentity        INT            = 0
   
   SET @b_Success = 1 
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
  
   IF @n_BatchNo <= 0   
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730001    
      SET @c_ErrMsg = 'Invalid Batch No. (isp_ExcelLoader_Insert)'    
      GOTO QUIT  
   END  
   
   IF ISNULL(RTRIM(@c_STGTableName), '') = '' OR ISNULL(RTRIM(@c_POSTTableName), '') = ''  
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730002  
      SET @c_ErrMsg = 'Staging or Post TableName Cannot be Null or Empty.(isp_ExcelLoader_Insert)'    
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
      --IF CHARINDEX(',', @c_PrimaryKey) <> 0  
      --BEGIN  
      --   DECLARE CUR_PRMYKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      --   SELECT LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(@c_PrimaryKey, ',')  
      --   OPEN CUR_PRMYKEY  
      --   FETCH FROM CUR_PRMYKEY INTO @c_PKValues  
   
      --   WHILE @@FETCH_STATUS <> -1  
      --   BEGIN  
      --      SET @n_PKCount += 1  
   
      --      IF ISNULL(RTRIM(@c_FParams), '') = '' AND ISNULL(RTRIM(@c_WhereParams), '') = ''  
      --      BEGIN  
      --         SET @c_DeclareParams = N' @PK' +CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255) = '''''  
      --         SET @c_FParams = N'@No, @c_STGStatus, @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_WhereParams = @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_SubWhereParams = N'ST.' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ExecParams = N'@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255)'  
      --         SET @c_ExecPK = N'@PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ExecInSQLWhere = N' @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ChkNull = N' ISNULL(RTRIM(@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + N'), '''') <> '''''  
      --      END  
      --      ELSE  
      --      BEGIN  
      --         SET @c_DeclareParams += CHAR(13) + CHAR(10) + N' , @PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255) = '''''   
      --         SET @c_FParams += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_WhereParams += N' AND ' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_SubWhereParams += N' AND ST.' + @c_PKValues + N' = @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ExecParams += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2)) + CHAR(9) + N' NVARCHAR(255)'  
      --         SET @c_ExecPK += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ExecInSQLWhere += N', @PK' + CAST(@n_PKCount AS NVARCHAR(2))  
      --         SET @c_ChkNull += N' AND ISNULL(RTRIM(@PK' + CAST(@n_PKCount AS NVARCHAR(2)) + N'), '''') <> '''''  
      --      END  
      --      FETCH FROM CUR_PRMYKEY INTO @c_PKValues  
      --   END  
      --   CLOSE CUR_PRMYKEY  
      --   DEALLOCATE CUR_PRMYKEY  
      --END  
      --ELSE  
      --BEGIN  
      --   SET @c_DeclareParams = N' @PK1' + CHAR(9) + N' NVARCHAR(255) = '''''  
      --   SET @c_FParams = N'@No, @c_STGStatus, @PK1'  
      --   SET @c_WhereParams = N' ' + @c_PrimaryKey + N' = @PK1'  
      --   SET @c_SubWhereParams = N'ST.' + @c_PrimaryKey + N' = @PK1'  
      --   SET @c_ExecParams = N'@PK1' + CHAR(9) + N' NVARCHAR(255)'  
      --   SET @c_ExecPK = N'@PK1'  
      --   SET @c_ExecInSQLWhere = N' @PK1'  
      --   SET @c_ChkNull = N' ISNULL(RTRIM(@PK1), '''') <> '''''  
      --END  
   
      --SET @SQL = N' SELECT @n_ChkIdentity=MAX(c.column_id) FROM sys.columns c WITH (NOLOCK) ' +  
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
   

      SET @c_DeclareParams =  (  
            SELECT CHAR(13)+CHAR(10)+CHAR(9)+ '@'+CAST(c.[column_id] AS NVARCHAR(5)) + 
            CASE 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'char'     THEN ' CHAR('+CAST(c.max_length AS NVARCHAR(5) )+')='''''
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nchar'    THEN ' NCHAR('+CAST(c.max_length AS NVARCHAR(5) )+')=''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varchar'  THEN ' VARCHAR('+CAST(c.max_length AS NVARCHAR(5) )+')=''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nvarchar' THEN ' NVARCHAR('+CAST(c.max_length/2 AS NVARCHAR(5) )+')=''''' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'text'     THEN ' TEXT = ''''' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'ntext'    THEN ' NTEXT = ''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'binary'   THEN ' BINARY('+CAST(c.max_length AS NVARCHAR(5) )+')=''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varbinary'THEN ' VARBINARY('+CAST(c.max_length AS NVARCHAR(5) )+')=''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'decimal'THEN ' DECIMAL('+CAST(c.precision AS NVARCHAR(5) )+',' + CAST(c.scale AS NVARCHAR(5) ) + ')=0' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'numeric'THEN ' NUMERIC('+CAST(c.precision AS NVARCHAR(5) )+',' + CAST(c.scale AS NVARCHAR(5) ) + ')=0' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'image'    THEN ' IMAGE = ''''' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'datetime' THEN ' DATETIME' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'date'     THEN ' DATE' 
               ELSE ' ' + UPPER(t.[name])
               END
            + CASE WHEN c.column_id=@n_ChkIdentity  THEN '' ELSE ',' END  
            FROM sys.columns c WITH (NOLOCK)  
            INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id   
            WHERE c.object_id = OBJECT_ID(@c_POSTTableName) AND is_identity = 0  
            ORDER BY c.column_id  
            FOR XML PATH(''), TYPE  
      ).value('.','nvarchar(max)') 

       SET @c_FParams =  (  
            SELECT CHAR(13)+CHAR(10)+CHAR(9)+ '@'+CAST(c.[column_id] AS NVARCHAR(5))
            + CASE WHEN c.column_id=@n_ChkIdentity  THEN '' ELSE ',' END  
            FROM sys.columns c WITH (NOLOCK)  
            INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id   
            WHERE c.object_id = OBJECT_ID(@c_POSTTableName) AND is_identity = 0  
            ORDER BY c.column_id  
            FOR XML PATH(''), TYPE  
      ).value('.','nvarchar(max)')  

      SET @SQL = N''  
      SET @SQL1 = ' DECLARE ' + @c_DeclareParams + CHAR(13) + CHAR(10) +  
                 ' DECLARE @n_RecordID BIGINT = 0' + CHAR(13) + CHAR(10) +  
                 ' DECLARE @c_STGStatus NVARCHAR(3) = ''''' + CHAR(13) + CHAR(10) +  
                 --' DECLARE @Count INT = 0' + CHAR(13) + CHAR(10) +  
                 --' DECLARE @InSubSQL NVARCHAR(MAX) = ''''' + CHAR(13) + CHAR(10) +  
                 --' DECLARE @c_SubSQL NVARCHAR(MAX) = ''''' + CHAR(13) + CHAR(10) +  
                 ' DECLARE CUR_DYNAMIC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR' + CHAR(13) + CHAR(10)
      SET @SQL2 = ' SELECT RecordID, STG_Status, ' + @SQL_Col + CHAR(13) + CHAR(10) +   
                 ' FROM ' + @c_STGTableName + ' WITH (NOLOCK)' + CHAR(13) + CHAR(10) +   
                 ' WHERE STG_BatchNo = @n_BatchNo' + CHAR(13) + CHAR(10) +   --STG_Status IN (''0'',''1'') AND
                 ' ORDER BY [No] ASC' + CHAR(13) + CHAR(10) +  
                 ' OFFSET @n_Offset ROWS FETCH NEXT @n_Limit ROWS ONLY' +  CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +  
                 ' OPEN CUR_DYNAMIC ' +  CHAR(13) + CHAR(10) +  CHAR(13) + CHAR(10) +  
                 ' FETCH FROM CUR_DYNAMIC INTO @n_RecordID, @c_STGStatus, ' + @c_FParams  + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +  
                 ' WHILE @@FETCH_STATUS <> -1 ' +  CHAR(13) + CHAR(10) +  
                 ' BEGIN ' +  CHAR(13) + CHAR(10) + CHAR(9) +  
                 ' IF ISNULL(RTRIM(@c_STGStatus),'''') IN (''0'', ''1'') ' +
                 ' BEGIN ' +
                 ' INSERT INTO ' + @c_POSTTableName + '('+ @SQL_Col + ') VALUES (' +@c_FParams+')' + CHAR(13) + CHAR(10) + CHAR(9) + 
                 ' IF @@ROWCOUNT >= 1' +  CHAR(13) + CHAR(10) + CHAR(9) +  
                 ' BEGIN ' +  CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 ' UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK) ' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) 
      SET @SQL3 = ' SET STG_Status = ''9''' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' WHERE RecordID=@n_RecordID '  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --' WHERE STG_Status IN (''0'',''1'') AND [No]=@No AND STG_BatchNo = @n_BatchNo '  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' END' + CHAR(13) + CHAR(10) + CHAR(9) +
                 ' ELSE' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 ' BEGIN' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK) ' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' SET STG_Status = ''5''' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' , STG_ErrMsg = ''Insert Invalid''' + CHAR(13) + CHAR(10) +  CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 --' WHERE STG_Status IN (''0'',''1'') AND [No]=@No AND STG_BatchNo = @n_BatchNo '  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' WHERE RecordID=@n_RecordID '  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  
                 ' END' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) +  
                 ' END' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 
                 ' FETCH FROM CUR_DYNAMIC INTO @n_RecordID, @c_STGStatus, ' + @c_FParams  + CHAR(13) + CHAR(10)+  
                 ' END' +  CHAR(13) + CHAR(10) +  
                 ' CLOSE CUR_DYNAMIC' + CHAR(13) + CHAR(10) +  
                 ' DEALLOCATE CUR_DYNAMIC'  
                     
      SET @c_ExecArgument = N' @n_BatchNo INT' +   
                            N',@n_Offset INT' +  
                            N',@n_Limit INT'   
                            --N',@No INT' +  
                            --N',@c_STGStatus NVARCHAR(1)'
      
      SET @SQL = CONCAT(@SQL1, @SQL2, @SQL3)

      IF @b_Debug = 1
      BEGIN
         PRINT @SQL1  
         PRINT @SQL2  
         PRINT @SQL3  
      END
        
   
      EXEC sp_executesql @SQL, @c_ExecArgument, @n_BatchNo, @n_Offset, @n_Limit --, @No, @c_STGStatus  

   END TRY    
   BEGIN CATCH    
      SET @n_Continue = 3  
      SET @b_Success = 0    
      SET @n_ErrNo = ERROR_NUMBER()    
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_ExcelLoader_Insert)'      
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
END

GO