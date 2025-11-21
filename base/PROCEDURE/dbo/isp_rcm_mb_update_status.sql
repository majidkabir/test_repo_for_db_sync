SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_MB_Update_Status                           */
/* Creation Date: 19-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21591 - [CN] Pearson Dynamic RCM for Update the status  */
/*                      in SCE                                          */
/*                                                                      */
/* Called By: MBOL Dynamic RCM configure at listname 'RCMConfig'        */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Jan-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_MB_Update_Status]
   @c_Mbolkey  NVARCHAR(10),
   @b_success  INT           OUTPUT,
   @n_err      INT           OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_cnt       INT,
           @n_starttcnt INT

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_err = 0

   IF EXISTS (SELECT 1
              FROM MBOL (NOLOCK)
              WHERE MbolKey = @c_Mbolkey
              AND [Status] >= '5')
   BEGIN
      GOTO QUIT_SP
   END
   ELSE
   BEGIN
      UPDATE dbo.MBOL
      SET [Status] = '5'
      WHERE MbolKey = @c_Mbolkey

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63330
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update MBOL Table Failed. (isp_RCM_MB_Update_Status)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' 
                          + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END

QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_Update_Status'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC

GO