SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ReplenishToFPA                                 */
/* Creation Date: 26-Dec-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#62931 - Replensihment Report for IDSHK LOR principle    */
/*          - Replenish To Forward Pick Area (FPA)                      */
/*          - Printed together with Move Ticket & Pickslip in a         */
/*            composite report                                          */
/*                                                                      */
/* Called By: RCM - Popup Pickslip in Loadplan / WavePlan               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author  Ver. Purposes                                     */
/* 26-Jun-09  Vanessa 1.1  SOS#139316 Add Logical Location -- (Vanessa01)*/
/* 12-Nov-09  NJOW01  1.2  SOS#153022 Assign toid by Putaway Zone,      */  
/*                         Logical Location, Location and Sku sorting.  */ 
/*                         Add Lottable02 & Lottable04                  */
/* 28-Jan-2019  TLTING_ext 1.3 enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC  [dbo].[nsp_ReplenishToFPA]
             @c_Key_Type      NVARCHAR(13)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   ,               @n_starttcnt   int


   DECLARE @b_debug   int,
           @b_success int,
           @n_err     int,
           @c_errmsg  NVARCHAR(255)

   SELECT @n_continue=1, @b_debug = 0

   DECLARE @c_CurrentSKU       NVARCHAR(20), 
           @c_CurrentStorer    NVARCHAR(15),
           @c_CurrentLOC       NVARCHAR(10),
           @c_FromLOC          NVARCHAR(10), 
           @c_FromLot          NVARCHAR(10), 
           @c_FromID           NVARCHAR(18),
           @c_FromCategory     NVARCHAR(10),
           @c_ReplenishmentKey NVARCHAR(10), 
           @c_fromlot2         NVARCHAR(10),
           @c_LocPrefix        NVARCHAR(3),
           @c_MoveIDPrefix     NVARCHAR(1),
           @c_MoveIDFCounter   NVARCHAR(4),
           @c_MoveIDHCounter   NVARCHAR(4),
           @c_MoveIDBCounter   NVARCHAR(4),
           @n_MoveIDFCounter   int,
           @n_MoveIDHCounter   int,
           @n_MoveIDBCounter   int,
           @n_numberofrecs     int,
           @n_FromQty          int
      
   DECLARE @c_PickCode       NVARCHAR(10),
           @c_Packkey        NVARCHAR(10),
           @c_PackUOM1       NVARCHAR(10),
           @c_PackUOM3       NVARCHAR(10),
           @c_ToLOC          NVARCHAR(10),
           @c_MoveID         NVARCHAR(18),
           @c_Printedby      NVARCHAR(60),
           @c_Facility       NVARCHAR(5),
           @c_ExternOrderkey NVARCHAR(50),  --tlting_ext 
           @c_PickdetailKey  NVARCHAR(10),
           @n_QtyNeeded      int,
           @n_Casecnt        int,
           @n_StdCube        float

   DECLARE @c_Key            NVARCHAR(10),
           @c_Type           NVARCHAR(2)

   SELECT @c_CurrentSKU = SPACE(20), 
          @c_CurrentStorer = SPACE(15),
          @c_CurrentLOC = SPACE(10),
          @n_FromQty = 0,
          @n_numberofrecs = 0

   SELECT @c_FromLOC = SPACE(10),  
          @c_fromlot = SPACE(10), 
          @c_fromid = SPACE(18),
          @n_FromQty = 0


   SELECT @n_QtyNeeded = 0, 
          @n_Casecnt = 0

   SELECT @c_LocPrefix = '',
          @n_MoveIDFCounter = 1,
          @n_MoveIDHCounter = 1,
          @n_MoveIDBCounter = 1

   SELECT @c_Key = LEFT(@c_Key_Type, 10)
   SELECT @c_Type = RIGHT(@c_Key_Type,2)

   CREATE TABLE #TEMPOUTSTANDING  (StorerKey      NVARCHAR(15),
		                             SKU            NVARCHAR(20),
		                             QtyNeeded      int,
		                             StdCube        int,
		                             PACKUOM1       NVARCHAR(10),
		                             Casecnt        int,
		                             PACKUOM3       NVARCHAR(10),
		                             PackKey        NVARCHAR(10),
		                             LocPrefix      NVARCHAR(3),
		                             Facility       NVARCHAR(5),
                                   Loc            NVARCHAR(10),
                                   LocationCategory NVARCHAR(10),
                                   Lot            NVARCHAR(10),
                                   ID             NVARCHAR(18),
                                   PickdetailKey  NVARCHAR(10),
                                   ExternOrderkey NVARCHAR(50))   --tlting_ext  	

   CREATE TABLE #REPLENISHMENT (StorerKey      NVARCHAR(15),
                                SKU            NVARCHAR(20),
                                FromLOC        NVARCHAR(10),
                                ToLOC          NVARCHAR(10),
                                Lot            NVARCHAR(10),
	                             Id             NVARCHAR(18),
	                             Qty            int,
	                             PackKey        NVARCHAR(10),
                                ExternOrderkey NVARCHAR(50),  --tlting_ext  
                                MoveId         NVARCHAR(18))


   IF @n_continue = 1 or @n_continue = 2
   BEGIN          
    IF @c_Type = 'WP'
    BEGIN
      INSERT INTO #TEMPOUTSTANDING (StorerKey,
		                              SKU,
		                              QtyNeeded,
		                              StdCube,
		                              PACKUOM1,
		                              Casecnt,
		                              PACKUOM3,
		                              PackKey,
		                              LocPrefix,
		                              Facility,
                                    Loc,
                                    LocationCategory,
                                    Lot,
                                    ID,
                                    PickdetailKey,
                                    ExternOrderkey)	
      SELECT PICKDETAIL.Storerkey,
             PICKDETAIL.SKU,
             SUM(PICKDETAIL.Qty),
             SKU.StdCube,
             PACK.PACKUOM1,
             PACK.Casecnt,
             PACK.PACKUOM3,
             SKU.Packkey,
             dbo.fnc_RTrim(CODELKUP.Long),
             ORDERS.Facility,
             PICKDETAIL.LOC,
             LOC.LocationCategory,
             PICKDETAIL.LOT,
             PICKDETAIL.ID,
             PICKDETAIL.PickdetailKey,
             ORDERS.ExternOrderKey
      FROM WAVE (NOLOCK)
      JOIN WAVEDETAIL (NOLOCK) ON (WAVE.WaveKey = WAVEDETAIL.WaveKey)
      JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.OrderKey)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey AND 
                                   PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.Storerkey = SKU.Storerkey)
      JOIN PACK (NOLOCK) ON (PACK.Packkey = SKU.Packkey)
      JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
      JOIN CODELKUP (NOLOCK) ON (SKU.CLASS = CODELKUP.Description AND SKU.BUSR3 = CODELKUP.Short
                                 AND CODELKUP.LISTNAME = 'LORBRAND')
      WHERE ORDERS.Userdefine08 = 'Y'
      AND   WAVE.WaveKey = @c_Key
      AND   LOC.LocationCategory = 'SELECTIVE'
      GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.SKU, SKU.StdCube, PACK.PACKUOM1, PACK.Casecnt, PACK.PACKUOM3, 
               SKU.Packkey, CODELKUP.Long, ORDERS.Facility, PICKDETAIL.LOC, LOC.LocationCategory,
               PICKDETAIL.LOT, PICKDETAIL.ID, PICKDETAIL.PickdetailKey, ORDERS.ExternOrderKey
      HAVING SUM(PICKDETAIL.Qty) > 0
    END
    ELSE IF @c_Type = 'LP'
    BEGIN
      INSERT INTO #TEMPOUTSTANDING (StorerKey,
		                              SKU,
		                              QtyNeeded,
		                              StdCube,
		                              PACKUOM1,
		                              Casecnt,
		                              PACKUOM3,
		                              PackKey,
		                              LocPrefix,
		                              Facility,
                                    Loc,
                                    LocationCategory, 
                                    Lot,
                                    ID,
                                    PickdetailKey,
                                    ExternOrderkey)	
      SELECT PICKDETAIL.Storerkey,
             PICKDETAIL.SKU,
             SUM(PICKDETAIL.Qty),
             SKU.StdCube,
             PACK.PACKUOM1,
             PACK.Casecnt,
             PACK.PACKUOM3,
             SKU.Packkey,
             dbo.fnc_RTrim(CODELKUP.Long),
             ORDERS.Facility,
             PICKDETAIL.LOC,
             LOC.LocationCategory,
             PICKDETAIL.LOT,
             PICKDETAIL.ID,
             PICKDETAIL.PickdetailKey,
             ORDERS.ExternOrderKey
      FROM LOADPLAN (NOLOCK)
      JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
      JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.OrderKey)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey AND 
                                   PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.Storerkey = SKU.Storerkey)
      JOIN PACK (NOLOCK) ON (PACK.Packkey = SKU.Packkey)
      JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
      JOIN CODELKUP (NOLOCK) ON (SKU.CLASS = CODELKUP.Description AND SKU.BUSR3 = CODELKUP.Short
                                 AND CODELKUP.LISTNAME = 'LORBRAND')
      WHERE LOADPLAN.Loadkey = @c_Key
      AND   LOC.LocationCategory = 'SELECTIVE'
      GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.SKU, SKU.StdCube, PACK.PACKUOM1, PACK.Casecnt, PACK.PACKUOM3, 
               SKU.Packkey, CODELKUP.Long, ORDERS.Facility, PICKDETAIL.LOC, LOC.LocationCategory,
               PICKDETAIL.LOT, PICKDETAIL.ID, PICKDETAIL.PickdetailKey, ORDERS.ExternOrderKey
      HAVING SUM(PICKDETAIL.Qty) > 0 
    END

      IF @b_debug = 1
      BEGIN
         SELECT '#TEMPOUTSTANDING table'
         SELECT * FROM #TEMPOUTSTANDING (NOLOCK)
      END


     	DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	   SELECT a.Storerkey, a.SKU, a.QtyNeeded, a.StdCube, a.Packkey, a.LocPrefix, a.LOC, 
	          a.LocationCategory, a.LOT, a.ID, a.ExternOrderkey, a.PickdetailKey
      FROM #TEMPOUTSTANDING a
      JOIN LOC L2 (NOLOCK) ON (a.Loc = L2.Loc)
      ORDER BY L2.PutawayZone, L2.LogicalLocation, L2.Loc, a.Sku  --NJOW01
      --Order By Storerkey, SKU
	   
		OPEN C_CUR
		
		FETCH NEXT FROM C_CUR INTO @c_CurrentStorer, @c_CurrentSKU, @n_QtyNeeded, @n_StdCube, @c_Packkey, @c_LocPrefix, @c_FromLOC, @c_FromCategory, @c_FromLot, @c_FromID, @c_ExternOrderkey, @c_PickdetailKey
		
		WHILE @@FETCH_STATUS <> -1 
		BEGIN

         IF @b_debug = 1
         BEGIN
            Print 'SKU: '+ @c_CurrentSKU + ' Qty: ' + cast(@n_QtyNeeded as NVARCHAR(10))
            SELECT '@n_StdCube', @n_StdCube, '@c_Packkey', @c_Packkey, '@c_ExternOrderkey', @c_ExternOrderkey
            SELECT '@c_FromLOC', @c_FromLOC, '@c_FromCategory', @c_FromCategory, '@c_FromLot', @c_FromLot, '@c_FromID', @c_FromID
         END

         SELECT @c_ToLOC = @c_LocPrefix + '_F000' -- location to be determined
         SELECT @c_MoveIDPrefix = 'F'

--  Comment this part now, only base on CBM calculation during Phase 2 (Start)
--          IF @n_StdCube >= 0.500 -- Pallet Move ID
--          BEGIN
--            SELECT @c_ToLOC = @c_LocPrefix + '_F000' -- location to be determined
--            SELECT @c_MoveIDPrefix = 'F'
--          END
--          ELSE IF @n_StdCube >= 0.25 AND @n_StdCube < 0.500 -- Half Pallet Move ID
--          BEGIN
--            SELECT @c_ToLOC = @c_LocPrefix + '_H000' -- location to be determined
--            SELECT @c_MoveIDPrefix = 'H'
--          END
--          ELSE IF @n_StdCube < 0.25 -- Less Than Carton Move ID
--          BEGIN
--            SELECT @c_ToLOC = @c_LocPrefix + '_B000' -- location to be determined
--            SELECT @c_MoveIDPrefix = 'B'
--          END
--  Comment this part now, only base on CBM calculation during Phase 2 (End)
	
         IF NOT EXISTS (SELECT 1 FROM #REPLENISHMENT (NOLOCK) WHERE STORERKEY = @c_CurrentStorer AND SKU = @c_CurrentSKU)
         BEGIN

					SELECT @c_MoveID = @c_LocPrefix 
	                             + '_' 
	                             + RIGHT(dbo.fnc_RTrim(CONVERT(CHAR, DATEPART(YEAR, getdate()))),2)
				                    + RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(MONTH, getdate()))), 2)
				                    + RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(DAY, getdate()))), 2) 
	                             + '_' + @c_MoveIDPrefix 
	                             + CASE WHEN @c_MoveIDPrefix = 'F' THEN RIGHT(dbo.fnc_RTrim(REPLICATE(0, 4) + CONVERT(CHAR, @n_MoveIDFCounter)), 4)
	                                    WHEN @c_MoveIDPrefix = 'H' THEN RIGHT(dbo.fnc_RTrim(REPLICATE(0, 4) + CONVERT(CHAR, @n_MoveIDHCounter)), 4)
	                                    WHEN @c_MoveIDPrefix = 'B' THEN RIGHT(dbo.fnc_RTrim(REPLICATE(0, 4) + CONVERT(CHAR, @n_MoveIDBCounter)), 4)
	                               END 
	                                    
	            IF @c_MoveIDPrefix = 'F'
	            BEGIN
	              SELECT @n_MoveIDFCounter = @n_MoveIDFCounter + 1
	            END
	            ELSE IF @c_MoveIDPrefix = 'H'
	            BEGIN
	              SELECT @n_MoveIDHCounter = @n_MoveIDHCounter + 1
	            END
	            ELSE IF @c_MoveIDPrefix = 'B'
	            BEGIN
	              SELECT @n_MoveIDBCounter = @n_MoveIDBCounter + 1
	            END

            END 
            ELSE
            BEGIN
                  SELECT DISTINCT @c_MoveID = MoveId
                  FROM #REPLENISHMENT (NOLOCK)
                  WHERE STORERKEY = @c_CurrentStorer 
                  AND SKU = @c_CurrentSKU
            END
                       
            IF @b_debug = 1
            BEGIN
               Print '@n_FromQty: ' + cast(@n_FromQty as NVARCHAR(10)) + ' @c_Packkey: ' + @c_Packkey
               Print '@n_StdCube: ' + cast(@n_StdCube as NVARCHAR(10)) + ' @c_ToLOC: ' + @c_ToLOC  + '@c_MoveID: ' + @c_MoveID
            END

            INSERT #REPLENISHMENT (
            StorerKey,
            SKU,
            FromLOC,
            ToLOC,
            Lot,
            Id,
            Qty,
            PackKey,
            ExternOrderkey,
            MoveId)
            VALUES (
            @c_CurrentStorer,
            @c_CurrentSKU,
            @c_FromLOC,
            @c_ToLOC,
            @c_fromlot,
            @c_fromid,
            @n_QtyNeeded,
            @c_Packkey,
            @c_ExternOrderkey,
            @c_MoveID)
	

            IF @b_debug = 1
            BEGIN
               SELECT @c_CurrentSKU ' SKU', @c_ToLOC ' LOC'
               SELECT @n_QtyNeeded ' @n_QtyNeeded', @c_fromlot ' from lot', @c_fromid ' from lot'
            END

            UPDATE PICKDETAIL WITH (ROWLOCK)
              SET ToLoc = @c_ToLOC,
                  DROPID = @c_MoveID,
                  Trafficcop = NULL
            WHERE PickdetailKey = @c_PickdetailKey

	   FETCH NEXT FROM C_CUR INTO @c_CurrentStorer, @c_CurrentSKU, @n_QtyNeeded, @n_StdCube, @c_Packkey, @c_LocPrefix, @c_FromLOC, @c_FromCategory, @c_FromLot, @c_FromID, @c_ExternOrderkey, @c_PickdetailKey
	 END -- While detail
	 CLOSE C_CUR
	 DEALLOCATE C_CUR
  END -- If Continue = 1

  IF @n_continue=3  -- Error Occured - Process AND Return
  BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishToFPA'
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
      -- RETURN
   END

   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, SUM(R.Qty) as TotalQty, R.StorerKey, R.PackKey,
          SKU.Descr, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, 
          SKU.BUSR3, IsNULL(SKU.AltSku, '') as AltSku, suser_sname(), L2.Facility, R.MoveId, L2.LogicalLocation, -- (Vanessa01)
          @c_Key, LA.Lottable02, LA.Lottable04  --NJOW01
   FROM  #REPLENISHMENT R (NOLOCK)
   JOIN  SKU (NOLOCK) ON (SKU.SKU = R.SKU AND SKU.Storerkey = R.Storerkey)
--   JOIN  LOC L1 (NOLOCK) ON (L1.Loc = R.ToLoc)
   JOIN  LOC L2 (NOLOCK) ON (L2.Loc = R.FromLoc)
   JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN  LOTATTRIBUTE LA (NOLOCK) ON (R.Lot = LA.Lot) --NJOW01
   GROUP BY R.FromLoc, R.Id, R.ToLoc, R.Sku, R.StorerKey, R.PackKey,
            SKU.Descr, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, 
            SKU.BUSR3, SKU.AltSku, L2.Facility, R.MoveId, L2.LogicalLocation, -- (Vanessa01)
            LA.Lottable02, LA.Lottable04
   ORDER BY R.FromLoc, R.SKU 

   DROP TABLE #REPLENISHMENT

END -- End of Proc

GO