SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: [isp_ExcelLoader_DelInsert]                         */    
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
CREATE PROC [dbo].[isp_ExcelLoader_DelInsert] (    
   @c_STGTableName   NVARCHAR(255)  = ''  
,  @c_POSTTableName  NVARCHAR(255)  = ''  
,  @c_BatchNo           INT         = 0  
,  @n_Offset            INT         = 0 
,  @n_Limit             INT         = 0   
,  @b_Debug             INT         = 0    
,  @b_Success           INT         = 0    OUTPUT    
,  @n_ErrNo             INT         = 0    OUTPUT    
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
    
   DECLARE @n_Continue     INT            = 1
         , @n_StartCnt     INT            = @@TRANCOUNT
         , @n_RowCnt       INT            = @@ROWCOUNT
         , @SQL            NVARCHAR(MAX)  = ''
         , @SQL_Col        NVARCHAR(MAX)  = ''
         , @n_ChkIdentity  INT            = 0
   
   SET @b_Success = 1
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
  
   IF @c_BatchNo <= 0   
   BEGIN  
      SET @n_Continue = 3    
      SET @b_Success = 0
      SET @n_ErrNo = 730001    
      SET @c_ErrMsg = N'Invalid Batch No. (isp_ExcelLoader_DelInsert)'    
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_STGTableName), '') = '' OR ISNULL(RTRIM(@c_POSTTableName), '') = ''  
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730002  
      SET @c_ErrMsg = N'Staging or Post TableName Cannot be Null or Empty.(isp_ExcelLoader_DelInsert)'    
      GOTO QUIT  
   END  
  
   IF @n_Offset < 0 OR @n_Limit < 0  
   BEGIN  
      SET @SQL = N'SELECT @n_Count=COUNT(1) FROM ' + @c_STGTableName + N' WITH (NOLOCK) WHERE STG_BatchNo = @c_BatchNo'  
      EXEC sp_executesql @SQL, N'@c_BatchNo INT, @n_Count INT OUTPUT', @c_BatchNo, @n_Count = @n_Limit OUTPUT  
  
      IF @b_Debug = 1  
         PRINT @n_Limit  
  
      SET @n_Offset =0  
   END  
  
   BEGIN TRANSACTION

   BEGIN TRY  
      
      --SET @SQL = N' SELECT @n_ChkIdentity=MAX(column_id) FROM sys.columns c WITH (NOLOCK) ' +  
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
            + CASE WHEN c.column_id=@n_ChkIdentity THEN '' ELSE ',' END  
            FROM sys.columns c   
            INNER JOIN sys.types t ON c.user_type_id = t.user_type_id   
            WHERE c.object_id = OBJECT_ID(@c_POSTTableName) AND is_identity = 0  
            ORDER BY c.column_id  
            FOR XML PATH(''), TYPE  
      ).value('.','nvarchar(max)')  
  
      SET @SQL = N''
      SET @SQL = N' IF @n_Offset = 0' +  
                 N' BEGIN' +  
                 N'    IF EXISTS(SELECT 1 FROM ' + @c_POSTTableName + ' WITH (NOLOCK))' +  
                 N'    BEGIN' +
                 N'       IF EXISTS(SELECT 1 FROM ' + @c_STGTableName + ' WITH (NOLOCK)' +  
                 N'       WHERE STG_BatchNo = @c_BatchNo)' + --STG_Status IN (''0'', ''1'') AND
                 N'       BEGIN' +  
                 N'          DELETE FROM ' + @c_POSTTableName +  
                 N'       END' + 
                 N'    END' +  
                 N' END' +  
                 N' INSERT INTO ' + @c_POSTTableName + '('+ @SQL_Col + ')' +  
                 N' SELECT ' + @SQL_Col + ' FROM ' + @c_STGTableName + ' WITH (NOLOCK)' +  
                 N' WHERE STG_Status IN (''0'', ''1'') AND STG_BatchNo = @c_BatchNo' +
                 N' ORDER BY [No] ASC' +  
                 N' OFFSET 0 ROWS' +  
                 N' FETCH NEXT 15000 ROWS ONLY' 
                    
      EXEC sp_executesql @SQL, N'@n_Offset INT, @c_BatchNo INT', @n_Offset, @c_BatchNo   --, @n_Limit INT   ,@n_Limit  
      SET @n_RowCnt = @@ROWCOUNT  
        
      IF @b_Debug = 1  
      BEGIN
         PRINT @SQL  
         PRINT @n_RowCnt  
         --PRINT @n_Limit
      END

      SET @SQL = N'' 

      IF @n_RowCnt > 0  
      BEGIN    
         SET @SQL = N'  UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK)' +  
                    N'  SET STG_Status = ''9''' +  
                    N'  WHERE [No] IN (SELECT [No] FROM ' + @c_STGTableName + ' WITH (NOLOCK)' +  
                    N'  WHERE STG_Status IN (''0'', ''1'') AND STG_BatchNo = @c_BatchNo ORDER BY [No] ASC' +   
                    N'  OFFSET 0 ROWS' +  
                    N'  FETCH NEXT 15000 ROWS ONLY)'
      END  
      ELSE  
      BEGIN  
         SET @SQL = N'  UPDATE ' + @c_STGTableName + ' WITH (ROWLOCK)' +  
                    N'  SET STG_Status = ''5''' +  
                    N'  WHERE [No] IN (SELECT [No] FROM ' + @c_STGTableName + ' WITH (NOLOCK)' +  
                    N'  WHERE STG_Status IN (''0'', ''1'') AND STG_BatchNo = @c_BatchNo ORDER BY [No] ASC' +   
                    N'  OFFSET 0 ROWS' +  
                    N'  FETCH NEXT 15000 ROWS ONLY)'    
      END  
  
      EXEC sp_executesql @SQL, N'@c_BatchNo INT', @c_BatchNo    --, @n_Offset INT, @n_Limit INT    , @n_Offset, @n_Limit
  
      IF @b_Debug = 1  
         PRINT @SQL  
  
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3    
      SET @b_Success = 0
      SET @n_ErrNo = ERROR_NUMBER()  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_ExcelLoader_DelInsert)'    
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