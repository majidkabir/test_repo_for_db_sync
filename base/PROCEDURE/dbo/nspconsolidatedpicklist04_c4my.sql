SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspConsolidatedPickList04_C4MY] (
 		@a_s_LoadKey NVARCHAR(10)
 )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/************************************************************************/
/* Trigger: nspConsolidatedPickList04_C4MY                              */
/* Creation Date: 17 Jan 2004                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan (Modified From nspConsolidatedPickList04)          */
/*                                                                      */
/* Purpose:   Conso Pick List for C4 - Add Barcode Values               */
/*                                                                      */
/* Input Parameters:    Loadkey                                         */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage: Print Consolidated pickslip                                   */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: RMC Print Consolidated pickslip                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/*                                                                      */
/************************************************************************/

 DECLARE @d_date_start	datetime,
 		@d_date_end		datetime,
 		@c_sku		 NVARCHAR(20),
 		@c_storerkey NVARCHAR(15),
 		@c_lot		 NVARCHAR(10),
 		@c_uom		 NVARCHAR(10),
 		@c_Route       NVARCHAR(10),
 		@c_Exe_String  NVARCHAR(60),
 		@n_Qty         int,
 		@c_Pack        NVARCHAR(10),
 		@n_CaseCnt     int,
 		@n_gn 			int  -- Added by Jacob , Date:Feb 15, 2001

 DECLARE @c_CurrOrderKey NVARCHAR(10),
 		@c_MBOLKey		 NVARCHAR(10),
 		@c_firsttime	 NVARCHAR(1),
 		@c_PrintedFlag	 NVARCHAR(1),
 		@n_err				int,
 		@n_continue			int,
 		@c_PickHeaderKey NVARCHAR(10),
 		@b_success       	int,
 		@c_errmsg         NVARCHAR(255),
		@c_debug			   NVARCHAR(1)

 SELECT @c_debug = '0'

 /* Start Modification */
 -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Conso, 8 - By Order
 IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
 		    WHERE ExternOrderKey = @a_s_LoadKey
 		    AND   Zone = '7')
 BEGIN
 	SELECT @c_firsttime = 'N'
 	SELECT @c_PrintedFlag = 'Y'
 END
 ELSE
 BEGIN
 	SELECT @c_firsttime = 'Y'
 	SELECT @c_PrintedFlag = 'N'
 END -- Record Not Exists
 BEGIN TRAN
 -- Uses PickType as a Printed Flag
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
 	ELSE
 	BEGIN
 		SELECT @n_continue = 3
 		ROLLBACK TRAN
 	END
 END
 IF @c_firsttime = "Y"
 BEGIN
 	EXECUTE nspg_GetKey
 		"PICKSLIP",
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
 	(@c_pickheaderkey, @a_s_LoadKey,     "0",      '7',  "")
 	
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
 		ELSE
 			ROLLBACK TRAN
 	END
 END
 ELSE
 BEGIN
 	SELECT @c_pickheaderkey = PickHeaderKey 
 	FROM  PickHeader (NOLOCK) 
 	WHERE ExternOrderKey = @a_s_LoadKey
 	AND   Zone = '7'
 END
 /*Create Temp Result table */
 SELECT  ConsoGroupNo = 0,
 	Loadplan.LoadKey LoadKey,
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
 	Pack1=Space(10),
 	Pack2=Space(10),
 	Pack3=Space(10),
 	Pack4=Space(10), 
	Pack5=Space(10),
 	Pack6=Space(10),
 	Pack7=Space(10),
 	Pack8=Space(10),
 	TotQty=0,
 	TotCases=0,
 	TotPack=Space(10),
 	DESCR=Space(60),			-- (YokeBeen01)
 	UOM1=Space(10),
 	UOM3=Space(10),
 	CaseCnt=0,
 	ORDERS.ExternOrderKey ExtOrder1, 
 	ORDERS.ExternOrderKey ExtOrder2, 
 	ORDERS.ExternOrderKey ExtOrder3, 
 	ORDERS.ExternOrderKey ExtOrder4, 
 	ORDERS.ExternOrderKey ExtOrder5, 
 	ORDERS.ExternOrderKey ExtOrder6, 
 	ORDERS.ExternOrderKey ExtOrder7,
 	ORDERS.ExternOrderKey ExtOrder8,
 	PickSlipNo=Space(18),
 	Lottable01=Space(18),
 	Lottable02=Space(18),
 	Lottable03=Space(18),
 	Lottable04=Space(40),
 	ORDERS.InvoiceNo InvoiceNo1, 
 	ORDERS.InvoiceNo InvoiceNo2, 
 	ORDERS.InvoiceNo InvoiceNo3, 
 	ORDERS.InvoiceNo InvoiceNo4, 
 	ORDERS.InvoiceNo InvoiceNo5, 
 	ORDERS.InvoiceNo InvoiceNo6, 
 	ORDERS.InvoiceNo InvoiceNo7,
 	ORDERS.InvoiceNo InvoiceNo8,
	PrintedFlag=Space(1),				-- SOS26757
	Barcode1=space(30),
	Barcode2=space(30),
	Barcode3=space(30),
	Barcode4=space(30),
	Barcode5=space(30)
 INTO #CONSOLIDATED 
 FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
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

 DECLARE @n_Qty1   int,      
		   @c_Pack1  NVARCHAR(10),
         @n_Qty2   int,
         @c_Pack2  NVARCHAR(10),
         @n_Qty3   int,
         @c_Pack3  NVARCHAR(10),
         @n_Qty4   int,
         @c_Pack4  NVARCHAR(10),
         @n_Qty5   int,
         @c_Pack5  NVARCHAR(10),
         @n_Qty6   int,
         @c_Pack6  NVARCHAR(10),
         @n_Qty7   int,
         @c_Pack7  NVARCHAR(10),
         @n_Qty8   int,
         @c_Pack8  NVARCHAR(10),
         @n_TotQty   int,
         @c_TotPack  NVARCHAR(10),
         @n_TotCases int,
         @n_CasesQty int,       
			@c_Descr    NVARCHAR(60),		-- (YokeBeen01)
         @c_Packkey  NVARCHAR(10)

 DECLARE @c_Invoice1 NVARCHAR(18),
         @c_Invoice2 NVARCHAR(18),
         @c_Invoice3 NVARCHAR(18),
         @c_Invoice4 NVARCHAR(18),
         @c_Invoice5 NVARCHAR(18),
         @c_Invoice6 NVARCHAR(18),
         @c_Invoice7 NVARCHAR(18),
         @c_Invoice8 NVARCHAR(18)

 DECLARE @c_ExtOrder1 NVARCHAR(30),
         @c_ExtOrder2 NVARCHAR(30),
         @c_ExtOrder3 NVARCHAR(30),
         @c_ExtOrder4 NVARCHAR(30),
         @c_ExtOrder5 NVARCHAR(30),
         @c_ExtOrder6 NVARCHAR(30),
         @c_ExtOrder7 NVARCHAR(30),
         @c_ExtOrder8 NVARCHAR(30)

 DECLARE @c_PickSlipNo NVARCHAR(18),
 	@c_lottable01 NVARCHAR(18),
 	@c_lottable02 NVARCHAR(18),
 	@c_lottable03 NVARCHAR(18), -- SOS14561
 	@d_lottable04 datetime


 DECLARE @c_barcode  NVARCHAR(30),
			@c_barcode1 NVARCHAR(30),
			@c_barcode2 NVARCHAR(30),
  			@c_barcode3 NVARCHAR(30),
			@c_barcode4 NVARCHAR(30),
			@c_barcode5 NVARCHAR(30),
			@n_cnt int


	CREATE TABLE #TEMPBARCODE
	    (Storerkey NVARCHAR(15) NULL,
		 SKU NVARCHAR(20) NULL,
       Barcode NVARCHAR(30) NULL,
		 Rowid int NOT NULL IDENTITY (1, 1))

 
 SELECT  LOC=space(10),
 		SKU.SKU SKU,
 		ORDERS.OrderKey OrderKey,
 		GroupNo=0,
 		GroupSeq=0,
 		Lot=space(10)  
 INTO #SKUGroup
 FROM SKU (NOLOCK), ORDERS (NOLOCK)
 WHERE 1 = 2
 -- Do a grouping for sku
 DECLARE @c_OrderKey NVARCHAR(10),
 		@c_ExtOrder NVARCHAR(30),
 		@c_InvoiceNo NVARCHAR(18), -- SOS20546, Add by June 17.Mar.2004
 		@c_LOC      NVARCHAR(10),
 		@n_Count    int,
 		@n_GroupNo  int,
 		@n_GroupSeq int,
 		@c_logicallocation NVARCHAR(18)
 DECLARE CUR_1 SCROLL CURSOR FOR
 SELECT DISTINCT ORDERDETAIL.OrderKey,
 		ORDERDETAIL.SKU,
 		PICKDETAIL.LOC,
 		LOC.LogicalLocation,
 		PICKDETAIL.Lot
 FROM LoadplanDetail (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK), LOC (nolock)
 WHERE LoadplanDetail.ORDERKEY = ORDERDETAIL.OrderKey
  AND  LoadplanDetail.LoadKey = @a_s_LoadKey
  AND  PICKDETAIL.ORDERKEY 
       = ORDERDETAIL.ORDERKEY
  AND  PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER
  AND  PICKDETAIL.QTY > 0
  AND  PICKDETAIL.LOC = LOC.Loc
  AND  PICKDETAIL.Status < '5'
 ORDER BY ORDERDETAIL.OrderKey

 OPEN CUR_1
 SELECT @n_GroupNo = 1
 SELECT @n_GroupSeq = 0
 FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 WHILE @@FETCH_STATUS <> -1
 BEGIN
 	SELECT @n_Count = Count(*)
 	FROM   #SKUGroup
 	WHERE  OrderKey = @c_OrderKey
    IF @n_Count = 0
    BEGIN
       SELECT @n_GroupSeq = @n_GroupSeq + 1
       IF @n_GroupSeq > 5       		-- 13-Jul-2004 YTWan SOS#24811: Print 5 group in 1 Page
       BEGIN
          SELECT @n_GroupNo=@n_GroupNo + 1
          SELECT @n_GroupSeq = 1
       END
       INSERT INTO #SKUGroup VALUES (" ",
 			" ",
 			@c_OrderKey,
			
 			IsNULL(@n_GroupNo,  1) ,
 			IsNULL(@n_GroupSeq, 1),
 			@c_lot)
    END -- IF ORDERKEY NOT EXIST
    FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 END -- WHILE FETCH STATUS <> -1

 FETCH FIRST FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 WHILE @@FETCH_STATUS <> -1
 BEGIN
    SELECT @n_GroupNo = GroupNo,
           @n_GroupSeq = GroupSeq
    FROM   #SKUGroup
    WHERE  OrderKey = @c_OrderKey
    AND    Lot = @c_lot
    AND    LOC = " "
    AND    SKU = " "
 
   IF @@ROWCOUNT > 0
    BEGIN
       UPDATE #SKUGroup
          SET LOC = @c_LOC,
              SKU = @c_SKU
       WHERE  OrderKey = @c_OrderKey
       AND    Lot = @c_lot
       AND    LOC = " "   
       AND    SKU = " "
    END
    ELSE
    BEGIN
   
    SELECT @n_Count = COUNT(*)
       FROM   #SKUGroup
       WHERE  OrderKey = @c_OrderKey
       AND    Lot = @c_lot
       AND    LOC = @c_Loc
       AND    SKU = @c_SKU
       IF @n_Count = 0
       BEGIN
          SELECT @n_GroupNo = GroupNo,
       
          @n_GroupSeq = GroupSeq
          FROM   #SKUGroup
          WHERE  OrderKey = @c_OrderKey
            AND  Lot = @c_lot
          INSERT INTO #SKUGroup VALUES (@c_LOC,
                   @c_SKU,
                   @c_OrderKey,                
						 IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1),
				 		  @c_lot)
       END
    END
    FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 END


 DECLARE CUR_2 SCROLL CURSOR FOR
    SELECT DISTINCT GROUPNO, LOC, SKU, LOT -- GROUPNO added by Jacob
    FROM   #SKUGroup                       --Date: Feb 15, 2001 
    ORDER BY GROUPNO, LOC, SKU             --Description: so that a record with the same loc, sku, and lot 							 --             BUT different groupno will be inserted into
                                           --             #Consolidated by the insert statement right AFTER the
                                           --             closing of the cursor CUR_2
 OPEN CUR_2
 FETCH NEXT FROM CUR_2 INTO @n_gn, @c_LOC, @c_SKU, @c_lot
 WHILE @@FETCH_STATUS <> -1
 BEGIN
   DECLARE CUR_3 CURSOR FOR 
       SELECT ORDERKEY, GroupNo, GroupSeq, Lot
       FROM   #SKUGroup
       WHERE  LOC = @c_LOC
       AND    Lot = @c_lot
       AND    SKU = @c_SKU
       AND    GROUPNO = @n_gn   -- GROUPNO added by Jacob
                                -- Date : Feb 15, 2001
                                -- Description : So that it will differentiate also records with different GROUPNO
    OPEN CUR_3
    FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq, @c_lot
    WHILE @@FETCH_STATUS <> -1
    BEGIN
       SELECT @c_Route     = ORDERS.Route,           
				  @c_StorerKey = ORDERS.StorerKey,
              @c_ExtOrder = ORDERS.ExternOrderKey,
				  @c_InvoiceNo = ORDERS.Invoiceno -- SOS20546
       FROM   ORDERS (NOLOCK)
       WHERE  ORDERS.OrderKey = @c_OrderKey

       SELECT @n_Qty = 0
    SELECT @c_Pack = ""
       SELECT @n_CaseCnt=0
       SELECT @n_Qty     = SUM(PICKDETAIL.QTY)
       FROM   PICKDETAIL (NOLOCK)
       WHERE  PICKDETAIL.OrderKey = @c_OrderKey
       AND    PICKDETAIL.SKU   = @c_SKU
       AND    PICKDETAIL.LOC  = @c_LOC
       AND    PICKDETAIL.LOT  = @c_LOT

       SELECT @n_CaseCnt = ISNULL(CaseCnt,0)
       FROM   SKU (NOLOCK),    PACK (NOLOCK)
       WHERE  SKU.SKU = @C_SKU
       AND    PACK.PACKKEY = SKU.PACKKEY
		 AND    SKU.Storerkey = @c_Storerkey  -- SOS23855
       IF @n_CaseCnt = 0
          SELECT @c_Pack = " " -- No of Item in Carton not available
       ELSE
       BEGIN
          SELECT @c_Pack = CONVERT(char(10), FLOOR(@n_Qty / @n_CaseCnt))
          SELECT @n_CasesQty = FLOOR(@n_Qty / @n_CaseCnt)
          SELECT @n_Qty = @n_Qty % @n_CaseCnt
       END
       SELECT @n_TotQty   = @n_TotQty  + @n_Qty
       SELECT @n_TotCases = @n_TotCases + @n_CasesQty
       IF @n_GroupSeq = 1
       BEGIN
          SELECT @c_Route1 = @c_Route
          SELECT @c_ExtOrder1 = @c_ExtOrder
          SELECT @c_Invoice1 = @c_InvoiceNo -- SOS20546
          SELECT @c_StorerKey1 = @c_StorerKey
          SELECT @c_OrderKey1 = @c_OrderKey
          SELECT @n_Qty1      = @n_Qty
          SELECT @c_Pack1     = @c_Pack
          SELECT @n_TotCases = @n_CasesQty
          SELECT @n_TotQty   = @n_Qty
          UPDATE #CONSOLIDATED
				 SET Route1 =IsNULL(@c_Route,"") ,
                 StorerKey1 = @c_StorerKey,
                 OrderKey1 = @c_OrderKey,
                 ExtOrder1 = @c_ExtOrder,
					  InvoiceNo1 = @c_InvoiceNo -- SOS20546
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 2
		 BEGIN
          SELECT @c_Route2 = @c_Route
          SELECT @c_StorerKey2 = @c_StorerKey
          SELECT @c_OrderKey2 = @c_OrderKey
          SELECT @n_Qty2      = @n_Qty
  	       SELECT @c_Pack2     = @c_Pack
          SELECT @c_ExtOrder2 = @c_ExtOrder
			 SELECT @c_Invoice2 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route2 = @c_Route,
                 StorerKey2 = @c_StorerKey,            
				     OrderKey2 = @c_OrderKey,
                 ExtOrder2 = @c_ExtOrder,
					  InvoiceNo2 = @c_InvoiceNo -- SOS20546
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 3
       BEGIN
          SELECT @c_Route3 = @c_Route
  
        SELECT @c_StorerKey3 = @c_StorerKey
          SELECT @c_OrderKey3 = @c_OrderKey
          SELECT @n_Qty3      = @n_Qty
          SELECT @c_Pack3     = @c_Pack
          SELECT @c_ExtOrder3 = @c_ExtOrder
			 SELECT @c_Invoice3 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route3 = @c_Route,
                 StorerKey3 = @c_StorerKey,
                 OrderKey3  = @c_OrderKey,
                 ExtOrder3 = @c_ExtOrder,
					  InvoiceNo3 = @c_InvoiceNo -- SOS20546        
					  WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 4
       BEGIN
          SELECT @c_Route4 = @c_Route
          SELECT @c_StorerKey4 = @c_StorerKey
          SELECT @c_OrderKey4 = @c_OrderKey
          SELECT @n_Qty4      = @n_Qty
          SELECT @c_Pack4     = @c_Pack
          SELECT @c_ExtOrder4 = @c_ExtOrder
			 SELECT @c_Invoice4 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route4 = @c_Route,
                 StorerKey4 = @c_StorerKey,        
			        OrderKey4 = @c_OrderKey,
                 ExtOrder4 = @c_ExtOrder,
					  InvoiceNo4 = @c_InvoiceNo -- SOS20546
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 5
       BEGIN
          SELECT @c_Route5 = @c_Route
          SELECT @c_StorerKey5 = @c_StorerKey
          SELECT @c_OrderKey5 = @c_OrderKey
          SELECT @n_Qty5      = @n_Qty
          SELECT @c_Pack5     = @c_Pack
          SELECT @c_ExtOrder5 = @c_ExtOrder
			 SELECT @c_Invoice5 = @c_InvoiceNo -- SOS20546

          UPDATE #CONSOLIDATED
             SET Route5 = @c_Route,
                 StorerKey5 = @c_StorerKey,
                 OrderKey5 = @c_OrderKey,
                  ExtOrder5 = @c_ExtOrder,
						InvoiceNo5 = @c_InvoiceNo -- SOS20546
    
      WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 6
       BEGIN
          SELECT @c_Route6 = @c_Route
          SELECT @c_StorerKey6 = @c_StorerKey
          SELECT @c_OrderKey6 = @c_OrderKey
          SELECT @n_Qty6      = @n_Qty
          SELECT @c_Pack6     = @c_Pack
          SELECT @c_ExtOrder6 = @c_ExtOrder
			 SELECT @c_Invoice6 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route6 = @c_Route,
                 StorerKey6 = @c_StorerKey,    
		           OrderKey6 = @c_OrderKey,
                 ExtOrder6 = @c_ExtOrder,
					  InvoiceNo6 = @c_InvoiceNo -- SOS20546
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 7
       BEGIN
          SELECT @c_Route7 = @c_Route
          SELECT @c_StorerKey7 = @c_StorerKey
          SELECT @c_OrderKey7 = @c_OrderKey
          SELECT @n_Qty7      = @n_Qty
          SELECT @c_Pack7     = @c_Pack
          SELECT @c_ExtOrder7 = @c_ExtOrder
			 SELECT @c_Invoice7 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route7 = @c_Route,
                 StorerKey7 = @c_StorerKey,
                 OrderKey7 = @c_OrderKey,
                 ExtOrder7 = @c_ExtOrder,
					  InvoiceNo7 = @c_InvoiceNo -- SOS20546
 
         WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 8
       BEGIN
          SELECT @c_Route8 = @c_Route
          SELECT @c_StorerKey8 = @c_StorerKey
          SELECT @c_OrderKey8 = @c_OrderKey
          SELECT @n_Qty8      = @n_Qty
          SELECT @c_Pack8     = @c_Pack
          SELECT @c_ExtOrder8 = @c_ExtOrder
			 SELECT @c_Invoice8 = @c_InvoiceNo -- SOS20546
          UPDATE #CONSOLIDATED
             SET Route8 = @c_Route,
                 StorerKey8 = @c_StorerKey, 
                 OrderKey8 = @c_OrderKey,
                 ExtOrder8 = @c_ExtOrder,
					  InvoiceNo8 = @c_InvoiceNo -- SOS20546
          WHERE  ConsoGroupNo = @n_GroupNo
       END
		 	SELECT  @c_Lottable01 = Lottable01,
 					  @c_Lottable02 = Lottable02,
			 		  @c_Lottable03 = Lottable03, -- SOS14561
                 @d_Lottable04 = Lottable04
          FROM   LOTATTRIBUTE (NOLOCK)
          WHERE  LOT = @c_LOT
       FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq, @c_lot
    END

    IF @n_CaseCnt <> 0 
		SELECT @c_TotPack = CONVERT(char(10), @n_TotCases)
    ELSE
		SELECT @c_TotPack = ''  -- select @n_gn groupno, @c_orderkey ordkey

		INSERT INTO #CONSOLIDATED VALUES (
          @n_GroupNo,
          @a_s_LoadKey,
          @c_LOC,      
		    @c_SKU,
          IsNULL(@c_StorerKey1,""),
          IsNULL(@c_OrderKey1,""),
          IsNULL(@c_Route1,""),   
          IsNULL(@c_StorerKey2,""),
          IsNULL(@c_OrderKey2,""),
          IsNULL(@c_Route2,""),
          IsNULL(@c_StorerKey3,""),
          IsNULL(@c_OrderKey3,""),
          IsNULL(@c_Route3,""),
          IsNULL(@c_StorerKey4,""),
          IsNULL(@c_OrderKey4,""),
          IsNULL(@c_Route4,""),
          IsNULL(@c_StorerKey5,""),
          IsNULL(@c_OrderKey5,""),
          IsNULL(@c_Route5,""),
          IsNULL(@c_StorerKey6,""),
          IsNULL(@c_OrderKey6,""),
          IsNULL(@c_Route6,""),
          IsNULL(@c_StorerKey7,""),
          IsNULL(@c_OrderKey7,""),
          IsNULL(@c_Route7,""),
          IsNULL(@c_StorerKey8,""),
          IsNULL(@c_OrderKey8,""),
          IsNULL(@c_Route8,""),
          IsNULL(@n_Qty1,0),
          IsNULL(@n_Qty2,0),
          IsNULL(@n_Qty3,0),
          IsNULL(@n_Qty4,0),
          IsNULL(@n_Qty5,0),
          IsNULL(@n_Qty6,0),       
		    IsNULL(@n_Qty7,0),
          IsNULL(@n_Qty8,0),
          IsNull(@c_Pack1,""),
          IsNull(@c_Pack2,""),
          IsNull(@c_Pack3,""),
          IsNull(@c_Pack4,""),
          IsNull(@c_Pack5,""),
          IsNull(@c_Pack6,""),
          IsNull(@c_Pack7,""),
          IsNull(@c_Pack8,""),
          IsNull(@n_TotQty,0),
          IsNull(@n_TotCases,0),
          IsNull(@c_TotPack,""),
          "",
          "",
          "",
          0,
          ISNULL(@c_ExtOrder1,""),
          ISNULL(@c_ExtOrder2,""),
          ISNULL(@c_ExtOrder3,""),
          ISNULL(@c_ExtOrder4,""),
          ISNULL(@c_ExtOrder5,""),
          ISNULL(@c_ExtOrder6,""),
          ISNULL(@c_ExtOrder7,""),
          ISNULL(@c_ExtOrder8,""),
	 		 @c_PickHeaderKey,
	 		 @c_lottable01,
	 		 @c_lottable02,
	 		 @c_lottable03, -- SOS14561
		 	--	 CONVERT(char(10), @d_lottable04, 103)
 			 @d_lottable04,
			 -- Start - SOS20546
          ISNULL(@c_Invoice1,""),
          ISNULL(@c_Invoice2,""),
          ISNULL(@c_Invoice3,""),         
			 ISNULL(@c_Invoice4,""),
          ISNULL(@c_Invoice5,""),
          ISNULL(@c_Invoice6,""),
          ISNULL(@c_Invoice7,""),
          ISNULL(@c_Invoice8,""),
			 -- End - SOS20546
			 @c_PrintedFlag, 	-- SOS26757
          ISNULL(@c_barcode1,""),
			 ISNULL(@c_barcode2,""),
			 ISNULL(@c_barcode3,""),
			 ISNULL(@c_barcode4,""),
			 ISNULL(@c_barcode5,""))

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
   
    SELECT @c_lottable01=""
    SELECT @c_lottable02=""
    SELECT @c_lottable03="" -- SOS14561
    SELECT @d_lottable04=NULL
    SELECT @n_TotQty=0, @n_CasesQty=0, @c_TotPack=""
   
    DEALLOCATE CUR_3
    FETCH NEXT FROM CUR_2 INTO @n_gn, @c_LOC, @c_SKU, @c_lot
 END
 DEALLOCATE CUR_2
 CLOSE CUR_1
 DEALLOCATE CUR_1

-- Comment by June 03.June.04 SOS23855
-- Move it to bottom, update the descr after updating empty Orderkey1
/*
 UPDATE #CONSOLIDATED
    SET DESCR=SKU.DESCR,
        UOM1=PACK.Packuom1,
        UOM3=Pack.PackUOM3,
        CaseCnt=Pack.CaseCnt
 FROM SKU (NOLOCK), PACK (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = SKU.Storerkey -- SOS23855
 AND   #CONSOLIDATED.SKU = SKU.SKU
 AND   SKU.PACKKEY = PACK.PACKKEY
*/

 /* Start Modification */
    BEGIN TRAN
       UPDATE PickDetail
       SET PickSlipNo = PICKHEADER.PickHeaderKey,
           Trafficcop = NULL
       FROM   PickDetail ,  LoadPlanDetail, PickHeader 
       WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
       AND    PickDetail.Status IN ('0','1','2','3','4')
       AND    PickHeader.ExternOrderKey = LoadPlanDetail.LoadKey
       AND    PickHeader.Zone = '7'
       AND    LoadPlanDetail.LoadKey = @a_s_LoadKey
       AND    ( PickDetail.PickSlipNo is NULL OR PICKDETAIL.Pickslipno = '' )
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
 			ELSE
 				ROLLBACK TRAN
       END
 /*
 End */
 SELECT @c_orderkey = orderkey1,
 		@c_storerkey = storerkey1,
 		@c_ExtOrder = ExtOrder1,
 		@c_InvoiceNo = InvoiceNo1, -- SOS20546
 		@c_route = route1
 FROM #consolidated
 WHERE orderkey1 <> ''

 UPDATE #consolidated
 SET orderkey1 = @c_orderkey,
     storerkey1 = @c_storerkey,
     ExtOrder1 = @c_ExtOrder,
	  Invoiceno1 = @c_InvoiceNo, -- SOS20546
     route1 = @c_route
 WHERE orderkey1 = ''

-- Move by June 03.June.04 SOS23855
-- Update the descr after updating empty Orderkey1
 UPDATE #CONSOLIDATED
    SET DESCR=SKU.DESCR,
        UOM1=PACK.Packuom1,
        UOM3=Pack.PackUOM3,
        CaseCnt=Pack.CaseCnt
 FROM SKU (NOLOCK), PACK (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = SKU.Storerkey 
 AND   #CONSOLIDATED.SKU = SKU.SKU
 AND   SKU.PACKKEY = PACK.PACKKEY

 INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
 SELECT #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.MANUFACTURERSKU 
 FROM #CONSOLIDATED, SKU (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = SKU.Storerkey 
 AND   #CONSOLIDATED.SKU = SKU.SKU
 AND   dbo.fnc_LTrim(dbo.fnc_RTrim(SKU.MANUFACTURERSKU)) IS NOT NULL
 GROUP BY  #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.MANUFACTURERSKU

 INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
 SELECT #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.ALTSKU 
 FROM #CONSOLIDATED, SKU (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = SKU.Storerkey 
 AND   #CONSOLIDATED.SKU = SKU.SKU
 AND   dbo.fnc_LTrim(dbo.fnc_RTrim(SKU.ALTSKU)) IS NOT NULL
 GROUP BY  #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.ALTSKU
 
 INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
 SELECT #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.RetailSku 
 FROM #CONSOLIDATED, SKU (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = SKU.Storerkey 
 AND   #CONSOLIDATED.SKU = SKU.SKU
 AND   dbo.fnc_LTrim(dbo.fnc_RTrim(SKU.RetailSku)) IS NOT NULL
 GROUP BY  #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, SKU.RetailSku

 INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
 SELECT #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, UPC.UPC 
 FROM #CONSOLIDATED, UPC (NOLOCK)
 WHERE #CONSOLIDATED.Storerkey1 = UPC.Storerkey 
 AND   #CONSOLIDATED.SKU = UPC.SKU
 GROUP BY  #CONSOLIDATED.Storerkey1, #CONSOLIDATED.SKU, UPC.UPC

 DECLARE bc_cursor CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT DISTINCT Storerkey, Sku 
    FROM   #TEMPBARCODE 
 OPEN bc_cursor
 FETCH NEXT FROM bc_cursor INTO @c_storerkey, @c_Sku 
 WHILE @@FETCH_STATUS <> -1
 BEGIN 
		SELECT @c_barcode1 = '', @c_barcode2 = '', @c_barcode3 = '', @c_barcode4 = '', @c_barcode5 = ''

		SELECT @n_cnt = 1
		DECLARE bc1_cursor CURSOR FAST_FORWARD READ_ONLY FOR
		    SELECT Barcode 
		    FROM   #TEMPBARCODE 
			 WHERE  Storerkey = @c_storerkey
			 AND    Sku = @c_Sku 
			 order  by rowid
		OPEN bc1_cursor
		FETCH NEXT FROM bc1_cursor INTO @c_barcode
		WHILE @@FETCH_STATUS <> -1
		BEGIN 
				IF @n_cnt = 1
					SELECT @c_barcode1 = @c_barcode
				IF @n_cnt = 2
					SELECT @c_barcode2 = @c_barcode
				IF @n_cnt = 3
					SELECT @c_barcode3 = @c_barcode
				IF @n_cnt = 4
					SELECT @c_barcode4 = @c_barcode
				IF @n_cnt = 5
				BEGIN
					SELECT @c_barcode5 = @c_barcode
					BREAK
				END
				Select @n_cnt = @n_cnt + 1

				FETCH NEXT FROM bc1_cursor INTO @c_barcode
		END

		UPDATE #CONSOLIDATED
		    SET Barcode1=@c_barcode1,
		        Barcode2=@c_barcode2,
		        Barcode3=@c_barcode3,
		        Barcode4=@c_barcode4,
				  Barcode5=@c_barcode5
		WHERE #CONSOLIDATED.Storerkey1 = @c_storerkey
		AND   #CONSOLIDATED.SKU = @c_Sku
		CLOSE  bc1_cursor
		DEALLOCATE bc1_cursor

		FETCH NEXT FROM bc_cursor INTO @c_storerkey, @c_Sku 
 END 
 CLOSE  bc_cursor 
 DEALLOCATE bc_cursor
 
 Drop table #TEMPBARCODE
 

-- (YokeBeen02) - Start.
--  SELECT @c_orderkey = orderkey1
--  FROM #consolidated
--  WHERE orderkey1 <> ''
-- 
--  UPDATE #consolidated
--  SET orderkey1 = @c_orderkey
--  WHERE orderkey1 = ''

 DECLARE CUR_4 SCROLL CURSOR FOR
    SELECT DISTINCT ConsoGroupNo 
    FROM   #consolidated    
	 ORDER BY ConsoGroupNo

 OPEN CUR_4
 FETCH NEXT FROM CUR_4 INTO @n_GroupNo 
 WHILE @@FETCH_STATUS <> -1
 BEGIN
	 SELECT @c_orderkey1 = max(orderkey1),
			  @c_route1 = max(route1),
			  @c_storerkey1 = max(storerkey1),
			  @c_ExtOrder1 = max(ExtOrder1),
			  @c_orderkey2 = max(orderkey2),
			  @c_route2 = max(route2),
			  @c_storerkey2 = max(storerkey2),
			  @c_ExtOrder2 = max(ExtOrder2),
			  @c_orderkey3 = max(orderkey3),
			  @c_route3 = max(route3),
			  @c_storerkey3 = max(storerkey3),
			  @c_ExtOrder3 = max(ExtOrder3),
			  @c_orderkey4 = max(orderkey4),
			  @c_route4 = max(route4),
			  @c_storerkey4 = max(storerkey4),
			  @c_ExtOrder4 = max(ExtOrder4),
			  @c_orderkey5 = max(orderkey5),
			  @c_route5 = max(route5),
			  @c_storerkey5 = max(storerkey5),
			  @c_ExtOrder5 = max(ExtOrder5)
	 FROM #consolidated 
	 WHERE (orderkey2 <> '' OR orderkey3 <> '' OR orderkey4 <> '' OR orderkey5 <> '')
	 AND ConsoGroupNo = @n_GroupNo

	 if @c_debug = '1'
	 begin
		 print '#Consolidated - #1...'
		 SELECT	'Orderkey2 - ', @c_orderkey2 , @c_route2, @c_storerkey2, @c_ExtOrder2, 
					'Orderkey3 - ', @c_orderkey3 , @c_route3, @c_storerkey3, @c_ExtOrder3, 
					'Orderkey4 - ', @c_orderkey4 , @c_route4, @c_storerkey4, @c_ExtOrder4, 
					'Orderkey5 - ', @c_orderkey5 , @c_route5, @c_storerkey5, @c_ExtOrder5, 
					'ConsoGroupNo - ', @n_GroupNo
	 end

	 UPDATE #consolidated
	 SET orderkey1 = ISNULL(@c_orderkey1,'') ,
		  storerkey1 = ISNULL(@c_storerkey1,'') ,
		  route1 = ISNULL(@c_route1,'') ,
		  ExtOrder1 = ISNULL(@c_ExtOrder1,'') 
	 WHERE orderkey1 = ''
	 AND ConsoGroupNo = @n_GroupNo

	 UPDATE #consolidated
	 SET orderkey2 = ISNULL(@c_orderkey2,'')  ,
		  storerkey2 = ISNULL(@c_storerkey2,'') ,
		  route2 = ISNULL(@c_route2,'') ,
		  ExtOrder2 = ISNULL(@c_ExtOrder2,'')
	 WHERE orderkey2 = ''
	 AND ConsoGroupNo = @n_GroupNo
	
	 UPDATE #consolidated
	 SET orderkey3 = ISNULL(@c_orderkey3,'') ,
		  storerkey3 = ISNULL(@c_storerkey3,'') ,
		  route3 = ISNULL(@c_route3,'') ,
		  ExtOrder3 = ISNULL(@c_ExtOrder3,'')
	 WHERE orderkey3 = ''
	 AND ConsoGroupNo = @n_GroupNo
	
	 UPDATE #consolidated
	 SET orderkey4 = ISNULL(@c_orderkey4,'') ,
		  storerkey4 = ISNULL(@c_storerkey4,'') ,
		  route4 = ISNULL(@c_route4,'') ,
		  ExtOrder4 = ISNULL(@c_ExtOrder4,'') 
	 WHERE orderkey4 = ''
	 AND ConsoGroupNo = @n_GroupNo
	
	 UPDATE #consolidated
	 SET orderkey5 = ISNULL(@c_orderkey5,'') ,
		  storerkey5 = ISNULL(@c_storerkey5,'') ,
		  route5 = ISNULL(@c_route5,'') ,
		  ExtOrder5 = ISNULL(@c_ExtOrder5,'') 
	 WHERE orderkey5 = ''
	 AND ConsoGroupNo = @n_GroupNo
	
	 FETCH NEXT FROM CUR_4 INTO @n_GroupNo 
 END
 CLOSE CUR_4
 DEALLOCATE CUR_4
-- (YokeBeen02) - End.

 if @c_debug = '1'
 begin
	 print '#Consolidated - #2...'
	 select * from #consolidated 
 end

 SELECT #consolidated.* 
 FROM #CONSOLIDATED, LOC (NOLOCK)
 where #consolidated.loc = LOC.loc
 order by loc.logicallocation

 DROP TABLE #CONSOLIDATED
 DROP TABLE #SKUGroup

 END /* main procedure */

GO