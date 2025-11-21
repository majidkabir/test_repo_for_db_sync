SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispLoseId                                          */
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
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author  Ver  Purposes                                     */
/* 2010-10-05 Shong   1.1  Added new Parameter TarGet Location          */
/************************************************************************/
CREATE PROC [dbo].[ispLoseId] 
    @c_TargetLoc NVARCHAR(10) = '%'
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE
 @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err        int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2       int              -- For Additional Error Detection
 ,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue   int                 
 ,         @n_starttcnt  int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int                  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBOA1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
    DECLARE	@c_storerkey NVARCHAR(15),
 				@c_sku	 NVARCHAR(20),
 				@c_lot	 NVARCHAR(10),
 				@c_id		   NVARCHAR(18),
 				@c_loc	 NVARCHAR(10),
 				@c_toloc	   NVARCHAR(10),
 				@n_qty		int,
 				@c_packkey NVARCHAR(10),
 				@c_uom	 NVARCHAR(10),
 				@c_ReplenishmentKey NVARCHAR(10),
 				@n_InvQty       int,
 				@c_ToId         NVARCHAR(18)

     IF @c_TargetLoc = '%' 
     BEGIN
        DECLARE CUR1 CURSOR fast_forward read_only FOR
         SELECT DISTINCT LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, 
             (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated)
         FROM LOTxLOCxID (NOLOCK), SKUxLOC (NOLOCK), LOC (NOLOCK)
         WHERE LOTxLOCxID.ID <> ''
         AND   LOTxLOCxID.LOC = LOC.LOC
         AND   LOC.LOSEID = '1'
         AND   LOTxLOCxID.Qty > 0
         AND   LOTxLOCxID.StorerKey = SKUxLOC.StorerKey
         AND   LOTxLOCxID.SKU = SKUxLOC.SKU
         AND   LOTxLOCxID.LOC = SKUxLOC.LOC
         AND   SKUxLOC.LocationType IN ('PICK', 'CASE')
         AND   (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) > 0         
     END 
     ELSE
     BEGIN
        DECLARE CUR1 CURSOR fast_forward read_only FOR
         SELECT DISTINCT LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, 
             (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated)
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC l (NOLOCK) ON l.Loc = LOTxLOCxID.Loc 
         WHERE LOTxLOCxID.ID <> ''
         AND   LOTxLOCxID.LOC = @c_TargetLoc 
         AND   l.LOSEID = '1'
         AND   LOTxLOCxID.Qty > 0
         AND   (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) > 0         
     END
 		
     OPEN CUR1
 	  FETCH NEXT FROM CUR1 INTO @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty
     WHILE @@fetch_status <> -1
     BEGIN   
  		  SELECT @c_lot 'lot', @c_loc 'Location', @c_id 'ID'

        SELECT @c_packkey = PACK.Packkey,
 				   @c_uom = PACK.PACKUOM3
          FROM PACK (NOLOCK), SKU (NOLOCK)
 			WHERE SKU.PackKey = PACK.PackKey
 			AND   SKU.StorerKey = @c_Storerkey
 			AND   SKU.SKU = @c_sku

         IF @n_qty > 0 
 		   BEGIN
 			   BEGIN TRAN
 	
 	         EXECUTE nspItrnAddMove
 				NULL,
 				@c_storerkey,
 				@c_sku,
 				@c_lot,
 				@c_loc,
 				@c_id,
 				@c_loc,
 				@c_ID,
 				"",
 				"",
				"",
 				"",
 				NULL,
 				NULL,
 				0,
 				0,
 				@n_qty,
 				0,
 				0,
 				0,
 				0,
 				0,
 				0,
 				' ',
 				'ispLoseID',
 				@c_packkey,
 				@c_uom,
 				1,
 				NULL,
 				"",
 				@b_Success  OUTPUT,
 				@n_err      OUTPUT,
 				@c_errmsg   OUTPUT
 	
			IF @b_Success = 1
			   COMMIT TRAN
			ELSE
         BEGIN
				ROLLBACK TRAN
            BREAK 
         END 
		 END
 			
 		 FETCH NEXT FROM CUR1 INTO @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty
    END -- While
 	 DEALLOCATE CUR1
 END
   /* #INCLUDE <TRMBOHA2.SQL> */

END

GO