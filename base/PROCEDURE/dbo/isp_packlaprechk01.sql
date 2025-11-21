SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackLAPreChk01                                      */
/* Creation Date: 2021-11-23                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-18322 - [CN]DYSON_Ecompacking_X708_Function_CR          */
/*        :                                                             */
/* Called By: isp_PackLAPreCheck_Wrapper                                */
/*          : isp_PackLAPreChkXX                                        */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-11-23  Wan      1.0   Created.                                  */
/* 2021-11-23  Wan      1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_PackLAPreChk01]
     @c_PickSlipNo   NVARCHAR(10)
   , @c_Storerkey    NVARCHAR(15) 
   , @c_Sku          NVARCHAR(20)  
   , @c_TaskBatchNo  NVARCHAR(10)   = ''               
   , @b_Success      INT            = 1   OUTPUT
   , @n_Err          INT            = 0   OUTPUT
   , @c_ErrMsg       NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT =  @@TRANCOUNT
         , @n_Continue        INT = 1
         
         , @c_Facility        NVARCHAR(5)  = ''
         , @c_PackByLottable  NVARCHAR(30) = ''

   SET @b_Success  = 0
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_PackByLottable = fgr.Authority FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PackByLottable') AS fgr
   
   IF @c_PackByLottable IN ('0', '1') --1:Normal Packing, 2:Ecom Packing 3:Both Normal & Ecom Packing
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_TaskBatchNo = ''     --Not From Ecom Packing
   BEGIN
      GOTO QUIT_SP
   END
 
   IF EXISTS (SELECT 1 FROM dbo.SKU AS s WITH (NOLOCK) WHERE s.StorerKey = @c_Storerkey AND s.Sku = @c_Sku
              AND s.SKUGROUP = 'X708' AND s.SerialNoCapture = '0'
             )
   BEGIN 
      SET @b_Success = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackLAPreChk01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO