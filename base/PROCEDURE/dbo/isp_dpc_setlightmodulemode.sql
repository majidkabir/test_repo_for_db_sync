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

CREATE PROC [dbo].[isp_DPC_SetLightModuleMode] 
(
   @c_StorerKey        NVARCHAR(15)
  ,@n_LMM_No           INT 
  ,@c_UpDownLight      VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_LightMode        VARCHAR(10) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_LightColor       VARCHAR(20) -- 0=White 1=Orange 2=Purple 3=Red 4=LightBlue 5=Green 6=Blue 7=Off
  ,@c_SEG              VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_BUZ              VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_CfmUpDownLight   VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_CfmLightMode     VARCHAR(10) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_CfmLightColor    VARCHAR(20) -- 0=White 1=Orange 2=Purple 3=Red 4=LightBlue 5=Green 6=Blue 7=Off
  ,@c_CfmSEG           VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_CfmBUZ           VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnUpDownLight    VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnLightMode      VARCHAR(10) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnLightColor     VARCHAR(20) -- 0=White 1=Orange 2=Purple 3=Red 4=LightBlue 5=Green 6=Blue 7=Off
  ,@c_FnSEG            VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnBUZ            VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnCfmUpDownLight VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnCfmLightMode   VARCHAR(10) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnCfmLightColor  VARCHAR(20) -- 0=White 1=Orange 2=Purple 3=Red 4=LightBlue 5=Green 6=Blue 7=Off
  ,@c_FnCfmSEG         VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High
  ,@c_FnCfmBUZ         VARCHAR(20) -- 0=Off 1=On 2=Flash 3=Flash High                                   --                                      
  ,@c_FunctionKey      VARCHAR(10) = 'Enabled' -- Enabled, Disabled
  ,@c_ConfirmButton    VARCHAR(10) = 'Enabled' -- Enabled, Disabled
  ,@c_DecrementMode    VARCHAR(10) = 'NO'      -- Yes, NO
  ,@c_QtyRevisionKey   VARCHAR(20) = 'Scroll'  -- NotUse, Scroll, PlusMinus   
  ,@b_Success          INT OUTPUT  
  ,@n_Err              INT OUTPUT
  ,@c_ErrMsg           NVARCHAR(215) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @c_DSPMessage VARCHAR(4000), 
           @c_LMMCommand VARCHAR(4000),
           @c_RtnCommand VARCHAR(4000),
           @n_IsRDT      INT,
           @n_StartTCnt  INT,
           @n_Continue   INT,
           @c_DeviceType NVARCHAR(20) 
   
   SET @c_LMMCommand = ''
      
   EXEC isp_DPC_GenLightModuleMode 
      @c_Stage       ='Initial' --Initial, Confirm, FnKey, FnKeyConfirm  
     ,@c_UpDownLight = @c_UpDownLight -- Off ,On ,Flash ,Flash High
     ,@c_LightMode   = @c_LightMode -- Off ,On ,Flash ,Flash High
     ,@c_LightColor  = @c_LightColor -- White, Orange, Purple, Red, LightBlue, Green, Blue
     ,@c_SEG         = @c_SEG  -- Off ,On ,Flash ,Flash High
     ,@c_BUZ         = @c_BUZ -- Off ,On ,Flash ,Flash High
     ,@c_LMMCommand  = @c_RtnCommand OUTPUT
     ,@b_Success     = @b_Success OUTPUT
     ,@n_Err         = @n_Err OUTPUT
     ,@c_ErrMsg      = @c_ErrMsg
     
   SET @c_LMMCommand = @c_RtnCommand
   
   EXEC isp_DPC_GenLightModuleMode 
      @c_Stage       ='Confirm' --Initial, Confirm, FnKey, FnKeyConfirm  
     ,@c_UpDownLight = @c_CfmUpDownLight -- Off ,On ,Flash ,Flash High
     ,@c_LightMode   = @c_CfmLightMode   -- Off ,On ,Flash ,Flash High
     ,@c_LightColor  = @c_CfmLightColor  -- White, Orange, Purple, Red, LightBlue, Green, Blue
     ,@c_SEG         = @c_CfmSEG  -- Off ,On ,Flash ,Flash High
     ,@c_BUZ         = @c_CfmBUZ  -- Off ,On ,Flash ,Flash High
     ,@c_LMMCommand  = @c_RtnCommand OUTPUT
     ,@b_Success     = @b_Success OUTPUT
     ,@n_Err         = @n_Err OUTPUT
     ,@c_ErrMsg      = @c_ErrMsg
   
   SET @c_LMMCommand = @c_LMMCommand + '&' + @c_RtnCommand

   EXEC isp_DPC_GenLightModuleMode 
      @c_Stage       ='FnKey' --Initial, Confirm, FnKey, FnKeyConfirm  
     ,@c_UpDownLight = @c_FnUpDownLight -- Off ,On ,Flash ,Flash High
     ,@c_LightMode   = @c_FnLightMode   -- Off ,On ,Flash ,Flash High
     ,@c_LightColor  = @c_FnLightColor  -- White, Orange, Purple, Red, LightBlue, Green, Blue
     ,@c_SEG         = @c_FnSEG  -- Off ,On ,Flash ,Flash High
     ,@c_BUZ         = @c_FnBUZ  -- Off ,On ,Flash ,Flash High
     ,@c_LMMCommand  = @c_RtnCommand OUTPUT
     ,@b_Success     = @b_Success OUTPUT
     ,@n_Err         = @n_Err OUTPUT
     ,@c_ErrMsg      = @c_ErrMsg
   
   SET @c_LMMCommand = @c_LMMCommand + '&' + @c_RtnCommand

   EXEC isp_DPC_GenLightModuleMode 
      @c_Stage          ='FnKeyConfirm'       -- Initial, Confirm, FnKey, FnKeyConfirm  
     ,@c_UpDownLight    = @c_FnCfmUpDownLight -- Off ,On ,Flash ,Flash High
     ,@c_LightMode      = @c_FnCfmLightMode   -- Off ,On ,Flash ,Flash High
     ,@c_LightColor     = @c_FnCfmLightColor  -- White, Orange, Purple, Red, LightBlue, Green, Blue
     ,@c_SEG            = @c_FnCfmSEG         -- Off ,On ,Flash ,Flash High
     ,@c_BUZ            = @c_FnCfmBUZ         -- Off ,On ,Flash ,Flash High
     ,@c_FunctionKey    = @c_FunctionKey      -- Enabled, Disabled
     ,@c_ConfirmButton  = @c_ConfirmButton    -- Enabled, Disabled
     ,@c_DecrementMode  = @c_DecrementMode    -- Yes, NO
     ,@c_QtyRevisionKey = @c_QtyRevisionKey   -- NotUse, Scroll, PlusMinus 
     ,@c_LMMCommand     = @c_RtnCommand OUTPUT
     ,@b_Success        = @b_Success OUTPUT
     ,@n_Err            = @n_Err OUTPUT
     ,@c_ErrMsg         = @c_ErrMsg
   
   SET @c_LMMCommand = @c_LMMCommand + '&' + @c_RtnCommand
         
                                
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1         
   
   PRINT  @c_LMMCommand
   SET @c_DSPMessage = 'ADD_LM_MODE_STR<TAB>' + CAST(@n_LMM_No AS VARCHAR(10)) + '<TAB>' + @c_LMMCommand
   
   DECLARE Cursor_Device CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT MAX(Code)
   FROM CODELKUP c WITH (NOLOCK) 
   WHERE c.LISTNAME = 'TCPClient' 
   AND Short = 'LIGHT'
   GROUP BY c.Long 
   
   OPEN Cursor_Device
   FETCH NEXT FROM Cursor_Device INTO @c_DeviceType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC isp_DPC_SendMsg @c_StorerKey, @c_DSPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType
      
      FETCH NEXT FROM Cursor_Device INTO @c_DeviceType
   END
   CLOSE Cursor_Device 
   DEALLOCATE Cursor_Device 

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
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_SetLightModuleMode'  
           
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