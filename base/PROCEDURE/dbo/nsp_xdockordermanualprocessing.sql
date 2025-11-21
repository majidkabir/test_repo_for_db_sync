SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[nsp_xdockordermanualprocessing] 
 	@c_orderkey	 NVARCHAR(10),
 	@c_orderline   NVARCHAR(5) ,
 	@c_storerkey   NVARCHAR(15),
 	@c_sku		   NVARCHAR(20),
	@n_qtyallocate	int,
	@n_totallocate	int
AS
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

	DECLARE @i_success integer,
	        @i_error   integer,
	        @c_errmsg  NVARCHAR(255),
			  @n_continue int, 
			  @n_starttcnt int

	DECLARE @c_caseid NVARCHAR(10), @c_pickdetkey NVARCHAR(18), @c_pickhdkey NVARCHAR(18),	@c_fromupdateloop NVARCHAR(1), 
			  @b_success NVARCHAR(1), @c_uom NVARCHAR(10), @c_packkey NVARCHAR(10), @n_cnt int, 
			  @c_prevlot NVARCHAR(18), @c_prevloc NVARCHAR(10), @c_previd NVARCHAR(18), @c_pickkey NVARCHAR(18) 
	
	DECLARE @n_OpenQty int, @n_ShippedQty int, @n_AllocateQty int, @n_PickQty int, @c_facility NVARCHAR(5),  
			  @n_err	int, @n_remainQty int, @n_pdallocateqty int, @n_sysremainqty int, @n_pdworkqty int, 
			  @n_InvQty int, @c_lot NVARCHAR(18), @c_loc NVARCHAR(10), @c_Id NVARCHAR(18), @c_externpokey NVARCHAR(20) 

	SELECT @i_success = 0, @i_error = 0, @n_continue = 1, @n_starttcnt=@@TRANCOUNT

	IF @n_qtyallocate = @n_totallocate 
	BEGIN 
		SELECT @n_continue = 3
		SELECT @i_error = 15001
		SELECT @c_errmsg = 'nspxdockorderprocessing - Nothing to be done'		
		GOTO EXITROUTINE
	END

	IF (@n_continue = 1 OR @n_continue =2) 
	BEGIN 
		IF (@n_totallocate < 0)  
		BEGIN 
			SELECT @n_continue = 3
			SELECT @i_error = 15001
			SELECT @c_errmsg = 'nspxdockorderprocessing - Allocated Qty cannot be Negative'		
			GOTO EXITROUTINE
		END
	END

	IF (@n_continue = 1 OR @n_continue =2) 
	BEGIN 
		SELECT @c_uom = OD.UOM, @c_packkey = OD.PACKKEY, 
				 @n_openqty = OD.OpenQty, @n_AllocateQty = OD.QtyAllocated, 
				 @n_PickQty = OD.Qtypicked, @c_externpokey = OD.ExternPoKey, 
				 @c_facility = OH.FACILITY 
		  FROM ORDERDETAIL OD (Nolock), ORDERS OH (Nolock) 
		 WHERE OH.Orderkey = OD.Orderkey 
		   AND OD.Orderkey = @c_orderkey 
		   AND OD.Orderlinenumber = @c_orderline 
	
		IF @@Rowcount = 0 
		BEGIN 
			SELECT @n_continue = 3
			SELECT @i_error = 15010
			SELECT @c_errmsg = 'nspxdockorderprocessing - CrossDock Strategy Not Found'		
			GOTO EXITROUTINE
		END
	END

	IF (@n_continue = 1 OR @n_continue =2) 
	BEGIN 
		IF (@n_AllocateQty + @n_pickqty + (@n_totallocate - @n_qtyallocate)) > @n_openqty 
		BEGIN
			BEGIN TRANSACTION 
			UPDATE ORDERDETAIL 
				SET OPENQTY = @n_AllocateQty + @n_pickqty + (@n_totallocate - @n_qtyallocate)  
			 WHERE Orderkey = @c_orderkey
				AND Orderlinenumber = @c_orderline 				

			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err <> 0 
			BEGIN 
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 15110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of Orderdetail Table Failed (nsp_xdockOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
				GOTO EXITROUTINE
			END 
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				COMMIT TRAN
			END
		END

		SELECT @n_remainQty = @n_totallocate - @n_qtyallocate 		

		IF @n_qtyallocate = 0 
		BEGIN 	
			IF EXISTS(SELECT PICKDETAILKEY FROM PICKDETAIL (NOLOCK) 
						  WHERE ORDERKEY = @c_orderkey AND ORDERLINENUMBER = @c_orderline AND STATUS < '5')
			BEGIN 
				GOTO UpdatePickDetail 
			END
			ELSE
			BEGIN
				GOTO CreatePickDetail 
			END
		END
		ELSE 
		BEGIN
			IF @n_totallocate = 0 
			BEGIN 				
				DELETE PICKDETAIL 
				 WHERE ORDERKEY = @c_orderkey 
				   AND ORDERLINENUMBER = @c_orderline 
				   AND STATUS < '5' 

				GOTO EXITROUTINE
			END 
			ELSE
			BEGIN 
				IF @n_remainQty < 0 
				BEGIN 
					SELECT @c_pickkey = ''
					WHILE (1=1) 
					BEGIN
						SELECT @c_pickkey = Pickdetailkey, @n_pickqty = Qty FROM PICKDETAIL (NOLOCK) 
						 WHERE ORDERKEY = @c_orderkey 
						   AND ORDERLINENUMBER = @c_orderline 
						   AND STATUS < '5' 
							AND Pickdetailkey > @c_pickkey
					
						IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_pickkey)) = '' OR @c_pickkey IS NULL 
						BEGIN 
							BREAK
						END
						ELSE
						BEGIN 
							IF ABS(@n_remainQty) >= @n_pickqty 
							BEGIN 
								DELETE PICKDETAIL 
								 WHERE Pickdetailkey = @c_pickkey 
								   AND STATUS < '5'

								SELECT @n_remainQty = @n_remainQty + @n_pickqty 
							END
							ELSE
							BEGIN 
								UPDATE PICKDETAIL 
								   SET QTY = QTY + @n_remainQty
								 WHERE Pickdetailkey = @c_pickkey 
								   AND STATUS < '5' 

								SELECT @n_remainQty = 0  
							END

							IF @n_remainQty = 0 BREAK
						END
					END 

					GOTO EXITROUTINE
				END
				ELSE
				BEGIN
					IF @n_remainQty > 0 
					BEGIN 
						IF EXISTS(SELECT PICKDETAILKEY FROM PICKDETAIL (NOLOCK) 
									  WHERE ORDERKEY = @c_orderkey AND ORDERLINENUMBER = @c_orderline 
									    AND STATUS < '5') 
						BEGIN
							GOTO UpdatePickDetail 
						END
						ELSE
						BEGIN
							GOTO CreatePickDetail 
						END
					END	
				END				
			END
		END

		CreatePickDetail: 
	
		-- LOOKUP Inventory record for potential candidate 

		DECLARE Inv_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
		SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS Qty, 
				 LLI.Lot, LLI.Loc, LLI.ID 
		  FROM Lotxlocxid LLI (nolock), Lotattribute LA (Nolock), Loc (Nolock) 
		 WHERE LLI.Lot = LA.Lot
		   AND LLI.Loc = Loc.Loc 
			AND Loc.Facility = @c_facility 
			AND LLI.Storerkey = @c_storerkey 
			AND LLI.Sku = @c_sku 
			AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0 
			AND LA.Lottable03 = @c_externpokey  
		GROUP BY LLI.Lot, LLI.Loc, LLI.ID
	
		OPEN Inv_CUR 
		FETCH NEXT FROM Inv_CUR INTO @n_Invqty, @c_lot, @c_loc, @c_id 
		
		WHILE @@FETCH_STATUS = 0 
		BEGIN 

			CreatePickDetailLoop:

			IF @n_remainQty > @n_Invqty 
			BEGIN 
				SELECT @n_remainQty = @n_remainQty - @n_Invqty
				SELECT @n_pdworkqty = @n_Invqty
			END
			ELSE 
			BEGIN
				SELECT @n_remainQty = 0 
				SELECT @n_pdworkqty = @n_remainQty
			END
	
			EXEC nspg_getkey
				'PICKHEADERKEY' ,
				10 ,
				@c_pickhdkey 	OUTPUT ,
				@b_success		OUTPUT,
				@n_err			OUTPUT,
				@c_errmsg		OUTPUT 
		
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
				SELECT @i_error = 15100
				SELECT @c_errmsg = 'nspxdockorderprocessing - Generation of PickHeader Key Failed'
				BREAK
			END
		
			EXEC nspg_getkey
				'PICKDETAILKEY' ,
				10 ,
				@c_pickdetkey 	OUTPUT ,
				@b_success		OUTPUT,
				@n_err			OUTPUT,
				@c_errmsg		OUTPUT 
		
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
				SELECT @i_error = 15100
				SELECT @c_errmsg = 'nspxdockorderprocessing - Generation of PickDetail Key Failed'
				BREAK
			END
		
			EXEC nspg_getkey
				'CARTONID' ,
				10 ,
				@c_caseid	 	OUTPUT ,
				@b_success		OUTPUT,
				@n_err			OUTPUT,
				@c_errmsg		OUTPUT 
		
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
				SELECT @i_error = 15100
				SELECT @c_errmsg = 'nspxdockorderprocessing - Generation of CASE ID Key Failed'
				BREAK
			END

			BEGIN TRANSACTION 
			INSERT PICKDETAIL (Pickdetailkey, CASEID, PickHeaderKey, OrderKey, Orderlinenumber, 
									 Storerkey, Sku, UOM, UOMQty, Qty, Lot, Loc, ID, Packkey, CartonGroup) 	
					 	  VALUES (@c_pickdetkey, @c_caseid, @c_pickHdkey, @c_orderkey, @c_orderline, 
									 @c_storerkey, @c_sku, @c_uom, 1, @n_pdworkqty, @c_lot, 
									 @c_loc, @c_Id, @c_Packkey, 'STD' ) 
	
			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err <> 0 
			BEGIN 
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 15220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": INSERT of PICK Table Failed (nsp_xdockOrdermanualProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
				BREAK 
			END
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				COMMIT TRAN
			END
	
			IF @c_fromupdateloop = 'Y' 
			BEGIN 
				GOTO JobFromCreatepickdetail 			
			END
			ELSE
			BEGIN
				IF @n_remainQty = 0 
				BEGIN 
					BREAK
				END 
			END
	
			FETCH NEXT FROM Inv_CUR INTO @n_Invqty, @c_lot, @c_loc, @c_id 
		END

		GOTO EXITROUTINE

		UPDATEPICKDETAIL:

		-- LOOKUP Inventory record for potential candidate 

		DECLARE Inv_CUR CURSOR  FAST_FORWARD READ_ONLY FOR 
		SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS Qty, 
				 LLI.Lot, LLI.Loc, LLI.ID 
		  FROM Lotxlocxid LLI (nolock), Lotattribute LA (Nolock), Loc (Nolock) 
		 WHERE LLI.Lot = LA.Lot
		   AND LLI.Loc = Loc.Loc 
			AND Loc.Facility = @c_facility 
			AND LLI.Storerkey = @c_storerkey 
			AND LLI.Sku = @c_sku 
			AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0 
			AND LA.Lottable03 = @c_externpokey  
		GROUP BY LLI.Lot, LLI.Loc, LLI.ID
	
		OPEN Inv_CUR 
		FETCH NEXT FROM Inv_CUR INTO @n_Invqty, @c_lot, @c_loc, @c_id 
		
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			IF @c_prevlot <> @c_lot OR @c_prevloc <> @c_loc OR @c_previd <> @c_id 
			BEGIN  
				SELECT @c_prevlot = @c_lot, @c_prevloc = @c_loc, @c_previd = @c_id 

				SELECT @c_pickkey = Pickdetailkey FROM PICKDETAIL (NOLOCK) 
				 WHERE Orderkey = @c_orderkey AND ORDERLINENUMBER = @c_orderline 
					AND LOT = @c_lot AND LOC = @c_loc AND ID = @c_id AND STATUS < '5'  

				IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_pickkey)) = '' OR @c_pickkey IS NULL 
				BEGIN 
					SELECT @c_fromupdateloop = 'Y'
					GOTO CreatePickDetailLoop

					JobFromCreatepickdetail: 

					IF @n_remainQty = 0 
					BEGIN
						BREAK
					END 
			
					FETCH NEXT FROM Inv_CUR INTO @n_Invqty, @c_lot, @c_loc, @c_id 

					CONTINUE  
				END
			END

			IF @n_remainQty > @n_Invqty 
			BEGIN 
				SELECT @n_remainQty = @n_remainQty - @n_Invqty
				SELECT @n_pdworkqty = @n_Invqty
			END
			ELSE 
			BEGIN
				SELECT @n_remainQty = 0 
				SELECT @n_pdworkqty = @n_remainQty
			END
	
			BEGIN TRANSACTION 
			UPDATE PICKDETAIL SET Qty = @n_pdworkqty
			 WHERE PICKDETAILKEY = @c_pickkey  
	
			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err <> 0 
			BEGIN 
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 15220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE of PICK Table Failed (nsp_xdockOrdermanualProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
				BREAK 
			END
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				COMMIT TRAN
			END
	
			IF @n_remainQty = 0 
			BEGIN
				BREAK
			END 
	
			FETCH NEXT FROM Inv_CUR INTO @n_Invqty, @c_lot, @c_loc, @c_id 
		END

		GOTO EXITROUTINE
	END

	EXITROUTINE:
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		SELECT @i_success = 0
		IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @n_starttcnt
			BEGIN
				COMMIT TRAN
			END
		END
		execute nsp_logerror @i_error, @c_errmsg, "nsp_xdockordermanualprocessing"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		SELECT @i_success, @i_error, @c_errmsg
		RETURN
	END
	ELSE
	BEGIN
		SELECT @i_success = 1
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		SELECT @i_success, @i_error, @c_errmsg
		RETURN
	END
END


GO