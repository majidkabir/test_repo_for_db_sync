SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_WS_WCS_VF_ContainerCommand                                   */
/* Creation Date: 17 Dec 2012                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send Container Command Message to VF (Storerkey-18405) WCS  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* RDTMsg : 82401 - 82450                                               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/* 25-Oct-2013  Chee     1.1      Remove Hardcoding of Database Name    */
/*                                (Chee01)                              */
/* 03-Dec-2014  Ung      1.2      Remove temp table to prevent recompile*/
/* 20-Jul-2016	 KTLow	 1.3		 Add WebService Client Parameter (KT01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_WS_WCS_VF_ContainerCommand](
    @cLPNNo          NVARCHAR(20)
   ,@cContainerType  NVARCHAR(15) 
   ,@cToLoc          NVARCHAR(20)
   ,@bSuccess        INT            OUTPUT
   ,@nErr            INT            OUTPUT
   ,@cErrMsg         NVARCHAR(215)  OUTPUT
   ,@bByPassChecking INT = 0
   ,@nFunc           INT = 0
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
      @nTrancount             INT

   DECLARE 
      @cCommand               NVARCHAR(15),
      @cStorerKey             NVARCHAR(15)

   DECLARE
      @cListName              NVARCHAR(10),
      @cCode_FilePath         NVARCHAR(30),
      @cCode_ConnString       NVARCHAR(30),
      @cCode_DematicURL       NVARCHAR(30),
      @cWSClientContingency   NVARCHAR(1),   
      @cConnectionString      NVARCHAR(250),
      @cDoNoSendMessagetoWCS  NVARCHAR(1)

   DECLARE 
      @cWCSKey   NVARCHAR(10)

   -- (Chee01)
   DECLARE 
      @cExecStatements      NVARCHAR(4000),  
      @cExecArguments          NVARCHAR(4000), 
      @cWebServiceLogDBName    NVARCHAR(30)   

   SET @nDebug      = 0
   SET @bSuccess    = 1
   SET @nErr        = 0
   SET @cErrmsg     = ''

   SET @cBatchNo = ''
   IF @nFunc = 1799 -- rdtfnc_VFCDC_ConveyorMove
      SET @cBatchNo = 'M'

   SET @cStatus          = '9'
   SET @cListName        = 'WebService'
   SET @cCode_FilePath   = 'FilePath'
   SET @cCode_DematicURL  = 'DematicURL'
   SET @cCode_ConnString = 'ConnString'

   SET @cStorerKey = '18405'

   SET @cWebRequestMethod   = 'POST'
   SET @cContentType        = 'application/xml'
   SET @cWebRequestEncoding = 'utf-8'
   SET @cXMLEncodingString  = '<?xml version="1.0" encoding="UCS"?>'
   SET @cXMLNamespace       = '<root xmlns:p="http://Dematic.com.au/WCSXMLSchema/VF"/>'

   -- Get WSConfig.ini File Path from CODELKUP
   SELECT @cIniFilePath = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = @cListName
     AND Code = @cCode_FilePath

   IF ISNULL(@cIniFilePath,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 82401
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- Get VF WCS Dematic Web Service Request URL 
   SELECT @cWebRequestURL = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = @cListName
     AND Code = @cCode_DematicURL

   IF ISNULL(@cWebRequestURL,'') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 82402
      SET @cErrmsg = 'Web Service Request URL is empty. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @nDebug = 1
   BEGIN
      SELECT @cIniFilePath AS 'WSConfig.ini File Path',
             @cWebRequestURL AS 'Web Service Request URL'
   END

   IF isnull(@cLPNNo, '') = ''
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 82413
      SET @cErrmsg = 'LPN number empty. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @bByPassChecking = 0
   BEGIN 
      -- Inbound Checking
      SELECT TOP 1 @cStorerKey = StorerKey
      FROM   UCC WITH (NOLOCK)    
      WHERE  UCCNo = @cLPNNo  
        AND  StorerKey = @cStorerKey

      IF ISNULL(@cStorerKey,'') = ''
      BEGIN
         SELECT TOP 1 @cStorerKey = StorerKey
         FROM   LotxLocxID WITH (NOLOCK)    
         WHERE  ID = @cLPNNo  
      END

      IF ISNULL(@cStorerKey,'') = ''
      BEGIN
         -- Outbound Checking
         SELECT TOP 1 @cStorerKey = StorerKey
         FROM   Packdetail WITH (NOLOCK)    
         WHERE  DropID = @cLPNNo  
           AND  StorerKey = @cStorerKey
      END
   END --  IF @bByPassChecking = 1

   IF @cStorerKey IS NULL
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 82403
      SET @cErrmsg = 'Invalid LPN number. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   IF @nDebug = 1
   BEGIN
      SELECT @cStorerKey AS 'StorerKey'
   END

   -- If container type is empty, set command to AddVisit
   IF ISNULL(@cContainerType,'') <> ''
   BEGIN
      SET @cCommand = 'AddContainer'

      IF @cContainerType <> 'FullCase' AND @cContainerType <> 'Replenishment' AND @cContainerType <> 'Pick'
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 82404
         SET @cErrmsg = 'Invalid Container Type. (isp_WS_WCS_VF_ContainerCommand)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      SET @cCommand = 'AddVisit'
      SET @cContainerType = NULL
   END

   IF ISNULL(@cToLoc,'') = ''
   BEGIN
SET @bSuccess = 0
      SET @nErr = 82405
      SET @cErrmsg = 'To Loc is empty. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

   -- Create XML Request String
   ;WITH XMLNAMESPACES ('http://Dematic.com.au/WCSXMLSchema/VF' As p)
   SELECT @xRequestString =
   (
      SELECT
         @cCommand         "Command",  
         @cContainerType   "ContainerType",  
         RTRIM(@cLPNNo)    "ContainerID",  
         RTRIM(@cToLoc)    "Destination"  
      FOR XML PATH('ContainerCommand'),
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
      SET @nErr = 82415
      SET @cErrmsg = 'NSQLConfig - WebServiceLogDBName is empty. (isp_WS_WCS_VF_ContainerCommand)'
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END
  
   SET @cExecStatements = ''  
   SET @cExecArguments = ''   
   SET @cExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.WebService_Log ( '  
                          + 'DataStream, StorerKey, Type, BatchNo, WebRequestURL, WebRequestMethod, ContentType, '
                          + 'RequestString, Status, ClientHost, WSIndicator, SourceKey, SourceType) '   
                          + 'VALUES ( @cDataStream, @cStorerKey, @cType, @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType, '
                          + '@cRequestString, @cStatus, @cClientHost, @cWSIndicator, @cSourceKey, @cSourceType) ' + CHAR(13)
                          + 'SET @nSeqNo = @@IDENTITY '
        
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
                         + '@cSourceType       NVARCHAR(50), '
                         + '@nSeqNo            INT  OUTPUT'  
                         
   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, 
                      @nFunc, @cStorerKey, 'O', @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType,
                      @cRequestString, @cStatus, 'C', 'R', @cLPNNo, 'isp_WS_WCS_VF_ContainerCommand', @nSeqNo OUTPUT 

   IF @@ERROR <> 0
   BEGIN
      SET @bSuccess = 0
      SET @nErr = 82406
      SET @cErrmsg = 'Error inserting into WebService_Log Table. (isp_WS_WCS_VF_ContainerCommand)'
                   + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit
   END

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
      SET @nErr = 82414     
      SET @cErrmsg = 'nspGetRight DoNoSendMessagetoWCS Failed. (isp_WS_WCS_VF_ContainerCommand)'          
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
         SET @nErr = 82407     
         SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp_WS_WCS_VF_ContainerCommand)'          
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
            SET @nErr = 82408   
              
            -- SET @cErrmsg        
            IF ISNULL(@cVBErrMsg,'') <> ''        
            BEGIN        
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
            END        
            ELSE        
            BEGIN        
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp_WS_WCS_VF_ContainerCommand)'        
                             + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'        
            END        
         END     
      END  
      ELSE  
      BEGIN  
         SELECT @cConnectionString = 'Data Source=' + UDF01 + ';uid=' + UDF02 + ';pwd=' + dbo.fnc_DecryptPWD(UDF03) 
                                     + ';Application Name=' + UDF04 + ';Enlist=false'
         FROM CODELKUP WITH (NOLOCK)  
         WHERE LISTNAME = @cListName 
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
            SET @nErr = 82409  
              
            -- SET @cErrmsg        
            IF ISNULL(@cVBErrMsg,'') <> ''        
            BEGIN        
               SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
            END        
            ELSE        
            BEGIN        
               SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp_WS_WCS_VF_ContainerCommand)'        
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
--   UPDATE [DTSITF].[dbo].[WebService_Log] WITH (ROWLOCK)
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
      SET @nErr = 82410
      SET @cErrmsg = 'Error updating WebService_Log Table. (isp_WS_WCS_VF_ContainerCommand)'
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
     GOTO Quit
   END

   IF @cStatus = '5'
   BEGIN
      GOTO Quit
   END

   -- Insert/Update into WCSRouting to check Old/New LPN
   SELECT @cWCSKey = WCSKey
   FROM WCSRouting WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey AND ToteNo = @cLPNNo

   IF ISNULL(@cWCSKey, '') = ''
   BEGIN
      EXECUTE nspg_GetKey         
      'WCSKey',         
      10,         
      @cWCSKey   OUTPUT,         
      @bSuccess  OUTPUT,         
      @nErr      OUTPUT,         
      @cErrMsg   OUTPUT          

      IF NOT @bSuccess = 1         
     BEGIN        
         SET @bSuccess = 0
         SET @nErr = 82411
         SET @cErrmsg = 'nspGetRight WCSKey Failed. (isp_WS_WCS_VF_ContainerCommand)'          
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )' 
         GOTO Quit
      END       
            
      INSERT INTO WCSRouting        
      (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType, Status)        
      VALUES        
      (@cWCSKey, @cLPNNo, '', '', '', @cStorerKey, 'VFCDC', '', '', @cStatus) 

      IF @@ERROR <> 0
      BEGIN
         SET @bSuccess = 0
         SET @nErr = 82412
         SET @cErrmsg = 'Error inserting into WCSRouting Table. (isp_WS_WCS_VF_ContainerCommand)'
                      + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@nErr,0)) + ' )'
         GOTO Quit
      END
   END

Quit:
   WHILE @nTrancount > @@TRANCOUNT
      COMMIT TRAN

   -- (Chee01)
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

END -- Procedure



GO