SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_MultiBOM                                        */
/* Creation Date: 29 Dec 2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Auto Create ASN for Orders  SOS#198615                      */
/*                                                                      */
/* Input Parameters: Orderkey                                           */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 27-May-2014  TKLIM     1.1  Added Lottables 06-15                    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_MultiBOM] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey   NVARCHAR(20),
           @c_SKU                NVARCHAR(20),
           @c_PackKey            NVARCHAR(10),
           @c_UOM                NVARCHAR(5),
           @c_StorerKey          NVARCHAR(15),
           @c_OrderLine          NVARCHAR(5),
           @c_Facility           NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
           @c_id                 NVARCHAR(18),
           @c_ToLoc              NVARCHAR(10),
           @c_Lot                NVARCHAR(10)

   DECLARE @c_Lottable01         NVARCHAR(18),
           @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18),
           @d_Lottable04         DATETIME,
           @d_Lottable05         DATETIME,
           @c_Lottable06         NVARCHAR(30),
           @c_Lottable07         NVARCHAR(30),
           @c_Lottable08         NVARCHAR(30),
           @c_Lottable09         NVARCHAR(30),
           @c_Lottable10         NVARCHAR(30),
           @c_Lottable11         NVARCHAR(30),
           @c_Lottable12         NVARCHAR(30),
           @d_Lottable13         DATETIME,
           @d_Lottable14         DATETIME,
           @d_Lottable15         DATETIME,
           @n_ShippedQty         int

   DECLARE @c_NewReceiptKey      NVARCHAR(10),
           @c_ReceiptLine        NVARCHAR(5),
           @n_LineNo             int,
           @n_ExpectedQty        int,
           @c_warehousereference NVARCHAR(18)

   DECLARE @n_starttcnt          int
    
   DECLARE @n_continue           int,
           @b_success            int,
           @n_err                int,
           @c_errmsg             NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT 
   
   --BEGIN TRAN   

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  

      SELECT @c_id = '', 
             @c_lot = '',
             @c_toloc = ''
             
      SELECT @c_ExternReceiptKey   = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_Facility = ORDERS.Facility,
             @c_Storerkey = ORDERS.Storerkey
      FROM   ORDERS WITH (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey
      
      /*IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_Storerkey )
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63500   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Storer Key: ' + RTRIM(ISNULL(@c_Storerkey,'')) +
                       ' (ispPopulateTOASN_MultiBOM)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END*/

      /*IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE ExternReceiptkey = @c_ExternReceiptkey AND Storerkey = @c_Storerkey)
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63501   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ASN ExternReceiptkey Already Exist In System: ' + RTRIM(ISNULL(@c_ExternReceiptkey,'')) +
                       ' (ispPopulateTOASN_MultiBOM)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END*/

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN             
         IF ISNULL(RTRIM(@c_StorerKey),'') <> '' 
         BEGIN
            -- get next receipt key
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
                     'RECEIPT'
                     , 10
                     , @c_NewReceiptKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
            
            IF @b_success = 1
            BEGIN
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, WarehouseReference, StorerKey, RecType, Facility, DocType, RoutingTool)                                    
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_StorerKey, 'KIT', @c_Facility, 'A', 'Y')
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err) 
               SET @n_err = 63502   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_MultiBOM)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63503   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_MultiBOM)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         END
      END -- if continue = 1 or 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_toloc = Userdefine04
         FROM FACILITY (NOLOCK)
         WHERE Facility = @c_Facility
        
         IF ISNULL(@c_toloc,'') = ''
            SET @c_toloc = 'QC'        
      END
   
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
         SELECT @c_ExternOrderLine = SPACE(5)
         
         WHILE 1=1
         BEGIN
            SET ROWCOUNT 1
         
            SELECT @c_SKU       = ORDERDETAIL.AltSku,   
                   @n_ShippedQty = ORDERDETAIL.QtyToProcess,
                   @c_OrderLine  = MIN(ORDERDETAIL.OrderLineNumber),
                   @c_ExternOrderLine = MIN(ISNULL(ORDERDETAIL.ExternLineNo,'')),
                   @c_lottable01 = ORDERDETAIL.Lottable01, 
                   @c_lottable02 = ORDERDETAIL.Lottable02, 
                   @c_lottable03 = ORDERDETAIL.Lottable03, 
                   @d_lottable04 = ORDERDETAIL.Lottable04,
                   @c_Lottable06 = ORDERDETAIL.Lottable06,
                   @c_Lottable07 = ORDERDETAIL.Lottable07,
                   @c_Lottable08 = ORDERDETAIL.Lottable08,
                   @c_Lottable09 = ORDERDETAIL.Lottable09,
                   @c_Lottable10 = ORDERDETAIL.Lottable10,
                   @c_Lottable11 = ORDERDETAIL.Lottable11,
                   @c_Lottable12 = ORDERDETAIL.Lottable12,
                   @d_Lottable13 = ORDERDETAIL.Lottable13,
                   @d_Lottable14 = ORDERDETAIL.Lottable14,
                   @d_Lottable15 = ORDERDETAIL.Lottable15
            FROM ORDERDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
            JOIN SKU WITH (NOLOCK) ON (SKU.Storerkey = ORDERDETAIL.Storerkey
                                         AND SKU.Sku = ORDERDETAIL.Sku)
            WHERE ( ORDERDETAIL.QtyToProcess > 0 ) AND  
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND
                  ( SKU.PrePackIndicator = 'Y')
            GROUP BY ORDERDETAIL.AltSku, ORDERDETAIL.QtyToProcess,
                     ORDERDETAIL.Lottable01, ORDERDETAIL.Lottable02, ORDERDETAIL.Lottable03, ORDERDETAIL.Lottable04,
                     ORDERDETAIL.Lottable06, ORDERDETAIL.Lottable07, ORDERDETAIL.Lottable08, ORDERDETAIL.Lottable09, ORDERDETAIL.Lottable10,
                     ORDERDETAIL.Lottable11, ORDERDETAIL.Lottable12, ORDERDETAIL.Lottable13, ORDERDETAIL.Lottable14, ORDERDETAIL.Lottable15
            HAVING MIN(ORDERDETAIL.OrderLineNumber) > @c_OrderLine
            ORDER BY MIN(ORDERDETAIL.OrderLineNumber)

            IF @@ROWCOUNT = 0
               BREAK
   
            SET ROWCOUNT 0 
   
            IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_storerkey AND Sku = @c_sku ) 
            BEGIN 
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err)
               SET @n_err = 63504   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Sku: '+ RTRIM(ISNULL(@c_Sku,'')) + 
                             ' for Storerkey ' + RTRIM(ISNULL(@c_Storerkey,'')) + 
                             '( ispPopulateTOASN_MultiBOM)' + ' ( ' + ' SQLSvr MESSAGE=' + 
                             RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
            ELSE
            BEGIN
               SELECT @c_PackKey = SKU.PackKey,
                      @c_UOM = PACK.PACKUOM3
               FROM SKU (NOLOCK)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               WHERE SKU.Storerkey = @c_storerkey
               AND SKU.Sku = @c_sku                               
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN                
               SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
         
               SELECT @n_ExpectedQty = @n_ShippedQty 

               INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,    
                                          ExternLineNo,        StorerKey,           SKU, 
                                          QtyExpected,         QtyReceived,         ExternPoKey, 
                                          UOM,                 PackKey,             ToLoc,
                                          Lottable01,          Lottable02,          Lottable03,          Lottable04,                   
                                          Lottable06,          Lottable07,          Lottable08,          Lottable09,       Lottable10,
                                          Lottable11,          Lottable12,          Lottable13,          Lottable14,       Lottable15,
                                          ToID,                ToLot,               BeforeReceivedQty,   FinalizeFlag)                                                   
                           VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptkey,   
                                          @c_OrderLine,        @c_StorerKey,        @c_SKU,
                                          @n_ExpectedQty,      0,                   @c_WarehouseReference,   
                                          @c_UOM,              @c_Packkey,          @c_Toloc,
                                          @c_Lottable01,       @c_Lottable02,       @c_Lottable03,       @d_Lottable04,                
                                          @c_Lottable06,       @c_Lottable07,       @c_Lottable08,       @c_Lottable09,    @c_Lottable10,
                                          @c_Lottable11,       @c_Lottable12,       @d_Lottable13,       @d_Lottable14,    @d_Lottable15,
                                          @c_id,               @c_Lot,              0,                   'N')                                           
         
               SELECT @n_LineNo = @n_LineNo + 1         
            END
         END
      END -- WHILE
      SET ROWCOUNT 0
      
      QUIT_SP:

      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN
   
         SELECT @b_success = 0
   
         IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_MultiBOM'
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

   END -- if continue = 1 or 2 001
END


GO