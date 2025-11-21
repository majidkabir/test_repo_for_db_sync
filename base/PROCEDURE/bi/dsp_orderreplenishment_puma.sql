SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************************************/
-- Purpose  : MYS-LogiReport-Create Views/SP in BI Schema https://jiralfl.atlassian.net/browse/WMS-23581 
/* Updates:                                                                                              */
/* Date				Author      Ver.  Purposes                                                           */
/* 11-Nov-2023		Jareklim    1.0   Created                                                            */
/*********************************************************************************************************/
--EXEC  BI.dsp_OrderReplenishment_PUMA 'PUMA', '2023-09-01 00:00','2023-09-13 11:59','KESAS','FOOTWEAR','N','N'
--EXEC  BI.dsp_OrderReplenishment_PUMA '','','','','','',''
--EXEC  BI.dsp_OrderReplenishment_PUMA NULL,NULL,NULL,NULL,NULL,NULL.NULL
CREATE   PROC [BI].[dsp_OrderReplenishment_PUMA]
	@PARAM_Storerkey     NVARCHAR(15) = ''
	, @PARAM_deliveryfrom DATETIME = ''
	, @PARAM_deliveryto   DATETIME = ''
	, @PARAM_Facility      NVARCHAR(5)  = ''
	, @PARAM_SkuGroup      NVARCHAR(10)  = ''
	, @PARAM_ShowBCode     NVARCHAR(1)  = ''
	, @PARAM_EmptyPickLOC  NVARCHAR(1)  = ''

AS
BEGIN
SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   	IF ISNULL(@PARAM_StorerKey, '') = ''
		      SET @PARAM_StorerKey = ''

      IF ISNULL(@PARAM_Facility, '') = ''
		      SET @PARAM_Facility = ''

    --IF ISNULL(@PARAM_GENERIC_EditDateFrom, '') = ''
   --   SET @PARAM_GENERIC_EditDateFrom = CONVERT(VARCHAR(10),getdate() -32 , 121)
   --IF ISNULL(@PARAM_GENERIC_EditDateTo , '') = ''
			--SET @PARAM_GENERIC_EditDateTo  = GETDATE()

		DECLARE    @Debug	BIT = 0
		       , @LogId   INT
			   , @LinkSrv   NVARCHAR(128)
               , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
               , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
               , @cParamOut NVARCHAR(4000)= ''
               , @cParamIn  NVARCHAR(4000)= '{ "PARAM_StorerKey":"'    +@PARAM_StorerKey+'"'
                                    + '"PARAM_deliveryfrom":"'+CONVERT(NVARCHAR(19),@PARAM_deliveryfrom,121)+'"'
                                    + '"PARAM_deliveryTo":"'+CONVERT(NVARCHAR(19),@PARAM_deliveryTo,121)+'"'
									+ '"PARAM_Facility":"'    +@PARAM_Facility+'"'
									+ '"PARAM_SkuGroup":"'    +@PARAM_SkuGroup+'"'
									+ '"PARAM_ShowBCode":"'    +@PARAM_ShowBCode+'"'
									+ '"PARAM_EmptyPickLOC":"'    +@PARAM_EmptyPickLOC+'"'
                                    + ' }'

EXEC BI.dspExecInit @ClientId = @PARAM_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   --, @Schema = @Schema;

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement
		 , @c_SKU NVARCHAR(20)  
         , @c_PrevSKU NVARCHAR(20)  
         , @c_FromLOC NVARCHAR(10)  
         , @c_FromID NVARCHAR(18)  
		 , @c_FromLocAisle NVARCHAR(10)
		 , @c_FromLocBay NVARCHAR(10)
		 , @c_FromLocLevel NVARCHAR(10)
         , @c_FromLOTLOCID NVARCHAR(38)  
         , @n_QTYtoReplen INT  
         , @n_QTYAvail INT  
         , @c_GetLottable01 NVARCHAR(18)  
         , @c_GetLottable02 NVARCHAR(18)  
         , @c_GetLottable03 NVARCHAR(18)  
         , @c_RetVal NVARCHAR(255)  

--ORDER DEMAND
SELECT OD.StorerKey
	, OD.Sku
	, [NoOfOrder] = COUNT(DISTINCT O.OrderKey)
	, [OrderQty] = SUM(OD.OriginalQty)
	, [ToLoc] = SPACE(10)
	, 0 AS PFAvail
	, 0 AS BulkAvail
	, 0 AS QtyToReplen
	, SKU.Descr
	, PACK.PackUOM3
	, @PARAM_ShowBCode AS ShowBCode
	, SKU.Style
	, SKU.Size
    , SKU.Skugroup
	, O.Doctype 
INTO #PMDemand
FROM BI.V_ORDERS O (NOLOCK)
JOIN BI.V_ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
JOIN BI.V_SKU SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku)
JOIN BI.V_PACK PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
WHERE O.StorerKey = @PARAM_Storerkey
AND O.[Status] in ('0')
AND O.DeliveryDate >= @PARAM_deliveryfrom
AND O.DeliveryDate <= @PARAM_deliveryto
AND O.Facility = @PARAM_Facility
AND SKU.SkuGroup = @PARAM_SkuGroup    --add in v1.1
GROUP BY OD.StorerKey
	, OD.Sku
	, SKU.Descr
	, PACK.PackUOM3
    , SKU.Style
	, SKU.Size
	, O.Doctype 
       , SKU.Skugroup
ORDER BY OD.StorerKey
, OD.Sku


--UPDATE PF LOC (PICKFACE AND HIGHBAY)
UPDATE #PMDemand
SET ToLOC = sl.LOC
FROM #PMDemand d (NOLOCK)
INNER JOIN (SELECT SL.StorerKey
				, SL.Sku
				, MIN(SL.LOC) AS LOC -- sku could have multi pick face, use min()
			FROM BI.V_SKUxLOC SL (NOLOCK)
			JOIN BI.V_LOC LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			WHERE SL.StorerKey = @PARAM_Storerkey
			AND LOC.Facility =@PARAM_Facility
			AND LOC.HOSTWHCODE = '001'
			AND((LOC.LocationType IN ('PICK') AND LOC.LocationCategory IN ('SHELVING'))
			OR (LOC.LocationType IN ('OTHER') --AND LOC.PutawayZone = 'BULK'        --COMMENT IN v1.1
			AND LOC.LocationCategory in ('RACK')))
			GROUP BY SL.StorerKey, SL.Sku) SL
ON (d.StorerKey = SL.StorerKey AND d.Sku = SL.Sku)


--UPDATE PF AVAIL
UPDATE #PMDemand
SET PFAvail = sl.PFAvail
FROM #PMDemand r (NOLOCK)
INNER JOIN (SELECT SL.StorerKey
				, SL.Sku
				, SUM(SL.Qty - SL.QtyAllocated - SL.QtyPicked) PFAvail
			FROM BI.V_SKUxLOC SL (NOLOCK)
			JOIN BI.V_LOC LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			WHERE SL.StorerKey = @PARAM_Storerkey
			AND LOC.Facility = @PARAM_Facility
			AND (SL.Qty - SL.QtyAllocated - SL.QtyPicked) > 0
			AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
			AND LOC.Status <> 'HOLD'
			AND LOC.HOSTWHCODE = '001'
			AND((LOC.LocationType IN ('PICK') AND LOC.LocationCategory IN ('SHELVING'))
			OR (LOC.LocationType IN ('OTHER') --AND LOC.PutawayZone = 'BULK'        
			AND LOC.LocationCategory in ('RACK')))
			GROUP BY SL.StorerKey, SL.Sku) SL
ON (r.StorerKey = SL.StorerKey AND r.Sku = SL.Sku)


--UPDATE BULK AVAIL
UPDATE #PMDemand
SET BulkAvail = SL.BulkAvail
FROM #PMDemand r (NOLOCK)
INNER JOIN (SELECT SL.StorerKey
				, SL.Sku
				, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS BulkAvail
			FROM BI.V_SKUxLOC SL (NOLOCK)
			JOIN BI.V_LOC LOC (NOLOCK) ON (SL.Loc = LOC.Loc)
			JOIN BI.V_LOTxLOCxID LLI (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
			JOIN BI.V_LOTATTRIBUTE L (NOLOCK) ON (L.Lot = LLI.Lot)
			WHERE SL.StorerKey =@PARAM_Storerkey
			AND LOC.Facility = @PARAM_Facility
			AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
			AND LOC.HOSTWHCODE = '001'
			AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
			AND LOC.Status <> 'HOLD'
			AND LOC.LocationType IN ('OTHER')
			AND LOC.LocationCategory in ('SHELVING','BULK')
			GROUP BY SL.StorerKey, SL.Sku) SL
ON (r.StorerKey = SL.StorerKey AND r.Sku = SL.Sku)


--UPDATE QtyToReplen (Deduct QtyAvailable from PF)
UPDATE #PMDemand
SET QtyToReplen = OrderQty - PFAvail
	WHERE (OrderQty - PFAvail) > 0



--DELETE THOSE DONOT NEED TO REPLEN
IF ISNULL(@PARAM_EmptyPickLOC, 'N') = 'N'
BEGIN
	DELETE #PMDemand
	WHERE QtyToReplen = 0 
END
ELSE
BEGIN
	DELETE #PMDemand
	WHERE QtyToReplen = 0
END


-- create blank #PMReplen          
   SELECT lli.StorerKey  
        , lli.Sku  
        , lli.Loc  
        , lli.Id  
        , lli.Qty  
        , l.Lottable01  
        , l.Lottable02  
        , l.Lottable03  
		, loc.LocAisle
		, loc.LocBay
		, loc.LocLevel
		, SPACE(5) AS QtyAvail
   INTO #PMReplen  
   FROM BI.V_LOTxLOCxID lli (NOLOCK)  
   JOIN BI.V_LOTATTRIBUTE l (NOLOCK) ON lli.Lot = l.Lot  
   JOIN BI.V_LOC LOC (NOLOCK) ON LOC.Loc = LLI.Loc 
   WHERE 1 = 0  
  
   DECLARE cur_Demand CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT StorerKey  
        , Sku  
        , QTYtoReplen  
   FROM #PMDemand  
   ORDER BY StorerKey  
          , Sku  
  
 OPEN cur_Demand  
  
   FETCH NEXT FROM cur_Demand  
   INTO @PARAM_Storerkey  
      , @c_SKU  
      , @n_QTYtoReplen  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @c_PrevSKU <> @c_SKU  
      BEGIN  
         SET @c_FromLOTLOCID = N''  
         SET @c_FromLOC = N''  
         SET @c_FromID = N''  
         SET @c_PrevSKU = @c_SKU  
      END  
  
      SELECT TOP 1 @c_FromLOTLOCID = REPLICATE(  
                                        '0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))  
                                     + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc  
                                     + lli.Id + lli.Lot  
                 , @c_FromLOC = lli.Loc  
                 , @c_FromID = lli.Id  
                 , @n_QTYAvail = SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked)  
                 , @c_GetLottable01 = l.Lottable01  
                 , @c_GetLottable02 = l.Lottable02  
                 , @c_GetLottable03 = l.Lottable03  
				 , @c_FromLocAisle = loc.LocAisle
				 , @c_FromLocBay = loc.LocBay
				 , @c_FromLocLevel = loc.LocLevel
      FROM BI.V_LOTxLOCxID lli (NOLOCK)  
      JOIN BI.V_SKUxLOC sl (NOLOCK) ON (lli.StorerKey = sl.StorerKey AND lli.Sku = sl.Sku AND lli.Loc = sl.Loc)  
      JOIN BI.V_LOC LOC (NOLOCK) ON (sl.Loc = LOC.Loc)  
      JOIN BI.V_LOTATTRIBUTE l (NOLOCK) ON (l.Lot = lli.Lot)  
      WHERE sl.StorerKey = @PARAM_Storerkey  
      AND   sl.Sku = @c_SKU  
	  AND   LOC.HOSTWHCODE = '001'
      AND   LOC.LocationCategory in ('SHELVING','BULK') 
	  AND   LOC.LocationType IN ('OTHER')
      AND   (lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0  
      AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )  
      AND   LOC.Status <> 'HOLD'  
      --AND   (l.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')  
      --AND   (l.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')  
      --AND   (l.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')  
      AND   LOC.Facility = @PARAM_Facility  
      GROUP BY lli.Loc  
             , lli.Id  
             , lli.Lot  
             , lli.Loc  
             , lli.Id  
			 , loc.loclevel
			 , loc.LocAisle
			 , loc.locbay
             , l.Lottable01  
             , l.Lottable02  
             , l.Lottable03  
      HAVING REPLICATE('0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))  
             + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc + lli.Id + lli.Lot > @c_FromLOTLOCID  
      ORDER BY REPLICATE('0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))  
               + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc + lli.Id + lli.Lot  
  
      IF @n_QTYAvail IS NULL  
         FETCH NEXT FROM cur_Demand  
         INTO @PARAM_Storerkey  
            , @c_SKU  
            , @n_QTYtoReplen  
      ELSE  
      BEGIN  
         IF @n_QTYtoReplen <= @n_QTYAvail  
         BEGIN  
            INSERT INTO #PMReplen (StorerKey, Sku, Loc, Id, LocAisle, LocBay, LocLevel, Qty, Lottable01, Lottable02, Lottable03, QtyAvail)  
            VALUES (@PARAM_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @c_FromLocAisle, @c_FromLocBay, @c_FromLocLevel, @n_QTYtoReplen, @c_GetLottable01  
                  , @c_GetLottable02, @c_GetLottable03, @n_QTYAvail)  
            FETCH NEXT FROM cur_Demand  
            INTO @PARAM_Storerkey  
               , @c_SKU  
               , @n_QTYtoReplen  
         END  
         ELSE  
         BEGIN  
            INSERT INTO #PMReplen (StorerKey, Sku, Loc, Id, LocAisle, LocBay, LocLevel, Qty, Lottable01, Lottable02, Lottable03, QtyAvail)  
            VALUES (@PARAM_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @c_FromLocAisle, @c_FromLocBay, @c_FromLocLevel, @n_QTYAvail, @c_GetLottable01, @c_GetLottable02  
                  , @c_GetLottable03, @n_QTYAvail)  
            SET @n_QTYtoReplen = @n_QTYtoReplen - @n_QTYAvail  
         END  
      END  
   END  
   CLOSE cur_Demand  
   DEALLOCATE cur_Demand  
  
   SELECT d.StorerKey  
        , d.Sku  
		, d.Style
		, d.Size
        , d.DESCR  
        , d.PackUOM3  
        , d.Skugroup
        , d.ToLoc
        , d.Doctype
		, [QtyAvail] = r.QtyAvail
        , [FromLoc] = r.Loc  
        , [FromID] = r.Id  
		, r.LocAisle
		, r.LocLevel
		, r.LocBay
        , [QtyToReplen] = r.Qty  
        , r.Lottable01  
        , r.Lottable02  
        , r.Lottable03  
        , d.ShowBCode  
        , ISNULL(@c_RetVal,'') AS Logo  
   FROM #PMDemand  d  
   LEFT JOIN #PMReplen r ON (r.StorerKey = d.StorerKey AND r.Sku = d.Sku)  
   ORDER BY R.locaisle, r.locbay, r.loclevel, r.loc, r.sku   --update v1.1
  
   IF CURSOR_STATUS('LOCAL', 'cur_Demand') IN ( 0, 1 )  
   BEGIN  
      CLOSE cur_Demand  
      DEALLOCATE cur_Demand  
   END  
  
   IF OBJECT_ID('tempdb..#PMDemand') IS NOT NULL  
      DROP TABLE #PMDemand  
  
   IF OBJECT_ID('tempdb..#PMReplen') IS NOT NULL  
      DROP TABLE #PMReplen  

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

END --procedure

GO