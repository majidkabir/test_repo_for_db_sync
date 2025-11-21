SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspShipDropID                                      */
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

CREATE PROC    [dbo].[nspShipDropID]
@c_dropid       NVARCHAR(18)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int               -- Debug On Or Off
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0, @b_debug = 0
   DECLARE @c_childid NVARCHAR(18), @c_caseid NVARCHAR(10)
   SELECT @c_childid = "", @c_caseid = ""
   /* #INCLUDE <SPSDI1.SQL> */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_dropid)) IS NULL
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 85400
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Parameters Passed (nspShipDropID)"
      END
   END -- @n_continue =1 or @n_continue = 2
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_caseid = @c_dropid -- So that we only take the first 10 characters of the ID comming in.
      IF EXISTS(SELECT caseid FROM PICKDETAIL WHERE CASEID = @c_caseid
      AND STATUS < "9")
      BEGIN
         BEGIN TRANSACTION tran_updatepickdetail
            UPDATE pickdetail set status = "9" WHERE CASEID = @c_caseid
            AND STATUS < "9"
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 85410   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of PickDetail Failed (nspShipDropID)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
            IF @n_continue = 3
            BEGIN
               ROLLBACK TRANSACTION tran_updatepickdetail
            END
         ELSE
            BEGIN
               COMMIT TRANSACTION tran_updatepickdetail
               IF @b_debug = 1
               BEGIN
                  select "caseid transaction committed for caseid"
               END
               SELECT @n_continue = 4 -- Don't need to do anything else
            END
         END
      ELSE
         BEGIN
            IF EXISTS(SELECT caseid FROM PICKDETAIL WHERE CASEID = @c_caseid
            AND STATUS = "9")
            BEGIN
               IF @b_debug = 1
               BEGIN
                  select "caseid is already shipped, continue set to 4"
               END
               SELECT @n_continue = 4 -- Don't need to do anything else, caseid already shipped.
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @c_childid = ""
         WHILE (1=1) AND (@n_continue = 1 or @n_continue = 2)
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_childid = childid
            FROM DROPIDDETAIL
            WHERE DROPID = @c_dropid AND
            CHILDID > @c_childid
            ORDER BY childid
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            IF @b_debug = 1
            BEGIN
               select "executing sp for childid ",@c_childid
            END
            SELECT @b_success = 0
            EXECUTE nspShipDropID
            @c_dropid     =  @c_childid
            ,              @b_Success    =  @b_success OUTPUT
            ,              @n_err        =  @n_err     OUTPUT
            ,              @c_errmsg     =  @c_errmsg  OUTPUT
            IF @b_success = 0
            BEGIN
               SELECT @n_continue = 3
            END
         ELSE
            BEGIN
               IF EXISTS (SELECT DROPID FROM DROPID WHERE DROPID = @c_dropid and STATUS < "9")
               BEGIN
                  BEGIN TRANSACTION tran_updatedropid
                     UPDATE DROPID SET STATUS = "9" WHERE DROPID = @c_dropid and STATUS < "9"
                     IF @n_continue = 3
                     BEGIN
                        ROLLBACK TRANSACTION tran_updatedropid
                     END
                  ELSE
                     BEGIN
                        COMMIT TRANSACTION tran_updatedropid
                        SELECT @n_continue = 4 -- Don't need to do anything else
                     END
                  END
               END
            END
            SET ROWCOUNT 0
         END
         /* #INCLUDE <SPSDI2.SQL> */
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
            execute nsp_logerror @n_err, @c_errmsg, "nspShipDropID"
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