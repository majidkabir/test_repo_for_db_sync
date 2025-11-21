SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispExtract_StockStatus] 
	( @c_StorerKey   NVARCHAR(15) )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	SELECT SKU.SKU, SKU.DESCR, SKUStatus='SOH'+ SPACE(7) , QTY=SUM(Qty)
	INTO   #SOH
	FROM   LOTxLOCxID (NOLOCK), SKU (NOLOCK)
	WHERE  LOTxLOCxID.StorerKey = SKU.StorerKey
	AND    LOTxLOCxID.SKU = SKU.SKU
	AND    SKU.StorerKey = @c_StorerKey
	AND    LOTxLOCxID.Qty > 0
	GROUP BY SKU.SKU, SKU.DESCR

	SELECT SKU, QTY=SUM(Qty)
	INTO   #SHIPPED
	FROM   ITRN (NOLOCK)
	WHERE  StorerKey = @c_StorerKey
	AND    TranType = 'WD'
	AND    SourceType = 'ntrPickDetailUpdate'
	AND    AddDate >= CAST( Convert( NVARCHAR(20), GETDATE(), 106) + '00:00:00:000' AS Datetime )
	AND    AddDate <= CAST( Convert( NVARCHAR(20), GETDATE(), 106) + '23:59:59:999' AS Datetime )
	GROUP BY SKU

	SELECT SKU, QTY=SUM(Qty)
	INTO   #RECEIVED
	FROM   ITRN (NOLOCK), TRANSFER (NOLOCK)
	WHERE  StorerKey = 'SBHK'
	AND    TranType = 'DP'
	AND    SourceType LIKE 'ntrTransferDetailUpdate'
	AND    ITRN.AddDate >= CAST( Convert( NVARCHAR(20), GETDATE(), 106) + '00:00:00:000' AS Datetime )
	AND    ITRN.AddDate <= CAST( Convert( NVARCHAR(20), GETDATE(), 106) + '23:59:59:999' AS Datetime )
	AND    Transfer.TransferKey = LEFT(SourceKey,10)
	GROUP BY SKU

	UPDATE #SOH
		SET Qty = #SOH.Qty + #SHIPPED.Qty
	FROM #SHIPPED
	WHERE #SHIPPED.SKU = #SOH.SKU

	UPDATE #SOH
		SET Qty = #SOH.Qty + #RECEIVED.Qty
	FROM #RECEIVED
	WHERE #RECEIVED.SKU = #SOH.SKU

	INSERT INTO #SOH (SKU, DESCR, SKUStatus, Qty)
		SELECT SKU.SKU, SKU.DESCR, 'Shipped', Qty
		FROM   #SHIPPED, SKU (NOLOCK)
		WHERE  SKU.StorerKey = @c_StorerKey
		AND    SKU.SKU = #SHIPPED.SKU
		
	INSERT INTO #SOH (SKU, DESCR, SKUStatus, Qty)
		SELECT SKU.SKU, SKU.DESCR, 'Received', Qty
		FROM   #RECEIVED, SKU (NOLOCK)
		WHERE  SKU.StorerKey = @c_StorerKey
		AND    SKU.SKU = #RECEIVED.SKU
		
	INSERT INTO #SOH (SKU, DESCR, SKUStatus, Qty)
	SELECT SKU.SKU, SKU.DESCR, SKUStatus='Allocated' , QTY=SUM(QtyAllocated)
	FROM   LOTxLOCxID (NOLOCK), SKU (NOLOCK)
	WHERE  LOTxLOCxID.StorerKey = SKU.StorerKey
	AND    LOTxLOCxID.SKU = SKU.SKU
	AND    SKU.StorerKey = @c_StorerKey
	AND    LOTxLOCxID.QtyAllocated > 0
	GROUP BY SKU.SKU, SKU.DESCR


	INSERT INTO #SOH (SKU, DESCR, SKUStatus, Qty)
	SELECT SKU.SKU, SKU.DESCR, SKUStatus='Picked' , QTY=SUM(QtyPicked)
	FROM   LOTxLOCxID (NOLOCK), SKU (NOLOCK)
	WHERE  LOTxLOCxID.StorerKey = SKU.StorerKey
	AND    LOTxLOCxID.SKU = SKU.SKU
	AND    SKU.StorerKey = @c_StorerKey
	AND    LOTxLOCxID.QtyPicked > 0
	GROUP BY SKU.SKU, SKU.DESCR

	SELECT * FROM #SOH
	ORDER BY SKU, SKUStatus

END


GO