SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrBrokerageAdd                                             */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS#15134                                                  */
/* Version: 5.5                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrBrokerageAdd] --First Time Deployment
--ALTER TRIGGER [dbo].[ntrBrokerageAdd]
ON  [dbo].[Brokerage]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @b_Success       int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err           int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2          int       -- For Additional Error Detection
   ,         @c_errmsg        NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue      int
   ,         @n_starttcnt     int       -- Holds the current transaction count
   ,         @c_preprocess    NVARCHAR(250) -- preprocess
   ,         @c_pstprocess    NVARCHAR(250) -- post process
   ,         @n_cnt           int
   ,         @c_BrokerageKey  int
   ,         @c_Storerkey     NVARCHAR(15)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   
   ----Not suppose to check
   --IF UPDATE(TrafficCop)
   --BEGIN
   --   SELECT @n_continue = 4
   --END

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN

      SELECT @c_BrokerageKey = BrokerageKey 
           , @c_Storerkey    = Storerkey
      FROM   INSERTED
      WHERE doctype = 'PO'

      IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) 
                  WHERE  StorerKey = @c_Storerkey
                  AND    ConfigKey = 'BRKADDLOG' 
                  AND    sValue    = '1' )
      BEGIN
         EXEC ispGenTransmitLog3 'BRKADDLOG', @c_BrokerageKey, '', @c_Storerkey, '' 
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.
            SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err) + ': Unable To Obtain LogKey. (ntrBrokerageAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- If exists kitlog
   END


   /* #INCLUDE <TRLU2.SQL> */
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
      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrBrokerageAdd'

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
END

GO