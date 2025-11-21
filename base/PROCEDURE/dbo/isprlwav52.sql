SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV52                                              */
/* Creation Date: 2022-05-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19633 - TH-Nike-Wave Release                            */
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
/* 2022-05-12  Wan      1.0   Created.                                  */
/* 2022-05-12  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV52]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_debug       INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         
         --, @c_Facility        NVARCHAR(5) = ''
         --, @c_Storerkey       NVARCHAR(15)= ''
         --, @c_Release_Opt5    NVARCHAR(4000) = ''

         
         , @c_SQL             NVARCHAR(4000) = ''
         , @c_SQLParms        NVARCHAR(4000) = ''         
         
   -- Generate Validation for ispRLWAV52 include its sub SPs
   EXEC [dbo].[ispRLWAV52_VLDN]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
   ,  @b_debug    = @b_debug

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   
   -- B2B RPF Task 
   EXEC [dbo].[ispRLWAV52_RPF]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
   ,  @b_debug    = @b_debug

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- B2B Cartonization
   EXEC [dbo].[ispRLWAV52_PACK]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
   ,  @b_debug    = @b_debug

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   -- B2B CPK task        
   EXEC [dbo].[ispRLWAV52_CPK]
      @c_Wavekey  = @c_Wavekey 
   ,  @b_Success  = @b_Success   OUTPUT 
   ,  @n_Err      = @n_Err       OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
   ,  @b_debug    = @b_debug

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
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WAVE Table Failed. (ispRLWAV52)'   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV52'
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