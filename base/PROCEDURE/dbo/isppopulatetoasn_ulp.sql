SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_ULP                                             */
/* Creation Date: 22 Oct 2010                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS (SOS#191963)                */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 27-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_ULP] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
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
            @c_ExternOrderLine   NVARCHAR(10),
            @c_RecType           NVARCHAR(10)


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
            @n_ShippedQty        int

   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @c_ConsigneeKey      NVARCHAR(15),
            @n_ExpectedQty       int,
            @n_QtyReceived       int,
            @c_loclast           NVARCHAR(30),
            @c_warehousereference NVARCHAR(10)
    
   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @n_starttcnt         int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT
   SET @c_RecType  = 'TR'
   -- insert into Receipt Header
   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN         
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.Orderkey,
             @c_WarehouseReference = ORDERS.ExternOrderkey,
             @c_facility = ORDERS.Facility     
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
   END 
    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SELECT @c_loclast = Userdefine04
     FROM FACILITY (NOLOCK)
     WHERE Facility = @c_Facility
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
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
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, DOCTYPE)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_rectype, @c_facility, 'A')
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTOASN_ULP)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTOASN_ULP)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
               ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
         ORDER by ORDERDETAIL.OrderLineNumber
         
         IF @@ROWCOUNT = 0
            BREAK
   
         SET ROWCOUNT 0      
         IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND 
            dbo.fnc_RTrim(@c_OrderLine) IS NOT NULL 
         BEGIN
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
   
            INSERT INTO RECEIPTDETAIL (ReceiptKey,    ReceiptLineNumber,   ExternReceiptKey, 
                                       ExternLineNo,  StorerKey,           SKU, 
                                       QtyExpected,   QtyReceived,         BeforeReceivedQty,
                                       UOM,           PackKey,             ToLoc,   
                                       Lottable01,    Lottable02,          Lottable03,    Lottable04,    Lottable05,
                                       Lottable06,    Lottable07,          Lottable08,    Lottable09,    Lottable10,
                                       Lottable11,    Lottable12,          Lottable13,    Lottable14,    Lottable15)
                                             
                           VALUES     (@c_NewReceiptKey, @c_ReceiptLine,   @c_ExternReceiptKey,
                                       @c_OrderLine,     @c_StorerKey,     @c_SKU,
                                       ISNULL(@n_QtyReceived,0),   0,      ISNULL(@n_QtyReceived,0),
                                       @c_UOM,           @c_Packkey,       @c_loclast, 
                                       @c_Lottable01,    @c_Lottable02,    @c_Lottable03,    @d_Lottable04,    @d_Lottable05,    
                                       @c_Lottable06,    @c_Lottable07,    @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                       @c_Lottable11,    @c_Lottable12,    @d_Lottable13,    @d_Lottable14,    @d_Lottable15)   
                                             
               SELECT @n_LineNo = @n_LineNo + 1
   
               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

            END -- WHILE @@FETCH_STATUS <> -1
            DEALLOCATE PICK_CUR

         END
      END
      SET ROWCOUNT 0
   END 
         
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
   
      SELECT @b_success = 0
   
      IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
      BEGIN   
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_ULP'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
     -- WHILE @@TRANCOUNT >= @n_starttcnt
     -- BEGIN
     --    COMMIT TRAN
     -- END
      RETURN
   END      

GO