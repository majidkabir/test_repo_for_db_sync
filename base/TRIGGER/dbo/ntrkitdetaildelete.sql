SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrKitDetailDelete                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Delete Kit Detail Record                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 14-June-2006 Vicky         Modify Update OpenQty to cater ManyToMany */
/*                            Kitting                                   */ 
/* 28-Apr-2011  KHLim01       Insert Delete log                         */
/* 14-Jul-2011  KHLim02       GetRight for Delete log                   */
/* 22-May-2012  TLTING01      Data integrity - insert dellog 4 status   */
/*                             < '9'                                    */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrKitDetailDelete]
 ON [dbo].[KITDETAIL]
 FOR DELETE
 AS
 BEGIN
 IF @@ROWCOUNT = 0
 BEGIN
 RETURN
 END 
 SET NOCOUNT ON
 SET ANSI_NULLS OFF  
 SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_debug int
 SELECT @b_debug = 0
 IF @b_debug = 1
 BEGIN
 SELECT "DELETED ", * FROM DELETED
 END
 ELSE IF @b_debug = 2
 BEGIN
 DECLARE @profiler NVARCHAR(80)
 SELECT @profiler = "PROFILER,701,00,0,ntrKitDetailDelete Trigger                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 DECLARE @b_Success       int,  -- Populated by calls to stored procedures - was the proc successful?
 @n_err              int,       -- Error number returned by stored procedure or this trigger
 @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
 @n_continue         int,       -- continuation flag: 1 = Continue, 2 = failed but continue processsing, 3 = failed do not continue processing, 4 = successful but skip further processing
 @n_starttcnt        int,       -- Holds the current transaction count
 @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
,@c_authority        NVARCHAR(1)  -- KHLim02
 SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
      /* #INCLUDE <TRTDD1.SQL> */     

 IF (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 SELECT @n_continue = 4
 END
 
   -- TLTING01
    -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrKITDETAILDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.KITDETAIL_DELLOG ( KITKey, KITLineNumber, Type )
         SELECT DELETED.KITKey, DELETED.KITLineNumber, DELETED.Type 
         FROM DELETED
         JOIN KIT (NOLOCK) ON KIT.KITKey = DELETED.KITKey
         WHERE KIT.STATUS < '9'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table KITDETAIL Failed. (ntrKITDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END

         IF @n_cnt = 0
         BEGIN
            INSERT INTO dbo.KITDETAIL_DELLOG ( KITKey, KITLineNumber, Type )
            SELECT DELETED.KITKey, DELETED.KITLineNumber, DELETED.Type 
            FROM DELETED
            WHERE DELETED.STATUS < '9'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table KITDETAIL Failed. (ntrKITDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
   END
   -- End (KHLim01) 

 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS ( SELECT *
 FROM DELETED
 WHERE Status = "9" )
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 70101
 SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Posted rows may not be deleted. (ntrKitDetailDelete)"
 END
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,02,0,KIT Update                                   ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 DECLARE @n_deletedcount int
 SELECT @n_deletedcount = (select count(*) FROM deleted)
 IF @n_deletedcount = 1
 BEGIN
    UPDATE KIT
    SET  KIT.OpenQty = KIT.OpenQty - DELETED.ExpectedQty
    FROM KIT, DELETED
    WHERE  KIT.KitKey = DELETED.KitKey
    AND  DELETED.TYPE = "F"  

    -- Added By Vicky on 14-June-2006 (Start)
    UPDATE KIT
    SET  KIT.OpenQty = KIT.OpenQty - DELETED.ExpectedQty
    FROM KIT, DELETED
    WHERE  KIT.KitKey = DELETED.KitKey
    AND  DELETED.TYPE = "T"  
    -- Added By Vicky on 14-June-2006 (End)
 END
 ELSE
 BEGIN
    UPDATE KIT SET KIT.OpenQty = (KIT.Openqty - (Select Sum(DELETED.ExpectedQty) From DELETED
          Where DELETED.KitKey = KIT.KitKey AND DELETED.TYPE = "F"))
    FROM KIT,DELETED
    WHERE KIT.KitKey IN (SELECT Distinct KitKey From DELETED)
    AND KIT.KitKey = DELETED.KitKey
    AND DELETED.TYPE = "F"

    -- Added By Vicky on 14-June-2006 (Start)
    UPDATE KIT SET KIT.OpenQty = (KIT.Openqty - (Select Sum(DELETED.ExpectedQty) From DELETED
          Where DELETED.KitKey = KIT.KitKey AND DELETED.TYPE = "T"))
    FROM KIT,DELETED
    WHERE KIT.KitKey IN (SELECT Distinct KitKey From DELETED)
    AND KIT.KitKey = DELETED.KitKey
    AND DELETED.TYPE = "T"
    -- Added By Vicky on 14-June-2006 (End)
 END
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table KIT. (ntrKitDetailDelete)" + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,02,9,KIT Update                                   ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 END
 END

      /* #INCLUDE <TRTDD2.SQL> */
 IF @n_continue = 3  -- Error Occured - Process And Return
 BEGIN
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > = @n_starttcnt
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
 EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrKitDetailDelete"
 RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,00,9,ntrKitDetailDelete Trigger                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 ELSE
 BEGIN
 WHILE @@TRANCOUNT > @n_starttcnt
 BEGIN
 COMMIT TRAN
 END
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,00,9,ntrKitDetailDelete Trigger         ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 END



GO