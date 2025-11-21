SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/
/* Stored Proc : nsp_GetPickSlipXD07 	                           		*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: 		                                                   */
/*                                                                      */
/* Purpose: PickSlip Report                              					*/
/*                                                                      */
/* Called By: r_dw_print_pickxdorder07						                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author        	Purposes                                  */
/* 2007-04-05	ONG01				SOS#71903 - Add Column POTYPE					*/
/* 2007-07-11	LEONG				SOS#79918 - Change Join Table					*/
/* 2008-05-08  TLTING         Avoid return multiple result in LEFT JOIN */
/* 2008-09-04  Vanessa        SOS#113720                -- (Vanessa01)  */
/*                            Replace @c_pickheaderkey prefix 'X' as 'P'*/
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD07] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
AS
BEGIN
-- Type = P for ExternPOKey, L for LoadKey
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE @c_pickheaderkey NVARCHAR(10),
	   @n_continue		int,
	   @c_errmsg	 NVARCHAR(255),
	   @b_success		int,
	   @n_err			int,
	   @c_sku		 NVARCHAR(20), 
		@c_firsttime NVARCHAR(1), 
		@c_row		 NVARCHAR(10), 
		@c_PrintedFlag NVARCHAR(1), 
		@c_storerkey NVARCHAR(15), 
		@c_skudescr  NVARCHAR(60), 
		@n_Casecnt 		float, 
		@n_innerpack 	float, 
		@c_recvby	 NVARCHAR(18), 
		@n_rowid			int, 
		@n_starttcnt   int  

	CREATE TABLE #TEMPPICKDETAIL (
			PickDetailKey	 NVARCHAR(18),
			OrderKey			 NVARCHAR(10), 
			OrderLineNumber NVARCHAR(5),  
			StorerKey		 NVARCHAR(15),  
			Sku				 NVARCHAR(20),  
			Qty					Int,		
			Lot				 NVARCHAR(10),  
			Loc				 NVARCHAR(10), 
			ID					 NVARCHAR(18), 
			Packkey			 NVARCHAR(10), 
			PickslipNo		 NVARCHAR(10) NULL, 
			PrintedFlag		 NVARCHAR(1))

	CREATE TABLE #TEMPPICKSKU (
			Rowid			int IDENTITY(1,1),
			Storerkey NVARCHAR(20),
			Sku		 NVARCHAR(15))
	   	   		   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 
	SELECT @c_row = '0'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock 
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
             WHERE ExternOrderKey = @c_refkey 
             AND   Zone = 'XD')
   BEGIN
      SELECT @c_firsttime = 'N'
	
      IF EXISTS (SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_refkey AND Zone = 'XD'
                 AND PickType = '0')
      BEGIN
         SELECT @c_PrintedFlag = 'N'
      END 
      ELSE
      BEGIN
         SELECT @c_PrintedFlag = 'Y'
      END

      -- Uses PickType as a Printed Flag
      BEGIN TRAN 

      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
      WHERE ExternOrderKey = @c_refkey 
      AND   Zone = 'XD'
      AND   PickType = '0'

      IF @@ERROR = 0 
      BEGIN
         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 
      END 	
      ELSE
      BEGIN 
         ROLLBACK TRAN 
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
   		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickHeader Failed. (nsp_GetPickSlipXD07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END 

		SELECT @c_PrintedFlag = 'Y'
	END
	ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

	IF (@n_continue = 1 or @n_continue=2) 
	BEGIN
		IF dbo.fnc_RTrim(@c_type) = 'P' 
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, 
												  Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag)
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag
			  FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK)
			 WHERE PD.ORDERKEY = OD.ORDERKEY 
				AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
				AND OD.EXTERNPOKEY = @c_refkey 
				AND PD.STATUS < '5'
			ORDER BY PD.Pickdetailkey

		END
		ELSE
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, 
												  Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag)
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag
			  FROM LOADPLANDETAIL LPD (NOLOCK), PICKDETAIL PD (NOLOCK)
			 WHERE PD.ORDERKEY = LPD.ORDERKEY 
				AND LPD.LOADKEY = @c_refkey 
				AND PD.STATUS < '5'
			ORDER BY PD.Pickdetailkey
		END

	   IF @c_firsttime = 'Y'
	   BEGIN 
			INSERT INTO #TEMPPICKSKU (storerkey, Sku) 
			SELECT DISTINCT STORERKEY, SKU 
			  FROM #TEMPPICKDETAIL 
			ORDER BY STORERKEY, SKU 

			SELECT @n_rowid = 0 		
	
	      WHILE 1=1 
	      BEGIN
				SELECT @n_rowid = Min(rowid) 
				  FROM #TEMPPICKSKU 	
				 WHERE Rowid > @n_rowid

				IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

				Select @c_storerkey = storerkey, @c_sku = sku 
				  from #TEMPPICKSKU 
				 Where Rowid = @n_rowid

				EXECUTE nspg_GetKey 
					'PICKSLIP',
					9,   
					@c_pickheaderkey     OUTPUT,
					@b_success   	 OUTPUT,
					@n_err       	 OUTPUT,
					@c_errmsg    	 OUTPUT
				
				IF @n_err <> 0 
				BEGIN
					select @n_continue = 3
					Break 
				END
				
				IF @c_type = 'P' 
				BEGIN
					SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
				END
				ELSE
				BEGIN
					SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
				END
				
				select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

            BEGIN TRAN 

				INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
				VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

            IF @@ERROR = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               BREAK 
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
					BEGIN TRAN 

   				UPDATE #TEMPPICKDETAIL 
   					SET PICKSLIPNO = @c_pickheaderkey 
   				 WHERE #TEMPPICKDETAIL.STORERKEY = @c_storerkey 
   					AND #TEMPPICKDETAIL.SKU = @c_sku 
   	
					SELECT @n_err = @@ERROR
			
	            IF @n_err = 0 
	            BEGIN
	               WHILE @@TRANCOUNT > 0 
	                  COMMIT TRAN 
	            END 	
	            ELSE
	            BEGIN
	               ROLLBACK TRAN 
	               SELECT @n_continue = 3
	               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
	         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
						Break
	            END

            END 
			END

			IF @n_continue = 1 OR @n_continue = 2
			BEGIN 
            BEGIN TRAN 
		
				UPDATE PICKDETAIL 
					SET TRAFFICCOP = NULL, 
						 PICKSLIPNO = #TEMPPICKDETAIL.PICKSLIPNO 
				  FROM #TEMPPICKDETAIL (NOLOCK) 
				 WHERE PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY
		
				SELECT @n_err = @@ERROR
		
            IF @n_err = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

				Select @c_row = '0'

            BEGIN TRAN 
	
				INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey)
				SELECT OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey FROM #TEMPPICKDETAIL 
				Order BY Pickdetailkey 

				SELECT @n_err = @@ERROR
            IF @n_err = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into RefKeyLookup Failed. (nsp_GetPickSlipXD07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
			END

	   END

		IF @n_continue = 1 OR @n_continue = 2
		BEGIN 
			IF @c_type <> 'P' 
			BEGIN 
				SELECT @c_refkey = (SELECT DISTINCT OD.EXTERNPOKEY 
										   FROM ORDERDETAIL OD (NOLOCK), #TEMPPICKDETAIL 
				 						  WHERE OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
										    AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER)
			END		
	
			SELECT @c_recvby = (SELECT MAX(EDITWHO) 
						 		 		FROM RECEIPTDETAIL (NOLOCK) 
									  WHERE EXTERNRECEIPTKEY = @c_refkey)


         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 

			SELECT #TEMPPICKDETAIL.*, ISNULL(SKU.DESCR,'') SKUDESCR, OD.EXTERNPOKEY, OH.CONSIGNEEKEY, OH.C_COMPANY, 
					 OH.Priority, OH.DeliveryDate, OH.NOTES, STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute, 
					 ISNULL(PACK.Casecnt, 0) CASECNT, ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby 
					 , ISNULL(PO.POTYPE , '') POTYPE		-- ONG01
			  FROM #TEMPPICKDETAIL JOIN ORDERDETAIL OD WITH (NOLOCK)
					ON OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
					AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER
			-- Add by June 30.June.2004, dun display P/S records when Pickheader rec not successfully inserted 
			  JOIN PICKHEADER PH (NOLOCK) ON PH.Pickheaderkey = #TEMPPICKDETAIL.PickslipNo 
			  JOIN SKU WITH (NOLOCK)
					ON #TEMPPICKDETAIL.STORERKEY = SKU.STORERKEY 
					AND #TEMPPICKDETAIL.SKU = SKU.SKU 
			  JOIN PACK WITH (NOLOCK) 
					ON SKU.PACKKEY = PACK.PACKKEY
			  JOIN ORDERS OH WITH (NOLOCK)
					ON OH.ORDERKEY = OD.ORDERKEY
			  LEFT OUTER JOIN STORER WITH (NOLOCK)
					ON STORER.STORERKEY = OH.CONSIGNEEKEY 
				LEFT OUTER JOIN STORERSODEFAULT 
					ON STORER.STORERKEY = STORERSODEFAULT.STORERKEY 
				--LEFT JOIN PO (NOLOCK) ON OH.ExternPOKey = PO.ExternPOkey 		-- ONG01
				LEFT JOIN PO (NOLOCK) ON OD.ExternPOKey = PO.ExternPOkey 		-- SOS#79918
                                   AND OH.Storerkey = PO.Storerkey         -- TLTING
			ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, STORERSODEFAULT.XDockRoute  
	   END
	END

	DROP Table #TEMPPICKDETAIL 
	DROP Table #TEMPPICKSKU 

   IF @n_continue=3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipXD07'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

SET QUOTED_IDENTIFIER OFF 

GO