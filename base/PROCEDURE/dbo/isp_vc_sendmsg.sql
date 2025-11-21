SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_VC_SendMsg                                     */  
/* Creation Date: 22-02-2013                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Chew KP                                                  */  
/*                                                                      */  
/* Purpose: WMS to Vocollect                                            */  
/*                                                                      */  
/*                                                                      */  
/* Input Parameters:  @c_MessageNo    - Unique no for Incoming data     */  
/*                                                                      */  
/* Output Parameters: @b_Success       - Success Flag  = 0              */  
/*                    @n_Err           - Error Code    = 0              */  
/*                    @c_ErrMsg        - Error Message = ''             */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
    
CREATE PROC [dbo].[isp_VC_SendMsg]   
(  
   @c_StorerKey NVARCHAR(15)  
  ,@c_Message   NVARCHAR(2000)   
  ,@b_Success   INT OUTPUT    
  ,@n_Err       INT OUTPUT  
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
     
   DECLARE    
      @c_IniFilePath          NVARCHAR(100),  
      @c_RemoteEndPoint       NVARCHAR(50),  
      @c_SendMessage          NVARCHAR(4000),  
      @c_LocalEndPoint        NVARCHAR(50) ,  
      @c_ReceiveMessage       NVARCHAR(4000),  
      @c_vbErrMsg             NVARCHAR(4000),  
      @n_DataLength           INT,  
      @c_VC_MessageNo        NVARCHAR(20),  
      @c_MessageNum_Out       NVARCHAR(20),  
      @n_Continue             INT,  
      @n_SerialNo_Out         INT,  
      @n_Status_Out           INT,  
      @c_DPC_RtnMessage       NVARCHAR(1000),  
      @c_DPC_RtnStatus        NVARCHAR(10),  
      @n_StartTCnt            INT,  
      @n_IsRDT                INT,  
      @c_DPC_RefNo            NVARCHAR(20)     
  
      SET @n_Continue = 1  
      SET @n_StartTCnt = @@TRANCOUNT   
        
      BEGIN TRANSACTION  
  
      SELECT @c_IniFilePath = c.UDF01,   
             @c_RemoteEndPoint = c.Long  
      FROM CODELKUP c WITH (NOLOCK)  
      WHERE ListName = 'TCPClient'   
      AND   c.Code = @c_StorerKey   
  
      IF ISNULL(RTRIM(@c_IniFilePath),'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 61000  
         SET @c_ErrMsg = 'File Path (UDF01) - TCPClientSetup Record Not Found CodeLkUp Table'  
         SET @n_Continue = 3  
         GOTO EXIT_SP  
      END  
  
      IF LEN(@c_RemoteEndPoint) < 15   
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 61001  
         SET @c_ErrMsg = 'Communication IP & Port (Long) Not Found CodeLkUp Table'  
         SET @n_Continue = 3  
         GOTO EXIT_SP           
      END  
  
        
      SET @b_Success = 0          
          
      EXECUTE nspg_GetKey          
         'TCPOUTLog',          
         10,             
         @c_MessageNum_Out OUTPUT,          
         @b_Success        OUTPUT,          
         @n_Err            OUTPUT,          
         @c_ErrMsg         OUTPUT          
           
      IF @b_Success = 1  
      BEGIN  
         SET @c_VC_MessageNo = @c_MessageNum_Out  
      END     
        
        
   SET @n_DataLength = 0  
     
   SET @c_SendMessage = @c_Message + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(1)
  
  
   INSERT INTO TCPSocket_OUTLog         
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)         
   VALUES         
      (@c_VC_MessageNo, 'SEND', 'VOCOLLECT', @c_SendMessage, '0', @c_StorerKey, '', '', @c_RemoteEndPoint)    
  
   SELECT @n_SerialNo_Out = SerialNo     
   FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)     
   WHERE  MessageNum    = @c_VC_MessageNo    
   AND    MessageType   = 'SEND'     
   AND    Status        = '0'    
        
   SET @c_vbErrMsg = ''  
   SET @c_ReceiveMessage = ''  
     
   EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
    @c_IniFilePath,  
    @c_RemoteEndPoint,  
    @c_SendMessage,  
    @c_LocalEndPoint     OUTPUT,  
    @c_ReceiveMessage    OUTPUT,  
    @c_vbErrMsg          OUTPUT  
  
--   SELECT   
--      @c_SendMessage '@c_SendMessage',    
--    @c_LocalEndPoint '@c_LocalEndPoint',    
--    @c_ReceiveMessage '@c_ReceiveMessage',    
--    @c_vbErrMsg '@c_vbErrMsg'  
  
--   IF ISNULL(RTRIM(@c_vbErrMsg),'') <> ''  
--   BEGIN  
--      SET @n_Status_Out = 5  
--        
--      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)     
--      SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)     
--           , ErrMsg = ISNULL(@c_vbErrMsg, '')     
--           , LocalEndPoint = @c_LocalEndPoint   
--      WHERE  SerialNo = @n_SerialNo_Out    
--        
--      SET @b_Success=0  
--     SET @n_Err = 67000  
--      SET @c_ErrMsg = @c_vbErrMsg  
--   END  
--   ELSE   
--   IF ISNULL(RTRIM(@c_ReceiveMessage),'') <> ''     
--   BEGIN  
--      EXEC [dbo].[isp_DPC_GetRtnStatus] @c_ReceiveMessage, @c_DPC_RtnStatus OUTPUT,@c_DPC_RtnMessage OUTPUT, @c_DPC_RefNo OUTPUT  
--        
--      IF @c_DPC_RtnStatus = 'NO'   
--      BEGIN  
--         SET @n_Status_Out = 5  
--           
--         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)     
--         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)     
--              , ErrMsg = ISNULL(@c_DPC_RtnMessage, '')     
--              , LocalEndPoint = @c_LocalEndPoint   
--         WHERE  SerialNo = @n_SerialNo_Out    
--           
--         SET @b_Success=0  
--         SET @n_Err = 67001  
--         SET @c_ErrMsg = @c_DPC_RtnMessage  
--                           
--      END  
--      ELSE  
--      BEGIN  
--          SET @n_Status_Out = 9  
--           
--         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)     
--         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)     
--              , ErrMsg = ISNULL(@c_ReceiveMessage, '')     
--              , LocalEndPoint = @c_LocalEndPoint   
--         WHERE  SerialNo = @n_SerialNo_Out  
--  
--         SET @b_Success=1  
--         SET @n_Err = 0  
--         SET @c_ErrMsg = ''                      
--      END  
--   END  
     
  
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
          RAISERROR (@n_err, 10, 1) WITH SETERROR     
          
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten    
      END       
      ELSE    
      BEGIN    
         ROLLBACK TRAN    
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_SendMsg'    
             
         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started      
         COMMIT TRAN    
             
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

SET ANSI_NULLS OFF

GO