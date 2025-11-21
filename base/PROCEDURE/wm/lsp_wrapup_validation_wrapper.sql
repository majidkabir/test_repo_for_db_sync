SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Wrapup_Validation_Wrapper                       */  
/* Creation Date: 25-Oct-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.5                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2020-06-16 Wan01    1.1   WMS-2049. Fix not to return correct         */
/*                           @b_success when error executing             */
/*                           isp_Wrapup_Validation                       */
/* 2020-11-18 SWT01    1.2   Bug fixing                                  */ 
/* 2020-11-23 Wan02    1.2   Add Big Outer Begin Try..End Try to enable  */
/*                           Revert when Sub SP Raise error              */ 
/* 2021-01-15 Wan03    1.3   Execute Login if @c_UserName<>SUSER_SNAME() */
/* 2023-03-09 NJOW01   1.4   LFWM-3608 Performance tuning for XML Reading*/
/* 2023-05-18 Wan04    1.5   LFWM-4116 Performance tuning                */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Wrapup_Validation_Wrapper]  
      @c_Module               NVARCHAR(60) = ''
   ,  @c_ControlObject        NVARCHAR(60) = ''
   ,  @c_UpdateTable          NVARCHAR(30)
   ,  @c_XMLSchemaString      NVARCHAR(MAX) 
   ,  @c_XMLDataString        NVARCHAR(MAX) 
   ,  @b_Success              INT OUTPUT    
   ,  @n_Err                  INT OUTPUT
   ,  @c_Errmsg               NVARCHAR(255) OUTPUT
   ,  @c_UserName             NVARCHAR(128) = ''
   ,  @n_WarningNo            INT = 0       OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1) = 'N' 
   ,  @c_IsSupervisor         CHAR(1) = 'N' 
   ,  @c_XMLDataString_Prev   NVARCHAR(MAX) = '' 
AS  
BEGIN  
   SET ANSI_NULLs ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE @c_SPName                NVARCHAR(50)   = ''
         , @c_SQL                   NVARCHAR(MAX)  = ''
         , @c_SQLParms              NVARCHAR(4000) = ''         
         , @b_logerror              BIT            = 0   --(Wan02)
         
         , @b_CallFromSP            BIT            = 0   --(Wan04) 
         
   --NJOW01      
   DECLARE      
           @c_ReqInPutExtValidate   NVARCHAR(10) = 'Y'         
         , @c_Storerkey             NVARCHAR(15) = ''   
         , @n_StorerPos             INT = 0 
         , @n_StorerEndPos          INT = 0        
         , @c_StorerTag             NVARCHAR(200) = ''                   
         , @c_TableColumns          NVARCHAR(MAX) = '' 
         , @c_ColumnName            NVARCHAR(128) = ''  
         , @c_DataType              NVARCHAR(128) = ''  
         , @c_TableName             NVARCHAR(30) = ''   
         , @c_SQLSchema             NVARCHAR(MAX) = ''           
         , @x_XMLSchema             XML  
         , @x_XMLData               XML  
         , @n_XMLHandle             INT = 0                 
         , @c_SQLSchema_OXML        NVARCHAR(MAX) = ''  
         , @c_TableColumns_OXML     NVARCHAR(MAX) = ''  
         , @c_SQL2                  NVARCHAR(MAX) = ''
         
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan03) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] 
               @c_UserName = @c_UserName  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
            
      IF @n_Err = 0   
      BEGIN       
         EXECUTE AS LOGIN = @c_UserName
      END
   END                                   --(Wan03) - END
   
   DECLARE 
      @n_Continue       INT = 1
   --(Wan02) - START  
   BEGIN TRY
      SET @c_SPName = 'lsp_Validate_' + RTRIM(@c_UpdateTable) + '_Std'
      
      IF EXISTS (SELECT 1                                                           --(wan04) - START                
                 FROM dbo.sysobjects (NOLOCK) WHERE ID = OBJECT_ID(@c_ControlObject) AND [Type] = 'P')   
      BEGIN 
         SET @b_CallFromSP = 1
      END 
     
      IF @b_CallFromSP = 1 AND LEN(@c_XMLDataString) <> ''
      BEGIN
         IF SUBSTRING(@c_XMLDataString, 1, 15) = 'CUSTOM_VALIDATE'
         BEGIN
         
            SET @c_ReqInPutExtValidate = 'Y'
            GOTO CUSTOM_VALIDATE
         END 
         
         IF SUBSTRING(@c_XMLDataString, 1, 12) = 'STD_VALIDATE'
         BEGIN
            SET @c_ReqInPutExtValidate = 'N'
            GOTO STD_VALIDATE
         END          
      END                                                                           --(wan04) - END                         
      
      --NJOW01 S
      IF OBJECT_ID('tempdb..#VALDN') IS NOT NULL AND @b_CallFromSP = 0              --(wan04)  
      BEGIN  
         DROP TABLE #VALDN  
      END  
      IF OBJECT_ID('tempdb..#SCHEMA') IS NOT NULL AND @b_CallFromSP = 0             --(wan04)  
      BEGIN  
         DROP TABLE #SCHEMA  
      END  
      
      IF @c_Module <> 'w_userdefine_extended_validation' AND @b_CallFromSP = 0      --(wan04) 
      BEGIN
         IF @c_UpdateTable IN('TRANSFER','TRANSFERDETAIL')
            SET @c_StorerTag = RTRIM(@c_UpdateTable)+'.FromStorerkey="'
         ELSE   
            SET @c_StorerTag = RTRIM(@c_UpdateTable)+'.Storerkey="'
           
         SELECT @n_StorerPos = CHARINDEX(@c_StorerTag , @c_XMLDataString)

         IF @n_StorerPos > 0 
            SELECT @n_StorerEndPos = CHARINDEX('"', LEFT(@c_XMLDataString, @n_StorerPos + 100), @n_StorerPos + LEN(@c_StorerTag))

         IF @n_StorerEndPos > 0
            SELECT @c_Storerkey = SUBSTRING(@c_XMLDataString, @n_StorerPos + LEN(@c_StorerTag), @n_StorerEndPos - @n_StorerPos - LEN(@c_StorerTag))
             
         IF NOT EXISTS(SELECT TOP 1 1
                        FROM CODELKUP CL (NOLOCK) 
                        JOIN CODELIST CLS (NOLOCK) ON CL.UDF01 = CLS.LISTNAME
                        JOIN CODELKUP CLSD (NOLOCK) ON CLS.ListName = CLSD.Listname
                        JOIN V_Extended_Validation V ON CLS.ListGroup = V.ValidateTable AND CL.Code = V.ValidationType
                        WHERE CL.ListName = 'VALDNCFG'
                        AND V.ValidationType <> V.ValidateTable
                        AND CLS.ListGroup = @c_UpdateTable
                        AND CL.Storerkey = @c_Storerkey) 
            AND @n_StorerEndPos > 0
         BEGIN
            SET @c_ReqInPutExtValidate = 'N'
         END                

         IF @c_ReqInPutExtValidate = 'Y' 
              OR EXISTS (SELECT 1 FROM sys.Objects (NOLOCK) WHERE Name = @c_SPName AND type = 'P') 
         BEGIN      
            CREATE TABLE #VALDN( Rowid  INT NOT NULL IDENTITY(1,1) PRIMARY KEY)  
            CREATE TABLE #SCHEMA (Column_Name NVARCHAR(80), Data_Type NVARCHAR(80)) 
            
            SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)  
            SET @x_XMLData = CONVERT(XML, @c_XMLDataString)  
            
            EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLSchemaString      
            DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT ColName, DataType 
               FROM OPENXML (@n_XMLHandle, '/Table/Column',1)  
               WITH (ColName  NVARCHAR(128),  
                     DataType NVARCHAR(128))
              
            OPEN CUR_SCHEMA  
            
            FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
            
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               SET @c_TableName = ''  
               IF CHARINDEX('.', @c_ColumnName) > 0   
               BEGIN  
                  SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))  
                  SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))  
               END  
            
               SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_datatype + ' NULL, '  
               SET @c_SQLSchema_OXML  = @c_SQLSchema_OXML + '['+@c_TableName+@c_ColumnName + '] ' + @c_DataType + ', '
               SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '  
               SET @c_TableColumns_OXML = @c_TableColumns_OXML + '[' + @c_TableName + @c_ColumnName + '], '

               IF CHARINDEX('(', @c_datatype) > 0  
               BEGIN  
                    SET @c_datatype = LTRIM(RTRIM(LEFT(@c_datatype, CHARINDEX('(', @c_datatype) - 1)))  
               END  
                 
               INSERT INTO #SCHEMA (Column_Name, Data_Type)  
               VALUES (@c_ColumnName, @c_datatype)  
                                           
               FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
            END  
            CLOSE CUR_SCHEMA  
            DEALLOCATE CUR_SCHEMA      
            EXEC sp_xml_removedocument @n_XMLHandle            

            IF @c_SQLSchema <> ''  
            BEGIN  
               SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '  
            
               EXEC (@c_SQL)  
            
               EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLDataString
            
               
               SET @c_SQL = N' INSERT INTO #VALDN' 
                           + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                           + ' SELECT ' + SUBSTRING(@c_TableColumns_OXML, 1, LEN(@c_TableColumns_OXML) - 1)
                           + ' FROM  OPENXML (@n_XMLHandle, ''Row'',1) '
                           + ' WITH (' + SUBSTRING(@c_SQLSchema_OXML, 1, LEN(@c_SQLSchema_OXML) - 1) + ')'
                              
               EXEC sp_executeSQl @c_SQL
                                 , N'@n_XMLHandle INT'
                                 , @n_XMLHandle                  
                                                 
               EXEC sp_xml_removedocument @n_XMLHandle                         
            END
         END   
      END   
      --NJOW02 E
     
      IF @c_Module = N'w_userdefine_extended_validation'
      BEGIN
         GOTO CUSTOM_VALIDATE
      END
      -- Getting the Window/object lookup between Exceed and WM system.
      
      STD_VALIDATE:                                                                 --(Wan04)
      IF @n_Continue IN (1,2) --AND ( @c_ProceedWithWarning <> 'N' OR (@c_ProceedWithWarning = 'Y' OR @n_WarningNo < 1) )
      BEGIN  

         --IF @c_UpdateTable NOT IN ( 'RECEIPT', 'PICKDETAIL' )
         BEGIN
            SET @b_Success = 1
            SET @n_Err = 0 
            SET @c_Errmsg = ''
                     
            IF EXISTS (SELECT 1 FROM sys.Objects (NOLOCK) WHERE Name = @c_SPName AND type = 'P')
            BEGIN                      
               SET @c_SQL = N'EXEC WM.' + @c_SPName
                          + ' @c_XMLSchemaString   = @c_XMLSchemaString'
                          + ',@c_XMLDataString     = @c_XMLDataString'
                          + ',@b_Success           = @b_Success   OUTPUT'
                          + ',@n_Err               = @n_Err       OUTPUT'
                          + ',@c_ErrMsg            = @c_Errmsg    OUTPUT' 
                          + ',@n_WarningNo         = @n_WarningNo OUTPUT'
                          + ',@c_ProceedWithWarning= @c_ProceedWithWarning'
                          + ',@c_IsSupervisor      = @c_IsSupervisor'
                          + ',@c_XMLDataString_Prev= @c_XMLDataString_Prev'   

               SET @c_SQLParms = N'@c_XMLSchemaString    NVARCHAR(MAX)' 
                               + ',@c_XMLDataString      NVARCHAR(MAX)'
                               + ',@b_Success            INT            OUTPUT'
                               + ',@n_Err                INT            OUTPUT'
                               + ',@c_ErrMsg             NVARCHAR(255)  OUTPUT' 
                               + ',@n_WarningNo          INT            OUTPUT'
                               + ',@c_ProceedWithWarning CHAR(1)'  
                               + ',@c_IsSupervisor       CHAR(1)' 
                               + ',@c_XMLDataString_Prev NVARCHAR(MAX)'  
               -- SWT01   
               BEGIN TRY
                  SET @b_Success = 1   
                  EXEC sp_ExecuteSQL @c_SQL
                                    ,@c_SQLParms
                                    ,@c_XMLSchemaString     
                                    ,@c_XMLDataString      
                                    ,@b_Success            OUTPUT 
                                    ,@n_Err                OUTPUT 
                                    ,@c_ErrMsg             OUTPUT 
                                    ,@n_WarningNo          OUTPUT
                                    ,@c_ProceedWithWarning  
                                    ,@c_IsSupervisor  
                                    ,@c_XMLDataString_Prev
               END TRY  
     
               BEGIN CATCH  
                  SET @b_Success = 0   
                  SET @n_err = 553802  
                  SET @c_ErrMsg = ERROR_MESSAGE()  
                  SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_SPName + '. (lsp_Wrapup_Validation_Wrapper)'  
                                 + '( ' + @c_errmsg + ' )' 
                  SET @b_logerror = 1                       --(Wan02)                
               END CATCH      
        
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO EXIT_SP
               END
            END
         END -- @c_UpdateTable = 'RECEIPT'
      END -- @n_Continue IN (1,2)
     
      CUSTOM_VALIDATE:        
      IF @n_Continue IN (1,2) AND @c_ReqInPutExtValidate = 'Y' --NJOW01                                                                                  
      BEGIN
         BEGIN TRY      
         SET @b_Success = 1
                           
         EXEC isp_Wrapup_Validation         
             @c_Window          = @c_Module          
            ,@c_BusObj          = @c_ControlObject          
            ,@c_UpdateTable     = @c_UpdateTable     
            ,@c_XMLSchemaString = @c_XMLSchemaString 
            ,@c_XMLDataString   = @c_XMLDataString   
            ,@b_Success         = @b_Success  OUTPUT       
            ,@n_Err             = @n_Err      OUTPUT       
            ,@c_Errmsg          = @c_Errmsg   OUTPUT              
         END TRY

         BEGIN CATCH
            SET @n_err = 553801
            SET @c_ErrMsg = ERROR_MESSAGE()            
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_Wrapup_Validation. (lsp_Wrapup_Validation_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
            SET @b_logerror = 1                       --(Wan02)            
         END CATCH    
                      
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END              
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3 
      SET @c_errmsg = ERROR_MESSAGE()
      SET @c_errmsg = 'Save Validation Fail. (lsp_Wrapup_Validation_Wrapper)'
                    + '( SQLSvr MESSAGE=' + @c_errmsg + ' ) '  
      SET @b_logerror = 1                
      GOTO EXIT_SP      
   END CATCH --(Wan02) - END
        
   EXIT_SP:  
   
   --NJOW01 S
   IF OBJECT_ID('tempdb..#VALDN') IS NOT NULL AND @b_CallFromSP = 0                 --(wan04)  
   BEGIN  
      DROP TABLE #VALDN  
   END     
   IF OBJECT_ID('tempdb..#SCHEMA') IS NOT NULL AND @b_CallFromSP = 0                --(wan04)  
   BEGIN  
      DROP TABLE #SCHEMA  
   END  
   --NJOW01 E

   SET @b_success = 0         --(Wan01)
   IF @n_Continue IN (1,2)
   BEGIN
      SET @b_success = 1      --(Wan01)
      SET @n_WarningNo = 0
   END  
   ELSE  --(Wan02) - START
   BEGIN
      IF @b_logerror = 1 
      BEGIN
         execute nsp_logerror @n_err, @c_errmsg, 'lsp_Wrapup_Validation_Wrapper' 
      END 
   END   --(Wan02) - END

   REVERT      
END

GO