SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackADByCS01                                     */
/* Creation Date: 2020-06-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13503 - SG - Prestige - Packing [CR]                    */
/*        :                                                             */
/* Called By: Normal packing - Packdetail ItemChanged                   */
/*          : of_getantidiversionbycasecnt                              */
/*          : isp_GetPackADByCaseCnt_Wrapper                            */
/*          : SubSP ispPackADByCS01                                     */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackADByCS01]
           @c_Orderkey           NVARCHAR(10)
         , @n_CartonNo           INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @n_Qty                INT
         , @n_ADLines            INT = 0        OUTPUT  
         , @n_Explode            INT = 0        OUTPUT 
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
           @n_StartTCnt                INT   = @@TRANCOUNT
         , @n_Continue                 INT   = 1

         , @b_ADCSByEA                 BIT   = 0
         , @n_CaseCnt                  FLOAT          = 0.00
         , @c_Packkey                  NVARCHAR(10)   = ''
         , @c_BUSR6                    NVARCHAR(30)   = ''

         , @n_PackedAD                 INT            = 0
         , @c_CartonNo                 NVARCHAR(5 )   = 0

   SET @b_Success       = 1      
   SET @n_Err           = 0
   SET @c_Errmsg        = ''
  
   SELECT @c_Packkey = Packkey
         ,@c_BUSR6 = ISNULL(RTRIM(SKU.BUSR6),'')
   FROM SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = @c_Storerkey
   AND   SKU.Sku = @c_Sku

   SELECT @n_CaseCnt = ISNULL(PACK.CaseCnt,0.00)
   FROM PACK WITH (NOLOCK)
   WHERE PACK.Packkey = @c_Packkey
   
   IF @c_BUSR6 <> ''
   BEGIN
      SELECT @b_ADCSByEA = 1
      FROM CODELKUP CL WITH (NOLOCK) 
      WHERE CL.ListName = 'PRESTGADEA'
      AND CL.Code       = @c_BUSR6

      SET @c_CartonNo = CONVERT(NVARCHAR(5), @n_CartonNo)
    
      SELECT @n_PackedAD = COUNT(1)
      FROM SERIALNO SN WITH (NOLOCK)
      WHERE SN.Orderkey  = @c_Orderkey
      AND   SN.OrderLineNumber = @c_CartonNo
      AND   SN.StorerKey = @c_Storerkey
      AND   SN.Sku       = @c_Sku
   END

   IF @b_ADCSByEA = 1
   BEGIN
      SET @n_ADLines = @n_Qty - @n_PackedAD
      SET @n_Explode = 0
   END
   ELSE
   BEGIN
      SET @n_Explode = 0
      IF @n_Qty >= @n_CaseCnt
      BEGIN
         SET @n_Explode = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackADByCS01'
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