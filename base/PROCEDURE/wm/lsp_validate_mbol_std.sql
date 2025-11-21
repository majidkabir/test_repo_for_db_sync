SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_MBOL_Std                                */  
/* Creation Date: 17-Jun-2019                                             */  
/* Copyright: LFL                                                         */  
/* Written by:                                                            */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 8.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch               */
/* 2023-03-14   NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_MBOL_Std] (
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
   
   --(mingle01) - START
   BEGIN TRY
      /*  --NJOW01 Removed    
      IF OBJECT_ID('tempdb..#MBOL') IS NOT NULL
      BEGIN
         DROP TABLE #MBOL
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
      CREATE TABLE #MBOL( Rowid  INT NOT NULL IDENTITY(1,1) ) 

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
         SET @c_SQL = N'ALTER TABLE #MBOL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #MBOL' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
                       
      END
      */

      DECLARE 
              @c_MBOLKey                        NVARCHAR(10) = ''
            , @c_StorerKey                      NVARCHAR(15) = ''
            , @c_Facility                       NVARCHAR(15) = ''          
            , @c_Vessel                         NVARCHAR(30) = ''
            , @c_Drivername                     NVARCHAR(30) = ''
            , @c_CarrierKey                     NVARCHAR(10) = ''
            , @c_Userdefine05                   NVARCHAR(20) = '' 
            , @c_Userdefine09                   NVARCHAR(10) = ''
            , @c_Userdefine10                   NVARCHAR(10) = ''
            , @c_ShipperAcctCode                NVARCHAR(15) = ''
            , @c_ShipToAcctCode                 NVARCHAR(15) = ''
            , @c_Status                         NVARCHAR(10) = ''
            , @dt_ArrivalDateFinalDestination   DATETIME 

            , @b_ValidCarrier                   INT          = 0      
            , @b_ValidShipper                   INT          = 0   
            , @b_ValidShipTo                    INT          = 0   
      -- StorerConfig 
      DECLARE 
            @c_MBOLDeliveryInfo                 NVARCHAR(1) = '0'
         ,  @c_CheckProFormABOL                 NVARCHAR(1) = '0'
            
      SELECT  
            @c_MBOLKey        = M.MBOLKey
         ,  @c_Vessel         = ISNULL(M.Vessel,'')
         ,  @c_Drivername     = ISNULL(M.Drivername,'')
         ,  @c_CarrierKey     = ISNULL(M.CarrierKey,'')
         ,  @c_Userdefine05   = ISNULL(M.Userdefine05,'')   
         ,  @c_Userdefine09   = ISNULL(M.Userdefine09,'')    
         ,  @c_Userdefine10   = ISNULL(M.Userdefine10,'')    
         ,  @c_ShipperAcctCode= ISNULL(M.ShipperAccountCode,'')
         ,  @c_ShipToAcctCode = ISNULL(M.ConsigneeAccountCode,'') 
         ,  @dt_ArrivalDateFinalDestination = M.ArrivalDateFinalDestination
         ,  @c_Status         = M.[Status]
      FROM  #VALDN M  --NJOW01          

      SELECT TOP 1 @c_Storerkey = OH.Storerkey
            , @c_Facility = OH.Orderkey
      FROM MBOLDETAIL MD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON MD.Orderkey = OH.Orderkey
      WHERE MD.MBOLKey = @c_MBOLKey

      IF @c_Storerkey = ''
      BEGIN
         GOTO EXIT_SP
      END

      SELECT @c_MBOLDeliveryInfo = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLDeliveryInfo')
      SELECT @c_CheckProFormABOL = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CheckProFormABOL')

      IF @c_MBOLDeliveryInfo = '1'
      BEGIN
         IF @c_Vessel = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556851
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Vehicle Number is required'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @c_Drivername = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556852
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Driver Name is required'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @dt_ArrivalDateFinalDestination IS NULL OR @dt_ArrivalDateFinalDestination = CONVERT(DATETIME, '1900-01-01')
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556853
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delivery Date is required'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END
      END

      IF @c_CheckProFormABOL = '1' AND @c_Status ='9'
      BEGIN
         IF @c_Userdefine05 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556854
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine05 is required PRODUCT SEAL'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @c_Userdefine09 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556855
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine09 is required for FORWARDER SEAL'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @c_Userdefine10 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556856
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine10 is required for Van'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         SELECT @b_ValidCarrier = ISNULL(SUM(CASE WHEN Storerkey = @c_CarrierKey THEN 1 ELSE 0 END),0)
               ,@b_ValidShipper = ISNULL(SUM(CASE WHEN Storerkey = @c_ShipperAcctCode THEN 1 ELSE 0 END),0)
               ,@b_ValidShipTo  = ISNULL(SUM(CASE WHEN Storerkey = @c_ShipToAcctCode THEN 1 ELSE 0 END),0)
         FROM STORER WITH (NOLOCK)
         WHERE Storerkey IN (@c_CarrierKey, @c_ShipperAcctCode, @c_ShipToAcctCode)

         IF @b_ValidCarrier = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556857
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': CarrierKey Must be Valid StorerKey'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @b_ValidShipper = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556858
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Shipper Must be Valid StorerKey'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END

         IF @b_ValidShipTo = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556859
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Ship To Must be Valid StorerKey'
                          + '. (lsp_Validate_MBOL_Std)'
            GOTO EXIT_SP
         END
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0 
   END
   
END -- Procedure

GO