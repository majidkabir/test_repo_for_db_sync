SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_BatchRefill_11                */
/* Creation Date: 07-April-2010                                         */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: Replenishment Report for IDSMY C4LGMM                       */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_11]
				 @c_wavekey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   , @n_starttcnt   int

   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   @n_qtytaken int,
   @n_SerialNo int, 
	@n_MaxDPick_Loc int,
	@n_TempCount    int

   SELECT @n_continue=1, @b_debug = 0

--   IF @c_zone12 <> '' AND ISNUMERIC(@c_zone12) = 1
--      SELECT @b_debug = CAST( @c_zone12 AS int)
	CREATE TABLE #Temp_Replen  -- (ChewKP01)
   (
	Wavekey			 NVARCHAR(10) NULL , 
	FromLoc			 NVARCHAR(10) NULL, 
	Id					 NVARCHAR(20) NULL, 
	ToLoc				 NVARCHAR(10) NULL, 
	Sku				 NVARCHAR(20) NULL, 
	Qty					INT , 
	StorerKey		 NVARCHAR(20) NULL, 
	Lot				 NVARCHAR(10) NULL, 
	PackKey			 NVARCHAR(10) NULL,
	Descr				 NVARCHAR(60) NULL, 
	Priority			 NVARCHAR(5) NULL, 
	PutawayZone		 NVARCHAR(10) NULL, 
	CASECNT				INT , 
	PACKUOM1			 NVARCHAR(10) NULL, 
	PACKUOM3			 NVARCHAR(10) NULL, 
	ReplenishmentKey NVARCHAR(10) NULL, 
	QtyAvailable		INT, 
	Lottable02		 NVARCHAR(18) NULL, 
	Lottable04			datetime NULL,
	MaxDynamicPickLocation INT)
   
   IF @n_continue = 1
   BEGIN
			INSERT #TEMP_REPLEN
         SELECT R.Wavekey, R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
         SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, LA.Lottable02, LA.Lottable04 , 0
		   FROM  REPLENISHMENT R (NOLOCK) , SKU (NOLOCK), LOC L1 (NOLOCK), PACK (NOLOCK),  LOC L2 (nolock), LOTxLOCxID LT (nolock) , LOTATTRIBUTE LA (NOLOCK)-- Pack table added by Jacob Date Jan 03, 2001
         WHERE SKU.Sku = R.Sku
         AND  SKU.StorerKey = R.StorerKey
         AND  L1.Loc = R.ToLoc
         AND  L2.Loc = R.FromLoc
         AND  LT.Lot = R.Lot
         AND  LT.Loc = R.FromLoc
         AND  LT.ID = R.ID
         AND  LT.LOT = LA.LOT
         AND  LT.SKU = LA.SKU
         AND  LT.STORERKEY = LA.STORERKEY
         AND  SKU.PackKey = PACK.PackKey
         AND  R.confirmed = 'N'
         --AND  L1.Facility = @c_zone01
         --AND  (LT.Storerkey = @c_storerkey )
         AND  R.Wavekey = @c_wavekey
         GROUP BY R.Wavekey, R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
         SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, LT.Qty, LT.QtyAllocated, LT.QtyPicked, LA.Lottable02, LA.Lottable04
			, L1.PutawayZone
			ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 

			
			Select  @n_TempCount = 1 from Replenishment (NOLOCK)
			Where wavekey = @c_wavekey
			Group By  wavekey, toloc
			
			SET @n_MaxDPick_Loc = @@Rowcount 

			UPDATE #TEMP_REPLEN
			SET MaxDynamicPickLocation = @n_MaxDPick_Loc
			
			SELECT * FROM #TEMP_REPLEN
			
			DROP Table #TEMP_REPLEN

   END
   
END
-- end procedure

GO