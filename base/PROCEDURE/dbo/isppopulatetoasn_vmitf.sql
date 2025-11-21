SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_VMITF                                           */
/* Creation Date: 6th Nov 2008                                          */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS (VMI Transfer) SOS#120983   */
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
/* 19-Nov-2009  NJOW01  1.1   150612 - Truncate storerkey to max 8 char */
/*                            when update to toloc.                     */ 
/* 27-May-2014  TKLIM   1.2   Added Lottables 06-15                     */
/************************************************************************/


CREATE PROCEDURE [dbo].[ispPopulateTOASN_VMITF] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE  @c_ExternReceiptKey     NVARCHAR(20),
            @c_SKU                  NVARCHAR(20),
            @c_PackKey              NVARCHAR(10),
            @c_UOM                  NVARCHAR(5),
            @c_SKUDescr             NVARCHAR(60),
            @c_StorerKey            NVARCHAR(15),
            @c_OrderLine            NVARCHAR(5),
            @c_Facility             NVARCHAR(5),
            @c_ExternOrderLine      NVARCHAR(10),
            @c_id                   NVARCHAR(18),
            @c_ToLoc                NVARCHAR(10),
            @c_Notes                NVARCHAR(2000)


   DECLARE  @c_Lottable01           NVARCHAR(18),
            @c_Lottable02           NVARCHAR(18),
            @c_Lottable03           NVARCHAR(18),
            @d_Lottable04           DATETIME,
            @d_Lottable05           DATETIME,
            @c_Lottable06           NVARCHAR(30),
            @c_Lottable07           NVARCHAR(30),
            @c_Lottable08           NVARCHAR(30),
            @c_Lottable09           NVARCHAR(30),
            @c_Lottable10           NVARCHAR(30),
            @c_Lottable11           NVARCHAR(30),
            @c_Lottable12           NVARCHAR(30),
            @d_Lottable13           DATETIME,    
            @d_Lottable14           DATETIME,    
            @d_Lottable15           DATETIME,    
            @n_ShippedQty           int

   DECLARE  @c_NewReceiptKey        NVARCHAR(10),
            @c_ReceiptLine          NVARCHAR(5),
            @n_LineNo               int,
            @c_ToFacility           NVARCHAR(5),
            @n_ExpectedQty          int,
            @n_QtyReceived          int,
            @n_RemainExpectedQty    int,
            @c_warehousereference   NVARCHAR(10),
            @c_ordertype            NVARCHAR(10)

   DECLARE  @n_pos                  int,
            @n_starttcnt            int
    
   DECLARE  @n_continue             int,
            @b_success              int,
            @n_err                  int,
            @c_errmsg               NVARCHAR(255),
            @c_salesofftake         NVARCHAR(1) -- Add by June 27.Mar.02

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT 
   
   --BEGIN TRAN   

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN  

      SET @c_id = ''
       
      SELECT @c_ExternReceiptKey   = ISNULL(ORDERS.ExternOrderkey,''),
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_ordertype          = ORDERS.Type,
             @c_Notes              = CAST(ORDERS.Notes AS NVARCHAR(2000))     
      FROM   ORDERS WITH (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey

      IF SUBSTRING(ISNULL(@c_Notes, ''),1,3) <> 'VMI'
      BEGIN
         GOTO QUIT_SP
      END

      SET @n_Pos = CHARINDEX(' ', @c_Notes)

      SET @c_Notes = SUBSTRING(@c_Notes,@n_Pos+1, LEN(@c_Notes))

      SET @n_Pos = CHARINDEX(' ', @c_Notes)

      IF @n_Pos > 0 
         SET @c_Storerkey = SUBSTRING(@c_Notes,1, @n_Pos-1)
      ELSE
         SET @c_Storerkey = ISNULL(@c_Notes,'')

      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_Storerkey )
      BEGIN

         SET @n_continue = 3
         SET @c_errmsg = CONVERT(char(250),@n_err)
         SET @n_err = 63501   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Storer Key: ' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_Storerkey)) +
                       ' (ispPopulateTOASN_VMITF)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN 
         IF LEN(LTRIM(RTRIM(@c_Storerkey))) > 8  --NJOW01
           SET @c_Toloc =  LEFT(LTRIM(RTRIM(@c_Storerkey)),8) + '10'
         ELSE
           SET @c_Toloc =  LTRIM(RTRIM(@c_Storerkey)) + '10'
         
   
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
               INSERT INTO RECEIPT (ReceiptKey, WarehouseReference, StorerKey, RecType, Facility, DocType)
               VALUES (@c_NewReceiptKey, @c_warehousereference, @c_StorerKey, 'BMSVMI', 'BR', 'A')
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err) 
               SET @n_err = 63502   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_VMITF)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63503   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_VMITF)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         END
      END -- if continue = 1 or 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
         SELECT @c_ExternOrderLine = SPACE(5)
         
   
         WHILE 1=1
         BEGIN
             SET ROWCOUNT 1
         
            SELECT @c_SKU       = ORDERDETAIL.Sku,   
                  @c_PackKey    = ORDERDETAIL.PackKey,   
                  @c_UOM        = ORDERDETAIL.UOM,   
                  @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                  @c_SKUDescr   = SKU.DESCR,   
                  @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
                  @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,'')
             FROM ORDERDETAIL WITH (NOLOCK)
                  JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
                  JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
                  ( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )
            ORDER by ORDERDETAIL.ExternLineNo

            IF @@ROWCOUNT = 0
               BREAK
   
            SET ROWCOUNT 0 
   
            IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_storerkey AND Sku = @c_sku ) 
            BEGIN 
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(char(250),@n_err)
               SET @n_err = 63504   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid To Sku: '+ dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_Sku)) + 
                             ' for Storerkey ' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_Storerkey)) + 
                             '( ispPopulateTOASN_VMITF)' + ' ( ' + ' SQLSvr MESSAGE=' + 
                             dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
            END 
     
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN 
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND 
                  ISNULL(RTRIM(@c_OrderLine), '') <> ''
               BEGIN
                    DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                        SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                               ISNULL(LOTATTRIBUTE.Lottable02,''),
                               ISNULL(LOTATTRIBUTE.Lottable03,''),
                               LOTATTRIBUTE.Lottable04,
                               ISNULL(LOTATTRIBUTE.Lottable06,''),
                               ISNULL(LOTATTRIBUTE.Lottable07,''),
                               ISNULL(LOTATTRIBUTE.Lottable08,''),
                               ISNULL(LOTATTRIBUTE.Lottable09,''),
                               ISNULL(LOTATTRIBUTE.Lottable10,''),
                               ISNULL(LOTATTRIBUTE.Lottable11,''),
                               ISNULL(LOTATTRIBUTE.Lottable12,''),
                               LOTATTRIBUTE.Lottable13,
                               LOTATTRIBUTE.Lottable14,
                               LOTATTRIBUTE.Lottable15
                        FROM PICKDETAIL   WITH (NOLOCK) 
                        JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                        WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                               PICKDETAIL.OrderLineNumber = @c_OrderLine)
                        GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU,    LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,
                        LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                        LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15
            
                     OPEN PICK_CUR
                     
                     FETCH NEXT FROM PICK_CUR
                           INTO @n_QtyReceived, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                 @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                 @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
         
   
                        IF @n_QtyReceived IS NULL
                           SELECT @n_QtyReceived = 0   

                        INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,    
                                                   ExternLineNo,        StorerKey,           SKU, 
                                                   QtyExpected,         QtyReceived,
                                                   UOM,                 PackKey,             ToLoc,
                                                   Lottable01,          Lottable02,          Lottable03,       Lottable04,             
                                                   Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                                   Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                                   ToID,                BeforeReceivedQty,   FinalizeFlag)
                                                   
                                    VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,   
                                                   @c_OrderLine,        @c_StorerKey,        @c_SKU,
                                                   ISNULL(@n_QtyReceived,0),   ISNULL(@n_QtyReceived,0),               
                                                   @c_UOM,              @c_Packkey,          @c_Toloc,
                                                   @c_ExternReceiptKey, @c_Lottable02,       @c_Lottable03,    @d_Lottable04,         
                                                   @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                                   @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                                   @c_id,               ISNULL(@n_QtyReceived,0),   'Y')   
         
                        SELECT @n_LineNo = @n_LineNo + 1
         
                        FETCH NEXT FROM PICK_CUR
                              INTO @n_QtyReceived, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_VMITF'
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