SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPostOrderProcessingStrategy                     */
/* Creation Date: 29-SEP-2014                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  306662-Change PostAllocationSP support                     */
/*                  allocation strategykey pickcode setup               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 17-04-2018   NJOW01  1.1   WMS-4345 Support post wave                */ 
/************************************************************************/
CREATE PROC [dbo].[ispPostOrderProcessingStrategy]  
     @c_OrderKey    NVARCHAR(10) = ''
   , @c_LoadKey     NVARCHAR(10) = ''
   , @C_Wavekey     NVARCHAR(10) = ''  --NJOW01
   , @c_StrategyKey NVARCHAR(30)  
   , @b_Success     INT           OUTPUT  
   , @n_Err         INT           OUTPUT  
   , @c_ErrMsg      NVARCHAR(250) OUTPUT  
   , @b_debug       INT = 0  
AS  
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
  
   DECLARE  @n_Continue                   INT,  
            @n_StartTCnt                  INT, -- Holds the current transaction count   
            @c_sCurrentLineNumber         NVARCHAR(5),
            @c_UOM                        NVARCHAR(10),
            @c_PickCode                   NVARCHAR(30),
            @c_LocationTypeOverride       NVARCHAR(10),
            @c_LocationTypeOverRideStripe NVARCHAR(10)

   DECLARE  @c_SQL         NVARCHAR(MAX),    
            @c_SQLParm     NVARCHAR(MAX)    
  
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0
   SELECT @c_ErrMsg=''
   SELECT @c_sCurrentLineNumber = SPACE(5)  
  
   IF @n_Continue=1 OR @n_Continue=2  
   BEGIN  
      IF (ISNULL(@c_OrderKey,'') = '' AND ISNULL(@c_LoadKey,'') = '' AND ISNULL(@c_WaveKey,'') = '') OR ISNULL(RTRIM(@c_StrategyKey),'') = ''
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @n_Err = 63500  
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Parameters Passed (ispPostOrderProcessingStrategy)'  
      END  
   END -- @n_Continue =1 or @n_Continue = 2  

   WHILE (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN  

      SELECT TOP 1  
             @c_sCurrentLineNumber = AllocateStrategyLineNumber , 
             @c_UOM = UOM,
             @c_PickCode = PickCode,
             @c_LocationTypeOverride = LocationTypeOverride,
             @c_LocationTypeOverRideStripe = LocationTypeOverRideStripe
      FROM AllocateStrategyDetail (NOLOCK)  
      WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
        AND AllocateStrategyKey = @c_StrategyKey  
      ORDER BY AllocateStrategyLineNumber  

      IF @@ROWCOUNT = 0  
      BEGIN  
         IF @b_debug = 1 OR @b_debug = 2  
         BEGIN  
            PRINT ''  
            PRINT ''  
            PRINT '-- No More Strategy'  
            PRINT '   CurrentLineNumber: ' +  RTRIM(@c_sCurrentLineNumber)  
            PRINT '   @c_StrategyKey: ' + RTRIM(@c_StrategyKey)  
         END  
         BREAK  
      END  

      IF @b_debug = 1 OR @b_debug = 2  
      BEGIN  
         PRINT ''  
         PRINT ''  
         PRINT '-- Allocate Strategy Found'
         PRINT '   CurrentLineNumber: ' +  RTRIM(@c_sCurrentLineNumber)  
         PRINT '   @c_StrategyKey: ' + RTRIM(@c_StrategyKey)  
      END  
  
      IF @b_debug = 1 OR @b_debug = 2  
      BEGIN  
         PRINT ''  
         PRINT ''  
         PRINT '-- Execute Allocate Strategy * ' + RTRIM(@c_PickCode) 
         PRINT '   EXEC ' +  RTRIM(@c_PickCode) + ' ' + '@c_Orderkey=''' + RTRIM(@c_OrderKey)
      END  

      IF EXISTS (SELECT 1
                 FROM [INFORMATION_SCHEMA].[PARAMETERS] 
                 WHERE SPECIFIC_NAME = @c_PickCode
                 AND PARAMETER_NAME = '@c_wavekey')  --NJOW01
      BEGIN
         SET @c_SQL = N'  
            EXECUTE ' + @c_PickCode  + CHAR(13) +  
            '  @c_OrderKey = @c_OrderKey ' + CHAR(13) +  
            ', @c_LoadKey  = @c_LoadKey  ' + CHAR(13) +
            ', @c_WaveKey  = @c_WaveKey  ' + CHAR(13) +
            ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
            ', @n_Err      = @n_Err       OUTPUT ' + CHAR(13) +  
            ', @c_ErrMsg   = @c_ErrMsg      OUTPUT ' + CHAR(13) + 
            ', @b_debug    = @b_Debug ' + CHAR(13) 
         
         SET @c_SQLParm =  N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_Wavekey NVARCHAR(10), ' +   
                            '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_Debug INT'         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_OrderKey, @c_LoadKey, @c_Wavekey,   
                            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_debug 
      END
      ELSE IF ISNULL(@c_Wavekey,'') = '' --NJOW04 Backward compatibility. if the custom sp is old version without wavekey and call from wave. don't execute the sp.
      BEGIN           
         SET @c_SQL = N'  
            EXECUTE ' + @c_PickCode  + CHAR(13) +  
            '  @c_OrderKey = @c_OrderKey ' + CHAR(13) +  
            ', @c_LoadKey  = @c_LoadKey  ' + CHAR(13) +
            ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
            ', @n_Err      = @n_Err       OUTPUT ' + CHAR(13) +  
            ', @c_ErrMsg   = @c_ErrMsg      OUTPUT ' + CHAR(13) + 
            ', @b_debug    = @b_Debug ' + CHAR(13) 
            --', @c_UOM' +
            --', @c_LocationTypeOverride' + 
            --', @c_LocationTypeOverRideStripe' + 
         
         SET @c_SQLParm =  N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), ' +   
                            '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_Debug INT'         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_OrderKey, @c_LoadKey,  
                            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_debug 
                         --,@c_UOM, LocationTypeOverride, @c_LocationTypeOverRideStripe 
      END                   
      
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63502    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PickCode +   
                          CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostOrderProcessingStrategy)'
      END  


      /*
      SET @c_SQL = N'
         EXECUTE ' + @c_PickCode + CHAR(13) +
         '  @c_Key ' +
         ', @c_UOM' +
         ', @c_LocationTypeOverride' + 
         ', @c_LocationTypeOverRideStripe' + 
         ', @b_Success   OUTPUT' + 
         ', @n_Err       OUTPUT' + 
         ', @c_ErrMsg    OUTPUT' +
         ', @b_Debug'

      SET @c_SQLParm =  N'@c_Key NVARCHAR(10), @c_UOM NVARCHAR(10), ' + 
                         '@c_LocationTypeOverride NVARCHAR(10), @c_LocationTypeOverRideStripe NVARCHAR(10), ' + 
                         '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_Debug INT'       
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Key, @c_UOM, LocationTypeOverride, @c_LocationTypeOverRideStripe, 
                         @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_debug

      IF @@ERROR <> 0 OR @b_Success <> 1
      BEGIN
         SELECT @n_Continue = 3  
         SELECT @n_Err = 63500  
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PickCode + 
                          CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostOrderProcessingStrategy)' 
      END
      */
   END -- LOOP ALLOCATE STRATEGY DETAIL Lines 
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostOrderProcessingStrategy'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
  
END -- Procedure

GO