SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispPKUCCChk02                                           */
/* Creation Date: 13-Dec-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: ChongCS                                                  */
/*                                                                      */
/* Purpose: WMS-21313 -[CN] YONEX time note of UCC status change        */
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
/* Date         Author   Ver   Purposes                                 */
/* 13-Dec-2022  ChongCS  1.0   DevOps Combine Script                    */
/************************************************************************/
CREATE   PROC [dbo].[ispPKUCCChk02]
           @c_PickSlipNo         NVARCHAR(10)
         , @c_UCCNo              NVARCHAR(20)
         , @b_Success            INT            OUTPUT   --0: Error 1: No Error 2: Warning
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

         , @c_Loadkey               NVARCHAR(10) = ''
         , @c_Orderkey              NVARCHAR(10) = ''
         , @c_UserDefine02          NVARCHAR(50) = ''
         , @c_Storerkey             NVARCHAR(15) = ''
         , @c_SUSR4                 NVARCHAR(20) = ''
         , @c_SKU                   NVARCHAR(20) = ''
         , @c_uccstatus             NVARCHAR(1) = ''

   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_Errmsg        = ''

   SELECT TOP 1
               @c_Orderkey= ISNULL(PH.Orderkey,'')
            ,  @c_Loadkey = ISNULL(PH.ExternOrderkey,'')
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickheaderKey = @c_PickSlipNo

   IF @c_Orderkey <> ''
   BEGIN
      SELECT TOP 1 @c_UserDefine02 = OH.UserDefine02
                 , @c_Storerkey    = OH.StorerKey
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END
   ELSE IF @c_Loadkey <> ''
   BEGIN
      SELECT @c_UserDefine02 = CASE WHEN MIN(OH.UserDefine02) = MAX(OH.UserDefine02) THEN MIN(OH.UserDefine02) ELSE '' END
           , @c_Storerkey    = MAX(OH.StorerKey)
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
   END

   SELECT @c_uccstatus = UCC.status
   FROM UCC (NOLOCK)
   JOIN SKU (NOLOCK) ON SKU.StorerKey = UCC.Storerkey AND SKU.SKU = UCC.SKU
   WHERE UCC.UCCNo = @c_UCCNo
   AND UCC.Storerkey = @c_Storerkey
   
   IF ISNUMERIC(@c_uccstatus) = 1 AND CAST(@c_uccstatus AS INT) >= 6
   BEGIN
         SET @n_continue = 3  
         SET @n_err = 65536   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': cannot scan UCC as UCC status more than 6 . (ispPKUCCChk02)'    
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPKUCCChk02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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