SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_CNA                                             */
/* Creation Date: 12.Sep.2006                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS for IDSCN CNA               */
/*                                                                      */
/* Usage: Copy from ispPopulateToASN                                    */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 17-Oct-2013  NJOW01  1.0   292260-map Orderdetail.Lottable02 to      */
/*                            Receiptdetail.Userdefine02                */
/* 28-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/* 11-Apr-2019  WLCHOOI	1.2   WMS-8609-Set Receiptdetail.Lottable03 = N */
/*                             When Orderdetail.Userdefine01 <> ECOM    */
/************************************************************************/

CREATE PROC [dbo].[ispPopulateTOASN_CNA] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10)

   DECLARE @c_Lottable01            NVARCHAR(18),
           @c_Lottable02            NVARCHAR(18),
           @c_Lottable03            NVARCHAR(18),
           @d_Lottable04            DATETIME,
           @d_Lottable05            DATETIME,
           @c_Lottable06            NVARCHAR(30),
           @c_Lottable07            NVARCHAR(30),
           @c_Lottable08            NVARCHAR(30),
           @c_Lottable09            NVARCHAR(30),
           @c_Lottable10            NVARCHAR(30),
           @c_Lottable11            NVARCHAR(30),
           @c_Lottable12            NVARCHAR(30),
           @d_Lottable13            DATETIME,
           @d_Lottable14            DATETIME,
           @d_Lottable15            DATETIME,
           @n_ShippedQty            int

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_ConsigneeKey          NVARCHAR(15),
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @n_RemainExpectedQty     int,
           @c_loclast               NVARCHAR(30),
           @c_TOLOC                 NVARCHAR(30),
           @c_userdefine08          NVARCHAR(30) ,
           @c_userdefine07          NVARCHAR(30),
           @c_Userdefine01          NVARCHAR(30),
           @c_warehousereference    NVARCHAR(10)
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @c_salesofftake          NVARCHAR(1) -- Add by June 27.Mar.02

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   -- insert into Receipt Header
   
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN         
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_ExternOrderLine = ORDERDETAIL.ExternLineNo,
             @c_facility = ORDERS.Facility     
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey  
    
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_loclast = Userdefine01,
               @c_userdefine08 = Userdefine08,
               @c_userdefine07 = userdefine07
         FROM FACILITY (NOLOCK)
         WHERE Facility = @c_Facility
      END
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         IF dbo.fnc_RTRIM(@c_StorerKey) IS NOT NULL
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
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, appointment_no, DOCTYPE)
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, 'TF', @c_userdefine08, @c_facility, 'A')
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
            END
         END    
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
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
                  @c_ExternOrderLine = ORDERDETAIL.ExternLineNo,
                  @c_Userdefine01 = ORDERDETAIL.Userdefine01
             FROM ORDERDETAIL (NOLOCK)
                  JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
                  JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
                  ( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )

            ORDER by ORDERDETAIL.ExternLineNo
            IF @@ROWCOUNT = 0
               BREAK
   
            SET ROWCOUNT 0      
            IF dbo.fnc_RTRIM(@c_OrderKey) IS NOT NULL AND 
               dbo.fnc_RTRIM(@c_OrderLine) IS NOT NULL 
            BEGIN
                 DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                     SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                        LOTATTRIBUTE.Lottable01,
                        LOTATTRIBUTE.Lottable02, --NJOW01
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
                        LOTATTRIBUTE.Lottable15,
                        PICKDETAIL.LOC
                     FROM PICKDETAIL (NOLOCK) 
                     JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                     WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                            PICKDETAIL.OrderLineNumber = @c_OrderLine)
                     GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                              LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                              LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                              LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                              PICKDETAIL.LOC
         
               OPEN PICK_CUR               
               FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, 
                                          @c_TOLOC
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
   
                  -- select @n_RemainExpectedQty '@n_RemainExpectedQty', @n_QtyReceived '@n_QtyReceived',
                  --       @c_ExternPOKey '@c_ExternPOKey' 
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptKey, 
                                             ExternLineNo,        StorerKey,           SKU, 
                                             QtyExpected,         QtyReceived,
                                             UOM,                 PackKey,             ToLoc,
                                             Lottable01,          Lottable02,          Lottable03,       
                                             Lottable04,          Lottable05,       
                                             Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                             Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                             BeforeReceivedQty,   Userdefine02)
                  VALUES                    (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_OrderLine,        @c_StorerKey,        @c_SKU,
                                             ISNULL(@n_QtyReceived,0),  0,               -- ONG01 
                                             @c_UOM,              @c_Packkey,          @c_TOLOC,
                                             @c_Lottable01,       @c_Userdefine01,     CASE WHEN LTRIM(RTRIM(@c_Userdefine01)) <> 'ECOM' THEN 'N' ELSE '' END,  --WL01
                                             @d_Lottable04,       @d_Lottable05,  
                                             @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                             @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                             ISNULL(@n_QtyReceived,0), @c_Lottable02)   -- ONG01                                             
                  SELECT @n_LineNo = @n_LineNo + 1
   
                  FETCH NEXT FROM PICK_CUR
                        INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @d_Lottable04, @d_Lottable05, 
                                             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                             @c_TOLOC
               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
            END -- Orderkey & OrderLine is Not Null
         END -- End
      END -- if continue = 1 or 2 
      SET ROWCOUNT 0
   END -- if continue = 1 or 2 001

GO