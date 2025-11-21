SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nsp_FullPallet_ReplenishmentRpt02                     */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By: r_full_Pallet_replenishment_report02                         */
/*                                                                         */
/* PVCS Version: 1.6                                                      */
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
/* 02-Nov-2009  ChewKP     1.2   SOS#152090 - Add in Lottable02, Lottable04*/
/*                               Casecnt for Replenishment Report          */
/* 14-Dec-2009  Leong      1.3   SOS#156197 - Pass In StorerKey            */
/* 05-MAR-2018  Wan01      1.4   WM - Add Functype                         */
/* 05-OCT-2018  CZTENG01   1.5   WM - Add ReplGrp                          */
/* 09-Mar-2022  WLChooi    1.6   DevOps Combine Script                     */
/* 09-Mar-2022  WLChooi    1.6   WMS-19114 Add config to filter Lottable03 */
/*                               (WL01)                                    */
/*06-Dec-2022   CHONGCS    1.7   WMS-15511 revised report logic (CS01)     */
/***************************************************************************/

CREATE   PROC [dbo].[nsp_FullPallet_ReplenishmentRpt02]
   @c_zone01    NVARCHAR(10),
   @c_zone02    NVARCHAR(10),
   @c_zone03    NVARCHAR(10),
   @c_zone04    NVARCHAR(10),
   @c_zone05    NVARCHAR(10),
   @c_zone06    NVARCHAR(10),
   @c_zone07    NVARCHAR(10),
   @c_zone08    NVARCHAR(10),
   @c_zone09    NVARCHAR(10),
   @c_zone10    NVARCHAR(10),
   @c_zone11    NVARCHAR(10),
   @c_zone12    NVARCHAR(10),
   @c_storerkey NVARCHAR(15),
   @c_ReplGrp  NVARCHAR(30) = ''    --(CZTENG01)
,  @c_Functype NCHAR(1) = ''        --(Wan01)  
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

   DECLARE @b_debug        INT,
            @c_Packkey      NVARCHAR(10),
            @c_UOM          NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
            @n_Pallet       INT,
            @n_FullPackQty  INT,
            @c_LocationType NVARCHAR(10)

   SELECT @n_continue = 1,
            @b_debug = 0
            
   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan01) - END            

   IF @c_FuncType IN ('', 'G')                                       --(Wan01)
   BEGIN                                                             --(Wan01)
      EXEC dbo.isp_GenReplenishment
         @c_zone01     = @c_zone01,
         @c_zone02     = @c_zone02,
         @c_zone03     = @c_zone03,
         @c_zone04     = @c_zone04,
         @c_zone05     = @c_zone05,
         @c_zone06     = @c_zone06,
         @c_zone07     = @c_zone07,
         @c_zone08     = @c_zone08,
         @c_zone09     = @c_zone09,
         @c_zone10     = @c_zone10,
         @c_zone11     = @c_zone11,
         @c_zone12     = @c_zone12,
         @c_ReplenFlag = 'PP',
         @c_storerkey  = @c_storerkey -- SOS#156197
   
      IF @c_FuncType = 'G'
      BEGIN
         GOTO QUIT_SP         
      END
   END                                                               
   --(Wan01) - END

   IF ( @c_zone02 = 'ALL' )
   BEGIN
      IF ( @c_storerkey = 'ALL' )
      BEGIN
         SELECT   R.FromLOC,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  LOC.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  ReplenishmentKey,
                  LA.Lottable02,  -- SOS#152090
                  LA.Lottable04,  -- SOS#152090
                  LA.Lottable03,  --CS01
                  @c_ReplGrp as ReplenGrp  --CS01            
         --WL01 S
         FROM REPLENISHMENT R (NOLOCK)
         JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
         JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc
         JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = R.LOT
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'NoFilterLott03'
                                       AND CL.Long = 'r_full_pallet_replenishment_report02' AND CL.Storerkey = R.Storerkey
            --CS01 S
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME='DSGLOC' AND CL1.Storerkey = R.Storerkey 
                                           AND CL1.code2=CASE WHEN ISNULL(@c_ReplGrp,'') <> '' THEN @c_ReplGrp ELSE CL1.code2 END
                                           AND CL1.code = LA.Lottable03
            --CS01 E
         WHERE R.confirmed = 'N'
         AND LOC.Facility = @c_zone01
         --AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --CS01
        AND (R.Replenishmentgroup = CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN @c_ReplGrp ELSE R.Replenishmentgroup END  OR @c_ReplGrp = 'ALL')   --CS01
         AND 1 = (CASE WHEN ISNULL(CL.Short,'N') = 'Y' AND LA.Lottable03 NOT IN (SELECT DISTINCT TRIM(ColValue) FROM dbo.fnc_DelimSplit(',', CL.Notes) FDS) THEN 1 
                       WHEN ISNULL(CL.Short,'N') = 'N' THEN 1
                  ELSE 0 END )
         --CS01 S
          AND LOC.Floor = CASE WHEN @c_ReplGrp = 'GT' THEN 'GT'          
                                WHEN @c_ReplGrp = 'MT' THEN 'MT' 
                         ELSE LOC.Floor END  
         AND LA.Lottable03 =  CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN LA.Lottable03 ELSE CL1.Code END
        --CS01 E
         --FROM     REPLENISHMENT R ( NOLOCK ),
         --         SKU (NOLOCK),
         --         LOC (NOLOCK),
         --         PACK (NOLOCK), -- Pack table added by Jacob Date Jan 03, 2001
         --         LOTATTRIBUTE LA (NOLOCK) -- SOS#152090
         --WHERE    SKU.Sku = R.Sku AND
         --         SKU.StorerKey = R.StorerKey AND
         --         LOC.Loc = R.ToLoc AND
         --         SKU.PackKey = PACK.PackKey AND
         --         R.confirmed = 'N' AND
         --         LOC.Facility = @c_zone01 AND -- SOS#140132
         --         LA.LOT = R.LOT -- SOS#152090
         --    AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --(Wan01)
         --WL01 E
         ORDER BY LOC.PutawayZone,
                  R.Priority
      END
      ELSE
      BEGIN
            SELECT   R.FromLOC,
                     R.Id,
                     R.ToLoc,
                     R.Sku,
                     R.Qty,
                     R.StorerKey,
                     R.Lot,
                     R.PackKey,
                     SKU.Descr,
                     R.Priority,
                     LOC.PutawayZone,
                     PACK.CASECNT,
                     PACK.PACKUOM1,
                     PACK.PACKUOM3,
                     ReplenishmentKey,
                     LA.Lottable02,  -- SOS#152090
                     LA.Lottable04,  -- SOS#152090
                     LA.Lottable03,  --CS01
                     @c_ReplGrp as ReplenGrp  --CS01 
            --WL01 S
            FROM REPLENISHMENT R (NOLOCK)
            JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
            JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = R.LOT
            LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'NoFilterLott03'
                                          AND CL.Long = 'r_full_pallet_replenishment_report02' AND CL.Storerkey = R.Storerkey
            --CS01 S
            LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME='DSGLOC' AND CL1.Storerkey = R.Storerkey 
                                           AND CL1.code2=CASE WHEN ISNULL(@c_ReplGrp,'') <> '' THEN @c_ReplGrp ELSE CL1.code2 END
                                           AND CL1.code = LA.Lottable03
            --CS01 E
            WHERE R.confirmed = 'N'
            AND LOC.Facility = @c_zone01
            AND R.Storerkey = @c_storerkey
           --AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --CS01
            AND (R.Replenishmentgroup = CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN @c_ReplGrp ELSE R.Replenishmentgroup END  OR @c_ReplGrp = 'ALL')   --CS01
            AND 1 = (CASE WHEN ISNULL(CL.Short,'N') = 'Y' AND LA.Lottable03 NOT IN (SELECT DISTINCT TRIM(ColValue) FROM dbo.fnc_DelimSplit(',', CL.Notes) FDS) THEN 1 
                          WHEN ISNULL(CL.Short,'N') = 'N' THEN 1
                     ELSE 0 END )
           --CS01 S
          AND LOC.Floor = CASE WHEN @c_ReplGrp = 'GT' THEN 'GT'          
                                WHEN @c_ReplGrp = 'MT' THEN 'MT' 
                         ELSE LOC.Floor END  
          AND LA.Lottable03 =  CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN LA.Lottable03 ELSE CL1.Code END
          --CS01 E
            --FROM     REPLENISHMENT R ( NOLOCK ),
            --         SKU (NOLOCK),
            --         LOC (NOLOCK),
            --         PACK (NOLOCK), -- Pack table added by Jacob Date Jan 03, 2001
            --         LOTATTRIBUTE LA (NOLOCK) -- SOS#152090
            --WHERE    SKU.Sku = R.Sku AND
            --         SKU.StorerKey = R.StorerKey AND
            --         LOC.Loc = R.ToLoc AND
            --         SKU.PackKey = PACK.PackKey AND
            --         R.confirmed = 'N' AND
            --         LOC.Facility = @c_zone01 AND -- SOS#140132
            --         R.Storerkey = @c_storerkey AND
            --         LA.LOT = R.LOT -- SOS#152090
            --    AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --(Wan01)
            --WL01 E
            ORDER BY LOC.PutawayZone,
                     R.Priority
      END -- ( @c_storerkey = 'ALL' )
   END -- ( @c_zone02 = 'ALL' )

   IF ( @c_zone02 <> 'ALL'  )
   BEGIN
      IF ( @c_storerkey = 'ALL' )
      BEGIN
         SELECT   R.FromLOC,
                  R.Id,
                  R.ToLoc,
                  R.Sku,
                  R.Qty as Qty,
                  R.StorerKey,
                  R.Lot,
                  R.PackKey,
                  SKU.Descr,
                  R.Priority,
                  LOC.PutawayZone,
                  PACK.CASECNT,
                  PACK.PACKUOM1,
                  PACK.PACKUOM3,
                  ReplenishmentKey,
                  LA.Lottable02,  -- SOS#152090
                  LA.Lottable04,  -- SOS#152090
                  LA.Lottable03,  --CS01
                  @c_ReplGrp as ReplenGrp  --CS01 
         --WL01 S
         FROM REPLENISHMENT R (NOLOCK)
         JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
         JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc
         JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = R.LOT
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'NoFilterLott03'
                                       AND CL.Long = 'r_full_pallet_replenishment_report02' AND CL.Storerkey = R.Storerkey
         --CS01 S
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME='DSGLOC' AND CL1.Storerkey = R.Storerkey 
                                           AND CL1.code2=CASE WHEN ISNULL(@c_ReplGrp,'') <> '' THEN @c_ReplGrp ELSE CL1.code2 END
                                           AND CL1.code = LA.Lottable03
         --CS01 E
         WHERE R.confirmed = 'N'
         AND LOC.Facility = @c_zone01
         AND LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                                  @c_zone05, @c_zone06, @c_zone07,
                                  @c_zone08, @c_zone09, @c_zone10,
                                  @c_zone11, @c_zone12 )
         --AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --CS01
         AND (R.Replenishmentgroup = CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN @c_ReplGrp ELSE R.Replenishmentgroup END  OR @c_ReplGrp = 'ALL')   --CS01
         AND 1 = (CASE WHEN ISNULL(CL.Short,'N') = 'Y' AND LA.Lottable03 NOT IN (SELECT DISTINCT TRIM(ColValue) FROM dbo.fnc_DelimSplit(',', CL.Notes) FDS) THEN 1 
                       WHEN ISNULL(CL.Short,'N') = 'N' THEN 1
                  ELSE 0 END )
         --CS01 S
          AND LOC.Floor = CASE WHEN @c_ReplGrp = 'GT' THEN 'GT'          
                                WHEN @c_ReplGrp = 'MT' THEN 'MT' 
                         ELSE LOC.Floor END  
          AND LA.Lottable03 =  CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN LA.Lottable03 ELSE CL1.Code END
         --CS01 E
         --FROM     REPLENISHMENT R ( NOLOCK ),
         --         SKU (NOLOCK),
         --         LOC (NOLOCK),
         --         PACK (NOLOCK), -- Pack table added by Jacob. Date: Jan 03, 2001
         --         LOTATTRIBUTE LA (NOLOCK) -- SOS#152090
         --WHERE    SKU.Sku = R.Sku AND
         --         SKU.StorerKey = R.StorerKey AND
         --         LOC.Loc = R.ToLoc AND
         --         SKU.PackKey = PACK.PackKey AND
         --         R.confirmed = 'N' AND
         --         LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
         --                              @c_zone05, @c_zone06, @c_zone07,
         --                              @c_zone08, @c_zone09, @c_zone10,
         --                              @c_zone11, @c_zone12 ) AND
         --         LOC.Facility = @c_zone01 AND -- SOS#140132
         --         LA.LOT = R.LOT -- SOS#152090
         --    AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)
         --WL01 E
         ORDER BY LOC.PutawayZone,
                  R.FromLOC,
                  R.Sku
      END
      ELSE
      BEGIN
            SELECT   R.FromLOC,
                     R.Id,
                     R.ToLoc,
                     R.Sku,
                     R.Qty as Qty,
                     R.StorerKey,
                     R.Lot,
                     R.PackKey,
                     SKU.Descr,
                     R.Priority,
                     LOC.PutawayZone,
                     PACK.CASECNT,
                     PACK.PACKUOM1,
                     PACK.PACKUOM3,
                     ReplenishmentKey,
                     LA.Lottable02,  -- SOS#152090
                     LA.Lottable04,   -- SOS#152090
                     LA.Lottable03,  --CS01
                     @c_ReplGrp as ReplenGrp  --CS01 
            --WL01 S
            FROM REPLENISHMENT R (NOLOCK)
            JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
            JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = R.LOT
            LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'NoFilterLott03'
                                          AND CL.Long = 'r_full_pallet_replenishment_report02' AND CL.Storerkey = R.Storerkey
            --CS01 S
            LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME='DSGLOC' AND CL1.Storerkey = R.Storerkey 
                                           AND CL1.code2=CASE WHEN ISNULL(@c_ReplGrp,'') <> '' THEN @c_ReplGrp ELSE CL1.code2 END
                                           AND CL1.code = LA.Lottable03
            --CS01 E
            WHERE R.confirmed = 'N'
            AND LOC.Facility = @c_zone01
            AND LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                                     @c_zone05, @c_zone06, @c_zone07,
                                     @c_zone08, @c_zone09, @c_zone10,
                                     @c_zone11, @c_zone12 )
            AND R.Storerkey = @c_storerkey
           --AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --CS01
            AND (R.Replenishmentgroup = CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN @c_ReplGrp ELSE R.Replenishmentgroup END  OR @c_ReplGrp = 'ALL')   --CS01
            AND 1 = (CASE WHEN ISNULL(CL.Short,'N') = 'Y' AND LA.Lottable03 NOT IN (SELECT DISTINCT TRIM(ColValue) FROM dbo.fnc_DelimSplit(',', CL.Notes) FDS) THEN 1 
                          WHEN ISNULL(CL.Short,'N') = 'N' THEN 1
                     ELSE 0 END )
           --CS01 S
            AND LOC.Floor = CASE WHEN @c_ReplGrp = 'GT' THEN 'GT'          
                                WHEN @c_ReplGrp = 'MT' THEN 'MT' 
                         ELSE LOC.Floor END  
          AND LA.Lottable03 =  CASE WHEN @c_ReplGrp NOT IN ('GT','MT') THEN LA.Lottable03 ELSE CL1.Code END
          --CS01 E
            --FROM     REPLENISHMENT R ( NOLOCK ),
            --         SKU (NOLOCK),
            --         LOC (NOLOCK),
            --         PACK (NOLOCK), -- Pack table added by Jacob. Date: Jan 03, 2001
            --         LOTATTRIBUTE LA (NOLOCK) -- SOS#152090
            --WHERE    SKU.Sku = R.Sku AND
            --         SKU.StorerKey = R.StorerKey AND
            --         LOC.Loc = R.ToLoc AND
            --         SKU.PackKey = PACK.PackKey AND
            --         R.confirmed = 'N' AND
            --         LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
            --                              @c_zone05, @c_zone06, @c_zone07,
            --                              @c_zone08, @c_zone09, @c_zone10,
            --                              @c_zone11, @c_zone12 ) AND
            --         LOC.Facility = @c_zone01 AND -- SOS#140132
            --         R.Storerkey = @c_storerkey AND
            --         LA.LOT = R.LOT -- SOS#152090
            --    AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') --(Wan01)

            ORDER BY LOC.PutawayZone,
                     R.FromLOC,
                     R.Sku
      END -- ( @c_storerkey = 'ALL' )
   END -- ( @c_zone02 <> 'ALL'  )
   QUIT_SP:                                                                   --(Wan01)
END

GO