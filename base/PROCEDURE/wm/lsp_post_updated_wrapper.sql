SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Post_Updated_Wrapper                            */  
/* Creation Date: 25-Oct-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 2020-11-30  Wan01    1.1   Add Big Outer Begin Try..End Try to enable */
/*                            Revert when Raise error                    */  
/* 15-Jan-2021 Wan02    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Post_Updated_Wrapper]  
      @c_Module            NVARCHAR(60) = ''
   ,  @c_Schema            NVARCHAR(128) = 'DBO'
   ,  @c_TableName         NVARCHAR(128) = ''
   ,  @c_RefKey1           NVARCHAR(50)  = ''
   ,  @c_RefKey2           NVARCHAR(50)  = ''
   ,  @c_RefKey3           NVARCHAR(50)  = ''
   ,  @c_ColumnsUpdated    NVARCHAR(4000) = ''
   ,  @c_RefreshHeader     CHAR(1) = 'N' OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N' OUTPUT 
   ,  @b_Success           INT = 1 OUTPUT   
   ,  @n_Err               INT = 0 OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = '' OUTPUT
   ,  @c_UserName          NVARCHAR(128) = ''
AS  
BEGIN  
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE @c_PrimaryKey NVARCHAR(128) = ''
         , @c_StorerKey  NVARCHAR(15) = ''
         , @c_Facility   NVARCHAR(5)  = ''
         , @c_SQL        NVARCHAR(MAX) = ''
         , @n_KeySeq     INT = 0 
         , @c_StoredProcedure NVARCHAR(128) = ''
         , @n_StepNo     INT = 0 

   SET @b_Success = 1
   SET @c_RefreshHeader = 'N'
   SET @c_RefreshDetail = 'N'

    -- Not doing anything if storerkey not exists
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.[COLUMNS] AS c WITH(NOLOCK)
                   WHERE c.TABLE_NAME = @c_TableName
                   AND   c.TABLE_SCHEMA = @c_Schema)
    BEGIN
       RETURN 
    END
                 
    DECLARE CUR_PRIMARY_KEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT COLUMN_NAME 
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
    AND TABLE_NAME = @c_TableName
    AND TABLE_SCHEMA = @c_Schema
    ORDER BY ORDINAL_POSITION
       
    OPEN CUR_PRIMARY_KEY 
    
    FETCH NEXT FROM CUR_PRIMARY_KEY INTO @c_PrimaryKey 
    WHILE @@FETCH_STATUS = 0 
    BEGIN
       SET @n_KeySeq = @n_KeySeq + 1
       
       IF @c_SQL = ''
       BEGIN
         SET @c_SQL = N'SELECT @c_StorerKey = StorerKey FROM ' + @c_Schema + '.' + @c_TableName + CHAR(13) + 
                      N' WHERE ' + @c_PrimaryKey + ' = ' + 
                      CASE WHEN @n_KeySeq = 1 THEN QUOTENAME(@c_RefKey1,'''') 
                           WHEN @n_KeySeq = 2 THEN QUOTENAME(@c_RefKey2,'''') 
                           WHEN @n_KeySeq = 3 THEN QUOTENAME(@c_RefKey3,'''')
                      END 
       END
       ELSE 
       BEGIN
         SET @c_SQL = @c_SQL + CHAR(13) + 
                      N' AND ' + @c_PrimaryKey + ' = ' + 
                      CASE WHEN @n_KeySeq = 1 THEN QUOTENAME(@c_RefKey1,'''') 
                           WHEN @n_KeySeq = 2 THEN QUOTENAME(@c_RefKey2,'''') 
                           WHEN @n_KeySeq = 3 THEN QUOTENAME(@c_RefKey3,'''')
                      END           
       END        
       FETCH NEXT FROM CUR_PRIMARY_KEY INTO @c_PrimaryKey
    END
    CLOSE CUR_PRIMARY_KEY
    DEALLOCATE CUR_PRIMARY_KEY

    -- PRINT @c_SQL
    
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err = 0 
      BEGIN
         EXECUTE AS LOGIN=@c_UserName
      END
   END                                    --(Wan02) - END  
       
    BEGIN TRY  --(Wan01) - START    
      IF @c_SQL <> ''
      BEGIN
      
         SET @c_StorerKey = ''
         EXEC sp_ExecuteSQL @c_SQL, N' @c_StorerKey NVARCHAR(15) OUTPUT', @c_StorerKey OUTPUT
       
         DECLARE CUR_STORED_PROCEDURE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT wtec.StepNo, wtec.StoredProcedure 
         FROM WM.WMS_TABLE_EVENT_CONFIG AS wtec WITH(NOLOCK) 
         WHERE wtec.Module = @c_Module 
         AND   wtec.TableName = @c_TableName 
         AND   wtec.[Event] = 'UPDATED' 
         AND   wtec.StorerKey = @c_StorerKey
         UNION 
         SELECT 0 AS [StepNo], wtec.StoredProcedure 
         FROM WM.WMS_TABLE_EVENT_CONFIG AS wtec WITH(NOLOCK) 
         WHERE wtec.Module = @c_Module 
         AND   wtec.TableName = @c_TableName 
         AND   wtec.[Event] = 'UPDATED' 
         AND   wtec.StorerKey = 'ALL'        
         ORDER BY StepNo 
       
       
         OPEN CUR_STORED_PROCEDURE
       
         FETCH FROM CUR_STORED_PROCEDURE INTO @n_StepNo, @c_StoredProcedure
       
         WHILE @@FETCH_STATUS = 0
         BEGIN
         EXEC sp_ExecuteSQL @c_StoredProcedure, 
         N'@c_StorerKey  NVARCHAR(15)
         ,  @c_RefKey1           NVARCHAR(50)  = ''''
         ,  @c_RefKey2           NVARCHAR(50)  = ''''
         ,  @c_RefKey3           NVARCHAR(50)  = ''''
         ,  @c_ColumnsUpdated    NVARCHAR(4000) = '''' 
         ,  @c_RefreshHeader     CHAR(1) = ''N'' OUTPUT
         ,  @c_RefreshDetail     CHAR(1) = ''N'' OUTPUT 
         ,  @b_Success           INT = 1 OUTPUT   
         ,  @n_Err               INT = 0 OUTPUT
         ,  @c_Errmsg            NVARCHAR(255) = '''' OUTPUT
         ,  @c_UserName          NVARCHAR(128) = '''''
         , @c_StorerKey 
         , @c_RefKey1         
         , @c_RefKey2         
         , @c_RefKey3         
         , @c_ColumnsUpdated 
         , @c_RefreshHeader  OUTPUT 
         , @c_RefreshDetail  OUTPUT 
         , @b_Success OUTPUT        
         , @n_Err     OUTPUT            
         , @c_Errmsg  OUTPUT         
         , @c_UserName          
       
         FETCH FROM CUR_STORED_PROCEDURE INTO @n_StepNo, @c_StoredProcedure
         END
       
         CLOSE CUR_STORED_PROCEDURE
         DEALLOCATE CUR_STORED_PROCEDURE

      END -- IF @c_SQL <> ''
   END TRY

   BEGIN CATCH
      SET @c_ErrMsg = 'POST Update fail. (lsp_Post_Updated_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Post_Updated_Wrapper'  
   END CATCH   --(Wan01) - END   
   REVERT      
END

GO