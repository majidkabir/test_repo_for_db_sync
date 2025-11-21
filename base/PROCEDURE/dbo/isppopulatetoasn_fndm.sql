SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_FNDM                                            */
/* Creation Date: 7th Sept 2010                                         */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Auto Create ASN for FNDM Orders  SOS#186290                 */
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
/* Date         Author  Ver.  Purposes                                  */
/* 28-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_FNDM] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_MasterSKU             NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10),
           @c_id                    NVARCHAR(18),
           @c_ToLoc                 NVARCHAR(10),
           @c_Lot                   NVARCHAR(10),
           @c_Notes2                NVARCHAR(2000),
           @n_casecnt               int

   DECLARE @c_Carrierkey            NVARCHAR(15),
           @c_CarrierName           NVARCHAR(30),
           @c_CarrierAddress1       NVARCHAR(45),
           @c_CarrierAddress2       NVARCHAR(45),
           @c_CarrierCity           NVARCHAR(45),
           @c_CarrierState          NVARCHAR(2),
           @c_CarrierZip            NVARCHAR(10)

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
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @n_RemainExpectedQty     int,
           @c_warehousereference    NVARCHAR(10)

   DECLARE @n_starttcnt             int
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT 
   
   --BEGIN TRAN   

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  

      SET @c_id = ''
      SET @c_Facility = '4610'
      --SET @c_CarrierKey = '46580'
      SET @c_CarrierKey = 'FNDM'
       
      SELECT @c_ExternReceiptKey   = ISNULL(ORDERS.ExternOrderkey,''),
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_Notes2             = CAST(ORDERS.Notes2 AS NVARCHAR(2000))                  
      FROM   ORDERS WITH (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey

      IF LEFT(ISNULL(@c_Notes2,''),4) <> 'FNDM'
      BEGIN
         GOTO QUIT_SP
      END
      
      SELECT @c_CarrierName      = ISNULL(RTRIM(STORER.Company),''),
             @c_CarrierAddress1  = ISNULL(RTRIM(STORER.Address1),''),
             @c_CarrierAddress2  = ISNULL(RTRIM(STORER.Address2),''),
             @c_CarrierCity      = ISNULL(RTRIM(STORER.City),''),
             @c_CarrierState     = ISNULL(RTRIM(STORER.State),''),
             @c_CarrierZip       = ISNULL(RTRIM(STORER.Zip),'')
      FROM STORER (NOLOCK)
      WHERE STORER.Storerkey = @c_Carrierkey

      SET @c_Storerkey = ISNULL(@c_Notes2,'')

      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_Storerkey )
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63500   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Storer Key: ' + RTRIM(ISNULL(@c_Storerkey,'')) +
                       ' (ispPopulateTOASN_FNDM)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END

      IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE ExternReceiptkey = @c_ExternReceiptkey AND Storerkey = @c_Storerkey)
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63501   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ASN ExternReceiptkey Already Exist In System: ' + RTRIM(ISNULL(@c_ExternReceiptkey,'')) +
                       ' (ispPopulateTOASN_FNDM)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN             
         IF ISNULL(RTRIM(@c_StorerKey),'') <> '' -- IS NOT NULL
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
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, WarehouseReference, StorerKey, RecType, Facility, DocType, RoutingTool, 
                                    Carrierkey, CarrierName, CarrierAddress1, CarrierAddress2, CarrierCity, CarrierState, CarrierZip)
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_ExternReceiptkey, @c_StorerKey, 'NORMAL', @c_Facility, 'A', 'Y', 
                       @c_CarrierKey, @c_CarrierName, @c_CarrierAddress1, @c_CarrierAddress2, @c_CarrierCity, @c_CarrierState, @c_CarrierZip)
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err) 
               SET @n_err = 63502   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_FNDM)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63503   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_FNDM)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         END
      END -- if continue = 1 or 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
         SELECT @c_ExternOrderLine = SPACE(5)
         
         WHILE 1=1
         BEGIN
             SET ROWCOUNT 1
         
            SELECT @c_SKU       = SKU.AltSku,   
                  @c_PackKey    = ORDERDETAIL.PackKey,   
                  @c_UOM        = ORDERDETAIL.UOM,   
                  @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                  @c_SKUDescr   = SKU.DESCR,   
                  @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
                  @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),
                  @c_MasterSKU = ORDERDETAIL.Sku
             FROM ORDERDETAIL WITH (NOLOCK)
                  JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
                  JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
                  ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
            ORDER by ORDERDETAIL.OrderLineNumber

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
                             '( ispPopulateTOASN_FNDM)' + ' ( ' + ' SQLSvr MESSAGE=' + 
                             RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
            ELSE
            BEGIN
                SELECT @c_PackKey = SKU.PackKey,
                      @c_UOM = PACK.PACKUOM1,
                      @n_CaseCnt = PACK.Casecnt
               FROM SKU (NOLOCK)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               WHERE SKU.Storerkey = @c_storerkey
               AND SKU.Sku = @c_sku                
               
               IF @n_CaseCnt = 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(char(250),@n_err)
                  SET @n_err = 63505   
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Casecnt Not Yet Setup For Packkey: '+RTRIM(@c_PackKey)+' To Sku: '+ RTRIM(ISNULL(@c_Sku,'')) + 
                                 ' for Storerkey ' + RTRIM(ISNULL(@c_Storerkey,'')) + 
                                '( ispPopulateTOASN_FNDM)' + ' ( ' + ' SQLSvr MESSAGE=' + 
                                RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END        
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN                
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
                  ISNULL(RTRIM(@c_OrderLine), '') <> ''
               BEGIN
                    DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                        SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                               ISNULL(LOTATTRIBUTE.Lottable01,''),
                               ISNULL(LOTATTRIBUTE.Lottable02,''),
                               ISNULL(LOTATTRIBUTE.Lottable03,''),
                               LOTATTRIBUTE.Lottable04,
                               LOTATTRIBUTE.Lottable05,
                               ISNULL(LOTATTRIBUTE.Lottable06,''),
                               ISNULL(LOTATTRIBUTE.Lottable07,''),
                               ISNULL(LOTATTRIBUTE.Lottable08,''),
                               ISNULL(LOTATTRIBUTE.Lottable09,''),
                               ISNULL(LOTATTRIBUTE.Lottable10,''),
                               ISNULL(LOTATTRIBUTE.Lottable11,''),
                               ISNULL(LOTATTRIBUTE.Lottable12,''),
                               LOTATTRIBUTE.Lottable13,
                               LOTATTRIBUTE.Lottable14,
                               LOTATTRIBUTE.Lottable15,
                               PICKDETAIL.Lot,
                               PICKDETAIL.Loc,
                               PICKDETAIL.Id
                        FROM PICKDETAIL   WITH (NOLOCK) 
                        JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                        WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                               PICKDETAIL.OrderLineNumber = @c_OrderLine)
                        GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                                 LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                                 LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                                 LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                                 PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.Id
            
                     OPEN PICK_CUR
                     
                     FETCH NEXT FROM PICK_CUR
                        INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                             @c_Lot, @c_ToLoc, @c_id
            
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
         
                        IF @n_QtyReceived IS NULL
                           SELECT @n_QtyReceived = 0 
                          
                        SELECT @n_QtyReceived = @n_QtyReceived * @n_CaseCnt  

                        INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,    
                                                   ExternLineNo,        StorerKey,           SKU, 
                                                   QtyExpected,         QtyReceived,         ExternPoKey, 
                                                   UOM,                 PackKey,             ToLoc,
                                                   Lottable01,          Lottable02,          Lottable03,       Lottable04,       Lottable05,       
                                                   Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                                   Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                                   ToID,                ToLot,                   
                                                   BeforeReceivedQty,   FinalizeFlag,        ALTSKU)                                                   
                                    VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptkey,   
                                                   @c_OrderLine,        @c_StorerKey,        @c_SKU,
                                                   ISNULL(@n_QtyReceived,0),   0,            @c_ExternReceiptkey,   
                                                   @c_UOM,              @c_Packkey,          @c_Toloc,
                                                   @c_Lottable01,       @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05,         
                                                   @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                                   @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                                   @c_id,               @c_Lot,                                   
                                                   0,                   'N',                 @c_MasterSKU)   
                                                   
         
                        SELECT @n_LineNo = @n_LineNo + 1
         
                        FETCH NEXT FROM PICK_CUR
                           INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                                @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                                @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                                @c_Lot, @c_ToLoc, @c_id
                     END -- WHILE @@FETCH_STATUS <> -1
                     DEALLOCATE PICK_CUR
               END
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_FNDM'
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