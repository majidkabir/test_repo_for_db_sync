SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Stored Procedure:  isp_PTL_Initialize                                      */  
/* Copyright: IDS                                                             */  
/* Purpose: Sending Z Command Integration SP                                  */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2017-03-17 1.0  ChewKP     Created                                         */  
/******************************************************************************/  
CREATE PROC [PTL].[isp_PTL_Initialize]  
(  
   @n_Func           INT  
  ,@c_StorerKey      NVARCHAR(15)   
  ,@b_Success        INT OUTPUT  
  ,@n_Err            INT OUTPUT  
  ,@c_ErrMsg         NVARCHAR(215) OUTPUT  
  ,@c_DeviceIP       NVARCHAR(40) = ''  
  ,@c_LModMode       NVARCHAR(10) = ''  
   
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
           --@n_IsRDT           INT,  
           @n_StartTCnt       INT,  
           @n_Continue        INT,  
           @c_DeviceType      NVARCHAR(20),  
           --@c_DeviceProLogKey NVARCHAR(10),  
           @c_LightAction     NVARCHAR(20),  
           @c_PTLKey          CHAR(10),  
           @n_LenOfValues     INT,    
           @c_CommandValue    NVARCHAR(15),   
           @nTranCount        INT,  
           @cLangCode         NVARCHAR(3)  
      
   DECLARE --@c_StorerKey      NVARCHAR(15)              
          --,@c_DeviceID       VARCHAR(20)              
          --,@c_DevicePos      VARCHAR(10)     
          --,@c_LModMode       NVARCHAR(10)  
          @n_LightLinkLogKey INT  
          ,@dAddDate         DATETIME  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
--   IF NOT EXISTS(SELECT 1 FROM PTL.PTLTran p WITH (NOLOCK)  
--                 WHERE p.PTLKey = @n_PTLKey  
--                   AND p.[Status]<>'9')  
--   BEGIN  
--      SET @n_Err = 94052  
--      SET @c_ErrMsg = '94052 - No Record Found in PTLTRAN, PTLKey=' + CAST(@n_PTLKey AS VARCHAR(10))  
--      SET @n_Continue=3  
--      GOTO EXIT_SP  
--   END  
  
   IF @c_DeviceIP = ''  
   BEGIN  
         --SET @n_Err = 107051  
         --SET @c_ErrMsg = '94051 - PTLKey Requied'  
           
         SET @n_Err = 107051  
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP') --IPAddressReq  
                       
         SET @n_Continue=3  
         GOTO Quit  
   END  
  
  
   IF ISNULL(RTRIM(@c_LModMode),'')  = ''  
   BEGIN  
         SET @n_Err = 107052  
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP') --LModeReq  
                       
         SET @n_Continue=3  
         GOTO Quit  
   END  
  
   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''  
   BEGIN  
      SET @n_Err = 94053  
      SET @c_ErrMsg = '94053 - IP Address cannot be NULL'  
      SET @n_Continue=3  
      GOTO Quit  
   END  
  
   SELECT TOP 1  @c_DeviceType = ll.DeviceType  
              ,@c_StorerKey = ll.StorerKey  
   FROM DeviceProfile ll WITH (NOLOCK)  
   WHERE ll.IPAddress = @c_DeviceIP  
        
   SELECT @c_LightCommand = SUBSTRING(Description,1,1)  
   FROM PTL.LightMode WITH (NOLOCK)   
   WHERE LightModeNo = @c_LModMode  
     
   SET @dAddDate = Getdate()  
  
   INSERT INTO PTL.LFLightLinkLOG(  
          Application, LocalEndPoint,   RemoteEndPoint,  
          SourceKey,      MessageType,     Data,  
          Status,      AddDate,         DeviceIPAddress )  
   VALUES(  
          'LFLigthLink', '' , '',  
          0, 'COMMAND', @c_LightCommand,  
          '0', @dAddDate, @c_DeviceIP  )  
  
   SET @n_LightLinkLogKey = @@identity  
   SET @c_TCPMessage = @n_LightLinkLogKey  
  
   EXEC PTL.isp_PTL_SendMsg @c_StorerKey, @c_TCPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType  
                           ,''  
  
   IF @n_Err <> 0  
   BEGIN  
      SET @n_Continue=3  
      GOTO Quit  
   END  
   ELSE  
   BEGIN  
      -- Handling transaction  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN isp_PTL_Initialize -- For rollback or commit only our own transaction     
  
      INSERT INTO PTL.LightInput ( IPAddress, DevicePosition, OutputData, Status, AddDate )  
      VALUES ( @c_DeviceIP, '', @c_LightCommand, '9' , @dAddDate )  
  
      
  
      COMMIT TRAN isp_PTL_Initialize  
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN isp_PTL_Initialize -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO