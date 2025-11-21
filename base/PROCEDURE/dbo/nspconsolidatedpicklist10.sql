SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspConsolidatedPickList10                      		*/
/* Creation Date:                                     						*/
/* Copyright: IDS                                                       */
/* Written by:                                           					*/
/*                                                                      */
/* Purpose:  Create Consolidated PickSlip (10) - for WTCTH			      */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - LoadKey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick10         			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 20-Nov-2002  June      		Bug Fixes (SOS8637) 	               		*/
/* 16-Mar-2005  MaryVong      Modified layout and added more fields     */
/*                            (SOS33358)											*/ 
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nspConsolidatedPickList10] (
 @a_s_LoadKey NVARCHAR(10)
 )
 AS
 BEGIN   
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE @d_date_start	datetime,
 		@d_date_end		 	datetime,
 		@c_sku			  NVARCHAR(20),
 		@c_storerkey	  NVARCHAR(15),
 		@c_lot			  NVARCHAR(10),
 		@c_uom			  NVARCHAR(10),
 		@c_Route         NVARCHAR(10),
 		@c_Exe_String    NVARCHAR(60),
 		@n_Qty          	int,
 		@c_Pack          NVARCHAR(10),
 		@n_CaseCnt      	int,
		@c_uom1 			  NVARCHAR(10),
		@c_uom3 			  NVARCHAR(10)

 DECLARE @c_CurrOrderKey NVARCHAR(10),
 		@c_MBOLKey			 NVARCHAR(10),
 		@c_firsttime		 NVARCHAR(1),
 		@c_PrintedFlag   	 NVARCHAR(1),
 		@n_err          	 int,
 		@n_continue     	 int,
 		@c_PickHeaderKey 	 NVARCHAR(10),
 		@b_success       	 int,
 		@c_errmsg        	 NVARCHAR(255)
 /* Start Modification */
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

    IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
              WHERE ExternOrderKey = @a_s_LoadKey
              AND   Zone = '7')
    BEGIN
       SELECT @c_firsttime = 'N'
       SELECT @c_PrintedFlag = 'Y'

    	 -- Uses PickType as a Printed Flag
       BEGIN TRAN

    	 UPDATE PickHeader
    	   SET PickType = '1',
    	       TrafficCop = NULL
    	   WHERE ExternOrderKey = @a_s_LoadKey
    	   AND Zone = '7'
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
    		 END
       END
    END -- PickHeader Exists 
    ELSE
    BEGIN
       SELECT @c_firsttime = 'Y'
       SELECT @c_PrintedFlag = 'N'
    END -- Record Not Exists


 	IF @c_firsttime = 'Y'
 	BEGIN
 		EXECUTE nspg_GetKey
 		'PICKSLIP',
 		9,   
 		@c_pickheaderkey     OUTPUT,
 		@b_success   	 OUTPUT,
 		@n_err       	 OUTPUT,
 		@c_errmsg    	 OUTPUT
 		
 		SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

 		BEGIN TRAN

 		INSERT INTO PICKHEADER
 		(PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
 		VALUES
 		(@c_pickheaderkey, @a_s_LoadKey,     '0',      '7',  '')
 		
 		SELECT @n_err = @@ERROR
 		IF @n_err <> 0 
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
 		END
 	END
 	ELSE
 	BEGIN
 		SELECT @c_pickheaderkey = PickHeaderKey 
 		FROM  PickHeader (NOLOCK) 
 		WHERE ExternOrderKey = @a_s_LoadKey
 		AND   Zone = '7'
 	END
 	
 /* End */
 /*Create Temp Result table */
 SELECT  ConsoGroupNo = 0,
 		Loadplan.LoadKey LoadKey,
 		DeliveryZone=SPACE(15),	-- SOS33358
		Putawayzone=SPACE(10),
 		PICKDETAIL.LOC Loc,
 		PICKDETAIL.SKU SKU,
 		ORDERS.StorerKey StorerKey1,
 		ORDERS.OrderKey  OrderKey1,
 		ORDERS.Route     Route1,
 		ORDERS.StorerKey StorerKey2,
 		ORDERS.OrderKey  OrderKey2,
 		ORDERS.Route     Route2,
 		ORDERS.StorerKey StorerKey3,
 		ORDERS.OrderKey  OrderKey3,
 		ORDERS.Route     Route3,
 		ORDERS.StorerKey StorerKey4,
 		ORDERS.OrderKey  OrderKey4,
 		ORDERS.Route     Route4,
 		ORDERS.StorerKey StorerKey5,
 		ORDERS.OrderKey  OrderKey5,
 		ORDERS.Route     Route5,
 		ORDERS.StorerKey StorerKey6,
 		ORDERS.OrderKey  OrderKey6,
 		ORDERS.Route     Route6,
 		ORDERS.StorerKey StorerKey7,
 		ORDERS.OrderKey  OrderKey7,
 		ORDERS.Route     Route7,
 		ORDERS.StorerKey StorerKey8,
 		ORDERS.OrderKey  OrderKey8,
 		ORDERS.Route     Route8,
 		PICKDETAIL.QTY   Qty1,
 		PICKDETAIL.QTY   Qty2,
 		PICKDETAIL.QTY   Qty3,
 		PICKDETAIL.QTY   Qty4,
 		PICKDETAIL.QTY   Qty5,
 		PICKDETAIL.QTY   Qty6,
 		PICKDETAIL.QTY   Qty7,
 		PICKDETAIL.QTY   Qty8,
 		Pack1=SPACE(10),
 		Pack2=SPACE(10),
 		Pack3=SPACE(10),
 		Pack4=SPACE(10),
 		Pack5=SPACE(10),
 		Pack6=SPACE(10),
 		Pack7=SPACE(10),
 		Pack8=SPACE(10),
 		TotQty=0,
 		TotCases=0,
 		TotPack=SPACE(10),
 		DESCR=SPACE(60),
 		UOM1=SPACE(10),
 		UOM3=SPACE(10),
 		CaseCnt=0,
 		ORDERS.ExternOrderKey InvoiceNo1, 
 		ORDERS.ExternOrderKey InvoiceNo2, 
 		ORDERS.ExternOrderKey InvoiceNo3, 
 		ORDERS.ExternOrderKey InvoiceNo4, 
 		ORDERS.ExternOrderKey InvoiceNo5, 
 		ORDERS.ExternOrderKey InvoiceNo6, 
 		ORDERS.ExternOrderKey InvoiceNo7,
 		ORDERS.ExternOrderKey InvoiceNo8,
 		LabelFlag='N' ,
 		PICKDETAIL.LOT Lot,
 		LOTATTRIBUTE.Lottable01 lottable1,
 		LOTATTRIBUTE.Lottable02 lottable2,
 		LOTATTRIBUTE.Lottable03 lottable3,
 		LOTATTRIBUTE.Lottable04 lottable4,
 		LOTATTRIBUTE.Lottable05 lottable5,
		PickHeaderKey=SPACE(10),
		C_Company1 = SPACE(45),
		C_Company2 = SPACE(45),
		C_Company3 = SPACE(45),
		C_Company4 = SPACE(45),
		C_Company5 = SPACE(45),
		C_Company6 = SPACE(45),
		C_Company7 = SPACE(45),
		C_Company8 = SPACE(45),
		printflag = SPACE(10), 
		Retailsku = SPACE(20),
		-- SOS33358
	   PrintedBy = SPACE(60),
		ConsigneeKey1 = SPACE(15),
		ConsigneeKey2 = SPACE(15),
		ConsigneeKey3 = SPACE(15),
		ConsigneeKey4 = SPACE(15),
		ConsigneeKey5 = SPACE(15),
		ConsigneeKey6 = SPACE(15),
		ConsigneeKey7 = SPACE(15),
		ConsigneeKey8 = SPACE(15),
 		NOTES1 = SPACE(60),
 		NOTES2 = SPACE(60),
 		NOTES3 = SPACE(60),
 		NOTES4 = SPACE(60),
 		NOTES5 = SPACE(60),
 		NOTES6 = SPACE(60),
 		NOTES7 = SPACE(60),
 		NOTES8 = SPACE(60),
 		TotEaches=0
 INTO #CONSOLIDATED 
 FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK), LOTATTRIBUTE(NOLOCK)
 WHERE 1 = 2
 
 DECLARE @c_Route1     NVARCHAR(10),
         @c_StorerKey1 NVARCHAR(15),
         @c_OrderKey1  NVARCHAR(10),
         @c_Route2     NVARCHAR(10),
         @c_StorerKey2 NVARCHAR(15),
         @c_OrderKey2  NVARCHAR(10),
         @c_Route3     NVARCHAR(10),
         @c_StorerKey3 NVARCHAR(15),
         @c_OrderKey3  NVARCHAR(10),
         @c_Route4     NVARCHAR(10),
         @c_StorerKey4 NVARCHAR(15),
         @c_OrderKey4  NVARCHAR(10),
         @c_Route5     NVARCHAR(10),
         @c_StorerKey5 NVARCHAR(15),
         @c_OrderKey5  NVARCHAR(10),
         @c_Route6     NVARCHAR(10),
         @c_StorerKey6 NVARCHAR(15),
         @c_OrderKey6  NVARCHAR(10),
         @c_Route7     NVARCHAR(10),
         @c_StorerKey7 NVARCHAR(15),
         @c_OrderKey7  NVARCHAR(10),
         @c_Route8     NVARCHAR(10),
         @c_StorerKey8 NVARCHAR(15),
         @c_OrderKey8  NVARCHAR(10)

 DECLARE @n_Qty1   	int,
         @c_Pack1   NVARCHAR(10),
         @n_Qty2   	int,
         @c_Pack2   NVARCHAR(10),
         @n_Qty3   	int,
         @c_Pack3   NVARCHAR(10),
         @n_Qty4   	int,
         @c_Pack4   NVARCHAR(10),
         @n_Qty5   	int,
         @c_Pack5   NVARCHAR(10),
         @n_Qty6   	int,
         @c_Pack6   NVARCHAR(10),
         @n_Qty7   	int,
         @c_Pack7   NVARCHAR(10),
         @n_Qty8   	int,
         @c_Pack8   NVARCHAR(10),
         @n_TotQty   int,
         @c_TotPack  NVARCHAR(10),
         @n_TotCases int,
         @n_CasesQty int,
         @c_Descr    NVARCHAR(60),
         @c_Packkey  NVARCHAR(10),
         @n_EachQty   int,  -- SOS33358
         @n_TotEaches int   -- SOS33358

 DECLARE @c_Invoice1 NVARCHAR(18),
         @c_Invoice2 NVARCHAR(18),
         @c_Invoice3 NVARCHAR(18),
         @c_Invoice4 NVARCHAR(18),
         @c_Invoice5 NVARCHAR(18),
         @c_Invoice6 NVARCHAR(18),
         @c_Invoice7 NVARCHAR(18),
         @c_Invoice8 NVARCHAR(18)

 DECLARE @c_company1 NVARCHAR(45),
			@c_company2 NVARCHAR(45),
			@c_company3 NVARCHAR(45),
			@c_company4 NVARCHAR(45),
			@c_company5 NVARCHAR(45),
			@c_company6 NVARCHAR(45),
			@c_company7 NVARCHAR(45),
			@c_company8 NVARCHAR(45)
 
 -- SOS33358
 DECLARE @c_consigneekey1 NVARCHAR(15),
			@c_consigneekey2 NVARCHAR(15),
			@c_consigneekey3 NVARCHAR(15),
			@c_consigneekey4 NVARCHAR(15),
			@c_consigneekey5 NVARCHAR(15),
			@c_consigneekey6 NVARCHAR(15),
			@c_consigneekey7 NVARCHAR(15),
			@c_consigneekey8 NVARCHAR(15)

 DECLARE	@c_notes1 NVARCHAR(60),		
			@c_notes2 NVARCHAR(60),
			@c_notes3 NVARCHAR(60),
			@c_notes4 NVARCHAR(60),
			@c_notes5 NVARCHAR(60),
			@c_notes6 NVARCHAR(60),
			@c_notes7 NVARCHAR(60),
			@c_notes8 NVARCHAR(60)

 DECLARE @c_company 	 NVARCHAR(45),
			@c_invoiceno NVARCHAR(18),
			@c_printflag NVARCHAR(10),
			@c_printedby NVARCHAR(60)	-- SOS33358

 CREATE TABLE #SKUGroup (
		PUTAWAYZONE NVARCHAR(10), 
	 	LOC 	    NVARCHAR(10),
	 	SKU 		 NVARCHAR(20),
	 	OrderKey  NVARCHAR(10),
	 	GroupNo  	int,
	 	GroupSeq 	int)

 -- Do a grouping for sku
 DECLARE @c_OrderKey 	 NVARCHAR(10),
 		@c_Invoice 			 NVARCHAR(18),
		@c_Putawayzone 	 NVARCHAR(10), 
 		@c_LOC      		 NVARCHAR(10),
 		@n_Count    			int,
 		@n_GroupNo  			int,
 		@n_GroupSeq 			int,
 		@c_logicallocation NVARCHAR(18),
	   @n_groupno1 			int,
		@n_groupseq1 			int

 -- SOS33358
 -- Get user name
 SELECT @c_printedby = suser_sname()

 DECLARE CUR_1 SCROLL CURSOR FOR
 SELECT DISTINCT pickdetail.OrderKey,
 	pickdetail.SKU,
 	ISNULL(LOC.Putawayzone,'') AS Putawayzone,
 	PICKDETAIL.LOC,
 	LOC.LogicalLocation,
 	PICKDETAIL.LOT
 FROM PICKDETAIL (NOLOCK), LOC (NOLOCK), ORDERS (NOLOCK)
 WHERE orders.loadkey = @a_s_loadkey
   and orders.orderkey = pickdetail.orderkey
   and pickdetail.loc = loc.loc
   and pickdetail.qty > 0
 ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, pickdetail.SKU, pickdetail.OrderKey

 OPEN CUR_1
 SELECT @n_GroupNo = 1
 SELECT @n_GroupSeq = 0
 FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Putawayzone, @c_Loc, @c_logicallocation, @c_lot
 WHILE @@FETCH_STATUS <> -1
 BEGIN
    SELECT @n_Count = Count(*)
    FROM   #SKUGroup
  	 WHERE  OrderKey = @c_OrderKey
    IF @n_Count = 0
    BEGIN
       SELECT @n_GroupSeq = @n_GroupSeq + 1
 		 -- Customize For Thailand for 7 Orders per pick slip
       IF @n_GroupSeq > 7
       BEGIN
          SELECT @n_GroupNo=@n_GroupNo + 1
          SELECT @n_GroupSeq = 1
       END
       	INSERT INTO #SKUGroup 
 					( PUTAWAYZONE, LOC, SKU, OrderKey, GroupNo, GroupSeq)
 			VALUES (@c_Putawayzone, @c_loc, @c_sku, @c_OrderKey, IsNULL(@n_GroupNo,  1), IsNULL(@n_GroupSeq, 1))
    END -- IF ORDERKEY NOT EXIST
	 ELSE
	 BEGIN
		IF NOT EXISTS (SELECT 1 
							FROM #skugroup 
							WHERE loc = @c_loc 
							  AND sku = @c_sku
							  AND orderkey = @c_orderkey)
		BEGIN
			SELECT @n_groupno1 = groupno, @n_groupseq1 = groupseq
			FROM #skugroup
			WHERE orderkey = @c_orderkey

			INSERT INTO #SKUGroup VALUES (@c_Putawayzone, @c_loc, @c_sku, @c_orderkey, @n_groupno1, @n_groupseq1)
		END
    END
    FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Putawayzone, @c_Loc, @c_logicallocation, @c_lot
 END -- WHILE FETCH STATUS <> -1

 SELECT @c_storerkey1 = storerkey, @c_company1 = c_company, @c_route1 = route, @c_invoice1 = externorderkey, @c_orderkey1 = orders.orderkey
		  , @c_consigneekey1 = orders.consigneekey, @c_notes1 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 1

 SELECT @c_storerkey2 = storerkey, @c_company2 = c_company, @c_route2 = route, @c_invoice2 = externorderkey, @c_orderkey2 = orders.orderkey
		  , @c_consigneekey2 = orders.consigneekey, @c_notes2 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 2

 SELECT @c_storerkey3 = storerkey, @c_company3 = c_company, @c_route3 = route, @c_invoice3 = externorderkey, @c_orderkey3 = orders.orderkey
		  , @c_consigneekey3 = orders.consigneekey, @c_notes3 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 3

 SELECT @c_storerkey4 = storerkey, @c_company4 = c_company, @c_route4 = route, @c_invoice4 = externorderkey, @c_orderkey4 = orders.orderkey
		  , @c_consigneekey4 = orders.consigneekey, @c_notes4 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 4

 SELECT @c_storerkey5 = storerkey, @c_company5 = c_company, @c_route5 = route, @c_invoice5 = externorderkey, @c_orderkey5 = orders.orderkey
		  , @c_consigneekey5 = orders.consigneekey, @c_notes5 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 5
 
 SELECT @c_storerkey6 = storerkey, @c_company6 = c_company, @c_route6 = route, @c_invoice6 = externorderkey, @c_orderkey6 = orders.orderkey
		  , @c_consigneekey6 = orders.consigneekey, @c_notes6 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 6

 SELECT @c_storerkey7 = storerkey, @c_company7 = c_company, @c_route7 = route, @c_invoice7 = externorderkey, @c_orderkey7 = orders.orderkey
		  , @c_consigneekey7 = orders.consigneekey, @c_notes7 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 7

 SELECT @c_storerkey8 = storerkey, @c_company8 = c_company, @c_route8 = route, @c_invoice8 = externorderkey, @c_orderkey8 = orders.orderkey
		  , @c_consigneekey8 = orders.consigneekey, @c_notes8 = CONVERT(NVARCHAR(60),orders.notes)	-- SOS33358
 FROM orders (NOLOCK) JOIN #skugroup
	ON orders.orderkey = #skugroup.orderkey
 WHERE groupseq = 8

 SELECT @c_pickheaderkey = pickheaderkey, @c_printflag = picktype
 FROM pickheader (NOLOCK)
 WHERE externorderkey = @a_s_loadkey
   AND zone = '7'
 
 DECLARE CUR_2 SCROLL CURSOR FOR
    SELECT DISTINCT PUTAWAYZONE, LOC, SKU
    FROM   #SKUGroup
    ORDER BY PUTAWAYZONE, LOC, SKU
 OPEN CUR_2
 FETCH NEXT FROM CUR_2 INTO @c_putawayzone, @c_LOC, @c_SKU
 WHILE @@FETCH_STATUS <> -1
 BEGIN
   DECLARE CUR_3 CURSOR FOR 
       SELECT ORDERKEY, GroupNo, GroupSeq
       FROM   #SKUGroup
       WHERE  LOC = @c_LOC
       AND    SKU = @c_SKU
    OPEN CUR_3
    FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
    WHILE @@FETCH_STATUS <> -1
    BEGIN
       SELECT @n_Qty = 0
       SELECT @c_Pack = ""
       SELECT @n_CaseCnt = 0
       SELECT @n_EachQty = 0

       SELECT @c_storerkey = storerkey, @n_Qty = SUM(PICKDETAIL.QTY)--, @n_EachQty = SUM(PICKDETAIL.QTY)
       FROM   PICKDETAIL (NOLOCK)
       WHERE  PICKDETAIL.OrderKey = @c_OrderKey
       AND    PICKDETAIL.SKU   = @c_SKU
       AND    PICKDETAIL.LOC  = @c_LOC
		 GROUP BY storerkey

       SELECT @n_CaseCnt = ISNULL(CaseCnt,0), @c_descr = descr, @c_uom1 = packuom1, @c_uom3 = packuom3
       FROM   SKU (NOLOCK), PACK (NOLOCK)
       WHERE  sku.storerkey = @c_storerkey
			and sku.sku = @c_sku
         and sku.packkey = pack.packkey

       IF @n_CaseCnt = 0
          SELECT @c_Pack = " " -- No of Item in Carton not available
       ELSE
       BEGIN
          SELECT @n_EachQty = @n_Qty   -- SOS33358
          SELECT @c_Pack = CONVERT(NVARCHAR(10), FLOOR(@n_Qty / @n_CaseCnt)) -- modified by Jacob, date: July 23, 2001. description:Changed from NVARCHAR(4) to NVARCHAR(10)
           IF @c_Pack = '0' select @c_Pack = ""
          SELECT @n_CasesQty = FLOOR(@n_Qty / @n_CaseCnt)
          SELECT @n_Qty = @n_Qty % @n_CaseCnt
       END
       SELECT @n_TotQty   = @n_TotQty  + @n_Qty
       SELECT @n_TotCases = @n_TotCases + @n_CasesQty
       SELECT @n_TotEaches = @n_TotEaches + @n_EachQty   -- SOS33358
       IF @n_GroupSeq = 1
       BEGIN
          SELECT @n_Qty1      = @n_Qty
          SELECT @c_Pack1     = @c_Pack
          SELECT @n_TotCases  = @n_CasesQty
          SELECT @n_TotQty    = @n_Qty
          SELECT @n_TotEaches = @n_EachQty   -- SOS33358
       END
       ELSE IF @n_GroupSeq = 2
       BEGIN
          SELECT @n_Qty2      = @n_Qty
          SELECT @c_Pack2     = @c_Pack
       END
       ELSE IF @n_GroupSeq = 3
       BEGIN
          SELECT @n_Qty3      = @n_Qty
          SELECT @c_Pack3     = @c_Pack
       END
       ELSE IF @n_GroupSeq = 4
       BEGIN
          SELECT @n_Qty4      = @n_Qty
          SELECT @c_Pack4     = @c_Pack
        END
       ELSE IF @n_GroupSeq = 5
       BEGIN
          SELECT @n_Qty5      = @n_Qty
          SELECT @c_Pack5     = @c_Pack
       END
       ELSE IF @n_GroupSeq = 6
       BEGIN
          SELECT @n_Qty6      = @n_Qty
          SELECT @c_Pack6     = @c_Pack
       END
       ELSE IF @n_GroupSeq = 7
       BEGIN
       	 SELECT @n_Qty7      = @n_Qty
          SELECT @c_Pack7     = @c_Pack
       END
       ELSE IF @n_GroupSeq = 8
       BEGIN
          SELECT @n_Qty8      = @n_Qty
          SELECT @c_Pack8     = @c_Pack
       END
       FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
    END
    IF @n_CaseCnt <> 0 
       SELECT @c_TotPack = CONVERT(NVARCHAR(10), @n_TotCases)-- modified by Jacob, date: July 23, 2001. description:Changed from NVARCHAR(4) to NVARCHAR(10)
    ELSE
       SELECT @c_TotPack = ''

		-- Start - Add by June 19.Nov.02 -- #8637 (To obtain Correct Lot#)
		SET ROWCOUNT 1
		SELECT @c_lot = SPACE(10)
		
		SELECT @c_lot = Lot
		FROM   PICKDETAIL (NOLOCK)
		WHERE  PICKDETAIL.OrderKey = @c_OrderKey
		AND    PICKDETAIL.SKU   = @c_SKU
		AND    PICKDETAIL.LOC  = @c_LOC
		AND    PICKDETAIL.Lot > @c_lot
		ORDER BY Lot
		
		IF @@ROWCOUNT = 0
		BREAK	
		SET ROWCOUNT 0
		-- End, #8637

    INSERT INTO #CONSOLIDATED VALUES (
          @n_GroupNo,
          @a_s_LoadKey,
			 "",					--	SOS33358
			 @c_Putawayzone, 
          @c_LOC,
          @c_SKU,
          ISNULL(@c_StorerKey1,""),
          ISNULL(@c_OrderKey1,""),
          ISNULL(@c_Route1,""),   
          ISNULL(@c_StorerKey2,""),
          ISNULL(@c_OrderKey2,""),
          ISNULL(@c_Route2,""),
          ISNULL(@c_StorerKey3,""),
          ISNULL(@c_OrderKey3,""),
          ISNULL(@c_Route3,""),
          ISNULL(@c_StorerKey4,""),
          ISNULL(@c_OrderKey4,""),
          ISNULL(@c_Route4,""),
          ISNULL(@c_StorerKey5,""),
          ISNULL(@c_OrderKey5,""),
          ISNULL(@c_Route5,""),
          ISNULL(@c_StorerKey6,""),
          ISNULL(@c_OrderKey6,""),
          ISNULL(@c_Route6,""),
          ISNULL(@c_StorerKey7,""),
          ISNULL(@c_OrderKey7,""),
          ISNULL(@c_Route7,""),
          ISNULL(@c_StorerKey8,""),
          ISNULL(@c_OrderKey8,""),
          ISNULL(@c_Route8,""),
          ISNULL(@n_Qty1,0),
          ISNULL(@n_Qty2,0),
          ISNULL(@n_Qty3,0),
          ISNULL(@n_Qty4,0),
          ISNULL(@n_Qty5,0),
          ISNULL(@n_Qty6,0),
          ISNULL(@n_Qty7,0),
          ISNULL(@n_Qty8,0),
          ISNULL(@c_Pack1,""),
          ISNULL(@c_Pack2,""),
          ISNULL(@c_Pack3,""),
        	 ISNULL(@c_Pack4,""),
          ISNULL(@c_Pack5,""),
          ISNULL(@c_Pack6,""),
          ISNULL(@c_Pack7,""),
          ISNULL(@c_Pack8,""),
          ISNULL(@n_TotQty,0),
          ISNULL(@n_TotCases,0),
          ISNULL(@c_TotPack,""),
          @c_descr,
          @c_uom1,
          @c_uom3,
          @n_casecnt,
          ISNULL(@c_Invoice1,""),
          ISNULL(@c_Invoice2,""),
          ISNULL(@c_Invoice3,""),
          ISNULL(@c_Invoice4,""),
          ISNULL(@c_Invoice5,""),
          ISNULL(@c_Invoice6,""),
          ISNULL(@c_Invoice7,""),
          ISNULL(@c_Invoice8,""),
 			 'Y',
 			 @c_lot,
 			 "",
 			 "",
 			 "",
 			 "",
 			 "",
			 @c_pickheaderkey,
			 ISNULL(@c_company1,""),
			 ISNULL(@c_company2,""),
			 ISNULL(@c_company3,""),
			 ISNULL(@c_company4,""),
			 ISNULL(@c_company5,""),
			 ISNULL(@c_company6,""),
			 ISNULL(@c_company7,""),
			 ISNULL(@c_company8,""),
			 @c_printflag, 
			 "",
			 -- SOS33358
			 @c_PrintedBy,
			 ISNULL(@c_consigneekey1,""),
			 ISNULL(@c_consigneekey2,""),
			 ISNULL(@c_consigneekey3,""),
			 ISNULL(@c_consigneekey4,""),
			 ISNULL(@c_consigneekey5,""),
			 ISNULL(@c_consigneekey6,""),
			 ISNULL(@c_consigneekey7,""),
			 ISNULL(@c_consigneekey8,""),
			 ISNULL(@c_notes1,""),
			 ISNULL(@c_notes2,""),
			 ISNULL(@c_notes3,""),
			 ISNULL(@c_notes4,""),
			 ISNULL(@c_notes5,""),
			 ISNULL(@c_notes6,""),
			 ISNULL(@c_notes7,""),
			 ISNULL(@c_notes8,""),
          ISNULL(@n_TotEaches,0)
          )
    SELECT @n_Qty1=0
    SELECT @n_Qty2=0
    SELECT @n_Qty3=0
    SELECT @n_Qty4=0
    SELECT @n_Qty5=0
    SELECT @n_Qty6=0
    SELECT @n_Qty7=0
    SELECT @n_Qty8=0
    SELECT @c_Pack1=""
    SELECT @c_Pack2=""
    SELECT @c_Pack3=""
    SELECT @c_Pack4=""
    SELECT @c_Pack5=""
    SELECT @c_Pack6=""
    SELECT @c_Pack7=""
    SELECT @c_Pack8=""
    SELECT @n_TotQty=0, @n_CasesQty=0, @c_TotPack=""
    SELECT @c_lot = ""
    -- SOS33358
    SELECT @n_TotEaches=0

    DEALLOCATE CUR_3
    FETCH NEXT FROM CUR_2 INTO @c_Putawayzone, @c_LOC, @c_SKU
 END
 DEALLOCATE CUR_2
 CLOSE CUR_1
 DEALLOCATE CUR_1

/*
-- Remark by June 19.Nov.2002 #8637 (Incorrect Lot - From DIFF order)
 UPDATE #CONSOLIDATED
   SET lot = LOTxLOCxID.lot
 	 LOTTABLE1 = LOTATTRIBUTE.LOTTABLE01,
 	 LOTTABLE2 = LOTATTRIBUTE.LOTTABLE02,
 	 LOTTABLE3 = LOTATTRIBUTE.LOTTABLE03,
 	 LOTTABLE4 = LOTATTRIBUTE.LOTTABLE04,
 	 LOTTABLE5 = LOTATTRIBUTE.LOTTABLE05
 FROM LOTATTRIBUTE (nolock), LOTxLOCxID (nolock)
 WHERE #CONSOLIDATED.SKU = LOTxLOCxID.SKU
 AND   #CONSOLIDATED.loc = LOTxLOCxID.loc
 AND   LOTATTRIBUTE.lot = LOTxLOCxID.lot
 AND   LOTATTRIBUTE.SKU = LOTXLOCXID.SKU -- Added By Vicky Date:07 Dec 2001
 AND   LOTATTRIBUTE.Storerkey = LOTXLOCXID.Storerkey -- Added By Vicky Date:07 Dec 2001
*/

 -- Changed June 20.Nov.2002 - SOS8637
 UPDATE #CONSOLIDATED
   SET LOTTABLE1 = LOTATTRIBUTE.LOTTABLE01,
 	 LOTTABLE2 = LOTATTRIBUTE.LOTTABLE02,
 	 LOTTABLE3 = LOTATTRIBUTE.LOTTABLE03,
 	 LOTTABLE4 = LOTATTRIBUTE.LOTTABLE04,
 	 LOTTABLE5 = LOTATTRIBUTE.LOTTABLE05, 
	 Retailsku = Sku.Retailsku 
 FROM LOTATTRIBUTE (NOLOCK), SKU (NOLOCK)  
 WHERE #CONSOLIDATED.Lot = LOTATTRIBUTE.Lot 
	AND LOTATTRIBUTE.storerkey = SKU.storerkey
   AND LOTATTRIBUTE.sku = SKU.sku

 -- SOS33358
 UPDATE #CONSOLIDATED
 	SET DeliveryZone = LOADPLAN.Delivery_Zone
 FROM LOADPLAN (NOLOCK)
 WHERE #CONSOLIDATED.LoadKey = LOADPLAN.LoadKey 
  AND LOADPLAN.LoadKey = @a_s_LoadKey

 SELECT * FROM #CONSOLIDATED

 DROP TABLE #CONSOLIDATED
 DROP TABLE #SKUGroup
 END /* main procedure */


GO