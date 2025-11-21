SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_TWPNG                                           */
/* Creation Date: 05-May-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Auto Create ASN for TW PNG Orders SOS#369248                */
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
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 06-Mar-2019  SPChin  1.1   INC0609703 - Add Filter By StorerKey      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_TWPNG] 
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
           @c_ToStorerKey        NVARCHAR(15),
           @c_OrderLine          NVARCHAR(5),
           @c_ToFacility         NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
           @c_ID                 NVARCHAR(18),
           @c_ToLoc              NVARCHAR(10),
           @c_Type               NVARCHAR(10),
           @c_WarehouseReference NVARCHAR(18),
           @c_POKey              NVARCHAR(20)

   DECLARE @c_Lottable01         NVARCHAR(18),
           @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18),
           @d_Lottable04         DATETIME,
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
           @c_FoundReceiptKey    NVARCHAR(10),
           @c_ReceiptLine        NVARCHAR(5),
           @n_LineNo             int,
           @n_QtyReceived        int
           
   DECLARE @n_continue           int,
           @b_success            int,
           @n_err                int,
           @c_errmsg             NVARCHAR(255),
           @n_starttcnt          int
           
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT 
   SELECT @c_ID = ''
   
   --BEGIN TRAN   

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
        
     SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.ExternOrderkey, 
            @c_Type               = 'NORMAL',
            @c_ToFacility         = ORDERS.Facility,             
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_POkey              = ORDERS.BuyerPO
     FROM  ORDERS WITH (NOLOCK)
     WHERE ORDERS.OrderKey = @c_OrderKey
                               
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN             
         IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
         BEGIN
            SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
            FROM RECEIPT(NOLOCK)
            WHERE Externreceiptkey = @c_ExternReceiptKey
            AND Warehousereference = @c_WarehouseReference
            AND storerkey = @c_ToStorerKey
            AND Rectype = @c_Type
            AND Facility = @c_ToFacility
            AND Doctype = 'R'              
            AND ISNULL(Externreceiptkey,'') <> ''
            AND ISNULL(Warehousereference,'') <> ''
            
            IF ISNULL(@c_FoundReceiptKey,'') <> ''
            BEGIN
                 SELECT @c_NewReceiptKey = @c_FoundReceiptKey
            END
            ELSE
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, Facility, DocType, RoutingTool, POKey)
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ToFacility, 'R', 'N', @c_POKey)
              
                  SET @n_err = @@Error
                  
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_TWPNG)' + ' ( ' + 
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
                  SET @n_err = 63499   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_TWPNG)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 63500   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_TWPNG)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         END
      END -- if continue = 1 or 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
         SELECT @c_ExternOrderLine = SPACE(5)
         
         IF ISNULL(@c_FoundReceiptKey,'') <> ''
         BEGIN
             SELECT @n_LineNo = CONVERT(INT,MAX(ReceiptLineNumber)) + 1 
             FROM RECEIPTDETAIL (NOLOCK)
             WHERE Receiptkey = @c_FoundReceiptKey         
             
             IF ISNULL(@n_LineNo,0) = 0
                SET @n_LineNo = 1    
         END   
         
         WHILE 1=1
         BEGIN
            SET ROWCOUNT 1
            
            SELECT @c_SKU        = SKU.SKU,   
                   @c_PackKey    = ORDERDETAIL.PackKey,   
                   @c_UOM        = ORDERDETAIL.UOM,   
                   @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                   @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
                   @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),              
                   @c_ToLoc = CASE WHEN CODELKUP.UDF01 = SKU.Susr4 THEN CODELKUP.UDF02 ELSE CODELKUP.UDF03 END
            FROM ORDERDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
            JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
            --LEFT JOIN  CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN'                                         --INC0609703 
            LEFT JOIN  CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' AND ORDERS.StorerKey = CODELKUP.StorerKey --INC0609703 
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
                       ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
            ORDER by ORDERDETAIL.OrderLineNumber
           
            IF @@ROWCOUNT = 0
               BREAK
            
            SET ROWCOUNT 0 
            
            IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 63495   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc: ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                           ' (ispPopulateTOASN_TWPNG)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
           
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN                
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
                  ISNULL(RTRIM(@c_OrderLine),'') <> ''
               BEGIN
                  DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                  SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                        ISNULL(LOTATTRIBUTE.Lottable01,''),
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
                  GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                           LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,
                           LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                           LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15
                 
                  OPEN PICK_CUR
                      
                  FETCH NEXT FROM PICK_CUR
                        INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                 
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
                 
                     IF @n_QtyReceived IS NULL
                        SELECT @n_QtyReceived = 0 
                                         
                     INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,    
                                                ExternLineNo,        StorerKey,           SKU, 
                                                QtyExpected,         QtyReceived,          
                                                UOM,                 PackKey,             ToLoc,
                                                Lottable01,          Lottable02,          Lottable03,       Lottable04,     
                                                Lottable06,          Lottable07,          Lottable08,       Lottable09,    Lottable10,
                                                Lottable11,          Lottable12,          Lottable13,       Lottable14,    Lottable15,
                                                BeforeReceivedQty,   FinalizeFlag,        ID)                                                   
                                    VALUES     (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptkey,   
                                                @c_ExternOrderLine,  @c_ToStorerKey,      @c_SKU,
                                                @n_QtyReceived,      0,               
                                                @c_UOM,              @c_Packkey,          @c_Toloc,                                                    
                                                @c_Lottable01,       @c_Lottable02,       @c_Lottable03,    @d_Lottable04,       
                                                @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09, @c_Lottable10,
                                                @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14, @d_Lottable15,
                                                0,                   'N',                 @c_ID)   
                                                                     
                     SELECT @n_LineNo = @n_LineNo + 1
                 
                     FETCH NEXT FROM PICK_CUR
                           INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                                @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                                @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                  END -- WHILE @@FETCH_STATUS <> -1
                  DEALLOCATE PICK_CUR
               END
            END
         END --while
      END
      SET ROWCOUNT 0
     
     /*IF @n_continue = 1 OR @n_continue = 2
     BEGIN
        UPDATE RECEIPT WITH (ROWLOCK) 
        SET ASNStatus = '9',  
            Status    = '9'  
        WHERE ReceiptKey = @c_NewReceiptKey      

           SET @n_err = @@Error
            
        IF @n_err <> 0
        BEGIN
                SET @n_continue = 3
             SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                SET @n_err = 63492   
                SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_TWPNG)' + ' ( ' + 
                       ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END              
     END*/
      
       QUIT_SP:

       IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
      
         --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         --BEGIN
            --ROLLBACK TRAN
         --END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_TWPNG'
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