SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackAntiDiversion_Wrapper                        */
/* Creation Date: 2020-06-01                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13503 - SG - Prestige - Packing [CR]                    */
/*        :                                                             */
/* Called By: Normal packing - Packdetail ItemChanged                   */
/*          : of_isAntiDiversion()                                      */
/*          : SubSP ispPackADXX                                         */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackAntiDiversion_Wrapper]
           @c_PickSlipNo         NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @n_AntiDiversion      INT = 1        OUTPUT 
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

         , @c_PackChkAD_SP          NVARCHAR(30) = ''
         , @c_SQL                   NVARCHAR(4000) = ''
         , @c_SQLParms              NVARCHAR(1000) = ''

   SET @n_AntiDiversion = 1    
   SET @b_Success       = 1      
   SET @n_Err           = 0
   SET @c_Errmsg        = ''

   EXEC nspGetRight  
      @c_Facility          -- facility  
   ,  @c_Storerkey         -- Storerkey  
   ,  NULL                 -- Sku  
   ,  'PackChkAntiDiversion'   -- Configkey  
   ,  @b_Success                 OUTPUT   
   ,  @c_PackChkAD_SP            OUTPUT   
   ,  @n_Err                     OUTPUT   
   ,  @c_ErrMsg                  OUTPUT 
      
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 70010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_GetPackAntiDiversion_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 

   SET @c_PackChkAD_SP = ISNULL(RTRIM(@c_PackChkAD_SP),'')

   IF @c_PackChkAD_SP = '0'
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_PackChkAD_SP = RTRIM(@c_PackChkAD_SP)

   IF EXISTS (SELECT 1 FROM sys.objects (NOLOCK) where object_id = object_id(@c_PackChkAD_SP))
   BEGIN
      SET @c_SQL  = N'EXEC ' + @c_PackChkAD_SP 
                  + ' @c_PickSlipNo    = @c_PickSlipNo'
                  + ',@c_Storerkey     = @c_Storerkey'
                  + ',@c_Sku           = @c_Sku'
                  + ',@n_AntiDiversion = @n_AntiDiversion   OUTPUT'
                  + ',@b_Success       = @b_Success         OUTPUT'
                  + ',@n_Err           = @n_Err             OUTPUT'
                  + ',@c_ErrMsg        = @c_ErrMsg          OUTPUT'

      SET @c_SQLParms= N'@c_PickSlipNo    NVARCHAR(10) '
                     + ',@c_Storerkey     NVARCHAR(15) '
                     + ',@c_Sku           NVARCHAR(20) '
                     + ',@n_AntiDiversion INT            OUTPUT'
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms  
                        ,@c_PickSlipNo    
                        ,@c_Storerkey     
                        ,@c_Sku           
                        ,@n_AntiDiversion OUTPUT
                        ,@b_Success       OUTPUT
                        ,@n_Err           OUTPUT
                        ,@c_ErrMsg        OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 70020   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_PackChkAD_SP + '. (isp_GetPackAntiDiversion_Wrapper)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP  
      END
   END
   
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @n_AntiDiversion = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackAntiDiversion_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO