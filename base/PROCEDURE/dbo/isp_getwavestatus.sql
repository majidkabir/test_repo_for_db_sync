SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                          
/* Store Procedure: isp_GetWaveStatus                                   */                                                                                          
/* Creation Date: 2019-10-04                                            */                                                                                          
/* Copyright: LFL                                                       */                                                                                          
/* Written by: Wan                                                      */                                                                                          
/*                                                                      */                                                                                          
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */        
/*                                                                      */                                                                                          
/* Called By: SCE                                                       */                                                                                          
/*          :                                                           */                                                                                          
/* PVCS Version: 1.0                                                    */                                                                                          
/*                                                                      */                                                                                          
/* Version: 8.0                                                         */                                                                                          
/*                                                                      */                                                                                          
/* Data Modifications:                                                  */                                                                                          
/*                                                                      */                                                                                          
/* Updates:                                                             */                                                                                          
/* Date        Author   Ver.  Purposes                                  */        
/* 17-Feb-2022 YTWan    1.1   Fix Wave.status not update to 9           */        
/*                            After MBOL Shipped - (JSM-51565)          */           
/************************************************************************/           
CREATE PROC [dbo].[isp_GetWaveStatus]        
      @c_WaveKey     NVARCHAR(15)         
   ,  @b_UpdateWave  INT            = 1    --1 => yes, 0 => No        
   ,  @c_Status      NVARCHAR(10)   = '0' OUTPUT        
   ,  @b_Success     INT            = 1   OUTPUT        
   ,  @n_Err         INT            = 0   OUTPUT        
   ,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT        
AS        
BEGIN           
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE          
           @n_StartTCnt       INT   = @@TRANCOUNT        
         , @n_Continue        INT   = 1        
        
   DECLARE @c_OrdStatus_Min   NVARCHAR(10) = '0'        
         , @c_OrdStatus_Max   NVARCHAR(10) = '0'        
        
   SELECT @c_OrdStatus_Min = ISNULL(MIN(O.[Status]),'0')          
         ,@c_OrdStatus_Max = ISNULL(MAX(O.[Status]),'0')          
   FROM WAVEDETAIL W WITH (NOLOCK)           
   JOIN ORDERS O WITH (NOLOCK) ON W.Orderkey = O.Orderkey           
   WHERE W.Wavekey = @c_WaveKey           
   AND   O.[Status] <= '9'                                               --(JSM-51565 start )                                             
   AND   O.SOStatus <>'CANC'          
          
   SET @c_Status = CASE WHEN @c_OrdStatus_Max IN ('0') THEN '0'          
                        WHEN @c_OrdStatus_Min IN ('0','1') AND @c_OrdStatus_Max > '1' THEN '1'          
                        WHEN @c_OrdStatus_Min IN ('2','3','4') AND @c_OrdStatus_Max > '2' THEN '2'             
                        WHEN @c_OrdStatus_Min IN ('5') AND @c_OrdStatus_Max > '5' THEN '5'               --(JSM-51565 end )          
                        ELSE @c_OrdStatus_Min         
                        END        
        
   IF @b_UpdateWave = 1        
   BEGIN        
      IF EXISTS ( SELECT 1        
                  FROM WAVE WITH (NOLOCK)        
                  WHERE Wavekey = @c_Wavekey        
                  AND   [Status] <> @c_Status        
                  )        
      BEGIN                           
         UPDATE WAVE         
            SET [Status] = @c_Status        
            ,   EditWho  = SUSER_SNAME()        
            ,   EditDate = GETDATE()        
            ,   TrafficCop = NULL          
         WHERE Wavekey = @c_WaveKey        
         AND [Status] <> @c_Status        
        
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_Continue = 3        
            SET @n_Err      = 67890        
            SET @c_ErrMsg   = ERROR_MESSAGE()        
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update WAVE Table fail. (isp_GetWaveStatus)'        
                            + '( ' + @c_ErrMsg + ' )'        
            GOTO QUIT_SP        
         END        
      END        
   END         
        
   QUIT_SP:        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
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
        
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetWaveStatus'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
   ELSE        
   BEGIN        
      SET @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
   END        
END 

GO