SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_ProductTurnover] (
			@c_facility_start NVARCHAR(5),
			@c_facility_end NVARCHAR(5),
			@c_storer NVARCHAR(18),
			@d_date_start datetime,
			@d_date_end datetime
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_sku NVARCHAR(20),
			@c_descr NVARCHAR(60),
			@n_recvd int,
			@n_shipped int,
			@n_returns int,
			@n_onhand int

  SELECT sku,
			descr,
			recvd = 0,
			shipped = 0,
			returns = 0,
			onhand = 0
  INTO #RESULT
  FROM SKU (NOLOCK)
  WHERE 1 = 2

  DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
  FOR
  SELECT sku, descr
  FROM SKU (NOLOCK)
  WHERE storerkey = @c_storer
    AND facility BETWEEN @c_facility_start AND @c_facility_end

  OPEN cur_1
  FETCH NEXT FROM cur_1 INTO @c_sku, @c_descr
  WHILE (@@fetch_status <> -1)
  BEGIN
    SELECT @n_recvd = COALESCE(SUM(qtyreceived), 0)
    FROM RECEIPT (NOLOCK) INNER JOIN RECEIPTDETAIL (NOLOCK)
      ON RECEIPT.receiptkey = RECEIPTDETAIL.receiptkey
    WHERE RECEIPT.storerkey = @c_storer
      AND RECEIPTDETAIL.sku = @c_sku
      AND RECEIPTDETAIL.lottable05 BETWEEN @d_date_start AND @d_date_end
      AND RECEIPT.rectype = 'NORMAL'

    SELECT @n_shipped = COALESCE(SUM(shippedqty), 0)
    FROM ORDERS (NOLOCK) INNER JOIN ORDERDETAIL (NOLOCK)
      ON ORDERS.orderkey = ORDERDETAIL.orderkey
    WHERE ORDERS.storerkey = @c_storer
      AND ORDERDETAIL.sku = @c_sku
      AND ORDERS.deliverydate BETWEEN @d_date_start AND @d_date_end

    SELECT @n_returns = COALESCE(SUM(qtyreceived), 0)
    FROM RECEIPT (NOLOCK) INNER JOIN RECEIPTDETAIL (NOLOCK)
      ON RECEIPT.receiptkey = RECEIPTDETAIL.receiptkey
    WHERE RECEIPT.storerkey = @c_storer
      AND RECEIPTDETAIL.sku = @c_sku
      AND RECEIPTDETAIL.lottable05 BETWEEN @d_date_start AND @d_date_end
      AND RECEIPT.rectype <> 'NORMAL'

    SELECT @n_onhand = COALESCE(SUM(qty), 0)
    FROM LOTxLOCxID (NOLOCK)
    WHERE storerkey = @c_storer
      AND sku = @c_sku

    INSERT INTO #RESULT VALUES(@c_sku, @c_descr, @n_recvd, @n_shipped, @n_returns, @n_onhand)
    
    FETCH NEXT FROM cur_1 INTO @c_sku, @c_descr
  END
  CLOSE cur_1
  DEALLOCATE cur_1  
 
  SELECT storer=@c_storer, datestart=@d_date_start, dateend=@d_date_end, * FROM #RESULT
  DROP TABLE #RESULT
END








GO