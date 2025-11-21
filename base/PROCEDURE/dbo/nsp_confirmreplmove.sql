SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_confirmreplmove     									*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                    			*/
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*																							   */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Rev Purposes                                   */
/* 25/08/2006   James    1.8 change select condition from               */
/*                            from originalqty to openqty               */ 
/************************************************************************/

CREATE PROC [dbo].[nsp_confirmreplmove] (
	@c_storerkey NVARCHAR(15),
	@c_sku		 NVARCHAR(20),
	@c_lot	      NVARCHAR(10),
	@c_fromloc	 NVARCHAR(10),
	@c_toloc		 NVARCHAR(10),
	@c_id	         NVARCHAR(18),
	@n_uccqty		int,
	@c_uccno		 NVARCHAR(20),
	@c_wavekey	 NVARCHAR(10),
	@b_Success   	int        OUTPUT,
   @n_err       	int        OUTPUT,
   @c_errmsg     NVARCHAR(250)  OUTPUT	 
) 
as
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	/* 5 April 2004 WANYT Timberland FBR#20679: RF Replenishment With UCC & UCC PICK */
   /* 4 Oct   2004 WANYT SOS#27925 */
	declare @n_continue  		int,
		@n_starttcnt 		int,
		@local_n_err 		int,
		@local_c_errmsg  NVARCHAR(255),
		@n_cnt       		int,
		@n_rowcnt       	int,
		@c_key		 NVARCHAR(15),
		@c_orderkey	 NVARCHAR(10),
		@c_orderlineno	 NVARCHAR(5),
		@n_ordavailqty		int,
		@c_uom		 NVARCHAR(10),
		@c_packkey	 NVARCHAR(10),
		@n_insertqty		int,
		@c_pickdetailkey NVARCHAR(10),
		@c_caseid	 NVARCHAR(10),
		@c_cartongroup	 NVARCHAR(10),
		@n_uomqty		int,
		@c_Zone NVARCHAR(10),
		@c_PickSlipNo NVARCHAR(10),
		@c_lottable02 NVARCHAR(18),
		@c_loseid NVARCHAR(1),
		@n_QtyInPickLOC int  -- SOS38467
			
	select @n_starttcnt=@@trancount , @n_continue=1, @local_n_err = 0, @local_c_errmsg = '',
		@b_success = 0, @n_err = 0, @c_errmsg = ''
		
	SELECT @n_insertqty = 0, @n_ordavailqty = 0, @c_key = ''
	
	BEGIN TRANSACTION

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN -- do the invty move
		EXECUTE nspItrnAddMove
 		NULL,
 		@c_storerkey,
 		@c_sku,
 		@c_lot,
 		@c_fromloc,
 		@c_id,
 		@c_toloc,
 		@c_id,
 		'OK',
 		'',
 		'',
 		'',
 		NULL,
 		NULL,
 		0,
 		0,
 		@n_uccqty,
 		0,
 		0,
 		0,
 		0,
 		0,
 		0,
 		@c_uccno,
 		'UCCREPLEN',
 		'',
 		'',
 		1,
 		NULL,
 		'',
 		@b_Success  OUTPUT,
 		@n_err      OUTPUT,
 		@c_errmsg   OUTPUT
      IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Replen Move failed. (nsp_confirmreplmove)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END -- do the invty move

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN -- update ucc
		UPDATE UCC
		SET loc = @c_toloc,
			EditDate = getdate(),
			EditWho = Suser_Sname()
		WHERE uccno = @c_uccno
		AND	loc = @c_fromloc
		AND	sku = @c_sku
		AND	storerkey = @c_storerkey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UCC table update failed. (nsp_confirmreplmove)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
	END -- update ucc

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN -- update replenishment
		UPDATE REPLENISHMENT
		SET Confirmed = 'Y',
			ToLoc = @c_toloc,
			EditDate = getdate(),
			EditWho = Suser_Sname(),
			Remark = 'Success - UCC Replen.',
			ArchiveCop = NULL
		WHERE RefNo = @c_uccno
		AND Confirmed = 'S'
-- Start : SOS38467
		AND Sku = @c_sku
		AND Lot = @c_lot
		AND FromLoc = @c_fromloc
-- SOS40045		
--	AND ToLoc  = @c_toloc 
		AND ID = @c_ID
-- End : SOS38467
		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Replenishment table update failed. (nsp_confirmreplmove)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
	END -- update replenishment

	-- Start : SOS38467
	-- Get QtyLeftToFulfill for Pick face loc
	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN 
		SELECT @n_QtyInPickLOC = ISNULL(SUM(QtyInPickLOC), 0)
		FROM   REPLENISHMENT (NOLOCK)
		JOIN   SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = REPLENISHMENT.Storerkey 
									AND SKUXLOC.SKU = REPLENISHMENT.SKU AND SKUXLOC.Loc = REPLENISHMENT.ToLoc
									AND (SKUXLOC.LocationType = 'CASE' OR SKUXLOC.LocationType = 'PICK')
		WHERE REPLENISHMENT.RefNo = @c_uccno	
		AND 	REPLENISHMENT.Sku = @c_sku
		AND 	REPLENISHMENT.Lot = @c_lot
		AND 	REPLENISHMENT.FromLoc = @c_fromloc
		AND 	REPLENISHMENT.ToLoc  = @c_toloc
		AND 	REPLENISHMENT.ID = @c_ID
	END 
	-- End : SOS38467

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN -- allocate
		SELECT @c_lottable02 = lottable02
		FROM LOTATTRIBUTE (NOLOCK)
		WHERE lot = @c_lot
			
		WHILE (1=1)
		BEGIN -- while
			SET ROWCOUNT 1
			IF @c_lottable02 = 'AP'
			BEGIN
				SELECT @c_orderkey = ORDERDETAIL.Orderkey,
					@c_orderlineno = ORDERDETAIL.OrderLineNumber,
					@n_ordavailqty = ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked,
					@c_uom = CASE ORDERDETAIL.UOM WHEN PACK.PACKUOM1 THEN '2'
							      WHEN PACK.PACKUOM2 THEN '3'
							      WHEN PACK.PACKUOM3 THEN '6'
							      WHEN PACK.PACKUOM4 THEN '1'
					 			END,
					@n_uomqty = CASE ORDERDETAIL.UOM WHEN PACK.PACKUOM1 THEN ABS(@n_ordavailqty /PACK.CaseCnt)
								      WHEN PACK.PACKUOM2 THEN ABS((ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) /PACK.InnerPack)
								      WHEN PACK.PACKUOM3 THEN (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked)
								      WHEN PACK.PACKUOM4 THEN ABS((ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) /PACK.Pallet)
					 				END,
					@c_packkey = ORDERDETAIL.Packkey,
					@c_key = ORDERDETAIL.Orderkey + ORDERDETAIL.OrderLineNumber
				FROM WAVEDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), PACK (NOLOCK) --, SKU (NOLOCK) 
				WHERE WAVEDETAIL.Orderkey   = ORDERDETAIL.Orderkey
				AND   ORDERDETAIL.Packkey   = PACK.Packkey
				AND   WAVEDETAIL.Wavekey    = @c_wavekey
				AND   ORDERDETAIL.Storerkey = @c_storerkey
				AND   ORDERDETAIL.Sku       = @c_sku
				AND	ORDERDETAIL.Lottable02 = @c_lottable02
--				AND   ORDERDETAIL.OriginalQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked <= @n_uccqty   /* 04-Oct-2004 YTWAN SOS#27925 */
--				AND	ORDERDETAIL.OriginalQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0	--edit by james on 25/08/2006 sos57318
				AND	ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0	
--				AND   ORDERDETAIL.Orderkey + ORDERDETAIL.OrderLineNumber > @c_key
--				ORDER BY ORDERDETAIL.Lottable02 DESC, ORDERDETAIL.Orderkey, ORDERDETAIL.OrderLineNumber
--				ORDER BY ORDERDETAIL.Orderkey, ORDERDETAIL.OrderLineNumber
			END
				
			IF @@ROWCOUNT = 0 OR @c_lottable02 <> 'AP'
			BEGIN
				SELECT  @c_orderkey    = ORDERDETAIL.Orderkey,
				     	@c_orderlineno = ORDERDETAIL.OrderLineNumber,
					@n_ordavailqty = ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked,
					@c_uom	       = CASE ORDERDETAIL.UOM WHEN PACK.PACKUOM1 THEN '2'
									      WHEN PACK.PACKUOM2 THEN '3'
									      WHEN PACK.PACKUOM3 THEN '6'
									      WHEN PACK.PACKUOM4 THEN '1'
							 END,
					@n_uomqty      = CASE ORDERDETAIL.UOM WHEN PACK.PACKUOM1 THEN ABS(@n_ordavailqty /PACK.CaseCnt)
									      WHEN PACK.PACKUOM2 THEN ABS((ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) /PACK.InnerPack)
									      WHEN PACK.PACKUOM3 THEN (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked)
									      WHEN PACK.PACKUOM4 THEN ABS((ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) /PACK.Pallet)
							 END,
					@c_packkey     = ORDERDETAIL.Packkey,
					@c_key         = ORDERDETAIL.Orderkey + ORDERDETAIL.OrderLineNumber
				FROM WAVEDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), PACK (NOLOCK) --, SKU (NOLOCK) 
				WHERE WAVEDETAIL.Orderkey   = ORDERDETAIL.Orderkey
				AND   ORDERDETAIL.Packkey   = PACK.Packkey
				AND   WAVEDETAIL.Wavekey    = @c_wavekey
				AND   ORDERDETAIL.Storerkey = @c_storerkey
				AND   ORDERDETAIL.Sku       = @c_sku
				AND	ORDERDETAIL.Lottable02 = ''
--				AND   ORDERDETAIL.OriginalQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked <= @n_uccqty  /* 04-Oct-2004 YTWAN SOS#27925 */
--				AND	ORDERDETAIL.OriginalQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0	--edit by james on 25/08/2006 sos57318
				AND	ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked > 0	
--				AND   ORDERDETAIL.Orderkey + ORDERDETAIL.OrderLineNumber > @c_key
--				ORDER BY ORDERDETAIL.Orderkey, ORDERDETAIL.OrderLineNumber
				
				IF @@ROWCOUNT = 0
				BEGIN
					SET ROWCOUNT 0
					BREAK
				END
			END
			SET ROWCOUNT 0
	
			IF @n_ordavailqty > 0 AND @n_uccqty > 0
			BEGIN -- @n_ordavailqty > 0 AND @n_uccqty > 0

				-- 04-Oct-2004 YTWAN SOS#27925 - START
				IF @n_uccqty < @n_ordavailqty
				BEGIN
					SELECT @n_ordavailqty = @n_uccqty
				END
				-- 04-Oct-2004 YTWAN SOS#27925 - END

				-- Start : SOS38467
				IF @n_QtyInPickLOC < @n_ordavailqty AND @n_QtyInPickLOC > 0
				BEGIN
					SELECT @n_ordavailqty = @n_QtyInPickLOC
				END 
				-- End : SOS38467

				EXECUTE nspg_getkey
					'PICKDETAILKEY' ,
					10 ,
					@c_pickdetailkey   Output ,
					@b_success      = @b_success output,
					@n_err          = @n_err output,
					@c_errmsg       = @c_errmsg output
	
				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
					
				IF (@n_continue = 1 OR @n_continue = 2) 
				BEGIN -- insert pickdetail
					SELECT @c_Zone = PutawayZone,
							@c_loseid = LoseID
					FROM LOC (NOLOCK)
					WHERE Loc = @c_toloc
	
					SELECT @c_PickSlipNo = ISNULL(MAX(pickslipno), '')
					FROM Pickdetail (NOLOCK) JOIN Loc (NOLOCK)
						ON Pickdetail.Loc = Loc.Loc
					WHERE Pickdetail.Orderkey = @c_OrderKey
						AND Loc.Putawayzone = @c_Zone
	
					IF @c_loseid = '1'
						SELECT @c_id = ''

					INSERT INTO PICKDETAIL( Pickdetailkey, 
						Caseid, 
						PickHeaderKey,
						Orderkey,
						OrderlineNumber,
						Storerkey, 
						Sku,
						UOM,
						UOMQty,
						Packkey,
						Lot,
						Loc,
						ID, 
						Qty,
						Wavekey,
						PickSlipNo,
						CartonType)
					VALUES( @c_pickdetailkey, 
						'',
						'',
						@c_orderkey,
						@c_orderlineno,
						@c_storerkey,
						@c_sku,
						@c_uom,
						@n_uomqty,
						@c_packkey,
						@c_lot,
						@c_toloc,
						@c_id,
						@n_ordavailqty,
						@c_wavekey, 
						@c_PickSlipNo,
						'REPLEN')	
				
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
					IF @local_n_err <> 0
					BEGIN 
						SELECT @n_continue = 3
						SELECT @local_n_err = 77301
						SELECT @local_c_errmsg = convert(char(5),@local_n_err)
						SELECT @local_c_errmsg =
						': Insert of Pickdetail table failed. (nsp_confirmreplmove) ' + ' ( ' +
						' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
					END
					ELSE
					BEGIN
						SELECT @n_uccqty = @n_uccqty - @n_ordavailqty

						-- 04-Oct-2004 YTWAN SOS#27925 - START
						IF @n_uccqty <= 0 BREAK
						-- 04-Oct-2004 YTWAN SOS#27925 - END

					END
				END -- insert pickdetail
			ELSE 
				BREAK
			END -- @n_ordavailqty > 0 AND @n_uccqty > 0 		   	
		END -- while
	END -- allocate
	
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_confirmreplmove'
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
END -- main

GO