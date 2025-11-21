SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Stored Procedure:  isp_PTL_Light_TMS                                      */
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-02-15 1.0 yeekung      WMS-16220 Created                              */
/******************************************************************************/
CREATE PROC [PTL].[isp_PTL_Light_TMS]
(
   @n_Func           INT
  ,@n_PTLKey         BIGINT
  ,@b_Success        INT OUTPUT
  ,@n_Err            INT OUTPUT
  ,@c_ErrMsg         NVARCHAR(215) OUTPUT
  ,@c_DeviceID       NVARCHAR(20) = ''
  ,@c_DevicePos      NVARCHAR(100) = ''
  ,@c_DeviceIP       NVARCHAR(40) = ''
  ,@c_DeviceStatus   NVARCHAR(1)=''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE --@c_DeviceIP        VARCHAR(40),
           @c_LightCommand    VARCHAR(MAX),
           @c_TCPMessage      VARCHAR(2000),
           @n_IsRDT           INT,
           @n_StartTCnt       INT,
           @n_Continue        INT,
           @c_DeviceType      NVARCHAR(20),
           --@c_DeviceProLogKey NVARCHAR(10),
           @c_LightAction     NVARCHAR(20),
           @c_PTLKey          CHAR(10),
           @n_LenOfValues     INT,  
           @c_CommandValue    NVARCHAR(15), 
           @nTranCount        INT,
           @cPutawayZone      NVARCHAR(20)
    
   DECLARE @c_StorerKey      NVARCHAR(15)            
          --,@c_DeviceID       VARCHAR(20)            
          --,@c_DevicePos      VARCHAR(10)   
          --,@c_LModMode       NVARCHAR(10)
          ,@n_LightLinkLogKey INT
          ,@dAddDate         DATETIME
          ,@c_BypassTCPSocketClient NVARCHAR(1)
          ,@c_RemoteEndPoint     NVARCHAR(50) 
          ,@c_SendMessage        VARCHAR(4000)
          ,@c_LocalEndPoint      VARCHAR(50)  
          ,@c_ReceiveMessage     VARCHAR(4000)
          ,@c_vbErrMsg           VARCHAR(4000)
          ,@c_IniFilePath        NVARCHAR(100)
          ,@n_SerialNo_Out         INT
   

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   BEGIN TRAN isp_PTL_Light_TMS

   SELECT top 1 @c_StorerKey=storerkey
   from deviceprofile (nolock)
   where deviceid=@c_DeviceID
   and storerkey<>''

   IF @c_DeviceStatus='1'
   BEGIN
      SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePos,1)

   END
   ELSE IF @c_DeviceStatus='0'
   BEGIN
      SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePos,@c_DeviceStatus)
   END

   SET @dAddDate = Getdate()


   SELECT TOP 1              
         @c_IniFilePath = c.UDF01,                       
         @c_RemoteEndPoint = c.Long                      
   FROM CODELKUP c WITH (NOLOCK)                      
   WHERE ListName    = 'TCPClient'                   
   AND   c.Short     = 'LIGHT'                        
   AND   c.Code      = @c_DeviceID    

   INSERT INTO PTL.LFLightLinkLOG(
         Application, LocalEndPoint,   RemoteEndPoint,
         SourceKey,      MessageType,     Data,
         Status,      AddDate,         DeviceIPAddress )
   VALUES(
            'LFLigthLink', '' , @c_RemoteEndPoint,
            @n_PTLKey, 'COMMAND', @c_LightCommand,
            '0', @dAddDate, @c_DeviceIP  )
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_Err = 163901
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, 'ENG', 'DSP') --InsLFLightLinkFail
      GOTO ROLLBACKTRAN
   END

   SET @n_LightLinkLogKey = @@identity
   SET @c_TCPMessage = @n_LightLinkLogKey                        
  

   INSERT INTO TCPSocket_OUTLog                             
      (MessageNum, MessageType, [Application], Data, Status, StorerKey, LabelNo, BatchNo, RemoteEndPoint)                             
   VALUES         
      ('', 'SEND', 'LF_LightLink', @c_LightCommand, '0', @c_StorerKey, '', '', @c_RemoteEndPoint) 

   IF @@ERROR <> 0
   BEGIN
      SET @n_Err = 163902
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, 'ENG', 'DSP') --InsTCPSocketFail
      GOTO ROLLBACKTRAN
   END

   SET @n_SerialNo_Out = @@identity   

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

   IF @c_BypassTCPSocketClient <> '1'       
   BEGIN              
      EXEC [master].[dbo].[isp_GenericTCPSocketClient]                      
       @c_IniFilePath,                      
       @c_RemoteEndPoint,                      
       @c_LightCommand,                      
       @c_LocalEndPoint     OUTPUT,                      
       @c_ReceiveMessage    OUTPUT,                      
       @c_vbErrMsg          OUTPUT                      
   END      

   IF ISNULL(@c_vbErrMsg,'') <> ''
   BEGIN
      SET @n_Err = 94009            
      SET @c_ErrMsg = @c_vbErrMsg      
                            
      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                         
      SET    STATUS = '5'                         
            , ErrMsg = ISNULL(@c_vbErrMsg, '')                         
            , LocalEndPoint = @c_LocalEndPoint               
            --, EndTime = GetDate()                 
      WHERE  SerialNo = @n_SerialNo_Out                        
              
      IF @@ERROR <> 0         
      BEGIN                      
         SET @b_Success=0                      
         SET @n_Err = 163903                     
         SET @c_ErrMsg = @c_vbErrMsg           
         SET @n_Continue = 3            
         GOTO RollBackTran        
      END        
              
      UPDATE PTL.LFLightLinkLOG WITH (ROWLOCK)                         
      SET    STATUS = '5'                    
            , ErrMsg = ISNULL(@c_vbErrMsg, '')                         
            , LocalEndPoint = @c_LocalEndPoint             
            , EndTime = GetDate()                   
      WHERE  SerialNo = @n_LightLinkLogKey  

      IF @@ERROR <> 0         
      BEGIN                      
         SET @b_Success=0                      
         SET @n_Err = 163904                     
         SET @c_ErrMsg = @c_vbErrMsg           
         SET @n_Continue = 3            
         GOTO RollBackTran        
      END    
   END
   ELSE
   BEGIN
      UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)                         
      SET    STATUS = '9'                       
            , ErrMsg = ISNULL(@c_ReceiveMessage, '')                         
            , LocalEndPoint = @c_LocalEndPoint             
            --, EndTime = GetDate()                   
      WHERE  SerialNo = @n_SerialNo_Out                      
                     
      IF @@ERROR <> 0         
      BEGIN                                    
         SET @b_Success=0                      
         SET @n_Err = 163905                      
         SET @c_ErrMsg = @c_vbErrMsg              
         SET @n_Continue = 3         
         GOTO RollBackTran             
      END            
           
      UPDATE PTL.LFLightLinkLOG WITH (ROWLOCK)                         
      SET    STATUS = '9'                   
            , ErrMsg = ISNULL(@c_vbErrMsg, '')                         
            , LocalEndPoint = @c_LocalEndPoint           
            , EndTime = GetDate()                     
      WHERE  SerialNo = @n_LightLinkLogKey        
                               
      IF @@ERROR <> 0         
      BEGIN                                    
         SET @b_Success=0                      
         SET @n_Err = 163906                   
         SET @c_ErrMsg = @c_vbErrMsg                  
         SET @n_Continue = 3          
         GOTO RollBackTran        
      END
   END 


   COMMIT TRAN isp_PTL_Light_TMS
   

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_PTL_Light_TMS -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN isp_PTL_Light_TMS
END


GO