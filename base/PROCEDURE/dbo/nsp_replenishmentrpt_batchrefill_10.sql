SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_BatchRefill_10                   */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: ChewKP                                                      */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.4                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 3-JUNE-2016 JayLim   1.2   Adding nolock for table     (Jay01)          */
/* 05-MAR-2018 Wan01    1.3   WM - Add Functype                            */
/* 05-OCT-2018 CZTENG01 1.4   WM - Add ReplGrp                             */
/***************************************************************************/

CREATE PROC [dbo].[nsp_ReplenishmentRpt_BatchRefill_10]
   @c_zone01      NVARCHAR(10),
   @c_zone02      NVARCHAR(10),
   @c_zone03      NVARCHAR(10),
   @c_zone04      NVARCHAR(10),
   @c_zone05      NVARCHAR(10),
   @c_zone06      NVARCHAR(10),
   @c_zone07      NVARCHAR(10),
   @c_zone08      NVARCHAR(10),
   @c_zone09      NVARCHAR(10),
   @c_zone10      NVARCHAR(10),
   @c_zone11      NVARCHAR(10),
   @c_zone12      NVARCHAR(10),
   @c_storerkey   NVARCHAR(15),
   @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,  @c_Functype    NCHAR(1) = ''        --(Wan01)  
AS 
   BEGIN
      SET NOCOUNT ON 
      SET QUOTED_IDENTIFIER OFF 
      SET CONCAT_NULL_YIELDS_NULL OFF
      DECLARE @n_continue INT          /* continuation flag 
 1=Continue
 2=failed but continue processsing 
 3=failed do not continue processing 
 4=successful but skip furthur processing */,
         @n_starttcnt INT 
      SELECT   @n_starttcnt = @@TRANCOUNT
      DECLARE @b_debug INT,
         @c_Packkey NVARCHAR(10),
         @c_UOM NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
         @n_qtytaken INT,
         @n_Pallet INT, 
         @n_FullPackQty INT,
         @c_LocationType NVARCHAR(10)
                  
      SELECT   @n_continue = 1,
               @b_debug = 0

   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan01) - END    
   
   IF @c_FuncType IN ( '','G' )                                      --(Wan01)
   BEGIN                                                             --(Wan01)   
      EXEC dbo.isp_GenReplenishment
         @c_zone01 = @c_zone01,
         @c_zone02 = @c_zone02, 
         @c_zone03 = @c_zone03,
         @c_zone04 = @c_zone04,
         @c_zone05 = @c_zone05,
         @c_zone06 = @c_zone06,
         @c_zone07 = @c_zone07,
         @c_zone08 = @c_zone08,
         @c_zone09 = @c_zone09,
         @c_zone10 = @c_zone10,
         @c_zone11 = @c_zone11,
         @c_zone12 = @c_zone12,
         @c_ReplenFlag = 'WHC',
         @c_storerkey  = @c_storerkey --SOS#156197
   END                                                               --(Wan01)
   --(Wan01) - START
      
   IF @c_FuncType = 'G'                                              
   BEGIN                                                             
      GOTO QUIT_SP
   END                                                              
   --(Wan01) - END

   IF ( @c_zone02 = 'ALL' ) 
   BEGIN  
      IF (@c_Storerkey = 'ALL' OR @c_Storerkey = '')
      BEGIN
         SELECT   R.FromLoc,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  L1.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  R.ReplenishmentKey,
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),
                  LA.Lottable02,
                  LA.Lottable04
         FROM     REPLENISHMENT R WITH (NOLOCK), -- (Jay01)
                  SKU (NOLOCK),
                  LOC L1 ( NOLOCK ),
                  PACK (NOLOCK),
                  LOC L2 ( NOLOCK ),
                  LOTxLOCxID LT ( NOLOCK ),
                  LOTATTRIBUTE LA ( NOLOCK )-- Pack table added by Jacob Date Jan 03, 2001
         WHERE    SKU.Sku = R.Sku AND
                  SKU.StorerKey = R.StorerKey AND
                  L1.Loc = R.ToLoc AND
                  L2.Loc = R.FromLoc AND
                  LT.Lot = R.Lot AND
                  LT.Loc = R.FromLoc AND
                  LT.ID = R.ID AND
                  LT.LOT = LA.LOT AND
                  LT.SKU = LA.SKU AND
                  LT.STORERKEY = LA.STORERKEY AND
                  SKU.PackKey = PACK.PackKey AND
                  R.confirmed = 'N' AND
                  L1.Facility = @c_zone01
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)  
         ORDER BY L1.PutawayZone,
                  R.Priority
      END     
      ELSE
      BEGIN
         SELECT   R.FromLoc,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  L1.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  R.ReplenishmentKey,
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),
                  LA.Lottable02,
                  LA.Lottable04
         FROM     REPLENISHMENT R WITH (NOLOCK), -- (Jay01)
                  SKU (NOLOCK),
                  LOC L1 ( NOLOCK ),
                  PACK (NOLOCK),
                  LOC L2 ( NOLOCK ),
                  LOTxLOCxID LT ( NOLOCK ),
                  LOTATTRIBUTE LA ( NOLOCK )-- Pack table added by Jacob Date Jan 03, 2001
         WHERE    SKU.Sku = R.Sku AND
                  SKU.StorerKey = R.StorerKey AND
                  L1.Loc = R.ToLoc AND
                  L2.Loc = R.FromLoc AND
                  LT.Lot = R.Lot AND
                  LT.Loc = R.FromLoc AND
                  LT.ID = R.ID AND
                  LT.LOT = LA.LOT AND
                  LT.SKU = LA.SKU AND
                  LT.STORERKEY = LA.STORERKEY AND
                  SKU.PackKey = PACK.PackKey AND
                  R.confirmed = 'N' AND
                  L1.Facility = @c_zone01 AND 
                  LT.STorerkey = @c_storerkey
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)  
         ORDER BY L1.PutawayZone,
                  R.Priority
      END        
   END
   ELSE 
   BEGIN
      IF (@c_Storerkey = 'ALL' OR @c_Storerkey = '')
      BEGIN
         SELECT   R.FromLoc,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  L1.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  R.ReplenishmentKey,
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),
                  LA.Lottable02,
                  LA.Lottable04
         FROM     REPLENISHMENT R WITH (NOLOCK), -- (Jay01)
                  SKU (NOLOCK),
                  LOC L1 ( NOLOCK ),
                  LOC L2 ( NOLOCK ),
                  PACK (NOLOCK),
                  LOTxLOCxID LT ( NOLOCK ),
                  LOTATTRIBUTE LA ( NOLOCK ) -- Pack table added by Jacob Date Jan 03, 2001
         WHERE    SKU.Sku = R.Sku AND
                  SKU.StorerKey = R.StorerKey AND
                  L1.Loc = R.ToLoc AND
                  L2.Loc = R.FromLoc AND
                  LT.Lot = R.Lot AND
                  LT.Loc = R.FromLoc AND
                  LT.ID = R.ID AND
                  LT.LOT = LA.LOT AND
                  LT.SKU = LA.SKU AND
                  LT.STORERKEY = LA.STORERKEY AND
                  SKU.PackKey = PACK.PackKey AND
                  R.confirmed = 'N' AND
                  L1.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                                       @c_zone05, @c_zone06, @c_zone07,
                                       @c_zone08, @c_zone09, @c_zone10,
                                       @c_zone11, @c_zone12 ) AND
                  L1.Facility = @c_zone01 
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)  
         ORDER BY L1.PutawayZone,
                  R.Priority
      END         
      ELSE
      BEGIN
         SELECT   R.FromLoc,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  L1.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  R.ReplenishmentKey,
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),
                  LA.Lottable02,
                  LA.Lottable04
         FROM     REPLENISHMENT R WITH (NOLOCK), -- (Jay01)
                  SKU (NOLOCK),
                  LOC L1 ( NOLOCK ),
                  LOC L2 ( NOLOCK ),
                  PACK (NOLOCK),
                  LOTxLOCxID LT ( NOLOCK ),
                  LOTATTRIBUTE LA ( NOLOCK ) -- Pack table added by Jacob Date Jan 03, 2001
         WHERE    SKU.Sku = R.Sku AND
                  SKU.StorerKey = R.StorerKey AND
                  L1.Loc = R.ToLoc AND
                  L2.Loc = R.FromLoc AND
                  LT.Lot = R.Lot AND
                  LT.Loc = R.FromLoc AND
                  LT.ID = R.ID AND
                  LT.LOT = LA.LOT AND
                  LT.SKU = LA.SKU AND
                  LT.STORERKEY = LA.STORERKEY AND
                  SKU.PackKey = PACK.PackKey AND
                  R.confirmed = 'N' AND
                  L1.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                                       @c_zone05, @c_zone06, @c_zone07,
                                       @c_zone08, @c_zone09, @c_zone10,
                                       @c_zone11, @c_zone12 ) AND
                  L1.Facility = @c_zone01  AND 
                  LT.STORERKEY = @c_storerkey
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)  
         ORDER BY L1.PutawayZone,
                  R.Priority
      END  
   END
   QUIT_SP:                                                          --(Wan01)
END

GO