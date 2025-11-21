SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/***************************************************************************/  
/* Stored Procedure: lsp_Validate_Receipt_Std                              */  
/* Creation Date: 24-Nov-2017                                              */  
/* Copyright: Maersk                                                       */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */  
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/* Version: 1.7                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */ 
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch                */
/* 2021-05-20  Wan01    1.2   LFWM-3505 Storerconfig:                      */
/*                            DisAllowDuplicateIdsOnWSRcpt SCE Enhancement */
/* 2022-09-19  Wan02    1.3   LFWM-3760 - PH - SCE Returns Validation Allow*/
/*                            Duplicate ID                                 */
/* 2022-10-13  Wan03    1.4   LFWM-3780 - PH Unilever                      */
/*                            DisAllowDuplicateIdsOnWSRcpt StorerCFG CR    */
/* 2023-03-14  NJOW01   1.5   LFWM-3608 performance tuning for XML Reading */
/* 2023-08-16  Wan04    1.6   LFWM-4417 - SCE PROD SG Receipt - Disallow   */
/*                            Duplicate Movable Unit ID Error When Save when*/
/*                            exists Receipt Reversed Detail               */
/* 2024-01-29  Wan05    1.7   UWP-14379-Implement pre-save ASN standard    */
/*                            validation check                             */
/***************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_Receipt_Std] (
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
      IF OBJECT_ID('tempdb..#RECEIPT') IS NOT NULL
      BEGIN
         DROP TABLE #RECEIPT
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

      --CREATE TABLE #RECEIPT( Rowid  INT NOT NULL IDENTITY(1,1) ) 
   /*  
	   --SET @c_XMLSchemaString = N'<Table> <Column ColName="RECEIPT.CarrierKey" DataType="NVARCHAR(15)" /><Column ColName="RECEIPT.CarrierName" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CarrierAddress1" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.CarrierAddress2" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.CarrierCity" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.CarrierState" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.CarrierZip" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.CarrierReference" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.WarehouseReference" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.OriginCountry" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.DestinationCountry" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.VehicleNumber" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.VehicleDate" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.PlaceOfLoading" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.PlaceOfDischarge" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.PlaceofDelivery" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.IncoTerms" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.TermsNote" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.ContainerKey" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.Signatory" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.PlaceofIssue" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.OpenQty" DataType="FLOAT" /><Column ColName="RECEIPT.Status" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.Notes" DataType="NVARCHAR(4000)" /><Column ColName="RECEIPT.ExternReceiptKey" DataType="NVARCHAR(20)" /><Column ColName="RECEIPT.ReceiptGroup" DataType="NVARCHAR(20)" /><Column ColName="RECEIPT.StorerKey" DataType="NVARCHAR(15)" /><Column ColName="RECEIPT.EffectiveDate" DataType="DATETIME" /><Column ColName="RECEIPT.ReceiptDate" DataType="DATETIME" /><Column ColName="RECEIPT.ContainerType" DataType="NVARCHAR(20)" /><Column ColName="RECEIPT.ContainerQty" DataType="FLOAT" /><Column ColName="RECEIPT.RECType" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.ASNStatus" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.ASNREASON" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.Appointment_No" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.Facility" DataType="NVARCHAR(15)" /><Column ColName="RECEIPT.LoadKey" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.xDockFlag" DataType="NVARCHAR(1)" /><Column ColName="RECEIPT.Processtype" DataType="NVARCHAR(1)" /><Column ColName="RECEIPT.MBOLKey" DataType="NVARCHAR(10)" /><Column ColName="RECEIPT.POKey" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.BilledContainerQty" DataType="FLOAT" /><Column ColName="RECEIPT.DocType" DataType="NVARCHAR(1)" /><Column ColName="RECEIPT.RoutingTool" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNTYPE1" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNTYPE2" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY2" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE3" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY3" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE4" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY4" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE5" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY5" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE6" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY6" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE7" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY7" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE8" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY8" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE9" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY9" DataType="FLOAT" /><Column ColName="RECEIPT.CTNTYPE10" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNQTY10" DataType="FLOAT" /><Column ColName="RECEIPT.NoOfPallet" DataType="FLOAT" /><Column ColName="RECEIPT.Weight" DataType="FLOAT" /><Column ColName="RECEIPT.WeightUnit" DataType="NVARCHAR(20)" /><Column ColName="RECEIPT.Cube" DataType="FLOAT" /><Column ColName="RECEIPT.CTNQTY1" DataType="FLOAT" /><Column ColName="RECEIPT.CubeUnit" DataType="NVARCHAR(20)" /><Column ColName="RECEIPT.UserDefine02" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine03" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine04" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine05" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine06" DataType="DATETIME" /><Column ColName="RECEIPT.UserDefine07" DataType="DATETIME" /><Column ColName="RECEIPT.UserDefine08" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine09" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine01" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.UserDefine10" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.NoOfTTLUnit" DataType="FLOAT" /><Column ColName="RECEIPT.PACKTYPE1" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE2" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE3" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE4" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE5" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE6" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE7" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE8" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.PACKTYPE9" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.NoOfMasterCtn" DataType="FLOAT" /><Column ColName="RECEIPT.PACKTYPE10" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.CTNCNT1" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT3" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT4" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT5" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT6" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT7" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT8" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT9" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT10" DataType="FLOAT" /><Column ColName="RECEIPT.CTNCNT2" DataType="FLOAT" /><Column ColName="RECEIPT.SellerName" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerCompany" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerAddress1" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerAddress3" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerAddress4" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerCity" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerState" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.SellerZip" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.SellerCountry" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.SellerContact1" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.SellerContact2" DataType="NVARCHAR(30)" /><Column ColName="RECEIPT.SellerPhone1" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.SellerPhone2" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.SellerEmail1" DataType="NVARCHAR(60)" /><Column ColName="RECEIPT.SellerEmail2" DataType="NVARCHAR(60)" /><Column ColName="RECEIPT.SellerFax1" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.SellerFax2" DataType="NVARCHAR(18)" /><Column ColName="RECEIPT.SellerAddress2" DataType="NVARCHAR(45)" /><Column ColName="RECEIPT.ReceiptKey" DataType="NVARCHAR(10)" /></Table>'

      --SET @c_XMLDataString = N'<Row RECEIPT.CarrierKey="" RECEIPT.CarrierName="" RECEIPT.CarrierAddress1="" RECEIPT.CarrierAddress2="" RECEIPT.CarrierCity="" RECEIPT.CarrierState="" RECEIPT.CarrierZip="" RECEIPT.CarrierReference="" RECEIPT.WarehouseReference="" RECEIPT.OriginCountry="" RECEIPT.DestinationCountry="" RECEIPT.VehicleNumber="" RECEIPT.VehicleDate="" RECEIPT.PlaceOfLoading="" RECEIPT.PlaceOfDischarge="" RECEIPT.PlaceofDelivery="" RECEIPT.IncoTerms="" RECEIPT.TermsNote="" RECEIPT.ContainerKey="" RECEIPT.Signatory="test2" RECEIPT.PlaceofIssue="" RECEIPT.OpenQty="120" RECEIPT.Status="0" RECEIPT.Notes="" RECEIPT.ExternReceiptKey="TESTETS111" RECEIPT.ReceiptGroup="" RECEIPT.StorerKey="JUNE" RECEIPT.EffectiveDate="2017-03-23 09:14:54" RECEIPT.ReceiptDate="2017-03-23 09:16:53" RECEIPT.ContainerType="" RECEIPT.ContainerQty="0" RECEIPT.RECType="TEST" RECEIPT.ASNStatus="0" RECEIPT.ASNREASON="" RECEIPT.Appointment_No="" RECEIPT.Facility="F1" RECEIPT.LoadKey="" RECEIPT.xDockFlag="0" RECEIPT.Processtype="" RECEIPT.MBOLKey="" RECEIPT.POKey="" RECEIPT.BilledContainerQty="0" RECEIPT.DocType="A" RECEIPT.RoutingTool="" RECEIPT.CTNTYPE1="" RECEIPT.CTNTYPE2="" RECEIPT.CTNQTY2="0" RECEIPT.CTNTYPE3="" RECEIPT.CTNQTY3="0" RECEIPT.CTNTYPE4="" RECEIPT.CTNQTY4="0" RECEIPT.CTNTYPE5="" RECEIPT.CTNQTY5="0" RECEIPT.CTNTYPE6="" RECEIPT.CTNQTY6="0" RECEIPT.CTNTYPE7="" RECEIPT.CTNQTY7="0" RECEIPT.CTNTYPE8="" RECEIPT.CTNQTY8="0" RECEIPT.CTNTYPE9="" RECEIPT.CTNQTY9="0" RECEIPT.CTNTYPE10="" RECEIPT.CTNQTY10="0" RECEIPT.NoOfPallet="0" RECEIPT.Weight="0" RECEIPT.WeightUnit="" RECEIPT.Cube="0" RECEIPT.CTNQTY1="0" RECEIPT.CubeUnit="" RECEIPT.UserDefine02="123466" RECEIPT.UserDefine03="55555552" RECEIPT.UserDefine04="" RECEIPT.UserDefine05="" RECEIPT.UserDefine06="1900-01-01 00:00:00" RECEIPT.UserDefine07="1900-01-01 00:00:00" RECEIPT.UserDefine08="" RECEIPT.UserDefine09="" RECEIPT.UserDefine01="ABC0001" RECEIPT.UserDefine10="" RECEIPT.NoOfTTLUnit="0" RECEIPT.PACKTYPE1="" RECEIPT.PACKTYPE2="" RECEIPT.PACKTYPE3="" RECEIPT.PACKTYPE4="" RECEIPT.PACKTYPE5="" RECEIPT.PACKTYPE6="" RECEIPT.PACKTYPE7="" RECEIPT.PACKTYPE8="" RECEIPT.PACKTYPE9="" RECEIPT.NoOfMasterCtn="0" RECEIPT.PACKTYPE10="" RECEIPT.CTNCNT1="0" RECEIPT.CTNCNT3="0" RECEIPT.CTNCNT4="0" RECEIPT.CTNCNT5="0" RECEIPT.CTNCNT6="0" RECEIPT.CTNCNT7="0" RECEIPT.CTNCNT8="0" RECEIPT.CTNCNT9="0" RECEIPT.CTNCNT10="0" RECEIPT.CTNCNT2="0" RECEIPT.SellerName="" RECEIPT.SellerCompany="" RECEIPT.SellerAddress1="" RECEIPT.SellerAddress3="" RECEIPT.SellerAddress4="" RECEIPT.SellerCity="" RECEIPT.SellerState="" RECEIPT.SellerZip="" RECEIPT.SellerCountry="" RECEIPT.SellerContact1="" RECEIPT.SellerContact2="" RECEIPT.SellerPhone1="" RECEIPT.SellerPhone2="" RECEIPT.SellerEmail1="" RECEIPT.SellerEmail2="" RECEIPT.SellerFax1="" RECEIPT.SellerFax2="" RECEIPT.SellerAddress2="" RECEIPT.ReceiptKey="0000017226" />'
   */

      /*
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
         SET @c_SQL = N'ALTER TABLE #RECEIPT  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #RECEIPT' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
                       
      END
      */

      DECLARE 
            @c_ReceiptKey           NVARCHAR(10) = '',
            @c_ASNStatus            NVARCHAR(10) = '',
            @c_StorerKey            NVARCHAR(15) = '',
            @c_Facility             NVARCHAR(15) = '',          
            @n_QtyReceived          INT = 0,  
            @c_DocType              NVARCHAR(1)  = '',
            @c_RecType              NVARCHAR(10) = '',
            @c_ExternReceiptKey     NVARCHAR(20) = '',
            @c_WarehouseReference   NVARCHAR(18) = '', 
            @c_ASNReason            NVARCHAR(10) = '',
            @c_CarrierKey           NVARCHAR(15) = '',
            @b_ValidID              INT          = 0                       --(Wan03)
         ,  @c_ASNStatus_From       NVARCHAR(10) = ''                      --(Wan05)
         ,  @n_Cnt                  INT          = 0                       --(Wan05)
 
      -- StorerConfig 
      DECLARE 
            @c_RCPTRQD                       NVARCHAR(1) = '0'
         ,  @c_OWITF                         NVARCHAR(1) = '0'
         ,  @c_DisAllowDuplicateIdsOnWSRcpt  NVARCHAR(30)= '0'             --(Wan01)
         ,  @c_DisAllowDupIDsOnWSRcpt_Option5 NVARCHAR(1000) = ''          --(Wan02)
         ,  @c_UniqueIDSkipDocType           NVARCHAR(30) = ''             --(Wan02) 
         ,  @c_AllowDupWithinPLTCnt          NVARCHAR(30) = 'N'            --(Wan03)                                                                   
            
      SELECT  
            @c_ReceiptKey = R.ReceiptKey
         ,  @c_ASNStatus = R.ASNStatus
         ,  @c_StorerKey = R.StorerKey 
         ,  @c_Facility  = R.Facility
         ,  @c_DocType   = R.DOCTYPE 
         ,  @c_RecType   = R.RECType
         ,  @c_ExternReceiptKey = R.ExternReceiptKey
         ,  @c_WarehouseReference = R.WarehouseReference
         ,  @c_ASNReason = R.ASNReason
         ,  @c_CarrierKey = R.CarrierKey
      FROM  #VALDN R  --NJOW01          

      IF @n_Continue IN (1,2)
      BEGIN
         IF ISNULL(RTRIM(@c_Facility),'') = ''
         BEGIN
            SET @n_Err = 551901
            SET @c_ErrMsg = 'Facility Required. (lsp_Validate_Receipt_Std)'
            SET @n_Continue = 3 
            GOTO EXIT_SP         
         END
      END 
 
      IF @n_Continue IN (1,2)                                                       --(Wan05)-START
      BEGIN
         SELECT @c_ASNStatus_From = r.ASNStatus
         FROM dbo.Receipt r(NOLOCK)
         WHERE r.ReceiptKey = @c_Receiptkey

         IF @c_ASNStatus_From <> @c_ASNStatus
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.fnc_GetAllowASNStatusChg(@c_Facility, @c_Storerkey, @c_Doctype, @c_Receiptkey, @c_ASNStatus_From, @c_ASNStatus) AASC
                       WHERE AASC.AllowChange = 0
                     )
            BEGIN
               SET @n_Continue = 3
               SET @n_err= 551909
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ASNStatus from ''' 
                              + @c_ASNStatus_From + ''' to ''' + @c_ASNStatus + ''''
                              +'. (lsp_Validate_Receipt_Std) |' + @c_ASNStatus_From + '|' + @c_ASNStatus        
            END  
         END      
      END                                                                           --(Wan05)-END
      --IF @n_Continue IN (1,2)
      --BEGIN
      --   EXEC nspGetRight
      --    @c_Facility = '',
      --    @c_StorerKey = @c_StorerKey,
      --    @c_sku = '',
      --    @c_ConfigKey = 'OWITF',
      --    @b_Success   = @b_Success OUTPUT,
      --    @c_authority = @c_OWITF OUTPUT,
      --    @n_err = @n_Err,
      --    @c_errmsg = @c_ErrMsg
         
      -- -- Copy From ue_asnstatus_rule 
      --   IF @c_OWITF = '1'
      --   BEGIN
      --    IF @c_ASNStatus IN ('9','CLOSED')
      --    BEGIN
      --       SET @n_QtyReceived = 0 
               
      --       SELECT SUM(R.QtyReceived) 
      --       FROM RECEIPTDETAIL AS r WITH(NOLOCK)
      --       WHERE r.ReceiptKey = @c_ReceiptKey 
      --       --AND r.FinalizeFlag = 'Y'
               
      --       IF @n_QtyReceived = 0 
      --       BEGIN
      --          SET @n_Err = 551902
      --          SET @c_ErrMsg = 'Not Allow to CLOSE before Finalized the Receipt'
      --          SET @n_Continue = 3 
      --          GOTO EXIT_SP 
      --       END 
      --    END  -- IF @c_ASNStatus IN ('9','CLOSED')       
      --   END -- IF @c_OWITF = '1'          
      --END-- IF @n_Continue IN (1,2)

      IF @n_Continue IN (1,2)
      BEGIN
         EXEC nspGetRight
            @c_Facility = '',
            @c_StorerKey = @c_StorerKey,
            @c_sku = '',
            @c_ConfigKey = 'RCPTRQD',
            @b_Success   = @b_Success OUTPUT,
            @c_authority = @c_RCPTRQD OUTPUT,
            @n_err = @n_Err,
            @c_errmsg = @c_ErrMsg      
            
         IF @c_RCPTRQD = '1'
         BEGIN
            IF ISNULL(RTRIM(@c_WarehouseReference),'') = '' OR ISNUMERIC(@c_WarehouseReference) <> 1
            BEGIN
               SET @n_Err = 551903
               SET @c_ErrMsg = 'Invalid Principal Doc # (Warehouse Reference). (lsp_Validate_Receipt_Std)'
               SET @n_Continue = 3 
               GOTO EXIT_SP            
            END
            
            IF ISNULL(RTRIM(@c_ASNReason),'') = ''
            BEGIN
               SET @n_Err = 551904
               SET @c_ErrMsg = 'Receipt Reason Required. (lsp_Validate_Receipt_Std)'
               SET @n_Continue = 3 
               GOTO EXIT_SP                     
            END
         END
      END 
      IF @n_Continue IN (1,2)
      BEGIN   
         DECLARE @c_ASN_CarrierKey_Required NVARCHAR(1) = '0'
               
         EXEC nspGetRight
            @c_Facility = '',
            @c_StorerKey = @c_StorerKey,
            @c_sku = '',
            @c_ConfigKey = 'ASN_CarrierKey_Required. (lsp_Validate_Receipt_Std)',
            @b_Success   = @b_Success OUTPUT,
            @c_authority = @c_ASN_CarrierKey_Required OUTPUT,
            @n_err = @n_Err,
            @c_errmsg = @c_ErrMsg  
                  
         IF @c_ASN_CarrierKey_Required = '1'
         BEGIN
            IF ISNULL(RTRIM(@c_CarrierKey),'') = ''  
            BEGIN
               SET @n_Err = 551905
               SET @c_ErrMsg = 'Carrierkey Required. (lsp_Validate_Receipt_Std) '
               SET @n_Continue = 3 
               GOTO EXIT_SP            
            END
         END            
      END
    
      IF @n_Continue IN (1,2)
      BEGIN   
         DECLARE @c_ASNUniqueLottableValue NVARCHAR(1) = '0',
                 @n_LottableCount          INT = 0 
               
         EXEC nspGetRight
            @c_Facility = '',
            @c_StorerKey = @c_StorerKey,
            @c_sku = '',
            @c_ConfigKey = 'ASNUniqueLottableValue',
            @b_Success   = @b_Success OUTPUT,
            @c_authority = @c_ASNUniqueLottableValue OUTPUT,
            @n_err = @n_Err,
            @c_errmsg = @c_ErrMsg  
                  
         IF @c_ASNUniqueLottableValue = '1' AND @c_DocType='A'
         BEGIN
            SET @n_LottableCount = 0
            
            SELECT @n_LottableCount = COUNT(*) FROM (
                  SELECT r.Lottable01, r.Lottable02, r.Lottable03
                  FROM RECEIPTDETAIL AS r WITH(NOLOCK)
                  WHERE r.ReceiptKey = @c_ReceiptKey 
                  GROUP BY r.Lottable01, r.Lottable02, r.Lottable03) Lottables
                  
            IF @n_LottableCount > 1       
            BEGIN
               SET @n_Err = 551906
               SET @c_ErrMsg = 'Lottable01, Lottable02 and Lottable03 Should be Unique. (lsp_Validate_Receipt_Std)'
               SET @n_Continue = 3 
               GOTO EXIT_SP            
            END
         END            
      END
      --(Wan01) - START
      IF @n_Continue IN ( 1, 2 )
      BEGIN
         --(Wan02) - START
         SELECT @c_DisAllowDuplicateIdsOnWSRcpt = fgr.Authority
               ,@c_DisAllowDupIDsOnWSRcpt_Option5 = fgr.Option5
         FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'DisAllowDuplicateIdsOnWSRcpt') AS fgr      
      
         SELECT @c_UniqueIDSkipDocType = dbo.fnc_GetParamValueFromString('@c_UniqueIDSkipDocType', @c_DisAllowDupIDsOnWSRcpt_Option5, @c_UniqueIDSkipDocType)
         IF @c_DisAllowDuplicateIdsOnWSRcpt = '1' AND CHARINDEX(@c_DocType, @c_UniqueIDSkipDocType, 1) > 0
         BEGIN 
            SET @c_DisAllowDuplicateIdsOnWSRcpt = '0'
         END
         --(Wan02) - END

         IF @c_DisAllowDuplicateIdsOnWSRcpt = '1'
         BEGIN
            --(Wan03) - START
            SET @c_AllowDupWithinPLTCnt = 'N'
            SELECT @c_AllowDupWithinPLTCnt = dbo.fnc_GetParamValueFromString('@c_AllowDupWithinPLTCnt', @c_DisAllowDupIDsOnWSRcpt_Option5, @c_AllowDupWithinPLTCnt)
            --(Wan03) - END
            
            IF @c_AllowDupWithinPLTCnt = 'N'             --(Wan03) 
            BEGIN
               IF EXISTS ( SELECT TOP 1 1 FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK) 
                           --JOIN dbo.ID AS i WITH (NOLOCK) ON i.ID = r.ToID                 --(Wan04)
                           JOIN dbo.LOTxLOCxID AS ltlci WITH (NOLOCK) ON ltlci.ID = r.ToID   --(Wan04)
                                                                     AND ltlci.Storerkey = r.Storerkey
                           WHERE r.ReceiptKey = @c_ReceiptKey
                           AND r.ToID <> ''
                           AND r.FinalizeFlag = 'N'      --2022-10-13 checked for not finalized record
                           AND r.BeforeReceivedQty > 0                                       --(Wan04)
                           AND ltlci.Qty + ltlci.PendingMoveIN > 0                           --(Wan04)
                           UNION
                           SELECT TOP 1 1 FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK) 
                           JOIN dbo.RECEIPTDETAIL AS r2 WITH (NOLOCK) ON r2.Storerkey = r.Storerkey AND r2.ToId = r.ToId
                           WHERE r.ReceiptKey = @c_ReceiptKey
                           AND r.ToID <> ''
                           AND r.FinalizeFlag = 'N'      --2022-10-13 checked for not finalized record
                           AND r.BeforeReceivedQty > 0   --(Wan04)
                           AND r2.FinalizeFlag = 'N'
                           AND r2.ToID <> ''  
                           AND r2.BeforeReceivedQty > 0  --(Wan04)                      
                           GROUP BY r.ToID
                           HAVING COUNT(1) > 1
                         )
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 551907
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow duplicate Movable Unit Id. (lsp_Validate_Receipt_Std)'
                  GOTO EXIT_SP
               END
            END                                          --(Wan03) - START
            ELSE
            BEGIN
               SET @b_ValidID = 1
               SELECT TOP 1 @b_ValidID = 0
               FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
               WHERE r.ReceiptKey = @c_ReceiptKey
               AND r.ToID <> ''
               AND r.FinalizeFlag = 'N'
               AND r.BeforeReceivedQty > 0                                          --(Wan04)
               AND EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL AS r2 WITH (NOLOCK)
                           WHERE r2.ReceiptKey <> @c_ReceiptKey
                           AND   r2.ToId = r.ToId
                           AND   r2.Storerkey = r.Storerkey                         --2023-10-04
                           AND   r2.BeforeReceivedQty > 0                           --(Wan04)
                           )
                           
               IF @b_ValidID = 1
               BEGIN
                  SELECT TOP 1 @b_ValidID = IIF(COUNT(DISTINCT r.Sku) > 1 OR SUM(r.BeforeReceivedQty) > MIN(p.Pallet), 0, 1)
                  FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
                  JOIN dbo.SKU AS s WITH (NOLOCK) ON s.StorerKey = r.StorerKey AND s.Sku = r.Sku
                  JOIN dbo.PACK AS p WITH (NOLOCK) ON s.PackKey = p.PackKey
                  WHERE r.ReceiptKey = @c_ReceiptKey
                  AND r.ToID <> ''
                  AND r.BeforeReceivedQty > 0                                       --(Wan04)
                  GROUP BY r.ToId 
                  ORDER BY IIF(COUNT(DISTINCT r.Sku) > 1 OR SUM(r.BeforeReceivedQty) > MIN(p.Pallet), 0, 1)
               END 
               
               IF @b_ValidID = 1
               BEGIN
                  -- Last & Further check if the Received ID is archived with inventory 
                  SELECT TOP 1 @b_ValidID = 0
                  FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
                  WHERE r.ReceiptKey = @c_ReceiptKey
                  AND r.ToID <> ''
                  AND r.BeforeReceivedQty > 0                                       --(Wan04)
                  AND EXISTS (SELECT 1 FROM dbo.LOTxLOCxID AS ltlci WITH (NOLOCK)
                              WHERE ltlci.ID = r.ToId
                              AND ltlci.Storerkey = r.Storerkey                     --2023-10-04
                              AND ltlci.Qty + ltlci.PendingMoveIN > 0               --(Wan04) 
                              )    
                  GROUP BY r.ToId                                                                          
                  HAVING MAX(r.FinalizeFlag) = 'N'                                        
               END        
                          
               IF @b_ValidID = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 551908
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Diallow duplicate Movable Unit Id with qty more than Pallet Count'
                                + '. (lsp_Validate_Receipt_Std)'
                  GOTO EXIT_SP
               END
            END                                             
         END                                             --(Wan03) - END
      END
      --(Wan01) - END
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