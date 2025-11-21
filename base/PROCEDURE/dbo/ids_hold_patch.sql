SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: ids_hold_patch                                             */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 13-Jul-2004            1.1   Include Drop Object before Create          */
/* 15-Oct-2004  mohit     1.2   change cursor type                         */
/* 05-Nov-2004  wtshong   1.3   Add NOLOCK                                 */
/***************************************************************************/ 
CREATE PROC [dbo].[ids_hold_patch] 
 	@c_storer NVARCHAR(15)  = '%',
 	@c_testonly NVARCHAR(1) = 'N'
 AS
 BEGIN -- main procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 	
 	DECLARE 	@c_lot NVARCHAR(10),
		@n_qtyonhold  int,
		@n_qtyholdid  int,
		@n_qtyholdloc int
 	
 	print 'Patching against  ' + (case @c_storer when  '%' then 'All storers' else @c_storer end)
 	
 	DECLARE cur_1  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 		SELECT lot, qtyonhold
 		FROM lot (nolock) 
 		WHERE storerkey 
      like @c_storer
 		AND qty > 0
 	
 	OPEN cur_1

 	FETCH NEXT FROM cur_1 INTO @c_lot, @n_qtyonhold
 	
 	WHILE (@@FETCH_STATUS <> -1)
 	BEGIN
 		print 'Begin patching lot :' + @c_lot + ' , current hold qty = ' + CAST(@n_qtyonhold as NVARCHAR(15))
 		
 		set @n_qtyholdid = 0
 		set @n_qtyholdloc = 0
 		begin transaction @c_lot
 		
 		SET @n_qtyholdid = isnull( (SELECT SUM(LOTxLOCxID.QTY)
 					FROM LOTxLOCxID (NOLOCK), ID (NOLOCK)
 					WHERE LOTxLOCxID.LOT = @c_lot
 					AND LOTxLOCxID.ID = ID.ID
 					AND ID.STATUS = 'HOLD'
 					AND LOTxLOCxID.QTY >= 1), 0)
 		
 		print '     total id hold qty :' + cast(@n_qtyholdid as NVARCHAR(15))

 		SET @n_qtyholdloc = isnull((SELECT SUM(LOTxLOCxID.QTY)
 					FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK) 
 					WHERE LOTxLOCxID.LOT = @c_lot
 					AND   LOTxLOCxID.LOC = LOC.LOC
 					AND   LOTxLOCxID.ID = ID.ID
 					AND   ID.STATUS = 'OK'
 					AND   (LOC.STATUS = 'HOLD' OR LOC.LOCATIONFLAG  = 'HOLD' OR LOC.LOCATIONFLAG = 'DAMAGE')
 					AND LOTxLOCxID.QTY >= 1), 0)
 		
 		print '     total loc hold qty :' + cast(@n_qtyholdloc as NVARCHAR(15))

 		IF @n_qtyonhold = (@n_qtyholdid + @n_qtyholdloc)
 			print 'End patching lot :' + @c_lot + ', no patch is required.'
 		ELSE
 		BEGIN
 			IF @c_testonly = 'Y'
 				print 'patching required for lot :' + dbo.fnc_RTrim(@c_lot) + ' with test only'
 			ELSE
 			BEGIN
 				update lot set qtyonhold =  (@n_qtyholdid + @n_qtyholdloc)
 				where lot = @c_lot
 	
 				print 'Patching lot :' + @c_lot + ' with update applied'
 			END
 		END
 		Commit Transaction @c_lot
 		
 		FETCH NEXT FROM cur_1 INTO @c_lot, @n_qtyonhold
 	END
 	CLOSE cur_1
 	DEALLOCATE cur_1
 	print '*** Inventory of which hold qty is still greater than avail qty ***'
 	select * from lot where storerkey like @c_storer and qtyonhold > (qty - qtyallocated - qtypicked - qtypreallocated) 
 	
 END -- main procedure



GO