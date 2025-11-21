SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_rfpicknpackconfirmorder] (
	@c_storerkey	 NVARCHAR(15),
	@c_orderkey        NVARCHAR(10),
	@c_zone		 NVARCHAR(10),
	@c_pickdetailkey   NVARCHAR(10),
	@c_pickslipno	 NVARCHAR(10) Output,
	@c_labelno	 NVARCHAR(20) OUTPUT,
	@b_genlabel	 NVARCHAR(1),
	@b_Success   		int		 OUTPUT,
   @n_err       		int		 OUTPUT,
   @c_errmsg    	 NVARCHAR(250) OUTPUT
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/* 25 March 2004 WANYT Timberland FBR#20720: RF Stock Take Entry */
	declare @n_continue  		int,
		@n_starttcnt 		int,
		@local_n_err 		int,
		@local_c_errmsg  NVARCHAR(255),
		@n_cnt       		int,
		@n_rowcnt       	int,
		@c_status	 NVARCHAR(10),
		@d_scanoutdate		datetime,
		@b_newpickslipno	int,
		@n_cartonno			int,
		@c_button NVARCHAR(1)
		
			
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = ''


	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN
		SELECT @c_pickslipno = MAX(pickslipno)
		FROM Pickdetail (NOLOCK) JOIN Loc (NOLOCK)
			ON Pickdetail.Loc = Loc.Loc
		WHERE Pickdetail.Orderkey = @c_orderkey
			AND Loc.Putawayzone = @c_zone
	
		IF (dbo.fnc_RTrim(@c_pickslipno) = '' OR dbo.fnc_RTrim(@c_pickslipno) IS NULL) AND
		   NOT EXISTS(SELECT 1 FROM PackHeader (NOLOCK) 
			      WHERE  PickSlipNo = @c_pickslipno 
			      AND    Orderkey   = @c_orderkey)	
	
		BEGIN
			EXECUTE nspg_getkey
				"PickSlip" ,
				9 ,
				@c_pickslipno   Output ,
				@b_success      = @b_success output,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output
	
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
			ELSE 
			BEGIN
				SELECT @c_pickslipno = 'P' + @c_pickslipno
				SELECT @b_newpickslipno = 1

				-- update pickdetail
				UPDATE PICKDETAIL
				SET    PickSlipNo = @c_pickslipno,
				       EditWho    = sUser_sName(), 
				       EditDate   = GetDate(),
						 Trafficcop = NULL
				FROM PICKDETAIL JOIN LOC
					ON PICKDETAIL.Loc = LOC.Loc
				WHERE PICKDETAIL.OrderKey = @c_orderkey
					AND LOC.Putawayzone = @c_zone
					AND SUBSTRING(PICKDETAIL.SKU, 15, 1) <> '3'	 
					AND (PickSlipNo IS NULL OR PickSlipNo = '')
			END
		END 

		SELECT @local_n_err = @@error, @n_cnt = @@rowcount

		IF @local_n_err <> 0
		BEGIN 
			SELECT @n_continue = 3
			SELECT @local_n_err = 77301
			SELECT @local_c_errmsg = convert(char(5),@local_n_err)
			SELECT @local_c_errmsg =
			': Update of PICKDETAIL table failed. (nsp_rfpicknpackconfirmorder) ' + ' ( ' +
			' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
		END 
		
		IF (@n_continue = 1 OR @n_continue = 2) AND (@b_newpickslipno = 1)
		BEGIN	
			INSERT INTO PACKHEADER (PickSlipNo, 
						Storerkey, 
						Route, 
						Orderkey, 
						OrderRefNo, 
						Loadkey, 
						Consigneekey)
			SELECT  @c_pickslipno, 
				ORDERS.Storerkey, 
				ORDERS.Route, 
				ORDERS.Orderkey, 
				ORDERS.ExternOrderkey, 	
				ORDERS.UserDefine09,
				ORDERS.Consigneekey
			FROM ORDERS (NOLOCK)
			WHERE ORDERS.OrderKey = @c_orderkey		
	
			SELECT @local_n_err = @@error, @n_cnt = @@rowcount

			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 77303
				SELECT @local_c_errmsg = convert(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				': Insert of PACKHEADER table failed. (nsp_rfpicknpackconfirmorder) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			END 
		END 

/*
		IF (@n_continue = 1 OR @n_continue = 2) 
		BEGIN	
							
			UPDATE  ORDERS
			SET 	Status   = '3',
				EditWho  = sUser_sName(),
				EditDate = GetDate(),
				Trafficcop = null
			WHERE Orderkey = @c_orderkey
			 
			SELECT @local_n_err = @@error, @n_cnt = @@rowcount

			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 77304
				SELECT @local_c_errmsg = convert(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				': Update of Orders table failed. (nsp_rfpicknpackconfirmorder) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			END 
		END 
*/
		IF (@n_continue = 1 OR @n_continue = 2) AND (@b_newpickslipno = 1)
		BEGIN	
			INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID)
			VALUES ( @c_pickslipno, GetDate(), sUser_sName())

			SELECT @local_n_err = @@error, @n_cnt = @@rowcount

			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 77302
				SELECT @local_c_errmsg = convert(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				': Insert of PICKINGINFO table failed. (nsp_rfpicknpackconfirmorder) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			END 
		END 
	END 

	IF (@n_continue = 1 OR @n_continue = 2) AND (@b_genlabel = '1')
	BEGIN
		EXECUTE nsp_genlabelno
			@c_orderkey,
			@c_storerkey  ,
			@c_labelno     = @c_labelno OUTPUT,
			@n_cartonno		= @n_cartonno OUTPUT,
			@b_success     = @b_success OUTPUT,
			@c_button		= '',
			@n_err         = @n_err     OUTPUT,
			@c_errmsg      = @c_errmsg  OUTPUT

		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_rfpicknpackconfirmorder"
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