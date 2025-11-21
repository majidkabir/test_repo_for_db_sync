SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRKIT06                                            */
/* Creation Date: 17-Feb-2023                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21773 - [CN] RITUALS_Kit_Finalize NEW                      */
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
/* 17-Feb-2023 1.0  WLChooi  DevOps Combine Script                         */
/***************************************************************************/
CREATE   PROC [dbo].[ispPRKIT06]
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

   DECLARE @n_Continue     INT
         , @n_StartTCount  INT
         , @c_Lottable03   NVARCHAR(50)

   SELECT @b_Success = 1
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @n_Continue = 1
        , @n_StartTCount = @@TRANCOUNT

   --1 Kit only have 1 Final Product
   SELECT TOP 1 @c_Lottable03 = ISNULL(CL.Code,'')
   FROM KITDETAIL KT (NOLOCK)
   JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.StorerKey = KT.StorerKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'RITST' AND CL.Storerkey = KT.StorerKey
                                 AND CL.Long = S.IVAS
   WHERE KT.KITKey = @c_Kitkey AND KT.[Type] = 'T'

   IF ISNULL(@c_Lottable03,'') <> ''
   BEGIN
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET LOTTABLE03 = @c_Lottable03
      WHERE KITKey = @c_Kitkey
      AND [Type] = 'T'

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
         SET @n_Err = 83010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update KITDETAIL Failed. (ispPRKIT06)' + ' ( '
                         + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
      END
   END

   --From ispPRKIT04
   UPDATE KITDETAIL WITH (ROWLOCK)
   SET KITDETAIL.Lottable08 = KIT.CustomerRefNo
   FROM KITDETAIL
   JOIN KIT (NOLOCK) ON KITDETAIL.Kitkey = KIT.Kitkey   
   WHERE KIT.Kitkey = @c_Kitkey
   AND KITDETAIL.Type = 'T'
 
   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83015  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Failed. (ispPRKIT06)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRKIT06'
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