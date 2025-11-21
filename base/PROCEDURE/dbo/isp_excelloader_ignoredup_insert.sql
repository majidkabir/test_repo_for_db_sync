SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*************************************************************************/      
/* Stored Procedure: [isp_ExcelLoader_IgnoreDup_Insert]                  */      
/* Creation Date: 24 Oct 2019                                            */      
/* Copyright: LFL                                                        */      
/* Written by: GHChan                                                    */      
/*                                                                       */      
/* Purpose: Delete the Table records and re insert data by partition     */      
/*                                                                       */      
/* Called By:  Excel Loader                                              */      
/*                                                                       */      
/* PVCS Version: 1.0                                                     */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date         Author   Ver  Purposes                                   */      
/* 24-Oct-2019  GHChan   1.0  Initial Development                        */      
/* 22-Oct-2020  GHChan   2.0  Hardcoded offset:0 and Limit:15000         */     
/*************************************************************************/      
CREATE PROC [dbo].[isp_ExcelLoader_IgnoreDup_Insert] (      
   @c_STGTableName   NVARCHAR(255)  = ''    
,  @c_POSTTableName  NVARCHAR(255)  = ''    
,  @c_PrimaryKey     NVARCHAR(2000) = ''    
,  @c_BatchNo        INT            = 0    
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
      
   DECLARE @n_Continue     INT            = 1
         , @n_StartCnt     INT            = @@TRANCOUNT
         , @n_RowCnt       INT            = @@ROWCOUNT
         , @SQL            NVARCHAR(MAX)  = ''  
         , @SQL_Col        NVARCHAR(MAX)  = ''  
         , @SQL_WITH       NVARCHAR(MAX)  = ''  
         , @n_ChkIdentity  INT            = 0
         , @c_WhereParams  NVARCHAR(1000) = ''
         , @c_PKValues     NVARCHAR(250)  = ''

   SET @b_Success = 1          
   /*********************************************/      
   /* Variables Declaration (End)               */      
   /*********************************************/      
    
   IF @c_BatchNo  <= 0     
   BEGIN    
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 730001      
      SET @c_ErrMsg = N'Invalid Batch No. (isp_ExcelLoader_IgnoreDup_Insert)'      
      GOTO QUIT    
   END    
    
   IF ISNULL(RTRIM(@c_STGTableName), '') = '' OR ISNULL(RTRIM(@c_POSTTableName), '') = ''    
   BEGIN    
      SET @n_Continue = 3    
      SET @b_Success = 0
      SET @n_ErrNo = 730002    
      SET @c_ErrMsg = N'Staging or Post TableName Cannot be Null or Empty.(isp_ExcelLoader_IgnoreDup_Insert)'      
      GOTO QUIT    
   END    
    
   IF @n_Offset < 0 OR @n_Limit < 0    
   BEGIN    
      SET @SQL = N'SELECT @n_Count=COUNT(1) FROM ' + @c_STGTableName + ' WITH (NOLOCK) WHERE STG_BatchNo = @c_BatchNo'    
      EXEC sp_executesql @SQL, N'@c_BatchNo  INT, @n_Count INT OUTPUT', @c_BatchNo, @n_Count = @n_Limit OUTPUT    
    
      IF @b_Debug = 1    
         PRINT @n_Limit    
    
      SET @n_Offset =0    
   END    
    
   IF ISNULL(RTRIM(@c_PrimaryKey), '') = ''    
   BEGIN    
      SET @n_Continue = 3      
      SET @b_Success = 0
      SET @n_ErrNo = 730003    
      SET @c_ErrMsg = N'PrimaryKey Cannot be empty!(isp_ExcelLoader_IgnoreDup_Insert)'      
      GOTO QUIT    
   END    
   BEGIN TRAN    
   BEGIN TRY
      IF CHARINDEX(',', @c_PrimaryKey) <> 0  
      BEGIN  
         DECLARE CUR_PRMYKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(@c_PrimaryKey, ',')  
         OPEN CUR_PRMYKEY  
         FETCH FROM CUR_PRMYKEY INTO @c_PKValues  

         WHILE @@FETCH_STATUS <> -1  
         BEGIN 
            IF ISNULL(RTRIM(@c_WhereParams), '') = ''  
            BEGIN  
               SET @c_WhereParams = N' TableA.' + @c_PKValues + ' = TableB.' + @c_PKValues    
            END  
            ELSE  
            BEGIN  
               SET @c_WhereParams += N' AND TableA.' + @c_PKValues + ' = TableB.' + @c_PKValues  
            END  
            FETCH FROM CUR_PRMYKEY INTO @c_PKValues  
         END  
         CLOSE CUR_PRMYKEY  
         DEALLOCATE CUR_PRMYKEY  
      END  
      ELSE  
      BEGIN  
         SET @c_WhereParams = N' TableA.' + @c_PrimaryKey + ' = TableB.' + @c_PrimaryKey 
      END


       --SET @SQL = N' SELECT @n_ChkIdentity=COUNT(1) FROM sys.columns c WITH (NOLOCK) ' +  
       --           N' INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id ' +  
       --           N' WHERE c.object_id = OBJECT_ID(@c_POSTTableName)'  

      -- SET @SQL = N' SELECT @n_ChkIdentity=MAX(column_id) FROM sys.columns c WITH (NOLOCK) ' +  
      --            N' INNER JOIN sys.types t WITH (NOLOCK) ON c.user_type_id = t.user_type_id ' +  
      --            N' WHERE c.object_id = OBJECT_ID(@c_POSTTableName)'
                    
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
    

      SET @SQL_WITH = N' ;WITH Result AS (' +    
                      N' SELECT ' + @SQL_Col + ', STG_Status, STG_ErrMsg ' +    
                      N', ROW_NUMBER() OVER (PARTITION BY '+@c_PrimaryKey+' ORDER BY [RecordID] DESC) AS row_count ' +CHAR(13) + CHAR(10) +    
                      N' FROM ' + @c_STGTableName + ' WITH (NOLOCK) ' + CHAR(13) + CHAR(10) +     
                      N' WHERE STG_BatchNo = @c_BatchNo ORDER BY [No] DESC ' + CHAR(13) + CHAR(10) +     --STG_Status IN (''0'', ''1'') AND
                      N' OFFSET @n_Offset ROWS' + CHAR(13) + CHAR(10) +    
                      N' FETCH NEXT @n_Limit ROWS ONLY)'
          
      --SET @SQL = N' IF @n_Offset = 0' + CHAR(13) + CHAR(10) +     
      --            ' BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)+     
      --            ' IF EXISTS(SELECT 1 FROM ' + @c_POSTTableName + ' WITH (NOLOCK))' + CHAR(13) + CHAR(10) + CHAR(9)+    
      --            ' BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)+CHAR(9)+    
      --            ' DELETE FROM ' + @c_POSTTableName + CHAR(13) + CHAR(10) + CHAR(9)+    
      --            ' END' + CHAR(13) + CHAR(10) +     
      --            ' END' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 

      SET @SQL = N''
      SET @SQL = @SQL_WITH +CHAR(13) + CHAR(10)+  
                 N'UPDATE TableA' +CHAR(13) + CHAR(10)+ CHAR(9)+    
                 N'SET TableA.STG_Status = ''5'' '+CHAR(13) + CHAR(10)+ CHAR(9)+    
                 N',   TableA.STG_ErrMsg = ''Duplicated Records Occurred!'' '+CHAR(13) + CHAR(10)+ CHAR(9)+
                 N' FROM Result AS TableA WITH (NOLOCK) '+CHAR(13) + CHAR(10)+ CHAR(9)+
                 N' INNER JOIN ' + @c_POSTTableName + ' AS TableB WITH (NOLOCK) ' + CHAR(13) + CHAR(10)+ CHAR(9)+
                 N' ON ' +  @c_WhereParams + CHAR(13) + CHAR(10)+CHAR(13) + CHAR(10) +
                 N' WHERE TableA.STG_Status IN (''0'', ''1'')'
      
      EXEC sp_executesql @SQL, N'@c_BatchNo INT, @n_Offset INT, @n_Limit INT ',-- @c_WhereParams NVARCHAR(1000)',    
                                 @c_BatchNo, @n_Offset,@n_Limit --, @c_WhereParams

      IF @b_Debug = 1
         PRINT 'First SQL :' + @SQL


      SET @SQL = N''
      SET @SQL = @SQL_WITH +CHAR(13) + CHAR(10)+    
                 N' INSERT INTO ' + @c_POSTTableName + '('+ @SQL_Col + ')' +CHAR(13) + CHAR(10)+    
                 N' SELECT ' + @SQL_Col + CHAR(13) + CHAR(10)+    
                 N' FROM Result r WITH (NOLOCK)' +CHAR(13) + CHAR(10)+    
                 N' WHERE r.row_count = 1 AND r.STG_Status IN (''0'',''1'')' + CHAR(13) + CHAR(10) +CHAR(13) + CHAR(10)    --
                  --+              
      EXEC sp_executesql @SQL, N'@n_Offset INT, @c_BatchNo INT, @n_Limit INT',    
                                 @n_Offset, @c_BatchNo,@n_Limit    
      SET @n_RowCnt = @@ROWCOUNT    
          
      IF @b_Debug = 1
         PRINT 'Second SQL :' + @SQL
  
       
      IF @n_RowCnt >= 1    
      BEGIN    
         SET @SQL = ''    
         SET @SQL = N' IF @n_RowCnt >= 1' + CHAR(13) + CHAR(10)+    
                    N' BEGIN' + CHAR(13) + CHAR(10)+ CHAR(9)+    
                     @SQL_WITH + CHAR(13) + CHAR(10)+ CHAR(9)+    
                    N' UPDATE Result' +CHAR(13) + CHAR(10)+ CHAR(9)+    
                    N' SET STG_Status = ' +CHAR(13) + CHAR(10)+ CHAR(9)+    
                    N' CASE WHEN row_count = 1' + CHAR(13) + CHAR(10)+ CHAR(9)+    
                    N' THEN ''9'' ELSE ''5'' END' + CHAR(13) + CHAR(10)+ CHAR(9)+ 
                    N' ,STG_ErrMsg = ' +CHAR(13) + CHAR(10)+ CHAR(9)+  
                    N' CASE WHEN row_count = 1' + CHAR(13) + CHAR(10)+ CHAR(9)+  
                    N' THEN '''' ELSE ''Duplicated Records Occurred!'' END END' --+ CHAR(13) + CHAR(10)+ CHAR(9)+  
                    --N' END' +CHAR(13) + CHAR(10)    
      END    
      --ELSE    
      --BEGIN    
      --PRINT 1    
      --   SET @n_Continue = 3    
      --   SET @b_Success = 0
      --   SET @n_ErrNo = 730004    
      --   SET @c_ErrMsg = N'No row has been inserted.(isp_ExcelLoader_IgnoreDup_Insert)'      
      --   GOTO QUIT    
      --END    
    
      EXEC sp_executesql @SQL, N'@n_RowCnt INT, @c_BatchNo INT, @n_Offset INT, @n_Limit INT', @n_RowCnt, @c_BatchNo, @n_Offset, @n_Limit    
    
      IF @b_Debug = 1
         PRINT 'Third SQL :' + @SQL    
    
   END TRY    
   BEGIN CATCH    
      SET @n_Continue = 3  
      SET @b_Success = 0    
      SET @n_ErrNo = ERROR_NUMBER()    
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_ExcelLoader_IgnoreDup_Insert)'      
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