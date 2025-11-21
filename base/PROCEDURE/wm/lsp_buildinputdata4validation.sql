SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_BuildInputData4Validation                       */  
/* Creation Date: 2023-02-28                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3648 - [CN]NIKE_TradeReturnASNReceipt_í▒Copy value to    */
/*          support all details in one receiptkey                        */                                                       
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-02-28 Wan      1.0   Created & DevOps Combine Script             */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_BuildInputData4Validation]  
   @c_WhereClause    NVARCHAR(MAX)  
,  @c_Key1           NVARCHAR(30)   = ''
,  @c_Key2           NVARCHAR(30)   = ''
,  @c_Key3           NVARCHAR(30)   = ''
,  @c_UpdateTable    NVARCHAR(30)   = ''
,  @b_Success        INT            = 1   OUTPUT    
,  @n_Err            INT            = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)  = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1
         
         , @c_UserName        NVARCHAR(128)  = SUSER_SNAME()   
         , @c_Columns         NVARCHAR(MAX)  = ''

         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_SQLParms        NVARCHAR(1000) = ''
         
         , @c_xmlSchemaString NVARCHAR(MAX)  = ''
         , @c_xmlDataString   NVARCHAR(MAX)  = '' 
                 
   DECLARE @t_TableCol  TABLE
         ( RowID        INT            IDENTITY(1,1)
         , ColName      NVARCHAR(50)   NOT NULL DEFAULT('')
         , DataType     NVARCHAR(30)   NOT NULL DEFAULT('')  
         )  
         
   SET @b_Success = 1
   SET @n_Err = 0 
   SET @c_Errmsg = ''

   BEGIN TRY
      INSERT INTO @t_TableCol (ColName, DataType)
      SELECT  c.[COLUMN_NAME] AS '@ColName'
           , c.[DATA_TYPE] + CASE WHEN c.[DATA_TYPE] LIKE 'n%char' THEN '(' + CAST(c.Character_Maximum_Length AS NVARCHAR) + ')'
                                  WHEN c.[DATA_TYPE] LIKE '%char'  THEN '(' + CAST(c.Character_Maximum_Length AS NVARCHAR) + ')'
                                  WHEN c.[DATA_TYPE] IN ('decimal','numeric') 
                                  THEN '('+ CAST(c.Numeric_Precision AS NVARCHAR) + ',' + CAST(c.Numeric_Scale AS NVARCHAR) + ')'
                                  ELSE ''
                                  END
            AS '@DataType'
      FROM Tempdb.INFORMATION_SCHEMA.COLUMNS c 
      JOIN tempdb.dbo.sysobjects AS s ON s.[name] = c.TABLE_NAME     -- Use SysObjects to get unique temp table name
      WHERE s.id = OBJECT_ID('tempdb..#INPUTDATA')                   
      AND   c.[DATA_TYPE] <> 'TimeStamp'
      ORDER BY c.ordinal_position
                      
      SELECT @c_Columns = STRING_AGG (CONVERT(NVARCHAR(MAX),'RTRIM(' + ttc.ColName + ') AS ''@'+ RTRIM(@c_UpdateTable) +'.' + ttc.ColName + ''''), ',' )
            WITHIN GROUP (ORDER BY ttc.RowID ASC)
      FROM @t_TableCol AS ttc
   
      SET @c_xmlSchemaString = (
                                 SELECT RTRIM(@c_UpdateTable) + '.' + ttc.ColName  AS '@ColName'
                                       ,ttc.DataType AS '@DataType'
                                 FROM @t_TableCol AS ttc
                                 ORDER BY ttc.RowID
                                 FOR XML PATH ('Column'), ROOT('Table')
                               )  

      SET @c_SQL = N'SET @c_xmlDataString = ('
                 + ' SELECT TOP 1 ' + @c_Columns + ' FROM #INPUTDATA'
                 + IIF(@c_WhereClause = '', '', ' WHERE ' + @c_WhereClause)
                 + ' FOR XML PATH (''Row'') )'
                 
      SET @c_SQLParms= N'@c_xmlDataString NVARCHAR(MAX)  OUTPUT'  
                     + ',@c_Key1          NVARCHAR(30)'   
                     + ',@c_Key2          NVARCHAR(30)'  
                     + ',@c_Key3          NVARCHAR(30)'  

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_xmlDataString OUTPUT 
                        ,@c_Key1      
                        ,@c_Key2     
                        ,@c_Key3   

      IF @c_XMLSchemaString = '' OR @c_XMLDataString = ''
      BEGIN
         SET @n_Continue = 3
      END
         
      IF @n_Continue IN (1,2)
      BEGIN         
         EXEC [WM].[lsp_Wrapup_Validation_Wrapper]  
            @c_Module            = ''
         ,  @c_ControlObject     = ''
         ,  @c_UpdateTable       = @c_UpdateTable
         ,  @c_XMLSchemaString   = @c_XMLSchemaString 
         ,  @c_XMLDataString     = @c_XMLDataString   
         ,  @b_Success           = @b_Success   OUTPUT        
         ,  @n_Err               = @n_Err       OUTPUT        
         ,  @c_Errmsg            = @c_Errmsg    OUTPUT
         ,  @c_UserName          = @c_UserName
         
         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
         END
      END                                                                                    
   END TRY

   BEGIN CATCH
      SET @n_continue = 3 
      SET @c_errmsg = ERROR_MESSAGE()
      GOTO EXIT_SP      
   END CATCH 
        
   EXIT_SP:  

   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[lsp_BuildInputData4Validation]'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO