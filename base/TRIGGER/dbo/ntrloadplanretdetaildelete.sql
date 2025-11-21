SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrLoadPlanRetDetailDelete
 ON LoadPlanRetDetail
 FOR DELETE
 AS
 BEGIN
 IF @@ROWCOUNT = 0
 BEGIN
 RETURN
 END
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
 @n_err              int,       -- Error number returned by stored procedure or this trigger
 @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
 @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
 @n_starttcnt        int,       -- Holds the current transaction count
 @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBODD1.SQL> */     
 IF (select count(1) from DELETED) =
 (select count(1) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
    SELECT @n_continue = 4
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
    IF EXISTS (SELECT * FROM LoadPlan (NOLOCK), DELETED
       WHERE LoadPlan.LoadKey = DELETED.LoadKey
       AND LoadPlan.Status IN ("5", "9"))
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90401
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": LoadPlan.Status = 'SHIPPED'. DELETE rejected. (ntrLoadPlanRetDetailDelete)"
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE Receipt
    SET LoadKey = NULL,
        Trafficcop = NULL
    FROM Receipt (NOLOCK), DELETED
    WHERE Receipt.ReceiptKey = DELETED.ReceiptKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 90402   
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table Receipt. (ntrLoadPlanRetDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE ReceiptDETAIL
    SET LoadKey = NULL,
        Trafficcop = NULL
    FROM ReceiptDETAIL (NOLOCK), DELETED
    WHERE ReceiptDETAIL.ReceiptKey = DELETED.ReceiptKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90403   
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ReceiptDETAIL. (ntrLoadPlanRetDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    DECLARE	@n_casecnt int,
 		@n_palletcnt int,
 		@n_weight decimal(15, 4),
 		@n_cube decimal(15, 4),
 		@n_custcnt int,
 		@n_Receiptcnt int,
 		@c_deleteloadkey NVARCHAR(10)
    SELECT @c_deleteloadkey = DELETED.LoadKey
    FROM DELETED
   	    
  	   
    /* 06/28/2001 CS expected but not instructed to do so */
    /*
    SELECT @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
              		         ELSE (ReceiptDETAIL.OpenQty / PACK.Pallet) END)),
 	  @n_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
 				ELSE (ReceiptDETAIL.OpenQty / PACK.CaseCnt) END))
    FROM ReceiptDETAIL (NOLOCK), LoadPlanRetDetail (NOLOCK), PACK (NOLOCK)
    WHERE ReceiptDETAIL.ReceiptKey = LoadPlanRetDetail.ReceiptKey
    AND LoadPlanRetDetail.LoadKey = @c_deleteloadkey
    AND ReceiptDETAIL.Packkey = PACK.Packkey
    */
    SELECT @n_weight = SUM(Weight), 
  	  @n_cube = SUM(Cube)
 -- 	  @n_cube = SUM(Cube),
 --	  @n_Receiptcnt = COUNT(ReceiptKey)
    FROM LoadPlanRetDetail (NOLOCK)
    WHERE LoadKey = @c_deleteloadkey
    IF @n_casecnt IS NULL SELECT @n_casecnt = 0
    IF @n_weight IS NULL SELECT @n_weight = 0
    IF @n_cube IS NULL SELECT @n_cube = 0
    IF @n_Receiptcnt IS NULL SELECT @n_Receiptcnt = 0
    IF @n_palletcnt IS NULL SELECT @n_palletcnt = 0
    IF @n_custcnt IS NULL SELECT @n_custcnt = 0
    UPDATE LoadPlan
    SET Return_Weight = @n_weight,
 Return_Cube = @n_cube
    WHERE LoadPlan.LoadKey = @c_deleteloadkey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90404   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table LoadPlan. (ntrLoadPlanRetDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
      /* #INCLUDE <TRMBODD2.SQL> */
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrLoadPlanRetDetailDelete"
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