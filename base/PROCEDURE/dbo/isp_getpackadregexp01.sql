SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackADRegExp01                                   */
/* Creation Date: 2020-06-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13503 - SG - Prestige - Packing [CR]                    */
/*        :                                                             */
/* Called By: Normal packing - w_popup_antidiversion                    */
/*          : of_getADRegExp                                            */
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
CREATE PROC [dbo].[isp_GetPackADRegExp01]
           @c_Orderkey           NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_RegExp             NVARCHAR(100)=''OUTPUT 
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

   SET @c_RegExp        = ''    
   SET @b_Success       = 1      
   SET @n_Err           = 0
   SET @c_Errmsg        = ''

   IF EXISTS ( SELECT 1 FROM SKU S (NOLOCK) 
               WHERE S.Storerkey = @c_Storerkey
               AND S.Sku = @c_Sku
               AND S.SUSR4 = 'AD'
               AND S.BUSR6 = 'MOROCCANOIL'
               )
   BEGIN 
      SET @c_RegExp = '^([A-Za-z]){3}(([A-Za-z0-9]){1,17})$'  --2020-07-21
   END
   
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @c_RegExp  = ''
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackADRegExp01'
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