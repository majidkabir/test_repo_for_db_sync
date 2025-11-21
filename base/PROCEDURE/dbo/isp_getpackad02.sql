SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetPackAD02                                         */
/* Creation Date: 03-Aug-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20384 - CN Converse Normal Pack Extend Validation       */
/*        :                                                             */
/* Called By: Normal packing - Packdetail ItemChanged                   */
/*          : of_isAntiDiversion()                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver   Purposes                                 */
/* 03-Aug-2022  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackAD02]
           @c_PickSlipNo         NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @n_AntiDiversion      INT = 0        OUTPUT
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

         , @c_Loadkey               NVARCHAR(10) = ''
         , @c_Orderkey              NVARCHAR(10) = ''
         , @c_UserDefine02          NVARCHAR(50) = ''

   SET @n_AntiDiversion = 0
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
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END
   ELSE IF @c_Loadkey <> ''
   BEGIN
      SELECT @c_UserDefine02 = CASE WHEN MIN(OH.UserDefine02) = MAX(OH.UserDefine02) THEN MIN(OH.UserDefine02) ELSE '' END
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
   END

   IF @c_UserDefine02 <> ''
   BEGIN
      SET @n_AntiDiversion = 0
   END
   ELSE
   BEGIN
      SET @n_AntiDiversion = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackAD02'
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