SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRedoPAK02                                            */
/* Creation Date: 2021-05-20                                            */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17004 - [CN] Taylormade_Ecom_Packing_SerialnoCapture_CR */
/*        :                                                             */
/* Called By: isp_PreRedoPack_Wrapper                                   */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-05-20  WLChooi  1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[ispRedoPAK02]
           @c_PickSlipNo   NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)
         , @b_Success      INT            = 1   OUTPUT
         , @n_Err          INT            = 0   OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         , @c_SerialNoKey     NVARCHAR(10) = ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   DECLARE CUR_SN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SerialNoKey
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PackSerialNo PSN (NOLOCK) ON PSN.PickSlipNo = PD.PickSlipNo AND PSN.LabelNo = PD.LabelNo 
                                 AND PSN.LabelLine = PD.LabelLine AND PSN.SKU = PD.SKU
                                 AND PSN.CartonNo = PD.CartonNo AND PSN.StorerKey = PD.StorerKey
   JOIN SerialNo SNO WITH (NOLOCK) ON (PSN.StorerKey = SNO.StorerKey AND PSN.SKU = SNO.SKU AND PSN.SerialNo = SNO.SerialNo)
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU
   WHERE PD.PickSlipNo = @c_PickSlipNo AND S.SerialNoCapture = '3'

   OPEN CUR_SN 

   FETCH NEXT FROM CUR_SN INTO @c_SerialNoKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM SerialNo
      WHERE SerialNoKey = @c_SerialNoKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 68010
         SET @c_Errmsg   = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Delete SerialNo Fail. (ispRedoPAK02)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM CUR_SN INTO @c_SerialNoKey
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_SN') IN (0 , 1)
   BEGIN
      CLOSE CUR_SN
      DEALLOCATE CUR_SN   
   END
  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRedoPAK02'
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