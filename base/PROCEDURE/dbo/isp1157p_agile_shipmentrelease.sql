SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store Procedure:  isp1157P_Agile_ShipmentRelease                     */          
/* Creation Date: 09-Mar-2012                                           */          
/* Copyright: IDS                                                       */          
/* Written by: JunYan                                                   */          
/*                                                                      */          
/* Purpose: SOS#237562 - Agile Elite - Shipment Release Request         */    
/*          SOS#237563 - Agile Elite - Shipment Release Response        */    
/*                                                                      */          
/* Input Parameters:  @c_DataStream                                     */          
/*                    @c_Storerkey                                      */          
/*                    @b_debug         - 0                              */          
/*                                                                      */          
/* Output Parameters: @b_success       - Success Flag  = 0              */          
/*                    @n_err           - Error Code    = 0              */          
/*                    @c_errmsg        - Error Message = ''             */          
/*                                                                      */          
/* Usage:                                                               */          
/*                                                                      */          
/* Called By:  Scheduler job                                            */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/* Updates:                                                             */          
/* Date         Author    Ver.  Purposes                                */     
/* 03-Apr-2012  Chee      1.1   Get Agile Web Service Request URL       */    
/*                              from CODELKUP (Chee01)                  */      
/* 09-Apr-2012  Ung       1.2   Pass in facility, for storer config     */    
/*                              AgileProcess (ung01)                    */    
/* 09-Apr-2012  Chee      1.3   Change OpenXML SELECT for response,     */    
/*                              for better error description (Chee02)   */    
/* 14-Apr-2012  Shong     1.4   User Account No as User Name            */  
/* 16-Apr-2012  Shong     1.5   Added SourceKey, SourceType to Web Log  */  
/* 11-May-2012  James     1.5   Filter specialhandling (james01)        */  
/* 03-Oct-2012  Chee      1.6   Add isp_GenericWebServiceClient_        */  
/*                              Contingency (Chee03)                    */
/* 27-Jun-2013  Chee      1.7   SOS# 282086 - Add Credentials to        */ 
/*                              AGILE Ship Release XML request for      */
/*                              Orders.SpecialHandling = 'X' (Chee04)   */ 
/* 20-Jul-2016	 KTLow	  1.8	  Add WebService Client Parameter (KT01)	*/ 
/************************************************************************/          
    
CREATE PROC [dbo].[isp1157P_Agile_ShipmentRelease] (          
       @c_DataStream    NVARCHAR(4)          
     , @c_Storerkey     NVARCHAR(15)       
     , @c_Facility      NVARCHAR(5)  -- (ung01)    
     , @b_debug         INT          
     , @b_success       INT = 0           OUTPUT          
     , @n_err           INT = 0        OUTPUT          
     , @c_errmsg        NVARCHAR(250) = NULL  OUTPUT          
     )          
AS          
BEGIN          
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF     
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
          
   /*********************************************/          
   /* Variables Declaration (Start)   */          
   /*********************************************/          
          
   -- OUT_LINE/OUT_FILE & General          
   DECLARE @n_continue                 INT          
         , @n_StartTCnt                INT          
                        
   DECLARE @c_PackageID                NVARCHAR(30)                  
                                                           
   DECLARE @d_GetDate                  DATETIME          
         , @c_GetDate                  NVARCHAR(14)          
         , @c_TransmitLogKey           NVARCHAR(10)                
         , @c_TableName                NVARCHAR(30)          
         , @c_TxFlag0                  NVARCHAR(1)          
         , @c_TxFlag1                  NVARCHAR(1)            
         , @c_TxFlag5                  NVARCHAR(1)          
         , @c_TxFlag9                  NVARCHAR(1)                  
         , @c_TxBatch                  NVARCHAR(1)          
    
   DECLARE      
      @c_IniFilePath         NVARCHAR(100),    
      @c_WebRequestURL       NVARCHAR(1000),    
      @c_WebRequestMethod    NVARCHAR(10),    
      @c_ContentType         NVARCHAR(100),    
      @c_WebRequestEncoding  NVARCHAR(30),    
      @c_XMLEncodingString   NVARCHAR(100),    
      @c_RequestString       NVARCHAR(MAX),    
      @c_ResponseString      NVARCHAR(MAX),    
      @c_VBErrMsg            NVARCHAR(MAX),    
      @x_RequestString       XML,    
      @x_ReponseString       XML,    
      @d_TimeIn              DATETIME,    
      @d_TimeOut             DATETIME,    
      @n_TotalTime           INT,    
      @c_Status              NVARCHAR(1),    
      @c_PackageWeight       NVARCHAR(20),    
      @n_Debug               INT,    
      @n_SeqNo               INT,    
      @c_BatchNo             NVARCHAR(10),    
      @c_UserName            NVARCHAR(30),    
      @c_ListName            NVARCHAR(10),    
      @c_Code_FilePath       NVARCHAR(30),    
      @c_TrackingNumber      NVARCHAR(30),    
      @c_PickSlipNo          NVARCHAR(10),    
      @n_CartonNo            INT,    
   -- @c_Facility            NVARCHAR(5), (ung01)    
      @c_AgileProcess        NVARCHAR(1),    
      @c_LabelNo             NVARCHAR(20),    
      @c_Code_AgileURL       NVARCHAR(30),    -- Chee01         
      @c_AccountID           NVARCHAR(18),  
      @c_OrderKey            NVARCHAR(10),  
      @c_Code_ConnString     NVARCHAR(30),    -- Chee03  
      @c_WSClientContingency NVARCHAR(1),     -- Chee03  
      @c_ConnectionString    NVARCHAR(250),  -- Chee03
      @c_ShippingKey         NVARCHAR(60),    -- Chee04
      @c_ListName_CarrierAcc NVARCHAR(10),    -- Chee04
      @c_Carrier             NVARCHAR(10)     -- Chee04
          
   DECLARE     
      @n_doc                   INT,    
      @c_TransactionIdentifier NVARCHAR(10),    
      @c_ShipmentID            NVARCHAR(10),    
      @n_Status_Code           INT,    
      @c_Status_Desc           NVARCHAR(215)    
    
   DECLARE @StoreSeqNoTempTable TABLE    
   (SeqNo INT);    
    
   DECLARE     
      @n_LogAttachmentID    INT    
     ,@c_Filename           NVARCHAR(60)    
     ,@n_LogFilekey         INT    
     ,@c_LineText           NVARCHAR(4000)    
          
   SET @c_errmsg                       = ''          
   SET @n_continue                     = 1          
   SET @n_StartTCnt                    = @@TRANCOUNT          
      
   SET @c_GetDate                      = ''           
   SET @c_Tablename                    = 'MBOL2LOG'      
   SET @c_TxFlag0                      = '0'  -- Open records           
   SET @c_TxFlag1                      = '1'  -- Records in progress            
   SET @c_TxFlag5                      = '5'       
   SET @c_TxFlag9                      = '9'           
   SET @d_Getdate                      = GETDATE()          
   SET @c_GetDate                      = CONVERT(VARCHAR, @d_GetDate, 112)            
                                       + LEFT(REPLACE(CONVERT(VARCHAR, @d_GetDate, 114),':',''),6)           
                   
   SET @c_UserName            = 'Administrator'     
   SET @c_ListName            = 'WebService'    
   SET @c_Code_FilePath       = 'FilePath'    
   SET @c_Code_AgileURL       = 'AgileURL'     -- Chee01     
   SET @c_Code_ConnString     = 'ConnString'   -- Chee03
   SET @c_ListName_CarrierAcc = 'CARRIERACC'   -- Chee04
    
   -- Log file Name    
   SET @c_FileName = 'AGILE_ShipRelease_' + @c_DataStream + '_' + RTRIM(@c_Storerkey) + '_' + REPLACE(REPLACE(REPLACE(convert(varchar, getdate(), 120),'-',''),':',''),' ','') + '.log'    
    
   --SET @c_WebRequestURL      = 'http://LFUSAAE15.lfusa.com/AgileElite Shipping/Services/XmlService.aspx'  -- Chee01         
   SET @c_WebRequestMethod   = 'POST'    
   SET @c_ContentType        = 'application/x-www-form-urlencoded'    
   SET @c_WebRequestEncoding = 'utf-8'    
   SET @c_XMLEncodingString  = '<?xml version="1.0" encoding="' + @c_WebRequestEncoding + '"?>'          
    
/* (ung01)    
   SELECT @c_Facility = S.Facility    
   FROM Storer S WITH (NOLOCK)    
   WHERE S.StorerKey = @c_StorerKey    
*/    
   EXEC dbo.nspGetRight    
      @c_Facility,    
      @c_StorerKey,    
      NULL,
      'AgileProcess',    
      @b_Success        OUTPUT,
      @c_AgileProcess   OUTPUT,
      @n_Err            OUTPUT,
      @c_ErrMsg         OUTPUT    
    
  IF NOT @b_Success = 1    
  BEGIN    
      SELECT @n_continue = 3         
      SELECT @n_err = 68016    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                         ': nspGetRight AgileProcess Failed. (isp1157P_Agile_ShipmentRelease)'      
      GOTO Quit    
  END    
    
  IF @c_AgileProcess <> '1'    
  BEGIN    
    GOTO Quit    
  END    
    
   -- Get WSConfig.ini File Path from CODELKUP    
   SELECT @c_IniFilePath = Long     
   FROM  CODELKUP WITH (NOLOCK)    
   WHERE ListName = @c_ListName    
   AND   Code = @c_Code_FilePath    
    
   IF ISNULL(@c_IniFilePath,'') = ''    
   BEGIN    
      SELECT @n_continue = 3         
      SELECT @n_err = 68001    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                         ': WSConfig.ini File Path is empty. (isp1157P_Agile_ShipmentRelease)'       
      GOTO Quit    
   END    
    
   -- Get Agile Web Service Request URL from CODELKUP (Chee01)    
   SELECT @c_WebRequestURL = Long         
   FROM CODELKUP WITH (NOLOCK)        
   WHERE ListName = @c_ListName        
     AND Code = @c_Code_AgileURL        
    
   IF ISNULL(@c_WebRequestURL,'') = ''        
   BEGIN        
      SELECT @n_continue = 3         
      SELECT @n_err = 68017    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                         ': Agile Web Service Request URL is empty. (isp1157P_Agile_ShipmentRelease)'       
      GOTO Quit    
   END        
    
   IF @n_debug = 1        
   BEGIN        
      SELECT @c_IniFilePath AS 'WSConfig.ini File Path',    
             @c_WebRequestURL AS 'Agile Web Service Request URL'        
   END            
    
   -- Get InterfaceLogID using [CNDTSITF].[dbo].[WebService_Log]    
  EXECUTE [CNDTSITF].[dbo].[nspg_getkey]    
       'InterfaceLogID'    
      , 10    
      , @n_LogAttachmentID OUTPUT    
      , @b_success         OUTPUT    
      , @n_err             OUTPUT    
      , @c_errmsg          OUTPUT    
    
  IF NOT @b_success = 1    
  BEGIN    
      SELECT @n_continue = 3        
      SELECT @n_err = 68002    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                         ': Failed to obtain InterfaceLogID. (isp1157P_Agile_ShipmentRelease)'       
      GOTO Quit    
  END    
    
  IF @n_debug = 1    
  BEGIN    
    SELECT @n_LogAttachmentID AS 'Log Attachment ID'    
  END    
    
   -- Get File Key using [CNDTSITF].[dbo].[WebService_Log]    
  EXECUTE nspg_getkey    
       'Filekey'    
      , 10    
      , @n_LogFilekey OUTPUT    
      , @b_success    OUTPUT    
      , @n_err        OUTPUT    
      , @c_errmsg     OUTPUT    
    
  IF NOT @b_success = 1    
  BEGIN    
      SELECT @n_continue = 3        
      SELECT @n_err = 68003    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                         ': Failed to obtain FileKey. (isp1157P_Agile_ShipmentRelease)'       
      GOTO Quit    
  END    
    
  IF @n_debug = 1    
  BEGIN    
    SELECT @n_LogFilekey AS 'File Key',    
             @c_DataStream AS 'DataStream'    
  END    
                                             
   /*********************************************/          
   /* Variables Declaration (End)               */          
   /*********************************************/          
          
   /*********************************************/          
   /* Std - Update Transmitflag to '1' (Start)  */          
   /*********************************************/            
   IF @n_continue = 1 OR @n_continue = 2          
   BEGIN       
          
      BEGIN TRAN    
    
      UPDATE dbo.TransmitLog3 WITH (ROWLOCK)    
      SET    Transmitflag  = @c_TxFlag1    
      WHERE  Tablename     = @c_Tablename    
      AND    Key3          = @c_StorerKey    
      AND    TransmitFlag  = @c_TxFlag0     
             
      IF @@ERROR = 0          
      BEGIN          
         WHILE @@TRANCOUNT > 0          
            COMMIT TRAN          
      END          
      ELSE          
      BEGIN          
         SELECT @n_continue = 3          
         SELECT @n_err = 68004          
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Update records in TransmitLog3 failed. (isp1157P_Agile_ShipmentRelease )'          
         GOTO QUIT       
      END          
            
   END           
   /************************************************************************************************/          
   /* Std - Update Transmitflag to '1' (End)                                                       */          
   /************************************************************************************************/          
   /* Main - Insert Records (Start)                                                                */          
   /************************************************************************************************/          
               
   DECLARE C_Shipment_OrderGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
   SELECT CS.PackageID, CS.TrackingNumber, CS.UCCLabelNo, MAX(CS.OrderKey)   
   FROM dbo.Transmitlog3 T WITH (NOLOCK)        
   JOIN dbo.MBOLDETAIL MD  WITH (NOLOCK) ON (T.Key1 = MD.MBOLKEY)   
   JOIN dbo.CartonShipmentDetail CS WITH (NOLOCK)     
   ON   (CS.OrderKey = MD.OrderKey)    
   JOIN dbo.Orders O WITH (NOLOCK) ON (CS.ORDERKEY = O.ORDERKEY)
   WHERE T.TableName    = @c_Tablename     
   AND   T.Transmitflag = @c_TxFlag1      
   AND   T.Key3         = @c_StorerKey       
   AND   ISNULL(O.specialhandling, '') NOT IN ('', 'N')     -- (james01)
   GROUP BY CS.PackageID, CS.TrackingNumber, CS.UCCLabelNo   
   ORDER BY CS.PackageID    
          
   OPEN C_Shipment_OrderGroup        
             
   FETCH NEXT FROM C_Shipment_OrderGroup INTO @c_PackageID, @c_TrackingNumber, @c_LabelNo, @c_OrderKey     
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN           
      SET @c_Status = '9'     
      SET @c_errmsg = ''    
      SET @c_LineText = ''    
      SET @c_PickSlipNo = ''    
      SET @n_CartonNo = NULL    
      SET @c_PackageWeight = ''
      SET @c_AccountID = ''  
    
      -- Delete Previous SeqNo    
      DELETE FROM @StoreSeqNoTempTable    
      WHERE SeqNo = @n_SeqNo    
      SET @n_SeqNo = NULL    
     
      -- Get PickSlipNo and CartonNo    
      SELECT     
         @c_PickSlipNo = pd.PickSlipNo,    
         @n_CartonNo   = pd.CartonNo    
      FROM PackDetail pd WITH (NOLOCK)    
      WHERE pd.UPC = @c_TrackingNumber    
   
      SELECT 
         @c_AccountID = RTRIM(O.M_Fax1),
         @c_Carrier   = CASE O.SpecialHandling     -- Chee04
                           WHEN 'U' THEN '12'              
                           WHEN 'X' THEN '17'              
                           WHEN 'N' THEN 'N'              
                           ELSE ''              
                        END 
      FROM   ORDERS O WITH (NOLOCK)   
      WHERE  O.OrderKey = @c_OrderKey      
         
      -- Get Package Weight    
      SELECT @c_PackageWeight = p.Weight    
      FROM   PackInfo p WITH (NOLOCK)     
      WHERE  p.PickSlipNo = @c_PickSlipNo     
      AND    p.CartonNo = @n_CartonNo    
    
      IF ISNULL(@c_PackageID,'') = ''    
      BEGIN     
         SELECT @c_Status = '5'    
         SELECT @n_err = 68005    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Package ID is empty. (isp1157P_Agile_ShipmentRelease)'       
         GOTO PROCESS_NEXT    
      END    
    
      IF ISNULL(@c_PackageWeight,'') = ''    
      BEGIN    
         SELECT @c_Status = '5'          
         SELECT @n_err = 68006    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Package Weight is empty. (isp1157P_Agile_ShipmentRelease)'      
         GOTO PROCESS_NEXT                                 
      END

      IF ISNULL(@c_Carrier,'') = ''              
      BEGIN
         SELECT @c_Status = '5'          
         SELECT @n_err = 68020    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Carrier Code is empty. (isp1157P_Agile_ShipmentRelease)'      
         GOTO PROCESS_NEXT
      END      

      -- Get Credentials/ShippingKey for Orders.SpecialHandling = 'X' (Chee04)
      IF @c_Carrier = '17'
      BEGIN
         IF ISNULL(@c_AccountID,'') = ''  
         BEGIN
            SELECT @c_Status = '5'          
            SELECT @n_err = 68021    
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': Account Number is empty. (isp1157P_Agile_ShipmentRelease)'      
            GOTO PROCESS_NEXT
         END  

         SELECT @c_ShippingKey = RTRIM(UDF03)
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = @c_ListName_CarrierAcc
           AND Code = @c_AccountID

         IF ISNULL(@c_ShippingKey,'') = ''  
         BEGIN
            SELECT @c_Status = '5'          
            SELECT @n_err = 68022    
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': Shipping Key is empty. (isp1157P_Agile_ShipmentRelease)'      
            GOTO PROCESS_NEXT
         END  
      END
    
      -- Create XML Request String    
      SET @x_RequestString =    
      (    
         SELECT     
            @c_PackageID  "TransactionIdentifier",    
            @c_PackageID  "ShipmentID",    
            (    
               SELECT    
                  (    
                     SELECT    
                  @c_PackageWeight   "Weight"    
                     FOR XML PATH('Package'), TYPE --PierbridgeShipReleaseRequest/Packages/Package    
                  )    
               FOR XML PATH('Packages'), TYPE --PierbridgeShipReleaseRequest/Packages    
            ),    
            (
               -- PierbridgeShipReleaseRequest/Credentials only required if Orders.SpecialHandling = 'X' (Chee04)
               SELECT CASE @c_Carrier WHEN '17' THEN
               (
                  SELECT  
                     @c_AccountID      "AccountNumber",
                     @c_ShippingKey    "ShippingKey"
                  FOR XML PATH('Credentials'), TYPE -- PierbridgeShipReleaseRequest/Credentials
               ) ELSE NULL END
            ),   
            @c_AccountID "UserName"    
         FOR XML PATH(''),    
         ROOT('PierbridgeShipReleaseRequest')    
      )    
    
      -- Create Request String    
      SET @c_RequestString = @c_XMLEncodingString + CAST(@x_RequestString AS NVARCHAR(MAX))    
    
      IF @n_debug = 1    
      BEGIN    
         SELECT @x_RequestString AS 'XML Request String'    
         SELECT @c_RequestString AS 'Request String'    
      END    
    
      -- Get BatchNo in [CNDTSITF].[dbo].[WebService_Log]    
      EXECUTE [CNDTSITF].[dbo].[nspg_getkey]    
      'WSDT_BatchNo'                
      , 10    
      , @c_BatchNo OUTPUT    
      , @b_success OUTPUT    
      , @n_err     OUTPUT    
      , @c_errmsg  OUTPUT    
    
      IF @b_success = 0    
      BEGIN    
         SELECT @n_continue = 3         
         SELECT @n_err = 68007    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Error executing [CNDTSITF].[dbo].[nspg_getkey]. (isp1157P_Agile_ShipmentRelease)'       
         GOTO Quit                                
      END    
    
      IF @n_debug = 1    
      BEGIN    
         SELECT     
            @c_BatchNo AS 'BatchNo',    
            @c_DataStream AS 'DataStream'    
      END      
    
      BEGIN TRAN     
    
      -- Insert Request String into [CNDTSITF].[dbo].[WebService_Log]    
      INSERT INTO [CNDTSITF].[dbo].[WebService_Log](    
         [DataStream],    
         [StorerKey],    
         [Type],     
         [BatchNo],     
         [WebRequestURL],     
         [WebRequestMethod],     
         [ContentType],     
         [RequestString],     
         [Status],    
         [ClientHost],     
         [WSIndicator],  
         [SourceKey],   
         [SourceType]  
      )    
      OUTPUT INSERTED.SeqNo INTO @StoreSeqNoTempTable    
      VALUES(    
         @c_DataStream,     
         @c_StorerKey,    
         'O',           -- Output    
         @c_BatchNo,    
         @c_WebRequestURL,     
         @c_WebRequestMethod,     
         @c_ContentType,     
         @c_RequestString,     
         @c_Status,    
         'C',           -- Client    
         'R',            -- RealTime    
         @c_LabelNo,  
         'isp1157P_Agile_ShipmentRelease'  
      )    
       
      IF @@ERROR <> 0     
      BEGIN        
         SELECT @n_continue = 3         
         SELECT @n_err = 68008    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Error inserting into [CNDTSITF].[dbo].[WebService_Log] Table. (isp1157P_Agile_ShipmentRelease)'       
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         COMMIT TRAN    
      END     
    
      -- Get SeqNo    
      SELECT @n_SeqNo = SeqNo     
      FROM @StoreSeqNoTempTable   

      -- Chee03  
      EXEC dbo.nspGetRight        
         NULL,
         NULL,
         NULL,
         'WebServiceClientContingency',        
         @b_Success              OUTPUT,        
         @c_WSClientContingency  OUTPUT,         
         @n_err                  OUTPUT,         
         @c_errmsg               OUTPUT    
        
      IF NOT @b_Success = 1        
      BEGIN        
         SELECT @n_continue = 3    
         SELECT @n_err = 68018   
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': nspGetRight WebServiceClientContingency Failed. (isp1157P_Agile_ShipmentRelease)'       
         GOTO Quit        
      END               

      IF @b_debug = 1        
      BEGIN        
         SELECT @c_WSClientContingency AS '@c_WSClientContingency'      
      END 
    
      SET @d_TimeIn = GETDATE()    
    
      IF @c_WSClientContingency <> '1'  
      BEGIN  
			--(KT01) - Start
         -- Send RequestString and Receive ResponseString     
         --EXEC [master].[dbo].[isp_GenericWebServiceClient]    
         --   @c_IniFilePath,    
         --   @c_WebRequestURL,    
         --   @c_WebRequestMethod,    
         --   @c_ContentType,    
         --   @c_WebRequestEncoding,    
         --   @c_RequestString,    
         --   @c_ResponseString   OUTPUT,    
         --   @c_VBErrMsg         OUTPUT    
         
			EXEC [master].[dbo].[isp_GenericWebServiceClient] @c_IniFilePath
																			, @c_WebRequestURL
																			, @c_WebRequestMethod --@c_WebRequestMethod
																			, @c_ContentType --@c_ContentType
																			, @c_WebRequestEncoding --@c_WebRequestEncoding
																			, @c_RequestString --@c_FullRequestString
																			, @c_ResponseString OUTPUT
																			, @c_VBErrMsg OUTPUT																 
																			, 10000 --@n_WebRequestTimeout -- Miliseconds
																			, '' --@c_NetworkCredentialUserName -- leave blank if no network credential
																			, '' --@c_NetworkCredentialPassword -- leave blank if no network credential
																			, 0 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
																			, '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
																			, '' --@c_HeaderAuthorization
																			, '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
			--(KT01) - End

         IF @@ERROR <> 0 OR ISNULL(@c_VBErrMsg,'') <> ''     
         BEGIN        
            SELECT @c_Status = '5'       
            SELECT @n_continue = 3                 
            SELECT @n_err = 68009    
       
            IF ISNULL(@c_VBErrMsg,'') <> ''        
            BEGIN        
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': ' + CAST(@c_VBErrMsg AS NVARCHAR(250)) + '. (isp1157P_Agile_ShipmentRelease)'      
            END     
            ELSE        
            BEGIN        
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp1157P_Agile_ShipmentRelease)'    
            END    
         END    
      END  
      ELSE  
      BEGIN  
         SELECT @c_ConnectionString = 'Data Source=' + UDF01 + ';uid=' + UDF02 + ';pwd=' + dbo.fnc_DecryptPWD(UDF03) 
                                     + ';Application Name=' + UDF04 + ';Enlist=false'
         FROM CODELKUP WITH (NOLOCK)  
         WHERE LISTNAME = @c_ListName  
           AND Code = @c_Code_ConnString  
     
         EXEC [master].[dbo].[isp_GenericWebServiceClient_Contingency]       
            @c_ConnectionString,  
            @c_IniFilePath,  
            @c_WebRequestURL,  
            @c_WebRequestMethod,  
            @c_ContentType,  
            @c_WebRequestEncoding,  
            @c_RequestString,  
            @c_ResponseString   OUTPUT,  
            @c_vbErrMsg         OUTPUT    
         
         IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> ''  
         BEGIN        
            SELECT @c_Status = '5'        
            SELECT @n_continue = 3        
            SELECT @n_err = 68019        
              
            -- SET @cErrmsg        
            IF ISNULL(@c_vbErrMsg,'') <> ''        
            BEGIN        
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': ' + CAST(@c_VBErrMsg AS NVARCHAR(250)) + '. (isp1157P_Agile_ShipmentRelease)'     
            END        
            ELSE        
            BEGIN        
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp1157P_Agile_ShipmentRelease)'     
            END        
         END    
      END -- IF @cWSClientContingency <> '1'  
    
      SET @d_TimeOut = GETDATE()    
      SET @n_TotalTime = DATEDIFF(ms, @d_TimeIn, @d_TimeOut)    
    
      BEGIN TRAN    
    
      UPDATE [CNDTSITF].[dbo].[WebService_Log] WITH (ROWLOCK)    
      SET Status = @c_Status, ErrMsg = @c_Errmsg, TimeIn = @d_TimeIn--, [Try] = [Try] + 1    
      WHERE SeqNo = @n_SeqNo    
     
      IF @@ERROR <> 0     
      BEGIN        
         SELECT @n_continue = 3         
         SELECT @n_err = 68010    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Error updating [CNDTSITF].[dbo].[WebService_Log] Table. (isp1157P_Agile_ShipmentRelease)'       
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         COMMIT TRAN    
      END     
          
      IF @c_Status = '5'    
      BEGIN    
         GOTO PROCESS_NEXT     
      END    
    
      -- Get rid of the encoding part in the root tag to prevent error: unable to switch the encoding    
      SET @x_ReponseString = CAST(REPLACE(@c_ResponseString, 'encoding="' + @c_WebRequestEncoding + '"', '') AS XML)    
    
      IF @n_debug = 1    
      BEGIN    
         SELECT @x_ReponseString AS 'XML Response String'    
         SELECT @c_ResponseString AS 'Response String'    
      END    
    
      BEGIN TRAN    
    
      -- Insert Response String into [CNDTSITF].[dbo].[WebService_Log]    
      INSERT INTO [CNDTSITF].[dbo].[WebService_Log](    
         [DataStream],    
         [StorerKey],    
         [Type],     
         [BatchNo],     
         [WebRequestURL],     
         [WebRequestMethod],     
         [ContentType],     
         [ResponseString],     
         [TimeOut],     
         [TotalTime],     
         [Status],    
         [ClientHost],     
         [WSIndicator],  
         [SourceKey],   
         [SourceType]  
      )     
      VALUES(    
         @c_DataStream,     
         @c_StorerKey,    
         'I',           -- Input    
         @c_BatchNo,    
         @c_WebRequestURL,     
         @c_WebRequestMethod,     
         @c_ContentType,     
         @c_ResponseString,     
         @d_TimeOut,     
         @n_TotalTime,     
         @c_Status,    
         'C',           -- Client    
         'R',           -- RealTime    
         @c_LabelNo,  
         'isp1157P_Agile_ShipmentRelease'  
      )    
    
      IF @@ERROR <> 0     
      BEGIN        
         SELECT @n_continue = 3         
         SELECT @n_err = 68011    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Error inserting into [CNDTSITF].[dbo].[WebService_Log] Table. (isp1157P_Agile_ShipmentRelease)'       
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         COMMIT TRAN    
      END     
    
      -- Extract ResponseString Data    
      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_ReponseString    
  
/* (Chee02)  
      SELECT       
         @c_TransactionIdentifier =  TransactionIdentifier,    
         @c_ShipmentID            =  ShipmentID,    
         @n_Status_Code           =  Code,    
         @c_Status_Desc           =  Description    
      FROM OPENXML (@n_doc, '/PierbridgeShipReleaseResponse', 2)    
      WITH(    
         TransactionIdentifier            NVARCHAR(20),    
         ShipmentID                       NVARCHAR(10),    
         Code                          INT          'Status/Code',    
         Description                      NVARCHAR(215) 'Status/Description'    
      )    
*/      
      -- SELECT statement that uses the OPENXML rowset provider. (Chee02)  
      SELECT     
         @c_TransactionIdentifier =  TransactionIdentifier,  
         @c_ShipmentID            =  ShipmentID,  
         @n_Status_Code           =  Code,  
         @c_Status_Desc           =  Description  
      FROM OPENXML (@n_doc, '/PierbridgeShipReleaseResponse/Packages/Package', 2)  
      WITH(  
         TransactionIdentifier            NVARCHAR(20) '../../TransactionIdentifier',  
         ShipmentID                       NVARCHAR(10) '../../ShipmentID',  
         Code                             INT          'Status/Code',  
         Description                      NVARCHAR(215) 'Status/Description'  
      )  
  
      EXEC sp_xml_removedocument @n_doc    
    
      IF @n_debug = 1    
      BEGIN    
      SELECT       
         @c_TransactionIdentifier AS 'TransactionIdentifier',    
         @c_ShipmentID  AS 'ShipmentID',    
         @n_Status_Code AS 'Status_Code',    
         @c_Status_Desc AS 'Status_Desc'    
      END    
    
      -- Response Failed    
      IF @n_Status_Code = 0    
      BEGIN      
         SELECT @c_Status = '5'    
         SELECT @n_err = 68012    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': ' + @c_Status_Desc + '. (isp1157P_Agile_ShipmentRelease)'       
         GOTO PROCESS_NEXT              
      END    
      -- Response Success    
      ELSE IF @n_Status_Code = 1    
      BEGIN    
         IF @n_Debug = 1    
         BEGIN    
            SELECT @c_Status_Desc AS 'Response Status Description'    
         END    
    
         IF @c_ShipmentID <> @c_PackageID    
         BEGIN    
            SELECT @c_Status = '5'    
            SELECT @n_err = 68013    
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                               ': Incorrect Shipment ID returned. (isp1157P_Agile_ShipmentRelease)'                                      
         END    
      END    
      ELSE IF @n_Status_Code <> 1    
      BEGIN        
         SELECT @c_Status = '5'    
         SELECT @n_err = 68014    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +          
                            ': Invalid Status Code. (isp1157P_Agile_ShipmentRelease)'          
      END    
    
      PROCESS_NEXT:    
    
         IF @c_Status = '5'    
         BEGIN    
            SET @c_LineText = 'AGILE Web Service ShipmentRelease Failed. Error: ' + RTRIM(@c_errmsg)    
                            + ', LabelNo: ' + RTRIM(@c_LabelNo)    
                            + ', PackageID: ' + RTRIM(@c_PackageID)    
    
            -- Insert error into Out_log    
            INSERT INTO [CNDTSITF].[dbo].[Out_log] (File_key, DataStream, [FileName], AttachmentID, LineText)    
            VALUES (@n_LogFilekey, @c_DataStream, @c_FileName, @n_LogAttachmentID, @c_LineText)    
         END    
           
      FETCH NEXT FROM C_Shipment_OrderGroup INTO @c_PackageID, @c_TrackingNumber, @c_LabelNo, @c_OrderKey       
   END -- END WHILE FOR C_Shipment_OrderGroup          
   CLOSE C_Shipment_OrderGroup          
   DEALLOCATE C_Shipment_OrderGroup          
          
   /************************************************************************************************/          
   /* Main - Insert Records (End)                                                                  */          
   /************************************************************************************************/          
   /* Std - Update Transmitflag to '3' (Start)                                                     */            
   /************************************************************************************************/          
            
   IF @n_continue = 1 OR @n_continue = 2            
   BEGIN            
   
      DECLARE C_Upd_TransmitLog3 CURSOR FAST_FORWARD READ_ONLY FOR          
      SELECT TransmitLogKey           
      FROM   dbo.TransmitLog3 T3 WITH (NOLOCK)          
      WHERE  T3.TableName    = @c_Tablename           
      AND    T3.Key3         = @c_StorerKey           
      AND    T3.Transmitflag = @c_TxFlag1           
           
      OPEN C_Upd_TransmitLog3          
      FETCH NEXT FROM C_Upd_TransmitLog3 INTO @c_TransmitLogKey          
      WHILE (@@FETCH_STATUS <> -1)          
      BEGIN          
          
         BEGIN TRAN    
               
         UPDATE dbo.TransmitLog3 WITH (ROWLOCK)            
         SET    Transmitflag   = @c_TxFlag9             
         WHERE  TransmitLogKey = @c_TransmitLogKey             
         AND    TransmitFlag   = @c_TxFlag1             
            
         IF @@ERROR = 0            
         BEGIN            
            WHILE @@TRANCOUNT > 0            
              COMMIT TRAN            
         END            
         ELSE            
         BEGIN            
            SELECT @n_continue = 3            
            SELECT @n_err = 68015            
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +            
                               ': Update records in TransmitLog3 failed. (isp1157P_Agile_ShipmentRelease )'         
            GOTO QUIT                                      
         END            
            
         FETCH NEXT FROM C_Upd_TransmitLog3 INTO @c_TransmitLogKey          
      END -- END WHILE FOR C_Upd_TransmitLog3          
      CLOSE C_Upd_TransmitLog3          
      DEALLOCATE C_Upd_TransmitLog3          
   END          
          
   /************************************************************************************************/          
   /* Std - Update Transmitflag to '3' (End)                                                       */          
   /************************************************************************************************/          
          
   QUIT:          
       
   IF CURSOR_STATUS('GLOBAL' , 'C_Shipment_OrderGroup') in (0 , 1)          
   BEGIN          
      CLOSE C_Shipment_OrderGroup          
      DEALLOCATE C_Shipment_OrderGroup          
   END          
       
   IF CURSOR_STATUS('GLOBAL' , 'C_Upd_TransmitLog3') in (0 , 1)          
   BEGIN          
      CLOSE C_Upd_TransmitLog3          
      DEALLOCATE C_Upd_TransmitLog3          
   END            
    
   /***********************************************/          
   /* Std - Send Email Alert (Start)              */          
   /***********************************************/         
       
   IF EXISTS (SELECT 1 FROM [CNDTSITF].[dbo].[Out_log]     
              WHERE File_key = @n_LogFilekey     
              AND DataStream = @c_DataStream)    
   BEGIN    
      EXEC [CNDTSITF].[dbo].[ispEmailAlert] @n_LogAttachmentID, @c_DataStream, 'I',     
                         'Error Log File for US AGILE ShipmentRelease' ,    
                         'Please refer to the attached file..', @b_Success  OUTPUT    
   END    
       
   /***********************************************/          
   /* Std - Send Email Alert (End)                */          
   /***********************************************/       
    
   /***********************************************/          
   /* Std - Error Handling (Start)                */          
   /***********************************************/          
   WHILE @@TRANCOUNT < @n_StartTCnt          
      BEGIN TRAN          
          
   IF @n_continue=3  -- Error Occured - Process And Return          
   BEGIN          
      SELECT @b_success = 0          
      IF @@TRANCOUNT > @n_StartTCnt          
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp1157P_Agile_ShipmentRelease '          
          
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
    RETURN          
   END          
   ELSE          
   BEGIN          
      SELECT @b_success = 1          
      WHILE @@TRANCOUNT > @n_StartTCnt          
      BEGIN          
         COMMIT TRAN          
      END          
      RETURN          
   END          
   /***********************************************/          
   /* Std - Error Handling (End)                  */          
   /***********************************************/          
END -- End Procedure


GO