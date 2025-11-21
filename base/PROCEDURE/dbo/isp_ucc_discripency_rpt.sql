SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_UCC_Discripency_Rpt                             */
/* Creation Date: 26-Apr-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: UCC Discripency Report                                      */
/*                                                                      */
/* Called By: Report Module                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Discripency_Rpt] (
      @cFacility     NVARCHAR(5)
,     @cStorerKey    NVARCHAR(15)
,     @cStartLoc     NVARCHAR(10)
,     @cEndLoc       NVARCHAR(10)
,     @cStartZone    NVARCHAR(10)
,     @cEndZone      NVARCHAR(10)
 )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @tHousekeepingLOC TABLE (
   	              StorerKey      NVARCHAR(15),
   	              SKU            NVARCHAR(20),
   	              LOC            NVARCHAR(10),
   	              Lottable02     NVARCHAR(18),
   	              Lottable03     NVARCHAR(18),
   	              LLIQty         INT,	
   	              UCCQty         INT,
   	              ReasonCd       NVARCHAR(20),
   	              PackSize       INT,
                  MultiPackSize  NVARCHAR(1), 
                  MultiLot       NVARCHAR(1),
                  LooseUCCQty    INT)
   	
   DECLARE @cSKU          NVARCHAR(20),
           @cLottable02   NVARCHAR(18),
           @cLottable03   NVARCHAR(18),
           @cLOC          NVARCHAR(10), 
           @nLLIQty       INT, 
           @nUCCQty       INT, 
           @nPackSize     INT,
           @nNoOfPackSize INT,
           @nLooseUCCQty  INT    
              
   DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT sku, sl.Loc 
   FROM SKUxLOC sl WITH (NOLOCK)
   JOIN LOC l WITH (NOLOCK) ON l.Loc = sl.Loc 
   WHERE sl.LocationType NOT IN ('PICK', 'CASE')
   AND l.LocationCategory NOT IN ('GOH', 'SHELVING','PACK&HOLD')
   AND l.LOC NOT IN ('WCS01', 'WS01')
   AND l.Facility = @cFacility 
   AND sl.StorerKey = @cStorerKey
   AND l.Loc BETWEEN @cStartLoc AND @cEndLoc
   AND l.Putawayzone BETWEEN @cStartZone AND @cEndZone
   
   OPEN CUR_SKUxLOC 
   FETCH NEXT FROM CUR_SKUxLOC INTO @cSKU, @cLOC
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	DECLARE CUR_LOTQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	SELECT LA.Lottable02, LA.Lottable03, SUM(lli.Qty - lli.QtyPicked) AS Qty 
   	FROM LOTxLOCxID lli WITH (NOLOCK)
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = lli.Lot 
   	WHERE lli.StorerKey = @cStorerKey 
   	AND   lli.Sku = @cSKU 
   	AND   lli.Loc = @cLOC 
   	GROUP BY LA.Lottable02, LA.Lottable03 
   	
   	OPEN CUR_LOTQty
   	FETCH NEXT FROM CUR_LOTQty INTO @cLottable02, @cLottable03, @nLLIQty
   	
   	WHILE @@FETCH_STATUS <> -1
   	BEGIN
   		SET @nUCCQty = 0 
   		SET @nPackSize = 0
   		
   		SELECT @nUCCQty = ISNULL(SUM(Qty),0), 
   		       @nPackSize = ISNULL(MAX(UCC.Qty),0), 
   		       @nNoOfPackSize = COUNT(DISTINCT UCC.Qty)   
   		FROM   UCC WITH (NOLOCK) 
   		JOIN LOTATTRIBUTE l WITH (NOLOCK) ON l.Lot = UCC.Lot 
   		WHERE UCC.Storerkey = @cStorerKey 
   		AND   UCC.SKU = @cSKU 
   		AND   UCC.LOC = @cLOC 
   		AND   L.Lottable02 = @cLottable02 
   		AND   L.Lottable03 = @cLottable03 
   		AND   UCC.[Status] BETWEEN '1' AND '4' 
         		
   		IF @nUCCQty <> @nLLIQty 
   		BEGIN
   			IF @nNoOfPackSize = 1 AND @nPackSize > 0 
   			   SET @nLooseUCCQty = @nLLIQty % @nPackSize 
            ELSE
            	SET @nLooseUCCQty = 0 
            				   
   			INSERT INTO @tHousekeepingLOC(StorerKey, SKU, LOC, Lottable02,
   			            Lottable03, LLIQty, UCCQty, ReasonCd, PackSize, 
   			            MultiPackSize, MultiLot , LooseUCCQty)
   			VALUES (@cStorerKey, @cSKU, @cLOC, @cLottable02, @cLottable03, @nLLIQty, @nUCCQty, 
   			CASE WHEN @nUCCQty = 0 THEN 'NO UCC'
   			     ELSE 'Qty Unmatch'
   			END,
   			@nPackSize, CASE WHEN @nNoOfPackSize > 1 THEN 'Y' ELSE '' END,
   			'', 
   			@nLooseUCCQty
   			)
   		END
   		IF @nUCCQty = @nLLIQty AND @nNoOfPackSize > 1 
   		BEGIN
   			INSERT INTO @tHousekeepingLOC(StorerKey, SKU, LOC, Lottable02,
   			            Lottable03, LLIQty, UCCQty, ReasonCd, PackSize, MultiPackSize,MultiLot, LooseUCCQty )
   			VALUES (@cStorerKey, @cSKU, @cLOC, @cLottable02, @cLottable03, @nLLIQty, @nUCCQty, 
   			CAST(@nNoOfPackSize AS NVARCHAR(5)) + ' Pack Size',
   			@nPackSize, CASE WHEN @nNoOfPackSize > 1 THEN 'Y' ELSE '' END, '', 0)			
   		END   		
   		
   		BREAK
   		FETCH NEXT FROM CUR_LOTQty INTO @cLottable02, @cLottable03, @nLLIQty 
   	END
   	CLOSE CUR_LOTQty
   	DEALLOCATE CUR_LOTQty 
   	
   	FETCH NEXT FROM CUR_SKUxLOC INTO @cSKU, @cLOC 
   END
   CLOSE CUR_SKUxLOC
   DEALLOCATE CUR_SKUxLOC 
   
   IF OBJECT_ID('tempdb..#MultiLot') IS NOT NULL
      DROP TABLE #MultiLot
   
   SELECT LOC  
   INTO #MultiLot 
   FROM @tHousekeepingLOC L 
   GROUP BY LOC
   HAVING COUNT(DISTINCT StorerKey+SKU+L.Lottable02+L.Lottable03) > 1
   
   IF EXISTS(SELECT 1 FROM #MultiLot)
   BEGIN
      UPDATE H 
         SET H.MultiLot = 'Y'  
      FROM @tHousekeepingLOC H 
      JOIN #MultiLot M ON H.LOC = M.LOC   
       	
   END
   SELECT H.StorerKey, H.SKU, SKU.DESCR, SKU.Style, SKU.Color, SKU.[Size], H.LOC,
          H.Lottable02, H.Lottable03, H.LLIQty, H.UCCQty, H.ReasonCd, H.PackSize,
          H.MultiPackSize, H.MultiLot, H.LooseUCCQty 
   FROM @tHousekeepingLOC H 
   JOIN SKU WITH (NOLOCK) ON H.StorerKey = SKU.StorerKey AND H.SKU = SKU.Sku
END

GO