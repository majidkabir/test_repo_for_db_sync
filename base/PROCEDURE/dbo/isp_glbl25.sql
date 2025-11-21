SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL25                                          */
/* Creation Date: 29-SEP-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15373 - CN PUMA generate label no                       */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    storerconfig: GenLabelNo_SP                       */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 15-Aug-2022 CSCHONG  1.1   Devops Scripts Combine & WMS-20457 (CS01) */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL25] (
         @c_PickSlipNo   NVARCHAR(10)
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT
         , @n_Err                INT
         , @c_ErrMsg             NVARCHAR(255)

   DECLARE @c_Orderkey           NVARCHAR(10)   = ''
         , @c_Consigneekey       NVARCHAR(15)   = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Loadkey            NVARCHAR(10)   = ''

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''

   SELECT @c_Orderkey = P.Orderkey
         ,@c_Storerkey= P.Storerkey
         ,@c_Loadkey  = P.Loadkey
   FROM PACKHEADER P WITH (NOLOCK)
   WHERE P.PickSlipNo = @c_PickSlipNo

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = Orderkey
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END

   SELECT @n_CartonNo = MAX(Cartonno)
    FROM    PackDetail (NOLOCK)
    WHERE  PickSlipNo = @c_Pickslipno

    IF ISNULL(@n_CartonNo,0) = 0
       SET @n_CartonNo = 1
    ELSE
       SET @n_CartonNo = @n_CartonNo + 1

   SELECT @c_Consigneekey = Consigneekey
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   SELECT @c_LabelNo = CASE WHEN @c_Consigneekey BETWEEN '0003920001' AND '0003929999' THEN 'W' ELSE 'O' END + RTRIM(ISNULL(@c_Loadkey,''))
                     + RIGHT('000000000' + LTRIM(RTRIM(CAST(@n_CartonNo AS NCHAR)) ),9)         --CS01

   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL25"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO