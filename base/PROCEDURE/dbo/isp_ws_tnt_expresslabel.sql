SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_WS_TNT_ExpressLabel                                          */
/* Creation Date: 24 Jul 2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send ExpressLabel web service request to TNT                */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: rdt.rdtfnc_Ecomm_Dispatch                                 */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/* 24-07-2014   Chee     1.0      Initial Version SOS#316568            */
/* 21-10-2014   Chee     1.1      Fix RDT user permission error when    */
/*                                sending email alert (Chee02)          */
/* 18-11-2014   CSCHONG  1.2      SOS325827 (CS01)                      */
/* 15-Dec-2015  NJOW01   1.3      358914-TNT shipment enhancements      */
/* 06-Apr-2016  CSCHONG  1.4      367364-Update service code (CS02)     */
/* 20-Jul-2016  KTLow    1.5      Add WebService Client Parameter (KT01)*/
/* 05-Dec-2016  Wan01    1.6      JIRA WMS-739                          */
/************************************************************************/

CREATE PROC [dbo].[isp_WS_TNT_ExpressLabel](
    @nMobile         INT
   ,@cPickSlipNo     NVARCHAR(10)  
   ,@nCartonNo       INT  
   ,@cLabelNo        NVARCHAR(20)  
   ,@bSuccess        INT            OUTPUT  
   ,@nErr            INT            OUTPUT  
   ,@cErrMsg         NVARCHAR(215)  OUTPUT
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
      @cXMLNamespace          NVARCHAR(100),
      @cRequestString         NVARCHAR(MAX),
      @cResponseString        NVARCHAR(MAX),
      @cVBErrMsg              NVARCHAR(MAX),
      @xRequestString         XML,
      @xResponseString         XML,
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
      @cTNTNetworkPassword    NVARCHAR(100)

   DECLARE
      @cListName              NVARCHAR(10),
      @cCode_FilePath         NVARCHAR(30),
      @cCode_ConnString       NVARCHAR(30),
      @cCode_TNTExpressLabel  NVARCHAR(30),
      @cWSClientContingency   NVARCHAR(1),   
      @cConnectionString      NVARCHAR(250),
      @cStorerKey             NVARCHAR(15),
      @cWebServiceLogDBName   NVARCHAR(30),
      @cExecStatements        NVARCHAR(4000),
      @cExecArguments         NVARCHAR(4000)

   DECLARE 
      @cConsignmentNumber     NVARCHAR(10),
      @cLoadKey NVARCHAR(10),
      @cOrderKey              NVARCHAR(10),
      @cOrderNotes            NVARCHAR(4000),
      @cConsigneeKey          NVARCHAR(15),
      @cFacility              NVARCHAR(5),
      @cOrderDate             NVARCHAR(19),
      @cSenderName            NVARCHAR(40),
      @cFacilityAddress2      NVARCHAR(30),      --(CS01)
      @cFacilityCity          NVARCHAR(45),
      @cSenderExactMatch      NVARCHAR(1),
      @cSenderProvince        NVARCHAR(45),
      @cFacilityZip           NVARCHAR(18),
      @cFacilityCountry       NVARCHAR(30),
      @cStorerCompany         NVARCHAR(30),       --(CS01)
      @cStorerAddress1        NVARCHAR(30),       --(CS01)
      @cStorerCity            NVARCHAR(90),
      @cDeliveryExactMatch    NVARCHAR(1),
      @cDeliveryProvince      NVARCHAR(45),
      @cStorerZip             NVARCHAR(18),
      @cStorerCountry         NVARCHAR(30),
      @cProductLineOfBusiness NVARCHAR(10),
      @cProductGroupID        NVARCHAR(10),
      @cProductSubGroupID     NVARCHAR(10),
      @cProductID             NVARCHAR(10),
      @cProductType           NVARCHAR(10),
      @cProductOption         NVARCHAR(10),
      @cAccountNumber         NVARCHAR(10),
      @cAccountCountry        NVARCHAR(10),
      @cIdentifier            NVARCHAR(10),
      @cGoodsDescription      NVARCHAR(40),
      @fPackLength            FLOAT,
      @fPackWidth             FLOAT,
      @fPackHeight            FLOAT,
      @fPackWeight            FLOAT,
      @nSequenceNumbers       INT,
      @nConsignmentNumber     INT,
      @nStartConNumber        INT,
      @nEndConNumber          INT,
      @nConNumberThreshold    INT,
      @cEmailRecipient1       NVARCHAR(60),
      @cEmailRecipient2       NVARCHAR(60),
      @cEmailRecipient3       NVARCHAR(60),
      @cEmailRecipient4       NVARCHAR(60),
      @cEmailRecipient5       NVARCHAR(60),
      @bSendEmail             INT,
      @cRecipients            NVARCHAR(MAX),
      @cBody                  NVARCHAR(MAX),
      @cSubject               NVARCHAR(255),
      @dLPUserDefDate01       DATETIME, --NJOW01
      @cOptionMonThu          NVARCHAR(30), --NJOW02
      @cOptionFriSat          NVARCHAR(30), --NJOW03
      @cOptionSunMon          NVARCHAR(30), --NJOW01
      @cOptionTueFri          NVARCHAR(30), --(Wan01)
      @cOptionSat             NVARCHAR(30), --(Wan01)
      @cOptionMon             NVARCHAR(30)  --(Wan01)

   DECLARE
      @nErrorCode             INT,
      @cErrorDescription      NVARCHAR(250),
      @c128CBarcode           NVARCHAR(30),
      @cProduct               NVARCHAR(20),
      @cOriginDepotCode       NVARCHAR(5),
      @cDestinationDepotCode  NVARCHAR(5),
      @cDueDayOfMonth         NVARCHAR(5),
      @cClusterCode           NVARCHAR(18),
      @dLoaddate              DATETIME   --(CS02)
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   CREATE TABLE #StoreSeqNoTempTable(SeqNo INT) 

   SET @nDebug      = 0

   SET @bSuccess    = 1
   SET @nErr        = 0
   SET @cErrmsg     = ''
   SET @bSendEmail  = 0

   SET @cStatus               = '9'
   SET @cBatchNo              = ''

   SET @cWebRequestMethod    = 'POST'
   SET @cContentType         = 'application/x-www-form-urlencoded' 
   SET @cWebRequestEncoding  = 'UTF-8'
   SET @cXMLEncodingString   = '<?xml version="1.0" encoding="UTF-8"?>'

   -- Default Value
   SET @cSenderName            = 'LF Logistics'
   SET @cSenderExactMatch      = 'Y'
   SET @cSenderProvince        = ''
   SET @cDeliveryExactMatch    = 'Y'
   SET @cDeliveryProvince      = ''
   SET @cProductLineOfBusiness = '1'
   SET @cProductGroupID        = '0'
   SET @cProductSubGroupID     = '0'
   SET @cProductType           = 'N'
   SET @cProductOption         = '1'
   SET @cAccountCountry        = 'GB'
   SET @cIdentifier            = '1'
   SET @cGoodsDescription      = 'piecelinegoods desc'
   SET @fPackLength            = 2.00
   SET @fPackWidth             = 1.00
   SET @fPackHeight            = 1.00
   SET @nSequenceNumbers       = 1

   -- Get WebService_Log DB Name
   SELECT @cWebServiceLogDBName = NSQLValue  
   FROM dbo.NSQLConfig WITH (NOLOCK)  
   WHERE ConfigKey = 'WebServiceLogDBName' 

   IF ISNULL(@cWebServiceLogDBName, '') = ''
   BEGIN
      SET @bSuccess = 0  
      SET @nErr = 80000
      SET @cErrmsg = 'NSQLConfig - WebServiceLogDBName is empty. (isp_WS_TNT_ExpressLabel)'
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
      SET @nErr = 80001
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp_WS_TNT_ExpressLabel)'
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
     AND Code = 'TNTExpressLabelURL'

   IF ISNULL(@cWebRequestURL,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 80002
      SET @cErrmsg = 'Web Service Request URL is empty. (isp_WS_TNT_ExpressLabel)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @nDebug = 1
   BEGIN
      SELECT @cWebServiceLogDBName AS 'Table WebService_Log DB Name',
             @cIniFilePath AS 'WSConfig.ini File Path',
             @cWebRequestURL AS 'Web Service Request URL'
   END

   EXECUTE dbo.nspg_GetKey    
         'TNTConNumber',    
         10,    
         @cConsignmentNumber OUTPUT,    
         @bSuccess           OUTPUT,    
         @nErr               OUTPUT,    
         @cErrMsg            OUTPUT    

   IF @bSuccess <> 1    
   BEGIN    
      SET @bSuccess = 0  
      SET @nErr = 80003
      SET @cErrmsg = 'Unable to retrieve new Consignment Number. (isp_WS_TNT_ExpressLabel)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit 
   END  

  SELECT 
      @nConNumberThreshold = ISNULL(Short, 0),
      @nStartConNumber     = ISNULL(Long, 0),
      @nEndConNumber       = ISNULL(Notes, 0),
      @cEmailRecipient1    = ISNULL(RTRIM(UDF01), ''),
      @cEmailRecipient2    = ISNULL(RTRIM(UDF02), ''),
      @cEmailRecipient3    = ISNULL(RTRIM(UDF03), ''),
      @cEmailRecipient4    = ISNULL(RTRIM(UDF04), ''),
      @cEmailRecipient5    = ISNULL(RTRIM(UDF05), '')
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'TNT'
     AND Code = 'ConNumberRange'

   SET @nConsignmentNumber = @cConsignmentNumber

   -- Not Within ConNumber Range
   IF @nConsignmentNumber < @nStartConNumber OR @nConsignmentNumber > @nEndConNumber 
   BEGIN    
      SET @bSuccess = 0  
      SET @nErr = 80004
      SET @cErrmsg = 'Not within Consignment Number range. (isp_WS_TNT_ExpressLabel)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit 
   END 

   -- Hit Threshold, Send Email Alert
   IF @nConsignmentNumber + @nConNumberThreshold >= @nEndConNumber
      SET @bSendEmail = 1

   -- Trim Leading Zero
   SET @cConsignmentNumber = CAST(@nConsignmentNumber AS NVARCHAR)

   SELECT @cOrderKey = RTRIM(OrderKey)
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo

   SELECT 
      @cOrderDate    = CONVERT(NVARCHAR(19), OrderDate, 126),
      @cOrderNotes   = RTRIM(Notes),
      @cFacility     = RTRIM(Facility),
      @cStorerKey    = RTRIM(StorerKey),
      @cLoadKey      = RTRIM(LoadKey),
      @cConsigneeKey = RTRIM(ConsigneeKey)
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   --NJOW01 
   SELECT @dLPUserDefDate01 = LPUserDefDate01,@dLoaddate = adddate       --(CS02)  
   FROM dbo.LoadPlan WITH (NOLOCK)  
   WHERE LoadKey = @cLoadKey  

   --(Wan01) - START
   SELECT @cOptionTueFri = RTRIM(ISNULL(C.Udf01,'')),
          @cOptionSat    = RTRIM(ISNULL(C.Udf02,'')),
          @cOptionMon    = RTRIM(ISNULL(C.Udf03,''))  
   FROM dbo.StorerSODefault SSD WITH (NOLOCK)    
   JOIN dbo.Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'TNTSRV' AND SSD.Terms = C.Code AND SSD.Storerkey = C.Storerkey
   WHERE SSD.StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END    
   AND ISNULL(Terms, '') <> ''
   
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
   SELECT @cOptionMonThu = RTRIM(ISNULL(C.Udf01,'')),
          @cOptionFriSat = RTRIM(ISNULL(C.Udf02,'')),
          @cOptionSunMon = RTRIM(ISNULL(C.Udf03,''))
   FROM dbo.StorerSODefault SSD WITH (NOLOCK)    
   JOIN dbo.Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'TNTSRV' AND SSD.Terms = C.Code AND SSD.Storerkey = C.Storerkey
   WHERE SSD.StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END    
   AND ISNULL(Terms, '') <> ''    

   IF DATEPART(dw, @dLPUserDefDate01) IN (7)--= 6 --Friday   --(CS02)
   BEGIN
      SET @cProductOption = @cOptionFriSat
   END
   ELSE IF DATEPART(dw, @dLPUserDefDate01) = 2 --Mon           --(CS02)
   /*CS02 Start*/
   BEGIN
      IF DATEPART(dw, @dLoaddate) = 6
      BEGIN
         SET @cProductOption = @cOptionMonThu 
      END
      ELSE IF DATEPART(dw, @dLoaddate) = 1
      BEGIN
         SET @cProductOption = @cOptionSunMon
      END
   END
   /*CS02 End*/
   ELSE IF DATEPART(dw, @dLPUserDefDate01) IN (3,4,5,6) --Mon to Fri --(CS02)
   BEGIN
      SET @cProductOption = @cOptionMonThu         
   END
   ELSE      
   BEGIN
      SET @cProductOption = '1'
   END      
   --NJOW01 e
   */
   --(Wan01) - END

   SELECT 
      @cFacilityAddress2 = CAST(RTRIM(Address2) as nchar(30)),   --(CS01)
      @cFacilityCity     = RTRIM(City),
      @cFacilityZip      = RTRIM(Zip),
      @cFacilityCountry  = RTRIM(Country)
   FROM dbo.Facility WITH (NOLOCK)
   WHERE Facility = @cFacility

   IF EXISTS(SELECT 1 FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey AND [Type] = '2')
   BEGIN
      SELECT 
         @cStorerCompany  = CAST(RTRIM(Company) AS NCHAR(30)),    --(CS01)
         @cStorerAddress1 = CAST(RTRIM(Address1) as nchar(30)),   --(CS01)
         @cStorerCity     = RTRIM(City),
         @cStorerZip      = RTRIM(Zip),
         @cStorerCountry  = RTRIM(Country)
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cConsigneeKey
        AND [Type] = '2'
   END
   ELSE
   BEGIN
      SELECT 
         @cStorerCompany  = CAST(RTRIM(Company) AS NCHAR(30)),         --(cs01)
         @cStorerAddress1 = CAST(RTRIM(Address1) as nchar(30)) ,       --(CS01)
         @cStorerCity     = RTRIM(City),
         @cStorerZip      = RTRIM(Zip),
         @cStorerCountry  = RTRIM(Country)
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
   END

   SET @cProductID = 'EX'
   SELECT @cProductID = RTRIM(Terms)
   FROM dbo.StorerSODefault WITH (NOLOCK) 
   WHERE StorerKey = CASE WHEN ISNULL(@cConsigneeKey, '') <> '' THEN @cConsigneeKey ELSE @cStorerKey END
     AND ISNULL(Terms, '') <> ''

   SELECT @fPackWeight = SUM(PD.Qty * ISNULL(SKU.STDGrossWGT, 0)) 
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE PD.PickSlipno = @cPickSlipNo
     AND PD.LabelNo = @cLabelNo

   -- Create XML Request String              
   SET @xRequestString =              
   (              
      SELECT               
         @cConsignmentNumber         "@key",    
         (              
            SELECT                  
               @cConsignmentNumber   "consignmentNumber",              
               @cOrderKey            "customerReference"          
            FOR XML PATH('consignmentIdentity'), TYPE -- labelRequest/consignment/consignmentIdentity              
         ),
         @cOrderDate                 "collectionDateTime",
         (              
            SELECT                  
               @cSenderName          "name",              
               @cFacilityAddress2    "addressLine1",
               @cFacilityCity        "addressLine2",              
               @cFacilityCity        "town",
               @cSenderExactMatch    "exactMatch",              
               @cSenderProvince      "province",
               @cFacilityZip         "postcode",              
               @cFacilityCountry     "country"
            FOR XML PATH('sender'), TYPE -- labelRequest/consignment/sender              
         ),
         (              
            SELECT                  
               @cStorerKey + @cStorerCompany  "name",              
               @cStorerAddress1               "addressLine1",        
               @cStorerCity                   "town",
               @cDeliveryExactMatch           "exactMatch",              
               @cDeliveryProvince             "province",
               @cStorerZip                    "postcode",              
               @cStorerCountry                "country"
            FOR XML PATH('delivery'), TYPE -- labelRequest/consignment/delivery              
         ),
         (              
            SELECT                  
               @cProductLineOfBusiness "lineOfBusiness",              
               @cProductGroupID        "groupId",
               @cProductSubGroupID     "subGroupId",              
               @cProductID             "id",
               @cProductType           "type",              
               @cProductOption         "option"
            FOR XML PATH('product'), TYPE -- labelRequest/consignment/product              
         ),
         (              
            SELECT                  
               @cAccountNumber     "accountNumber",              
               @cAccountCountry    "accountCountry"
            FOR XML PATH('account'), TYPE -- labelRequest/consignment/account              
         ),
         @cOrderNotes        "specialInstructions",
         @nCartonNo          "totalNumberOfPieces",
         (              
            SELECT                  
               @cIdentifier          "identifier",              
               @cGoodsDescription    "goodsDescription",
               (              
                  SELECT                  
                     CAST(@fPackLength AS DECIMAL(18,2))     "length",              
                     CAST(@fPackWidth AS DECIMAL(18,2))      "width",
                     CAST(@fPackHeight AS DECIMAL(18,2))     "height",              
                     CAST(@fPackWeight AS DECIMAL(18,2))     "weight"
                  FOR XML PATH('pieceMeasurements'), TYPE -- labelRequest/consignment/pieceLine/pieceMeasurements           
               ),
               (              
                  SELECT                  
                     @nSequenceNumbers   "sequenceNumbers",              
                     @cLabelNo           "pieceReference"
                  FOR XML PATH('pieces'), TYPE -- labelRequest/consignment/pieceLine/pieces           
               )
            FOR XML PATH('pieceLine'), TYPE -- labelRequest/consignment/pieceLine              
         )
      FOR XML PATH('consignment'),              
      ROOT('labelRequest')              
   )              

   -- Create Request String
   SET @cRequestString = @cXMLEncodingString + CAST(@xRequestString AS NVARCHAR(MAX))

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
                      @cRequestString, @cStatus, 'C', 'R', @cLabelNo, 'isp_WS_TNT_ExpressLabel' 

   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0
      SET @nErr = 80005
      SET @cErrmsg = 'Error inserting into WebService_Log Table. (isp_WS_TNT_ExpressLabel)'
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
      SET @nErr = 80006     
      SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp_WS_TNT_ExpressLabel)'          
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
         SET @nErr = 80007  
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp_WS_TNT_ExpressLabel)'        
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
         SET @nErr = 80008 
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp_WS_TNT_ExpressLabel)'        
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
      SET @nErr = 80009
      SET @cErrmsg = 'Error updating WebService_Log Table. (isp_WS_TNT_ExpressLabel)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END  

   IF @cStatus = '5'
   BEGIN
      GOTO Quit
   END

   -- Extract ResponseString Data    
   EXEC sp_xml_preparedocument @ndoc OUTPUT, @xResponseString    

   SELECT
      @nErrorCode            = errorCode,
      @cErrorDescription     = errorDescription,   
      @c128CBarcode          = barcode,
      @cProduct              = product,
      @cOriginDepotCode      = originDepotCode,
      @cDestinationDepotCode = destinationDepotCode,
      @cDueDayOfMonth        = dueDayOfMonth,
      @cClusterCode          = clusterCode
   FROM OPENXML (@ndoc, '/labelResponse', 2)  
   WITH(  
      errorCode            INT           'brokenRules/errorCode',
      errorDescription     NVARCHAR(250) 'brokenRules/errorDescription',
      barcode              NVARCHAR(30)  'consignment/pieceLabelData/barcode',
      product              NVARCHAR(20)  'consignment/consignmentLabelData/product',
      originDepotCode      NVARCHAR(5)   'consignment/consignmentLabelData/originDepot/depotCode',
      destinationDepotCode NVARCHAR(5)   'consignment/consignmentLabelData/destinationDepot/depotCode',
      dueDayOfMonth        NVARCHAR(5)   'consignment/consignmentLabelData/destinationDepot/dueDayOfMonth',
      clusterCode          NVARCHAR(18)  'consignment/consignmentLabelData/clusterCode'
   ) 

   EXEC sp_xml_removedocument @ndoc    

   IF @nDebug = 1  
   BEGIN  
   SELECT  
      @nErrorCode              AS 'errorCode',
      @cErrorDescription       AS 'errorDescription',
      @c128CBarcode            AS '128CBarcode',
      @cProduct                AS 'product',
      @cOriginDepotCode        AS 'originDepotCode',
      @cDestinationDepotCode   AS 'destinationDepotCode',
      @cDueDayOfMonth          AS 'dueDayOfMonth',
      @cClusterCode            AS 'clusterCode'
   END  

   -- Response Failed              
   IF ISNULL(@nErrorCode, 0) > 0             
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 80013               
      SET @cErrmsg = CAST(@nErrorCode AS NVARCHAR) + ' - ' + @cErrorDescription + ' (isp_WS_TNT_ExpressLabel)'                
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit              
   END

UpdateDB:  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  

   IF EXISTS (SELECT 1 FROM CartonShipmentDetail WITH (NOLOCK)  
              WHERE UCCLabelNo = @cLabelNo)  
   BEGIN  
      -- Insert/Update into Table  
      UPDATE CartonShipmentDetail WITH (ROWLOCK)  
      SET DestinationZipCode     = @cClusterCode  
         ,FormCode               = @cOriginDepotCode
         ,TrackingNumber         = @cConsignmentNumber
         ,GroundBarcodeString    = @c128CBarcode
         ,RoutingCode            = @cDestinationDepotCode + '-' + @cDueDayOfMonth
         ,ServiceTypeDescription = @cProduct
         ,ServiceCode            = @cProductOption         --(CS02)
      WHERE  UCCLabelNo = @cLabelNo  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 80010  
         SET @cErrmsg = 'Error updating [dbo].[CartonShipmentDetail] Table. (isp_WS_TNT_ExpressLabel)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO RollbackTran  
      END  
   END  
   ELSE  
   BEGIN  
      INSERT INTO dbo.CartonShipmentDetail (  
         Storerkey, Orderkey, Loadkey, UCCLabelNo, CartonWeight, 
         DestinationZipCode, FormCode, TrackingNumber, 
         GroundBarcodeString, RoutingCode, ServiceTypeDescription,ServiceCode         --(CS02)
      ) VALUES (  
         @cStorerKey, @cOrderKey, @cLoadKey, @cLabelNo, @fPackWeight, 
         @cClusterCode, @cOriginDepotCode, @cConsignmentNumber, 
         @c128CBarcode, @cDestinationDepotCode + '-' + @cDueDayOfMonth, @cProduct,@cProductOption --(CS02)
      )  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 80011 
         SET @cErrmsg = 'Error inserting into [dbo].[CartonShipmentDetail] Table. (isp_WS_TNT_ExpressLabel)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO RollbackTran  
      END  
   END -- IF EXISTS (SELECT 1 FROM CartonShipmentDetail WITH (NOLOCK) WHERE UCCLabelNo = @cLabelNo)  
  
   COMMIT TRAN  
   GOTO Quit  
  
RollbackTran:  
   ROLLBACK TRAN  

Quit:
   -- Send Email Alert
   IF @bSendEmail = 1
   BEGIN
      SET @cSubject = 'TNT Consignment Number Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')

      SET @cBody = CASE WHEN @nEndConNumber - @nConsignmentNumber > 0 THEN CAST(@nEndConNumber - @nConsignmentNumber AS NVARCHAR) 
                   ELSE 'No' 
                   END + ' consignment number remaining.' + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + 'Please request a new range of consignmet number from TNT.' + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + 'Kindly update the following after that: ' + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + ' - Start Range = CODELKUP.Long WHERE Listname = ''TNT'' AND Code = ''ConNumberRange'' ' + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + ' - End Range   = CODELKUP.Notes WHERE Listname = ''TNT'' AND Code = ''ConNumberRange'' ' + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + ' - Current     = NCounter.KeyCount WHERE KeyName = ''TNTConNumber'' ' 

      -- Insert into DTSITF.Email alert table to send out email (Chee02)
      SET @cExecStatements = ''  
      SET @cExecArguments = ''   
      SET @cExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.EmailAlert ( '  
                             + 'AttachmentID, Subject, Recipient1, Recipient2, Recipient3, '
                             + 'Recipient4, Recipient5, EmailBody, Status) '   
                             + 'VALUES ( '  
                             + '@nAttachmentID, @cSubject, @cRecipient1, @cRecipient2, @cRecipient3, '
                             + '@cRecipient4, @cRecipient5, @cEmailBody, @cStatus)'
           
      SET @cExecArguments = N'@nAttachmentID  INT,           ' 
                            + '@cSubject      NVARCHAR(255), '
                            + '@cRecipient1   NVARCHAR(60),  '
                            + '@cRecipient2   NVARCHAR(60),  '
                            + '@cRecipient3   NVARCHAR(60),  '
                            + '@cRecipient4   NVARCHAR(60),  '
                            + '@cRecipient5   NVARCHAR(60),  '
                            + '@cEmailBody    NVARCHAR(MAX), '
                            + '@cStatus       NVARCHAR(1)    '

      EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                         0, @cSubject, @cEmailRecipient1, @cEmailRecipient2, @cEmailRecipient3, 
                         @cEmailRecipient4, @cEmailRecipient5, @cBody, '0' 

      IF @@ERROR <> 0
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 80012
         SET @cErrmsg = 'Error inserting into dbo.EmailAlert table. (isp_WS_TNT_ExpressLabel)'
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      END
   END -- IF @bSendEmail = 1

   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   WHILE @nTrancount > @@TRANCOUNT
      COMMIT TRAN

END -- Procedure


GO