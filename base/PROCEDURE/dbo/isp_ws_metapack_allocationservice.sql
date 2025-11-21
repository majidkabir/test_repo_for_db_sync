SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_WS_Metapack_AllocationService                                */
/* Creation Date: 07 Aug 2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send Allocation Service web service request to Metapack     */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: rdt.rdtfnc_Ecomm_Dispatch                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* RDT message range: 91401 - 91450                                     */  
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/* 07-08-2014   Chee     1.0      Initial Version SOS#317664            */
/* 28-08-2014   James    1.1      Return metapack error (james01)       */
/* 29-08-2014   Chee     1.2      Update CarrierConsignmentCode to      */
/*                                PackDetail.RefNo, ConsignmentCode to  */
/*                                PackDetail.RefNo2 (Chee01)            */
/* 01-09-2014   James    1.3      Populate '.' when addr1, 2, 3 & city  */
/*                                is blank (james02)                    */
/* 05-09-2014   James    1.4      Only call metapack for sku which has  */
/*                                been packed only (james03)            */
/* 14-10-2014   Chee     1.5      SOS#322547 (Chee02)                   */
/* 4-12-2014    TLTING   1.6      Performance Tune                      */  
/* 27-11-2014   ChewKP   1.7      SOS#326418 (ChewKP01)                 */
/* 15-12-2014   James    1.8      Remove filter by pickslipno when get  */
/*                                info from pickdetail (james04)        */
/* 18-12-2014   James    1.9      SOS328265 - Change metapack mappings  */
/*                                1. consignmentValue (james05)         */
/*                                2. orderValue                         */
/*                                3. unitProductWeight                  */
/* 26-12-2014   James    2.0      Extend unitProductWeight (james06)    */  
/* 16-02-2015   James    2.1      SOS333460-Search static data (james07)*/
/* 13-03-2015   James    2.2      SOS335590 - Fix for orderdetail line  */
/*                                having same sku but send only 1 line  */
/*                                to metapack (james08)                 */
/* 29-06-2015   James    2.3      Remove reference to Archive (james09) */
/* 13-07-2015   James    2.4      Remove all validation BUT keep the    */
/*                                "search and populate" from datamart   */
/*                                (james10)                             */
/* 15-03-2016   KHChan   2.5      SOS#366012 (KH01)                     */
/* 12-04-2016   KHChan   2.6      SOS#368470 (KH02)                     */
/* 20-Jul-2016	KTLow	   2.7		  Add WebService Client Parameter (KT01)*/
/* 11-Oct-2016  NJOW01   2.8      WMS-495 Change line2 mapping from     */
/*                                c_city to c_state if c_country = 'US' */
/*                                empty phone change from '.' to '0'    */
/* 28-Jan-2019  TLTING_ext 2.9  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_WS_Metapack_AllocationService](
    @nMobile           INT
   ,@cPickSlipNo       NVARCHAR(10)  
   ,@nCartonNo         INT  
   ,@cLabelNo          NVARCHAR(20)
   ,@cDocumentFilePath NVARCHAR(1000) OUTPUT
   ,@bSuccess          INT            OUTPUT  
   ,@nErr              INT            OUTPUT  
   ,@cErrMsg           NVARCHAR(215)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF


   DECLARE
      @cIniFilePath             NVARCHAR(100),
      @cWebRequestURL           NVARCHAR(1000),
      @cWebRequestMethod        NVARCHAR(10),
      @cContentType             NVARCHAR(100),
      @cWebRequestEncoding      NVARCHAR(30),
      @cXMLEncodingString       NVARCHAR(100),
      @cXMLNamespace            NVARCHAR(500),
      @cRequestString           NVARCHAR(MAX),
      @cResponseString          NVARCHAR(MAX),
      @cVBErrMsg                NVARCHAR(MAX),
      @xRequestString           XML,
      @xResponseString          XML,
      @dTimeIn                  DATETIME,
      @dTimeOut                 DATETIME,
      @nTotalTime               INT,
      @cStatus                  NVARCHAR(1),
      @cBatchNo                 NVARCHAR(10),
      @nDebug                   INT,
      @nSeqNo                   INT,
      @ndoc                     INT,
      @nTrancount               INT,
      @cMetapackNetworkUserName NVARCHAR(100),
      @cMetapackNetworkPassword NVARCHAR(100)

   DECLARE
      @cWSClientContingency   NVARCHAR(1),   
      @cConnectionString      NVARCHAR(250),
      @cStorerKey             NVARCHAR(15),
      @cWebServiceLogDBName   NVARCHAR(30),
      @cExecStatements        NVARCHAR(4000),
      @cExecArguments         NVARCHAR(4000)

   DECLARE 
      @cOrderKey             NVARCHAR(10),
      @cOrdersUserDefine02   NVARCHAR(20),
      @cOrdersUserDefine03   NVARCHAR(20),
      @cOrdersNotes          NVARCHAR(4000),
      @cOrdersNotes2         NVARCHAR(4000),
      @cExternOrderKey       NVARCHAR(50),  --tlting_ext
      @cRecipientCountry     NVARCHAR(30),
      @cRecipientAddress1    NVARCHAR(45),
      @cRecipientAddress2    NVARCHAR(45),
      @cRecipientAddress3    NVARCHAR(45),
      @cRecipientCity        NVARCHAR(45),
      @cRecipientState       NVARCHAR(45), --NJOW01
      @cRecipientZip         NVARCHAR(18),
      @cRecipientPhone1      NVARCHAR(18),
      @cRecipientPhone2      NVARCHAR(18),
      @cRecipientContact1    NVARCHAR(30),
      @cRecipientVat         NVARCHAR(18),
      @cIncoterm             NVARCHAR(10),
      @cIncotermDescr        NVARCHAR(50), -- (ChewKP01) 
      @nDayFactor            INT,          -- (ChewKP01) 
      @dDeliveryDate         DATETIME,     -- (ChewKP01) 
      @cDay                  NVARCHAR(10)  -- (ChewKP01) 

   DECLARE
      @nConsignmentValue      FLOAT, 
      @nOD_UnitPrice          FLOAT, 
      @nPD_Qty                INT, 
      @cPD_SKU                NVARCHAR( 20) 
      
      

   DECLARE @tProduct TABLE (
      productCode            NVARCHAR(20),
      productDescription     NVARCHAR(60),
      harmonisedProductCode  NVARCHAR(30),
      productQuantity        FLOAT,
      totalProductValue      FLOAT,
      unitProductWeight      FLOAT,
      countryOfOrigin        NVARCHAR(18),
      fabricContent          NVARCHAR(30),
      productTypeDescription NVARCHAR(30), 
      productLine            NVARCHAR(5)  -- (james08)
   )

   DECLARE @tCMDError TABLE(
      ErrMsg NVARCHAR(250)
   )

   DECLARE
      @cConsignmentCode        NVARCHAR(20),
      @cCarrierName            NVARCHAR(10),
      @cDocuments              NVARCHAR(MAX),
      @cLabels                 NVARCHAR(MAX),
      @cPrinterName            NVARCHAR(10),
      @cWorkingFilePath        NVARCHAR(250),
      @cFileName               NVARCHAR(100),
      @cPrintFilePath          NVARCHAR(250),
      @cCMD                    NVARCHAR(1000),
      @nReturnCode             INT,
      @cCarrierConsignmentCode NVARCHAR(20)  -- (Chee01)

   DECLARE @cMetaPackErr      NVARCHAR( 10), 
           @cMetaPackErrMsg   NVARCHAR( 100), 
           @cProduct_SKU      NVARCHAR( 20), 
           @cfabricContent    NVARCHAR( 30), 
           @cproductTypeDescription NVARCHAR( 30), 
           @ccountryOfOrigin  NVARCHAR( 18) 
           
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   CREATE TABLE #StoreSeqNoTempTable(SeqNo INT) 

   SET @nDebug      = 0

   SET @bSuccess    = 1
   SET @nErr        = 0
   SET @cErrmsg     = ''

   SET @cStatus               = '9'
   SET @cBatchNo              = ''
   SET @cDocumentFilePath     = ''

   SET @cWebRequestMethod    = 'POST'
   SET @cContentType         = 'application/xml' 
   SET @cWebRequestEncoding  = 'UTF-8'
   SET @cXMLEncodingString   = '<?xml version="1.0" encoding="UTF-8"?>'
   SET @cXMLNamespace = '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="urn:DeliveryManager/services" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="urn:DeliveryManager/services" xmlns:ns2="urn:DeliveryManager/types"/>'

   SELECT @cPrinterName = Printer
   FROM rdt.rdtmobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get WebService_Log DB Name
   SELECT @cWebServiceLogDBName = NSQLValue  
   FROM dbo.NSQLConfig WITH (NOLOCK)  
   WHERE ConfigKey = 'WebServiceLogDBName' 

   IF ISNULL(@cWebServiceLogDBName, '') = ''
   BEGIN
      SET @bSuccess = 0  
      SET @nErr = 91401
      SET @cErrmsg = 'NSQLConfig - WebServiceLogDBName is empty. (isp_WS_Metapack_AllocationService)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit 
   END

   -- Get WSConfig.ini File Path from CODELKUP
   SELECT @cIniFilePath = RTRIM(Long)
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'WebService'
     AND Code = 'FilePath'

   IF ISNULL(@cIniFilePath,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 91402
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp_WS_Metapack_AllocationService)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF NOT EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                 WHERE PickSlipNo = @cPickSlipNo
                   AND CartonNo = @nCartonNo 
                   AND LabelNo = @cLabelNo)
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 91414
      SET @cErrmsg = 'Invalid LabelNo. (isp_WS_Metapack_AllocationService)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   SELECT @cConsignmentCode = RefNo2 --RefNo -- (Chee01)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo 
     AND CartonNo = @nCartonNo 
     AND LabelNo = @cLabelNo

   -- IF EXISTS ConsignmentCode in WMS, Send ConsignmentService XML to retrieve pdf only, Else send AllocService XML
   SELECT 
      @cWebRequestURL = RTRIM(Long),
      @cMetapackNetworkUserName = RTRIM(UDF01),
      @cMetapackNetworkPassword = RTRIM(UDF02)
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'WebService'
     AND Code = CASE WHEN ISNULL(@cConsignmentCode, '') IN ('', '0')
                     THEN 'MetapackAllocServURL'  
                     ELSE 'MetapackConsigServURL'  
                END  

   IF ISNULL(@cWebRequestURL,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 91403
      SET @cErrmsg = 'Web Service Request URL is empty. (isp_WS_Metapack_AllocationService)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @nDebug = 1
   BEGIN
      SELECT @cWebServiceLogDBName AS 'Table WebService_Log DB Name',
             @cIniFilePath AS 'WSConfig.ini File Path',
             @cWebRequestURL AS 'Web Service Request URL'
   END

   -- IF EXISTS ConsignmentCode in WMS, Send ConsignmentService XML to retrieve pdf only, Else send AllocService XML
   IF ISNULL(@cConsignmentCode, '') IN ('', '0')
   BEGIN
      SELECT @cOrderKey = RTRIM(OrderKey)
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      SELECT 
         @cStorerKey            = RTRIM(ISNULL(StorerKey,'')),
         @cOrdersUserDefine02   = RTRIM(ISNULL(UserDefine02,'')),
         @cOrdersUserDefine03   = RTRIM(ISNULL(UserDefine03,'')),
         @cOrdersNotes          = RTRIM(ISNULL(Notes,'')),
         @cOrdersNotes2         = RTRIM(ISNULL(Notes2,'')),
         @cExternOrderKey       = RTRIM(ISNULL(ExternOrderKey,'')),
         @cRecipientCountry     = RTRIM(ISNULL(C_Country,'')),
         @cRecipientAddress1    = RTRIM(ISNULL(C_Address1,'')),
         @cRecipientAddress2    = RTRIM(ISNULL(C_Address2,'')),
         @cRecipientAddress3    = RTRIM(ISNULL(C_Address3,'')),
         @cRecipientCity        = RTRIM(ISNULL(C_City,'')),
         @cRecipientZip         = RTRIM(ISNULL(C_Zip,'')),
         --@cRecipientPhone1      = RTRIM(ISNULL(C_Phone2,'')), --(KH01)
         @cRecipientPhone1      = RTRIM(ISNULL(C_Phone1,'')), --(KH01)
         @cRecipientPhone2      = RTRIM(ISNULL(C_Phone2,'')),
         @cRecipientContact1    = RTRIM(ISNULL(C_Contact1,'')),
         @cRecipientVat         = RTRIM(ISNULL(C_Vat,'')),
         @cIncoterm             = RTRIM(ISNULL(Incoterm,'')),
         @dDeliveryDate         = DeliveryDate, -- (ChewKP01) 
         @cRecipientState       = RTRIM(ISNULL(C_State,'')) --NJOW01         
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SET @nConsignmentValue = 0
      -- Get total value for this carton
      DECLARE CUR_VALUE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT SKU, ISNULL( SUM( QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
      AND   CartonNo = @nCartonNo 
      AND   LabelNo = @cLabelNo
      GROUP BY SKU
      OPEN CUR_VALUE
      FETCH NEXT FROM CUR_VALUE INTO @cPD_SKU, @nPD_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @nOD_UnitPrice = ISNULL( UnitPrice, 0)
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   SKU = @cPD_SKU

         SET @nConsignmentValue = @nConsignmentValue + ( @nPD_Qty * @nOD_UnitPrice)
         FETCH NEXT FROM CUR_VALUE INTO @cPD_SKU, @nPD_Qty
      END
      CLOSE CUR_VALUE
      DEALLOCATE CUR_VALUE
 
      -- james02
      IF LEN( RTRIM( @cRecipientAddress1)) < 3  
      BEGIN  
         SET @cRecipientAddress1 = RTRIM( @cRecipientAddress1) +   
            CASE WHEN RTRIM( ISNULL( @cRecipientAddress1,'')) = '' THEN '...'   
                 WHEN LEN( RTRIM( ISNULL( @cRecipientAddress1,''))) = 1 THEN '..'   
                 WHEN LEN( RTRIM( ISNULL( @cRecipientAddress1,''))) = 2 THEN '.'   
            ELSE '' END   
      END  
  
      IF LEN( RTRIM(@cRecipientAddress2)) < 3  
      BEGIN  
         SET @cRecipientAddress2 = RTRIM( @cRecipientAddress2) +   
            CASE WHEN RTRIM( ISNULL( @cRecipientAddress2,'')) = '' THEN '...'   
                 WHEN LEN( RTRIM(ISNULL( @cRecipientAddress2,''))) = 1 THEN '..'   
                 WHEN LEN( RTRIM(ISNULL( @cRecipientAddress2,''))) = 2 THEN '.'   
            ELSE '' END   
      END  
  
      IF LEN( RTRIM( @cRecipientAddress3)) < 3  
      BEGIN  
         SET @cRecipientAddress3 = RTRIM( @cRecipientAddress3) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientAddress3,'')) = '' THEN '...'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientAddress3,''))) = 1 THEN '..'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientAddress3,''))) = 2 THEN '.'   
            ELSE '' END   
      END  
  
      IF LEN( RTRIM(@cRecipientCity)) < 3  
      BEGIN  
         SET @cRecipientCity = RTRIM( @cRecipientCity) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientCity,'')) = '' THEN '...'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientCity,''))) = 1 THEN '..'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientCity,''))) = 2 THEN '.'   
            ELSE '' END   
      END  
  
      --NJOW01
      IF LEN( RTRIM(@cRecipientState)) < 3  
      BEGIN  
         SET @cRecipientState = RTRIM( @cRecipientState) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientState,'')) = '' THEN '...'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientState,''))) = 1 THEN '..'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientState,''))) = 2 THEN '.'   
            ELSE '' END   
      END  

      IF LEN( RTRIM(@cRecipientPhone1)) < 3  
      BEGIN  
         SET @cRecipientPhone1 = RTRIM( @cRecipientPhone1) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientPhone1,'')) = '' THEN '000' --NJOW01  
                 WHEN LEN(RTRIM(ISNULL( @cRecipientPhone1,''))) = 1 THEN '00' --NJOW01  
                 WHEN LEN(RTRIM(ISNULL( @cRecipientPhone1,''))) = 2 THEN '0' --NJOW01   
            ELSE '' END   
      END  
  
      IF LEN( RTRIM(@cRecipientPhone2)) < 3  
      BEGIN  
         SET @cRecipientPhone2 = RTRIM( @cRecipientPhone2) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientPhone2,'')) = '' THEN '000' --NJOW01   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientPhone2,''))) = 1 THEN '00' --NJOW01  
                 WHEN LEN(RTRIM(ISNULL( @cRecipientPhone2,''))) = 2 THEN '0' --NJOW01
            ELSE '' END   
      END  
  
      IF LEN( RTRIM(@cRecipientContact1)) < 3  
      BEGIN  
         SET @cRecipientContact1 = RTRIM( @cRecipientContact1) +   
            CASE WHEN RTRIM(ISNULL( @cRecipientContact1,'')) = '' THEN '...'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientContact1,''))) = 1 THEN '..'   
                 WHEN LEN(RTRIM(ISNULL( @cRecipientContact1,''))) = 2 THEN '.'   
            ELSE '' END   
      END

      IF EXISTS(SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'INCOTERMS' AND CODE = @cIncoterm)
      BEGIN
         SELECT @cIncotermDescr = Short
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE LISTNAME = 'INCOTERMS' 
         AND CODE = @cIncoterm

         IF @cIncoterm = '20'
         BEGIN
            SELECT @cDay = DateName(dw,@dDeliveryDate) 

            SELECT @nDayFactor = Short 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'DayFactor' 
            AND CODE = @cDay

            SET @cIncotermDescr = @cIncotermDescr + '/'  + 
                                  CONVERT( NVARCHAR(10) , ( @dDeliveryDate - @nDayFactor ),120   )  + '/' +
                                  '*-*' + '/' +
                                  CONVERT (NVARCHAR(10),  @dDeliveryDate , 120  )  + '/' + 
                                  '*-23:59'
         END  
      END
      
      IF @cRecipientCountry <> '' AND 
         EXISTS(SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'INCOTERMS' AND UDF02 = @cRecipientCountry AND ISNULL(Short, '') <> '')
         SELECT @cRecipientCountry = RTRIM(Short)
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE LISTNAME = 'ISOCOUNTRY' 
           AND UDF02 = @cRecipientCountry 
           AND ISNULL(Short, '') <> ''

      INSERT INTO @tProduct (productCode, productDescription, harmonisedProductCode, productQuantity, totalProductValue, unitProductWeight,
                             countryOfOrigin, fabricContent, productTypeDescription, productLine)
      SELECT RTRIM(OD.SKU), RTRIM(SKU.Descr), RTRIM(ISNULL(SKU.BUSR4,'')), SUM(OD.QtyPicked + OD.ShippedQty), ISNULL(OD.UnitPrice, 0), 
             CASE WHEN ISNULL(SKU.StdGrossWgt, 0) <= 0 THEN 0.01 ELSE SKU.StdGrossWgt END,
             RTRIM(ISNULL(RD.Vesselkey, '')), RTRIM(ISNULL(RD.UserDefine02, '')), RTRIM(ISNULL(RD.UserDefine04, '')), 
             OD.OrderLineNumber     -- (james08)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON PD.Lot = LA.Lot
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
      LEFT JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = LEFT(LA.Lottable02, 10) AND RD.ReceiptLineNumber = RIGHT(LA.Lottable02, 5)   
      WHERE PD.OrderKey = @cOrderKey     -- (james04)
        AND PD.Status >= '5'     -- (james03)  
      GROUP BY RTRIM(OD.SKU), RTRIM(SKU.Descr), RTRIM(ISNULL(SKU.BUSR4,'')), ISNULL(OD.UnitPrice, 0), --ISNULL(SKU.StdGrossWgt, 0),
               CASE WHEN ISNULL(SKU.StdGrossWgt, 0) <= 0 THEN 0.01 ELSE SKU.StdGrossWgt END,
               RTRIM(ISNULL(RD.Vesselkey, '')), RTRIM(ISNULL(RD.UserDefine02, '')), RTRIM(ISNULL(RD.UserDefine04, '')), 
               OD.OrderLineNumber     -- (james08)

      -- (james07)
      -- Sometime if the value cannot be found in production db  
      -- (due to data lost or cycle count) then just get the 1st occurence in 
      -- the receiptdetail based on sku.
      DECLARE cur_Product CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT productCode
      FROM @tProduct
      WHERE (ISNULL( fabricContent, '') = '' OR 
             ISNULL( productTypeDescription, '') = '' OR 
             ISNULL( countryOfOrigin, '') = '') 
      OPEN cur_Product
      FETCH NEXT FROM cur_Product INTO @cProduct_SKU 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT TOP 1 @cfabricContent = UserDefine02 
         FROM DATAMART.ODS.ReceiptDetail WITH (NOLOCK)          
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cProduct_SKU
         AND   ISNULL( UserDefine02, '') <> '' 
         ORDER BY EDITDATE DESC

         SELECT TOP 1 @cproductTypeDescription = UserDefine04 
         FROM DATAMART.ODS.ReceiptDetail WITH (NOLOCK)          
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cProduct_SKU
         AND   ISNULL( UserDefine04, '') <> ''
         ORDER BY EDITDATE DESC

         SELECT TOP 1 @ccountryOfOrigin = Vesselkey 
         FROM DATAMART.ODS.ReceiptDetail WITH (NOLOCK)          
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cProduct_SKU
         AND   ISNULL( Vesselkey, '') <> ''
         ORDER BY EDITDATE DESC

         UPDATE @tProduct SET 
            fabricContent = CASE WHEN ISNULL( fabricContent, '') = '' THEN @cfabricContent ELSE fabricContent END, 
            productTypeDescription = CASE WHEN ISNULL( productTypeDescription, '') = '' THEN @cproductTypeDescription ELSE productTypeDescription END, 
            countryOfOrigin = CASE WHEN ISNULL( countryOfOrigin, '') = '' THEN @ccountryOfOrigin ELSE countryOfOrigin END  
         WHERE productCode = @cProduct_SKU

         FETCH NEXT FROM cur_Product INTO @cProduct_SKU 
      END
      CLOSE cur_Product
      DEALLOCATE cur_Product
      /* (james10)
      -- If after looking at all sku data on receiptdetail we still do not have the required data then return error message
      IF EXISTS ( SELECT 1 FROM @tProduct WHERE (ISNULL( fabricContent, '') = '' OR ISNULL( productTypeDescription, '') = ''))
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 91415
         SET @cErrmsg = 'Static data is empty. (isp_WS_Metapack_AllocationService)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
         GOTO Quit
      END
      */
      IF EXISTS ( SELECT 1 FROM @tProduct WHERE 
                  ISNULL( fabricContent, '') = '' OR 
                  ISNULL( productTypeDescription, '') = '' OR 
                  ISNULL( countryOfOrigin, '') = '' OR 
                  ISNULL( harmonisedProductCode, '') = '')
      UPDATE @tProduct SET   
         fabricContent = CASE WHEN ISNULL( fabricContent, '') = '' THEN '...' ELSE fabricContent END,   
         productTypeDescription = CASE WHEN ISNULL( productTypeDescription, '') = '' THEN '...' ELSE productTypeDescription END,   
         countryOfOrigin = CASE WHEN ISNULL( countryOfOrigin, '') = '' THEN 'GB' ELSE countryOfOrigin END, 
         harmonisedProductCode = CASE WHEN ISNULL( harmonisedProductCode, '') = '' THEN '...' ELSE harmonisedProductCode END 

      -- Create XML Request String
      ;WITH XMLNAMESPACES (
         'http://schemas.xmlsoap.org/soap/encoding/' AS soapenc,
         'urn:DeliveryManager/services'              AS ser,
         'http://schemas.xmlsoap.org/soap/envelope/' AS soapenv,
         'http://www.w3.org/2001/XMLSchema'          AS xsd,
         'http://www.w3.org/2001/XMLSchema-instance' AS xsi
      )
      SELECT @cRequestString =
      (
         SELECT 
            '' AS "soapenv:Header",
            ( 
               SELECT
                  'http://schemas.xmlsoap.org/soap/encoding/' AS "@soapenv:encodingStyle",
               (
                 SELECT
                     'typ:Consignment'                 AS "@xsi:type",
                     'xsd:double'                      AS "CODAmount/@xsi:type", 
                     0                                 AS "CODAmount",
                     'xsd:boolean'                     AS "CODFlag/@xsi:type", 
                     'false'                           AS "CODFlag",
                     'xsd:double'                      AS "CODSurcharge/@xsi:type", 
                     0                                 AS "CODSurcharge",
                     'xsd:boolean'                     AS "alreadyPalletisedGoodsFlag/@xsi:type", 
                     'false'                           AS "alreadyPalletisedGoodsFlag",
                     'xsd:double'                      AS "carrierServiceVATRate/@xsi:type", 
                     0.0                               AS "carrierServiceVATRate",
                     'soapenc:string'                  AS "cashOnDeliveryCurrency/@xsi:type", 
                     'GBP'                             AS "cashOnDeliveryCurrency",
                     'xsd:boolean'                     AS "consignmentLevelDetailsFlag/@xsi:type", 
                     'false'                           AS "consignmentLevelDetailsFlag",
                     CASE @nConsignmentValue -- @cOrdersUserDefine02 
                       WHEN 0 THEN NULL
                       ELSE 'xsd:double'
                     END                               AS "consignmentValue/@xsi:type", 
                     CASE @nConsignmentValue -- @cOrdersUserDefine02 
                        WHEN 0 THEN NULL 
                        ELSE RTRIM( CAST( @nConsignmentValue AS NVARCHAR( 10))) -- @cOrdersUserDefine02 
                     END                               AS "consignmentValue",
                     CASE @cOrdersUserDefine03 
                       WHEN '' THEN NULL
                       ELSE 'soapenc:string'
                     END                               AS "consignmentValueCurrencyCode/@xsi:type", 
                     CASE @cOrdersUserDefine03 
                        WHEN '' THEN NULL 
                        ELSE @cOrdersUserDefine03 
                     END                               AS "consignmentValueCurrencyCode",
                     'xsd:double'                      AS "consignmentValueCurrencyRate/@xsi:type", 
                     0                                 AS "consignmentValueCurrencyRate",
                     'xsd:double'                      AS "consignmentWeight/@xsi:type", 
                     0.5                               AS "consignmentWeight",
                     'xsd:boolean'                     AS "customsDocumentationRequired/@xsi:type", 
                     'false'                           AS "customsDocumentationRequired",
                     'xsd:boolean'                     AS "fragileGoodsFlag/@xsi:type", 
                     'false'                           AS "fragileGoodsFlag",
                     'xsd:boolean'                     AS "hazardousGoodsFlag/@xsi:type", 
                     'false'                           AS "hazardousGoodsFlag",
                     'xsd:double'                      AS "insuranceValue/@xsi:type", 
                     0                                 AS "insuranceValue",
                     'xsd:double'                      AS "insuranceValueCurrencyRate/@xsi:type", 
                     0                                 AS "insuranceValueCurrencyRate",
                     'xsd:double'                      AS "maxDimension/@xsi:type", 
                     0                                 AS "maxDimension",
                     'xsd:boolean'                     AS "moreThanOneMetreGoodsFlag/@xsi:type", 
                     'false'                           AS "moreThanOneMetreGoodsFlag",
                     'xsd:boolean'                     AS "moreThanTwentyFiveKgGoodsFlag/@xsi:type", 
                     'false'                           AS "moreThanTwentyFiveKgGoodsFlag",
                     CASE @cOrderKey 
                       WHEN '' THEN NULL
                       ELSE 'soapenc:string'
                     END                               AS "orderNumber/@xsi:type", 
                     CASE @cOrderKey 
                        WHEN '' THEN NULL 
                        ELSE @cOrderKey 
                     END                               AS "orderNumber",
                     CASE @nConsignmentValue -- @cOrdersUserDefine02 
                       WHEN 0 THEN NULL
                       ELSE 'xsd:double'
                     END                               AS "orderValue/@xsi:type", 
                     CASE @nConsignmentValue -- @cOrdersUserDefine02 
                        WHEN 0 THEN NULL 
                        ELSE RTRIM( CAST( @nConsignmentValue AS NVARCHAR( 10))) -- @cOrdersUserDefine02 
                     END                               AS "orderValue",
                     'xsd:int'                         AS "parcelCount/@xsi:type", 
                     1                                 AS "parcelCount",
                     (
                        SELECT
                           'ns2:Parcel[1]'             AS "@soapenc:arrayType",
                           'soapenc:Array'             AS "@xsi:type",
                           (
                              SELECT
                                 'ns2:Parcel'                    AS "@xsi:type", 
                                 CASE @cExternOrderKey 
                                    WHEN '' THEN NULL
                                    ELSE 'soapenc:string'
                                 END                             AS "cartonId/@xsi:type", 
                                 CASE @cExternOrderKey 
                                    WHEN '' THEN NULL 
                                    ELSE @cExternOrderKey 
                                 END                             AS "cartonId",
                                 'xsd:double'                    AS "dutyPaid/@xsi:type", 
                                 0                               AS "dutyPaid",
                                 'xsd:int'                       AS "number/@xsi:type", 
                                 1                               AS "number",
                                 'xsd:double'                    AS "parcelDepth/@xsi:type", 
                                 20                              AS "parcelDepth",
                                 'xsd:double'                    AS "parcelHeight/@xsi:type", 
                                 20                              AS "parcelHeight",
                                 CASE @nConsignmentValue 
                                    WHEN 0 THEN NULL
                                    ELSE 'xsd:double'
                                 END                             AS "parcelValue/@xsi:type", 
                                 CASE @nConsignmentValue 
                                    WHEN 0 THEN NULL 
                                    ELSE RTRIM( CAST( @nConsignmentValue AS NVARCHAR( 10))) 
                                 END                             AS "parcelValue",
                                 'xsd:double'                    AS "parcelWeight/@xsi:type", 
                                 0.5                             AS "parcelWeight",
                                 'xsd:double'                    AS "parcelWidth/@xsi:type", 
                                 20                              AS "parcelWidth",
                                 (
                                    SELECT
                                       'ns2:Product[1]'          AS "@soapenc:arrayType",
                                       'soapenc:Array'           AS "@xsi:type",
                                       (
                                          SELECT
                                             'ns2:Product'                                     AS "@xsi:type",
                                             CASE countryOfOrigin 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "countryOfOrigin/@xsi:type",
                                             CASE countryOfOrigin 
                                                WHEN '' THEN NULL 
                                                ELSE countryOfOrigin 
                                             END                                               AS "countryOfOrigin",
                                             CASE fabricContent 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "fabricContent/@xsi:type",
                                             CASE fabricContent 
                                                WHEN '' THEN NULL 
                                                ELSE fabricContent 
                                             END                                               AS "fabricContent",
                                             CASE harmonisedProductCode 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "harmonisedProductCode/@xsi:type",
                                             CASE harmonisedProductCode 
                                                WHEN '' THEN NULL 
                                                ELSE harmonisedProductCode 
                                             END                                               AS "harmonisedProductCode",
                                             CASE productCode 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "productCode/@xsi:type",
                                             CASE productCode 
                                                WHEN '' THEN NULL 
                                                ELSE productCode 
                                             END                                               AS "productCode",
                                             CASE productDescription 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "productDescription/@xsi:type",
                                             CASE productDescription 
                                                WHEN '' THEN NULL 
                                                ELSE productDescription 
                                             END                                               AS "productDescription",
                                             'xsd:long'                                        AS "productQuantity/@xsi:type",
                                             CAST(productQuantity AS DECIMAL(18,0))            AS "productQuantity",
                                             CASE productTypeDescription 
                                                WHEN '' THEN NULL
                                                ELSE 'soapenc:string'
                                             END                                               AS "productTypeDescription/@xsi:type",
                                             CASE productTypeDescription 
                                                WHEN '' THEN NULL 
                                                ELSE productTypeDescription 
                                             END                                               AS "productTypeDescription",
                                             'xsd:double'                                      AS "totalProductValue/@xsi:type",
                                             --CAST(totalProductValue AS DECIMAL(18,0))          AS "totalProductValue",
                                             RTRIM( CAST( totalProductValue AS NVARCHAR( 18))) AS "totalProductValue",
                                             'xsd:double'                                      AS "unitProductWeight/@xsi:type",
--                                             CASE WHEN unitProductWeight < 1 THEN 0.01 
--                                                  ELSE CAST(unitProductWeight AS DECIMAL(18,1)) 
--                                             END                                               AS "unitProductWeight"
                                             RTRIM( CAST( unitProductWeight AS NVARCHAR( 18))) AS "unitProductWeight" 
                                          FROM @tProduct 
                                          FOR XML PATH('products'), TYPE
                                       )
                                    FOR XML PATH('products'), TYPE
                                 )
                              FOR XML PATH('parcels'), TYPE
                           )
                        FOR XML PATH('parcels'), TYPE
                     ),
                     'soapenc:string'                     AS "podRequired/@xsi:type", 
                     'any'                                AS "podRequired",
                     'ns2:Property[0]'                    AS "properties/@soapenc:arrayType", 
                     'soapenc:Array'                      AS "properties/@xsi:type", 
                     (
                        SELECT
                           'ns2:Address'                  AS "@xsi:type",
                           CASE @cRecipientCountry 
                              WHEN '' THEN NULL
                              ELSE 'soapenc:string'
                           END                            AS "countryCode/@xsi:type",
                           CASE @cRecipientCountry 
                              WHEN '' THEN NULL 
                              ELSE @cRecipientCountry 
                           END                            AS "countryCode",
                           CASE @cRecipientAddress1 
                              WHEN '' THEN NULL
                              ELSE 'soapenc:string'
                           END                            AS "line1/@xsi:type",
                           CASE @cRecipientAddress1 
                              WHEN '' THEN NULL 
                              ELSE @cRecipientAddress1 
                           END                            AS "line1",
                           CASE @cRecipientAddress2 
                              WHEN '' THEN NULL
                              ELSE 'soapenc:string'
                           END                            AS "line2/@xsi:type",
                           CASE @cRecipientAddress2 
                              WHEN '' THEN NULL 
                              ELSE @cRecipientAddress2 
                           END                            AS "line2",
--                           CASE @cRecipientAddress3 
--                              WHEN '' THEN NULL
--                              ELSE 'soapenc:string'
--                           END                            AS "line3/@xsi:type",
--                           CASE @cRecipientAddress3 
--                              WHEN '' THEN NULL 
--                              ELSE @cRecipientAddress3 
--                           END                            AS "line3",
                           CASE @cRecipientCity   
                              WHEN '' THEN NULL  
                              ELSE 'soapenc:string'  
                           END                            AS "line3/@xsi:type",  
                           CASE @cRecipientCity   
                              WHEN '' THEN NULL   
                              ELSE @cRecipientCity   
                           END                            AS "line3",
                           
                           CASE WHEN @cRecipientCountry = 'US' THEN  --NJOW01
                              CASE @cRecipientState 
                                 WHEN '' THEN NULL
                                 ELSE 'soapenc:string'
                              END
                           ELSE                          
                              CASE @cRecipientCity 
                                 WHEN '' THEN NULL
                                 ELSE 'soapenc:string'
                              END   
                           END AS "line4/@xsi:type",
                           CASE WHEN @cRecipientCountry = 'US' THEN  --NJOW01
                              CASE @cRecipientState 
                                 WHEN '' THEN NULL 
                                 ELSE @cRecipientState 
                              END 
                           ELSE
                              CASE @cRecipientCity 
                                 WHEN '' THEN NULL 
                                 ELSE @cRecipientCity 
                              END                            
                           END AS "line4",                                                      
                           /*CASE @cRecipientCity 
                              WHEN '' THEN NULL
                              ELSE 'soapenc:string'
                           END                            AS "line4/@xsi:type",
                           CASE @cRecipientCity 
                              WHEN '' THEN NULL 
                              ELSE @cRecipientCity 
                           END                            AS "line4",*/
                           CASE @cRecipientZip 
                              WHEN '' THEN NULL
                              ELSE 'soapenc:string'
                           END                            AS "postCode/@xsi:type",
                           CASE @cRecipientZip 
                              WHEN '' THEN NULL 
                              ELSE @cRecipientZip 
                           END                            AS "postCode"
                        FOR XML PATH('recipientAddress'), TYPE
                     ),
                     CASE @cRecipientPhone1 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientContactPhone/@xsi:type",
                     CASE @cRecipientPhone1 
                        WHEN '' THEN NULL 
                        ELSE @cRecipientPhone1 
                     END                           AS "recipientContactPhone",
                     --(KH01) - S
                     CASE @cOrdersNotes2 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientEmail/@xsi:type",
                     CASE @cOrdersNotes2 
                        WHEN '' THEN NULL 
                        ELSE @cOrdersNotes2 
                     END                           AS "recipientEmail",
                     --(KH01) - E
                     --CASE @cRecipientPhone2 --(KH02) 
                     CASE @cRecipientPhone1 --(KH02) 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientMobilePhone/@xsi:type",
                     --CASE @cRecipientPhone2 --(KH02)
                     CASE @cRecipientPhone1 --(KH02)
                        WHEN '' THEN NULL 
                        --ELSE @cRecipientPhone2 --(KH02)
                        ELSE @cRecipientPhone1 --(KH02)
                     END                           AS "recipientMobilePhone",
                     CASE @cRecipientContact1 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientName/@xsi:type",
                     CASE @cRecipientContact1 
                        WHEN '' THEN NULL 
                        ELSE @cRecipientContact1 
                     END                           AS "recipientName",
--                     'soapenc:string'              AS "recipientName/@xsi:type", 
--                     '.'                           AS "recipientName",
--                     'soapenc:string'              AS "recipientNotificationType/@xsi:type", 
--                     'N'                           AS "recipientNotificationType",
                     --CASE @cRecipientPhone1 --(KH02)
                     CASE @cRecipientPhone2 --(KH02)
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientPhone/@xsi:type",
                     --CASE @cRecipientPhone1 --(KH02)
                     CASE @cRecipientPhone2 --(KH02)
                        WHEN '' THEN NULL 
                        --ELSE @cRecipientPhone1 --(KH02)
                        ELSE @cRecipientPhone2 --(KH02)
                     END                           AS "recipientPhone",
                     CASE @cRecipientVat 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "recipientVatNumber/@xsi:type",
                     CASE @cRecipientVat 
                        WHEN '' THEN NULL 
                        ELSE @cRecipientVat 
                     END                           AS "recipientVatNumber",
                     (
                        SELECT
                           'ns2:Address'                   AS "@xsi:type", 
                           'soapenc:string'                AS "companyName/@xsi:type", 
                           'Jack Wills'                    AS "companyName",
                           'soapenc:string'                AS "countryCode/@xsi:type", 
                           'GBR'                           AS "countryCode",
                           'soapenc:string'                AS "line1/@xsi:type", 
                           'Unit 1 Parkway Interchange'    AS "line1",
                           'soapenc:string'                AS "line2/@xsi:type", 
                           '35 Kettlebridge Road'          AS "line2",
                           'soapenc:string'                AS "line3/@xsi:type", 
                           'Sheffield'                     AS "line3",
                           'soapenc:string'                AS "line4/@xsi:type", 
                           'South Yorkshire'               AS "line4",
                           'soapenc:string'                AS "postCode/@xsi:type", 
                           'S9 3BZ'                        AS "postCode"
                        FOR XML PATH('senderAddress'), TYPE
                     ),
                     'soapenc:string'              AS "senderCode/@xsi:type", 
                     --'000'                         AS "senderCode",
                     '001'                         AS "senderCode",            -- (Chee02)
                     'soapenc:string'              AS "senderEmail/@xsi:type", 
                     'jack@jackwills.com'          AS "senderEmail",           -- (Chee02)
                     'soapenc:string'              AS "senderMobilePhone/@xsi:type", 
                     '0114 261 5615/5625'          AS "senderMobilePhone",     -- (Chee02)
                     'soapenc:string'              AS "senderName/@xsi:type", 
                     --'Westcoast'                   AS "senderName",
                     'Jack Wills'                  AS "senderName",            -- (Chee02)
                     'soapenc:string'              AS "senderPhone/@xsi:type", 
                     '0208 747 7601'               AS "senderPhone",           -- (Chee02)
                     'soapenc:string'              AS "senderTimeZone/@xsi:type", 
                     'Europe/London'               AS "senderTimeZone",
                     'xsd:double'                  AS "shippingCharge/@xsi:type", 
                     0                             AS "shippingCharge",     
                     'xsd:double'                  AS "shippingChargeCurrencyRate/@xsi:type",
                     0                             AS "shippingChargeCurrencyRate",
                     CASE @cOrdersNotes 
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "specialInstructions1/@xsi:type",
                     CASE @cOrdersNotes 
                        WHEN '' THEN NULL 
                        ELSE @cOrdersNotes 
                     END                           AS "specialInstructions1",
                     CASE @cOrdersNotes2
                        WHEN '' THEN NULL
                        ELSE 'soapenc:string'
                     END                           AS "specialInstructions2/@xsi:type",
                     CASE @cOrdersNotes2
                        WHEN '' THEN NULL
                        ELSE @cOrdersNotes2
                     END                           AS "specialInstructions2",
                     'xsd:double'                  AS "taxAndDuty/@xsi:type", 
                     0                             AS "taxAndDuty",     
                     'xsd:double'                  AS "taxAndDutyCurrencyRate/@xsi:type", 
                     0                             AS "taxAndDutyCurrencyRate",  
                     'soapenc:string'              AS "transactionType/@xsi:type", 
                     'Delivery'                    AS "transactionType",     
                     'xsd:boolean'                 AS "twoManLiftFlag/@xsi:type", 
                     'false'                       AS "twoManLiftFlag"
                  FOR XML PATH('consignment'), TYPE
               ),
               CASE @cIncoterm 
                  WHEN '' THEN NULL
                  ELSE 'soapenc:string'
               END                            AS "bookingCode/@xsi:type", 
               CASE @cIncoterm 
                  WHEN '' THEN NULL 
                  ELSE @cIncotermDescr 
               END                            AS "bookingCode",
               'xsd:boolean'                  AS "calculateTaxAndDuty/@xsi:type", 
               'false'                        AS "calculateTaxAndDuty"
               FOR XML PATH('ser:despatchConsignmentWithBookingCode'),
               ROOT('soapenv:Body'), TYPE
            )
         FOR XML PATH(''),
         ROOT('soapenv:Envelope')
      )

      -- Remove Redundant Namespace
      SET @cRequestString = REPLACE(@cRequestString, '<consignment xsi:type="typ:Consignment">', '<consignment xmlns:typ="urn:DeliveryManager/types" xsi:type="typ:Consignment">')
   END
   ELSE
   BEGIN
      SELECT @cStorerKey = RTRIM(StorerKey)
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      -- Create XML Request String
      ;WITH XMLNAMESPACES (
         'http://schemas.xmlsoap.org/soap/encoding/' AS soapenc,
         'urn:DeliveryManager/services'              AS ser,
         'http://schemas.xmlsoap.org/soap/envelope/' AS soapenv,
         'http://www.w3.org/2001/XMLSchema'          AS xsd,
         'http://www.w3.org/2001/XMLSchema-instance' AS xsi
      )
      SELECT @cRequestString =
      (
         SELECT 
            '' AS "soapenv:Header",
            ( 
               SELECT 
                  'http://schemas.xmlsoap.org/soap/encoding/' AS "@soapenv:encodingStyle",
                  'ser:ArrayOf_soapenc_string'                AS "consignmentCodes/@xsi:type", 
                  'soapenc:string[]'                          AS "consignmentCodes/@soapenc:arrayType", 
                  @cConsignmentCode                           AS "consignmentCodes/item",
                  (
                     SELECT
                        'ser:ArrayOf_tns1_Property'           AS "@xsi:type",
                        'typ:Property[]'                      AS "@soapenv:arrayType",
                        (
                           SELECT
                              'type'                          AS "propertyName",
                              'all'                           AS "propertyValue"
                           FOR XML PATH('item'), TYPE
                        ),
                        (
                           SELECT
                              'format'                        AS "propertyName",
                              'pdf'                           AS "propertyValue"
                           FOR XML PATH('item'), TYPE
                        ),
                        (
                           SELECT
                              'dimension'                     AS "propertyName",
                              '6x4'                           AS "propertyValue"
                           FOR XML PATH('item'), TYPE
                        ),
                        (
                           SELECT
                              'dpi'                           AS "propertyName",
                              '300'                           AS "propertyValue"
                           FOR XML PATH('item'), TYPE
                        )
                     FOR XML PATH('parameters'), TYPE
                  )
               FOR XML PATH('ser:createPaperworkForConsignments'),
               ROOT('soapenv:Body'), TYPE
            )
         FOR XML PATH(''),
         ROOT('soapenv:Envelope')
      )

      SET @cRequestString = REPLACE(@cRequestString, '<parameters xsi:type="ser:ArrayOf_tns1_Property" soapenv:arrayType="typ:Property[]">', '<parameters xmlns:typ="urn:DeliveryManager/types" xsi:type="ser:ArrayOf_tns1_Property" soapenc:arrayType="typ:Property[]">')
   END

   -- Remove Redundant Namespace
   SET @cRequestString = REPLACE(@cRequestString, ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="urn:DeliveryManager/services" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"', '')
   SET @cRequestString = REPLACE(@cRequestString, '<soapenv:Envelope>', '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="urn:DeliveryManager/services" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">')

   -- Create Request String
   SET @xRequestString = CAST(@cRequestString AS XML)
   SET @cRequestString = @cXMLEncodingString + @cRequestString

   IF @nDebug = 1
   BEGIN
      SELECT @xRequestString AS 'XML Request String'
      SELECT @cRequestString AS 'Request String'
   END
  
   -- Insert Request String into [WebService_Log]
   SET @cExecStatements = ''  
   SET @cExecArguments = ''   
   SET @cExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log ( '  
                          + 'DataStream, StorerKey, Type, BatchNo, WebRequestURL, WebRequestMethod, ContentType, '
                          + 'RequestString, Status, ClientHost, WSIndicator, SourceKey, SourceType) '   
                          + 'OUTPUT INSERTED.SeqNo INTO #StoreSeqNoTempTable VALUES ( '  
                          + '@cDataStream, @cStorerKey, @cType, @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType, '
                          + '@cRequestString, @cStatus, @cClientHost, @cWSIndicator, @cSourceKey, @cSourceType)'
        
   SET @cExecArguments = N'@cDataStream        NVARCHAR(10),   ' 
                         + '@cStorerKey        NVARCHAR(15),   '
                         + '@cType             NVARCHAR(1),    '
                         + '@cBatchNo          NVARCHAR(10),   '
                         + '@cWebRequestURL    NVARCHAR(1000), '
                         + '@cWebRequestMethod NVARCHAR(10),   '
                         + '@cContentType      NVARCHAR(100),  '
                         + '@cRequestString    NVARCHAR(MAX),  '
                         + '@cStatus           NVARCHAR(1),    '
                         + '@cClientHost       NVARCHAR(1),    '
                         + '@cWSIndicator      NVARCHAR(1),    '
                         + '@cSourceKey        NVARCHAR(50),   '
                         + '@cSourceType       NVARCHAR(50)    '

   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                      '', @cStorerKey, 'O', @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType,
                      @cRequestString, @cStatus, 'C', 'R', @cLabelNo, 'isp_WS_Metapack_AllocationService' 

   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0
      SET @nErr = 91404
      SET @cErrmsg = 'Error inserting into WebService_Log Table. (isp_WS_Metapack_AllocationService)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END  

   SELECT @nSeqNo = SeqNo
   FROM #StoreSeqNoTempTable

   EXEC dbo.nspGetRight        
      NULL,        
      NULL,        
      NULL,        
      'WebServiceClientContingency',        
      @bSuccess               OUTPUT,        
      @cWSClientContingency   OUTPUT,         
      @nErr                   OUTPUT,         
      @cErrMsg                OUTPUT    
        
   IF NOT @bSuccess = 1        
   BEGIN        
      SET @bSuccess = 0         
      SET @nErr = 91405     
      SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp_WS_Metapack_AllocationService)'          
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'          
      GOTO Quit        
   END  
   
   IF @nDebug = 1        
   BEGIN        
      SELECT @cWSClientContingency AS '@cWSClientContingency'      
   END   

   SET @dTimeIn = GETDATE()

   IF @cWSClientContingency <> '1'  
   BEGIN
      --(KT01) - Start  
      -- Send RequestString and Receive ResponseString        
      --EXEC [master].[dbo].[isp_GenericWebServiceClient]        
      --   @cIniFilePath,        
      --   @cWebRequestURL,        
      --   @cWebRequestMethod,        
      --   @cContentType,        
      --   @cWebRequestEncoding,        
      --   @cRequestString,        
      --   @cResponseString   OUTPUT,        
      --   @cVBErrMsg         OUTPUT,
      --   0,
      --   @cMetapackNetworkUserName,
      --   @cMetapackNetworkPassword,
      --   1  -- IsSoapRequest

		EXEC [master].[dbo].[isp_GenericWebServiceClient] @cIniFilePath
																		, @cWebRequestURL
																		, @cWebRequestMethod --@c_WebRequestMethod
																		, @cContentType --@c_ContentType
																		, @cWebRequestEncoding --@c_WebRequestEncoding
																		, @cRequestString --@c_FullRequestString
																		, @cResponseString OUTPUT
																		, @cVBErrMsg OUTPUT																 
																		, 0 --@n_WebRequestTimeout -- Miliseconds
																		, @cMetapackNetworkUserName --@c_NetworkCredentialUserName -- leave blank if no network credential
																		, @cMetapackNetworkPassword --@c_NetworkCredentialPassword -- leave blank if no network credential
																		, 1 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
																		, '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
																		, '' --@c_HeaderAuthorization
																		, '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
		--(KT01) - End

      -- (James01)
      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
      BEGIN        
         SET @cMetaPackErr = SUBSTRING( @cResponseString, CHARINDEX( '<faultstring>', @cResponseString) + 13, 6)
         IF ISNULL( @cMetaPackErr, '') <> ''  
         BEGIN  
            SELECT @cMetaPackErrMsg = Long FROM dbo.CODELKUP WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   Listname = 'METAPACKER'  
            AND   Code = @cMetaPackErr  
              
            SET @cMetaPackErrMsg = RTRIM( @cMetaPackErr) + ' ' + @cMetaPackErrMsg  
         END  
         
         SET @cStatus = '5'        
         SET @bSuccess = 0        
         SET @nErr = 91406 
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CASE WHEN ISNULL( @cMetaPackErrMsg, '') = '' THEN CAST(@cVBErrMsg AS NVARCHAR(250)) ELSE @cMetaPackErrMsg END
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp_WS_Metapack_AllocationService)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
         END        
      END     
   END  
   ELSE  
   BEGIN  
      SELECT @cConnectionString = 'Data Source=' + UDF01 + ';uid=' + UDF02 + ';pwd=' + dbo.fnc_DecryptPWD(UDF03) 
                                  + ';Application Name=' + UDF04 + ';Enlist=false'
      FROM CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = 'WebService'  
        AND Code = 'ConnString'  
  
      EXEC [master].[dbo].[isp_GenericWebServiceClient_Contingency]       
         @cConnectionString,  
         @cIniFilePath,  
         @cWebRequestURL,  
         @cWebRequestMethod,  
         @cContentType,  
         @cWebRequestEncoding,  
         @cRequestString,  
         @cResponseString   OUTPUT,  
         @cvbErrMsg         OUTPUT,
         0,
         @cMetapackNetworkUserName,
         @cMetapackNetworkPassword,
         1  -- IsSoapRequest
      
      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
      BEGIN        
         SET @cStatus = '5'        
         SET @bSuccess = 0        
         SET @nErr = 91407 
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp_WS_Metapack_AllocationService)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
         END        
      END    
   END -- IF @cWSClientContingency <> '1'  

   SET @dTimeOut = GETDATE()
   SET @nTotalTime = DATEDIFF(ms, @dTimeIn, @dTimeOut)

   -- Get rid of the encoding part in the root tag to prevent error: unable to switch the encoding
   SET @xResponseString = CAST(REPLACE(@cResponseString, 'encoding="' + @cWebRequestEncoding + '"', '') AS XML)

   IF @nDebug = 1
   BEGIN
      SELECT @xResponseString AS 'XML Response String'
      SELECT @cResponseString AS 'Response String'
   END

  -- Update [WebService_Log]
   SET @cExecStatements = ''  
   SET @cExecArguments = ''   
   SET @cExecStatements = N'UPDATE ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log WITH (ROWLOCK) '  
                          + 'SET Status = @cStatus, ErrMsg = @cErrmsg, TimeIn = @dTimeIn, '
                          + '    ResponseString = @cResponseString, TimeOut = @dTimeOut, TotalTime = @nTotalTime '   
                          + 'WHERE SeqNo = @nSeqNo'
        
   SET @cExecArguments = N'@cStatus          NVARCHAR(1),   ' 
                         + '@cErrmsg         NVARCHAR(215), '
                         + '@cBatchNo        NVARCHAR(10),  '
                         + '@cResponseString NVARCHAR(MAX), '
                         + '@dTimeIn         DATETIME,      '
                         + '@dTimeOut        DATETIME,      '
                         + '@nTotalTime      INT,           '
                         + '@nSeqNo          INT            '

   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                      @cStatus, @cErrmsg, @cBatchNo, @cResponseString, @dTimeIn, @dTimeOut, @nTotalTime, @nSeqNo

   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0
      SET @nErr = 91408
      SET @cErrmsg = 'Error updating WebService_Log Table. (isp_WS_Metapack_AllocationService)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END  

   IF @cStatus = '5'
   BEGIN
      GOTO Quit
   END

   -- Extract ResponseString Data    
   EXEC sp_xml_preparedocument @ndoc OUTPUT, @xResponseString , @cXMLNamespace  

   IF ISNULL(@cConsignmentCode, '') IN ('', '0')
   BEGIN
      SELECT     
         @cConsignmentCode        = consignmentCode,
         @cCarrierName            = carrierName,
         @cDocuments              = documents,
         @cLabels                 = labels,
         @cCarrierConsignmentCode = carrierConsignmentCode  -- (Chee01)
      FROM OPENXML (@ndoc, '/soapenv:Envelope/soapenv:Body/ns1:despatchConsignmentWithBookingCodeResponse/despatchConsignmentWithBookingCodeReturn', 2)  
      WITH(  
         consignmentCode        NVARCHAR(20)   'consignment/consignmentCode',
         carrierName            NVARCHAR(10)   'consignment/carrierName',
         documents              NVARCHAR(MAX)  'paperwork/documents',
         labels                 NVARCHAR(MAX)  'paperwork/labels',
         carrierConsignmentCode NVARCHAR(20)   'consignment/carrierConsignmentCode' -- (Chee01)
      ) 
   END
   ELSE
   BEGIN
      SELECT     
         @cDocuments       = documents,
         @cLabels          = labels
      FROM OPENXML (@ndoc, '/soapenv:Envelope/soapenv:Body/ns1:createPaperworkForConsignmentsResponse/createPaperworkForConsignmentsReturn', 2)  
      WITH(  
         documents          NVARCHAR(MAX)  'documents',
         labels             NVARCHAR(MAX)  'labels'
      ) 
   END

   EXEC sp_xml_removedocument @ndoc   

   IF @nDebug = 1  
   BEGIN  
   SELECT  
      @cConsignmentCode            AS 'consignmentCode',
      @cCarrierName                AS 'carrierName',
      @cDocuments                  AS 'documents',
      @cLabels                     AS 'labels',
      @cCarrierConsignmentCode     AS 'carrierConsignmentCode'
   END  

UpdateDB:  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN

   IF NOT EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                 WHERE PickSlipNo = @cPickSlipNo 
                   AND CartonNo = @nCartonNo 
                   AND LabelNo = @cLabelNo
                   AND ISNULL(RefNo, '') <> '')
   BEGIN
      UPDATE dbo.PackDetail WITH (ROWLOCK)
      SET RefNo = @cCarrierConsignmentCode, RefNo2 = @cConsignmentCode,  -- (Chee01)
          Editdate = getdate(),         -- tlting  
          Editwho  = Suser_Sname()        
      WHERE PickSlipNo = @cPickSlipNo
        AND CartonNo = @nCartonNo
        AND LabelNo = @cLabelNo

      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 91409  
         SET @cErrmsg = 'Error updating [dbo].[PackDetail] Table. (isp_WS_Metapack_AllocationService)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO RollbackTran  
      END  

      UPDATE dbo.Orders WITH (ROWLOCK)
      SET UserDefine10 = @cCarrierName,
          TrafficCop = NULL,      --tlting  
          Editdate = getdate(),  
          Editwho  = Suser_Sname()  
      WHERE OrderKey = @cOrderKey

      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 91410  
         SET @cErrmsg = 'Error updating [dbo].[Orders] Table. (isp_WS_Metapack_AllocationService)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO RollbackTran  
      END  
   END

   COMMIT TRAN  
   GOTO Quit  
  
RollbackTran:  
   ROLLBACK TRAN  

Quit:
    SELECT 
       @cWorkingFilePath = Long,
       @cPrintFilePath = Notes
    FROM dbo.CODELKUP WITH (NOLOCK)
    WHERE LISTNAME = 'Metapack'
      AND Code = 'PDFPrint'

   -- Create PDF labels
   IF ISNULL(@cLabels, '') <> ''
   BEGIN
      SET @cFileName = 'Labels_' + @cLabelNo + '.pdf'

      EXEC [master].[dbo].[isp_GenericFileCreator]
         @cLabels,
         @cFileName,
         @cWorkingFilePath,
         @cvbErrMsg         OUTPUT

      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
      BEGIN
         SET @bSuccess = 0        
         SET @nErr = 91411
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericFileCreator]. (isp_WS_Metapack_AllocationService)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
         END        
      END

      IF @nDebug = 1
         SELECT 'PDF Label: ' + @cFileName + ' created.'

      -- Print PDF Labels
      IF ISNULL(@cPrinterName, '') <> ''
      BEGIN
         SET @nReturnCode = 0
         SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cPrinterName + '"'

         INSERT INTO @tCMDError
         EXEC @nReturnCode = xp_cmdshell @cCMD
         IF @nReturnCode <> 0
         BEGIN
            SET @bSuccess = 0  
            SET @nErr = 91412
            SET @cErrmsg = 'Error printing labels. (isp_WS_Metapack_AllocationService)'  
                         + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         END

         IF @nDebug = 1
            SELECT 'PDF Label: ' + @cFileName + ' printed.'

      END  -- IF ISNULL(@cPrinterName, '') <> ''
   END  -- IF ISNULL(@cLabels, '') <> ''

   -- Create PDF documents
   IF ISNULL(@cDocuments, '') <> ''
   BEGIN
      SET @cFileName = 'C23_' + @cLabelNo + '.pdf'

      EXEC [master].[dbo].[isp_GenericFileCreator]
         @cDocuments,
         @cFileName,
         @cWorkingFilePath,
         @cvbErrMsg         OUTPUT

      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
      BEGIN
         SET @bSuccess = 0        
         SET @nErr = 91413
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericFileCreator]. (isp_WS_Metapack_AllocationService)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
         END        
      END
      SET @cDocumentFilePath = @cWorkingFilePath + '\' + @cFileName

      IF @nDebug = 1
         SELECT 'PDF Document: ' + @cFileName + ' created.'

   END  -- IF ISNULL(@cDocuments, '') <> ''

   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   WHILE @nTrancount > @@TRANCOUNT
      COMMIT TRAN

END -- Procedure

GO