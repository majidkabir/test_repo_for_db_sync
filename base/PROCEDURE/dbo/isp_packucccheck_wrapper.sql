SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackUCCCheck_Wrapper                                */
/* Creation Date: 03-Aug-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20384 - CN Converse Normal Pack Extend Validation       */
/*        :                                                             */
/* Called By: Normal packing - UCC (ue_ucc_rule)                        */
/*          : of_PackUCCCheck()                                         */
/*          : Storerconfig.Configkey = PackUCCCheck_SP                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-Aug-2022  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/
CREATE PROC [dbo].[isp_PackUCCCheck_Wrapper]
           @c_PickSlipNo         NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_UCCNo              NVARCHAR(20)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1

         , @c_PackUCCCheck_SP       NVARCHAR(30) = ''
         , @c_SQL                   NVARCHAR(4000) = ''
         , @c_SQLParms              NVARCHAR(1000) = ''

   SET @b_Success       = 1      
   SET @n_Err           = 0
   SET @c_Errmsg        = ''

   EXEC nspGetRight  
      @c_Facility          -- facility  
   ,  @c_Storerkey         -- Storerkey  
   ,  NULL                 -- Sku  
   ,  'PackUCCCheck_SP'    -- Configkey  
   ,  @b_Success                 OUTPUT   
   ,  @c_PackUCCCheck_SP         OUTPUT   
   ,  @n_Err                     OUTPUT   
   ,  @c_ErrMsg                  OUTPUT 
      
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 65535   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_PackUCCCheck_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 

   SET @c_PackUCCCheck_SP = ISNULL(RTRIM(@c_PackUCCCheck_SP),'')

   IF @c_PackUCCCheck_SP = '0'
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_PackUCCCheck_SP = RTRIM(@c_PackUCCCheck_SP)

   IF EXISTS (SELECT 1 FROM sys.objects (NOLOCK) where object_id = object_id(@c_PackUCCCheck_SP))
   BEGIN
      SET @c_SQL  = N'EXEC ' + @c_PackUCCCheck_SP 
                  + '  @c_PickSlipNo = @c_PickSlipNo'
                  + ', @c_UCCNo      = @c_UCCNo'
                  + ', @b_Success    = @b_Success  OUTPUT'
                  + ', @n_Err        = @n_Err      OUTPUT'
                  + ', @c_ErrMsg     = @c_ErrMsg   OUTPUT'

      SET @c_SQLParms= N'@c_PickSlipNo    NVARCHAR(10) '
                     + ',@c_UCCNo         NVARCHAR(15) '
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms  
                        ,@c_PickSlipNo    
                        ,@c_UCCNo     
                        ,@b_Success       OUTPUT
                        ,@n_Err           OUTPUT
                        ,@c_ErrMsg        OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_continue = 3  
         --SET @n_err = 65536   
         --SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_PackUCCCheck_SP + '. (isp_PackUCCCheck_Wrapper)'   
         --            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackUCCCheck_Wrapper'
   END
   ELSE
   BEGIN
      IF @b_Success <> 2
         SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO