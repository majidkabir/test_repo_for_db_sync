SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EPACKPrePrintCheck01                                */
/* Creation Date: 13-JUL-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2306 - CN-Nike SDC WMS ECOM Packing CR                  */
/*                                                                      */
/* Called By: isp_EPACKPrePrintCheck_Wrapper                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EPACKPrePrintCheck01]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_CartonNoStart   NVARCHAR(10)
         , @c_CartonNoEnd     NVARCHAR(10)
         , @c_ReportType      NVARCHAR(30)
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
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 

         , @n_RecCnt          INT
         , @n_QtyPacked       INT

         , @c_Orderkey        NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   SET @c_Orderkey = ''
   SELECT @c_Orderkey = ISNULL(RTRIM(PH.Orderkey),'')
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo

   IF NOT EXISTS( SELECT 1   
                  FROM ORDERS OH (NOLOCK) 
                  WHERE OH.Orderkey = @c_Orderkey
                  AND OH.Type = 'COD'
                )
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_RecCnt = 0
   SELECT @n_RecCnt = COUNT(DISTINCT PD.LabelNo)
         ,@n_QtyPacked = SUM(PD.Qty)
   FROM PACKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_PickSlipNo

   IF @n_RecCnt = 1
   BEGIN
      IF (  SELECT ISNULL(SUM(OriginalQty),0)
            FROM ORDERDETAIL OD WITH (NOLOCK)
            WHERE OD.Orderkey = @c_Orderkey 
         ) = @n_QtyPacked
      BEGIN
         GOTO QUIT_SP
      END             
   END

   IF EXISTS( SELECT 1   
              FROM ORDERS OH (NOLOCK) 
              WHERE OH.Orderkey = @c_Orderkey
              AND OH.SOStatus = '5'
            )
   BEGIN
      --SET @n_Continue = 2     -- Not To Print w/o errmsg
      GOTO QUIT_SP
   END

   SET @n_Continue = 3
   SET @c_ErrMsg =  'Orderkey: ' + RTRIM(@c_Orderkey) + ' is Requesting Tracking #. Print Later. (isp_EPACKPrePrintCheck01)'

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPACKPrePrintCheck01'
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END
END -- procedure

GO