SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrLoadPlanRetDetailAdd
 ON  LoadPlanRetDetail
 FOR INSERT
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF
  	
 DECLARE @b_debug int
 SELECT @b_debug = 0
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
      /* #INCLUDE <TRMBODA1.SQL> */  
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    IF EXISTS (SELECT 1 FROM LoadPlan (NOLOCK), INSERTED
       WHERE LoadPlan.LoadKey = INSERTED.LoadKey
       AND LoadPlan.Status = "9")
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90301
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": LoadPlan Status = 'CLOSED'. UPDATE rejected. (ntrLoadPlanRetDetailAdd)"
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE Receipt
    SET LoadKey = INSERTED.LoadKey,
        TrafficCop = NULL
    FROM Receipt (NOLOCK), INSERTED
    WHERE Receipt.ReceiptKey = INSERTED.ReceiptKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90302  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table Receipt. (ntrLoadPlanRetDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE ReceiptDETAIL
    SET ReceiptDETAIL.LoadKey = INSERTED.LoadKey,
        ReceiptDETAIL.TrafficCop = NULL
    FROM ReceiptDETAIL (NOLOCK), INSERTED
    WHERE ReceiptDETAIL.ReceiptKey = INSERTED.ReceiptKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 90303 
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ReceiptDETAIL. (ntrLoadPlanRetDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    DECLARE     @n_casecnt 	  int,
 		@n_palletcnt 	  int,
 		@c_loadkey 	  NVARCHAR(10),
 		@c_loadlinenumber NVARCHAR(5),
 		@n_weight	  decimal(15, 4),
 		@n_cube		  decimal(15, 4)
 --		@n_Receiptcnt	  int
    SELECT @c_loadkey = INSERTED.LoadKey,
 	  @c_loadlinenumber = INSERTED.LoadLineNumber
    FROM INSERTED
    /* 06/28/2001 CS expected but not yet instructed to do so */
    /*
    SELECT @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
              		         ELSE (ReceiptDETAIL.QtyExpected / PACK.Pallet) END)),
 	  @n_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
 				ELSE (ReceiptDETAIL.QtyExpected / PACK.CaseCnt) END)),
    FROM ReceiptDETAIL (NOLOCK), PACK (NOLOCK), LoadPlanRetDetail (NOLOCK)
    WHERE ReceiptDETAIL.ReceiptKey = LoadPlanRetDetail.ReceiptKey
    AND LoadPlanRetDetail.LoadKey = @c_loadkey
    AND ReceiptDETAIL.Packkey = Pack.Packkey
    SELECT @n_weight = SUM(Weight), 
  	  @n_cube = SUM(Cube),
 	  @n_Receiptcnt = COUNT(ReceiptKey)
    FROM LoadPlanRetDetail (NOLOCK)
    WHERE LoadPlanRetDetail.LoadKey = @c_loadkey
    IF @n_casecnt IS NULL SELECT @n_casecnt = 0
    IF @n_weight IS NULL SELECT @n_weight = 0
    IF @n_cube IS NULL SELECT @n_cube = 0
    IF @n_Receiptcnt IS NULL SELECT @n_Receiptcnt = 0
    IF @n_palletcnt IS NULL SELECT @n_palletcnt = 0
    IF @n_custcnt IS NULL SELECT @n_custcnt = 0
    UPDATE LoadPlan
    SET LoadPlan.ReceiptCount = @n_Receiptcnt,
        LoadPlan.Return_Weight = @n_weight,
        LoadPlan.return_Cube = @n_cube,
        LoadPlan.PalletCnt = @n_palletcnt,
        LoadPlan.CaseCnt = @n_casecnt
    WHERE LoadPlan.LoadKey = @c_loadkey
    */
    SELECT @n_weight = SUM(Weight), 
  	  @n_cube = SUM(Cube)
    FROM LoadPlanRetDetail (NOLOCK)
    WHERE LoadPlanRetDetail.LoadKey = @c_loadkey
    IF @n_weight IS NULL SELECT @n_weight = 0
    IF @n_cube IS NULL SELECT @n_cube = 0
    Update LoadPlan
    SET LoadPlan.Return_Weight = @n_Weight,
        LoadPlan.return_Cube = @n_Cube
    FROM LoadPlanRetDetail    
    WHERE LoadPlan.LoadKey = @c_loadkey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=90304   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table LoadPlan. (ntrLoadPlanRetDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
      /* #INCLUDE <TRMBODA2.SQL> */
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrLoadPlanRetDetailAdd"
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