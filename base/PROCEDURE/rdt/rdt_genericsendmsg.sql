SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_GenericSendMsg                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-05-07 1.0  ChewKP  Created                                         */
/***************************************************************************/
CREATE PROC [RDT].[rdt_GenericSendMsg](
  @nMobile      INT,           
  @nFunc        INT,           
  @cLangCode    NVARCHAR( 3),  
  @nStep        INT,           
  @nInputKey    INT,           
  @cFacility    NVARCHAR( 5) , 
  @cStorerKey   NVARCHAR( 15), 
  @cType        NVARCHAR( 10), 
  @cDeviceID    NVARCHAR(10),
  @cMessage     NVARCHAR(MAX),
  @nErrNo       INT           OUTPUT, 
  @cErrMsg      NVARCHAR(250) OUTPUT  
  
   
) AS
BEGIN              
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF             
                 
   DECLARE                
      @c_IniFilePath        NVARCHAR(100),              
      @c_RemoteEndPoint     NVARCHAR(50),              
      @c_SendMessage        NVARCHAR(MAX),              
      @c_LocalEndPoint      VARCHAR(50) ,              
      @c_ReceiveMessage     VARCHAR(4000),              
      @c_vbErrMsg           VARCHAR(4000),              
      @n_DataLength           INT,              
      @c_WCS_MessageNo        VARCHAR(20),              
      --@c_MessageNum_Out       VARCHAR(20),              
      @n_Continue             INT,              
      @n_SerialNo_Out         INT,              
      @n_Status_Out           INT,              
      @c_WCS_RtnMessage       VARCHAR(1000),              
      @c_WCS_RtnStatus        VARCHAR(10),              
      @n_StartTCnt            INT,              
      @n_IsRDT                INT,              
      @c_WCS_RefNo            VARCHAR(20),       
      @c_BypassTCPSocketClient NVARCHAR(1),
      @b_success               INT,
      @c_ReturnErrorSP         NVARCHAR(20),
      @cSQL                    NVARCHAR(MAX),
      @cSQLParam               NVARCHAR(MAX)
      
      
      
      SET @n_StartTCnt = @@TRANCOUNT             
      SET @nErrNo = 0        
      
      BEGIN TRANSACTION          
      
      SET @n_Continue = 1          
      
      
      
      IF ISNULL(RTRIM(@cDeviceID),'') <> ''      
      BEGIN      
         SELECT TOP 1      
                @c_IniFilePath = c.UDF01,               
                @c_RemoteEndPoint = c.Long ,     
                @c_ReturnErrorSP = c.UDF02          
         FROM CODELKUP c WITH (NOLOCK)              
         WHERE ListName    = 'TCPClient'           
         AND   c.Short     = @cType              
         AND   c.Code      = @cDeviceID    
         AND   c.StorerKey = @cStorerKey                
      END        
      
      
--      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''        
--      BEGIN      
--         IF ISNULL(RTRIM(@c_DeviceType),'') = ''      
--         BEGIN      
--            SELECT TOP 1      
--                   @c_IniFilePath = c.UDF01,               
--                   @c_RemoteEndPoint = c.Long              
--            FROM CODELKUP c WITH (NOLOCK)              
--            WHERE ListName = 'TCPClient'           
--            AND   c.Short  = 'WCS'                           
--         END        
--         ELSE      
--         BEGIN              
--            SELECT TOP 1      
--                   @c_IniFilePath = c.UDF01,               
--                   @c_RemoteEndPoint = c.Long              
--            FROM CODELKUP c WITH (NOLOCK)               
--            WHERE ListName = 'TCPClient'       
--            AND   c.Code   = @c_DeviceType            
--            AND   c.Short  = 'WCS'                           
--         END      
--      END      
      
      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''              
      BEGIN              
         --SET @b_Success = 0    
         SET @nErrNo = 124051              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         SET @n_Continue = 3              
         GOTO EXIT_SP              
      END              
      
      IF LEN(@c_RemoteEndPoint) < 15               
      BEGIN              
         --SET @b_Success = 0              
         SET @nErrNo = 124052              
         --SET @cErrMsg = 'Communication IP & Port (Long) Not Found CodeLkUp Table'       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --IPPortNotFound       
         SET @n_Continue = 3              
         GOTO EXIT_SP                       
      END              
      
      --SET @b_Success = 0                      
   
      
   SET @c_SendMessage = RTRIM(@cMessage) 

   --PRINT @c_RemoteEndPoint
   --PRINT @c_SendMessage
   
   SET @c_SendMessage = @cMessage

   INSERT INTO TCPSocket_OUTLog                     
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)                     
   VALUES                     
      ('', 'SEND', 'LF_TCPIP', @c_SendMessage, '0', @cStorerKey, '', '', @c_RemoteEndPoint)                
      
   SET @n_SerialNo_Out = @@identity       
   --SET @b_Success = 0                    
      
   SET @c_BypassTCPSocketClient = ''      
   EXECUTE nspGetRight      
      NULL,       
      @cStorerKey,      
      NULL,      
      'BypassTCPSocketClient',      
      @b_success                 OUTPUT,      
      @c_BypassTCPSocketClient   OUTPUT,      
      @nErrNo                     OUTPUT,      
      @cErrMsg                  OUTPUT      
      
   SET @c_vbErrMsg = ''              
   SET @c_ReceiveMessage = ''         
  


   IF @c_BypassTCPSocketClient <> '1'      
   BEGIN      
      EXEC [master].[dbo].[isp_GenericTCPSocketClient]              
       @c_IniFilePath,              
       @c_RemoteEndPoint,              
       @c_SendMessage,              
       @c_LocalEndPoint     OUTPUT,              
       @c_ReceiveMessage    OUTPUT,              
       @c_vbErrMsg          OUTPUT              
   END      
   
   --PRINT @c_vbErrMsg + 'aadfasdfasfd'

                       
   IF ISNULL(RTRIM(@c_vbErrMsg),'') <> ''              
   BEGIN              
      SET @n_Status_Out = 5              
      
      SET @nErrNo = 124059    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                    
      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                 
      SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)                 
           , ErrMsg = ISNULL(@c_vbErrMsg, '')                 
           , LocalEndPoint = @c_LocalEndPoint       
           --, EndTime = GetDate()         
      WHERE  SerialNo = @n_SerialNo_Out                
      
      IF @@ERROR <> 0 
      BEGIN              
         SET @b_Success=0              
         SET @nErrNo = 124053             
         --SET @cErrMsg = @c_vbErrMsg   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --UpdTCPOutLogFail       
         SET @n_Continue = 3    
      END
      
      
      
   END              
   ELSE               
   IF ISNULL(RTRIM(@c_ReceiveMessage),'') <> ''                 
   BEGIN              
      --EXEC [PTL].[isp_PTL_GetRtnStatus] @c_ReceiveMessage, @c_WCS_RtnStatus OUTPUT,@c_WCS_RtnMessage OUTPUT, @c_WCS_RefNo OUTPUT              
      SET @c_WCS_RtnStatus = '' 
      
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_ReturnErrorSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @c_ReturnErrorSP) +
            ' @c_ReceiveMessage, @c_WCS_RtnStatus OUTPUT,@c_WCS_RtnMessage OUTPUT'
         SET @cSQLParam =
            '@c_ReceiveMessage        NVARCHAR( 4000),         ' +
            '@c_WCS_RtnStatus         NVARCHAR( 10)    OUTPUT, ' +
            '@c_WCS_RtnMessage        NVARCHAR( 4000)  OUTPUT  ' 
           

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @c_ReceiveMessage, @c_WCS_RtnStatus OUTPUT,@c_WCS_RtnMessage OUTPUT

         --IF @nErrNo <> 0
         --BEGIN
         --   SET @n_Continue = 3              
         --   GOTO EXIT_SP  
         --END
      END


         
      IF @c_WCS_RtnStatus = 'NO'               
      BEGIN              
         SET @n_Status_Out = 5    
         
         SET @nErrNo = 124060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
                       
         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                 
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)                 
              , ErrMsg = ISNULL(@c_ReceiveMessage, '')                 
              , LocalEndPoint = @c_LocalEndPoint   
              --, EndTime = GetDate()             
         WHERE  SerialNo = @n_SerialNo_Out                
         
         IF @@ERROR <> 0 
         BEGIN                            
            SET @b_Success=0              
            SET @nErrNo = 124055              
            --SET @cErrMsg = @c_WCS_RtnMessage     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --UpdTCPOutLogFail  
         END
         
                           
      END              
      ELSE              
      BEGIN              
         SET @n_Status_Out = 9              
         
                       
         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                 
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)                 
              , ErrMsg = ISNULL(@c_ReceiveMessage, '')                 
              , LocalEndPoint = @c_LocalEndPoint     
              --, EndTime = GetDate()           
         WHERE  SerialNo = @n_SerialNo_Out              
             
         IF @@ERROR <> 0 
         BEGIN                            
            SET @b_Success=0              
            SET @nErrNo = 124057              
            --SET @cErrMsg = @c_vbErrMsg      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --UpdTCPOutLogFail     
            SET @n_Continue = 3      
         END    

                                   
      END              
   END              
                 
              
EXIT_SP:              
   IF @n_Continue=3  -- Error Occured - Process And Return                
   BEGIN                
       --DECLARE @n_IsRDT INT                
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT                
                      
      IF @n_IsRDT = 1 -- (ChewKP01)                
      BEGIN                
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here                
          -- Instead we commit and raise an error back to parent, let the parent decide                
                      
          -- Commit until the level we begin with                
          WHILE @@TRANCOUNT > @n_StartTCnt                
             COMMIT TRAN                
                      
          -- Raise error with severity = 10, instead of the default severity 16.                 
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger            
          RAISERROR (@nErrNo, 10, 1) WITH SETERROR                 
                      
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten                
      END                   
      ELSE                
      BEGIN                
         ROLLBACK TRAN                
                    
                         
         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started                  
         COMMIT TRAN                
                 
         EXECUTE nsp_logerror @nErrNo, @cErrMsg, 'isp_PTL_SendMsg'             
                         
         RETURN                
      END                
                      
   END                
   ELSE                
   BEGIN                
      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started                  
         COMMIT TRAN                
                   
      RETURN                
   END                      
END -- procedure 

GO