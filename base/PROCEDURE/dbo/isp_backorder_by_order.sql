SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_BackOrder_by_order 	                           	*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: ONG GB                                                   */
/*                                                                      */
/* Purpose: Back Order Report                              					*/
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_backorder_by_order						                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author         Purposes                                  */
/* 2006-12-29  ONG01          Fix bug: Show SKU even no data in SKUxLoc	*/
/* 2007-05-11  James          Remarks INTO #TempBackOrder Keyword      	*/
/************************************************************************/


CREATE PROC [dbo].[isp_BackOrder_by_order](
 	@c_StorerKey NVARCHAR(15)
,  @c_OrderDateStart NVARCHAR(8)
,  @c_OrderDateEnd NVARCHAR(8)
,  @b_debug 		int = 0
)
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
	SET NOCOUNT ON
	DECLARE @n_continue 		int
	   , @n_starttcnt			int		-- Holds the current transaction count  
		, @n_err      			int
		, @c_errmsg   		 NVARCHAR(250)
	
	-- Initialize Local Variables
   SELECT @n_starttcnt = @@TRANCOUNT ,@n_continue = 1 

   IF OBJECT_ID('tempdb..#TempStk')          IS NOT NULL      DROP TABLE #TempStk
   IF OBJECT_ID('tempdb..#TempBackOrder')    IS NOT NULL      DROP TABLE #TempBackOrder
   IF OBJECT_ID('tempdb..#TempOrder')    		IS NOT NULL      DROP TABLE #TempOrder

	CREATE TABLE [#TempBackOrder] (
		[StorerKey] [char] (15) NULL ,
		[Facility] [char] (5) NULL ,
		[OrderDate] [datetime] NULL ,
		[BillDate] [datetime] NULL ,
		[Wavekey] [char] (10) NULL ,
		[Type] [char] (10) NULL ,
		[Status] [char] (10) NULL ,
		[OrderKey] [char] (10) NULL ,
		[ExternOrderKey] [char] (30) NULL ,
		[Loadkey] [char] (10) NULL ,
		[InvoiceNo] [char] (10) NULL ,
		[ConsigneeKey] [char] (15) NULL ,
		[C_Company] [char] (45) NULL ,
		[StorerName] [char] (45) NULL ,
		[OrderLineNumber] [char] (5) NULL ,
		[SKU] [char] (20) NULL ,
		[Descr] [char] (60) NULL ,
		[UOM] [char] (10) NULL ,
		[Lottable01] [char] (18) NULL ,
		[OriginalQty] [int] NULL ,
		[Qtyallocated] [int] NULL ,
		[QtyPicked] [int] NULL ,
		[ShippedQty] [int] NULL ,
		[TotalOrder] [int] NULL ,
		[QtyAvail] [int] NULL ,
		[QtyStock] [int] NULL 
	) ON [PRIMARY]

	-- Date Validation
	IF (ISDATE(@c_OrderDateStart) = 0 OR ISDATE(@c_OrderDateEnd) = 0)
	BEGIN
      SELECT @n_Continue = 3
		SELECT @n_err = 68001
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Invalid Date Input (isp_BackOrder_by_order)'  
	END

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN	
	INSERT INTO #TempBackOrder (
	StorerKey, Facility, OrderDate, 	BillDate, Wavekey, Type, Status, OrderKey, ExternOrderKey, 
	Loadkey, InvoiceNo, ConsigneeKey, C_Company, StorerName, OrderLineNumber, SKU, Descr, UOM, Lottable01, 
	OriginalQty, Qtyallocated, QtyPicked, TotalOrder, QtyAvail, QtyStock) 

		SELECT ORDERS.StorerKey, 
			ORDERS.Facility,
			ORDERS.OrderDate,	
			GUI.BillDate,	
			ISNULL(WaveDetail.Wavekey, '') Wavekey, 
			ORDERS.Type,	
			ORDERS.Status,
			ORDERS.OrderKey,	
			ORDERS.ExternOrderKey,	
			Orders.Loadkey,
			ORDERS.InvoiceNo,
			ORDERS.ConsigneeKey,	
			Orders.C_Company,	
			Storer.Company StorerName,
			ORDERDETAIL.OrderLineNumber,	
			ORDERDETAIL.SKU,	
			SKU.Descr,	
			ORDERDETAIL.UOM,	
			ORDERDETAIL.Lottable01,
			ORDERDETAIL.OriginalQty,	
			ORDERDETAIL.Qtyallocated,	
			ORDERDETAIL.QtyPicked,	
			0 TotalOrder,
			0 QtyAvail, 	
			0 QtyStock 	
--		INTO #TempBackOrder
		FROM ORDERS (NOLOCK) 
		JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey 
		JOIN SKU (NOLOCK) ON SKU.SKU = Orderdetail.SKU AND SKU.Storerkey = ORDERS.Storerkey
	  LEFT OUTER JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = Orders.Orderkey 
		JOIN STORER (NOLOCK) ON Storer.Storerkey = Orders.Storerkey  
		LEFT OUTER JOIN GUI (NOLOCK) ON GUI.InvoiceNo = ORDERS.InvoiceNo
	  WHERE ORDERS.StorerKey = @c_StorerKey
			 AND ORDERS.Status <> 'CANC'
		 AND CONVERT(datetime, CONVERT(CHAR(10), ORDERS.OrderDate ,120)) BETWEEN @c_OrderDateStart AND @c_OrderDateEnd 
		GROUP BY ORDERS.StorerKey, 
			ORDERS.Facility,
			ORDERS.OrderDate,	
			ORDERS.Type,	
			ORDERS.Status,
			ORDERS.OrderKey,	
			ORDERS.ExternOrderKey,	
			Orders.Loadkey,
			ORDERS.InvoiceNo,
			ORDERS.ConsigneeKey,	
			Orders.C_Company,	
			Storer.Company ,
			ORDERDETAIL.OrderLineNumber,	
			ORDERDETAIL.SKU,	
			SKU.Descr,	
			ORDERDETAIL.UOM,	
			ORDERDETAIL.OriginalQty,	
			ORDERDETAIL.Qtyallocated,	
			ORDERDETAIL.QtyPicked,	
			ORDERDETAIL.Lottable01,
			GUI.BillDate,	
			ISNULL(WaveDetail.Wavekey, '')
		ORDER BY ORDERDETAIL.SKU
		
		If @@ROWCOUNT = 0
			SELECT @n_continue = 2
	END

	-- if Recound not found , @n_continue = 2
	IF @n_continue = 1
	BEGIN
		SELECT LotxLocxID.SKU , Loc.HOSTWHCODE , SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) QtyAvail
		, SUM(LOTxLOCxID.Qty) QtyStock
		INTO #TempStk
		FROM LotxLocxID (NOLOCK)
		JOIN Loc (NOLOCK) ON Loc.Loc = LotxLocxID.Loc
		WHERE LotxLocxID.Storerkey =  @c_StorerKey
		GROUP BY LotxLocxID.SKU, Loc.HOSTWHCODE 
		
		-- Calculate Total Required Order 
		SELECT SKU, ORDERDETAIL.Lottable01, SUM(ORDERDETAIL.OriginalQty - QtyAllocated - QtyPicked) TotalOrder 
		INTO #TempOrder 
		FROM ORDERS (NOLOCK) 
		JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey 
	  WHERE ORDERS.StorerKey = @c_StorerKey
		 AND ORDERS.Status < 3
		 AND CONVERT(datetime, CONVERT(CHAR(10), ORDERS.OrderDate ,120)) BETWEEN @c_OrderDateStart AND @c_OrderDateEnd 
		GROUP BY SKU ,ORDERDETAIL.Lottable01


		UPDATE #TempBackOrder
		SET QtyAvail = ISNULL(t2.QtyAvail, 0) , QtyStock = ISNULL(t2.QtyStock , 0)					-- ONG01
			,TotalOrder = t3.TotalOrder
		FROM #TempBackOrder t1
		LEFT OUTER JOIN #TempStk t2 ON t1.SKU = t2.SKU	AND t1.Lottable01 = t2.HostWHCODE		-- ONG01
		JOIN #TempOrder t3 ON t1.SKU = t3.SKU AND t1.Lottable01 = t3.Lottable01

		If @b_debug = 1
		BEGIN
			PRINT 'Before Delete'
			SELECT SKU, OriginalQty ,TotalOrder, QtyAvail, QtyStock FROM #TempBackOrder
			ORDER BY SKU
		END 	

		-- Omit Those Record not required	
		DELETE FROM #TempBackOrder
		WHERE TotalOrder < QtyAvail		-- Show Only TotalOrder > QtyAvail
		OR Status > 3							-- Show Only Status <= 3

		If @b_debug = 1 OR @b_debug = 2
		BEGIN
			PRINT 'Final... '
			SELECT SKU, OriginalQty, QtyStock, QtyAvail ,TotalOrder FROM #TempBackOrder
			ORDER BY SKU
		END 	
	
	END	-- If with record found

	If @n_continue = 1 OR @n_continue = 2
	BEGIN
		SELECT * FROM #TempBackOrder
		ORDER BY SKU
	END

	If @n_continue = 3
	BEGIN
	   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
	   RETURN  
	END

   IF OBJECT_ID('tempdb..#TempStk')          IS NOT NULL      DROP TABLE #TempStk
   IF OBJECT_ID('tempdb..#TempBackOrder')    IS NOT NULL      DROP TABLE #TempBackOrder
   IF OBJECT_ID('tempdb..#TempOrder')    		IS NOT NULL      DROP TABLE #TempOrder

END

GO