SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRKIT05                                            */
/* Creation Date: 05-Feb-2023                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21587 - [TW] EA_Exceed Kitting - Copy ExternLineNo_New     */
/*                                                                         */
/* Called By: ispPreFinalizeKitWrapper                                     */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Ver  Author   Purposes                                      */
/* 05-Feb-2023 1.0  WLChooi  DevOps Combine Script                         */
/***************************************************************************/
CREATE   PROC [dbo].[ispPRKIT05]
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

   DECLARE @n_Continue    INT
         , @n_StartTCount INT
         , @c_ExternLineNo     NVARCHAR(50)

   SELECT @b_Success = 1
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @n_Continue = 1
        , @n_StartTCount = @@TRANCOUNT

   SELECT @c_ExternLineNo = KITDETAIL.ExternLineNo
   FROM KITDETAIL WITH (NOLOCK)
   WHERE KITDETAIL.KITKey = @c_Kitkey
   AND KITDETAIL.[Type] = 'T'
   AND ISNULL(KITDETAIL.ExternLineNo,'') <> ''
   ORDER BY CAST(KITDETAIL.KITLineNumber AS INT) DESC

   UPDATE KITDETAIL WITH (ROWLOCK)
   SET KITDETAIL.ExternLineNo = @c_ExternLineNo
   WHERE KITDETAIL.KITKey = @c_Kitkey AND KITDETAIL.[Type] = 'T'
   AND ISNULL(KITDETAIL.ExternLineNo,'') = ''

   SET @n_Err = @@ERROR

   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
      SET @n_Err = 83010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update KITDETAIL Failed. (ispPRKIT05)' + ' ( '
                      + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
   END

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRKIT05'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END

      RETURN
   END
END

GO