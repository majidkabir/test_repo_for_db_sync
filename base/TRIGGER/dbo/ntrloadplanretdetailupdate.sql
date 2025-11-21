SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrLoadPlanRetDetailUpdate                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: LoadPlanRetDetail UPDATE Transaction                        */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records UPDATE                                       */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver   Purposes                               */
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 25 May2012   TLTING02   1.3   DM integrity - add update editdate B4  */
/*                               TrafficCop                             */
/* 28-Oct-2013  TLTING     1.4   Review Editdate column update          */
/************************************************************************/


CREATE TRIGGER ntrLoadPlanRetDetailUpdate
 ON  LoadPlanRetDetail
 FOR UPDATE
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
 
 IF UPDATE(ArchiveCop)
 BEGIN
    SELECT @n_continue = 4 
 END
 
 IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
 BEGIN
    UPDATE LoadPlanRetDetail with (ROWLOCK)
    SET EditDate = GETDATE(),
        EditWho = SUSER_SNAME(),
        Trafficcop = NULL
    FROM LoadPlanRetDetail, INSERTED
    WHERE LoadPlanRetDetail.LoadKey = INSERTED.LoadKey
    AND LoadPlanRetDetail.LoadLineNumber = INSERTED.LoadLineNumber
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90406   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table LoadPlanRetDetail. (ntrLoadPlanRetDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END 
 IF UPDATE(TrafficCop)
 BEGIN
    SELECT @n_continue = 4 
 END

      /* #INCLUDE <TRMBODU1.SQL> */     
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    -- 06/28/2001 CS supposing it is not ok to update loadKey
    IF UPDATE(LoadKey)
    BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 90401
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Not allowed to change loadkey. (ntrLoadPlanRetDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END  
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
      DECLARE   @n_casecnt	int,
                @n_palletcnt	int,
                @n_custcnt	int,
                @n_Receiptcnt	int,
                @n_weight	decimal(15, 4),
                @n_cube	decimal(15, 4),
                @c_insertloadkey NVARCHAR(10),
                @c_deleteloadkey NVARCHAR(10)
      /* 06/28/2001 CS Expected but not instructed to do so */
      /*
      SELECT @c_insertloadkey = INSERTED.LoadKey
      FROM INSERTED
 	SELECT   @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
                     ELSE (ReceiptDETAIL.OpenQty / PACK.Pallet) END)),
               @n_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
                     ELSE (ReceiptDETAIL.OpenQty / PACK.CaseCnt) END))
      FROM ReceiptDETAIL (NOLOCK), LoadPlanRetDetail (NOLOCK), PACK (NOLOCK), SKU (NOLOCK)
      WHERE ReceiptDETAIL.ReceiptKey = LoadPlanRetDetail.ReceiptKey
 	AND LoadPlanRetDetail.LoadKey = @c_insertloadkey
      AND ReceiptDETAIL.Packkey = PACK.Packkey
      AND ReceiptDETAIL.SKU = SKU.SKU
      */
      SELECT @n_weight = 0, @n_cube = 0, @n_Receiptcnt = 0, @n_custcnt = 0
      SELECT @n_weight = SUM(Weight), 
           @n_cube = SUM(Cube)
 	  	--@n_Receiptcnt = COUNT(ReceiptKey)
      FROM LoadPlanRetDetail (NOLOCK)
      WHERE LoadKey = @c_insertloadkey
 	IF @n_casecnt IS NULL SELECT @n_casecnt = 0
    	IF @n_weight IS NULL SELECT @n_weight = 0
 	IF @n_cube IS NULL SELECT @n_cube = 0
      IF @n_Receiptcnt IS NULL SELECT @n_Receiptcnt = 0
      IF @n_palletcnt IS NULL SELECT @n_palletcnt = 0
      IF @n_custcnt IS NULL SELECT @n_custcnt = 0
      UPDATE LoadPlan
      SET Return_Weight = @n_weight,
          Return_Cube = @n_cube,
          EditDate = GETDATE(),        --tlting
          EditWho = SUSER_SNAME()
      WHERE LoadPlan.LoadKey = @c_insertloadkey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
           SELECT @n_continue = 3
           SELECT @n_err=90402
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table LoadPlan. (ntrLoadPlanRetDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
 END
 	
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    IF EXISTS( SELECT INSERTED.ReceiptKey
               FROM   INSERTED, DELETED
               WHERE  INSERTED.LoadKey = DELETED.LoadKey
               AND    INSERTED.LoadLineNumber = DELETED.LoadLineNumber
               AND    INSERTED.ReceiptKey <> DELETED.ReceiptKey )
    BEGIN
       UPDATE Receipt
          SET Receipt.LoadKey = NULL,      
              Trafficcop = NULL,
              EditDate = GETDATE(),    --tlting
              EditWho = SUSER_SNAME()
  FROM Receipt, DELETED
       WHERE Receipt.ReceiptKey = DELETED.ReceiptKey
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @n_err=90402   
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table Receipt. (ntrLoadPlanRetDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          UPDATE Receipt
          SET Receipt.LoadKey = INSERTED.LoadKey,
              Trafficcop = NULL,
              EditDate = GETDATE(), --tlting
              EditWho = SUSER_SNAME()
          FROM Receipt, INSERTED
          WHERE Receipt.ReceiptKey = INSERTED.ReceiptKey
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err=90403  
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table Receipt. (ntrLoadPlanRetDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
       END
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    IF EXISTS( SELECT INSERTED.ReceiptKey
               FROM   INSERTED, DELETED
               WHERE  INSERTED.LoadKey = DELETED.LoadKey
               AND    INSERTED.LoadLineNumber = DELETED.LoadLineNumber
               AND    INSERTED.ReceiptKey <> DELETED.ReceiptKey )
    BEGIN
       UPDATE ReceiptDETAIL
          SET ReceiptDETAIL.LoadKey = NULL,      
              Trafficcop = NULL,
              EditDate = GETDATE(),       --tlting
              EditWho = SUSER_SNAME()
       FROM ReceiptDETAIL, DELETED
       WHERE ReceiptDETAIL.ReceiptKey = DELETED.ReceiptKey
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @n_err=90404   
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ReceiptDETAIL. (ntrLoadPlanRetDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN
          UPDATE ReceiptDETAIL
          SET ReceiptDETAIL.LoadKey = INSERTED.LoadKey,
              Trafficcop = NULL,
              EditDate = GETDATE(),       --tlting
              EditWho = SUSER_SNAME()
          FROM ReceiptDETAIL, INSERTED
          WHERE ReceiptDETAIL.ReceiptKey = INSERTED.ReceiptKey
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err=90405   
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ReceiptDETAIL. (ntrLoadPlanRetDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
       END
    END
 END

      /* #INCLUDE <TRMBODU2.SQL> */
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrLoadPlanRetDetailUpdate"
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