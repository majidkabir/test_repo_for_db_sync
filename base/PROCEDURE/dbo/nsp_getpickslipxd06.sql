SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipXD06                           		*/
/* Creation Date: 09-Jan-2006                           						*/
/* Copyright: IDS                                                       */
/* Written by:                                           					*/
/*                                                                      */
/* Purpose:  Create XDOCK Pickslip (06) - For Reprint purpose				*/
/*           SOS30495 WTC-XDOCK - Pick Case & Piece separately          */
/*           Notes: Modified from nsp_GetPickSlipXD02                   */
/*                                                                      */
/* Input Parameters:  @c_refkey,  - ExternOrderkey if type='P', Loadkey */
/*												if type='L'									*/
/*							 @c_type	-	 -	'P'(ExternPOKey) or 'L'(Loadkey)    */
/*                                                                      */
/*                                                                      */
/* Called By:  rpt_id = 'XDPSLP01', dw = r_dw_print_pickxdorder06       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 27-Jan-2006  MaryVong      Modified BEGIN TRAN and Error setting     */
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD06] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
AS
BEGIN
-- Type = P for ExternPOKey, L for LoadKey
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey NVARCHAR(10),
	   @n_continue		int,
	   @c_errmsg	 NVARCHAR(255),
	   @b_success		int,
	   @n_err			int,
	   @c_sku		 NVARCHAR(20), 
		@c_row		 NVARCHAR(10), 
		@c_PrintedFlag NVARCHAR(1), 
		@c_storerkey NVARCHAR(15), 
		@c_skudescr  NVARCHAR(60), 
		@n_Casecnt 		float, 
		@n_innerpack 	float, 
		@c_recvby	 NVARCHAR(18), 
		@n_rowid			int, 
		@n_starttcnt   int,
		@c_UOM		 NVARCHAR(10)	-- SOS30495

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
			PrintedFlag		 NVARCHAR(1), 
			RowId					Int IDENTITY(1, 1) NOT NULL,
			UOM				 NVARCHAR(10),	-- SOS30495
			LogicalLocation NVARCHAR(18))	-- SOS30495

	CREATE TABLE #TEMPPICKSKU (
			Rowid			int IDENTITY(1,1),
			Storerkey NVARCHAR(20),
			Sku		 NVARCHAR(15),
         UOM		   NVARCHAR(10)  ) -- SOS30495
	   	   		   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 
	SELECT @c_row = '0'

   BEGIN TRAN

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock 
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
             WHERE ExternOrderKey = @c_refkey 
             AND   Zone = 'XD')
   BEGIN
		SELECT @c_row = MAX(Convert(int,WAVEKEY)) FROM PICKHEADER (NOLOCK) 
		 WHERE ExternOrderKey = @c_refkey AND Zone = 'XD' 
	END
	ELSE
   BEGIN
		SELECT @c_row = '0' 
   END -- Record Not Exists

	IF (@n_continue = 1 OR @n_continue=2) 
	BEGIN
		IF dbo.fnc_RTrim(@c_type) = 'P' 
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, 
												  Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag,
												  UOM, LogicalLocation)	-- SOS30495
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, 
					 CASE WHEN PD.PickSlipNo IS NULL THEN 'N'
					 	   WHEN PD.PickSlipNo = '' THEN 'N' 
							ELSE 'Y'
					 END,
					 PD.UOM, LOC.LogicalLocation	-- SOS30495 
			  FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK),
					 LOC (NOLOCK)	-- SOS30495
			 WHERE PD.ORDERKEY = OD.ORDERKEY 
				AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
				AND PD.Loc = LOC.Loc	-- SOS30495
				AND OD.EXTERNPOKEY = @c_refkey 
				AND PD.STATUS < '5'
			-- ORDER BY PD.Pickdetailkey	-- SOS30495
			ORDER BY PD.SKU, PD.UOM, LOC.LogicalLocation, LOC.Loc
		END
		ELSE
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, 
												  Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag,
												  UOM, LogicalLocation)	-- SOS30495
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, 
					 CASE WHEN PD.PickSlipNo IS NULL THEN 'N'
					 	   WHEN PD.PickSlipNo = '' THEN 'N' 
							ELSE 'Y'
					 END,
					 PD.UOM, LOC.LogicalLocation	-- SOS30495 
			  FROM LOADPLANDETAIL LPD (NOLOCK), PICKDETAIL PD (NOLOCK),
					 LOC (NOLOCK)	-- SOS30495
			 WHERE PD.ORDERKEY = LPD.ORDERKEY
				AND PD.Loc = LOC.Loc	-- SOS30495 
				AND LPD.LOADKEY = @c_refkey 
				AND PD.STATUS < '5'
			-- ORDER BY PD.Pickdetailkey	-- SOS30495
			ORDER BY PD.SKU, PD.UOM, LOC.LogicalLocation, LOC.Loc
		END

		INSERT INTO #TEMPPICKSKU (Storerkey, Sku, UOM) -- SOS30495
		SELECT DISTINCT STORERKEY, SKU, UOM 
		  FROM #TEMPPICKDETAIL 
		 WHERE (PickSlipNo IS NULL OR PickSlipNo = '') 
		ORDER BY STORERKEY, SKU, UOM

		SELECT @n_rowid = 0 		

      WHILE 1=1 
      BEGIN

			SELECT @n_rowid = MIN(rowid) 
			  FROM #TEMPPICKSKU 	
			 WHERE Rowid > @n_rowid

			IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			SELECT @c_storerkey = storerkey, @c_sku = sku, @c_UOM = UOM -- SOS30495
			  FROM #TEMPPICKSKU 
			 WHERE Rowid = @n_rowid

			EXECUTE nspg_GetKey 
				'PICKSLIP',
				9,   
				@c_pickheaderkey     OUTPUT,
				@b_success   	 OUTPUT,
				@n_err       	 OUTPUT,
				@c_errmsg    	 OUTPUT
			
			IF @n_err <> 0 
			BEGIN
				SELECT @n_continue = 3
				BREAK 
			END
			
			SELECT @c_pickheaderkey = 'X' + @c_pickheaderkey
		
			SELECT @c_row = CONVERT(char(10), CONVERT(int, @c_row) + 1) 

			INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63311   
      		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD06)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            BREAK 
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN

				UPDATE #TEMPPICKDETAIL 
					SET PICKSLIPNO = @c_pickheaderkey 
				 WHERE #TEMPPICKDETAIL.STORERKEY = @c_storerkey 
					AND #TEMPPICKDETAIL.SKU = @c_sku 
               AND #TEMPPICKDETAIL.UOM = @c_UOM -- SOS30495
 				   AND (#TEMPPICKDETAIL.PickSlipNo IS NULL OR #TEMPPICKDETAIL.PickSlipNo = '') 
	
				SELECT @n_err = @@ERROR
		
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63312   
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD06)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
					BREAK
            END
         END 
		END

		IF @n_continue = 1 OR @n_continue = 2
		BEGIN 
			UPDATE PICKDETAIL 
				SET TRAFFICCOP = NULL, 
					 PICKSLIPNO = #TEMPPICKDETAIL.PICKSLIPNO 
			  FROM #TEMPPICKDETAIL (NOLOCK) 
			 WHERE PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY 
			   AND (PICKDETAIL.PickSlipNo IS NULL OR PICKDETAIL.PickSlipNo = '') 
	
			SELECT @n_err = @@ERROR
	
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63313   
      		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD06)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

			SELECT @c_row = '0'

			INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey)
			SELECT OrderKey, OrderLinenumber, PickslipNo, Pickdetailkey FROM #TEMPPICKDETAIL 
			 WHERE PrintedFlag = 'N' 
			 ORDER BY Pickdetailkey 

			SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
      		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into RefKeyLookup Failed. (nsp_GetPickSlipXD06)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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

			SELECT #TEMPPICKDETAIL.PickDetailKey, 
            #TEMPPICKDETAIL.OrderKey, 
            #TEMPPICKDETAIL.OrderLineNumber, 
            #TEMPPICKDETAIL.StorerKey, 
            #TEMPPICKDETAIL.Sku, 
            #TEMPPICKDETAIL.Qty, 
            #TEMPPICKDETAIL.Lot, 
            #TEMPPICKDETAIL.Loc, 
            #TEMPPICKDETAIL.ID, 
            #TEMPPICKDETAIL.Packkey, 
            #TEMPPICKDETAIL.PickslipNo, 
            #TEMPPICKDETAIL.PrintedFlag, 
            -- SOS30495
            CASE #TEMPPICKDETAIL.UOM 
               WHEN '1'	THEN 'Pallet'
               WHEN '2' THEN 'Case'
               WHEN '3'	THEN 'InnerPack'
               WHEN '6' THEN 'Each'
            END as UOM,
            #TEMPPICKDETAIL.LogicalLocation,
            ISNULL(SKU.DESCR,'') SKUDESCR, OD.EXTERNPOKEY, OH.CONSIGNEEKEY, OH.C_COMPANY, 
            OH.Priority, OH.DeliveryDate, 
            CONVERT(NVARCHAR(60), OH.NOTES), STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute, 
            ISNULL(PACK.Pallet, 0) Pallet, ISNULL(PACK.Casecnt, 0) CaseCnt, 
            ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby,
            UserID = sUser_sName()  
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
         GROUP BY #TEMPPICKDETAIL.PickDetailKey, 
            #TEMPPICKDETAIL.OrderKey, 
            #TEMPPICKDETAIL.OrderLineNumber, 
            #TEMPPICKDETAIL.StorerKey, 
            #TEMPPICKDETAIL.Sku, 
            #TEMPPICKDETAIL.Qty, 
            #TEMPPICKDETAIL.Lot, 
            #TEMPPICKDETAIL.Loc, 
            #TEMPPICKDETAIL.ID, 
            #TEMPPICKDETAIL.Packkey, 
            #TEMPPICKDETAIL.PickslipNo, 
            #TEMPPICKDETAIL.PrintedFlag, 
            -- SOS30495
            CASE #TEMPPICKDETAIL.UOM 
               WHEN '1'	THEN 'Pallet'
               WHEN '2' THEN 'Case'
               WHEN '3'	THEN 'InnerPack'
               WHEN '6' THEN 'Each'
               END,
            #TEMPPICKDETAIL.LogicalLocation,
            SKU.DESCR, OD.EXTERNPOKEY, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, 
            CONVERT(NVARCHAR(60), OH.NOTES), STORERSODEFAULT.XDockLane, STORERSODEFAULT.XDockRoute, 
            PACK.Pallet, PACK.Casecnt, 
            PACK.Innerpack
			ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, STORERSODEFAULT.XDockRoute  
	   END
	END

	DROP TABLE #TEMPPICKDETAIL 
	DROP Table #TEMPPICKSKU

   /* Return Statement */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
       IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
       execute nsp_logerror @n_err, @c_errmsg, "nsp_GetPickSlipXD06"
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
   END
   ELSE
   BEGIN
   /* Error Did Not Occur , Return Normally */
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
            COMMIT TRAN
       END
       RETURN
   END
   /* End Return Statement */

END

GO