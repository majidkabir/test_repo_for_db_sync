SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ntrSHIFTUpdate                                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: KHLim                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Oct-2013  TLTING    1.1   Review Editdate column update           */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrSHIFTUpdate] 
ON  [dbo].[SHIFT] 
FOR UPDATE 
AS 
IF @@ROWCOUNT = 0 
BEGIN 
   RETURN 
END 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

DECLARE @b_Success     int       -- Populated by calls to stored procedures - was the proc successful?
      , @n_err         int       -- Error number returned by stored procedure or this trigger
      , @n_err2        int       -- For Additional Error Detection
      , @c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger
      , @n_continue    int
      , @n_starttcnt   int       -- Holds the current transaction count
      , @c_preprocess  NVARCHAR(250) -- preprocess
      , @c_pstprocess  NVARCHAR(250) -- post process
      , @n_cnt         int
      , @b_debug       int
      


SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_debug = 0

IF ( @n_continue = 1 OR @n_continue= 2 ) AND NOT UPDATE(EditDate)
BEGIN
     UPDATE SHIFT
        SET EditWho = SUSER_SNAME(),
             EditDate = GetDate()
     FROM SHIFT, INSERTED
    WHERE SHIFT.Sequence = INSERTED.Sequence
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
         BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 72807 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                       + ': Unable to Update SHIFT table (ntrSHIFTUpdate)' 
                       + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
   END
END

      /* #INCLUDE <TRMBOHU2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrSHIFTUpdate' 
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END


GO