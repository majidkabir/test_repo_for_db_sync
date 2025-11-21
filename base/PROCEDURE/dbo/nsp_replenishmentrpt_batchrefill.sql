SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_BatchRefill                      */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By: r_full_Pallet_replenishment_report02                         */
/*                                                                         */
/* PVCS Version: 1.6                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 23-Jun-2009  Leong      1.1   SOS#140132 - Include Facility filter      */
/* 02-Nov-2009  Shong      1.2   New Concept Introduce. Will be calling    */
/*                               Sub-SP isp_GenReplenishment               */
/* 14-Dec-2009  Leong      1.3   SOS#156197 - Pass In StorerKey            */
/* 07-Feb-2014  YTWan      1.4   SOS#301047 - TH-Requeset Default          */
/*                               StorerInventory Replenishment (Wan01)     */
/* 05-MAR-2018  Wan02      1.5   WM - Add Functype                         */
/* 05-OCT-2018  CZTENG01   1.6   WM - Add ReplGrp                         */
/***************************************************************************/

CREATE PROC [dbo].[nsp_ReplenishmentRpt_BatchRefill]
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
   @c_zone12      NVARCHAR(10)
,  @c_storerkey   NVARCHAR(15) = ''         --(Wan01)
,  @c_ReplGrp     NVARCHAR(30) = 'ALL'      --(CZTENG01)
,  @c_Functype    NCHAR(1) = ''             --(Wan02)
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue INT          
   /* continuation flag 
   1=Continue
   2=failed but continue processsing 
   3=failed do not continue processing 
   4=successful but skip furthur processing */
   DECLARE @n_starttcnt INT 
   SELECT   @n_starttcnt = @@TRANCOUNT
      
   DECLARE @b_debug        INT,
            @c_Packkey      NVARCHAR(10),
            @c_UOM          NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
            @n_qtytaken     INT,
            @n_Pallet       INT, 
            @n_FullPackQty  INT,
            @c_LocationType NVARCHAR(10) 
            --@c_storerkey    NVARCHAR(15) -- SOS#156197        --(Wan01)
                  
   SELECT  @n_continue = 1,
            @b_debug = 0
            
   --(Wan02) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan02) - END                       

   IF @c_FuncType IN ( '','G' )                                      --(Wan02)
   BEGIN                                                             --(Wan02)   
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
         @c_ReplenFlag = 'W',
--         @c_storerkey  = '' --SOS#156197
         @c_storerkey = @c_storerkey                              --(Wan01)

      IF @c_FuncType = 'G'
      BEGIN
         GOTO QUIT_SP
      END
   END                                                              
   --(Wan02) - END

   IF ( @c_zone02 = 'ALL' ) 
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
      FROM     REPLENISHMENT R WITH (NOLOCK),
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
               R.Storerkey = CASE WHEN @c_Storerkey = 'ALL' THEN R.Storerkey ELSE @c_Storerkey END  AND  --(Wan01) 
               R.confirmed = 'N' AND
               L1.Facility = @c_zone01
          AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --(Wan02)
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
      FROM     REPLENISHMENT R WITH (NOLOCK),
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
               R.Storerkey = CASE WHEN @c_Storerkey = 'ALL' THEN R.Storerkey ELSE @c_Storerkey END  AND   --(Wan01)
               R.confirmed = 'N' AND
               L1.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                                    @c_zone05, @c_zone06, @c_zone07,
                                    @c_zone08, @c_zone09, @c_zone10,
                                    @c_zone11, @c_zone12 ) AND
               L1.Facility = @c_zone01
          AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --(Wan02)
      ORDER BY L1.PutawayZone,
               R.Priority
   END
   QUIT_SP:                                                                --(Wan02)
END

GO