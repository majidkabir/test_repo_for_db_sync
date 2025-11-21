SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43                                              */
/* Creation Date: 2021-07-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-15  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/

CREATE PROC [dbo].[ispRLWAV43]
   @c_Wavekey     NVARCHAR(10)    
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
         
         , @c_Facility        NVARCHAR(5) = ''
         , @c_Storerkey       NVARCHAR(15)= ''
         , @c_Release_Opt5    NVARCHAR(4000) = ''
         , @c_PPA_SP          NVARCHAR(30)= ''
         
         , @c_SQL             NVARCHAR(4000) = ''
         , @c_SQLParms        NVARCHAR(4000) = ''         
         
   SELECT TOP 1
         @c_Facility  = o.Facility
       , @c_Storerkey = o.Storerkey
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN ORDERS AS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey      
   WHERE w.WaveKey = @c_Wavekey
   ORDER BY w.WaveDetailKey
         
   EXEC nspGetRight          
         @c_Facility  = @c_Facility          
      ,  @c_StorerKey = @c_StorerKey         
      ,  @c_sku       = NULL          
      ,  @c_ConfigKey = 'ReleaseWave_SP'         
      ,  @b_Success   = @b_Success        OUTPUT          
      ,  @c_authority = ''           
      ,  @n_err       = @n_err            OUTPUT          
      ,  @c_errmsg    = @c_errmsg         OUTPUT   
      ,  @c_OPtion5   = @c_Release_Opt5   OUTPUT 
       
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- Generate Validation for ispRLWAV43 include its sub SPs
   EXEC [dbo].[ispRLWAV43_VLDN]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   -- ECOM Multi Order SortStation Loc Assignment & Generate Pack Task
   EXEC [dbo].[ispRLWAV43_PTL]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- ECOM Single Pack task generation
   EXEC [dbo].[ispRLWAV43_PTSK]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   -- B2B, B2C RPF Task 
   EXEC [dbo].[ispRLWAV43_RPF]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- B2B, B2C Cartonization
   EXEC [dbo].[ispRLWAV43_PACK]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- B2B PPA Calculation
   SET @c_PPA_SP = 'ispRLWAV43_PPA'
   SELECT @c_PPA_SP = dbo.fnc_GetParamValueFromString('@c_PPA_SP', @c_Release_Opt5, @c_PPA_SP) 
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects AS o WITH (NOLOCK) WHERE o.schema_id = SCHEMA_ID('dbo') 
                  AND o.[Name] = @c_PPA_SP AND o.[TYPE]='P') 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PPA SP not found: ' + @c_PPA_SP + '. (ispRLWAV43)'   
      GOTO QUIT_SP  
   END
      
   SET @c_SQL = N'EXEC dbo.' + @c_PPA_SP 
               + '  @c_Wavekey  = @c_Wavekey' 
               + ', @b_Success  = @b_Success   OUTPUT' 
               + ', @n_Err      = @n_Err       OUTPUT'
               + ', @c_ErrMsg   = @c_ErrMsg    OUTPUT'
                 
   SET @c_SQLParms = N'@c_Wavekey   NVARCHAR(10)'
                     + ',@b_Success   INT OUTPUT'
                     + ',@n_Err       INT OUTPUT'
                     + ',@c_ErrMsg    NVARCHAR(255) OUTPUT'
      
   EXEC sp_ExecuteSQL  @c_SQL 
                     , @c_SQLParms
                     , @c_Wavekey
                     , @b_Success   OUTPUT  
                     , @n_Err       OUTPUT
                     , @c_ErrMsg    OUTPUT
       
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   -- B2B & B2B CPK task        
   EXEC [dbo].[ispRLWAV43_CPK]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   -- B2B OTM Interface
   EXEC [dbo].[ispRLWAV43_ITF]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'Y'              
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
     
   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 69020    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WAVE Table Failed. (ispRLWAV43)'   
      GOTO QUIT_SP  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43'
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