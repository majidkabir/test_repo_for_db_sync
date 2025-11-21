SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspConsolidatedPickList02                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2014-01-13   TLTING        Commit Transaction                        */
/************************************************************************/

CREATE PROC [dbo].[nspConsolidatedPickList02] (
@a_s_LoadKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
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
   DECLARE @n_starttcnt INT
   SELECT  @n_starttcnt = @@TRANCOUNT
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN  
   /* Start Modification */
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
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

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   BEGIN TRAN

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
   END -- @c_firsttime = "Y"
   ELSE
   BEGIN
      SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
      WHERE ExternOrderKey = @a_s_LoadKey
      AND   Zone = '7'
   END
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END   
      /* End */
      /*Create Temp Result table */
      CREATE TABLE #CONSOLIDATED
      (  ConsoGroupNo int DEFAULT 0,
      LoadKey NVARCHAR(10) NULL,
      Loc NVARCHAR(10) NULL,
      SKU NVARCHAR(20) NULL,
      StorerKey1 NVARCHAR(15),
      OrderKey1  NVARCHAR(10),
      Route1     NVARCHAR(10),
      StorerKey2 NVARCHAR(15),
      OrderKey2  NVARCHAR(10),
      Route2     NVARCHAR(10),
      StorerKey3 NVARCHAR(15),
      OrderKey3  NVARCHAR(10),
      Route3     NVARCHAR(10),
      StorerKey4 NVARCHAR(15),
      OrderKey4  NVARCHAR(10),
      Route4     NVARCHAR(10),
      StorerKey5 NVARCHAR(15),
      OrderKey5  NVARCHAR(10),
      Route5     NVARCHAR(10),
      StorerKey6 NVARCHAR(15),
      OrderKey6  NVARCHAR(10),
      Route6     NVARCHAR(10),
      StorerKey7 NVARCHAR(15),
      OrderKey7  NVARCHAR(10),
      Route7     NVARCHAR(10),
      StorerKey8 NVARCHAR(15),
      OrderKey8  NVARCHAR(10),
      Route8     NVARCHAR(10),
      Qty1 int DEFAULT 0,
      Qty2 int DEFAULT 0,
      Qty3 int DEFAULT 0,
      Qty4 int DEFAULT 0,
      Qty5 int DEFAULT 0,
      Qty6 int DEFAULT 0,
      Qty7 int DEFAULT 0,
      Qty8 int DEFAULT 0,
      Pack1 NVARCHAR(10) DEFAULT Space(10),
      Pack2 NVARCHAR(10) DEFAULT Space(10),
      Pack3 NVARCHAR(10) DEFAULT Space(10),
      Pack4 NVARCHAR(10) DEFAULT Space(10),
      Pack5 NVARCHAR(10) DEFAULT Space(10),
      Pack6 NVARCHAR(10) DEFAULT Space(10),
      Pack7 NVARCHAR(10) DEFAULT Space(10),
      Pack8 NVARCHAR(10) DEFAULT Space(10),
      TotQty int DEFAULT 0,
      TotCases int DEFAULT 0,
      TotPack NVARCHAR(10) DEFAULT Space(10),
      DESCR NVARCHAR(60) DEFAULT Space(60), -- jacob 14 Dec 2001. length extended from 30 to 60 characters
      UOM1 NVARCHAR(10) DEFAULT Space(10),
      UOM3 NVARCHAR(10) DEFAULT Space(10),
      CaseCnt int DEFAULT 0,
      InvoiceNo1 NVARCHAR(30) NULL,
      InvoiceNo2 NVARCHAR(30) NULL,
      InvoiceNo3 NVARCHAR(30) NULL,
      InvoiceNo4 NVARCHAR(30) NULL,
      InvoiceNo5 NVARCHAR(30) NULL,
      InvoiceNo6 NVARCHAR(30) NULL,
      InvoiceNo7 NVARCHAR(30) NULL,
      InvoiceNo8 NVARCHAR(30) NULL,
      PickSlipNo NVARCHAR(18) DEFAULT '',
      Lottable01 NVARCHAR(18) DEFAULT '',
      Lottable02 NVARCHAR(18) DEFAULT '',
      Lottable03 NVARCHAR(18) DEFAULT '',
      Lottable04 datetime NULL)
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
      @c_Descr    NVARCHAR(60), -- YokeBeen (14/12/2001) Changed char from 30 to 60.
      @c_Packkey  NVARCHAR(10)
      DECLARE @c_Invoice1 NVARCHAR(18),
      @c_Invoice2 NVARCHAR(18),
      @c_Invoice3 NVARCHAR(18),
      @c_Invoice4 NVARCHAR(18),
      @c_Invoice5 NVARCHAR(18),
      @c_Invoice6 NVARCHAR(18),
      @c_Invoice7 NVARCHAR(18),
      @c_Invoice8 NVARCHAR(18)
      DECLARE @c_PickSlipNo NVARCHAR(18),
      @c_lottable01 NVARCHAR(18),
      @c_lottable02 NVARCHAR(18),
      @c_lottable03 NVARCHAR(18),
      @d_lottable04 datetime
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
      PICKDETAIL.Lot
      FROM LoadplanDetail (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK), LOC (nolock)
      WHERE LoadplanDetail.ORDERKEY = ORDERDETAIL.OrderKey
      AND  LoadplanDetail.Loadkey = ORDERDETAIL.LoadKey ---added by vicky Date:07 Dec 2001
      AND  LoadplanDetail.LoadKey = @a_s_LoadKey
      AND  PICKDETAIL.ORDERKEY        = ORDERDETAIL.ORDERKEY
      AND  PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER
      AND  PICKDETAIL.QTY > 0
      AND  PICKDETAIL.LOC = LOC.Loc
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
            IF @n_GroupSeq > 8
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
      /*
      print 'first SKU grouping...'
      select * from #skugroup
      */
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
      /*
      print '2nd SKU grouping...'
      select * from #skugroup
      */
      DECLARE CUR_2 SCROLL CURSOR FOR
      SELECT DISTINCT LOC, SKU, LOT
      FROM   #SKUGroup
      ORDER BY LOC, SKU
      OPEN CUR_2
      FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU, @c_lot
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DECLARE CUR_3 CURSOR FOR
         SELECT ORDERKEY, GroupNo, GroupSeq, Lot
         FROM   #SKUGroup
         WHERE  LOC = @c_LOC
         AND    Lot = @c_lot
         AND    SKU = @c_SKU
         OPEN CUR_3
         FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq, @c_lot
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_Route     = ORDERS.Route,
            @c_StorerKey = ORDERS.StorerKey,
            @c_Invoice   = ORDERS.InvoiceNo
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
            AND    SKU.Storerkey = @c_Storerkey
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
            SELECT @c_Lottable01 = Lottable01,
            @c_Lottable02 = Lottable02,
            @c_Lottable03 = Lottable03,
            @d_Lottable04 = Lottable04
            FROM   LOTATTRIBUTE (NOLOCK)
            WHERE  LOT = @c_LOT
            AND    LOTATTRIBUTE.Storerkey = @c_Storerkey -- added by vicky Date:07 Dec 2001
            AND    LOTATTRIBUTE.Sku = @c_sku --added by vicky Date:07 Dec 2001
            FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq, @c_lot
         END
         IF @n_CaseCnt <> 0
         SELECT @c_TotPack = CONVERT(char(10), @n_TotCases)
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
         @c_Invoice1,
         @c_Invoice2,
         @c_Invoice3,
         @c_Invoice4,
         @c_Invoice5,
         @c_Invoice6,
         @c_Invoice7,
         @c_Invoice8,
         @c_PickHeaderKey,
         @c_lottable01,
         @c_lottable02,
         @c_lottable03,
         @d_lottable04
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
         /**
         SELECT @c_Invoice1=""
         SELECT @c_Invoice2=""
         SELECT @c_Invoice3=""
         SELECT @c_Invoice4=""
         SELECT @c_Invoice5=""
         SELECT @c_Invoice6=""
         SELECT @c_Invoice7=""
         SELECT @c_Invoice8=""
         **/
         SELECT @c_lottable01=""
         SELECT @c_lottable02=""
         SELECT @c_lottable03=""
         SELECT @d_lottable04=NULL
         SELECT @n_TotQty=0, @n_CasesQty=0, @c_TotPack=""
         DEALLOCATE CUR_3
         FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU, @c_lot
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
      AND   #CONSOLIDATED.Storerkey1 = SKU.Storerkey -- Add by June 07.June.04 SOS23922

      SELECT #consolidated.* FROM #CONSOLIDATED, LOC (NOLOCK)
      where #consolidated.loc = LOC.loc
      order by loc.logicallocation
      DROP TABLE #CONSOLIDATED
      DROP TABLE #SKUGroup
      WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN
         BEGIN TRAN
      END         
   END /* main procedure */



GO