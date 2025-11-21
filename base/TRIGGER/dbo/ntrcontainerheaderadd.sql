SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger:  ntrContainerHeaderAdd                                         */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Trigger point upon any Add  on the Container                  */
/*                                                                         */
/* Return Status:  None                                                    */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: When records added                                           */
/*                                                                         */
/* PVCS Version: 1.5                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 17-Mar-2009  TLTING          Change user_name() to SUSER_SNAME()        */
/* 31-Mar-2020  kocy      1.1   Skip when data move from Archive (kocy01)  */
/* 13-Jan-2021  Shong     1.2   Comment the update for AddWho... Schema    */
/*                              Default already have this. Redundancy      */
/***************************************************************************/

CREATE TRIGGER [dbo].[ntrContainerHeaderAdd]
 ON  [dbo].[CONTAINER]
 FOR INSERT
 AS
 BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF	
 
 DECLARE    @b_Success     int            -- Populated by calls to stored procedures - was the proc successful?
         ,  @n_err         int            -- Error number returned by stored procedure or this trigger
         ,  @n_err2        int            -- For Additional Error Detection
         ,  @c_errmsg      NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
         ,  @n_continue    int                 
         ,  @n_starttcnt   int            -- Holds the current transaction count
         ,  @c_preprocess  NVARCHAR(250)  -- preprocess
         ,  @c_pstprocess  NVARCHAR(250)  -- post process
         ,  @n_cnt int
         
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 /* #INCLUDE <TRCONHA1.SQL> */ 
 
 -- kocy01(s)
 IF @n_continue=1 or @n_continue=2  
 BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = "9")
    BEGIN
       SELECT @n_continue = 4
    END
 END
 --kocy01(e)

 IF @n_continue=1 or @n_continue=2
 BEGIN
   IF EXISTS (SELECT * FROM INSERTED WHERE Status = "9")
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err=67902
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad CONTAINER.Status. (nspContainerHeaderAdd)"
   END
 END

 --IF @n_continue=1 or @n_continue=2
 --BEGIN
 --  UPDATE CONTAINER
 --  SET TrafficCop = NULL,
 --  AddDate = GETDATE(),
 --  AddWho = SUSER_SNAME(),
 --  EditDate = GETDATE(),
 --  EditWho = SUSER_SNAME()
 --  FROM CONTAINER, INSERTED
 --  WHERE CONTAINER.ContainerKey = INSERTED.ContainerKey
   
 --  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 --  IF @n_err <> 0
 --  BEGIN
 --     SELECT @n_continue = 3
 --     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 --     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table CONTAINER. (nspContainerHeaderAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 --  END
 --END

 /* #INCLUDE <TRCONHA2.SQL> */
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

   execute nsp_logerror @n_err, @c_errmsg, "ntrContainerHeaderAdd"
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

END -- End SP

GO