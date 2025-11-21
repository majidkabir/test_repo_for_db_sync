SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_rfputaway] (
	@c_fromid NVARCHAR(18),
	@c_toloc  NVARCHAR(10),
	@c_ucc01  NVARCHAR(20),
	@c_ucc02  NVARCHAR(20),
	@c_ucc03  NVARCHAR(20), 
	@c_ucc04  NVARCHAR(20),  
	@c_ucc05  NVARCHAR(20),
	@c_ucc06  NVARCHAR(20),
	@c_ucc07  NVARCHAR(20),
	@c_ucc08  NVARCHAR(20), 
	@c_ucc09  NVARCHAR(20),  
	@c_ucc10  NVARCHAR(20)
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	declare @n_continue  	int,
		@n_starttcnt 	int,
		@b_success   	int,
		@n_err       	int,
		@c_errmsg       NVARCHAR(255),
		@local_n_err 	int,
		@local_c_errmsg NVARCHAR(255),
		@n_cnt       	int,
		@n_rowcnt       int,
		@c_storerkey  NVARCHAR(15),
		@c_sku 	      NVARCHAR(20),
		@c_uccno      NVARCHAR(20),
		@c_lot	      NVARCHAR(10),
		@c_fromloc    NVARCHAR(10),
		@c_toid	      NVARCHAR(18),
		@n_qty	     	int,
		@c_lotxlocxid   NVARCHAR(38),
		@c_loseid	 NVARCHAR(1)
		


	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = ''

	SELECT @c_lotxlocxid = ' '

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN
		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ucc01+@c_ucc02+@c_ucc03+@c_ucc04+@c_ucc05+@c_ucc06+@c_ucc07+@c_ucc08+@c_ucc09+@c_ucc10)) is null 
                BEGIN
			WHILE (@n_continue = 1 OR @n_continue = 2)
			BEGIN
				SET ROWCOUNT 1
				
				SELECT @n_rowcnt = 0
				
				SELECT  @c_lotxlocxid = dbo.fnc_RTrim(Lot)+ dbo.fnc_RTrim(Loc) + dbo.fnc_RTrim(ID),
					@c_storerkey = Storerkey,
					@c_sku       = Sku,
					@c_lot	     = Lot,
					@c_fromloc   = Loc,
					@n_rowcnt = 1
				FROM LOTxLOCxID (NOLOCK)
				WHERE ID  = @c_fromid
				AND  dbo.fnc_RTrim(Lot)+ dbo.fnc_RTrim(Loc) + dbo.fnc_RTrim(ID) > @c_lotxlocxid
				AND  Loc <> @c_toloc
				AND  QTY > 0  
				ORDER BY LOT, LOC, ID
	
				SET ROWCOUNT 0

				IF @n_rowcnt = 0 
				BEGIN
					BREAK
				END 

				SELECT @c_toid = @c_fromid
			
				SELECT @n_qty = NULL

				SELECT  @n_qty = SUM(Qty)
				FROM UCC (NOLOCK)
				WHERE LOT = @c_lot
				AND   LOC = @c_Fromloc
				AND   ID  = @c_fromid
				AND   Status = '1'
				GROUP BY LOT, LOC, ID

				EXECUTE nspItrnAddMove
					@n_itrnsysid	= NULL ,
					@c_storerkey	= @c_storerkey ,
					@c_sku		= @c_sku ,
					@c_lot		= @c_lot ,
					@c_fromloc	= @c_fromloc ,
					@c_fromid	= @c_fromid ,
					@c_toloc	= @c_toloc,
					@c_toid		= @c_toid ,
					@c_status	= '' ,
					@c_lottable01	= '' , 
					@c_lottable02	= '' , 
					@c_lottable03	= '' , 
					@d_lottable04	= NULL , 
					@d_lottable05	= NULL , 
					@n_casecnt	= 0 ,
					@n_innerpack	= 0 ,
					@n_qty		= @n_qty ,
					@n_pallet	= 0 ,
					@f_cube		= 0 ,
					@f_grosswgt	= 0 ,
					@f_netwgt	= 0 ,
					@f_otherunit1	= 0 ,
					@f_otherunit2	= 0 ,
					@c_sourcekey	= @c_fromid ,
					@c_sourcetype	= 'PLTPUTAWAY' ,
					@c_packkey	= '' ,
					@c_uom		= '' ,
					@b_uomcalc	= 1 ,
					@d_effectivedate= NULL,
					@c_itrnkey	= '',
	 				@b_success      = @b_success output,
					@n_err          = @n_err output,
					@c_errmsg       = @c_errmsg output

				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END

				IF (@n_continue = 1 or @n_continue = 2)
				BEGIN
					SELECT @c_loseid = loseid
					FROM LOC (NOLOCK)
					WHERE Loc = @c_toloc

					UPDATE UCC
					SET Loc = @c_toloc,
					    ID  = CASE @c_loseid
									WHEN '1' THEN ''
									ELSE @c_toid
								 END,
						 Status = '2'
					WHERE LOT = @c_lot
					AND   LOC = @c_Fromloc
					AND   ID  = @c_fromid
		
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
					IF @local_n_err <> 0
					BEGIN 
						SELECT @n_continue = 3
						SELECT @local_n_err = 77301
						SELECT @local_c_errmsg = convert(char(5),@local_n_err)
						SELECT @local_c_errmsg =
						': update of UCC table failed. (nsp_rfputaway) ' + ' ( ' +
						' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
					END  
					
				END 
			END -- END WHILE
		END
		ELSE
		BEGIN

			WHILE (@n_continue = 1 OR @n_continue = 2)
			BEGIN
				SET ROWCOUNT 1
				
				SELECT @n_rowcnt = 0
				
				SELECT @n_qty = 0

				SELECT  @c_lotxlocxid = dbo.fnc_RTrim(LLI.Lot)+ dbo.fnc_RTrim(LLI.Loc) + dbo.fnc_RTrim(LLI.ID),
					@c_storerkey = LLI.Storerkey,
					@c_sku       = LLI.Sku,
					@c_lot	     = LLI.Lot,
					@c_fromloc   = LLI.Loc,
					@n_qty	     = Sum(U.Qty),
					@n_rowcnt    = 1
				FROM LOTxLOCxID  LLI(NOLOCK), UCC U(NOLOCK)
				WHERE LLI.LOT = U.LOT
				AND   LLI.LOC = U.LOC
				AND   LLI.ID  = U.ID
				AND   LLI.ID  = @c_fromid
				AND  LLI.Loc <> @c_toloc
				AND  dbo.fnc_RTrim(LLI.Lot)+ dbo.fnc_RTrim(LLI.Loc) + dbo.fnc_RTrim(LLI.ID) > @c_lotxlocxid
				AND  U.Status = '1'
				AND (U.UCCNO = @c_ucc01 OR U.UCCNO = @c_ucc02 OR U.UCCNO = @c_ucc03 OR U.UCCNO = @c_ucc04 OR
		             	     U.UCCNO = @c_ucc05 OR U.UCCNO = @c_ucc06 OR U.UCCNO = @c_ucc07 OR U.UCCNO = @c_ucc08 OR
			             U.UCCNO = @c_ucc09 OR U.UCCNO = @c_ucc10)
				GROUP BY LLI.LOT, LLI.LOC, LLI.ID, LLI.Storerkey, LLI.Sku
				ORDER BY LLI.LOT, LLI.LOC, LLI.ID 
	
				SET ROWCOUNT 0

				IF @n_rowcnt = 0 
				BEGIN
					BREAK
				END 

				SELECT @c_toid = ''

				EXECUTE nspItrnAddMove
					@n_itrnsysid	= NULL ,
					@c_storerkey	= @c_storerkey ,
					@c_sku		= @c_sku ,
					@c_lot		= @c_lot ,
					@c_fromloc	= @c_fromloc ,
					@c_fromid	= @c_fromid ,
					@c_toloc	= @c_toloc,
					@c_toid		= @c_toid ,
					@c_status	= '' ,
					@c_lottable01	= '' , 
					@c_lottable02	= '' , 
					@c_lottable03	= '' , 
					@d_lottable04	= NULL , 
					@d_lottable05	= NULL , 
					@n_casecnt	= 0 ,
					@n_innerpack	= 0 ,
					@n_qty		= @n_qty ,
					@n_pallet	= 0 ,
					@f_cube		= 0 ,
					@f_grosswgt	= 0 ,
					@f_netwgt	= 0 ,
					@f_otherunit1	= 0 ,
					@f_otherunit2	= 0 ,
					@c_sourcekey	= '' ,
					@c_sourcetype	= 'CTNPUTAWAY' ,
					@c_packkey	= '' ,
					@c_uom		= '' ,
					@b_uomcalc	= 1 ,
					@d_effectivedate= NULL,
					@c_itrnkey	= '',
	 				@b_success      = @b_success output,
					@n_err          = @n_err output,
					@c_errmsg       = @c_errmsg output

				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
	
				IF (@n_continue = 1 or @n_continue = 2)
				BEGIN 
					UPDATE UCC
					SET Loc = @c_toloc,
					    Id  = @c_toid,
						 Status = '2'
					WHERE Lot = @c_lot
					AND   Loc = @c_fromloc
					AND   ID  = @c_fromid
					AND   Status = '1'
					AND (UCCNO = @c_ucc01 OR UCCNO = @c_ucc02 OR UCCNO = @c_ucc03 OR UCCNO = @c_ucc04 OR
			             	     UCCNO = @c_ucc05 OR UCCNO = @c_ucc06 OR UCCNO = @c_ucc07 OR UCCNO = @c_ucc08 OR
				             UCCNO = @c_ucc09 OR UCCNO = @c_ucc10)
	
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
					IF @local_n_err <> 0
					BEGIN 
						SELECT @n_continue = 3
						SELECT @local_n_err = 77302
						SELECT @local_c_errmsg = convert(char(5),@local_n_err)
						SELECT @local_c_errmsg =
						': update of UCC table failed. (nsp_rfputaway) ' + ' ( ' +
						' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
					END  

				END 
			END -- END WHILE
		END
	END

	IF @n_continue=3  -- error occured - process and return
	BEGIN
		SELECT @b_success = 0
		IF @@trancount = 1 and @@trancount > @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@trancount > @n_starttcnt
			BEGIN
				COMMIT TRAN
			END
		END
	
		SELECT @n_err = @local_n_err
		SELECT @c_errmsg = @local_c_errmsg
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_rfputaway"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@trancount > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
   
END

GO