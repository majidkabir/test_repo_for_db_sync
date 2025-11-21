SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_ChannelInvHold_Std                      */  
/* Creation Date: 2021-09-22                                              */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose: LFWM-2918 - SCE Channel Management modules  Channel Inventory */
/*        : Hold implementations                                          */  
/*                                                                        */  
/* Called By: WM.lsp_Wrapup_Validation_Wrapper                            */  
/*                                                                        */  
/* Version: 1.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date        Author   Ver   Purposes                                    */ 
/* 2021-09-22  Wan      1.0   Created.                                    */
/* 2021-09-22  Wan      1.0   DevOps Script Combine                       */
/* 2023-03-14  NJOW01   1.1   LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_ChannelInvHold_Std] (
  @c_XMLSchemaString    NVARCHAR(MAX) 
, @c_XMLDataString      NVARCHAR(MAX) 
, @b_Success            INT OUTPUT
, @n_Err                INT OUTPUT
, @c_ErrMsg             NVARCHAR(250) OUTPUT
, @n_WarningNo          INT = 0       OUTPUT
, @c_ProceedWithWarning CHAR(1) = 'N'
, @c_IsSupervisor       CHAR(1) = 'N' 
, @c_XMLDataString_Prev NVARCHAR(MAX) = ''
) AS 
BEGIN
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON
  
   DECLARE     
      @x_XMLSchema         XML
   ,  @x_XMLData           XML 
   ,  @c_TableColumns      NVARCHAR(MAX) = N''
   ,  @c_ColumnName        NVARCHAR(128) = N''
   ,  @c_DataType          NVARCHAR(128) = N''
   ,  @c_TableName         NVARCHAR(30)  = N''
   ,  @c_SQL               NVARCHAR(MAX) = N''
   ,  @c_SQLSchema         NVARCHAR(MAX) = N''
   ,  @c_SQLData           NVARCHAR(MAX) = N''   
   ,  @n_Continue          INT = 1 
   ,  @n_XMLHandle         INT                  --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01

   BEGIN TRY
        /* --NJOW01 Removed      
      IF OBJECT_ID('tempdb..#CHANNELINVHOLD') IS NOT NULL
      BEGIN
         DROP TABLE #CHANNELINVHOLD
      END
      */

      --NJOW01 S      
      IF OBJECT_ID('tempdb..#VALDN') IS NULL
      BEGIN
         CREATE TABLE #VALDN( Rowid  INT NOT NULL IDENTITY(1,1) )   
         
         SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
         SET @x_XMLData = CONVERT(XML, @c_XMLDataString)
         
         EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLSchemaString      
         DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ColName, DataType 
            FROM OPENXML (@n_XMLHandle, '/Table/Column',1)  
            WITH (ColName  NVARCHAR(128),  
                  DataType NVARCHAR(128))
                                    
         OPEN CUR_SCHEMA
         
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_TableName = ''
            IF CHARINDEX('.', @c_ColumnName) > 0 
            BEGIN
               SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
               SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
            END
         
            SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
            SET @c_SQLSchema_OXML  = @c_SQLSchema_OXML + '['+@c_TableName+@c_ColumnName + '] ' + @c_DataType + ', '
            SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
            SET @c_TableColumns_OXML = @c_TableColumns_OXML + '[' + @c_TableName + @c_ColumnName + '], '
               
            FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
         END
         CLOSE CUR_SCHEMA
         DEALLOCATE CUR_SCHEMA
         EXEC sp_xml_removedocument @n_XMLHandle    
                       
         IF LEN(@c_SQLSchema) > 0 
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
      --NJOW01 E                            

      /*
      CREATE TABLE #CHANNELINVHOLD( Rowid  INT NOT NULL IDENTITY(1,1) )   

      SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
      SET @x_XMLData = CONVERT(XML, @c_XMLDataString)

      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT x.value('@ColName', 'NVARCHAR(128)') AS columnname
            ,x.value('@DataType','NVARCHAR(128)') AS datatype
      FROM @x_XMLSchema.nodes('/Table/Column') TempXML (x)
         
      OPEN CUR_SCHEMA

      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_TableName = ''
         IF CHARINDEX('.', @c_ColumnName) > 0 
         BEGIN
            SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
            SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
         END

         SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
         SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
         SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], '
            
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
      END
      CLOSE CUR_SCHEMA
      DEALLOCATE CUR_SCHEMA
          
          
      IF LEN(@c_SQLSchema) > 0 
      BEGIN
         SET @c_SQL = N'ALTER TABLE #CHANNELINVHOLD  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #CHANNELINVHOLD' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
      END
      */

      DECLARE
            @n_InvHoldKey        BIGINT       = 0
         ,  @c_HoldType          NVARCHAR(10) = ''
         ,  @c_Facility          NVARCHAR(5) = ''
         ,  @c_Storerkey         NVARCHAR(15) = ''
         ,  @c_Sku               NVARCHAR(20) = ''
         ,  @c_Channel           NVARCHAR(20) = ''
         ,  @c_C_Attribute01     NVARCHAR(18) = ''  
         ,  @c_C_Attribute02     NVARCHAR(18) = ''  
         ,  @c_C_Attribute03     NVARCHAR(18) = ''  
         ,  @c_C_Attribute04     NVARCHAR(8)  = ''  
         ,  @c_C_Attribute05     NVARCHAR(8)  = ''  
         ,  @n_Channel_ID        BIGINT       = 0 
         ,  @c_Hold              NVARCHAR(1)  = ''
         ,  @c_Remarks           NVARCHAR(255)= ''  

      SELECT TOP 1
            @c_HoldType       = c.HoldType     
         ,  @c_Facility       = c.Facility     
         ,  @c_Storerkey      = c.Storerkey    
         ,  @c_Sku            = c.Sku          
         ,  @c_Channel        = c.Channel      
         ,  @c_C_Attribute01  = c.C_Attribute01 
         ,  @c_C_Attribute02  = c.C_Attribute02 
         ,  @c_C_Attribute03  = c.C_Attribute03 
         ,  @c_C_Attribute04  = c.C_Attribute04 
         ,  @c_C_Attribute05  = c.C_Attribute05 
         ,  @n_Channel_ID     = c.Channel_ID
         ,  @c_Hold           = c.Hold         
         ,  @c_Remarks        = c.Remarks  
      FROM #VALDN AS c   --NJOW01
      ORDER BY c.InvHoldkey  
      
      EXEC dbo.isp_ValidateChannelInvHold
           @c_HoldType           = @c_HoldType            
         , @c_Facility           = @c_Facility           
         , @c_Storerkey          = @c_Storerkey          
         , @c_Sku                = @c_Sku                
         , @c_Channel            = @c_Channel            
         , @c_C_Attribute01      = @c_C_Attribute01      
         , @c_C_Attribute02      = @c_C_Attribute02      
         , @c_C_Attribute03      = @c_C_Attribute03      
         , @c_C_Attribute04      = @c_C_Attribute04      
         , @c_C_Attribute05      = @c_C_Attribute05      
         , @n_Channel_ID         = @n_Channel_ID        
         , @c_Hold               = @c_Hold                
         , @c_Remarks            = @c_Remarks            
         , @b_Success            = @b_Success            OUTPUT  
         , @n_Err                = @n_Err                OUTPUT  
         , @c_ErrMsg             = @c_ErrMsg             OUTPUT  

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 559851
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Error Executing isp_ValidateChannelInvHold. (lsp_Validate_ChannelInvHold_Std)'
                       + '( ' + @c_ErrMsg + ' )'
         GOTO EXIT_SP
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() 
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0 
   END
   ELSE
   BEGIN
      SET @b_Success = 1   
   END
END -- Procedure

GO