SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_prepackvalidate01                                   */
/* Creation Date: 26-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4051 - [TW] Packing Module Validation                   */
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
/************************************************************************/
CREATE PROC [dbo].[isp_prepackvalidate01]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_SourceType      NVARCHAR(30)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_Cnt             INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_Loadkey         NVARCHAR(10)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @c_SourceType NOT IN ('SCANNPACK', 'PACKING')
   BEGIN 
      GOTO QUIT_SP
   END
  
   SET @c_Orderkey = ''
   SELECT @c_Orderkey = ISNULL(RTRIM(PH.Orderkey),'')
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   SET @n_Cnt = 0
   SET @c_ErrMsg = ''
   IF @c_Orderkey = ''
   BEGIN
      SET @c_Loadkey = ''
      SELECT TOP 1 @c_Loadkey = CASE WHEN ISNULL(RTRIM(PH.ExternOrderkey),'') = ''
                                     THEN ISNULL(RTRIM(PH.Loadkey),'')
                                     ELSE ISNULL(RTRIM(PH.ExternOrderkey),'')
                                     END
                  ,@n_Cnt = 1
      FROM PICKHEADER PH WITH (NOLOCK)
      WHERE PH.PickHeaderKey = @c_PickSlipNo

      SELECT TOP 1 @c_ErrMsg = ISNULL(RTRIM(CL.Description),'')
                  ,@n_Cnt = 1
      FROM LOADPLAN LP WITH (NOLOCK)
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
      JOIN ORDERS   OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
      JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'NONEPACKSO')
                                     AND(CL.Code = OH.SOStatus)
                                     AND(CL.Storerkey = OH.Storerkey)
      WHERE LP.Loadkey = @c_Loadkey
      ORDER BY ISNULL(RTRIM(CL.Description),'')
   END
   ELSE
   BEGIN
      SELECT @c_ErrMsg = ISNULL(RTRIM(CL.Description),'')
            ,@n_Cnt = 1
      FROM ORDERS   OH WITH (NOLOCK)
      JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'NONEPACKSO')
                                     AND(CL.Code = OH.SOStatus)
                                     AND(CL.Storerkey = OH.Storerkey)
      WHERE OH.Orderkey = @c_Orderkey
   END

   IF @n_Cnt = 1
   BEGIN
      SET @n_Continue=3 
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ' + @c_ErrMsg
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_prepackvalidate01'
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