SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/    
/* SP: isp_WS_TNT_ShipmentRequest                                       */    
/* Creation Date: 19 Aug 2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Loop each ConsignmentNumber for Orderkey to send            */    
/*          ShipmentRequest web service request consist of MBOL Shipment*/    
/*          Order & Driver's Manifest to TNT                            */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By: Schedule Job after MBOL Shipped transmitlog3.MBOL2LOG     */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.3                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver      Purposes                              */    
/* 19-08-2014   Chee     1.0      Initial Version SOS#318657            */    
/* 17-11-2014   NJOW01   1.1      325158-Email alert on empty udf01 &   */  
/*                                udf03 of consigneesku.                */   
/* 30-09-2014   Chee     1.1      SOS#321735 TNT Weekend Terms (Chee01) */  
/* 03-12-2014   TKLim    1.1      StorerAddress123 to VARCHAR(30) (TK01)*/  
/* 19-12-2014   YTWan    1.3      Suspect Respond Time Out and get empty*/  
/*                                reponsestring. Fixed.(Wan01)          */  
/* 21-12-2014   Shong    1.4      Insert into transmitlog2 table when   */  
/*                                Sucessfully sent to TNT               */  
/* 08-12-2014   TKLim    1.5      Insert TL2 after all cnsgmt sent(TK02)*/  
/* 16-01-2015   James    1.6      SOS323145 - Set Transmitlog3 = IGNOR  */
/*                                when PlaceofLoadingQualifier <> TNT   */
/*                                Enhance TNT file creation (james01)   */
/* 24-Mar-2015  MCTang   1.7      Fix Invalid Object Issues (MC01)      */
/* 15-Dec-2015  NJOW02   1.8      358914-TNT shipment enhancements      */
/* 20-Jul-2016  KTLow    1.9      Add WebService Client Parameter (KT01)*/
/* 05-Dec-2016  SHONG01  2.0      JIRA WMS-739 (Wan02)                  */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_WS_TNT_ShipmentRequest](    
    @cTransmitlogKey  NVARCHAR(10)    
   ,@cTableName       NVARCHAR(30)    
   ,@cMbolKey         NVARCHAR(10)    
   ,@cKey2            NVARCHAR(5)    
   ,@cStorerKey       NVARCHAR(10)    
   ,@cTransmitBatch   NVARCHAR(30)    
   ,@bSuccess         INT            OUTPUT      
   ,@nErr             INT            OUTPUT      
   ,@cErrMsg          NVARCHAR(250)  OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
    
   DECLARE    
      @cIniFilePath           NVARCHAR(100),    
      @cWebRequestURL         NVARCHAR(1000),    
      @cWebRequestMethod      NVARCHAR(10),    
      @cContentType           NVARCHAR(100),    
      @cWebRequestEncoding    NVARCHAR(30),    
      @cXMLEncodingString     NVARCHAR(100),    
      @cRequestString         NVARCHAR(MAX),    
      @cResponseString        NVARCHAR(MAX),    
      @cVBErrMsg              NVARCHAR(MAX),    
      @xRequestString         XML,    
      @xResponseString        XML,    
      @dTimeIn                DATETIME,    
      @dTimeOut               DATETIME,    
      @nTotalTime             INT,    
      @cStatus                NVARCHAR(1),    
      @cBatchNo               NVARCHAR(10),    
      @nDebug                 INT,    
      @nSeqNo                 INT,    
      @ndoc                   INT,    
      @nTrancount             INT,    
      @cTNTNetworkUserName    NVARCHAR(100),    
      @cTNTNetworkPassword    NVARCHAR(100),   
      @cWSClientContingency   NVARCHAR(1),       
      @cConnectionString      NVARCHAR(250),    
      @cWebServiceLogDBName   NVARCHAR(30),    
      @cExecStatements        NVARCHAR(4000),    
      @cExecArguments         NVARCHAR(4000)    
    
   DECLARE     
      @cConsignmentNumber     NVARCHAR(10),    
      @cOrderKey              NVARCHAR(10),    
      @cLoadKey               NVARCHAR(10),    
      @cOrderNotes            NVARCHAR(4000),    
      @cConsigneeKey          NVARCHAR(15),    
      @cFacility              NVARCHAR(5),    
      @cOrderDate             NVARCHAR(19),    
      @cSenderName            NVARCHAR(40),    
      @cFacilityAddress1      NVARCHAR(45),    
      @cFacilityAddress2      NVARCHAR(45),    
      @cFacilityAddress3      NVARCHAR(45),    
      @cFacilityState         NVARCHAR(45),    
      @cFacilityCity          NVARCHAR(45),    
      @cFacilityZip           NVARCHAR(18),    
      @cFacilityCountry       NVARCHAR(30),    
      @cStorerCompany         NVARCHAR(45),    
      @cStorerAddress1        NVARCHAR(30),  --(TK01)   
      @cStorerAddress2        NVARCHAR(30),  --(TK01)  
      @cStorerAddress3        NVARCHAR(30),  --(TK01)  
      @cStorerCity            NVARCHAR(90),    
      @cStorerZip             NVARCHAR(18),    
      @cStorerCountry         NVARCHAR(30),    
      @cStorerContact1        NVARCHAR(30),    
      @cStorerPhone1          NVARCHAR(18),    
      @cService               NVARCHAR(10),    
      @cAccountNumber         NVARCHAR(10),    
      @fCartonWeight          FLOAT,    
      @nPackDetailQty         INT,     
      @fGoodsValue            FLOAT,     
      @cLabelNo               NVARCHAR(20),  
      @cProductOption         NVARCHAR(10), --NJOW02
      @cOptionMonThu          NVARCHAR(30), --NJOW02
      @cOptionFriSat          NVARCHAR(30), --NJOW02
      @cOptionSatSunMon       NVARCHAR(30), --SHONG01
      @cOptionTueFri          NVARCHAR(30), --(Wan02)
      @cOptionSat             NVARCHAR(30), --(Wan02)
      @cOptionMon             NVARCHAR(30), --(Wan02)
      -- (Chee01)  
      @cOrderType             NVARCHAR(10),  
      @dLPUserDefDate01       DATETIME,  
      @cNoSundayTNTDelivery   NVARCHAR(10)  
  
   DECLARE    
      @cResponseNumber        NVARCHAR(10),    
      @nErrorCode             INT,    
      @cErrorDescription      NVARCHAR(250),    
      @cRecipients            NVARCHAR(MAX),    
      @cBody                  NVARCHAR(MAX),    
      @cSubject               NVARCHAR(255),    
      @c_UDF01                NVARCHAR(60), --NJOW01  
      @c_UDF03                NVARCHAR(60), --NJOW01  
      @bProcessed             INT, -- SHONG01  
      @cPrevOrderKey          NVARCHAR(10)   --TK02 
    
   DECLARE @tError TABLE(    
      OrderKey           NVARCHAR(10),    
      LabelNo            NVARCHAR(20),    
      ConsignmentNumber  NVARCHAR(10),    
      Storerkey          NVARCHAR(15), --NJOW01  
      Consigneekey       NVARCHAR(15), --NJOW01  
      City               NVARCHAR(45), --NJOW01  
      ZipCode            NVARCHAR(18), --NJOW01  
      ErrMsg             NVARCHAR(250)    
   )    

   -- (james01)
   IF NOT EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) 
                   WHERE MbolKey = @cMbolKey
                   AND   PlaceofLoadingQualifier = 'TNT')
   BEGIN    
      SET @bSuccess = 0    
      SET @nErr = 90010 
      SET @cErrmsg = 'PlaceofLoadingQualifier <> TNT. (isp_WS_TNT_ShipmentRequest)'    
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    

      -- Insert Request String into [WebService_Log]    
      SET @cExecStatements = ''      
      SET @cExecArguments = ''       

      SET @cExecStatements = N'UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK) SET '     --MC01  
                             +'Transmitflag = ''IGNOR'' '
                             +'WHERE TransmitlogKey = ''' + @cTransmitlogKey     + ''''
               
      SET @cExecArguments = N'@cTableName        NVARCHAR(20),   '     
                            +'@cTransmitlogKey   NVARCHAR(10)    '    
    
      EXEC sp_ExecuteSql @cExecStatements, @cExecArguments,     
                         @cTableName, @cTransmitlogKey
    
      IF @@ERROR <> 0      
      BEGIN      
         SET @bSuccess = 0    
         SET @nErr = 90011    
         SET @cErrmsg = 'Error updating TransmitLog3.Transmitflag to IGNOR. (isp_WS_TNT_ShipmentRequest)'    
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
      END      
      
      GOTO Quit    
   END    

   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL    
      DROP TABLE #StoreSeqNoTempTable;    
    
   CREATE TABLE #StoreSeqNoTempTable(SeqNo INT)     
    
   SET @nDebug      = 0    
    
   SET @bSuccess    = 1    
   SET @nErr        = 0    
   SET @cErrmsg     = ''    
    
   SET @cStatus               = '9'    
   SET @cBatchNo              = ''    
    
   SET @cWebRequestMethod    = 'POST'    
   SET @cContentType         = 'application/x-www-form-urlencoded'     
   SET @cWebRequestEncoding  = 'UTF-8'    
   SET @cXMLEncodingString   = '<?xml version="1.0" encoding="UTF-8"?>'    
    
   -- Get WebService_Log DB Name    
   SELECT @cWebServiceLogDBName = NSQLValue      
   FROM dbo.NSQLConfig WITH (NOLOCK)      
   WHERE ConfigKey = 'WebServiceLogDBName'     
    
   IF ISNULL(@cWebServiceLogDBName, '') = ''    
   BEGIN    
      SET @bSuccess = 0      
      SET @nErr = 90000    
      SET @cErrmsg = 'NSQLConfig - WebServiceLogDBName is empty. (isp_WS_TNT_ShipmentRequest)'    
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
      SET @nErr = 90001    
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp_WS_TNT_ShipmentRequest)'    
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
      GOTO Quit    
   END    
    
   -- Get Web Service Request URL     
  SELECT     
      @cWebRequestURL = RTRIM(Long),    
      @cTNTNetworkUserName = RTRIM(UDF01),    
      @cTNTNetworkPassword = RTRIM(UDF02),    
      @cAccountNumber = RTRIM(UDF03)    
   FROM dbo.CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'WebService'    
     AND Code = 'TNTConnectURL'    
    
   IF ISNULL(@cWebRequestURL,'') = ''    
   BEGIN    
      SET @bSuccess = 0    
      SET @nErr = 90002    
      SET @cErrmsg = 'Web Service Request URL is empty. (isp_WS_TNT_ShipmentRequest)'    
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
      GOTO Quit    
   END    
    
   IF @nDebug = 1    
   BEGIN    
      SELECT @cWebServiceLogDBName AS 'Table WebService_Log DB Name',    
             @cIniFilePath AS 'WSConfig.ini File Path',    
             @cWebRequestURL AS 'Web Service Request URL'    
 END    
    
   DECLARE C_ConsignmentNumber CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT MD.OrderKey, UCCLabelNo, TrackingNumber, CartonWeight    
   FROM dbo.MbolDetail MD WITH (NOLOCK)    
   JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey    
   JOIN dbo.CartonShipmentDetail CSD WITH (NOLOCK) ON CSD.OrderKey = MD.OrderKey    
   WHERE MD.MbolKey = @cMbolKey    
     AND O.[Type] IN ('Store-A','STORE-R', 'WHOLESALE') -- Retail Orders    
   ORDER BY MD.OrderKey    --TK02

   OPEN C_ConsignmentNumber    
   FETCH NEXT FROM C_ConsignmentNumber INTO @cOrderKey, @cLabelNo, @cConsignmentNumber, @fCartonWeight    
    
   WHILE @@FETCH_STATUS <> -1     
   BEGIN    
      -- SHONG01 (Start)  
      IF EXISTS(SELECT 1 FROM TRANSMITLOG2 AS t WITH (NOLOCK) WHERE t.tablename = 'TNTSHPREQ' AND t.key1 = @cOrderKey)  
      BEGIN  
         SET @bProcessed = 1  
         GOTO NEXT   
      END  
      ELSE  
         SET @bProcessed = 0  
     -- SHONG01 (End)  
        
      SELECT     
         --@cOrderDate    = CONVERT(NVARCHAR(10), DeliveryDate, 103),  -- (Chee01)  
         @cOrderNotes   = RTRIM(ISNULL(Notes, '')),    
         @cFacility     = RTRIM(Facility),    
         @cLoadKey      = RTRIM(LoadKey),    
         @cConsigneeKey = RTRIM(ConsigneeKey),  
         @cOrderType    = [Type]   -- (Chee01)  
      FROM dbo.Orders WITH (NOLOCK)    
      WHERE OrderKey = @cOrderKey    
    
      --SET @cOrderDate    = CONVERT(NVARCHAR(10), GETDATE(), 103)    
      SELECT     
         @cFacilityAddress1 = RTRIM(Address1),    
         @cFacilityAddress2 = RTRIM(Address2),    
         @cFacilityAddress3 = RTRIM(Address3),    
         @cFacilityCity     = RTRIM(City),    
         @cFacilityState    = RTRIM(State),    
         @cFacilityZip      = RTRIM(Zip),    
         @cFacilityCountry  = RTRIM(Country)    
      FROM dbo.Facility WITH (NOLOCK)    
      WHERE Facility = @cFacility    
    
      IF EXISTS(SELECT 1 FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey AND [Type] = '2')    
      BEGIN  
         SELECT     
            @cStorerCompany  = RTRIM(Company),    
            @cStorerAddress1 = RTRIM(Address1),    
            @cStorerAddress2 = RTRIM(Address2),    
            @cStorerAddress3 = RTRIM(Address3),    
            @cStorerCity     = RTRIM(City),    
            @cStorerZip      = RTRIM(Zip),    
            @cStorerCountry  = RTRIM(Country),    
            @cStorerContact1 = RTRIM(Contact1),    
            @cStorerPhone1   = RTRIM(Phone1)    
         FROM dbo.Storer WITH (NOLOCK)    
         WHERE StorerKey = @cConsigneeKey    
           AND [Type] = '2'    
      END  
      ELSE    
      BEGIN  
         SELECT     
            @cStorerCompany  = RTRIM(Company),    
            @cStorerAddress1 = RTRIM(Address1),    
            @cStorerAddress2 = RTRIM(Address2),    
            @cStorerAddress3 = RTRIM(Address3),    
            @cStorerCity     = RTRIM(City),    
            @cStorerZip      = RTRIM(Zip),    
            @cStorerCountry  = RTRIM(Country),    
            @cStorerContact1 = RTRIM(Contact1),    
            @cStorerPhone1   = RTRIM(Phone1)    
         FROM dbo.Storer WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
      END  
  
      --NJOW02 
      SET @cProductOption = '1'
      --(Wan02) - START
      SELECT @cService = RTRIM(C.Code),
             @cOptionTueFri = RTRIM(ISNULL(C.Udf01,'')),
             @cOptionSat    = RTRIM(ISNULL(C.Udf02,'')),
             @cOptionMon    = RTRIM(ISNULL(C.Udf03,''))  
      FROM dbo.StorerSODefault SSD WITH (NOLOCK)    
      JOIN dbo.Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'TNTSRV' AND SSD.Terms = C.Code AND SSD.Storerkey = C.Storerkey
      WHERE SSD.StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END    
      AND ISNULL(Terms, '') <> '' 
      /*
      SELECT @cService = RTRIM(C.Code),
             @cOptionMonThu = RTRIM(ISNULL(C.Udf01,'')),
             @cOptionFriSat = RTRIM(ISNULL(C.Udf02,'')),
             @cOptionMon    = RTRIM(ISNULL(C.Udf03,'')) -- SHONG01
      FROM dbo.StorerSODefault SSD WITH (NOLOCK)    
      JOIN dbo.Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'TNTSRV' AND SSD.Terms = C.Code AND SSD.Storerkey = C.Storerkey
      WHERE SSD.StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END    
      AND ISNULL(Terms, '') <> ''    
      */ -- (Wan02) - END
      /*
      SELECT @cService = RTRIM(C.UDF01)    
      FROM dbo.StorerSODefault SSD WITH (NOLOCK)    
      JOIN dbo.Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'TNTSRV' AND SSD.Terms = C.Code     
      WHERE SSD.StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END    
        AND ISNULL(Terms, '') <> ''    
      */
    
      -- Get LoadPlan.LPUserDefDate01 (Chee01)  
      SELECT @dLPUserDefDate01 = LPUserDefDate01  
      FROM dbo.LoadPlan WITH (NOLOCK)  
      WHERE LoadKey = @cLoadKey  

      --(Wan02)  - START
      IF DATEPART(dw, @dLPUserDefDate01) = 2 --Monday 
      BEGIN
         SET @cProductOption = @cOptionMon
      END
      ELSE IF DATEPART(dw, @dLPUserDefDate01) = 7 --Saturday
      BEGIN
         SET @cProductOption = @cOptionSat
      END
      ELSE IF DATEPART(dw, @dLPUserDefDate01) IN (3,4,5,6) --Tues to Friday
      BEGIN
         SET @cProductOption = @cOptionTueFri
      END     
      ELSE      
      BEGIN
         SET @cProductOption = '1'
      END      

      /*
      --NJOW02
      IF DATEPART(dw, @dLPUserDefDate01) = 6 --Friday 
      BEGIN
         SET @cProductOption = @cOptionFriSat
      END
      --ELSE IF DATEPART(dw, @dLPUserDefDate01) = 1 --Sunday
      ELSE IF DATEPART(dw, @dLPUserDefDate01) IN (1,7) --Sunday & Saturday (SHONG01)
      BEGIN
         SET @cProductOption = @cOptionSatSunMon
      END
      ELSE IF DATEPART(dw, @dLPUserDefDate01) IN (2,3,4,5) --Mon to Thu
      BEGIN
         SET @cProductOption = @cOptionMonThu         
      END     
      ELSE      
      BEGIN
         SET @cProductOption = '1'
      END      
      */  
      --(Wan02)  - END            
      -- Set Service for weekend delivery (Chee01)   
      IF DATEPART(dw, @dLPUserDefDate01) = 6 -- FRIDAY  
         AND @cOrderType LIKE 'STORE%'  
         --AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'TNTSATDEL' AND Code = @cConsigneeKey)  
      BEGIN  
  
         SELECT @cService = RTRIM(SUSR4)  
         FROM dbo.STORER WITH (NOLOCK)   
         WHERE StorerKey = ISNULL(RTRIM(@cConsigneeKey), '')  
         --TK01 - E  
           
      END  
  
      SELECT     
         @fGoodsValue = ISNULL(SUM(PD.Qty * ISNULL(CAST(REPLACE(REPLACE(REPLACE(CS.UDF01, 'ú', ''), '$', ''), 'Ç', '') AS FLOAT), 0)), 0),      
         @nPackDetailQty = ISNULL(SUM(PD.Qty), 0),       
         @c_UDF01 = MIN(ISNULL(CS.UDF01,'')), --NJOW01   
         @c_UDF03 = MIN(ISNULL(CS.UDF03,''))  --NJOW01  
      FROM dbo.PackDetail PD (NOLOCK)    
      JOIN dbo.ConsigneeSKU CS (NOLOCK) ON PD.Sku = CS.Sku     
      WHERE PD.LabelNo = @cLabelNo     
        AND CS.ConsigneeKey = @cConsigneeKey    

      -- (james01)
      -- goods value and insurance values are populated with ?00.00 if the goods and insurance value are zero 
      IF @fGoodsValue = 0 
         SET @fGoodsValue = 200

      EXEC dbo.nspGetRight  
         NULL,  
         @cStorerKey,  
         NULL,  
         'NoSundayTNTDelivery',  
         @bSuccess               OUTPUT,  
         @cNoSundayTNTDelivery   OUTPUT,  
         @nErr                   OUTPUT,  
         @cErrMsg                OUTPUT  
  
      IF NOT @bSuccess = 1  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 90015  
         SET @cErrmsg = 'nspGetRight NoSundayTNTDelivery Failed. (isp_WS_TNT_ShipmentRequest)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO Quit  
      END  
  
      /* --NJOW02 Remark
      IF @cNoSundayTNTDelivery = '1' AND DATEPART(dw, @dLPUserDefDate01) = 1 -- SUNDAY  
         SET @dLPUserDefDate01 = DATEADD(dd, 1, @dLPUserDefDate01)  
      */
  
      -- Set LoadPlan.LPUserDefDate01 as OrderDate (Chee01)  
      SET @cOrderDate = CONVERT(NVARCHAR(10), @dLPUserDefDate01, 103)  
      
      
      -- Create XML Request String                  
      SET @xRequestString =                  
      (                  
         SELECT                   
            (    
               SELECT    
                  @cTNTNetworkUserName  "COMPANY",    
                  @cTNTNetworkPassword  "PASSWORD",    
                  'EC'                  "APPID",    
                  '2.2'                 "APPVERSION"    
               FOR XML PATH('LOGIN'), TYPE -- ESHIPPER/LOGIN               
            ),    
            (    
               SELECT    
               (    
                  SELECT    
                     'LF Logistics'                 "COMPANYNAME",    
                     @cFacilityAddress1             "STREETADDRESS1",    
                     @cFacilityAddress2             "STREETADDRESS2",    
                     @cFacilityAddress3             "STREETADDRESS3",    
                     @cFacilityCity                 "CITY",    
                     @cFacilityState                "PROVINCE",  
                     @cFacilityZip                  "POSTCODE",    
                     @cFacilityCountry              "COUNTRY",    
                     @cAccountNumber                "ACCOUNT",    
                     ''                             "VAT",    
                     'Supervisor'                   "CONTACTNAME",    
                     '0114'                         "CONTACTDIALCODE",    
                     '2613021'                      "CONTACTTELEPHONE",    
                     'servicedesk@lfeurope.com'     "CONTACTEMAIL",    
                     (    
                        SELECT    
                           (    
                              SELECT    
                                 'LF Logistics'                  "COMPANYNAME",    
                                 @cFacilityAddress1              "STREETADDRESS1",    
                                 @cFacilityAddress2              "STREETADDRESS2",    
                                 @cFacilityAddress3              "STREETADDRESS3",    
                                 @cFacilityCity                  "CITY",    
                                 @cFacilityState                 "PROVINCE",    
                                 @cFacilityZip                   "POSTCODE",    
                                 @cFacilityCountry               "COUNTRY",    
                                 ''                              "VAT",    
                                 'Shift Supervisor'              "CONTACTNAME",    
                                 '0114'                          "CONTACTDIALCODE",    
                                 '2613021'                       "CONTACTTELEPHONE",    
                                 'servicedesk@lfeurope.com'      "CONTACTEMAIL"    
                              FOR XML PATH('COLLECTIONADDRESS'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/SENDER/COLLECTION/COLLECTIONADDRESS              
                           ),    
                           @cOrderDate                           "SHIPDATE",    
                           '14:00'                               "PREFCOLLECTTIME/FROM",    
                           '14:59'                               "PREFCOLLECTTIME/TO",    
                           '15:00'                               "ALTCOLLECTTIME/FROM",    
                           '16:00'                               "ALTCOLLECTTIME/TO",    
                           'Book in with security upon arrival'  "COLLINSTRUCTIONS"    
                        FOR XML PATH('COLLECTION'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/SENDER/COLLECTION            
                     )    
                  FOR XML PATH('SENDER'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/SENDER    
               ),    
               (    
                  SELECT    
                     @cConsignmentNumber  "CONREF",    
                     (    
                        SELECT    
                           (    
                              SELECT    
                                 @cStorerKey + @cStorerCompany                         "COMPANYNAME",    
                                 @cStorerAddress1                                      "STREETADDRESS1",    
                                 @cStorerAddress2                                      "STREETADDRESS2",    
                                 @cStorerAddress3                                      "STREETADDRESS3",    
                                 @cStorerCity                                          "CITY",    
                                 @cStorerZip                                           "POSTCODE",    
                                 @cStorerCountry                                       "COUNTRY",    
                                 @cStorerContact1                                      "CONTACTNAME",    
                                                 LEFT(@cStorerPhone1, 4)                               "CONTACTDIALCODE",    
                                 CASE WHEN LEN(@cStorerPhone1) > 4 THEN     
                                 SUBSTRING(@cStorerPhone1, 5, LEN(@cStorerPhone1)-1)     
                                 ELSE '' END                                           "CONTACTTELEPHONE"  
                              FOR XML PATH('RECEIVER'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/CONSIGNMENT/DETAILS/RECEIVER    
                           ),    
                           (    
                              SELECT    
                                 @cStorerKey + @cStorerCompany                    "COMPANYNAME",    
                                 @cStorerAddress1                                      "STREETADDRESS1",    
                                 @cStorerAddress2                                      "STREETADDRESS2",    
                                 @cStorerAddress3                                      "STREETADDRESS3",    
                                 @cStorerCity                                          "CITY",    
                                 @cStorerZip                                           "POSTCODE",    
                                 @cStorerCountry                                       "COUNTRY",    
                                 @cStorerContact1                                      "CONTACTNAME",    
                                 LEFT(@cStorerPhone1, 4)                               "CONTACTDIALCODE",    
                                 CASE WHEN LEN(@cStorerPhone1) > 4 THEN     
                                 SUBSTRING(@cStorerPhone1, 5, LEN(@cStorerPhone1)-1)     
                                 ELSE '' END                                           "CONTACTTELEPHONE"    
                              FOR XML PATH('DELIVERY'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/CONSIGNMENT/DETAILS/DELIVERY    
                           ),    
                           @cConsignmentNumber                 "CONNUMBER",    
                           'APPAREL'                           "CUSTOMERREF",    
                           'N'                                 "CONTYPE",    
                           'S'                                 "PAYMENTIND",    
                           '1'                                 "ITEMS",    
                           '10'                                "TOTALWEIGHT",    
                           '0.001'                             "TOTALVOLUME",    
                           CASE WHEN @fGoodsValue = 0 THEN '' ELSE 'GBP' END 
                                                               "CURRENCY",    
                           CAST(@fGoodsValue AS NUMERIC(18,2)) "GOODSVALUE",    
                           CAST(@fGoodsValue AS NUMERIC(18,2)) "INSURANCEVALUE",    
                           CASE WHEN @fGoodsValue = 0 THEN '' ELSE 'GBP' END                        
                                                               "INSURANCECURRENCY",    
                           @cService                           "SERVICE",    
                           @cProductOption                     "OPTION", --NJOW02
                           'APPAREL'                           "DESCRIPTION",    
                           @cOrderNotes                        "DELIVERYINST",    
                           (    
                              SELECT                      
                                 '1'                                    "ITEMS",        
                                 'SACK'                                 "DESCRIPTION",        
                                 '0.001'                                "LENGTH",        
                                 '0.001'                                "HEIGHT",        
                                 '0.001'                                "WIDTH",        
                                 '10'                                   "WEIGHT"
                              FOR XML PATH('PACKAGE'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/CONSIGNMENT/DETAILS/PACKAGE    
                           )    
                        FOR XML PATH('DETAILS'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/CONSIGNMENT/DETAILS    
                     )    
                  FOR XML PATH('CONSIGNMENT'), TYPE -- ESHIPPER/CONSIGNMENTBATCH/CONSIGNMENT    
               )    
               FOR XML PATH('CONSIGNMENTBATCH'), TYPE -- ESHIPPER/CONSIGNMENTBATCH               
            ),    
            (    
               SELECT    
                  @cConsignmentNumber   "CREATE/CONREF",    
                  @cConsignmentNumber   "SHIP/CONREF"    
               FOR XML PATH('ACTIVITY'), TYPE -- ESHIPPER/ACTIVITY               
            )    
         FOR XML PATH(''),                  
         ROOT('ESHIPPER')                  
      )    
    
      -- Create Request String    
      SET @cRequestString = 'xml_in=' + @cXMLEncodingString + CAST(@xRequestString AS NVARCHAR(MAX))    
    
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
                         @cRequestString, @cStatus, 'C', 'R', @cLabelNo, 'isp_WS_TNT_ShipmentRequest'     
    
      IF @@ERROR <> 0      
      BEGIN      
         SET @bSuccess = 0    
         SET @nErr = 90004    
         SET @cErrmsg = 'Error inserting into WebService_Log Table. (isp_WS_TNT_ShipmentRequest)'    
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next    
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
         SET @nErr = 90005         
         SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp_WS_TNT_ShipmentRequest)'              
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next            
      END      
          
      IF @nDebug = 1            
      BEGIN            
         SELECT @cWSClientContingency AS '@cWSClientContingency'          
      END       
    
      SET @dTimeIn = GETDATE()    
    
      IF @cWSClientContingency <> '1'      
      BEGIN 
              
         EXEC [master].[dbo].[isp_GenericWebServiceClient] @cIniFilePath
                                                         , @cWebRequestURL
                                                         , @cWebRequestMethod --@c_WebRequestMethod
                                                         , @cContentType --@c_ContentType
                                                         , @cWebRequestEncoding --@c_WebRequestEncoding
                                                         , @cRequestString --@c_FullRequestString
                                                         , @cResponseString OUTPUT
                                                         , @cVBErrMsg OUTPUT                                                
                                                         , 0 --@n_WebRequestTimeout -- Miliseconds
                                                         , @cTNTNetworkUserName --@c_NetworkCredentialUserName -- leave blank if no network credential
                                                         , @cTNTNetworkPassword --@c_NetworkCredentialPassword -- leave blank if no network credential
                                                         , 0 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
                                                         , '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
                                                         , '' --@c_HeaderAuthorization
                                                         , '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
         --(KT01) - End
                           
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''            
         BEGIN            
            SET @cStatus = '5'            
            SET @bSuccess = 0            
            SET @nErr = 90006      
                  
            -- SET @cErrmsg            
            IF ISNULL(@cVBErrMsg,'') <> ''            
            BEGIN            
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))            
            END            
            ELSE            
            BEGIN            
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp_WS_TNT_ShipmentRequest)'            
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
            @cTNTNetworkUserName,    
            @cTNTNetworkPassword    
             
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''            
         BEGIN            
            SET @cStatus = '5'            
            SET @bSuccess = 0            
            SET @nErr = 90007     
                  
            -- SET @cErrmsg            
            IF ISNULL(@cVBErrMsg,'') <> ''            
            BEGIN            
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))            
            END            
            ELSE            
            BEGIN            
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp_WS_TNT_ShipmentRequest)'            
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
         SET @nErr = 90008    
         SET @cErrmsg = 'Error updating WebService_Log Table. (isp_WS_TNT_ShipmentRequest)'    
                       + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next    
      END      
    
      IF @cStatus = '5'    
      BEGIN    
         GOTO Next    
      END    
    
      SET @cResponseNumber = REPLACE(@cResponseString, 'COMPLETE:', '')    
    
      -- Send another XML to get xml response    
      SET @cRequestString = 'xml_in=GET_RESULT:' + @cResponseNumber    
    
      IF @nDebug = 1    
         SELECT @cRequestString AS 'Request String'    
         
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
                         @cRequestString, @cStatus, 'C', 'R', @cLabelNo, 'isp_WS_TNT_ShipmentRequest'     
    
      IF @@ERROR <> 0      
      BEGIN      
         SET @bSuccess = 0    
         SET @nErr = 90009    
         SET @cErrmsg = 'Error inserting into WebService_Log Table. (isp_WS_TNT_ShipmentRequest)'    
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next    
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
         SET @nErr = 90010         
         SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp_WS_TNT_ShipmentRequest)'              
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next            
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
         --   @cTNTNetworkUserName,    
         --   @cTNTNetworkPassword    
              
         EXEC [master].[dbo].[isp_GenericWebServiceClient] @cIniFilePath
                                                         , @cWebRequestURL
                                                         , @cWebRequestMethod --@c_WebRequestMethod
                                                         , @cContentType --@c_ContentType
                                                         , @cWebRequestEncoding --@c_WebRequestEncoding
                                                         , @cRequestString --@c_FullRequestString
                                                         , @cResponseString OUTPUT
                                                         , @cVBErrMsg OUTPUT                                                
                                                         , 0 --@n_WebRequestTimeout -- Miliseconds
                                                         , @cTNTNetworkUserName --@c_NetworkCredentialUserName -- leave blank if no network credential
                                                         , @cTNTNetworkPassword --@c_NetworkCredentialPassword -- leave blank if no network credential
                                                         , 0 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
                                                         , '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
                                                         , '' --@c_HeaderAuthorization
                                                         , '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
         --(KT01) - End
                           
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''            
         BEGIN            
            SET @cStatus = '5'            
            SET @bSuccess = 0            
            SET @nErr = 90011      
                  
            -- SET @cErrmsg            
            IF ISNULL(@cVBErrMsg,'') <> ''            
            BEGIN            
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))            
            END            
            ELSE            
            BEGIN            
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp_WS_TNT_ShipmentRequest)'            
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
            @cTNTNetworkUserName,    
            @cTNTNetworkPassword    
             
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''            
         BEGIN            
            SET @cStatus = '5'            
            SET @bSuccess = 0            
            SET @nErr = 90012     
                  
            -- SET @cErrmsg            
            IF ISNULL(@cVBErrMsg,'') <> ''            
            BEGIN            
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))            
            END            
            ELSE            
            BEGIN            
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp_WS_TNT_ShipmentRequest)'            
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
         SET @nErr = 90013    
         SET @cErrmsg = 'Error updating WebService_Log Table. (isp_WS_TNT_ShipmentRequest)'    
                       + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         GOTO Next    
      END      
  
      IF @cStatus = '5'    
      BEGIN    
         GOTO Next    
      END    
      
      IF cast(@xResponseString as NVARCHAR(max)) = ''  
      BEGIN  
         SET @cStatus = '5'  
         SET @nErrorCode = '50001'  
         SET @cErrorDescription = 'No Response'  
      END  
      ELSE  
      BEGIN  
         -- Extract ResponseString Data        
         EXEC sp_xml_preparedocument @ndoc OUTPUT, @xResponseString        
       
         SELECT     
            @nErrorCode               = errorCode,    
            @cErrorDescription        = errorDescription    
         FROM OPENXML (@ndoc, '/document', 2)      
         WITH(      
            errorCode                INT           'ERROR/CODE',    
            errorDescription         NVARCHAR(250) 'ERROR/DESCRIPTION'    
         )     
       
         EXEC sp_xml_removedocument @ndoc    
      END  
      --(Wan01) - Fixed Error - The XML parse error 0xc00ce558 occurred on line number 1, near the XML text"" (END)  
  
      IF @nDebug = 1      
      BEGIN      
         SELECT      
            @nErrorCode               AS 'errorCode',    
            @cErrorDescription        AS 'errorDescription'    
      END      
    
      -- Response Failed                  
      IF ISNULL(@nErrorCode, 0) > 0                 
      BEGIN                  
         SET @bSuccess = 0                   
         SET @nErr = 90014                   
         SET @cErrmsg = CAST(@nErrorCode AS NVARCHAR) + ' - ' + @cErrorDescription + ' (isp_WS_TNT_ShipmentRequest)'                    
                       + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'    
     
  
         --NJOW01  
         INSERT INTO @tError (OrderKey, LabelNo, ConsignmentNumber, ErrMsg, Storerkey, Consigneekey, City, ZipCode)  
         VALUES (@cOrderKey, @cLabelNo, @cConsignmentNumber, @cErrMsg, @cStorerKey, @cConsigneeKey, @cStorerCity, @cStorerZip)  
    
         GOTO Next                  
      END    
    
Next:    
      IF @cStatus = '9' AND @bProcessed = 0  
      BEGIN  

         --TK02
         IF @cPrevOrderKey = ''
         BEGIN 
            SET @cPrevOrderKey = @cOrderKey
         END

         --TK02 - Only insert to TL2 when all consignment of the order complete successfully
         IF @cPrevOrderKey <> @cOrderKey
         BEGIN

            EXEC ispGenTransmitLog2  
               @c_TableName = 'TNTSHPREQ',  
               @c_Key1 = @cPrevOrderKey,   --@cOrderKey,     --TK02 - Insert previous completed orderKey
               @c_Key2 = '',  
               @c_Key3 = @cStorerKey,  
               @c_TransmitBatch = '',  
               @b_Success = 1,  
               @n_err = 0,  
               @c_errmsg = ''  

            SET @cPrevOrderKey = @cOrderKey     --TK02 - Store the current OrderKey

         END
      END  
        
      IF (@c_UDF01 = '' OR @c_UDF03 = '') --NJOW01  
         AND @bProcessed = 0 --SHONG01    
      BEGIN  
         SET @bSuccess = 0                 
         SET @nErr = 90018                 
         SET @cErrmsg = 'Empty UDF01 or UDF03 of ConsigneeSku. (isp_WS_TNT_ShipmentRequest)'            
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'  
  
         -- SendEmail Alert  
         INSERT INTO @tError (OrderKey, LabelNo, ConsignmentNumber, ErrMsg, Storerkey, Consigneekey, City, ZipCode)  
         VALUES (@cOrderKey, @cLabelNo, @cConsignmentNumber, @cErrMsg, @cStorerKey, @cConsigneeKey, @cStorerCity, @cStorerZip)  
      END  
      -- Initial Status back to '9' (SHONG01)  
      SET @cStatus = '9'  
        
      FETCH NEXT FROM C_ConsignmentNumber INTO @cOrderKey, @cLabelNo, @cConsignmentNumber, @fCartonWeight    
   END  -- While Fetch Status  
   CLOSE C_ConsignmentNumber    
   DEALLOCATE C_ConsignmentNumber    
    
Quit:    
   -- Send Email Alert    
   IF EXISTS(SELECT 1 FROM @tError)    
   BEGIN    
      INSERT INTO TraceInfo  
      (  
         TraceName,    TimeIn,       [TimeOut],  
         TotalTime,    Step1,        Step2,  
         Step3,        Step4,        Step5,  
         Col1,         Col2,         Col3,  
         Col4,         Col5  
      )  
      SELECT 'isp_WS_TNT_ShipmentRequest', GETDATE(), GETDATE(), '',   
      OrderKey, LabelNo, ConsignmentNumber, LEFT(ErrMsg, 20), Storerkey,   
      Consigneekey, City, ZipCode, '', ''  
      FROM @tError AS te  
        
       
      SELECT @cRecipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END     
                          + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END      
                          + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END      
                          + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END     
                          + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END     
      FROM dbo.CODELKUP WITH (NOLOCK)    
      WHERE LISTNAME  = 'TLOG3ExtSP'    
        AND Code      = @cTableName    
        AND StorerKey = @cStorerKey    
    
      IF ISNULL(@cRecipients, '') <> ''    
      BEGIN    
         SET @cSubject = 'TNT Shipment Request Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')    
    
         SET @cBody = '<b>Error Response from TNT Shipment Request:</b><br/><br/>'    
         SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +    
             '<tr bgcolor=silver><th>OrderKey</th><th>LabelNo</th><th>ConsignmentNumber</th><th>Storer</th><th>Consignee</th><th>City</th><th>Zip</th><th>Error</th></tr>' + CHAR(13) +   --NJOW01  
             CAST ( ( SELECT td = ISNULL(OrderKey,''), '',    
                             td = ISNULL(LabelNo,''), '',      
                             td = ISNULL(ConsignmentNumber,''), '',      
                             td = ISNULL(Storerkey,''), '',      --NJOW01  
                             td = ISNULL(Consigneekey,''), '',   --NJOW01  
                             td = ISNULL(City,''), '',       --NJOW01  
                             td = ISNULL(ZipCode,''), '',    --NJOW01  
                             td = ISNULL(ErrMsg,'')    
                      FROM @tError    
                 FOR XML PATH('tr'), TYPE       
             ) AS NVARCHAR(MAX) ) + '</table>' ;      
    
         EXEC msdb.dbo.sp_send_dbmail     
               @recipients      = @cRecipients,    
               @copy_recipients = NULL,    
               @subject         = @cSubject,    
               @body            = @cBody,    
               @body_format     = 'HTML' ;    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @bSuccess = 0    
            SET @nErr = 90003    
            SET @cErrmsg = 'Error executing sp_send_dbmail. (isp_WS_TNT_ShipmentRequest)'    
                         + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'    
         END    
      END -- IF ISNULL(@cRecipients, '') <> ''    
   END -- IF EXISTS(SELECT 1 FROM @tError)    
    
   IF (SELECT CURSOR_STATUS('LOCAL','C_ConsignmentNumber')) >=0    
   BEGIN    
      CLOSE C_ConsignmentNumber    
      DEALLOCATE C_ConsignmentNumber    
   END    
    
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL    
      DROP TABLE #StoreSeqNoTempTable;    
    
   WHILE @nTrancount > @@TRANCOUNT    
      COMMIT TRAN    
    
END -- Procedure    
  



GO