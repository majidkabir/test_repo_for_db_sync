SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: BondDPC Integration SP                                            */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2013-02-15 1.0  Shong      Created                                         */
/* 2014-05-15 1.1  Shong      Add Deveice Type when calling isp_DPC_SendMsg   */
/******************************************************************************/

CREATE PROC [dbo].[isp_DPC_DoMaintenance] 
(
   @c_StorerKey NVARCHAR(15)
  ,@c_DeviceID  NVARCHAR(20)
  ,@b_Success   INT OUTPUT  
  ,@n_Err       INT OUTPUT
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @c_DeviceIP   CHAR(40), 
           @c_DSPMessage VARCHAR(2000),
           @n_IsRDT      INT,
           @n_StartTCnt  INT,
           @n_Continue   INT,
           @c_DeviceType NVARCHAR(20)    
           
           
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1         
   
   BEGIN TRANSACTION
       
   SET @c_DeviceIP = ''
   SELECT @c_DeviceIP = ISNULL(ll.IPAddress,''), 
          @c_DeviceType = ll.DeviceType  
   FROM DeviceProfile ll WITH (NOLOCK)
   WHERE ll.DeviceID = @c_DeviceID 

   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''
   BEGIN
      SET @n_Err = 71000
      SET @c_ErrMsg = '72000 - Device Not Found in DeviceProfile'
      SET @n_Continue=3  
      GOTO EXIT_SP     
   END
   
   SET @c_DSPMessage = 'DO_MAINTENANCE<TAB>' + RTRIM(@c_DeviceIP)
   EXEC isp_DPC_SendMsg @c_StorerKey, @c_DSPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType


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
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_DoMaintenance'  
           
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
END

GO