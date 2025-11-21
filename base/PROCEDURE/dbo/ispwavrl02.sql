SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispWAVRL02                                                       */
/* Creation Date: 17 Dec 2012                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send Put Wave Message to VF (Storerkey-18405) WCS           */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 25-Oct-2013  Chee     1.1  Remove Hardcoding of Database Name        */
/*                            (Chee01)                                  */
/* 09-Jul-2015  NJOW01   1.2  343963-Wave Release to PTL enhancement    */  
/* 07-Sep-2015  NJOW02   1.3  343963-Only update UCC with UOM 6 from    */
/*                            status 1 to status 6                      */ 
/* 20-Jul-2016	 KTLow	 1.4	Add WebService Client Parameter (KT01)		*/ 
/************************************************************************/

CREATE PROC [dbo].[ispWAVRL02](
    @cWaveKey        NVARCHAR(10)
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
      @xReponseString         XML,
      @dTimeIn                DATETIME,
      @dTimeOut               DATETIME,
      @nTotalTime             INT,
      @cStatus                NVARCHAR(1),
      @cBatchNo               NVARCHAR(10),
      @nDebug                 INT,
      @nSeqNo                 INT,
      @ndoc                   INT,
      @nTrancount             INT,
      @cUserDefine01          NVARCHAR(20),
      @cWaveType              NVARCHAR(20),
      @nCount                 INT

   DECLARE
      @cStorerKey             NVARCHAR(15),
      @cTransactionType       NVARCHAR(10),
      @cReason                NVARCHAR(50),
      @cID                    NVARCHAR(10),
      @cPickSlipNo            NVARCHAR(10),
      @cOrderKey              NVARCHAR(10),
      @cUCCNo                 NVARCHAR(20),
      @cFlag                  NVARCHAR(10)

   DECLARE
      @cListName_WebService   NVARCHAR(10),
      @cListName_OrderGroup   NVARCHAR(10),
      @cCode_FilePath         NVARCHAR(30),
      @cCode_ConnString       NVARCHAR(30),
      @cCode_DematicURL       NVARCHAR(30),
      @cWSClientContingency   NVARCHAR(1),   
      @cConnectionString      NVARCHAR(250),
      @cDoNoSendMessagetoWCS  NVARCHAR(1)

   -- (Chee01)
   DECLARE 
      @cExecStatements         NVARCHAR(4000),  
      @cExecArguments          NVARCHAR(4000), 
      @cWebServiceLogDBName    NVARCHAR(30)   

--   DECLARE @StoreSeqNoTempTable TABLE
--  (SeqNo INT);

   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   CREATE TABLE #StoreSeqNoTempTable(SeqNo INT)

   SET @nDebug      = 0
   SET @bSuccess    = 1
   SET @nErr        = 0
   SET @cErrmsg     = ''
   SET @cBatchNo    = ''

   SET @cStatus              = '9'
   SET @cFlag                = 'CPRegular'
   SET @cTransactionType     = 'Put'
   SET @cListName_WebService = 'WebService'
   SET @cListName_OrderGroup = 'OrderGroup'
   SET @cCode_FilePath       = 'FilePath'
   SET @cCode_DematicURL     = 'DematicURL'
   SET @cCode_ConnString     = 'ConnString'

   SET @cWebRequestMethod   = 'POST'
   SET @cContentType        = 'application/xml'
   SET @cWebRequestEncoding = 'utf-8'
   SET @cXMLEncodingString  = '<?xml version="1.0" encoding="UCS"?>'
   SET @cXMLNamespace       = '<root xmlns:p="http://Dematic.com.au/WCSXMLSchema/VF"/>'

   SET @nCount = 0

   -- Get WSConfig.ini File Path from CODELKUP
   SELECT @cIniFilePath = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = @cListName_WebService
     AND Code = @cCode_FilePath

   IF ISNULL(@cIniFilePath,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20000
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- Get VF WCS Dematic Web Service Request URL 
   SELECT @cWebRequestURL = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = @cListName_WebService
     AND Code = @cCode_DematicURL

   IF ISNULL(@cWebRequestURL,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20001
      SET @cErrmsg = 'Web Service Request URL is empty. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @nDebug = 1
   BEGIN
      SELECT @cIniFilePath AS 'WSConfig.ini File Path',
             @cWebRequestURL AS 'Web Service Request URL'
   END

   SELECT TOP 1 @cStorerKey = OD.StorerKey
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey)
   WHERE WD.WaveKey = @cWaveKey  

   IF @nDebug = 1
   BEGIN
      SELECT @cStorerKey AS 'StorerKey'
   END

   IF @cStorerKey IS NULL
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20002
      SET @cErrmsg = 'Invalid WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- FBR#267700 checking 1: Check Wave.Userdefine01 and Orders.Ordergroup
   SELECT @cWaveType = UserDefine01
   FROM WAVE WITH (NOLOCK)
   WHERE WaveKey = @cWaveKey 

   IF ISNULL(@cWaveType,'') = ''
   BEGIN
      -- GET FROM ORDERS
      SELECT TOP 1 @cWaveType = CODELKUP.Short
      FROM WAVEDETAIL WD WITH (NOLOCK) 
      JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)
      WHERE WD.WaveKey = @cWaveKey 
        AND CODELKUP.Listname = @cListName_OrderGroup
   END
   
   IF ISNULL(@cWaveType,'') <> 'L'
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20003
      SET @cErrmsg = 'Only Launch wave allowed to use this function. WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- FBR#267700 checking 2: only allow to release to WCS after all FC task completed.
   /* --NJOW01
   IF EXISTS(SELECT 1 FROM WAVEDETAIL  WD WITH (NOLOCK)
                      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey)
                      JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey 
                                                            AND OD.OrderLineNumber = PD.OrderLineNumber)
                      WHERE WD.WaveKey = @cWaveKey AND PD.UOM = '2' AND PD.Status <> '4' AND PD.Status <> '3')
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20004
      SET @cErrmsg = 'Full Case Picking is not complete. WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END
   */

   -- Check if any piece pick left
   IF NOT EXISTS(SELECT 1 FROM WAVEDETAIL  WD WITH (NOLOCK)
                          JOIN ORDERDETAIL OD WITH (NOLOCK) ON (WD.Orderkey = OD.Orderkey)
                          JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey 
                                                            AND OD.OrderLineNumber = PD.OrderLineNumber)
                          WHERE WD.WaveKey = @cWaveKey AND PD.UOM = '6' AND PD.Status = '0') --NJOW01
                          --WHERE WD.WaveKey = @cWaveKey AND (PD.UOM = '6' OR PD.UOM = '7') AND PD.Status = '0')
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20005
      SET @cErrmsg = 'No more piece picking left. WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   SELECT @nCount = COUNT(1) 
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
   WHERE WD.WaveKey = @cWaveKey
   AND EXISTS (SELECT 1
                 FROM ORDERDETAIL OD WITH (NOLOCK) 
                 JOIN PICKDETAIL PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                 WHERE OD.Orderkey = O.OrderKey
                   --AND (PD.UOM = '6') OR PD.UOM = '7')
                   AND PD.UOM = '6' --NJOW03
                   AND PD.Status = '0')
                   
   IF @nDebug = 1
   BEGIN
      SELECT 'Number of piece orders for wave #' + @cWaveKey  + ': ' + CAST(@nCount AS NVARCHAR)
   END
   
   -- Only allow maximum of 448 piece pick orders per put wave (physically there is only 448 light locations)
   IF @nCount > 448
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20006
      SET @cErrmsg = 'No more piece picking left. WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- Update Wave Status
   IF EXISTS(SELECT 1 FROM WAVE WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND Status <> '4')
   BEGIN
      UPDATE WAVE WITH (ROWLOCK)
      SET Status = '4'
      WHERE WaveKey = @cWaveKey  

      IF @@ERROR <> 0
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 20019
         SET @cErrmsg = 'Error updating wave status, WaveKey : ' + @cWaveKey + '. (ispWAVRL02)'
                       + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
         GOTO Quit
      END
   END

   -- Only retrieve the allocated piece pick (UOM=6) order qty in packdetail
   SET @xRequestString = 
   (
      SELECT
         RTRIM(O.OrderKey)                                      "WorkAssignmentID",
       --RTRIM(ISNULL(O.UserDefine02,''))                       "Flag",
         @cFlag                                                 "Flag",
         RTRIM(ISNULL(O.ConsigneeKey,'')) + RTRIM(O.OrderKey)   "StoreID",
         (
            SELECT
               @cTransactionType                         "TransactionType",
               RTRIM(OD.OrderKey + OD.OrderLineNumber)   "MissionID",
               SUM(PD.Qty)                               "QtyRequired",
               RTRIM(ISNULL(SKU.ALTSKU,''))               "SKUID",
               RTRIM(ISNULL(SKU.Style,'')) + ' ' + 
               RTRIM(ISNULL(SKU.Color,'')) + ' ' + 
               RTRIM(ISNULL(SKU.Size,''))                "ShortDescription"
               FROM ORDERDETAIL OD WITH (NOLOCK) 
               JOIN PICKDETAIL PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
               JOIN SKU WITH (NOLOCK) ON (SKU.SKU = OD.Sku AND SKU.StorerKey = OD.StorerKey)
               WHERE OD.Orderkey = O.OrderKey
                 --AND (PD.UOM = '6' OR PD.UOM = '7') -- Piece Pick
                 AND PD.UOM = '6' -- Piece Pick NJOW01
                 AND PD.Status = '0'
               GROUP BY OD.OrderKey, OD.OrderLineNumber, SKU.ALTSKU , SKU.Style, SKU.Color, SKU.Size
            FOR XML PATH('OrderLine'), TYPE 
         ) 
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
      WHERE WD.WaveKey = @cWaveKey
        AND EXISTS (SELECT 1
                    FROM ORDERDETAIL OD WITH (NOLOCK) 
                    JOIN PICKDETAIL PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                    WHERE OD.Orderkey = O.OrderKey
                      --AND (PD.UOM = '6' OR PD.UOM = '7')
                      AND PD.UOM = '6' --NJOW01
                      AND PD.Status = '0')
      FOR XML PATH('WorkAssignment'), TYPE 
   )

   ;WITH XMLNAMESPACES ('http://Dematic.com.au/WCSXMLSchema/VF' As p)
   SELECT @xRequestString =
   (
      SELECT 
         @cWaveKey         "WaveID",
         @xRequestString
      FOR XML PATH('Wave'),
      ROOT('p:Download')
   )

   -- Create Request String
   SET @cRequestString = @cXMLEncodingString + CAST(@xRequestString AS NVARCHAR(MAX))

   IF @nDebug = 1
   BEGIN
      SELECT @xRequestString AS 'XML Request String'
      SELECT @cRequestString AS 'Request String'
   END

   -- (Chee01)
   SELECT @cWebServiceLogDBName = NSQLValue  
   FROM dbo.NSQLConfig WITH (NOLOCK)  
   WHERE ConfigKey = 'WebServiceLogDBName' 

   IF ISNULL(@cWebServiceLogDBName, '') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20007
      SET @cErrmsg = 'NSQLConfig - WebServiceLogDBName is empty. (ispWAVRL02)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END
  
--   -- Insert Request String into WebService_Log
--   INSERT INTO [CNDTSITF].[dbo].[WebService_Log](
--      [DataStream],
--      [StorerKey],
--      [Type],
--      [BatchNo],
--      [WebRequestURL],
--      [WebRequestMethod],
--      [ContentType],
--      [RequestString],
--      [Status],
--      [ClientHost],
--      [WSIndicator],
--      [SourceKey],
--      [SourceType]
--   )
--   OUTPUT INSERTED.SeqNo INTO @StoreSeqNoTempTable
--   VALUES(
--      '',
--      @cStorerKey,
--      'O',           -- Output
--      @cBatchNo,
--      @cWebRequestURL,
--      @cWebRequestMethod,
--      @cContentType,
--      @cRequestString,
--      @cStatus,
--      'C',           -- Client
--      'R',           -- RealTime
--      @cWaveKey, 
--      'ispWAVRL02'
--   )

   SET @cExecStatements = ''  
   SET @cExecArguments = ''   
   SET @cExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log ( '  
                          + 'DataStream, StorerKey, Type, BatchNo, WebRequestURL, WebRequestMethod, ContentType, '
                          + 'RequestString, Status, ClientHost, WSIndicator, SourceKey, SourceType) '   
                          + 'OUTPUT INSERTED.SeqNo INTO #StoreSeqNoTempTable VALUES ( '  
                          + '@cDataStream, @cStorerKey, @cType, @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType, '
                          + '@cRequestString, @cStatus, @cClientHost, @cWSIndicator, @cSourceKey, @cSourceType)'
        
 SET @cExecArguments = N'@cDataStream        NVARCHAR(10), ' 
                         + '@cStorerKey        NVARCHAR(15), '
                         + '@cType             NVARCHAR(1), '
                         + '@cBatchNo          NVARCHAR(10), '
                         + '@cWebRequestURL    NVARCHAR(1000), '
                         + '@cWebRequestMethod NVARCHAR(10), '
                         + '@cContentType      NVARCHAR(100), '
                         + '@cRequestString    NVARCHAR(MAX), '
                         + '@cStatus           NVARCHAR(1), '
                         + '@cClientHost       NVARCHAR(1), '
                         + '@cWSIndicator      NVARCHAR(1), '
                         + '@cSourceKey        NVARCHAR(50), '
                         + '@cSourceType       NVARCHAR(50)'

   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                      '', @cStorerKey, 'O', @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType,
                      @cRequestString, @cStatus, 'C', 'R', @cWaveKey, 'ispWAVRL02' 

   IF @@ERROR <> 0
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20008
      SET @cErrmsg = 'Error inserting into WebService_Log Table. (ispWAVRL02)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- Get SeqNo
   SELECT @nSeqNo = SeqNo
   FROM #StoreSeqNoTempTable -- @StoreSeqNoTempTable (Chee01)

   EXEC dbo.nspGetRight        
      NULL,        
      @cStorerKey,        
      NULL,        
      'DoNoSendMessagetoWCS',        
      @bSuccess               OUTPUT,        
      @cDoNoSendMessagetoWCS  OUTPUT,         
      @nErr                   OUTPUT,         
      @cErrMsg                OUTPUT    
        
   IF NOT @bSuccess = 1        
   BEGIN        
      SET @bSuccess = 0         
      SET @nErr = 20020     
      SET @cErrmsg = 'nspGetRight DoNoSendMessagetoWCS Failed. (ispWAVRL02)'          
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'          
      GOTO Quit        
   END  

   IF @cDoNoSendMessagetoWCS <> '1'
   BEGIN
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
         SET @nErr = 20009      
         SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (ispWAVRL02)'          
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
         --   @cVBErrMsg         OUTPUT        
         
			EXEC [master].[dbo].[isp_GenericWebServiceClient] @cIniFilePath
																			, @cWebRequestURL
																			, @cWebRequestMethod --@c_WebRequestMethod
																			, @cContentType --@c_ContentType
																			, @cWebRequestEncoding --@c_WebRequestEncoding
																			, @cRequestString --@c_FullRequestString
																			, @cResponseString OUTPUT
																			, @cVBErrMsg OUTPUT																 
																			, 10000 --@n_WebRequestTimeout -- Miliseconds
																			, '' --@c_NetworkCredentialUserName -- leave blank if no network credential
																			, '' --@c_NetworkCredentialPassword -- leave blank if no network credential
																			, 0 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
																			, '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
																			, '' --@c_HeaderAuthorization
																			, '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
			--(KT01) - End
			     
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cStatus = '5'        
            SET @bSuccess = 0        
            SET @nErr = 20010       
              
            -- SET @cErrmsg        
            IF ISNULL(@cVBErrMsg,'') <> ''        
            BEGIN        
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
            END        
            ELSE        
            BEGIN        
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (ispWAVRL02)'        
                             + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
            END        
         END     
      END  
      ELSE  
      BEGIN  
         SELECT @cConnectionString = 'Data Source=' + UDF01 + ';uid=' + UDF02 + ';pwd=' + dbo.fnc_DecryptPWD(UDF03) 
                                     + ';Application Name=' + UDF04 + ';Enlist=false'
         FROM CODELKUP WITH (NOLOCK)  
         WHERE LISTNAME = @cListName_WebService
           AND Code = @cCode_ConnString  
     
         EXEC [master].[dbo].[isp_GenericWebServiceClient_Contingency]       
            @cConnectionString,  
            @cIniFilePath,  
            @cWebRequestURL,  
            @cWebRequestMethod,  
            @cContentType,  
            @cWebRequestEncoding,  
            @cRequestString,  
            @cResponseString   OUTPUT,  
            @cvbErrMsg         OUTPUT    
         
         IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cStatus = '5'        
            SET @bSuccess = 0        
            SET @nErr = 20011        
              
            -- SET @cErrmsg        
            IF ISNULL(@cVBErrMsg,'') <> ''        
            BEGIN        
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
            END        
            ELSE        
            BEGIN        
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (ispWAVRL02)'        
                             + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
            END        
         END    
      END -- IF @cWSClientContingency <> '1'  
   END  -- IF @cDoNoSendMessagetoWCS <> '1'
   ELSE
   BEGIN
      SET @cStatus = '5'
      SET @dTimeIn = GETDATE()
   END

   SET @dTimeOut = GETDATE()
   SET @nTotalTime = DATEDIFF(ms, @dTimeIn, @dTimeOut)

   -- Get rid of the encoding part in the root tag to prevent error: unable to switch the encoding
   SET @xReponseString = CAST(REPLACE(@cResponseString, 'encoding="' + @cWebRequestEncoding + '"', '') AS XML)

   IF @nDebug = 1
   BEGIN
      SELECT @xReponseString AS 'XML Response String'
      SELECT @cResponseString AS 'Response String'
   END

   -- (Chee01)
--   UPDATE [CNDTSITF].[dbo].[WebService_Log] WITH (ROWLOCK)
--   SET Status = @cStatus, ErrMsg = @cErrmsg, TimeIn = @dTimeIn, 
--       ResponseString = @cResponseString, TimeOut = @dTimeOut, TotalTime = @nTotalTime
--   WHERE SeqNo = @nSeqNo

   SET @cExecStatements = ''  
   SET @cExecArguments = ''   
 SET @cExecStatements = N'UPDATE ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log WITH (ROWLOCK) '  
                          + 'SET Status = @cStatus, ErrMsg = @cErrmsg, TimeIn = @dTimeIn, '
                          + '    ResponseString = @cResponseString, TimeOut = @dTimeOut, TotalTime = @nTotalTime '   
                          + 'WHERE SeqNo = @nSeqNo'
        
   SET @cExecArguments = N'@cStatus          NVARCHAR(1), ' 
                         + '@cErrmsg         NVARCHAR(215), '
                         + '@dTimeIn         DATETIME, '
                         + '@cResponseString NVARCHAR(MAX), '
                         + '@dTimeOut        DATETIME, '
                         + '@nTotalTime      INT, '
                         + '@nSeqNo          INT'

   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                      @cStatus, @cErrmsg, @dTimeIn, @cResponseString, @dTimeOut, @nTotalTime, @nSeqNo

   IF @@ERROR <> 0
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 20012
      SET @cErrmsg = 'Error updating WebService_Log Table. (ispWAVRL02)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
     GOTO Quit
   END

   IF @cStatus = '5'
   BEGIN
      GOTO Quit
   END

   IF ISNULL(@cResponseString, '') <> ''
   BEGIN
      SET @cStatus = '5'

      -- Extract ResponseString Data
      EXEC sp_xml_preparedocument @ndoc OUTPUT, @xReponseString, @cXMLNamespace

      -- SELECT statement that uses the OPENXML rowset provider.
      SELECT 
         @cID = CASE WHEN ISNULL(WaveID,'') = '' THEN WorkAssignmentID ELSE WaveID END,
         @cReason = CASE WHEN ISNULL(Wave_Error_Reason, '') = '' THEN WA_Error_Reason ELSE Wave_Error_Reason END
      FROM OPENXML (@ndoc, '/p:Upload', 2)
      WITH(
         [WaveID]              NVARCHAR(10)  'Wave_Error/WaveID',
         [Wave_Error_Reason]   NVARCHAR(50)  'Wave_Error/Reason',
         [WorkAssignmentID]    NVARCHAR(10)  'WA_Error/WorkAssignmentID',
         [WA_Error_Reason]     NVARCHAR(50)  'WA_Error/Reason')

      EXEC sp_xml_removedocument @ndoc

      SET @bSuccess = 0
      SET @nErr = 20013
      SET @cErrmsg = 'Response error: ' + @cReason + '. ID#: ' + @cID + ' (ispWAVRL02)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'

      -- (Chee01)
--      UPDATE [CNDTSITF].[dbo].[WebService_Log] WITH (ROWLOCK)
--      SET Status = @cStatus, ErrMsg = @cErrmsg
--      WHERE SeqNo = @nSeqNo

      SET @cExecStatements = ''  
      SET @cExecArguments = ''   
      SET @cExecStatements = N'UPDATE ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log WITH (ROWLOCK) '  
                             + 'SET Status = @cStatus, ErrMsg = @cErrmsg '
                             + 'WHERE SeqNo = @nSeqNo'
           
      SET @cExecArguments = N'@cStatus  NVARCHAR(1), ' 
                            + '@cErrmsg NVARCHAR(215), '
                            + '@nSeqNo  INT'

      EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                         @cStatus, @cErrmsg, @nSeqNo

      IF @@ERROR <> 0
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 20014
         SET @cErrmsg = 'Error updating WebService_Log Table. (ispWAVRL02)'
                       + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
        GOTO Quit
      END

      GOTO Quit
   END

UpdateDB:
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN

   /**********************************************/   
   /* Create PickHeader For All Orders in Wave   */   
   /**********************************************/   
   DECLARE CUR_PH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
   SELECT DISTINCT OD.OrderKey  
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.Orderkey = WD.Orderkey)  
   WHERE WD.Wavekey = @cWaveKey    
     
   OPEN CUR_PH
   FETCH NEXT FROM CUR_PH INTO @cOrderKey     
   WHILE @@FETCH_STATUS <> -1        
   BEGIN      

      SET @cPickSlipNo = ''  

      SELECT @cPickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')   
      FROM dbo.PickHeader WITH (NOLOCK)   
      WHERE OrderKey = @cOrderKey   
 
      IF ISNULL(RTRIM(@cPickSlipNo),'') = ''  
      BEGIN  
         SET @bSuccess = 0    

         EXECUTE nspg_GetKey    
            'PICKSLIP',    
            9,       
            @cPickSlipNo     OUTPUT,    
            @bSuccess        OUTPUT,    
            @nErr            OUTPUT,    
            @cErrMsg         OUTPUT    

         IF @bSuccess <> 1    
         BEGIN    
            SET @bSuccess = 0
            SET @nErr = 20015 
            SET @cErrmsg = 'Error Getting PickSlipNo. (ispWAVRL02)'
                         + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
            GOTO RollbackTran      
         END    

         SET @cPickSlipNo = 'P' + @cPickSlipNo    

         INSERT INTO dbo.PickHeader (PickHeaderKey,  ExternOrderKey, Orderkey, Zone, ConsigneeKey, ConsoOrderKey)    
         VALUES (@cPickSlipNo, '', @cOrderKey, 'LP', '', '')   

         IF @@ERROR <> 0     
         BEGIN     
            SET @bSuccess = 0
            SET @nErr = 20016
            SET @cErrmsg = 'Error Creating PickHeader For OrderKey:' + @cOrderKey + ' (ispWAVRL02)'
                         + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
            GOTO RollbackTran      
         END
      END -- IF ISNULL(RTRIM(@cPickSlipNo),'') = ''    
      FETCH NEXT FROM CUR_PH INTO @cOrderKey     
   END       
   CLOSE CUR_PH        
   DEALLOCATE CUR_PH

   /*********************/   
   /* Update UCC       */   
   /********************/   

   DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
   SELECT DISTINCT PD.DropID, PD.StorerKey
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WD.OrderKey = OD.OrderKey)
   WHERE WD.Wavekey = @cWaveKey   
   AND PD.UOM = '6' --NJOW02
      
   OPEN CUR_UCC
   FETCH NEXT FROM CUR_UCC INTO @cUCCNo, @cStorerKey 
   WHILE @@FETCH_STATUS <> -1        
   BEGIN  

      UPDATE dbo.UCC WITH (ROWLOCK) 
      SET Status = '6'  
      WHERE UCCNo      = @cUCCNo  
      AND   StorerKey  = @cStorerKey  
      AND Status = '1' --NJOW02

      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0
         SET @nErr = 20017
         SET @cErrmsg = 'Update UCC Failed. (ispWAVRL02)'
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
         GOTO RollbackTran   
      END  

      FETCH NEXT FROM CUR_UCC INTO @cUCCNo, @cStorerKey  
   END       
   CLOSE CUR_UCC        
   DEALLOCATE CUR_UCC

   COMMIT TRAN
   GOTO Quit

RollbackTran:
   ROLLBACK TRAN

Quit:
   WHILE @nTrancount > @@TRANCOUNT
      COMMIT TRAN

   -- (Chee01)
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

   IF (SELECT CURSOR_STATUS('local','CUR_PH')) >=0   
   BEGIN  
      CLOSE CUR_PH                
      DEALLOCATE CUR_PH        
   END  

   IF (SELECT CURSOR_STATUS('local','CUR_UCC')) >=0   
   BEGIN  
      CLOSE CUR_UCC                
      DEALLOCATE CUR_UCC        
   END  
END -- Procedure


GO