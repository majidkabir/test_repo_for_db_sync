SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: nsp_GetPickSlipXD03                                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Print XDOCK Pickslip                                        */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Power Builder Print XDOCK Pickslip                        */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.   	Purposes                                */
/* 2005-06-15  Vicky         	  SOS#36849 - Add in Supplier name        */
/* 2007-04-05	 ONG01			    	SOS#71903 - Add Column POTYPE					  */
/* 2009-05-25	 NJOW01		1.1    	SOS#137191 - Add column BUSR3 (sensitive*/  
/*                              & non sensitive SKU flag)               */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD03] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
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
	   @n_err		int,
	   @c_sku	 NVARCHAR(20), 
	   @c_firsttime	        NVARCHAR(1), 
	   @c_row	 NVARCHAR(10), 
	   @c_PrintedFlag NVARCHAR(1), 
	   @c_storerkey	        NVARCHAR(15), 
 	   @c_skudescr 	        NVARCHAR(60), 
	   @n_Casecnt 		float, 
	   @n_innerpack 	float, 
	   @c_recvby	 NVARCHAR(18),
           @c_suppliername      NVARCHAR(45), -- SOS#36849
           @c_supplier          NVARCHAR(45)-- SOS#36849

	CREATE TABLE #TEMPPICKDETAIL (
			PickDetailKey	 NVARCHAR(18),
			OrderKey	 NVARCHAR(10), 
			OrderLineNumber	        NVARCHAR(5),  
			StorerKey	 NVARCHAR(15),  
			Sku		 NVARCHAR(20),  
			Qty			Int,		
			Lot		 NVARCHAR(10),  
			Loc		 NVARCHAR(10), 
			ID		 NVARCHAR(18), 
			Packkey		 NVARCHAR(10), 
			PickslipNo	 NVARCHAR(10) NULL, 
			PrintedFlag	 NVARCHAR(1))
	   	   		   
   SELECT @n_continue = 1	
	SELECT @c_row = '0'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock 
   SELECT @c_pickheaderkey = pickheaderkey  FROM PickHeader (NOLOCK) 
	WHERE ExternOrderKey = @c_refkey 
	AND   Zone = "XD"

	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_pickheaderkey)) IS NOT NULL
   BEGIN
      SELECT @c_firsttime = 'N'

      IF EXISTS (SELECT 1 FROM PickHeader (NOLOCK)
		 WHERE ExternOrderKey = @c_refkey
		 AND Zone = "XD"
		 AND PickType = "0")
      BEGIN
         SELECT @c_PrintedFlag = "N"
      END 
      ELSE
      BEGIN
         SELECT @c_PrintedFlag = "Y"
      END
    
      BEGIN TRAN

      -- Uses PickType as a Printed Flag
      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
      WHERE ExternOrderKey = @c_refkey 
      AND Zone = 'XD'
      AND PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
			SELECT @n_continue = 3
			IF @@TRANCOUNT >= 1
			BEGIN
				ROLLBACK TRAN
			END
		END
	   ELSE
      BEGIN
         IF @@TRANCOUNT > 0 
         BEGIN
				COMMIT TRAN
				SELECT @c_PrintedFlag = "Y"
			END
			ELSE
			BEGIN
				SELECT @n_continue = 3				
				ROLLBACK TRAN
			END
		END
	END
	ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = "N"
   END -- Record Not Exists

	IF (@n_continue = 1 or @n_continue=2) 
	BEGIN

		IF dbo.fnc_RTrim(@c_type) = 'P' 
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, 
						     Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag)
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, 
					 PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag
--			  INTO #TEMPPICKDETAIL 
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
--			  INTO #TEMPPICKDETAIL 
			  FROM LOADPLANDETAIL LPD (NOLOCK), PICKDETAIL PD (NOLOCK)
			 WHERE PD.ORDERKEY = LPD.ORDERKEY 
				AND LPD.LOADKEY = @c_refkey 
				AND PD.STATUS < '5'
			ORDER BY PD.Pickdetailkey
		END

	   IF @c_firsttime = "Y"
	   BEGIN 
			BEGIN TRAN

			EXECUTE nspg_GetKey
				"PICKSLIP",
				9,   
				@c_pickheaderkey     OUTPUT,
				@b_success   	 OUTPUT,
				@n_err       	 OUTPUT,
				@c_errmsg    	 OUTPUT
			
			
			SELECT @c_pickheaderkey = 'X' + @c_pickheaderkey

			
			INSERT INTO PICKHEADER
			(PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			VALUES
			(@c_pickheaderkey, @c_row, @c_refkey,     "0",      "XD",  "")

			IF @@ERROR <> 0 
			BEGIN
				IF @@TRANCOUNT >= 1
				BEGIN
					ROLLBACK TRAN
					SELECT @n_continue = 3
				END
			END
			ELSE
			BEGIN
				WHILE  @@TRANCOUNT > 0 
					COMMIT TRAN
			END
		END
		
		IF @n_continue <>  3
		BEGIN
			BEGIN TRAN
			UPDATE #TEMPPICKDETAIL 
			SET    PICKSLIPNO = @c_pickheaderkey 
			WHERE  dbo.fnc_LTrim(dbo.fnc_RTrim(#TEMPPICKDETAIL.PICKSLIPNO)) IS NULL
		
			IF @@ERROR <> 0
			BEGIN
				SELECT @n_continue = 3
			END

			IF @n_continue <> 3
			BEGIN
				UPDATE PICKDETAIL 
				SET TRAFFICCOP = NULL, 
					 PICKSLIPNO = #TEMPPICKDETAIL.PICKSLIPNO 
				FROM #TEMPPICKDETAIL 
				WHERE PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY
				AND dbo.fnc_LTrim(dbo.fnc_RTrim(PICKDETAIL.PICKSLIPNO)) IS NULL
		
				IF @@ERROR <> 0
				BEGIN
					SELECT @n_continue = 3
				END
			END 

			IF @n_continue <>  3
			BEGIN
				INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey)
				SELECT OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey FROM #TEMPPICKDETAIL 
				WHERE NOT EXISTS (Select 1 FROM RefKeyLookup (NOLOCK) WHERE Pickdetailkey = #TEMPPICKDETAIL.Pickdetailkey)
				Order BY Pickdetailkey

				IF @@ERROR <> 0
				BEGIN
					SELECT @n_continue = 3
				END				
			END

			IF @n_continue = 3
			BEGIN
				IF @@TRANCOUNT >= 1
				BEGIN
					ROLLBACK TRAN
				END
			END
			ELSE
			BEGIN
				IF @@TRANCOUNT > 0 
					COMMIT TRAN
				ELSE
					ROLLBACK TRAN
			END

		END

		IF @n_continue <>  3
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

                        -- Added By Vicky on 15-June-2005 for SOS#36849
                        -- Get suppliername, supplier
                        SELECT @c_suppliername = (SELECT STORER.Company
                                                  FROM STORER (NOLOCK)
                                                  JOIN PO (NOLOCK) ON ( STORER.Storerkey = PO.Sellername
                                                                    AND PO.ExternPOKey = @c_refkey ))
	
                        SELECT @c_supplier = (SELECT Sellername FROM PO (NOLOCK)
                                              WHERE PO.ExternPOKey = @c_refkey )
	
			SELECT #TEMPPICKDETAIL.*, ISNULL(SKU.DESCR,'') SKUDESCR, OD.EXTERNPOKEY, OH.CONSIGNEEKEY, OH.C_COMPANY, 
					 OH.Priority, OH.DeliveryDate, OH.NOTES, STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute, 
					 ISNULL(PACK.Casecnt, 0) CASECNT, ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby, @c_suppliername, 
                                          @c_supplier -- SOS#36849
                , ISNULL(PO.POTYPE ,'') POType,			-- ONG01
                Busr3 -- NJOW01
			  FROM #TEMPPICKDETAIL JOIN ORDERDETAIL OD WITH (NOLOCK)
					ON OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
					AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER
			  JOIN PICKHEADER PH (NOLOCK) ON PH.Pickheaderkey = #TEMPPICKDETAIL.PickslipNo 
			  JOIN SKU WITH (NOLOCK)
					ON #TEMPPICKDETAIL.STORERKEY = SKU.STORERKEY 
					AND #TEMPPICKDETAIL.SKU = SKU.SKU 
			  JOIN PACK WITH (NOLOCK) 
					ON SKU.PACKKEY = PACK.PACKKEY
			  JOIN ORDERS OH WITH (NOLOCK)
					ON OH.ORDERKEY = OD.ORDERKEY
			  JOIN STORER WITH (NOLOCK)
					ON STORER.STORERKEY = OH.CONSIGNEEKEY 
				LEFT OUTER JOIN STORERSODEFAULT 
					ON STORER.STORERKEY = STORERSODEFAULT.STORERKEY
				LEFT JOIN PO (NOLOCK) ON OH.ExternPOKey = PO.ExternPOkey 		-- ONG01
			ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, SKU.Busr3,  #TEMPPICKDETAIL.sku, STORERSODEFAULT.XDockRoute
		END
		DROP Table #TEMPPICKDETAIL
	END

END



GO