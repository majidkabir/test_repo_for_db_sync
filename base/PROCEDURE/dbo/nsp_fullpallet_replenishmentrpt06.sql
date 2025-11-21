SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nsp_FullPallet_ReplenishmentRpt06                     */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-8349 - FBR_ID_ New Full Pallet Replenishment Report v1.0   */
/*                                                                         */
/* Called By: r_full_Pallet_replenishment_report06                         */   
/*            Modified from nsp_FullPallet_ReplenishmentRpt                */
/*                                                                         */
/* PVCS Version: 1.4                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/***************************************************************************/

CREATE PROC [dbo].[nsp_FullPallet_ReplenishmentRpt06]
   @c_zone01      NVARCHAR(10),  --Facility
   @c_zone02      NVARCHAR(10),  --FromZone
   @c_zone03      NVARCHAR(10),  --ToZone
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
   @c_ReplGrp     NVARCHAR(30) = 'ALL',
   @c_Functype    NCHAR(1) = ''
     
AS 
   BEGIN
      SET NOCOUNT ON 
      SET QUOTED_IDENTIFIER OFF 
      SET CONCAT_NULL_YIELDS_NULL OFF
      DECLARE @n_continue INT          /* continuation flag 
                                 1=Continue
                                 2=failed but continue processsing 
                                 3=failed do not continue processing 
                                 4=successful but skip furthur processing */
      DECLARE @b_debug     INT
              --@c_storerkey NVARCHAR(15) -- SOS#156197
              ,@b_Success            INT           = 1
              ,@n_Err                INT           = 0               
              ,@c_ErrMsg             NVARCHAR(255) = ''     
              ,@n_RowRef             BIGINT
              ,@c_ReplenishmentKey   NVARCHAR(10)
                  
      SELECT  @n_continue = 1,
              @b_debug = 0
                       
      IF ISNULL(@c_ReplGrp,'') = ''  
      BEGIN  
         SET @c_ReplGrp = 'ALL'  
      END  
      
      IF @c_FuncType IN ( '','G' )
      BEGIN
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
			      @c_ReplenFlag = 'FP+PARM2',
			      @c_storerkey  = @c_storerkey --SOS#156197
      END

      IF @c_FuncType = 'G'
      BEGIN
         GOTO QUIT_SP  
      END

      IF(@n_continue = 1 OR @n_continue = 2)
      BEGIN
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
                     LOC.PutawayZone,
                     PACK.CASECNT,
                     PACK.PACKUOM1,
                     PACK.PACKUOM3,
                     R.ReplenishmentKey
            From     REPLENISHMENT R ( NOLOCK ),
                     SKU (NOLOCK),
                     LOC (NOLOCK),
                     PACK (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
            WHERE    SKU.Sku = R.Sku AND
                     SKU.StorerKey = R.StorerKey AND
                     LOC.Loc = R.ToLoc AND
                     SKU.PackKey = PACK.PackKey AND
                     R.Storerkey = CASE WHEN @c_Storerkey = 'ALL' THEN R.Storerkey ELSE @c_Storerkey END  AND  --(Wan01) 
                     R.confirmed = 'N'  AND
                    (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')
            ORDER BY LOC.PutawayZone,
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
                     LOC.PutawayZone,
                     PACK.CASECNT,
                     PACK.PACKUOM1,
                     PACK.PACKUOM3,
                     R.ReplenishmentKey
            From     REPLENISHMENT R ( NOLOCK ),
                     SKU (NOLOCK),
                     LOC (NOLOCK),
                     PACK (NOLOCK) -- Pack table added by Jacob. Date: Jan 03, 2001
            WHERE    SKU.Sku = R.Sku AND
                     SKU.StorerKey = R.StorerKey AND
                     LOC.Loc = R.ToLoc AND
                     SKU.PackKey = PACK.PackKey AND
                     R.Storerkey = CASE WHEN @c_Storerkey = 'ALL' THEN R.Storerkey ELSE @c_Storerkey END  AND  --(Wan01) 
                     R.confirmed = 'N' AND
                     --LOC.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,
                     --                     @c_zone05, @c_zone06, @c_zone07,
                     --                     @c_zone08, @c_zone09, @c_zone10,
                     --                     @c_zone11, @c_zone12 )   
                     LOC.putawayzone IN ( @c_zone03 )
                     AND
                    (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')
            ORDER BY LOC.PutawayZone,
                     R.FromLoc,
                     R.Sku
         END
      END
   QUIT_SP:
   END

GO