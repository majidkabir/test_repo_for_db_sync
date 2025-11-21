SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPopulateTSO2ASN                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 27-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTSO2ASN] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_ExternReceiptKey  NVARCHAR(20),
            @c_SKU               NVARCHAR(20),
            @c_PackKey           NVARCHAR(10),
            @c_UOM               NVARCHAR(5),
            @c_SKUDescr          NVARCHAR(60),
            @c_StorerKey         NVARCHAR(15),
            @c_OrderLine         NVARCHAR(5),
            @c_Facility          NVARCHAR(5),
            @c_ExternOrderLine   NVARCHAR(10)

   DECLARE  @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        DATETIME,
            @d_Lottable05        DATETIME,
            @c_Lottable06        NVARCHAR(30), 
            @c_Lottable07        NVARCHAR(30), 
            @c_Lottable08        NVARCHAR(30), 
            @c_Lottable09        NVARCHAR(30), 
            @c_Lottable10        NVARCHAR(30), 
            @c_Lottable11        NVARCHAR(30), 
            @c_Lottable12        NVARCHAR(30), 
            @d_Lottable13        DATETIME,     
            @d_Lottable14        DATETIME,     
            @d_Lottable15        DATETIME,     
            @n_ShippedQty        int,
            @c_BuyerPO           NVARCHAR(20)

   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @c_ConsigneeKey      NVARCHAR(15),
            @c_CarrierAgent      NVARCHAR(15),
            @c_ExternRouteCode   NVARCHAR(20),
            @c_ToLoc             NVARCHAR(10),
            @c_LoadKey           NVARCHAR(10),
            @n_ExpectedQty       int,
            @n_QtyReceived       int,
            @n_RemainExpectedQty int

   -- from PO
   DECLARE  @c_SellerName        NVARCHAR(45),
            @c_SellerAddr1       NVARCHAR(45),
            @c_SellerAddr2       NVARCHAR(45),
            @c_SellerAddr3       NVARCHAR(45),
            @c_SellerAddr4       NVARCHAR(45),
            @c_POKey             NVARCHAR(10),
            @c_POLine            NVARCHAR(5),
            @c_ExternPOKey       NVARCHAR(20),
            @c_ExternPOLine      NVARCHAR(10)

   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @c_salesofftake      NVARCHAR(1) -- Add by June 27.Mar.02

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   -- insert into Receipt Header

   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_StorerKey = PO.STORERKEY,
             @c_SellerName = PO.SellerName,
             @c_SellerAddr1 = PO.SellerAddress1,
             @c_SellerAddr2 = PO.SellerAddress2,
             @c_CarrierAgent = ISNULL(MBOL.CarrierAgent, ''),
             @c_POKey  = PO.POKey,
             @c_ExternReceiptKey = ORDERS.ExternPOKey,
             @c_LoadKey = ORDERS.LoadKey,
             @c_ExternRouteCode = CASE WHEN ORDERS.UserDefine08 = 'Y' OR ORDERS.UserDefine08 = 'N'
                                            THEN '1' -- Y/N = Type 1
                                       ELSE ORDERS.UserDefine08
                                  END,
             @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_ExternPOKey = ORDERS.ExternPOKey 
      FROM   ORDERS (NOLOCK)
       JOIN  PO (NOLOCK) ON (PO.ExternPOKey = ORDERS.ExternPOKey)
       LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      WHERE ORDERS.OrderKey = @c_OrderKey
        AND   ORDERS.ExternPOkey <> '' -- SOS38531
   
   -- ExternRouteCode
   -- Y/N = Type 1, Which gone thru full Outbound process, Allocate,pick, ship (Transfer from inter to External warehouse)
   -- Type 2, Allocate and Ship (Transfer from External Warehouse to Internal Warehouse)
   -- Type 3, Upload into ASN instead of Order
   -- Type 4, Only Preallocation

   -- Begin of Modification on 15-Mar-2002 
   -- Cannot use ExternRouteCode, because it's possible to transfer from Main to Consignment (Route Code = 1) 
   -- and Also Consignment warehouse to Main warehouse (RouteCode = 2)
   -- Every Facility in OW contain a Consignee Key, even Main Warehouse
   -- Use Facility User Define Field 03 as the Consignee Key
   -- Use Facility User Define Field 04 as Default Receiving DOCK, Cannot Hardcode to STAGE, cause there
   -- Might have more then 1 Main Warehouse
   -- Comment By SHONG
--       IF @c_ExternRouteCode = '2'
--       BEGIN
--          SELECT @c_ToLoc = @c_ConsigneeKey
--       END
--       ELSE
--       BEGIN
--          SELECT @c_ToLoc = 'STAGE'
--      END

      -- Added By Shong 12.Apr.2002
      IF EXISTS( SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_ConsigneeKey )
      BEGIN
         SELECT @c_ToLoc = sValue
         FROM STORERCONFIG (NOLOCK) 
         WHERE StorerKey = @c_ConsigneeKey
         AND   ConfigKey = 'RCPTLOC'

         IF dbo.fnc_RTrim(@c_ToLoc) IS NULL
            SELECT @c_ToLoc = 'STAGE'
      END
      ELSE
      BEGIN
         -- Only Main Warehouse contain Consignee Key
--          IF EXISTS(SELECT 1 FROM Facility (NOLOCK) WHERE UserDefine03 = @c_ConsigneeKey)
--          BEGIN
--             SELECT @c_ToLoc = UserDefine04
--             FROM   Facility (NOLOCK)
--             WHERE  UserDefine03 = @c_ConsigneeKey
--    
--             IF dbo.fnc_RTrim(@c_ToLoc) IS NULL
--                SELECT @c_ToLoc = 'STAGE'
--          END
--          BEGIN
            SELECT @c_salesofftake = 'Y'  -- Add by June 27.Mar.02
            SELECT @c_ToLoc = @c_ConsigneeKey
--          END
         -- End of Modification on 15-Mar-2002
      END

      SELECT @c_Facility = LOC.Facility
      FROM   LOC (NOLOCK)
      WHERE  LOC = @c_ToLoc
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      IF dbo.fnc_RTrim(@c_Storerkey) IS NOT NULL
      BEGIN
         -- get next receipt key
         SELECT @b_success = 0
         EXECUTE   nspg_getkey
                  "RECEIPT"
                  , 10
                  , @c_NewReceiptKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            -- Modified by June 13.Mar.02, default facility code base on TOLOC
            -- Modified by Shong, Don't insert Facility Code. They may transfer to other facility
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, RecType, POKey, CarrierName, 
                                 CarrierAddress1, CarrierAddress2, LoadKey, Facility)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, 'NORMAL', @c_POkey, @c_SellerName, 
                    @c_SellerAddr1, @c_SellerAddr2, @c_LoadKey, @c_Facility)
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END -- if continue = 1 or 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
      SELECT @c_ExternOrderLine = SPACE(5)

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1
      
         SELECT @c_SKU    = ORDERDETAIL.Sku,   
               @c_PackKey = ORDERDETAIL.PackKey,   
               @c_UOM     = ORDERDETAIL.UOM,   
               @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
               @c_SKUDescr  = SKU.DESCR,   
               @c_OrderLine = ORDERDETAIL.OrderLineNumber,
               @c_ExternOrderLine = ORDERDETAIL.ExternLineNo
         FROM ORDERDETAIL (NOLOCK)
               JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
               JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
--             ( ORDERDETAIL.OrderLineNumber > @c_OrderLine)
               ( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )
--         ORDER by ORDERDETAIL.OrderLineNumber Remark by June 10.May.02
           ORDER by ORDERDETAIL.ExternLineNo
         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0      
         IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND 
            dbo.fnc_RTrim(@c_OrderLine) IS NOT NULL AND 
            dbo.fnc_RTrim(@c_ExternPOKey) IS NOT NULL
         BEGIN
            -- Start - Add by June 8.May.02
            SELECT @c_ExternPOLine = MIN(ExternLineNo)
            FROM   PODETAIL (NOLOCK)
            WHERE  PODETAIL.ExternPOKey = @c_ExternPOKey 
            AND    PODETAIL.SKU = @c_SKU
            AND    PODETAIL.ExternLineNO NOT IN  (SELECT ExternLineNo FROM RECEIPTDETAIL (NOLOCK) 
                                         WHERE Externreceiptkey = @c_ExternPOKey AND SKU = @c_SKU)
            ORDER BY MIN(PODETAIL.ExternLineNo)
            IF @c_ExternPoLine IS NULL SELECT @c_ExternPOLine = SPACE(10)
            -- End - Add by June 8.May.02

            SELECT @n_ExpectedQty = ISNULL(PODETAIL.QtyOrdered, 0),
                   @c_POLine = PODETAIL.POLineNumber,
                   @c_ExternPOLine = ISNULL(PODETAIL.ExternLineNo, '') -- Add by June 8.May.02
            FROM   PO (NOLOCK)
            JOIN   PODETAIL (NOLOCK) ON (PO.POKey = PODETAIL.POKey)
            WHERE  PO.ExternPOKey = @c_ExternPOKey
--            AND  PODETAIL.ExternLineNo = @c_ExternOrderLine -- Remark by June 8.May.02
              AND  PODETAIL.ExternLineNo = @c_ExternPOLine
              AND  PODETAIL.SKU = @c_SKU -- Add by June 8.May.02
            ORDER BY PODETAIL.ExternLineNo -- Add by June 8.May.02
            
            IF @c_ExternPOLine <> '' 
            BEGIN
               SELECT @n_RemainExpectedQty = @n_ExpectedQty
   
               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                     LOTATTRIBUTE.Lottable01,
                     LOTATTRIBUTE.Lottable02,
                     LOTATTRIBUTE.Lottable03,
                     LOTATTRIBUTE.Lottable04,
                     LOTATTRIBUTE.Lottable05,
                     LOTATTRIBUTE.Lottable06,
                     LOTATTRIBUTE.Lottable07,
                     LOTATTRIBUTE.Lottable08,
                     LOTATTRIBUTE.Lottable09,
                     LOTATTRIBUTE.Lottable10,
                     LOTATTRIBUTE.Lottable11,
                     LOTATTRIBUTE.Lottable12,
                     LOTATTRIBUTE.Lottable13,
                     LOTATTRIBUTE.Lottable14,
                     LOTATTRIBUTE.Lottable15
               FROM PICKDETAIL (NOLOCK) 
               JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
               WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                        PICKDETAIL.OrderLineNumber = @c_OrderLine)
               GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                  LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                  LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10, 
                  LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15
     
               OPEN PICK_CUR
               
               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)
   
                  -- select @n_RemainExpectedQty '@n_RemainExpectedQty', @n_QtyReceived '@n_QtyReceived',
                  --       @c_ExternPOKey '@c_ExternPOKey' 
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  IF @n_RemainExpectedQty > @n_QtyReceived AND @n_QtyReceived > 0
                  BEGIN
                     SELECT @n_ExpectedQty = @n_QtyReceived
                  END
                  ELSE
                  BEGIN
                     SELECT @n_ExpectedQty = @n_RemainExpectedQty
                  END
                  
   --             select @c_NewReceiptKey, @c_ReceiptLine,   @c_ExternReceiptKey,
   --                   @c_ExternOrderLine,  @c_StorerKey,  @c_SKU,
   --                   @c_POKey,         @n_ExpectedQty,   @n_QtyReceived,
   --                   @c_UOM,           @c_Packkey,       @c_ToLoc,
   --                   @c_Lottable01,    @c_Lottable02,    @c_Lottable03, @d_Lottable04, @d_Lottable05, 
   --                   @c_Lottable06,    @c_Lottable07,    @c_Lottable08, @c_Lottable09, @c_Lottable10,
   --                   @c_Lottable11,    @c_Lottable12,    @d_Lottable13, @d_Lottable14, @d_Lottable15,
   --                   @n_QtyReceived,@c_POLine
   
                  SELECT @n_RemainExpectedQty = @n_RemainExpectedQty - @n_ExpectedQty
   
                  -- Start - Add by June 27.Mar.02
                  IF @c_salesofftake = 'Y'
                  BEGIN
                     SELECT @c_Lottable03 = @c_ConsigneeKey
                  END
                  -- End - Add by June 27.Mar.02
                     
                  -- Change by June 8.May.02 -> Change ExternLineNo = ExternPoLine instead of ExternOrderLine
   
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptKey, 
                                             ExternLineNo,        StorerKey,           SKU, 
                                             POKey,               QtyExpected,         QtyReceived,
                                             UOM,                 PackKey,             ToLoc,
                                             Lottable01,          Lottable02,          Lottable03,    Lottable04,    Lottable05,           
                                             Lottable06,          Lottable07,          Lottable08,    Lottable09,    Lottable10, 
                                             Lottable11,          Lottable12,          Lottable13,    Lottable14,    Lottable15,
                                             BeforeReceivedQty,   POLineNumber)
                              VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_ExternPOLine,     @c_StorerKey,        @c_SKU,
                                             @c_POKey,            ISNULL(@n_ExpectedQty,0),   0,
                                             @c_UOM,              @c_Packkey,          @c_ToLoc,
                                             @c_Lottable01,       @c_Lottable02,       @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                             @c_Lottable06,       @c_Lottable07,       @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11,       @c_Lottable12,       @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                             @n_QtyReceived,      @c_POLine)  
   
                  SELECT @n_LineNo = @n_LineNo + 1
   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
            END -- @c_ExternPOLine <> '' 
         END
      END -- WHILE
      SET ROWCOUNT 0
   END -- if continue = 1 or 2


GO