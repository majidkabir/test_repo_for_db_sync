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
/******************************************************************************/

CREATE PROC [dbo].[isp_DPC_GenLightModuleMode] 
(
   @c_Stage            VARCHAR(15) -- Initial, Confirm, FnKey, FnKeyConfirm  
  ,@c_UpDownLight      VARCHAR(20) -- Off, On, Flash, Flash High
  ,@c_LightMode        VARCHAR(10) -- Off, On, Flash, Flash High
  ,@c_LightColor       VARCHAR(20) -- White, Orange, Purple, Red, LightBlue, Green, Blue
  ,@c_SEG              VARCHAR(20) -- Off, On, Flash, Flash High
  ,@c_BUZ              VARCHAR(20) -- Off, On, Flash, Flash High
  ,@c_FunctionKey      VARCHAR(10) = '' -- Enabled, Disabled
  ,@c_ConfirmButton    VARCHAR(10) = '' -- Enabled, Disabled
  ,@c_DecrementMode    VARCHAR(10) = '' -- Yes, NO
  ,@c_QtyRevisionKey   VARCHAR(20) = '' -- NotUse, Scroll, PlusMinus 
  ,@c_LMMCommand       VARCHAR(4000) OUTPUT
  ,@b_Success          INT OUTPUT  
  ,@n_Err              INT OUTPUT
  ,@c_ErrMsg           NVARCHAR(215) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET @b_Success=1

   DECLARE @n_IsRDT      INT,
           @n_StartTCnt  INT,
           @n_Continue   INT,
           @c_StageNo    CHAR(1)
           
   SELECT @c_StageNo = 
      CASE @c_Stage 
         WHEN 'FnKeyConfirm' THEN '4'
         WHEN 'FnKey'        THEN '3'
         WHEN 'Confirm'      THEN '2'
         ELSE '1'
      END
   
   SET  @n_StartTCnt = @@TRANCOUNT       
   
   SET @c_LMMCommand = ''
   IF @c_UpDownLight NOT IN ('Off', 'On', 'Flash', 'Flash High')
   BEGIN
      SET @n_Err = 72001
      SET @c_ErrMsg = '72001 - Invalid UpDownLight Mode ' + @c_UpDownLight
      SET @n_Continue=3  
      GOTO EXIT_SP         
   END
   
   SELECT @c_LMMCommand = @c_LMMCommand + 'UP/DOWN Lights Status ' + @c_StageNo + '=' + UPPER(@c_UpDownLight) 
   

   IF @c_LightMode NOT IN ('Off', 'On', 'Flash', 'Flash High')
   BEGIN
      SET @n_Err = 72002
      SET @c_ErrMsg = '72001 - Invalid Light Mode ' + @c_LightMode
      SET @n_Continue=3  
      GOTO EXIT_SP         
   END  
 
   IF @c_LightColor NOT IN ('White', 'Orange', 'Purple', 'Red', 'LightBlue', 'Green', 'Blue', 'Off')
   BEGIN
      SET @n_Err = 72002
      SET @c_ErrMsg = '72001 - Invalid Light Color ' + @c_LightColor
      SET @n_Continue=3  
      GOTO EXIT_SP         
   END     

   DECLARE @c_RGB CHAR(3)
   
   SELECT @c_RGB = 
          CASE @c_LightColor
             WHEN 'White'     THEN '111' 
             WHEN 'Orange'    THEN '011'
             WHEN 'Purple'    THEN '101'                          
             WHEN 'LightBlue' THEN '110'
             WHEN 'Red'       THEN '001'
             WHEN 'Green'     THEN '010'
             WHEN 'Blue'      THEN '100'
             WHEN 'Off'       THEN '000'
          END                       
             
   -- Red
   SELECT @c_LMMCommand = @c_LMMCommand + '&' + 
          CASE SUBSTRING(@c_RGB, 1, 1) 
            WHEN '1' THEN 'LED0 Status ' + @c_StageNo + '=' + CASE WHEN @c_LightMode IN ('Flash', 'Flash High') THEN UPPER(@c_LightMode) 
                                       ELSE 'ON' 
                                    END  
            ELSE 'LED0 Status ' + @c_StageNo + '=OFF'  
          END                               

   -- Green
   SELECT @c_LMMCommand = @c_LMMCommand + '&' + 
          CASE SUBSTRING(@c_RGB, 2, 1) 
            WHEN '1' THEN 'LED1 Status ' + @c_StageNo + '=' + CASE WHEN @c_LightMode IN ('Flash', 'Flash High') THEN UPPER(@c_LightMode) 
                                       ELSE 'ON' 
                                    END  
            ELSE 'LED1 Status ' + @c_StageNo + '=OFF'  
          END                               
          
   -- Blue
   SELECT @c_LMMCommand = @c_LMMCommand + '&' + 
          CASE SUBSTRING(@c_RGB, 3, 1) 
            WHEN '1' THEN 'LED2 Status ' + @c_StageNo + '=' + CASE WHEN @c_LightMode IN ('Flash', 'Flash High') THEN UPPER(@c_LightMode) 
                                       ELSE 'ON' 
                                    END  
            ELSE 'LED2 Status ' + @c_StageNo + '=OFF'  
          END    
          
   IF @c_SEG NOT IN ('Off', 'On', 'Flash', 'Flash High')
   BEGIN
      SET @n_Err = 72002
      SET @c_ErrMsg = '72001 - Invalid SEG Mode ' + @c_SEG
      SET @n_Continue=3  
      GOTO EXIT_SP         
   END  
   SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'SEG Status ' + @c_StageNo + '=' + UPPER(@c_SEG) 

   IF @c_BUZ NOT IN ('Off', 'On', 'Flash', 'Flash High')
   BEGIN
      SET @n_Err = 72002
      SET @c_ErrMsg = '72001 - Invalid SEG Mode ' + @c_SEG
      SET @n_Continue=3  
      GOTO EXIT_SP         
   END  
   SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'BUZ Status ' + @c_StageNo + '=' + UPPER(@c_BUZ) 

   IF @c_ConfirmButton IN ('Enabled', 'Disabled')
   BEGIN
      SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'CONFIRM button=' + CASE WHEN @c_FunctionKey = 'Enabled' THEN 'YES' ELSE 'NO' END 
   END     

      
   IF @c_FunctionKey IN ('Enabled', 'Disabled')
   BEGIN
      SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'Fn key=' + CASE WHEN @c_FunctionKey = 'Enabled' THEN 'YES' ELSE 'NO' END 
   END                      

   IF @c_DecrementMode IN ('YES','NO')
   BEGIN
      SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'Fn key decrement mode=' + UPPER(@c_DecrementMode)
   END                      
   
   IF @c_QtyRevisionKey IN ('NotUse', 'Scroll', 'PlusMinus')
   BEGIN
      SELECT @c_LMMCommand = @c_LMMCommand + '&' + 'Quantity revision key=' + 
            CASE @c_QtyRevisionKey
                 WHEN 'NotUse'    THEN 'NOT USE'
                 WHEN 'Scroll'    THEN 'DIG NUM'
                 WHEN 'PlusMinus' THEN 'PLUS MINUS'
            END
   END
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1         
   
   --PRINT   @c_LMMCommand
   --SET @c_DSPMessage = 'ADD_LM_MODE_STR<TAB>3<TAB>' + @c_LMMCommand
   --EXEC isp_DPC_SendMsg @c_StorerKey, @c_DSPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT


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
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_GenLightModuleMode'  
           
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