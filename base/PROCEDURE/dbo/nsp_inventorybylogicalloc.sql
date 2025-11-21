SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nsp_InventoryByLogicalLoc                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2019-03-29   TLTING01 1.1  Bug fix                                   */     
/************************************************************************/

CREATE PROC [dbo].[nsp_InventoryByLogicalLoc] ( 
 @c_facility NVARCHAR(5),
 @c_start_aisle NVARCHAR(2),
 @c_end_aisle NVARCHAR(2),
 @n_start_level NVARCHAR(2),
 @n_end_level NVARCHAR(2),
 @c_zone NVARCHAR(10)

 )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

 	DECLARE @c_loc NVARCHAR(10),
 		@c_logicalloc NVARCHAR(10)

 	SELECT facility,
      putawayzone,
 		loc,
		CCLogicalLoc, 
 		storerkey = space(18),
 		sku = space(20),
      susr3 = space(18), -- agency code
 		descr = space(60),
 		lottable02 = space(18),
 		lottable04 = space(10),
 		qtyavail = 0,
 		packkey = space(10),
 		casecnt = 0,
 		packuom3 = space(10),
 		palletid = space(18)
 	INTO #RESULT
 	FROM LOC (nolock)
 	WHERE (1 = 2)

 	DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
 	FOR
 	SELECT putawayzone, loc, CCLogicalLoc
 	FROM LOC (nolock)
 	WHERE --loc =@c_location
  	   locaisle BETWEEN @c_start_aisle AND @c_end_aisle
	  and loclevel BETWEEN CONVERT(int, @n_start_level) AND CONVERT(int, @n_end_level)
     and facility = @c_facility
	  and putawayzone = @c_zone
     and putawayzone > ''
 	ORDER BY loc
 
 	OPEN cur_1
 	FETCH NEXT FROM cur_1 INTO @c_zone, @c_loc, @c_logicalloc
 	WHILE (@@fetch_status <> -1)
 	BEGIN
 		INSERT #RESULT
 		SELECT @c_facility,
         LOC.putawayzone, 
 			LOTxLOCxID.loc,
			LOC.CCLogicalLoc,
 			LOTxLOCxID.storerkey,
 			LOTxLOCxID.sku,
         sku.susr3, -- agency code
 			sku.descr,     --tlting01
 			LOTATTRIBUTE.lottable02, 
 			CONVERT(char(10), LOTATTRIBUTE.lottable04, 101), 
 			SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked),
 			SKU.packkey,
 			PACK.casecnt,
 			PACK.packuom3,
 			LOTxLOCxID.id
 		FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), LOTATTRIBUTE (NOLOCK), PACK (NOLOCK)
 		WHERE LOTxLOCxID.loc = LOC.loc
 		  AND LOTxLOCxID.sku = SKU.sku
        AND LOTxLOCxID.storerkey = SKU.storerkey	
 		  AND LOTxLOCxID.lot = LOTATTRIBUTE.lot
 		  AND SKU.packkey = PACK.packkey
 		  AND LOTxLOCxID.loc = @c_loc 
 		GROUP BY LOC.putawayzone, 
 			LOTxLOCxID.loc,
			LOC.CCLogicalloc,
 			LOTxLOCxID.storerkey,
 			LOTxLOCxID.sku,
         SKU.susr3, -- agency code
 			sku.descr, 
 			LOTATTRIBUTE.lottable02, 
 			CONVERT(char(10), LOTATTRIBUTE.lottable04, 101),
 			SKU.packkey,
 			PACK.casecnt,
 			PACK.packuom3,
 			LOTxLOCxID.id
 		HAVING SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) > 0
 		IF @@ROWCOUNT = 0
 			INSERT #RESULT (facility, putawayzone, loc, CCLogicalLoc, lottable04, qtyavail, casecnt) 
 				VALUES (@c_facility, @c_zone, @c_loc, @c_logicalloc, '00/00/00', 0, 0)
 
 		FETCH NEXT FROM cur_1 INTO @c_zone, @c_loc, @c_logicalloc
 	END
 	CLOSE cur_1
 	DEALLOCATE cur_1
 
 	SELECT facility = upper(facility),
      putawayzone = UPPER(putawayzone),
 		loc,
		CCLogicalLoc,
 		storerkey,
 		sku,
      susr3, -- agency code
 		descr,
 		lottable02,
 		lottable04,
 		qtyavail,
 		packkey,
 		casecnt,
 		packuom3,
 		palletid 
	FROM #RESULT-- ORDER BY loc	
 	DROP TABLE #RESULT
 END

GO