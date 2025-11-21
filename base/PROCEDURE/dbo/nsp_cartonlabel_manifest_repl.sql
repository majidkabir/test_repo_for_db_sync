SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_cartonlabel_manifest_repl] (
	@c_batchno	 NVARCHAR(20),
	@c_uccno1	 NVARCHAR(20),
	@c_uccno2	 NVARCHAR(20),
	@c_uccno3	 NVARCHAR(20),
	@c_uccno4	 NVARCHAR(20),
	@c_uccno5	 NVARCHAR(20),
	@c_uccno6	 NVARCHAR(20),
	@c_uccno7	 NVARCHAR(20),
	@c_uccno8	 NVARCHAR(20),
	@c_uccno9	 NVARCHAR(20),
	@c_uccno10	 NVARCHAR(20)
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/* 5 April 2004 WANYT Timberland FBR#20679: RF Replenishment With UCC and UCC Pick */
	declare @n_continue  		int,
		@n_starttcnt 		int,
		@local_n_err 		int,
		@local_c_errmsg  NVARCHAR(255),
		@n_cnt       		int,
		@n_rowcnt       	int,
		@b_success		int,
		@n_err			int,
		@c_errmsg	 NVARCHAR(255)
		

	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = ''

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN	
		IF dbo.fnc_RTrim(@c_uccno1) IS NULL AND dbo.fnc_RTrim(@c_uccno2) IS NULL AND dbo.fnc_RTrim(@c_uccno3) IS NULL AND
		   dbo.fnc_RTrim(@c_uccno4) IS NULL AND dbo.fnc_RTrim(@c_uccno5) IS NULL AND dbo.fnc_RTrim(@c_uccno6) IS NULL AND 
                   dbo.fnc_RTrim(@c_uccno7) IS NULL AND dbo.fnc_RTrim(@c_uccno8) IS NULL AND dbo.fnc_RTrim(@c_uccno9) IS NULL AND 
                   dbo.fnc_RTrim(@c_uccno10) IS NULL	
		BEGIN
			SELECT PACKHEADER.PickSlipNo,
				PACKHEADER.OrderRefNo,
				PACKDETAIL.LabelNo,
				PACKDETAIL.CartonNo,
				PACKDETAIL.Sku, 
				(SELECT ISNULL(MAX(P2.CartonNo), 0) 
				FROM PACKDETAIL P2 (NOLOCK) 
				WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
				AND P2.RefNo = REPLENISHMENT.RefNo
				AND REPLENISHMENT.ReplenishmentGroup = @c_batchno
				HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)
											WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) as CartonMax,
				SUM(PACKDETAIL.Qty) as Qty,
				CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,
				ORDERS.UserDefine04,
				(SELECT COUNT(1)
				FROM ORDERDETAIL (NOLOCK)
				WHERE ORDERDETAIL.OrderKey = PACKHEADER.OrderKey
					AND UserDefine05 > '')as PriceLabel
			FROM PACKHEADER (NOLOCK) 
			JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			JOIN ORDERS (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
			JOIN REPLENISHMENT (NOLOCK) ON (REPLENISHMENT.RefNo = PACKDETAIL.RefNo)
			WHERE REPLENISHMENT.ReplenishmentGroup = @c_batchno
				AND REPLENISHMENT.ToLoc = 'PICK'
			GROUP BY PACKHEADER.PickSlipNo, 
				 PACKHEADER.Orderkey,
				 PACKHEADER.OrderRefNo,
				 PACKDETAIL.LabelNo,
				 PACKDETAIL.CartonNo,
				 PACKDETAIL.Sku,
				 ORDERS.UserDefine04,
				 REPLENISHMENT.RefNo,
				 REPLENISHMENT.ReplenishmentGroup,
			    ORDERS.UserDefine05
		END 
		ELSE
		BEGIN
			SELECT PACKHEADER.PickSlipNo,
				PACKHEADER.OrderRefNo,
				PACKDETAIL.LabelNo,
				PACKDETAIL.CartonNo,
				PACKDETAIL.Sku, 
				(SELECT ISNULL(MAX(P2.CartonNo), 0) 
				FROM PACKDETAIL P2 (NOLOCK) 
				WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
				AND P2.RefNo = REPLENISHMENT.RefNo
				AND REPLENISHMENT.ReplenishmentGroup = @c_batchno
				HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)
											WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) as CartonMax,
				SUM(PACKDETAIL.Qty) as Qty,
				CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,
				ORDERS.UserDefine04,
				(SELECT COUNT(1)
				FROM ORDERDETAIL (NOLOCK)
				WHERE ORDERDETAIL.OrderKey = PACKHEADER.OrderKey
					AND UserDefine05 > '')as PriceLabel
			FROM PACKHEADER (NOLOCK) 
			JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			JOIN ORDERS (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
			JOIN REPLENISHMENT (NOLOCK) ON (REPLENISHMENT.RefNo = PACKDETAIL.RefNo)
			WHERE REPLENISHMENT.ReplenishmentGroup = @c_batchno
				AND REPLENISHMENT.ToLoc = 'PICK'
				AND ( REPLENISHMENT.RefNo = @c_uccno1 
						OR    REPLENISHMENT.RefNo = @c_uccno2
						OR    REPLENISHMENT.RefNo = @c_uccno3
						OR    REPLENISHMENT.RefNo = @c_uccno4
						OR    REPLENISHMENT.RefNo = @c_uccno5
						OR    REPLENISHMENT.RefNo = @c_uccno6
						OR    REPLENISHMENT.RefNo = @c_uccno7 
						OR    REPLENISHMENT.RefNo = @c_uccno8
						OR    REPLENISHMENT.RefNo = @c_uccno9
						OR    REPLENISHMENT.RefNo = @c_uccno10 )
			GROUP BY PACKHEADER.PickSlipNo, 
				PACKHEADER.Orderkey,
				PACKHEADER.OrderRefNo,
				PACKDETAIL.LabelNo,
				PACKDETAIL.CartonNo,
				PACKDETAIL.Sku,
				ORDERS.UserDefine04,
				REPLENISHMENT.RefNo,
				REPLENISHMENT.ReplenishmentGroup,
				ORDERS.UserDefine05
		END
	END 
END

GO