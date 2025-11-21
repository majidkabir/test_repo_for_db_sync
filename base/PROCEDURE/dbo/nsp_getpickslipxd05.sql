SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipXD05                           		*/
/* Creation Date: 09-Jan-2006                           						*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                    					*/
/*                                                                      */
/* Purpose:  Create XDOCK Pickslip (05) 											*/
/*           SOS30495 WTC-XDOCK - Pick Case & Piece separately          */
/*           Notes: Modified from nsp_GetPickSlipXD01                   */
/*                                                                      */
/* Input Parameters:  @c_refkey,  - ExternOrderkey if type='P', Loadkey */
/*												if type='L'									*/
/*							 @c_type	-	 -	'P'(ExternPOKey) or 'L'(Loadkey)    */
/*                                                                      */
/* Output Parameters: report                                            */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  dw = r_dw_print_pickxdorder05             					*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*	15-Dec-2008	 YTWan	  1.1   SOS#124231 Add Manufacturing lot and  	*/
/*                              Expiry date to the report (YTWan01)     */
/*                              Group same picktoline, shipto, customer,*/
/*                              order#, seq, mfglot, expirydate, remarks*/
/*                              and show as 1 record in detail          */ 
/*                              report (YTWan02)                        */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD05] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
AS
BEGIN
-- Type = P for ExternPOKey, L for LoadKey
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
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
			UOM				 NVARCHAR(10),	-- SOS30495
			LogicalLocation NVARCHAR(18))	-- SOS30495

	CREATE TABLE #TEMPPICKSKU (
			Rowid			int IDENTITY(1,1),
			Storerkey NVARCHAR(20),
			Sku		 NVARCHAR(15),
         UOM		   NVARCHAR(10) )   -- SOS30495
  	   		   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 
	SELECT @c_row = '0'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock 
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) 
             WHERE ExternOrderKey = @c_refkey 
             AND   Zone = 'XD')
   BEGIN
      SELECT @c_firsttime = 'N'
	
      IF EXISTS (SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_refkey AND Zone = 'XD'
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

      UPDATE PickHeader WITH (ROWLOCK)
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
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63311   
   		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickHeader Failed. (nsp_GetPickSlipXD05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
												  Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag,
												  UOM, LogicalLocation)	-- SOS30495
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag,
					 PD.UOM, LOC.LogicalLocation	-- SOS30495
			  FROM ORDERDETAIL OD WITH (NOLOCK), PICKDETAIL PD WITH (NOLOCK),
					 LOC WITH (NOLOCK)	-- SOS30495
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
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag,
					 PD.UOM, LOC.LogicalLocation	-- SOS30495
			  FROM LOADPLANDETAIL LPD WITH (NOLOCK), PICKDETAIL PD WITH (NOLOCK),
					 LOC WITH (NOLOCK)	-- SOS30495
			 WHERE PD.ORDERKEY = LPD.ORDERKEY
				AND PD.Loc = LOC.Loc	-- SOS30495
				AND LPD.LOADKEY = @c_refkey 
				AND PD.STATUS < '5'
			-- ORDER BY PD.Pickdetailkey	-- SOS30495
			ORDER BY PD.SKU, PD.UOM, LOC.LogicalLocation, LOC.Loc
		END

	   IF @c_firsttime = 'Y'
	   BEGIN

			INSERT INTO #TEMPPICKSKU (Storerkey, SKU, UOM) -- SOS30495
			SELECT DISTINCT STORERKEY, SKU, UOM 
			  FROM #TEMPPICKDETAIL 
			ORDER BY STORERKEY, SKU, UOM -- SOS30495

			SELECT @n_rowid = 0 		
	
	      WHILE 1=1 
	      BEGIN

				SELECT @n_rowid = MIN(rowid) 
				  FROM #TEMPPICKSKU 	
				 WHERE Rowid > @n_rowid

				IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

				SELECT @c_storerkey = storerkey, @c_sku = SKU, @c_UOM = UOM -- SOS30495
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

            BEGIN TRAN 

				INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, PickType, Zone, TrafficCop)
				VALUES (@c_pickheaderkey, @c_row, @c_refkey,  '0', 'XD', '')

            IF @@ERROR = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63312   
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               BREAK 
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
					BEGIN TRAN 

   				UPDATE #TEMPPICKDETAIL 
   					SET PICKSLIPNO = @c_pickheaderkey 
   				 WHERE #TEMPPICKDETAIL.STORERKEY = @c_storerkey 
   					AND #TEMPPICKDETAIL.SKU = @c_sku 
                  AND #TEMPPICKDETAIL.UOM = @c_UOM -- SOS30495
   	
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
	               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63313   
	         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
						BREAK
	            END

            END 
			END

			IF @n_continue = 1 OR @n_continue = 2
			BEGIN 
            BEGIN TRAN 
		
				UPDATE PICKDETAIL WITH (ROWLOCK)
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
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

				SELECT @c_row = '0'

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
         		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into RefKeyLookup Failed. (nsp_GetPickSlipXD05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
			END
	   END

		IF @n_continue = 1 OR @n_continue = 2
		BEGIN 
			IF @c_type <> 'P' 
			BEGIN 
				SELECT @c_refkey = (SELECT DISTINCT OD.EXTERNPOKEY 
										   FROM ORDERDETAIL OD WITH (NOLOCK), #TEMPPICKDETAIL 
				 						  WHERE OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
										    AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER)
			END		
	
			SELECT @c_recvby = (SELECT MAX(EDITWHO) 
						 		 		FROM RECEIPTDETAIL WITH (NOLOCK) 
									  WHERE EXTERNRECEIPTKEY = @c_refkey)

         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 
         -- SOS30495
         -- SELECT #TEMPPICKDETAIL.*, 
			SELECT MIN(#TEMPPICKDETAIL.PickDetailKey) AS PickDetailKey,				-- (YTWan02)
            #TEMPPICKDETAIL.OrderKey,
            MIN(#TEMPPICKDETAIL.OrderLineNumber) AS OrderLineNumber,				-- (YTWan02)
            #TEMPPICKDETAIL.StorerKey,
            #TEMPPICKDETAIL.Sku,
            SUM (#TEMPPICKDETAIL.Qty) as Qty,
            MIN(#TEMPPICKDETAIL.Lot) AS Lot,												-- (YTWan02)
            #TEMPPICKDETAIL.Loc,
            MIN(#TEMPPICKDETAIL.ID)  AS ID,												-- (YTWan02)
            #TEMPPICKDETAIL.Packkey,
            #TEMPPICKDETAIL.PickSlipNo,
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
            CONVERT(char(60), OH.NOTES), STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute, 
            ISNULL(PACK.Pallet, 0) Pallet,ISNULL(PACK.Casecnt, 0) CaseCnt, 
            ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby,
            UserID = sUser_sName(),
				/* YTwan01 - START */
				LA.Lottable02,
				LA.Lottable04  
				/* YTwan01 - END */
         FROM #TEMPPICKDETAIL JOIN ORDERDETAIL OD WITH (NOLOCK)
            ON OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
            AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER
			-- Add by June 30.June.2004, dun display P/S records when Pickheader rec not successfully inserted 
         JOIN PICKHEADER PH WITH (NOLOCK) ON PH.Pickheaderkey = #TEMPPICKDETAIL.PickslipNo 
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
			/* YTwan01 - START */
			JOIN LOTATTRIBUTE LA WITH (NOLOCK) 
				ON (LA.LOT = #TEMPPICKDETAIL.Lot)
			/* YTwan01 - END  */
         GROUP BY --#TEMPPICKDETAIL.PickDetailKey,										-- (YTWan02)
            #TEMPPICKDETAIL.OrderKey,
            --#TEMPPICKDETAIL.OrderLineNumber,											-- (YTWan02)
            #TEMPPICKDETAIL.StorerKey,
            #TEMPPICKDETAIL.Sku,
            --#TEMPPICKDETAIL.Lot,															-- (YTWan02)
            #TEMPPICKDETAIL.Loc,
            --#TEMPPICKDETAIL.ID,															-- (YTWan02)
            #TEMPPICKDETAIL.Packkey,
            #TEMPPICKDETAIL.PickSlipNo,
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
            CONVERT(char(60), OH.NOTES), STORERSODEFAULT.XDockLane, STORERSODEFAULT.XDockRoute, 
            PACK.Pallet, PACK.Casecnt, 
            PACK.Innerpack,
				/* YTwan01 - START */
				LA.Lottable02,
				LA.Lottable04
				/* YTwan01 - END */
			 ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, STORERSODEFAULT.XDockRoute, 
						 LA.Lottable04                                               --  YTWan01
	   END
	END

	DROP TABLE #TEMPPICKDETAIL
	DROP Table #TEMPPICKSKU

   IF @n_continue=3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipXD05'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

GO