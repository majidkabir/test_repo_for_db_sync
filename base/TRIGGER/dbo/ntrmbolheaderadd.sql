SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/  
/* Trigger:  ntrMbolHeaderAdd                                              */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:  Trigger point upon any insert MBOL                            */  
/*                                                                         */  
/* Input Parameters:                                                       */  
/*                                                                         */  
/* Output Parameters:  None                                                */  
/*                                                                         */  
/* Return Status:  None                                                    */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: When records Inserted                                        */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author Ver.  Purposes                                      */  
/* 17-Mar-2009  TLTING       Change user_name() to SUSER_SNAME()           */
/***************************************************************************/  

CREATE TRIGGER [dbo].[ntrMbolHeaderAdd]
 ON  [dbo].[MBOL]
 FOR INSERT
 AS
 BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF
  	
 DECLARE
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2 int              -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue int                 
 ,         @n_starttcnt int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int                  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBOA1.SQL> */     
 -- Added By SHONG 30-Apr-2003
 -- To allow records insert from Archive DB
 IF @n_continue=1 or @n_continue=2
 BEGIN
    IF EXISTS (SELECT * FROM INSERTED WHERE ArchiveCop = "9")
    BEGIN
      SELECT @n_continue = 4
    END
 END

 IF @n_continue=1 or @n_continue=2
 BEGIN
    IF EXISTS (SELECT * FROM INSERTED WHERE Status = "9")
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=72602
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad MBOL.Status. (nspMbolHeaderAdd)"
    END
 END
 -- Commented BY SHONG on 12-Jun-2003
 -- Double work, this default value already cater by Table Default Constrains
 /*
 IF @n_continue=1 or @n_continue=2
 BEGIN
    UPDATE MBOL
    SET TrafficCop = NULL,
        AddDate = GETDATE(),
        AddWho = SUSER_SNAME(),
        EditDate = GETDATE(),
        EditWho = SUSER_SNAME()
    FROM MBOL, INSERTED
    WHERE MBOL.MBOLKey = INSERTED.MBOLKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table MBOL. (nspMbolHeaderAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 */
 /* #INCLUDE <TRMBOHA2.SQL> */
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrMbolHeaderAdd"
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