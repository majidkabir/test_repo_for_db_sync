SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nsp_rfstocktake] (
	@c_cckey       NVARCHAR(10),
	@c_ccdetailkey NVARCHAR(10),
	@n_count       int,
        @c_loc         NVARCHAR(10),
	@c_uccno       NVARCHAR(20), 
	@c_storerkey   NVARCHAR(15),
	@c_sku         NVARCHAR(20),  
	@n_qty         int,
	@c_lottable01  NVARCHAR(18),
	@c_lottable02  NVARCHAR(18),
	@c_lottable03  NVARCHAR(18),
	@dt_lottable04  datetime,
	@dt_lottable05  datetime
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/* 24 March 2004 WANYT Timberland FBR#20720: RF Stock Take Entry */
	declare @n_continue  		int,
		@n_starttcnt 		int,
		@b_success   		int,
		@n_err       		int,
		@c_errmsg        NVARCHAR(255),
		@local_n_err 		int,
		@local_c_errmsg  NVARCHAR(255),
		@n_cnt       		int,
		@n_rowcnt       	int,
		@c_lot   	 NVARCHAR(10),
		@n_insertqty		int,
		@b_isok			int,
		@c_status               NVARCHAR(1),
		@c_entryccdetailkey NVARCHAR(10),
		@b_update	int

	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = '',@b_update=0

	IF ISDATE(@dt_lottable04) <> 1
		SELECT @dt_lottable04 = NULL

	SELECT @n_insertqty = @n_qty
	SELECT @c_status    = '1'

	IF dbo.fnc_RTrim(@c_uccno) IS NULL
	BEGIN  
	 	SELECT @c_uccno = ' '
	END 

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN			
		SELECT @n_rowcnt = 1	
		FROM  CCDETAIL (NOLOCK)
		WHERE CCKey = @c_cckey
			AND   CCDetailkey = @c_ccdetailkey
			AND   (Sku <> @c_sku
			OR		 RefNo <> @c_uccno
			OR     1 <> CASE @n_count 
								WHEN 1 THEN CASE 
												WHEN (Lottable01 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								   			WHEN (Lottable01 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND (Lottable01 = @c_lottable01) THEN 1
								   			ELSE 2 
											END
								ELSE 1
				    		END
			OR     1 <> CASE @n_count WHEN 1 THEN CASE WHEN (Lottable02 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								   WHEN (Lottable02 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								        (Lottable02 = @c_lottable02) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 1 THEN CASE WHEN (Lottable03 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								   WHEN (Lottable03 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								        (Lottable03 = @c_lottable03) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 1 THEN CASE WHEN (Lottable04 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								   WHEN (Lottable04 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								        (Lottable04 = @dt_lottable04) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 1 THEN CASE WHEN (Lottable05 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
					 			   WHEN (Lottable05 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								        (Lottable05 = @dt_lottable05) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END							
			OR     1 <> CASE @n_count WHEN 2 THEN CASE WHEN (Lottable01_cnt2 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								   WHEN (Lottable01_cnt2 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND 
								        (Lottable01_cnt2 = @c_lottable01) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 2 THEN CASE WHEN (Lottable02_cnt2 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								   WHEN (Lottable02_cnt2 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								        (Lottable02_cnt2 = @c_lottable02) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 2 THEN CASE WHEN (Lottable03_cnt2 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								   WHEN (Lottable03_cnt2 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								        (Lottable03_cnt2 = @c_lottable03) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 2 THEN CASE WHEN (Lottable04_cnt2 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								   WHEN (Lottable04_cnt2 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								        (Lottable04_cnt2 = @dt_lottable04) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 2 THEN CASE WHEN (Lottable05_cnt2 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
					 			   WHEN (Lottable05_cnt2 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								        (Lottable05_cnt2 = @dt_lottable05) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END		
			OR     1 <> CASE @n_count WHEN 3 THEN CASE WHEN (Lottable01_cnt3 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								   WHEN (Lottable01_cnt3 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND 
								        (Lottable01_cnt3 = @c_lottable01) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 3 THEN CASE WHEN (Lottable02_cnt3 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								   WHEN (Lottable02_cnt3 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								        (Lottable02_cnt3 = @c_lottable02) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 3 THEN CASE WHEN (Lottable03_cnt3 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								   WHEN (Lottable03_cnt3 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								        (Lottable03_cnt3 = @c_lottable03) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 3 THEN CASE WHEN (Lottable04_cnt3 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								   WHEN (Lottable04_cnt3 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								        (Lottable04_cnt3 = @dt_lottable04) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END
			OR     1 <> CASE @n_count WHEN 3 THEN CASE WHEN (Lottable05_cnt3 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
					 			   WHEN (Lottable05_cnt3 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								        (Lottable05_cnt3 = @dt_lottable05) THEN 1
								   ELSE 2 END
				    ELSE 1
				    END	)

		IF @n_rowcnt = 1 
		BEGIN
			SELECT @c_entryccdetailkey = @c_ccdetailkey
			
			-- Check entered stocktake rec exists in ccdetail
			SELECT @n_rowcnt = 0,
			       @c_ccdetailkey = CCDetailKey	
			FROM  CCDETAIL (NOLOCK)
			WHERE CCKey     = @c_cckey
			AND   Storerkey = @c_storerkey
			AND   Sku       = @c_sku
			AND   Loc       = @c_loc
			AND   1 = CASE @n_count WHEN 1 THEN CASE WHEN (Lottable01 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								 WHEN (Lottable01 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND 
								      (Lottable01 = @c_lottable01) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 1 THEN CASE WHEN (Lottable02 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								 WHEN (Lottable02 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								      (Lottable02 = @c_lottable02) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 1 THEN CASE WHEN (Lottable03 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								 WHEN (Lottable03 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								      (Lottable03 = @c_lottable03) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END 
			AND   1 = CASE @n_count WHEN 1 THEN CASE WHEN (Lottable04 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								 WHEN (Lottable04 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								      (Lottable04 = @dt_lottable04) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END 
			AND   1 = CASE @n_count WHEN 1 THEN CASE WHEN (Lottable05 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
								 WHEN (Lottable05 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								      (Lottable05 = @dt_lottable05) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END		
			AND   1 = CASE @n_count WHEN 2 THEN CASE WHEN (Lottable01_Cnt2 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								 WHEN (Lottable01_Cnt2 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND 
								      (Lottable01_Cnt2 = @c_lottable01) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 2 THEN CASE WHEN (Lottable02_Cnt2 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								 WHEN (Lottable02_Cnt2 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								      (Lottable02_Cnt2 = @c_lottable02) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 2 THEN CASE WHEN (Lottable03_Cnt2 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								 WHEN (Lottable03_Cnt2 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								      (Lottable03_Cnt2 = @c_lottable03) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 2 THEN CASE WHEN (Lottable04_Cnt2 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								 WHEN (Lottable04_Cnt2 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								      (Lottable04_Cnt2 = @dt_lottable04) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 2 THEN CASE WHEN (Lottable05_Cnt2 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
								 WHEN (Lottable05_Cnt2 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								      (Lottable05_Cnt2 = @dt_lottable05) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END		
			AND   1 = CASE @n_count WHEN 3 THEN CASE WHEN (Lottable01_Cnt3 IS NULL AND @c_lottable01 IS NULL) THEN 1 
								 WHEN (Lottable01_Cnt3 IS NOT NULL AND @c_lottable01 IS NOT NULL) AND 
								      (Lottable01_Cnt3 = @c_lottable01) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 3 THEN CASE WHEN (Lottable02_Cnt3 IS NULL AND @c_lottable02 IS NULL) THEN 1 
								 WHEN (Lottable02_Cnt3 IS NOT NULL AND @c_lottable02 IS NOT NULL) AND 
								      (Lottable02_Cnt3 = @c_lottable02) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 3 THEN CASE WHEN (Lottable03_Cnt3 IS NULL AND @c_lottable03 IS NULL) THEN 1 
								 WHEN (Lottable03_Cnt3 IS NOT NULL AND @c_lottable03 IS NOT NULL) AND 
								      (Lottable03_Cnt3 = @c_lottable03) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 3 THEN CASE WHEN (Lottable04_Cnt3 IS NULL AND @dt_lottable04 IS NULL) THEN 1 
								 WHEN (Lottable04_Cnt3 IS NOT NULL AND @dt_lottable04 IS NOT NULL) AND 
								      (Lottable04_Cnt3 = @dt_lottable04) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND   1 = CASE @n_count WHEN 3 THEN CASE WHEN (Lottable05_Cnt3 IS NULL AND @dt_lottable05 IS NULL) THEN 1 
								 WHEN (Lottable05_Cnt3 IS NOT NULL AND @dt_lottable05 IS NOT NULL) AND 
								      (Lottable05_Cnt3 = @dt_lottable05) THEN 1
								 ELSE 2 END
				  ELSE 1
				  END
			AND Refno = @c_uccno	
			
			IF @n_rowcnt = 1 
			BEGIN
				SELECT @n_qty = 0
			END	
			ELSE
			BEGIN
				IF @c_entryccdetailkey <> @c_ccdetailkey
				BEGIN
					-- cancel retrieved/original stocktake data
					UPDATE CCDETAIL
				 	SET   Qty             = CASE @n_count WHEN 1 THEN 0 ELSE Qty END,
					      Qty_Cnt2        = CASE @n_count WHEN 2 THEN 0 ELSE Qty_Cnt2 END,
					      Qty_Cnt3        =	CASE @n_count WHEN 3 THEN 0 ELSE Qty_Cnt3 END,
					      STATUS          = CASE lot WHEN ' ' THEN 1 ELSE 2 END,
					      EditDate	      = GetDate(),
					      EditWho         = Suser_Sname()	
					WHERE CCKey           = @c_cckey
					AND   ccdetailkey     = @c_entryccdetailkey
					AND   (Qty             <> CASE @n_count WHEN 1 THEN 0 ELSE Qty END
					OR     Qty_Cnt2        <> CASE @n_count WHEN 2 THEN 0 ELSE Qty_Cnt2 END
					OR     Qty_Cnt3        <> CASE @n_count WHEN 3 THEN 0 ELSE Qty_Cnt3 END)
					
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
					IF @n_cnt > 0
						SELECT @b_update = 1

					IF @local_n_err <> 0
					BEGIN 
						SELECT @n_continue = 3
						SELECT @local_n_err = 77301
						SELECT @local_c_errmsg = convert(char(5),@local_n_err)
						SELECT @local_c_errmsg =
						': update of CCDETAIL table failed. (nsp_rfstocktake) ' + ' ( ' +
						' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
					END 
				END 
			END 
		END

		IF (@n_continue = 1 OR @n_continue = 2) 
		BEGIN
			-- When @n_qty = 0, it cancel the retrieved/original stocktake data
			-- When @n_qty > 0, it updates the found data in the ccdetail
		
			UPDATE CCDETAIL
		 	SET   Qty             = CASE @n_count WHEN 1 THEN @n_qty ELSE Qty END,
			      Qty_Cnt2        = CASE @n_count WHEN 2 THEN @n_qty ELSE Qty_Cnt2 END,
			      Qty_Cnt3        =	CASE @n_count WHEN 3 THEN @n_qty ELSE Qty_Cnt3 END,
			      STATUS          = CASE Lot WHEN ' ' THEN 1 ELSE 2 END,
			      EditDate	      = GetDate(),
			      EditWho         = Suser_Sname()	
			WHERE CCKey           = @c_cckey
			AND   ccdetailkey     = @c_ccdetailkey
			AND   (Qty             <> CASE @n_count WHEN 1 THEN @n_qty ELSE Qty END
			OR     Qty_Cnt2        <> CASE @n_count WHEN 2 THEN @n_qty ELSE Qty_Cnt2 END
			OR     Qty_Cnt3        <> CASE @n_count WHEN 3 THEN @n_qty ELSE Qty_Cnt3 END)
	
			SELECT @local_n_err = @@error, @n_cnt = @@rowcount, @b_update = 1	
			-- IF @n_cnt > 0
			--	SELECT @b_update = 1

			IF @n_qty = 0
				SELECT @c_ccdetailkey = NULL

			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 77302
				SELECT @local_c_errmsg = convert(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				': update of CCDETAIL table failed. (nsp_rfstocktake) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			END 
		END	

		--Modified by YTWan on 15-Jul-2004 for if loc not exists in ccdetail - START
		IF (@n_continue = 1 OR @n_continue = 2) AND (@c_ccdetailkey ='')
			SELECT @c_ccdetailkey = NULL
		--Modified by YTWan on 15-Jul-2004 for if loc not exists in ccdetail - END

		IF (@n_continue = 1 OR @n_continue = 2) AND (@b_update = 0 OR @c_ccdetailkey IS NULL OR @c_ccdetailkey = NULL)
		BEGIN
			EXECUTE nspg_getkey
				'CCDETAILKEY' ,
				10 ,
				@c_ccdetailkey   Output ,
				@b_success      = @b_success output,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output

			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
			
			IF (@n_continue = 1 or @n_continue = 2)
			BEGIN 

				INSERT INTO CCDETAIL  ( cckey,
						 	ccdetailkey,
							storerkey,
							sku,
							lot,
							loc,
							id,
							status,
							lottable01,
							lottable02,
							lottable03,
							lottable04,
							lottable05,
							qty,
							lottable01_cnt2,
							lottable02_cnt2,
							lottable03_cnt2,
							lottable04_cnt2,
							lottable05_cnt2,
							qty_cnt2,
							lottable01_cnt3,
							lottable02_cnt3,
							lottable03_cnt3,
							lottable04_cnt3,
							lottable05_cnt3,
							qty_cnt3,
							refno)							
				VALUES ( @c_cckey, 
					 @c_ccdetailkey,
					 @c_storerkey,
					 @c_sku,
					 ' ',
					 @c_loc,
					 ' ',
					 '1',
					 CASE @n_count WHEN 1 THEN @c_lottable01 ELSE NULL END,
					 CASE @n_count WHEN 1 THEN @c_lottable02 ELSE NULL END,
					 CASE @n_count WHEN 1 THEN @c_lottable03 ELSE NULL END,
					 CASE @n_count WHEN 1 THEN @dt_lottable04 ELSE NULL END,
					 CASE @n_count WHEN 1 THEN @dt_lottable05 ELSE NULL END,
					 CASE @n_count WHEN 1 THEN @n_insertqty ELSE 0 END,
					 CASE @n_count WHEN 2 THEN @c_lottable01 ELSE NULL END,
					 CASE @n_count WHEN 2 THEN @c_lottable02 ELSE NULL END,
					 CASE @n_count WHEN 2 THEN @c_lottable03 ELSE NULL END,
					 CASE @n_count WHEN 2 THEN @dt_lottable04 ELSE NULL END,
					 CASE @n_count WHEN 2 THEN @dt_lottable05 ELSE NULL END,
					 CASE @n_count WHEN 2 THEN @n_insertqty ELSE 0 END,
					 CASE @n_count WHEN 3 THEN @c_lottable01 ELSE NULL END,
					 CASE @n_count WHEN 3 THEN @c_lottable02 ELSE NULL END,
					 CASE @n_count WHEN 3 THEN @c_lottable03 ELSE NULL END,
					 CASE @n_count WHEN 3 THEN @dt_lottable04 ELSE NULL END,
					 CASE @n_count WHEN 3 THEN @dt_lottable05 ELSE NULL END,
					 CASE @n_count WHEN 3 THEN @n_insertqty ELSE 0 END,
					 @c_uccno)
				SELECT @local_n_err = @@error, @n_cnt = @@rowcount

				IF @local_n_err <> 0
				BEGIN 
					SELECT @n_continue = 3
					SELECT @local_n_err = 77303
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					': Insert of CCDETAIL table failed. (nsp_rfstocktake) ' + ' ( ' +
					' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
				END 
			END 
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_rfstocktake"
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