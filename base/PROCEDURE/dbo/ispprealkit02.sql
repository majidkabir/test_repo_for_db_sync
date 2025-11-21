SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPREALKIT02                                         */
/* Creation Date: 15-Feb-2023                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21261 - [CN] RITUALS_Kit_Allocation NEW                    */
/*                                                                         */
/* Called By: isp_PreKitAllocation_Wrapper: PreKitAllocation_SP            */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 15-Dec-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[ispPREALKIT02]
(
   @c_Kitkey  NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug     INT
         , @n_Continue  INT
         , @n_StartTCnt INT

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = 0
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   IF EXISTS (  SELECT 1
                FROM KITDETAIL KD (NOLOCK)
                JOIN SKU S (NOLOCK) ON S.StorerKey = KD.StorerKey AND S.SKU = KD.SKU
                WHERE KD.KITKey = @c_Kitkey
                AND KD.Type = 'F'
                AND S.IVAS <> 'PASSED')
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 63070
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err)
                         + ': Not allowed to allocate due to SKU.IVAS <> PASSED. (ispPREALKIT02)'
   END

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPREALKIT02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO