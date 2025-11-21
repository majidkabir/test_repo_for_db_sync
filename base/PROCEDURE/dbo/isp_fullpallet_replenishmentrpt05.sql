SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_FullPallet_ReplenishmentRpt05                     */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: SOS#250413 - Unilever pallet replenishment report              */
/*                                                                         */
/* Called By: r_full_Pallet_replenishment_report05                         */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver   Purposes                                 */
/* 05-MAR-2018  Wan01       1.1   WM - Add Functype                        */
/* 05-OCT-2018  CZTENG01    1.2   WM - Add ReplGrp                         */
/***************************************************************************/

CREATE PROC [dbo].[isp_FullPallet_ReplenishmentRpt05]
       @c_zone01     NVARCHAR(10),
       @c_zone02     NVARCHAR(10),
       @c_zone03     NVARCHAR(10),
       @c_zone04     NVARCHAR(10),
       @c_zone05     NVARCHAR(10),
       @c_zone06     NVARCHAR(10),
       @c_zone07     NVARCHAR(10),
       @c_zone08     NVARCHAR(10),
       @c_zone09     NVARCHAR(10),
       @c_zone10     NVARCHAR(10),
       @c_zone11     NVARCHAR(10),
       @c_zone12     NVARCHAR(10),
       @c_storerkey  NVARCHAR(15) 
      ,@c_ReplGrp    NVARCHAR(30) = 'ALL' --(CZTENG01)
      ,@c_Functype   NCHAR(1) = ''        --(Wan01)  
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
           
     IF ISNULL(@c_Zone10,'') = '' 
        SET @c_Zone10 = 'ZZZZZZZZZZ'
     IF ISNULL(@c_Zone12,'') = '' 
        SET @c_Zone12 = 'ZZZZZZZZZZ'    

   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType = 'P'                                           
   BEGIN 
      GOTO QUIT_SP 
   END
   --(Wan01) - END            
          
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
            @c_ReplenFlag = 'FP+PARM',
            @c_storerkey  = @c_storerkey 
QUIT_SP:
   IF @c_FuncType = 'G'                                           
   BEGIN 
      RETURN
   END

   SELECT R.FromLoc,
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
          R.ReplenishmentKey,
          LA.Lottable02,
          LA.Lottable04,
          (LX.Qty - LX.QtyAllocated - LX.QtyPicked) AS QtyBal            
   From REPLENISHMENT R ( NOLOCK )
        JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey 
        JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc
        JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
        JOIN LOTATTRIBUTE LA (NOLOCK) ON R.Lot = LA.Lot
        JOIN LOTXLOCXID LX (NOLOCK) ON LX.Lot = R.Lot AND LX.Loc = R.FromLoc AND LX.ID = R.ID
   WHERE R.confirmed = 'N'
    AND R.SKU BETWEEN @c_zone09 AND @c_zone10 
    AND LOC.LocAisle BETWEEN @c_zone11 AND @c_zone12     
    AND (R.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')                      
    AND (LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                             @c_zone05, @c_zone06, @c_zone07,
                             @c_zone08) OR @c_zone02 = 'ALL')   
    AND (LOC.facility = @c_Zone01 OR @c_Zone01 = '')                 --(Wan01) 
    AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')    --(Wan01)  
   ORDER BY LOC.PutawayZone, R.Priority

END

GO