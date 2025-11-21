SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- =============================================
-- Author: WANYT
-- Create date: 20-May-2008
-- Description: Delete Details if Header was deleted
-- =============================================
/************************************************************************/
/* Trigger: ntrRDSStyleDelete                                           */
/* Creation Date: 20-May-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: WANYT                                                    */
/*                                                                      */
/* Purpose: Delete in RDSStyle table.                                   */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Exceed                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 6Jan2008     TLTING    1.1   @@TRANCOUNT >= @n_starttcnt to rollback */
/*                              (tlting01)                              */
/*                                                                      */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrRDSStyleDelete]
   ON  [dbo].[RDSStyle]
   AFTER DELETE
AS 
BEGIN
   DECLARE @n_StartTCnt int, 
           @n_Continue  int, 
           @b_success   int,
           @n_Err       int, 
           @c_ErrMsg    NVARCHAR(215) 

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1  

   IF EXISTS(SELECT 1 FROM RDSStyleColor WITH (NOLOCK) 
             JOIN DELETED ON (DELETED.Storerkey = RDSStyleColor.Storerkey
                          AND DELETED.Style = RDSStyleColor.Style))
   BEGIN
      DELETE RDSStyleColor 
      FROM   RDSStyleColor
      JOIN DELETED ON  (DELETED.Storerkey = RDSStyleColor.Storerkey
                    AND DELETED.Style = RDSStyleColor.Style)
      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Delete RDSStyleColor Failed!'
         GOTO QUIT
      END            
   END 

QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      -- Start tlting01
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt     -- tlting01    -- @@TRANCOUNT > @n_starttcnt
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
      -- End tlting01 
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrRDSStyleDelete'
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

END


GO