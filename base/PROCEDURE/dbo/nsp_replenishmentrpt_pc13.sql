SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_PC13                             */
/* Creation Date: 15-Dec-2010                                              */
/* Copyright: IDS                                                          */
/* Written by: NJOW                                                        */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 14-Jan-2011 NJOW01   1.0   197852-Change to use 'W' for @c_ReplenFlag   */
/*                            param                                        */
/* 01-MAR-2012 YTWan    1.1   SOS#237041: Add Lottable04 to report.        */
/*                               (Wan01)                                   */
/* 05-MAR-2018 Wan02    1.2   WM - Add Functype                            */
/* 05-OCT-2018 CZTENG01 1.3   WM - Add ReplGrp                             */
/***************************************************************************/

CREATE PROC [dbo].[nsp_ReplenishmentRpt_PC13]
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
,  @c_Functype    NCHAR(1) = ''        --(Wan02) 
AS 
BEGIN
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue INT          /* continuation flag 
   1=Continue
   2=failed but continue processsing 
   3=failed do not continue processing 
   4=successful but skip furthur processing */,
           @n_starttcnt INT 
      
   SELECT   @n_starttcnt = @@TRANCOUNT
   SELECT   @n_continue = 1

   --(Wan02) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
        
   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END
   --(Wan02) - END

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
      @c_storerkey  = @c_storerkey 

   --(Wan02) - START
   QUIT_SP:
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN
      END
   --(Wan02) - END


      SELECT   R.FromLoc,
               R.ToLoc,
               R.Sku,
               SUM(R.Qty) AS Qty,
               R.StorerKey,
               R.PackKey,
               SKU.Descr,
               L1.PutawayZone,
               PACK.CaseCnt,
               (SELECT SL.Qty - SL.QtyAllocated - SL.QtyPicked 
                FROM SKUxLOC SL (NOLOCK) WHERE SL.Storerkey = R.Storerkey AND SL.Sku = R.Sku
                                             AND SL.Loc = R.FromLoc) - SUM(R.Qty) AS QtyBal,
               L1.Facility,
               L1.LogicalLocation,
               --(Wan01) - START 
               LA.Lottable04
               --(Wan01) - END
      FROM     REPLENISHMENT R (NOLOCK)
               JOIN SKU (NOLOCK) ON (R.Storerkey = SKU.Storerkey AND R.SKU = SKU.SKU)
               JOIN LOC L1 (NOLOCK) ON (L1.Loc = R.FromLoc)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               --(Wan01) - START 
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (R.Lot = LA.Lot)
               --(Wan01) - END
      WHERE   R.confirmed = 'N' 
      AND (L1.putawayzone IN (@c_zone02, @c_zone03, @c_zone04,
                              @c_zone05, @c_zone06, @c_zone07,
                              @c_zone08, @c_zone09, @c_zone10,
                              @c_zone11, @c_zone12) OR @c_zone02 = 'ALL') 
      AND L1.Facility = @c_zone01 
      AND R.Storerkey = CASE WHEN @c_storerkey = 'ALL' OR @c_storerkey = '' THEN
                                    R.Storerkey ELSE @c_storerkey END   
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)                                                    
      GROUP BY R.FromLoc,
               R.ToLoc,
               R.Sku,
               R.StorerKey,
               R.PackKey,
               SKU.Descr,
               L1.PutawayZone,
               PACK.CaseCnt,
               L1.Facility,
               L1.LogicalLocation,
               --(Wan01) - START 
               LA.Lottable04
               --(Wan01) - END
      ORDER BY L1.Facility,
               L1.PutawayZone,
               L1.LogicalLocation
END

GO