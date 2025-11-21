SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/        
/* Stored Procedure: isp_PTL_TVSendMsg                                        */      
/* Copyright: IDS                                                             */               
/* Purpose: THG PTL Logic                                                     */                 
/*                                                                            */               
/* Modifications log:                                                         */               
/*                                                                            */               
/* Date       Rev  Author     Purposes                                        */               
/* 2019-06-24 1.0  YeeKung    WMS-9312 Created                                */         
/******************************************************************************/              
CREATE PROC [PTL].[isp_PTL_TVSendMsg]                     
(                    
   @c_StorerKey  NVARCHAR(15)    
  ,@cLangCode    NVARCHAR( 3)                      
  ,@c_Message    NVARCHAR(2000)             
  ,@b_Success    INT           OUTPUT                      
  ,@n_Err        INT           OUTPUT                    
  ,@c_ErrMsg     NVARCHAR(215) OUTPUT                   
  ,@c_DeviceID   NVARCHAR(20) = ''      
                      
)      
AS                    
BEGIN                    
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF       
    
      DECLARE                      
         @c_IniFilePath             NVARCHAR(100),                    
         @c_RemoteEndPoint          NVARCHAR(50),                    
         @c_SendMessage             NVARCHAR(4000),                    
         @c_LocalEndPoint           NVARCHAR(50) ,                    
         @c_ReceiveMessage          NVARCHAR(4000),                    
         @c_vbErrMsg                NVARCHAR(4000),                    
         @n_DataLength              INT,                    
         @c_PTL_MessageNo           NVARCHAR(20),                                 
         @n_Continue                INT,                    
         @n_SerialNo_Out            INT,                    
         @n_Status_Out              INT,                    
         @c_PTL_RtnMessage          NVARCHAR(1000),                    
         @c_PTL_RtnStatus           NVARCHAR(10),                    
         @n_StartTCnt               INT,                    
         @n_IsRDT                   INT,                    
         @c_PTL_RefNo               NVARCHAR(20),             
         @c_BypassTCPSocketClient   NVARCHAR(1),      
         @n_LightLinkLogKey         INT    
    
    
      SET @n_StartTCnt = @@TRANCOUNT                   
      SET @n_Err = 0              
            
      BEGIN TRANSACTION                
      SAVE TRAN isp_PTL_TVSendMsg        
               
      SET @n_Continue = 1         
                
      IF ISNULL(RTRIM(@c_DeviceID),'') <> ''            
      BEGIN            
         SELECT TOP 1            
            @c_IniFilePath = c.UDF01,                     
            @c_RemoteEndPoint = c.Long                    
         FROM CODELKUP c WITH (NOLOCK)                    
         WHERE ListName    = 'TCPClient'                 
         AND   c.Short     = 'TV'                      
        AND   c.Code      = @c_DeviceID    
        -- AND   c.storerkey = @c_StorerKey                          
      END    
                   
      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''                    
      BEGIN                    
         SET @b_Success = 0          
         SET @n_Err = 94001                    
         SET @c_ErrMsg = 'File Path (UDF01) - TCPClientSetup Record Not Found CodeLkUp Table'                    
         SET @n_Continue = 3                    
         GOTO RollBackTran                    
      END      
    
      IF LEN(@c_RemoteEndPoint) < 15                
      BEGIN                    
         SET @b_Success = 0                    
         SET @n_Err = 94002                    
         SET @c_ErrMsg = 'Communication IP & Port (Long) Not Found CodeLkUp Table'                    
         SET @n_Continue = 3                    
         GOTO RollBackTran                             
      END      
          
      SET @b_Success = 0                            
            
      SET @c_SendMessage = RTRIM(@c_Message)     
    
      INSERT INTO TCPSocket_OUTLog                           
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)                           
      VALUES                           
      ('', 'SEND', 'LF_Panel', @c_SendMessage, '0', @c_StorerKey, '', '', @c_RemoteEndPoint)                      
            
      SET @n_SerialNo_Out = @@identity             
      SET @b_Success = 0                          
            
      SET @c_BypassTCPSocketClient = ''            
      EXECUTE nspGetRight            
         NULL,             
         @c_StorerKey,            
         NULL,            
         'BypassTCPSocketClient',            
         @b_success                 OUTPUT,            
         @c_BypassTCPSocketClient   OUTPUT,            
         @n_Err                     OUTPUT,            
         @c_errmsg                  OUTPUT            
            
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
                         
      IF ISNULL(RTRIM(@c_vbErrMsg),'') <> ''                    
      BEGIN                    
         SET @n_Status_Out = 5                    
            
         SET @n_Err = 94009          
         SET @c_ErrMsg = 'TCPSocketError'        
                          
         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                       
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)                       
              , ErrMsg = ISNULL(@c_vbErrMsg, '')                       
              , LocalEndPoint =  ISNULL(@c_LocalEndPoint,'')             
              --, EndTime = GetDate()               
         WHERE  SerialNo = @n_SerialNo_Out                      
            
         IF @@ERROR <> 0       
         BEGIN                    
            SET @b_Success=0                    
            SET @n_Err = 94003                   
            SET @c_ErrMsg = @c_vbErrMsg         
            SET @n_Continue = 3          
            GOTO RollBackTran      
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
               SET @n_Err = 94007                      
               SET @c_ErrMsg = @c_vbErrMsg              
               SET @n_Continue = 3         
               GOTO RollBackTran             
            END   
         END     
              
      END    
   GOTO EXIT_SP    
END      
      
RollBackTran:        
   ROLLBACK TRAN isp_PTL_TVSendMsg -- Only rollback change made here        
        
EXIT_SP:                
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started        
      COMMIT TRAN isp_PTL_TVSendMsg       

GO