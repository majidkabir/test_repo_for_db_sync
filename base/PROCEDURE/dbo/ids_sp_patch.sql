SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ids_sp_patch                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)              */
/* 21-05-2012   KHLim01  1.2  Update EditDate                           */
/************************************************************************/


CREATE PROC [dbo].[ids_sp_patch] (
 @c_storer NVARCHAR(18)
 )
 AS
 BEGIN -- main procedure
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 	
 	DECLARE @c_storerkey NVARCHAR(18),
 			@c_sku NVARCHAR(20),
 			@c_lot NVARCHAR(10),
 			@c_loc NVARCHAR(10),
 			@c_id NVARCHAR(18),			-- tlting01
 			@n_qty int,
 			@n_qtyallocated int,
 			@n_qtypicked int,
 			@n_qtyexpected int,
 			@n_alloc int,
 			@n_pick int
 	
 	DECLARE cur_1 CURSOR OPTIMISTIC FOR
 		SELECT storerkey, sku, lot, loc, id
 		FROM lotxlocxid (NOLOCK)
 		WHERE storerkey = @c_storer
 			AND qty > 0
 --		  AND sku = @c_item
 		ORDER BY lot
 	
 	OPEN cur_1
 	FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id
 	WHILE (@@FETCH_STATUS <> -1)
 	BEGIN
 		SELECT @c_storerkey 'storerkey', @c_sku 'sku', @c_lot 'lot', @c_loc 'loc', @c_id 'id'
 	
 		IF EXISTS (SELECT 1
 				 FROM pickdetail (UPDLOCK)
 				 WHERE lot = @c_lot
 		  	  	   AND loc = @c_loc
 		  	  	   AND id = @c_id
 				   AND status < '9')
 		BEGIN -- for lotxlocxid update against pickdetail
 			BEGIN TRAN updatelotxlocxid
 			SELECT @n_alloc = ISNULL(SUM(qty), 0)
 			FROM pickdetail (UPDLOCK)
 			WHERE lot = @c_lot
 		  	  AND loc = @c_loc
 		  	  AND id = @c_id 
 			  AND status < '5'
 	
 			SELECT @n_pick = ISNULL(SUM(qty), 0)
 			FROM pickdetail (UPDLOCK)
 			WHERE lot = @c_lot
 		  	  AND loc = @c_loc
 		  	  AND id = @c_id 
 			  AND status BETWEEN '5' AND '8'
 	
 		     SELECT @n_qty = SUM(qty)
 			FROM lotxlocxid (UPDLOCK)
 			WHERE lot = @c_lot
 		  	  AND loc = @c_loc
 		  	  AND id = @c_id
 			
 			IF @n_qty < @n_alloc + @n_pick SELECT @n_qty = @n_qty + @n_alloc + @n_pick
 	
 			SELECT 'updating lotxlocxid...', @n_qty 'qty', @n_alloc 'qtyallocated', @n_pick 'qtypicked'
 			
 			UPDATE lotxlocxid WITH (UPDLOCK)
 			SET qty = @n_qty,
 				qtyallocated = @n_alloc,
 				qtypicked = @n_pick,
            EditDate  = GETDATE(),   -- KHLim01
 				trafficcop = NULL
 			WHERE lot = @c_lot
 		  	  AND loc = @c_loc
 		  	  AND id = @c_id
 			COMMIT TRAN updatelotxlocxid
 		END -- for lotxlocxid update against pickdetail
 	
 	-- set variables for lot update
 		SELECT @n_qty = ISNULL(SUM(qty), 0),
 			  @n_qtyallocated = ISNULL(SUM(qtyallocated), 0),
 			  @n_qtypicked = ISNULL(SUM(qtypicked), 0)
 		FROM lotxlocxid (UPDLOCK)
 		WHERE lot = @c_lot
 	
 	-- for lot update
 		IF NOT EXISTS (SELECT 1
 				 	FROM lot (UPDLOCK)
 				 	WHERE lot = @c_lot
 				   	  AND qty = @n_qty
 				   	  AND qtyallocated = @n_qtyallocated
 				   	  AND qtypicked = @n_qtypicked)
 		BEGIN -- update lot
 			BEGIN TRAN updatelot
 			SELECT 'updating lot...', @n_qty 'qty', @n_qtyallocated 'qtyallocated', @n_qtypicked 'qtypicked'
 			UPDATE lot WITH (UPDLOCK)
 			SET qty = @n_qty,
 			    qtyallocated = @n_qtyallocated,
 			    qtypicked = @n_qtypicked,
 			    qtypreallocated = 0,
             EditDate  = GETDATE(),   -- KHLim01
 			    trafficcop = NULL
 			WHERE lot = @c_lot
 		
 			IF @@ROWCOUNT = 0 SELECT 'lot not updated...'j
 			COMMIT TRAN updatelot
 		END -- update lot
 	
 	-- set variables for skuxloc update
 		SELECT @n_qty = ISNULL(SUM(qty), 0),
 			  @n_qtyallocated = ISNULL(SUM(qtyallocated), 0),
 			  @n_qtypicked = ISNULL(SUM(qtypicked), 0),
 			  @n_qtyexpected = ISNULL(SUM(qtyexpected), 0)
 		FROM lotxlocxid (UPDLOCK)
 		WHERE storerkey = @c_storerkey
 		  AND sku = @c_sku
 		  AND loc = @c_loc
 	
 	-- for skuxloc update
 		IF NOT EXISTS (SELECT 1
 				 	FROM skuxloc (UPDLOCK)
 				 	WHERE storerkey = @c_storerkey
 					  AND sku = @c_sku
 					  AND loc = @c_loc
 				   	  AND qty = @n_qty
 				   	  AND qtyallocated = @n_qtyallocated
 				   	  AND qtypicked = @n_qtypicked
 					  AND qtyexpected = @n_qtyexpected)
 		BEGIN -- update skuxloc
 			BEGIN TRAN updateskuxloc
 			SELECT 'updating skuxloc...', @n_qty 'qty', @n_qtyallocated 'qtyallocated', @n_qtypicked 'qtypicked'
 		
 			UPDATE skuxloc WITH (UPDLOCK)
 			SET qty = @n_qty,
 			    qtyallocated = @n_qtyallocated,
 			    qtypicked = @n_qtypicked,
 			    qtyexpected = @n_qtyexpected,
             EditDate  = GETDATE(),   -- KHLim01
 			    trafficcop = NULL
 			WHERE storerkey = @c_storerkey
 			  AND sku = @c_sku
 			  AND loc = @c_loc
 		
 			IF @@ROWCOUNT = 0 SELECT 'skuxloc not updated...'
 			COMMIT TRAN updateskuxloc
 		END -- update skuxloc
 	
 	-- set variable for id update
 		SELECT @n_qty = ISNULL(SUM(qty), 0)
 		FROM lotxlocxid (UPDLOCK)
 		WHERE id = @c_id
 	
 	-- for id update
 		IF NOT EXISTS (SELECT 1
 				 	FROM id (UPDLOCK)
 				 	WHERE id = @c_id
 				   	  AND qty = @n_qty)
 		BEGIN -- update ID
 			BEGIN TRAN updateid
 			SELECT 'updating id...', @n_qty 'qty'
 			
 			UPDATE id WITH (UPDLOCK)
 			SET qty = @n_qty,
             EditDate  = GETDATE(),   -- KHLim01
 			    trafficcop = NULL
 			WHERE id = @c_id
 		
 			IF @@ROWCOUNT = 0 SELECT 'id not updated...'
 			COMMIT TRAN updateid
 		END -- update ID
 		
 		FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id
 	END
 	CLOSE cur_1
 	DEALLOCATE cur_1
 END -- main procedure


GO