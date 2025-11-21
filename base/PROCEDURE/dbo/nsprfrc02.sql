SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFRC02                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspRFRC02]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_storerkey        NVARCHAR(15)
,              @c_sku              NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_loc              NVARCHAR(10)
,              @c_id               NVARCHAR(18)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_prokey           NVARCHAR(10)
,              @c_pokey            NVARCHAR(10)
,              @c_lottable01       NVARCHAR(18)
,              @c_lottable02       NVARCHAR(18)
,              @c_lottable03       NVARCHAR(18)
,              @c_field1           NVARCHAR(30)
,              @c_field2           NVARCHAR(30)
,              @c_field3           NVARCHAR(30)
,              @c_field4           NVARCHAR(30)
,              @c_field5           NVARCHAR(30)
,              @c_field6           NVARCHAR(30)
,              @c_field7           NVARCHAR(30)
,              @c_field8           NVARCHAR(30)
,              @c_field9           NVARCHAR(30)
,              @c_field10          NVARCHAR(30)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE  @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   /* #INCLUDE <SPRFRC01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_continue = @n_continue
   END
   IF @n_continue=3
   BEGIN
      IF @c_retrec="01"
      BEGIN
         SELECT @c_retrec="09"
      END
   END
ELSE
   BEGIN
      SELECT @c_retrec="01"
   END
   /* #INCLUDE <SPRFRC02_2.SQL> */
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)
   SELECT dbo.fnc_RTrim(@c_outstring)
   IF @n_continue=3  -- Error Occured - Process And Return
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFRC01"
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