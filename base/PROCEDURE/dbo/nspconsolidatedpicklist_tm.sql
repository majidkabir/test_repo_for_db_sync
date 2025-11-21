SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****** Object:  Stored Procedure dbo.nspConsolidatedPickList_TM2    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspConsolidatedPickList_TM](
 @a_s_LoadKey NVARCHAR(10)
 )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  DECLARE @d_date_start	datetime,
 	@d_date_end	datetime,
 	@c_sku	 NVARCHAR(20),
 	@c_storerkey NVARCHAR(15),
 	@c_lot	 NVARCHAR(10),
 	@c_uom	 NVARCHAR(10),
         @c_Route        NVARCHAR(10),
         @c_Exe_String   NVARCHAR(60),
         @n_Qty          int,
         @c_Pack         NVARCHAR(10),
         @n_CaseCnt      int
 DECLARE @c_CurrOrderKey NVARCHAR(10),
 	@c_MBOLKey NVARCHAR(10),
         @c_firsttime NVARCHAR(1),
         @c_PrintedFlag  NVARCHAR(1),
         @n_err          int,
         @n_continue     int,
         @c_PickHeaderKey NVARCHAR(10),
         @b_success       int,
         @c_errmsg        NVARCHAR(255)
 /* Start Modification */
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order, 4 - RF TM Consolidated pick list, 5 - RF TM By Order
    IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
              WHERE ExternOrderKey = @a_s_LoadKey
              AND   Zone = "4")
    BEGIN
       SELECT @c_firsttime = 'N'
       SELECT @c_PrintedFlag = 'Y'
    END
    ELSE
    BEGIN
       SELECT @c_firsttime = 'Y'
       SELECT @c_PrintedFlag = "N"
    END -- Record Not Exists
       BEGIN TRAN
       -- Uses PickType as a Printed Flag
       UPDATE PickHeader
       SET PickType = '1',
           TrafficCop = NULL
       WHERE ExternOrderKey = @a_s_LoadKey
       AND Zone = "4"
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
                    (@c_pickheaderkey, @a_s_LoadKey,     "0",      "4",  "")
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
                SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK) 
                 WHERE ExternOrderKey = @a_s_LoadKey
                 AND   Zone = "4"
             END
 /* End */
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
         DESCR=Space(60),
         UOM1=Space(10),
         UOM3=Space(10),
         CaseCnt=0,
         ORDERS.ExternOrderKey InvoiceNo1, 
         ORDERS.ExternOrderKey InvoiceNo2, 
         ORDERS.ExternOrderKey InvoiceNo3, 
         ORDERS.ExternOrderKey InvoiceNo4, 
         ORDERS.ExternOrderKey InvoiceNo5, 
         ORDERS.ExternOrderKey InvoiceNo6, 
         ORDERS.ExternOrderKey InvoiceNo7,
         ORDERS.ExternOrderKey InvoiceNo8,
 	LabelFlag='Y' ,
        PICKDETAIL.LOT Lot,
        LOTATTRIBUTE.Lottable01 lottable1,
        LOTATTRIBUTE.Lottable02 lottable2,
        LOTATTRIBUTE.Lottable03 lottable3,
        LOTATTRIBUTE.Lottable04 lottable4,
        LOTATTRIBUTE.Lottable05 lottable5
 INTO #CONSOLIDATED 
 FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK), LOTATTRIBUTE(NOLOCK)
 where 1 = 2
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
         @c_Descr    NVARCHAR(60),
         @c_Packkey  NVARCHAR(10)
 DECLARE @c_Invoice1 NVARCHAR(18),
         @c_Invoice2 NVARCHAR(18),
         @c_Invoice3 NVARCHAR(18),
         @c_Invoice4 NVARCHAR(18),
         @c_Invoice5 NVARCHAR(18),
         @c_Invoice6 NVARCHAR(18),
         @c_Invoice7 NVARCHAR(18),
         @c_Invoice8 NVARCHAR(18)
 SELECT  LOC=space(10),
         SKU.SKU SKU,
 	ORDERS.OrderKey OrderKey,
         GroupNo=0,
         GroupSeq=0       
 INTO #SKUGroup
 FROM SKU, ORDERS
 WHERE 1 = 2
 -- Do a grouping for sku
 DECLARE @c_OrderKey NVARCHAR(10),
         @c_Invoice NVARCHAR(18),
         @c_LOC      NVARCHAR(10),
         @n_Count    int,
         @n_GroupNo  int,
         @n_GroupSeq int,
 	@c_logicallocation NVARCHAR(18)
 DECLARE CUR_1 SCROLL CURSOR FOR
 SELECT 	DISTINCT ORDERDETAIL.OrderKey,
 	ORDERDETAIL.SKU,
              PICKDETAIL.LOC,
 	LOC.LogicalLocation,
 	PICKDETAIL.LOT
 FROM LoadplanDetail (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK), LOC (nolock), ORDERS (nolock), SKUxLOC (NOLOCK)
 WHERE LoadplanDetail.ORDERKEY = ORDERDETAIL.OrderKey
  AND  ORDERS.Orderkey = ORDERDETAIL.Orderkey
  AND  ORDERS.Orderkey = LOADPLANDETAIL.Orderkey
  AND  LoadplanDetail.LoadKey = @a_s_LoadKey
  AND  PICKDETAIL.ORDERKEY        = ORDERDETAIL.ORDERKEY
  AND  PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER
  AND  PICKDETAIL.QTY > 0
  AND  PICKDETAIL.LOC = LOC.Loc
  AND  PICKDETAIL.Status < '5'
 AND   PICKDETAIL.SKU = SKUxLOC.SKU
 AND   PICKDETAIL.LOC = SKUxLOC.LOC
 AND   PICKDETAIL.Storerkey = SKUxLOC.StorerKey
 AND 	SKUxLOC.LocationType IN ('PICK', 'CASE')
 -- added by jeff, for pricelabel = 'Y'
  AND  ( ORDERS.LabelPrice = 'Y' )
 ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, ORDERDETAIL.SKU, ORDERDETAIL.OrderKey
 -- ORDER BY  PICKDETAIL.LOC, ORDERDETAIL.SKU, ORDERDETAIL.OrderKey
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
       IF @n_GroupSeq > 8
       BEGIN
          SELECT @n_GroupNo=@n_GroupNo + 1
          SELECT @n_GroupSeq = 1
       END
       INSERT INTO #SKUGroup VALUES (" ",
                   " ",
                   @c_OrderKey,
                   IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1))
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
    AND    LOC = " "
    AND    SKU = " "
    IF @@ROWCOUNT > 0
    BEGIN
       UPDATE #SKUGroup
          SET LOC = @c_LOC,
              SKU = @c_SKU
       WHERE  OrderKey = @c_OrderKey
       AND    LOC = " "   
       AND    SKU = " "
    END
    ELSE
    BEGIN
       SELECT @n_Count = COUNT(*)
       FROM   #SKUGroup
       WHERE  OrderKey = @c_OrderKey
       AND    LOC = @c_Loc
       AND    SKU = @c_SKU
       IF @n_Count = 0
       BEGIN
          SELECT @n_GroupNo = GroupNo,
                 @n_GroupSeq = GroupSeq
          FROM   #SKUGroup
          WHERE  OrderKey = @c_OrderKey
          INSERT INTO #SKUGroup VALUES (@c_LOC,
                   @c_SKU,
                   @c_OrderKey,
                   IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1))
       END
    END
    FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 END
 DECLARE CUR_2 SCROLL CURSOR FOR
    SELECT DISTINCT LOC, SKU
    FROM   #SKUGroup
    ORDER BY LOC, SKU
 OPEN CUR_2
 FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
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
       SELECT @c_Route     = ORDERS.Route,
              @c_StorerKey = ORDERS.StorerKey,
              @c_Invoice = ORDERS.ExternOrderKey
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
       SELECT @n_CaseCnt = ISNULL(CaseCnt,0)
       FROM   SKU (NOLOCK),    PACK (NOLOCK)
       WHERE  SKU.SKU = @C_SKU
       AND    PACK.PACKKEY = SKU.PACKKEY
       IF @n_CaseCnt = 0
          SELECT @c_Pack = " " -- No of Item in Carton not available
       ELSE
       BEGIN
       SELECT @c_Pack = CONVERT(char(3), FLOOR(@n_Qty / @n_CaseCnt))
           IF @c_Pack = '0' select @c_Pack = ""
          SELECT @n_CasesQty = FLOOR(@n_Qty / @n_CaseCnt)
          SELECT @n_Qty = @n_Qty % @n_CaseCnt
       END
       SELECT @n_TotQty   = @n_TotQty  + @n_Qty
       SELECT @n_TotCases = @n_TotCases + @n_CasesQty
       IF @n_GroupSeq = 1
       BEGIN
          SELECT @c_Route1 = @c_Route
          SELECT @c_Invoice1 = @c_Invoice
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
                 InvoiceNo1 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 2
       BEGIN
          SELECT @c_Route2 = @c_Route
          SELECT @c_StorerKey2 = @c_StorerKey
          SELECT @c_OrderKey2 = @c_OrderKey
          SELECT @n_Qty2      = @n_Qty
          SELECT @c_Pack2     = @c_Pack
          SELECT @c_Invoice2 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route2 = @c_Route,
                 StorerKey2 = @c_StorerKey,
                 OrderKey2 = @c_OrderKey,
                 InvoiceNo2 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 3
       BEGIN
          SELECT @c_Route3 = @c_Route
          SELECT @c_StorerKey3 = @c_StorerKey
          SELECT @c_OrderKey3 = @c_OrderKey
          SELECT @n_Qty3      = @n_Qty
          SELECT @c_Pack3     = @c_Pack
          SELECT @c_Invoice3 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route3 = @c_Route,
                 StorerKey3 = @c_StorerKey,
                 OrderKey3  = @c_OrderKey,
                 InvoiceNo3 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 4
       BEGIN
          SELECT @c_Route4 = @c_Route
          SELECT @c_StorerKey4 = @c_StorerKey
          SELECT @c_OrderKey4 = @c_OrderKey
          SELECT @n_Qty4      = @n_Qty
          SELECT @c_Pack4     = @c_Pack
          SELECT @c_Invoice4 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route4 = @c_Route,
                 StorerKey4 = @c_StorerKey,
                 OrderKey4 = @c_OrderKey,
                 InvoiceNo4 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 5
       BEGIN
          SELECT @c_Route5 = @c_Route
          SELECT @c_StorerKey5 = @c_StorerKey
          SELECT @c_OrderKey5 = @c_OrderKey
          SELECT @n_Qty5      = @n_Qty
          SELECT @c_Pack5     = @c_Pack
          SELECT @c_Invoice5 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route5 = @c_Route,
                 StorerKey5 = @c_StorerKey,
                 OrderKey5 = @c_OrderKey,
                  InvoiceNo5 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 6
       BEGIN
          SELECT @c_Route6 = @c_Route
          SELECT @c_StorerKey6 = @c_StorerKey
          SELECT @c_OrderKey6 = @c_OrderKey
          SELECT @n_Qty6      = @n_Qty
          SELECT @c_Pack6     = @c_Pack
          SELECT @c_Invoice6 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route6 = @c_Route,
                 StorerKey6 = @c_StorerKey,
                 OrderKey6 = @c_OrderKey,
                 InvoiceNo6 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 7
       BEGIN
          SELECT @c_Route7 = @c_Route
          SELECT @c_StorerKey7 = @c_StorerKey
          SELECT @c_OrderKey7 = @c_OrderKey
          SELECT @n_Qty7      = @n_Qty
          SELECT @c_Pack7     = @c_Pack
          SELECT @c_Invoice7 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route7 = @c_Route,
                 StorerKey7 = @c_StorerKey,
                 OrderKey7 = @c_OrderKey,
                 InvoiceNo7 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 8
       BEGIN
          SELECT @c_Route8 = @c_Route
          SELECT @c_StorerKey8 = @c_StorerKey
          SELECT @c_OrderKey8 = @c_OrderKey
          SELECT @n_Qty8      = @n_Qty
          SELECT @c_Pack8     = @c_Pack
          SELECT @c_Invoice8 = @c_Invoice
          UPDATE #CONSOLIDATED
             SET Route8 = @c_Route,
                 StorerKey8 = @c_StorerKey,
                 OrderKey8 = @c_OrderKey,
                 InvoiceNo8 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
    END
    IF @n_CaseCnt <> 0 
       SELECT @c_TotPack = CONVERT(char(3), @n_TotCases)
    ELSE
       SELECT @c_TotPack = ''
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
          ""
          )
    select * from #consolidated
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
    SELECT @c_Invoice1=""
    SELECT @c_Invoice2=""
    SELECT @c_Invoice3=""
    SELECT @c_Invoice4=""
    SELECT @c_Invoice5=""
    SELECT @c_Invoice6=""
    SELECT @c_Invoice7=""
    SELECT @c_Invoice8=""
    SELECT @n_TotQty=0, @n_CasesQty=0, @c_TotPack=""
    SELECT @c_lot = ""
    DEALLOCATE CUR_3
    FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
 END
 DEALLOCATE CUR_2
 CLOSE CUR_1
 DEALLOCATE CUR_1
 UPDATE #CONSOLIDATED
    SET DESCR=SKU.DESCR,
        UOM1=PACK.Packuom1,
        UOM3=Pack.PackUOM3,
        CaseCnt=Pack.CaseCnt
 FROM SKU, PACK
 WHERE #CONSOLIDATED.SKU = SKU.SKU
 AND   SKU.PACKKEY = PACK.PACKKEY
 UPDATE #CONSOLIDATED
       SET lot = LOTxLOCxID.lot,
 	 lottable1 = LOTATTRIBUTE.lottable01,
 	 lottable2 = LOTATTRIBUTE.lottable02,
 	 lottable3 = LOTATTRIBUTE.lottable03,
 	 lottable4 = LOTATTRIBUTE.lottable04,
 	 lottable5 = LOTATTRIBUTE.lottable05
 FROM LOTATTRIBUTE (nolock), LOTxLOCxID (nolock)
 WHERE #CONSOLIDATED.SKU = LOTxLOCxID.SKU
 AND       #CONSOLIDATED.loc = LOTxLOCxID.loc
 AND       LOTATTRIBUTE.lot = LOTxLOCxID.lot
 -----------------------------------------------------------------------------------
 /* second loop, created for labelprice = 'N' */
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
         DESCR=Space(60),
         UOM1=Space(10),
         UOM3=Space(10),
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
        LOTATTRIBUTE.Lottable05 lottable5
 INTO #CONSOLIDATED1 
 FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK)
 where 1 = 2
 DELETE FROM #SKUGROUP
 DECLARE CUR_1 SCROLL CURSOR FOR
 SELECT 	DISTINCT ORDERDETAIL.OrderKey,
 	ORDERDETAIL.SKU,
              PICKDETAIL.LOC,
 	LOC.LogicalLocation,
 	PICKDETAIL.LOT
 FROM LoadplanDetail (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK), LOC (nolock), ORDERS (nolock), SKUxLOC(NOLOCK)
 WHERE LoadplanDetail.ORDERKEY = ORDERDETAIL.OrderKey
  AND  ORDERS.Orderkey = ORDERDETAIL.Orderkey
  AND  ORDERS.Orderkey = LOADPLANDETAIL.Orderkey
  AND  LoadplanDetail.LoadKey = @a_s_LoadKey
  AND  PICKDETAIL.ORDERKEY        = ORDERDETAIL.ORDERKEY
  AND  PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER
  AND  PICKDETAIL.QTY > 0
  AND  PICKDETAIL.LOC = LOC.Loc
 AND   PICKDETAIL.SKU = SKUxLOC.SKU
 AND   PICKDETAIL.LOC = SKUxLOC.LOC
 AND   PICKDETAIL.Storerkey = SKUxLOC.StorerKey
 AND 	SKUxLOC.LocationType IN ('PICK', 'CASE')
 -- added by jeff, for pricelabel = 'N'
  AND  ( ORDERS.LabelPrice = 'N' OR ORDERS.LabelPrice = '' OR ORDERS.LabelPrice is NULL )
 ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, ORDERDETAIL.SKU, ORDERDETAIL.OrderKey
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
       IF @n_GroupSeq > 8
       BEGIN
          SELECT @n_GroupNo=@n_GroupNo + 1
          SELECT @n_GroupSeq = 1
       END
       INSERT INTO #SKUGroup VALUES (" ",
                 " ",
                   @c_OrderKey,
                   IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1))
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
    AND    LOC = " "
    AND    SKU = " "
    IF @@ROWCOUNT > 0
    BEGIN
       UPDATE #SKUGroup
          SET LOC = @c_LOC,
              SKU = @c_SKU
       WHERE  OrderKey = @c_OrderKey
       AND    LOC = " "   
       AND    SKU = " "
    END
    ELSE
    BEGIN
       SELECT @n_Count = COUNT(*)
       FROM   #SKUGroup
       WHERE  OrderKey = @c_OrderKey
       AND    LOC = @c_Loc
       AND    SKU = @c_SKU
       IF @n_Count = 0
       BEGIN
          SELECT @n_GroupNo = GroupNo,
                 @n_GroupSeq = GroupSeq
          FROM   #SKUGroup
          WHERE  OrderKey = @c_OrderKey
          INSERT INTO #SKUGroup VALUES (@c_LOC,
                   @c_SKU,
                   @c_OrderKey,
                   IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1))
       END
    END
    FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot
 END
 DECLARE CUR_2 SCROLL CURSOR FOR
    SELECT DISTINCT LOC, SKU
    FROM   #SKUGroup
    ORDER BY LOC, SKU
 OPEN CUR_2
 FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
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
       SELECT @c_Route     = ORDERS.Route,
              @c_StorerKey = ORDERS.StorerKey,
              @c_Invoice = ORDERS.ExternOrderKey
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
       SELECT @n_CaseCnt = ISNULL(CaseCnt,0)
       FROM   SKU (NOLOCK),    PACK (NOLOCK)
       WHERE  SKU.SKU = @C_SKU
       AND    PACK.PACKKEY = SKU.PACKKEY
       IF @n_CaseCnt = 0
          SELECT @c_Pack = " " -- No of Item in Carton not available
       ELSE
       BEGIN
          SELECT @c_Pack = CONVERT(char(3), FLOOR(@n_Qty / @n_CaseCnt))
          IF @c_Pack = '0' select @c_Pack = ""
          SELECT @n_CasesQty = FLOOR(@n_Qty / @n_CaseCnt)
          SELECT @n_Qty = @n_Qty % @n_CaseCnt
       END
       SELECT @n_TotQty   = @n_TotQty  + @n_Qty
       SELECT @n_TotCases = @n_TotCases + @n_CasesQty
       IF @n_GroupSeq = 1
       BEGIN
          SELECT @c_Route1 = @c_Route
          SELECT @c_Invoice1 = @c_Invoice
          SELECT @c_StorerKey1 = @c_StorerKey
          SELECT @c_OrderKey1 = @c_OrderKey
          SELECT @n_Qty1      = @n_Qty
          SELECT @c_Pack1     = @c_Pack
          SELECT @n_TotCases = @n_CasesQty
          SELECT @n_TotQty   = @n_Qty
          UPDATE #CONSOLIDATED1
             SET Route1 =IsNULL(@c_Route,"") ,
                 StorerKey1 = @c_StorerKey,
                 OrderKey1 = @c_OrderKey,
                 InvoiceNo1 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 2
       BEGIN
          SELECT @c_Route2 = @c_Route
          SELECT @c_StorerKey2 = @c_StorerKey
          SELECT @c_OrderKey2 = @c_OrderKey
          SELECT @n_Qty2      = @n_Qty
          SELECT @c_Pack2     = @c_Pack
          SELECT @c_Invoice2 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route2 = @c_Route,
                 StorerKey2 = @c_StorerKey,
                 OrderKey2 = @c_OrderKey,
                 InvoiceNo2 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 3
       BEGIN
          SELECT @c_Route3 = @c_Route
          SELECT @c_StorerKey3 = @c_StorerKey
          SELECT @c_OrderKey3 = @c_OrderKey
          SELECT @n_Qty3      = @n_Qty
          SELECT @c_Pack3     = @c_Pack
          SELECT @c_Invoice3 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route3 = @c_Route,
                 StorerKey3 = @c_StorerKey,
                 OrderKey3  = @c_OrderKey,
                 InvoiceNo3 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 4
       BEGIN
          SELECT @c_Route4 = @c_Route
          SELECT @c_StorerKey4 = @c_StorerKey
          SELECT @c_OrderKey4 = @c_OrderKey
          SELECT @n_Qty4      = @n_Qty
          SELECT @c_Pack4     = @c_Pack
          SELECT @c_Invoice4 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route4 = @c_Route,
                 StorerKey4 = @c_StorerKey,
                 OrderKey4 = @c_OrderKey,
                 InvoiceNo4 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 5
       BEGIN
          SELECT @c_Route5 = @c_Route
          SELECT @c_StorerKey5 = @c_StorerKey
          SELECT @c_OrderKey5 = @c_OrderKey
          SELECT @n_Qty5      = @n_Qty
          SELECT @c_Pack5     = @c_Pack
          SELECT @c_Invoice5 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route5 = @c_Route,
                 StorerKey5 = @c_StorerKey,
                 OrderKey5 = @c_OrderKey,
                  InvoiceNo5 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 6
       BEGIN
          SELECT @c_Route6 = @c_Route
          SELECT @c_StorerKey6 = @c_StorerKey
          SELECT @c_OrderKey6 = @c_OrderKey
          SELECT @n_Qty6      = @n_Qty
          SELECT @c_Pack6     = @c_Pack
          SELECT @c_Invoice6 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route6 = @c_Route,
                 StorerKey6 = @c_StorerKey,
                 OrderKey6 = @c_OrderKey,
                 InvoiceNo6 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 7
       BEGIN
          SELECT @c_Route7 = @c_Route
          SELECT @c_StorerKey7 = @c_StorerKey
          SELECT @c_OrderKey7 = @c_OrderKey
          SELECT @n_Qty7      = @n_Qty
          SELECT @c_Pack7     = @c_Pack
          SELECT @c_Invoice7 = @c_Invoice
          UPDATE #CONSOLIDATED1
             SET Route7 = @c_Route,
                 StorerKey7 = @c_StorerKey,
                 OrderKey7 = @c_OrderKey,
                 InvoiceNo7 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       ELSE IF @n_GroupSeq = 8
       BEGIN
          SELECT @c_Route8 = @c_Route
          SELECT @c_StorerKey8 = @c_StorerKey
          SELECT @c_OrderKey8 = @c_OrderKey
          SELECT @n_Qty8      = @n_Qty
          SELECT @c_Pack8     = @c_Pack
          SELECT @c_Invoice8 = @c_Invoice
         UPDATE #CONSOLIDATED1
             SET Route8 = @c_Route,
                 StorerKey8 = @c_StorerKey,
                 OrderKey8 = @c_OrderKey,
                 InvoiceNo8 = @c_Invoice
          WHERE  ConsoGroupNo = @n_GroupNo
       END
       FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
    END
    IF @n_CaseCnt <> 0 
       SELECT @c_TotPack = CONVERT(char(3), @n_TotCases)
    ELSE
       SELECT @c_TotPack = ''
    INSERT INTO #CONSOLIDATED1 VALUES (
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
          ISNULL(@c_Invoice1,""),
          ISNULL(@c_Invoice2,""),
          ISNULL(@c_Invoice3,""),
          ISNULL(@c_Invoice4,""),
          ISNULL(@c_Invoice5,""),
          ISNULL(@c_Invoice6,""),
          ISNULL(@c_Invoice7,""),
          ISNULL(@c_Invoice8,""),
 	 'N',
          @c_lot,
          "",
          "",
          "",
          "",
          ""
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
    SELECT @c_Invoice1=""
    SELECT @c_Invoice2=""
    SELECT @c_Invoice3=""
    SELECT @c_Invoice4=""
    SELECT @c_Invoice5=""
    SELECT @c_Invoice6=""
    SELECT @c_Invoice7=""
    SELECT @c_Invoice8=""
    SELECT @n_TotQty=0, @n_CasesQty=0, @c_TotPack=""
    SELECT @c_lot = ""
    DEALLOCATE CUR_3
    FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
 END
 DEALLOCATE CUR_2
 CLOSE CUR_1
 DEALLOCATE CUR_1
 UPDATE #CONSOLIDATED1
    SET DESCR=SKU.DESCR,
        UOM1=PACK.Packuom1,
        UOM3=Pack.PackUOM3,
        CaseCnt=Pack.CaseCnt
 FROM SKU, PACK
 WHERE #CONSOLIDATED1.SKU = SKU.SKU
 AND   SKU.PACKKEY = PACK.PACKKEY
 UPDATE #CONSOLIDATED1
       SET lot = LOTxLOCxID.lot,
 	 lottable1 = LOTATTRIBUTE.lottable01,
 	 lottable2 = LOTATTRIBUTE.lottable02,
 	 lottable3 = LOTATTRIBUTE.lottable03,
 	 lottable4 = LOTATTRIBUTE.lottable04,
 	 lottable5 = LOTATTRIBUTE.lottable05
 FROM LOTATTRIBUTE (nolock), LOTxLOCxID (nolock)
 WHERE #CONSOLIDATED1.SKU = LOTxLOCxID.SKU
 AND       #CONSOLIDATED1.loc = LOTxLOCxID.loc
 AND       LOTATTRIBUTE.lot = LOTxLOCxID.lot
 -------------------------------------------/* Second loop, for pricelabel = 'N' */
 -----------------------------------------------------------------------------------
 /* Start Modification */
       BEGIN TRAN
       UPDATE PickDetail
       SET PickSlipNo = PICKHEADER.PickHeaderKey,
           Trafficcop = NULL
       FROM   PickDetail ,  LoadPlanDetail, PickHeader 
       WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
       AND    PickDetail.Status < '5'
 --      AND    PICKHeader.OrderKey = Pickdetail.OrderKey
       AND    PickHeader.ExternOrderKey = LoadPlanDetail.LoadKey
       AND    PickHeader.Zone = '4'
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
 /* End */
 /* New section added by Jeff */
 SELECT #consolidated.* INTO #consolidatedY FROM #CONSOLIDATED, LOC
 where #consolidated.loc = LOC.loc
 order by loc.logicallocation, Loc.Loc
 SELECT #consolidated1.* INTO #consolidatedN FROM #Consolidated1, LOC
 WHERE #Consolidated1.loc = LOC.Loc
 ORDER BY Loc.LogicalLocation, Loc.Loc
 select * from #consolidatedY
 UNION
 select * FROM #consolidatedN
 /*
 DROP TABLE #CONSOLIDATED
 DROP TABLE #SKUGroup
 */        
 END /* main procedure */




GO