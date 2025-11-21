SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_ReplenishmentRpt_StockStatus                   */
/* Creation Date: 01-Aug-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  NIKE China Wave Replenishment Report                       */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Input Parameters: @c_Zone1 - facility                                */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_replenishment_report02                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/
CREATE PROC [dbo].[nsp_ReplenishmentRpt_StockStatus]
            @c_zone01           NVARCHAR(10)
          , @c_zone02           NVARCHAR(10)
          , @c_zone03           NVARCHAR(10)
          , @c_zone04           NVARCHAR(10)
          , @c_zone05           NVARCHAR(10)
          , @c_zone06           NVARCHAR(10)
          , @c_zone07           NVARCHAR(10)
          , @c_zone08           NVARCHAR(10)
          , @c_zone09           NVARCHAR(10)
          , @c_zone10           NVARCHAR(10)
          , @c_zone11           NVARCHAR(10)
          , @c_zone12           NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    


   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
 ,               @n_starttcnt   int

   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   @n_qtytaken int
   SELECT @n_continue=1, @b_debug = 0

   IF @c_zone12 <> ''
      SELECT @b_debug = CAST( @c_zone12 AS int)

   DECLARE  @cStorerKey          NVARCHAR(15), 
            @cSKU                NVARCHAR(20),
            @cLOC                NVARCHAR(10),
            @nQty                int, 
            @nQtyLocationLimit   int,
            @nCaseCnt            int,
            @nPalletCnt          int,
            @nQtyAllocated       int,
            @nQtyPicked          int, 
            @nQtyNeedToReplen    int,
            @nQtyOnHold          int,
            @nQtyInBulk          int,
            @nUCCQty             int, 
            @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        DATETIME,
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @c_Lottable11        NVARCHAR(30),
            @c_Lottable12        NVARCHAR(30),
            @d_Lottable13        DATETIME,
            @d_Lottable14        DATETIME,
            @d_Lottable15        DATETIME

   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      /* Make a temp version of SKUxLOC */
      DECLARE @t_StockStatus TABLE (
               StorerKey         NVARCHAR(15), 
               SKU               NVARCHAR(20),
               LOC               NVARCHAR(10),
               Qty               int,
               QtyLocationLimit  int,
               CaseCnt           int,
               PalletCnt         int,
               QtyAllocated      int,
               QtyPicked         int, 
               QtyNeedToReplen   int,
               QtyOnHold         int,
               QtyInBulk         int,
               UCCQty            int, 
               Lottable01        NVARCHAR(18),
               Lottable02        NVARCHAR(18),
               Lottable03        NVARCHAR(18),
               Lottable04        DATETIME,
               Lottable06        NVARCHAR(30),
               Lottable07        NVARCHAR(30),
               Lottable08        NVARCHAR(30),
               Lottable09        NVARCHAR(30),
               Lottable10        NVARCHAR(30),
               Lottable11        NVARCHAR(30),
               Lottable12        NVARCHAR(30),
               Lottable13        DATETIME,
               Lottable14        DATETIME,
               Lottable15        DATETIME
      ) 
        

      IF @c_zone02 = 'ALL' 
      BEGIN 
         DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT SKUxLOC.StorerKey, SKUxLOC.SKU, SKUxLOC.LOC,          SKUxLOC.QtyLocationLimit, 
                   PACK.CaseCnt,      PACK.Pallet, SKUxLOC.QtyAllocated, SKUxLOC.QtyPicked, 
                   QtyNeedToReplen = SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated), 
                   SKUxLOC.Qty
            FROM SKUxLOC (NOLOCK)
            JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC 
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PACKKey 
            JOIN (SELECT DISTINCT SKUxLOC.STORERKEY, SKUxLOC.SKU
                  FROM   SKUxLOC (NOLOCK) 
                  JOIN   LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
                  WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0 
                  AND    SKUxLOC.LocationType NOT IN ('PICK','CASE') 
                  AND    LOC.FACILITY = @c_Zone01 
                  AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU 
         WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            -- AND  SKUxLOC.LOC = '6011035301'
      END
      ELSE
      BEGIN
         DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT SKUxLOC.StorerKey, SKUxLOC.SKU, SKUxLOC.LOC,          SKUxLOC.QtyLocationLimit, 
                   PACK.CaseCnt,      PACK.Pallet, SKUxLOC.QtyAllocated, SKUxLOC.QtyPicked, 
                   QtyNeedToReplen = SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)), 
                   SKUxLOC.Qty 
            FROM SKUxLOC (NOLOCK)
            JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC 
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PACKKey 
            JOIN (SELECT SKUxLOC.STORERKEY, SKUxLOC.SKU, SKUxLOC.LOC 
                  FROM   SKUxLOC (NOLOCK) 
                  JOIN   LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
                  WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0 
                  AND    SKUxLOC.LocationType NOT IN ('PICK','CASE') 
                  AND    LOC.FACILITY = @c_Zone01 
                  AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU 
         WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, 
                                     @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      END

      OPEN CUR_SKUxLOC 

      FETCH NEXT FROM CUR_SKUxLOC INTO  @cStorerKey, @cSKU , @cLOC , @nQtyLocationLimit, @nCaseCnt ,
            @nPalletCnt , @nQtyAllocated , @nQtyPicked, @nQtyNeedToReplen, @nQty 

      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN

         DECLARE CUR_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT 
               SUM( LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)) AS QtyOnHand,
               SUM( CASE WHEN (ID.Status = 'HOLD' OR LOT.Status = 'HOLD' OR LOC.Status = 'HOLD') OR 
                              (LOC.LocationFlag = 'HOLD' OR LOC.LocationFlag = 'DAMAGE') 
                         THEN LOTxLOCxID.Qty 
                         ELSE 0
                      END ) AS QtyHold,
               SUM(ISNULL(UCC.Qty,0)) As UCCQty,  
               LOTATTRIBUTE.Lottable01, 
               LOTATTRIBUTE.Lottable02, 
               LOTATTRIBUTE.Lottable03, 
               LOTATTRIBUTE.Lottable04,
               LOTATTRIBUTE.Lottable06,
               LOTATTRIBUTE.Lottable07,
               LOTATTRIBUTE.Lottable08,
               LOTATTRIBUTE.Lottable09,
               LOTATTRIBUTE.Lottable10,
               LOTATTRIBUTE.Lottable11,
               LOTATTRIBUTE.Lottable12,
               LOTATTRIBUTE.Lottable13,
               LOTATTRIBUTE.Lottable14,
               LOTATTRIBUTE.Lottable15
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK)     ON  (LOTxLOCxID.LOC = LOC.LOC)
         JOIN SKUXLOC (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)
                              AND (LOTxLOCxID.SKU = SKUXLOC.SKU)
                              AND (LOTxLOCxID.LOC = SKUXLOC.LOC)
                              AND (SKUXLOC.LOCATIONTYPE <> 'CASE')
                              AND (SKUXLOC.LOCATIONTYPE <> 'PICK')
         JOIN ID (NOLOCK)      ON  (LOTxLOCxID.ID = ID.ID)
         JOIN LOT(NOLOCK)      ON  (LOTxLOCxID.LOT = LOT.LOT)
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT -- SOS# 64895
         LEFT OUTER JOIN UCC ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID
                                    AND UCC.Status IN ('1','2'))
         WHERE LOTxLOCxID.StorerKey = @cStorerKey
         AND LOTxLOCxID.SKU = @cSKU
         AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
         GROUP BY LOTATTRIBUTE.Lottable01, 
                  LOTATTRIBUTE.Lottable02, 
                  LOTATTRIBUTE.Lottable03, 
                  LOTATTRIBUTE.Lottable04,
                  LOTATTRIBUTE.Lottable06,
                  LOTATTRIBUTE.Lottable07,
                  LOTATTRIBUTE.Lottable08,
                  LOTATTRIBUTE.Lottable09,
                  LOTATTRIBUTE.Lottable10,
                  LOTATTRIBUTE.Lottable11,
                  LOTATTRIBUTE.Lottable12,
                  LOTATTRIBUTE.Lottable13,
                  LOTATTRIBUTE.Lottable14,
                  LOTATTRIBUTE.Lottable15

         OPEN CUR_LOTxLOCxID

         FETCH NEXT FROM CUR_LOTxLOCxID INTO  @nQtyInBulk, @nQtyOnHold, @nUCCQty, 
                  @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                  @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            INSERT INTO @t_StockStatus VALUES (@cStorerKey        ,@cSKU               ,@cLOC 
                                              ,@nQty              ,@nQtyLocationLimit  ,@nCaseCnt         
                                              ,@nPalletCnt        ,@nQtyAllocated      ,@nQtyPicked       
                                              ,@nQtyNeedToReplen  ,@nQtyOnHold         ,@nQtyInBulk      ,@nUCCQty
                                              ,@c_Lottable01      ,@c_Lottable02       ,@c_Lottable03    ,@d_Lottable04      
                                              ,@c_Lottable06      ,@c_Lottable07       ,@c_Lottable08    ,@c_Lottable09    ,@c_Lottable10
                                              ,@c_Lottable11      ,@c_Lottable12       ,@d_Lottable13    ,@d_Lottable14    ,@d_Lottable15)

            FETCH NEXT FROM CUR_LOTxLOCxID INTO  @nQtyInBulk, @nQtyOnHold, @nUCCQty, 
                     @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                     @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                     @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
         END
         CLOSE CUR_LOTxLOCxID
         DEALLOCATE CUR_LOTxLOCxID

         FETCH NEXT FROM CUR_SKUxLOC INTO  @cStorerKey, @cSKU , @cLOC , @nQtyLocationLimit, @nCaseCnt ,
            @nPalletCnt , @nQtyAllocated , @nQtyPicked, @nQtyNeedToReplen, @nQty 

      END -- While CUR_SKUxLOC
      CLOSE CUR_SKUxLOC
      DEALLOCATE CUR_SKUxLOC 
   END

   SELECT Ss.*, SKU.DESCR 
   FROM @t_StockStatus Ss
   JOIN SKU WITH (NOLOCK) ON SS.StorerKey = SKU.StorerKey AND SS.SKU = SKU.SKU 
   ORDER BY SS.StorerKey, SS.SKU, SS.LOC

END

GO