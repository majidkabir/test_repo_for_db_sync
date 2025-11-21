SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************************/
/* Stored Procedure: isp_RPT_RP_REPLENISHONDEMAND_002                                   */
/* Creation Date: 09-Mar-2023                                                           */
/* Copyright: LFL                                                                       */
/* Written by: WLChooi                                                                  */
/*                                                                                      */
/* Purpose: WMS-21903 - NIKEMY, NIKESG Replenishment Report                             */
/*          Copy and modify from isp_ReplenishOnDemand_rpt                              */
/*                                                                                      */
/* Called By: Report                                                                    */
/*                                                                                      */
/* PVCS Version: 1.0                                                                    */
/*                                                                                      */
/* Version: 5.4                                                                         */
/*                                                                                      */
/* Data Modifications:                                                                  */
/*                                                                                      */
/* Updates:                                                                             */
/* Date         Author   Ver  Purposes                                                  */
/* 09-Mar-2023  WLChooi  1.0  DevOps Combine Script                                     */
/* 15-MAR-2023  Nicole  v1.1  Create SQL https://jiralfl.atlassian.net/browse/WMS-22016 */  
/* 27-MAR-2023  Nicole  v1.2  Modify SQL https://jiralfl.atlassian.net/browse/WMS-22016 */  
/* 30-MAR-2023  Nicole  v1.3  Modify SQL https://jiralfl.atlassian.net/browse/WMS-22016 */
/* 07-APR-2023  Nicole  v1.4  Modify SQL https://jiralfl.atlassian.net/browse/WMS-22016 */ 
/****************************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_RP_REPLENISHONDEMAND_002]
(
   @c_Storerkey     NVARCHAR(15)
 , @dt_deliveryfrom DATETIME
 , @dt_deliveryto   DATETIME
 , @c_SKUGroup      NVARCHAR(10)
 , @c_Lottable01    NVARCHAR(18) = ''
 , @c_Lottable02    NVARCHAR(18) = ''
 , @c_Lottable03    NVARCHAR(18) = ''
 , @c_Facility      NVARCHAR(5)  = ''
 , @c_PAZoneFrom    NVARCHAR(10) = ''
 , @c_PAZoneTo      NVARCHAR(10) = ''
 , @c_ShowBCode     NVARCHAR(1)  = 'N'
 , @c_EmptyPickLOC  NVARCHAR(1)  = 'N'
)
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_DEFAULTS OFF
	SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF


	DECLARE @T_TEMP AS TABLE
	(
	  RowID      INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
	, LOC        NVARCHAR(10)  NULL
	, ID         NVARCHAR(20)  NULL
	, QTY        INT           NULL
	, Lottable01 NVARCHAR(30)  NULL
	, Lottable02 NVARCHAR(30)  NULL
	, Lottable03 NVARCHAR(30)  NULL
	, LocLevel   INT           NULL
	, FromLLI    NVARCHAR(100) NULL
	)


	DECLARE @c_SKU          NVARCHAR(20)
		, @c_PrevSKU        NVARCHAR(20)
		, @c_FromLOC        NVARCHAR(10)
		, @c_FromID         NVARCHAR(18)
		, @n_QTYtoReplen    INT
		, @n_QTYAvail       INT
		, @c_GetLottable01  NVARCHAR(18)
		, @c_GetLottable02  NVARCHAR(18)
		, @c_GetLottable03  NVARCHAR(18)
		, @n_QtyA           INT
		, @n_QtyB           INT
		, @c_LocType        NVARCHAR(10)
		, @c_RetVal         NVARCHAR(255)
		, @n_RowA           INT
		, @n_RowB           INT
		, @c_FromLLI        NVARCHAR(100) = N''
		, @n_GetQTYtoReplen INT


	EXEC dbo.isp_GetCompanyInfo @c_Storerkey = @c_Storerkey  
								, @c_Type = N'1'  
								, @c_DataWindow = N'RPT_RP_REPLENISHONDEMAND_002'  
								, @c_RetVal = @c_RetVal OUTPUT  


	--ORDER DEMAND
	SELECT OD.StorerKey
		, OD.Sku
		, COUNT(DISTINCT O.OrderKey) NoOfOrder
		, SUM(OD.OriginalQty) OrderQTY
		, SPACE(10) ToLoc
		, 0 AS PFAvail
		, 0 AS BulkAvail
		, 0 AS QTYtoReplen  
		, SKU.Descr
		, PACK.PackUOM3
		, @c_ShowBCode AS ShowBCode
	INTO #Demand
	FROM ORDERS O (NOLOCK)
	INNER JOIN ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
	INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku)
	INNER JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
	WHERE O.StorerKey = @c_Storerkey
	AND O.[Status] = '0'
	AND DATEDIFF(DAY, @dt_deliveryfrom, O.DeliveryDate) >= 0
	AND DATEDIFF(DAY, O.DeliveryDate, @dt_deliveryto) >= 0
	AND SKU.SKUGROUP = @c_SKUGroup
	AND O.Facility = @c_Facility
	GROUP BY OD.StorerKey
		, OD.Sku
		, SKU.Descr
		, PACK.PackUOM3
	ORDER BY OD.StorerKey
		, OD.Sku
  
	--UPDATE PF LOC (LOC LIKE '1%-%-%')
	UPDATE #Demand
	SET ToLOC = sl.LOC
	FROM #Demand d (NOLOCK)
	INNER JOIN (SELECT SL.StorerKey
					, SL.Sku
					, MIN(SL.LOC) AS LOC -- sku could have multi pick face, use min()
				FROM SKUxLOC SL (NOLOCK)
				INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
				WHERE SL.StorerKey = @c_Storerkey
				AND SL.LocationType IN ('CASE', 'PICK')
				AND LOC.PutawayZone <> 'adidas'
				AND LOC.Facility = @c_Facility
				--AND LOC.Loc LIKE '1%-%-%'		--COMMENT OUT IN v1.1
				AND LOC.LocationType = 'PICK'
				AND LOC.PutawayZone BETWEEN @c_PAZoneFrom AND @c_PAZoneTo
				GROUP BY SL.StorerKey, SL.Sku) SL 
	ON (d.StorerKey = SL.StorerKey AND d.Sku = SL.Sku)
  
	--UPDATE PF AVAIL          
	UPDATE #Demand
	SET PFAvail = sl.PFAvail
	FROM #Demand r (NOLOCK)
	INNER JOIN (SELECT SL.StorerKey
					, SL.Sku
					, SUM(SL.Qty - SL.QtyAllocated - SL.QtyPicked) PFAvail
				FROM SKUxLOC SL (NOLOCK)
				INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
				WHERE SL.StorerKey = @c_Storerkey
				AND SL.LocationType IN ('CASE', 'PICK')
				AND (SL.Qty - SL.QtyAllocated - SL.QtyPicked) > 0
				AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
				AND LOC.Status <> 'HOLD'
				AND LOC.Facility = @c_Facility
				AND LOC.PutawayZone BETWEEN @c_PAZoneFrom AND @c_PAZoneTo
				--AND LOC.Loc LIKE '1%-%-%'		--COMMENT OUT IN v1.1
				AND LOC.LocationType = 'PICK'
				GROUP BY SL.StorerKey, SL.Sku) SL 
	ON (r.StorerKey = SL.StorerKey AND r.Sku = SL.Sku)
  
	--UPDATE BULK AVAIL         
	UPDATE #Demand
	SET BulkAvail = SL.BulkAvail
	FROM #Demand r (NOLOCK)
	INNER JOIN (SELECT SL.StorerKey
					, SL.Sku
					, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS BulkAvail
				FROM SKUxLOC SL (NOLOCK)
				INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
				INNER JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.StorerKey = SL.StorerKey
					AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)  
				INNER JOIN LOTATTRIBUTE L (NOLOCK) ON (L.Lot = LLI.Lot)
				WHERE SL.StorerKey = @c_Storerkey
				AND SL.LocationType NOT IN ('CASE', 'PICK')
				AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
				AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
				AND LOC.Status <> 'HOLD'
				AND (L.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
				AND (L.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
				AND (L.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
				AND LOC.Facility = @c_Facility
				AND LOC.LocationType = 'OTHER'
				AND LOC.Loc LIKE 'K%-%-%'
				GROUP BY SL.StorerKey, SL.Sku) SL 
	ON (r.StorerKey = SL.StorerKey AND r.Sku = SL.Sku)


	--UPDATE QtyToReplen (Dedict QtyAvailable from PF)
	UPDATE #Demand
	SET QTYtoReplen = OrderQTY - PFAvail
	WHERE (OrderQTY - PFAvail) > 0


	--DELETE THOSE DONOT NEED TO REPLEN    
	IF ISNULL(@c_EmptyPickLOC, 'N') = 'N'
	BEGIN
		DELETE #Demand
		WHERE QTYtoReplen = 0 --OR ISNULL(ToLOC, '') = ''		--COMMENT IN v1.3
	END
	ELSE
	BEGIN
		DELETE #Demand
		WHERE QTYtoReplen = 0
	END

	SET @c_FromLOC = N''
	SET @c_FromID = N''
	SET @c_LocType = N''


	--CREATE BLANK #Replen          
	SELECT LLI.StorerKey
		, LLI.Sku
		, LLI.Loc
		, LLI.ID
		, LLI.Qty
		, L.Lottable01
		, L.Lottable02
		, L.Lottable03
		, SPACE(10) AS LocType
		, SPACE(100) AS FromLLI
		, LLI.Qty AS QtyToRepl
	INTO #Replen
	FROM LOTxLOCxID LLI (NOLOCK)
	JOIN LOTATTRIBUTE L (NOLOCK) ON LLI.Lot = L.Lot
	WHERE 1 = 0


	DECLARE cur_Demand CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT StorerKey
			, Sku
			, QTYtoReplen  
		FROM #Demand
		ORDER BY StorerKey
			, Sku

		OPEN cur_Demand

		FETCH NEXT FROM cur_Demand
		INTO @c_Storerkey  
			, @c_SKU  
			, @n_QTYtoReplen  
  
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @n_QTYAvail = NULL
			SET @c_FromLOC = N''
			SET @c_FromID = N''
			SET @c_FromLLI = N''
  
		IF @c_PrevSKU <> @c_SKU  
		BEGIN
			SET @c_PrevSKU = @c_SKU  
			SET @n_GetQTYtoReplen = @n_QTYtoReplen  
		END


		--For LOCLevel = '1' (BULK PICK FACE)
		IF ISNULL(@c_FromLOC, '') = ''
		BEGIN
			DELETE FROM @T_TEMP

			INSERT INTO @T_TEMP
			SELECT LLI.Loc
				, LLI.ID
				, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS Qty
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
				, LLI.Loc + LLI.ID + LLI.Lot
			FROM LOTxLOCxID LLI (NOLOCK)
			INNER JOIN SKUxLOC SL (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
			INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			INNER JOIN LOTATTRIBUTE L (NOLOCK) ON (L.Lot = LLI.Lot)
			WHERE SL.StorerKey = @c_Storerkey
			AND SL.Sku = @c_SKU
			AND SL.LocationType NOT IN ('PICK', 'CASE')
			AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
			AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
			AND LOC.Status <> 'HOLD'
			AND (L.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
			AND (L.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
			AND (L.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
			AND LOC.Facility = @c_Facility
			AND LOC.LocationType = 'OTHER'
			AND LOC.Loc LIKE 'K%'
			AND LOC.LocLevel = 1
			AND (LLI.Loc + LLI.Id + LLI.Lot) NOT IN (SELECT DISTINCT L.FromLLI FROM #Replen L )
			GROUP BY LLI.Loc
				, LLI.ID
				, LLI.Lot
				, LLI.Loc
				, LLI.ID
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
		END  


		--For LOCLevel > 1	(BULK LOC)
		IF NOT EXISTS (SELECT 1 FROM @T_TEMP)  
		BEGIN
			DELETE FROM @T_TEMP

			INSERT INTO @T_TEMP
			SELECT LLI.Loc
				, LLI.ID
				, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS Qty
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
				, LLI.Loc + LLI.ID + LLI.Lot
			FROM LOTxLOCxID LLI (NOLOCK)
			INNER JOIN SKUxLOC SL (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
			INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			INNER JOIN LOTATTRIBUTE L (NOLOCK) ON (L.Lot = LLI.Lot)
			WHERE SL.StorerKey = @c_Storerkey
			AND SL.Sku = @c_SKU
			AND SL.LocationType NOT IN ('PICK', 'CASE')
			AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
			AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
			AND LOC.Status <> 'HOLD'
			AND (L.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
			AND (L.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
			AND (L.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
			AND LOC.Facility = @c_Facility
			AND LOC.LocationType = 'OTHER'
			AND LOC.Loc LIKE 'K%'
			AND LOC.LocLevel > 1
			AND   (LLI.Loc + LLI.Id + LLI.Lot) NOT IN (SELECT DISTINCT L.FromLLI FROM #Replen L )  
			GROUP BY LLI.Loc
				, LLI.ID
				, LLI.Lot
				, LLI.Loc
				, LLI.ID
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
		END


		--For LOCLevel = 0	(STAGING)			--ADD IN v1.3
		IF NOT EXISTS (SELECT 1 FROM @T_TEMP)  
		BEGIN
			DELETE FROM @T_TEMP

			INSERT INTO @T_TEMP
			SELECT LLI.Loc
				, LLI.ID
				, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS Qty
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
				, LLI.Loc + LLI.ID + LLI.Lot
			FROM LOTxLOCxID LLI (NOLOCK)
			INNER JOIN SKUxLOC SL (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
			INNER JOIN LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			INNER JOIN LOTATTRIBUTE L (NOLOCK) ON (L.Lot = LLI.Lot)
			WHERE SL.StorerKey = @c_Storerkey
			AND SL.Sku = @c_SKU
			AND SL.LocationType NOT IN ('PICK', 'CASE')
			AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
			AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
			AND LOC.Status <> 'HOLD'
			AND (L.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
			AND (L.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
			AND (L.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
			AND LOC.Facility = @c_Facility
			AND LOC.LocationType = 'OTHER'
			AND LOC.Loc IN ('NIKEMY', 'NIKESG', 'UNPICKMY', 'UNPICKSG')
			AND LOC.LocLevel = 0
			AND (LLI.Loc + LLI.Id + LLI.Lot) NOT IN (SELECT DISTINCT L.FromLLI FROM #Replen L )  
			GROUP BY LLI.Loc
				, LLI.ID
				, LLI.Lot
				, LLI.Loc
				, LLI.ID
				, L.Lottable01
				, L.Lottable02
				, L.Lottable03
				, LOC.LocLevel
		END
		

		IF ISNULL(@c_FromLOC, '') = ''
		BEGIN
			SELECT TOP 1 @n_QtyA = MIN(QTY - @n_QTYtoReplen)
				, @c_FromLOC = LOC  
				, @c_FromID = ID
				, @n_QTYAvail = QTY  
				, @c_GetLottable01 = Lottable01
				, @c_GetLottable02 = Lottable02
				, @c_GetLottable03 = Lottable03
				, @c_LocType = LocLevel
				, @n_RowA = RowID
				, @c_FromLLI = FromLLI
			FROM @T_TEMP
			GROUP BY LOC
				, ID
				, QTY
				, Lottable01
				, Lottable02
				, Lottable03
				, LocLevel
				, RowID
				, FromLLI
			HAVING MIN(QTY - @n_QTYtoReplen) >= 0
			ORDER BY MIN(QTY - @n_QTYtoReplen)
		END


		IF ISNULL(@c_FromLOC, '') = ''
		BEGIN
			SELECT TOP 1 @n_QtyB = MIN(@n_QTYtoReplen - QTY)
				, @c_FromLOC = LOC  
				, @c_FromID = ID
				, @n_QTYAvail = QTY  
				, @c_GetLottable01 = Lottable01
				, @c_GetLottable02 = Lottable02
				, @c_GetLottable03 = Lottable03
				, @c_LocType = LocLevel
				, @n_RowB = RowID
				, @c_FromLLI = FromLLI
			FROM @T_TEMP
			GROUP BY LOC
				, ID
				, QTY
				, Lottable01
				, Lottable02
				, Lottable03
				, LocLevel
				, RowID
				, FromLLI
			HAVING MIN(@n_QTYtoReplen - QTY) >= 0
			ORDER BY MIN(@n_QTYtoReplen - QTY)
		END
		

		IF @n_QTYAvail IS NULL
			FETCH NEXT FROM cur_Demand
			INTO @c_Storerkey
				, @c_SKU
				, @n_QTYtoReplen
		ELSE
		BEGIN
			IF @n_QTYtoReplen <= @n_QTYAvail
			BEGIN
				INSERT INTO #Replen (StorerKey, Sku, Loc, ID, Qty, Lottable01, Lottable02, Lottable03, LocType, FromLLI, QtyToRepl)
				VALUES (@c_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @n_QTYtoReplen, @c_GetLottable01, @c_GetLottable02, @c_GetLottable03, @c_LocType, @c_FromLLI, @n_GetQTYtoReplen)		--UPDATE IN v1.2
				--VALUES (@c_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @n_QTYAvail, @c_GetLottable01, @c_GetLottable02, @c_GetLottable03, @c_LocType, @c_FromLLI, @n_GetQTYtoReplen)

				FETCH NEXT FROM cur_Demand
				INTO @c_Storerkey
					, @c_SKU
					, @n_QTYtoReplen
			END
			ELSE  
			BEGIN  
				INSERT INTO #Replen (StorerKey, Sku, Loc, ID, Qty, Lottable01, Lottable02, Lottable03, LocType, FromLLI, QtyToRepl)
				VALUES (@c_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @n_QTYAvail, @c_GetLottable01, @c_GetLottable02, @c_GetLottable03, @c_LocType, @c_FromLLI, @n_GetQTYtoReplen)
				SET @n_QTYtoReplen = @n_QTYtoReplen - @n_QTYAvail
			END
		END
	END
	CLOSE cur_Demand
	DEALLOCATE cur_Demand
  
	SELECT D.StorerKey
		, D.Sku
		, D.Descr
		, D.PackUOM3
		, ToLoc = UPPER(D.ToLoc)	--UPDATE IN v1.3
		, D.QtyToReplen				--ADD IN v1.3		--ORDER QTY
		, Loc = UPPER(R.Loc)		--UPDATE IN v1.3
		, R.ID
		, Qty = ISNULL(R.Qty, 0)	--UPDATE IN v1.3	--QtyToReplen
		, R.Lottable01
		, R.Lottable02
		, R.Lottable03
		, D.ShowBCode
		, ISNULL(@c_RetVal, '') AS Logo
	FROM #Demand D
	LEFT JOIN #Replen R ON (R.StorerKey = D.StorerKey AND R.Sku = D.Sku)
	ORDER BY D.ToLOC, R.LocType, R.Loc


	IF CURSOR_STATUS('LOCAL', 'cur_Demand') IN ( 0, 1 )
	BEGIN
		CLOSE cur_Demand
		DEALLOCATE cur_Demand
	END

	IF OBJECT_ID('tempdb..#Demand') IS NOT NULL
		DROP TABLE #Demand

	IF OBJECT_ID('tempdb..#Replen') IS NOT NULL
		DROP TABLE #Replen
END


GO