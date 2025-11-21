SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNValidateToLoc                               */
/* Creation Date: 2020-09-14                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
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
CREATE PROC [dbo].[isp_RFID_ASNValidateToLoc]
           @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15) = '' 
         , @c_ToLoc              NVARCHAR(100)= '' 
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1

         , @c_CrossWH         NVARCHAR(30) = ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF NOT EXISTS( SELECT 1
                  FROM   LOC WITH (NOLOCK)
                  WHERE  LOC.Loc = @c_toloc
               )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 89010
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid Location: ' + @c_Toloc                           
                      + ' not found. (isp_RFID_ASNValidateToLoc)'
      GOTO QUIT_SP
   END
   
   SELECT @c_CrossWH = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CrossWH')

   IF @c_CrossWH <> '1'
   BEGIN
      IF NOT EXISTS( SELECT 1
                     FROM   LOC WITH (NOLOCK)
                     WHERE  LOC.Facility = @c_Facility
                     AND	 LOC.Loc = @c_toloc
                  )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 89020
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Location Doesn''t Exists in Facility: ' + @c_Facility                           + ' not found. (isp_RFID_ASNValidateToLoc)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNValidateToLoc'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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