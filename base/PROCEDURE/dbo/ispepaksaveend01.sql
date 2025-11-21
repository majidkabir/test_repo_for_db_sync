SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispEPAKSaveEnd01                                        */
/* Creation Date: 2020-10-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-14948 - PH_Benby_Ecom_Packing_Filter                    */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-OCT-2020 Wan      1.0   Created                                   */
/* 12-APR-2021 Wan01    1.1   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/
CREATE PROC [dbo].[ispEPAKSaveEnd01]
           @c_PickSlipNo   NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)
         , @b_Success      INT            = 1   OUTPUT
         , @n_Err          INT            = 0   OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  = ''  OUTPUT
         , @c_WarningMsg   NVARCHAR(255)  = ''  OUTPUT -- Warning Message: Block from PackConfirm with warning message, Allow to close ECOM Packing with warning message
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         
         , @n_ExistCnt        INT   = 0                                           --Wan01

   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   --(Wan01) 
   ; WITH PIF ( PickSlipNo, TrackingNo ) AS 
   ( SELECT PI.PickSlipNo
           ,TrackingNo = CASE WHEN ISNULL(PI.TrackingNo,'') <> '' THEN RTRIM(PI.TrackingNo) ELSE ISNULL(RTRIM(PI.RefNo),'') END  --(Wan01)
     FROM dbo.PackInfo AS PI WITH (NOLOCK)
     WHERE PI.PickSlipNo = @c_PickSlipNo
   )
   
   SELECT TOP 1 @n_ExistCnt = 1                                                  --Wan01                                                   
   FROM PIF WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON PIF.TrackingNo = OH.UserDefine04              --Wan01
   --WHERE PIF.PickSlipNo = @c_PickSlipNo                                        --Wan01
   WHERE PIF.TrackingNo <> ''                                                    --Wan01
   AND   OH.Storerkey = @c_Storerkey
   AND   OH.TrackingNo <> ''
   AND   OH.[Status] = '5'
               
   IF @n_ExistCnt = 1                                                            --Wan01
   BEGIN
      SET @c_WarningMsg = 'Duplicate Tracking No # Found.'  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispEPAKSaveEnd01'
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
END -- procedure

GO