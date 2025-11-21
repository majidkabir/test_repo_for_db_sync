SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispUpdateAllocatedLoad]
                @c_loadkey      NVARCHAR(10)
 ,              @b_Success      int        OUTPUT
 ,              @n_err          int        OUTPUT
 ,              @c_errmsg       NVARCHAR(250)  OUTPUT
 AS
 BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE        @n_continue int        ,  
 @n_starttcnt   int      , -- Holds the current transaction count
 @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
 @c_preprocess NVARCHAR(250) , -- preprocess
 @c_pstprocess NVARCHAR(250) , -- post process
 @n_err2 int             , -- For Additional Error Detection
 @b_debug int            -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
 DECLARE
 @n_alloc_casecnt	int,
 @n_alloc_palletcnt	int,
 @n_alloc_weight		decimal(15, 4),
 @n_alloc_cube		decimal(15, 4),
 @n_alloc_custcnt	int,
 @n_alloc_ordercnt	int
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
 SELECT @b_debug = 0
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 	SELECT 	@n_alloc_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
              		         ELSE ((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) / PACK.Pallet) END)),
           	@n_alloc_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
 				ELSE ((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) / PACK.CaseCnt) END)),
           	--@n_alloc_cube = SUM((ORDERDETAIL.QtyAllocated + OrderDetail.QtyPicked) * SKU.StdCube),
            @n_alloc_cube = SUM((ORDERDETAIL.QtyAllocated + OrderDetail.QtyPicked) * ROUND(SKU.StdCube,6)), -- SOS 85340
           	@n_alloc_weight = SUM((OrderDetail.QtyAllocated + OrderDetail.QtyPicked) * SKU.StdGrossWgt)
    	FROM ORDERDETAIL (NOLOCK), PACK (NOLOCK), SKU (NOLOCK), LoadPlanDetail (NOLOCK)
    	WHERE ORDERDETAIL.OrderKey = LoadPlanDetail.OrderKey
    	AND LoadPlandetail.LoadKey = @c_loadkey
    	AND ORDERDETAIL.Packkey = PACK.Packkey
    	AND ORDERDETAIL.SKU = SKU.SKU
    	AND ORDERDETAIL.Storerkey = SKU.Storerkey
 	SELECT @n_cnt = @@ROWCOUNT
 	IF @n_cnt = 0	SELECT @n_continue = 4
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    	SELECT 	@n_alloc_ordercnt = COUNT(DISTINCT ORDERS.OrderKey),
 	  	@n_alloc_custcnt = COUNT(DISTINCT ORDERS.ConsigneeKey)
    	FROM LoadPlanDetail, Orders, OrderDetail
    	WHERE LoadPlanDetail.LoadKey = @c_loadkey
    	AND ORDERS.OrderKey = LoadPlanDetail.OrderKey
    	AND OrderDetail.OrderKey = ORDERS.OrderKey
    	AND (OrderDetail.QtyAllocated + OrderDetail.QtyPicked) >= 1
 	SELECT @n_cnt = @@ROWCOUNT
 	IF @n_cnt = 0	SELECT @n_continue = 4
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 	IF @n_alloc_casecnt IS NULL SELECT @n_alloc_casecnt = 0
 	IF @n_alloc_weight IS NULL SELECT @n_alloc_weight = 0
 	IF @n_alloc_cube IS NULL SELECT @n_alloc_cube = 0
 	IF @n_alloc_ordercnt IS NULL SELECT @n_alloc_ordercnt = 0
 	IF @n_alloc_palletcnt IS NULL SELECT @n_alloc_palletcnt = 0
 	IF @n_alloc_custcnt IS NULL SELECT @n_alloc_custcnt = 0
 	UPDATE LoadPlan
    	SET AllocatedCustCnt = @n_alloc_custcnt,
 	AllocatedOrderCnt = @n_alloc_ordercnt,
 	AllocatedWeight = @n_alloc_weight,
 	AllocatedCube = @n_alloc_cube,
 	AllocatedPalletCnt = @n_alloc_palletcnt,
 	AllocatedCaseCnt = @n_alloc_casecnt,
 	TrafficCop = NULL
 	WHERE LoadKey = @c_loadkey
 	SELECT @n_err = @@ERROR
 	IF @n_err <> 0
       	BEGIN
 		SELECT @n_continue = 3
 		SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 89901 
 		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update LoadPlan table (ispUpdateAllocatedLoad)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 	END
 END  
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
    execute nsp_logerror @n_err, @c_errmsg, "ispUpdateAllocatedLoad"
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
 END -- End of Procedure


GO