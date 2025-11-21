SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateToASN_MultiBOM2                                       */
/* Creation Date: 26 Sep 2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Auto Create ASN for Orders - UNKIT  SOS#225774              */
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
/* Date         Author    Ver.  Purposes                                */
/* 07-04-2014   SPChin    1.1   SOS308158 - Bug Fixed                   */
/* 27-May-2014  TKLIM     1.2   Added Lottables 06-15                   */
/*b04-08-2014   NJOW01    1.3   317393 - Populate lottable01-05 to ASN  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateToASN_MultiBOM2] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10),
           @c_id                    NVARCHAR(18),
           @c_ToLoc                 NVARCHAR(10),
           @c_Lot                   NVARCHAR(10),
           @c_ComponentSku          NVARCHAR(20),
           @n_ComponentQty          int,
           @c_Key                   NVARCHAR(15) --NJOW01

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
           @n_ExpectedQty           int,
           @c_warehousereference    NVARCHAR(18)

   DECLARE @n_starttcnt             int
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @n_cnt                   int

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
                       ' (ispPopulateToASN_MultiBOM2)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END*/

      /*IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE ExternReceiptkey = @c_ExternReceiptkey AND Storerkey = @c_Storerkey)
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63501   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ASN ExternReceiptkey Already Exist In System: ' + RTRIM(ISNULL(@c_ExternReceiptkey,'')) +
                       ' (ispPopulateToASN_MultiBOM2)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
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
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_StorerKey, 'UNKIT', @c_Facility, 'A', 'Y')
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err) 
               SET @n_err = 63502   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateToASN_MultiBOM2)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63503   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateToASN_MultiBOM2)' + ' ( ' + 
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
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1, @c_Key = ''
         SELECT @c_ExternOrderLine = SPACE(5)
           
         SELECT @n_cnt = 0
         WHILE 1=1
         BEGIN
            SET ROWCOUNT 1
         
            SELECT @c_SKU              = ORDERDETAIL.Sku,   
                   --@n_ShippedQty       = SUM(ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked),
  	               @n_ShippedQty = SUM(PICKDETAIL.Qty),
                   @c_OrderLine        = MIN(ORDERDETAIL.OrderLineNumber),
                   @c_ExternOrderLine  = MIN(ISNULL(ORDERDETAIL.ExternLineNo,'')),
                   @c_lottable01       = LOTATTRIBUTE.Lottable01, 
                   @c_lottable02       = LOTATTRIBUTE.Lottable02, 
                   @c_lottable03       = LOTATTRIBUTE.Lottable03, 
                   @d_lottable04       = LOTATTRIBUTE.Lottable04,
                   @d_lottable05       = LOTATTRIBUTE.Lottable05,
                   @c_Lottable06       = LOTATTRIBUTE.Lottable06,
                   @c_Lottable07       = LOTATTRIBUTE.Lottable07,
                   @c_Lottable08       = LOTATTRIBUTE.Lottable08,
                   @c_Lottable09       = LOTATTRIBUTE.Lottable09,
                   @c_Lottable10       = LOTATTRIBUTE.Lottable10,
                   @c_Lottable11       = LOTATTRIBUTE.Lottable11,
                   @c_Lottable12       = LOTATTRIBUTE.Lottable12,
                   @d_Lottable13       = LOTATTRIBUTE.Lottable13,
                   @d_Lottable14       = LOTATTRIBUTE.Lottable14,
                   @d_Lottable15       = LOTATTRIBUTE.Lottable15,
	                 @c_key = MIN(ORDERDETAIL.OrderLineNumber + PICKDETAIL.Pickdetailkey)
            FROM ORDERDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
            JOIN SKU WITH (NOLOCK) ON (SKU.Storerkey = ORDERDETAIL.Storerkey
                                      AND SKU.Sku = ORDERDETAIL.Sku)
            JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
	      		JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
            WHERE ( ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked > 0 ) 
            AND   ( ORDERDETAIL.OrderKey = @c_orderkey ) --AND
                   --( SKU.PrePackIndicator = 'Y')
            GROUP BY ORDERDETAIL.Sku,
                     LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                     LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                     LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15
			      HAVING MIN(ORDERDETAIL.OrderLineNumber +  PICKDETAIL.PickdetailKey) > @c_Key
	          ORDER BY MIN(ORDERDETAIL.OrderLineNumber + PICKDETAIL.PickdetailKey)

            IF @@ROWCOUNT = 0
               BREAK
   
            SET ROWCOUNT 0 
            
            SELECT @n_cnt = @n_cnt + 1
   
            IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_storerkey AND Sku = @c_sku ) 
            BEGIN 
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err)
               SET @n_err = 63504   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Sku: '+ RTRIM(ISNULL(@c_Sku,'')) + 
                                  ' for Storerkey ' + RTRIM(ISNULL(@c_Storerkey,'')) + 
                                  '( ispPopulateToASN_MultiBOM2)' + ' ( ' + ' SQLSvr MESSAGE=' + 
                                  RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               BREAK
            END
            /*ELSE
            BEGIN
               SELECT @c_PackKey = SKU.PackKey,
                   @c_UOM = PACK.PACKUOM3
               FROM SKU (NOLOCK)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               WHERE SKU.Storerkey = @c_storerkey
               AND SKU.Sku = @c_sku                               
            END*/
           
            IF (SELECT COUNT(*) FROM BILLOFMATERIAL(NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_sku) > 0
            BEGIN
               DECLARE CUR_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT BOM.ComponentSku, SKU.Packkey, PACK.Packuom3, (@n_ShippedQty * BOM.Qty) AS Componentqty
               FROM BILLOFMATERIAL BOM (NOLOCK)
                 JOIN SKU (NOLOCK) ON BOM.Storerkey = SKU.Storerkey AND BOM.ComponentSku = SKU.Sku	--SOS308158
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE BOM.Storerkey = @c_Storerkey 
               AND BOM.Sku = @c_sku
               ORDER BY BOM.Sku                 
            END
            ELSE
            BEGIN
               DECLARE CUR_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT BOM.ComponentSku, BOM.ComponentSku_Packkey, BOM.ComponentSku_Packuom3,  
                      SUM(CASE WHEN ORD.casecnt = BOM.uomqty THEN ORD.fullpackctn * BOM.componentqty ELSE BOM.componentqty END) AS Componentqty 
               FROM (SELECT SKU.Storerkey, SKU.Sku,  
                           CASE WHEN PACK.Casecnt > 0 THEN FLOOR(@n_ShippedQty / PACK.Casecnt) ELSE 0 END AS fullpackctn, 
                           @n_ShippedQty % CAST(PACK.Casecnt AS INT) AS loosepackqty, PACK.casecnt  
                     FROM SKU (NOLOCK) 
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
                     WHERE SKU.Storerkey = @c_storerkey
                     AND SKU.Sku = @c_sku) AS ORD  
               JOIN (SELECT SKU.Storerkey, SKU.Sku,  
                           CASE WHEN PACK.Packuom3 = UPC.uom THEN PACK.qty 
                                WHEN PACK.Packuom1 = UPC.uom THEN PACK.casecnt 
                                WHEN PACK.Packuom2 = UPC.uom THEN PACK.innerpack 
                                WHEN PACK.Packuom4 = UPC.uom THEN PACK.pallet 
                                WHEN PACK.Packuom5 = UPC.uom THEN PACK.cube 
                                WHEN PACK.Packuom6 = UPC.uom THEN PACK.grosswgt END AS uomqty, 
                           BM.Sequence, BM.Componentsku, BM.QTY AS ComponentQty,  
                           SKU.Packkey, UPC.Upc, UPC.UOM, SKUCOMP.Descr AS Componentsku_descr,
                           SKUCOMP.Packkey AS Componentsku_packkey, PACKCOMP.Packuom3 AS Componentsku_packuom3 
                     FROM SKU (NOLOCK)  
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
                     JOIN UPC (NOLOCK) ON ((PACK.packuom3 = UPC.UOM   
                                             OR PACK.packuom1 = UPC.UOM 
                                             OR PACK.packuom2 = UPC.UOM 
                                             OR PACK.packuom4 = UPC.UOM 
                                             OR PACK.packuom5 = UPC.UOM 
                                             OR PACK.packuom6 = UPC.UOM)  
                                          AND SKU.Storerkey = UPC.Storerkey 
                                          AND SKU.Sku = UPC.Sku 
                                          AND SKU.Packkey = UPC.Packkey) 
                     JOIN BILLOFMATERIAL BM (NOLOCK) ON UPC.Storerkey = BM.Storerkey  
                                                         AND UPC.Upc = BM.Sku  
                     JOIN SKU SKUCOMP (NOLOCK) ON BM.Storerkey = SKUCOMP.Storerkey 
                                             AND BM.ComponentSku = SKUCOMP.Sku 
                     JOIN PACK PACKCOMP (NOLOCK) ON SKUCOMP.Packkey = PACKCOMP.Packkey 
                     WHERE SKU.Storerkey = @c_storerkey 
                     AND SKU.Sku = @c_sku) AS BOM 
               ON (ORD.Storerkey = BOM.Storerkey AND ORD.Sku = BOM.Sku  
               AND (CASE WHEN ORD.fullpackctn > 0 THEN ORD.Casecnt ELSE 0 END = BOM.uomqty  
                     OR ORD.loosepackqty = BOM.uomqty))  
               GROUP BY BOM.ComponentSku, BOM.ComponentSku_Packkey,  
                        BOM.ComponentSku_Packuom3
            END
            
            OPEN CUR_BOM 
            
            FETCH NEXT FROM CUR_BOM INTO @c_ComponentSku, @c_Packkey, @c_UOM, @n_ComponentQty   
            
            IF @@FETCH_STATUS <> 0
            BEGIN
                SET @n_continue = 3
                SET @n_err = 63505   
                SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': BOM Setup Not Found For Sku: '+ RTRIM(ISNULL(@c_Sku,'')) + 
                                   ' of Storerkey ' + RTRIM(ISNULL(@c_Storerkey,'')) + ' (ispPopulateToASN_MultiBOM2)' 
               BREAK
            END
            
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
               
               SELECT @n_ExpectedQty = @n_ComponentQty 
           
               INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,    
                                          ExternLineNo,        StorerKey,           SKU, 
                                          QtyExpected,         QtyReceived,         ExternPoKey, 
                                          UOM,                 PackKey,             ToLoc,
                                          Lottable01,          Lottable02,          Lottable03,          Lottable04,       Lottable05,            
                                          Lottable06,          Lottable07,          Lottable08,          Lottable09,       Lottable10,
                                          Lottable11,          Lottable12,          Lottable13,          Lottable14,       Lottable15,
                                          ToID,                ToLot,               BeforeReceivedQty,   FinalizeFlag)                                                   
                             VALUES      (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptkey,   
                                          @c_OrderLine,        @c_StorerKey,        @c_ComponentSku,
                                          @n_ExpectedQty,      0,                   @c_WarehouseReference,   
                                          @c_UOM,              @c_Packkey,          @c_Toloc,
                                          @c_Lottable01,       @c_Lottable02,       @c_Lottable03,       @d_Lottable04,    @d_Lottable05,            
                                          @c_Lottable06,       @c_Lottable07,       @c_Lottable08,       @c_Lottable09,    @c_Lottable10,
                                          @c_Lottable11,       @c_Lottable12,       @d_Lottable13,       @d_Lottable14,    @d_Lottable15,
                                          @c_id,               @c_Lot,              0,                   'N')   
                                            
               SELECT @n_LineNo = @n_LineNo + 1         
               FETCH NEXT FROM CUR_BOM INTO @c_ComponentSku, @c_Packkey, @c_UOM, @n_ComponentQty   
            END
            CLOSE CUR_BOM                
            DEALLOCATE CUR_BOM
         END --While
         
         IF @n_cnt = 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63506   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No Item Details Found (ispPopulateToASN_MultiBOM2)' 
         END
      END -- continue
      SET ROWCOUNT 0
             
      QUIT_SP:
           
      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN 
            
         SELECT @b_success = 0
            
         IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateToASN_MultiBOM2'
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