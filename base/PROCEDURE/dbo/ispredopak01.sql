SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRedoPAK01                                            */
/* Creation Date: 2020-10-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-14948 - PH_Benby_Ecom_Packing_Filter                    */
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
/* 09-OCT-2020 Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[ispRedoPAK01]
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

         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_Transmitlogkey  NVARCHAR(10) = ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_Storerkey = PH.Storerkey
         ,@c_Orderkey  = PH.Orderkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo

   SELECT @c_Transmitlogkey = TL2.Transmitlogkey
   FROM TRANSMITLOG2 TL2 WITH (NOLOCK)
   WHERE TableName = 'WSPICKCFMLOG'
   AND TL2.Key1 = @c_Orderkey
   AND TL2.Key2 = '5'
   AND TL2.Key3 = @c_Storerkey

   IF @c_Transmitlogkey <> ''               
   BEGIN
      UPDATE TRANSMITLOG2 
         SET Key2 = 'REDO'
            ,Trafficcop = NULL
      WHERE  Transmitlogkey = @c_Transmitlogkey 

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 68010
         SET @c_Errmsg   = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update TRANSMITLOG2 Fail. (ispRedoPAK01)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRedoPAK01'
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