SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ReplenishToFPA_Move_Ticket                     */
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
/* Date         Author  Ver.  Purposes                                  */
/* 26-Jun-09    Vanessa 1.1   SOS#139316 Add Logical Location -- (Vanessa01)*/
/* 17-Nov-09    NJOW01  1.2   SOS#153022 Add Lottable02 & Lottable04    */  
/* 24-May-11    NJOW02  1.3   SOS#216319 Add From ID and wave/load#     */ 
/************************************************************************/
CREATE PROC  [dbo].[nsp_ReplenishToFPA_Move_Ticket]
             @c_Key_Type      NVARCHAR(13)
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
   ,               @n_starttcnt   int


   DECLARE @b_debug   int,
           @b_success int,
           @n_err     int,
           @c_errmsg  NVARCHAR(255)

   DECLARE @c_Key            NVARCHAR(10),
           @c_Type           NVARCHAR(2)

   SELECT @c_Key = LEFT(@c_Key_Type, 10)
   SELECT @c_Type = RIGHT(@c_Key_Type,2)

   SELECT @n_continue=1, @b_debug = 0

   IF @c_Type = 'WP'
   BEGIN

		SELECT PICKDETAIL.Loc,
		       PICKDETAIL.ID,  --NJOW02
		       PICKDETAIL.ToLoc,
		       PICKDETAIL.SKU,
		       PICKDETAIL.Storerkey,
		       PICKDETAIL.Lot,
		       PICKDETAIL.DropID,
		       SUM(PICKDETAIL.Qty) as TotalQty,
		       SKU.Descr,
		       PACK.Casecnt,
		       PACK.PACKUOM1,
		       PACK.PACKUOM3,
		       L1.Facility as ToFacility,
		       L2.Facility as FromFacility,
		       ISNULL(SKU.AltSku, '') as UPC,
		       SKU.StdCube,
		       SKU.STDNETWGT,
           SKU.BUSR3,
           L2.Putawayzone,
           L2.LogicalLocation,  -- (Vanessa01)
 		       LA.Lottable02, --NJOW01
 		       LA.Lottable04,  --NJOW01
 		       @c_key
		FROM  WAVEDETAIL (NOLOCK)
      JOIN  PICKDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)
		JOIN  SKU (NOLOCK) ON (SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = PICKDETAIL.Storerkey)
		JOIN  LOC L1 (NOLOCK) ON (L1.Loc = PICKDETAIL.ToLoc)
		JOIN  LOC L2 (NOLOCK) ON (L2.Loc = PICKDETAIL.Loc)
		JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
		JOIN  LOTxLOCxID LT(NOLOCK) ON (LT.Lot = PICKDETAIL.Lot AND LT.Loc = PICKDETAIL.Loc AND  LT.ID = PICKDETAIL.ID)
		JOIN  LOTATTRIBUTE LA (NOLOCK) ON (LT.LOT = LA.LOT AND LT.SKU = LA.SKU AND LT.STORERKEY = LA.STORERKEY)
		WHERE WAVEDETAIL.Wavekey = @c_Key
      AND   (PICKDETAIL.ToLoc <> '' AND PICKDETAIL.ToLOC IS NOT NULL)
		GROUP BY PICKDETAIL.Loc,
		        PICKDETAIL.ID, --NJOW02
			      PICKDETAIL.ToLoc,
			      PICKDETAIL.SKU,
			      PICKDETAIL.Storerkey,
			      PICKDETAIL.Lot,
			      PICKDETAIL.DropID,
			      SKU.Descr,
			      PACK.Casecnt,
			      PACK.PACKUOM1,
			      PACK.PACKUOM3,
			      L1.Facility,
			      L2.Facility,
			      SKU.AltSku,
			      SKU.StdCube,
			      SKU.STDNETWGT,
            SKU.BUSR3,
            L2.Putawayzone,
            L2.LogicalLocation,  -- (Vanessa01)
 		        LA.Lottable02, --NJOW01
 		        LA.Lottable04  --NJOW01
   END
   ELSE IF @c_Type = 'LP'
   BEGIN

		SELECT PICKDETAIL.Loc,
		       PICKDETAIL.ID, --NJOW02
		       PICKDETAIL.ToLoc,
		       PICKDETAIL.SKU,
		       PICKDETAIL.Storerkey,
		       PICKDETAIL.Lot,
		       PICKDETAIL.DropID,
		       SUM(PICKDETAIL.Qty) as TotalQty,
		       SKU.Descr,
		       PACK.Casecnt,
		       PACK.PACKUOM1,
		       PACK.PACKUOM3,
		       L1.Facility as ToFacility,
		       L2.Facility as FromFacility,
		       ISNULL(SKU.AltSku, '') as UPC,
		       SKU.StdCube,
		       SKU.STDNETWGT,
           SKU.BUSR3,
           L2.Putawayzone,
           L2.LogicalLocation,  -- (Vanessa01)
 		       LA.Lottable02, --NJOW01
 		       LA.Lottable04,  --NJOW01
 		       @c_key 
		FROM  LOADPLANDETAIL (NOLOCK)
      JOIN  PICKDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)
		JOIN  SKU (NOLOCK) ON (SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = PICKDETAIL.Storerkey)
		JOIN  LOC L1 (NOLOCK) ON (L1.Loc = PICKDETAIL.ToLoc)
		JOIN  LOC L2 (NOLOCK) ON (L2.Loc = PICKDETAIL.Loc)
		JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
		JOIN  LOTxLOCxID LT(NOLOCK) ON (LT.Lot = PICKDETAIL.Lot AND LT.Loc = PICKDETAIL.Loc AND  LT.ID = PICKDETAIL.ID)
		JOIN  LOTATTRIBUTE LA (NOLOCK) ON (LT.LOT = LA.LOT AND LT.SKU = LA.SKU AND LT.STORERKEY = LA.STORERKEY)
		WHERE LOADPLANDETAIL.LoadKey = @c_Key
      AND   (PICKDETAIL.ToLoc <> '' AND PICKDETAIL.ToLOC IS NOT NULL)
		GROUP BY PICKDETAIL.Loc,
		        PICKDETAIL.ID, --NJOW02
			      PICKDETAIL.ToLoc,
			      PICKDETAIL.SKU,
			      PICKDETAIL.Storerkey,
			      PICKDETAIL.Lot,
			      PICKDETAIL.DropID,
			      SKU.Descr,
			      PACK.Casecnt,
			      PACK.PACKUOM1,
			      PACK.PACKUOM3,
			      L1.Facility,
			      L2.Facility,
			      SKU.AltSku,
			      SKU.StdCube,
			      SKU.STDNETWGT,
            SKU.BUSR3,
            L2.Putawayzone,
            L2.LogicalLocation,  -- (Vanessa01)
 		        LA.Lottable02, --NJOW01
 		        LA.Lottable04  --NJOW01
   END


END -- End of Proc

GO