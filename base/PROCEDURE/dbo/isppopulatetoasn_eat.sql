SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_EAT                                             */
/* Creation Date: 17-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19192 - Auto Create ASN for Arden Orders                */
/*          Duplicate and modify from ispPopulateTOASN_LOR              */
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
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 17-Mar-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 10-Feb-2023  WLChooi  1.1  WMS-21752 - Map Lottable08 (WL01)         */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateTOASN_EAT] 
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
           @c_PutawayLoc         NVARCHAR(10),
           @c_Type               NVARCHAR(10),
           @c_WarehouseReference NVARCHAR(18),
           @c_Mbolkey            NVARCHAR(10)

   DECLARE @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18),
           @d_Lottable04         DATETIME,
           @n_ShippedQty         INT,
           @c_Lottable08         NVARCHAR(50)   --WL01
            
   DECLARE @c_NewReceiptKey      NVARCHAR(10),
           @c_FoundReceiptKey    NVARCHAR(10),
           @c_ReceiptLine        NVARCHAR(5),
           @n_LineNo             INT,
           @n_QtyReceived        INT
           
   DECLARE @n_continue           INT,
           @b_success            INT,
           @n_err                INT,
           @c_errmsg             NVARCHAR(255),
           @n_StartTranCnt       INT
            
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTranCnt = @@TRANCOUNT 
   
   BEGIN TRAN   

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
        
      SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.Loadkey, 
            @c_Type               = ISNULL(CODELKUP.Short,''),
            @c_ToFacility         = MBOL.Facility,             
            @c_ToStorerkey        = ISNULL(CODELKUP.Storerkey,''),
            @c_Storerkey          = ORDERS.Storerkey,
            @c_ToLoc              = ISNULL(CODELKUP.UDF01,''),
            @c_PutawayLoc         = ISNULL(CODELKUP.UDF02,''),
            @c_WarehouseReference = MBOL.OtherReference,
            @c_Id                 = ORDERS.ExternOrderkey,
            @c_Mbolkey            = MBOL.Mbolkey 
      FROM  ORDERS WITH (NOLOCK)
      JOIN  MBOL WITH (NOLOCK) ON ORDERS.Mbolkey = MBOL.Mbolkey
      JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
      LEFT JOIN  CODELKUP WITH (NOLOCK) ON ORDERS.[Type] = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' 
                                       AND ORDERS.StorerKey = CODELKUP.Storerkey
      WHERE ORDERS.OrderKey = @c_OrderKey
                        
      IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63495   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc: ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                       ' (ispPopulateTOASN_EAT)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END

      IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_PutawayLoc) AND ISNULL(@c_PutawayLoc,'') <> ''
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63496   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Putaway Loc: ' + RTRIM(ISNULL(@c_PutawayLoc,'')) +
                       ' (ispPopulateTOASN_EAT)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END
       
      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63497   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                       ' (ispPopulateTOASN_EAT)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END
     
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
            AND Userdefine09 = @c_Mbolkey
             
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, Facility, DocType, RoutingTool, Userdefine09)
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ToFacility, 'R', 'N', @c_Mbolkey)
              
                  SET @n_err = @@Error
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_EAT)' + ' ( ' + 
                                   ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
                  SET @n_err = 63499   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_EAT)' 
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END
         END    
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 63500   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_EAT)' + ' ( ' + 
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
                   @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,'')
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
            
            IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku ) 
            BEGIN                     
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 63501   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_EAT)' + ' ( ' + 
                             ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
           
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN                
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
                  ISNULL(RTRIM(@c_OrderLine),'') <> ''
               BEGIN
                  DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                     SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                            ISNULL(LOTATTRIBUTE.Lottable02,''),
                            ISNULL(LOTATTRIBUTE.Lottable03,''),
                            LOTATTRIBUTE.Lottable04,
                            ISNULL(LOTATTRIBUTE.Lottable08,'')   --WL01
                     FROM PICKDETAIL   WITH (NOLOCK) 
                     JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                     WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                           PICKDETAIL.OrderLineNumber = @c_OrderLine)
                     GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU,  LOTATTRIBUTE.Lottable02, 
                              LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,
                              LOTATTRIBUTE.Lottable08   --WL01
                 
                  OPEN PICK_CUR
                   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable02, @c_Lottable03, @d_Lottable04, @c_Lottable08   --WL01
                 
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
                 
                     IF @n_QtyReceived IS NULL
                        SELECT @n_QtyReceived = 0 
                                      
                     INSERT INTO RECEIPTDETAIL (ReceiptKey,             ReceiptLineNumber,      ExternReceiptkey,    
                                                ExternLineNo,           StorerKey,              SKU, 
                                                QtyExpected,            QtyReceived,            PutawayLoc,
                                                UOM,                    PackKey,                ToLoc,
                                                Lottable01,             Lottable02,             
                                                Lottable03,             Lottable04,             Lottable08,   --WL01     
                                                BeforeReceivedQty,      FinalizeFlag,           ID)                                                   
                                        VALUES (@c_NewReceiptKey,       @c_ReceiptLine,         @c_ExternReceiptkey,   
                                                @c_ExternOrderLine,     @c_ToStorerKey,         @c_SKU,
                                                @n_QtyReceived,         0,                      @c_PutawayLoc,               
                                                @c_UOM,                 @c_Packkey,             @c_Toloc,
                                                @c_ID,                  @c_Lottable02,
                                                @c_Lottable03,          @d_Lottable04,          @c_Lottable08,   --WL01       
                                                0,                      'N',                    @c_ID )  
                                                                  
                     SELECT @n_LineNo = @n_LineNo + 1
                 
                     FETCH NEXT FROM PICK_CUR
                        INTO @n_QtyReceived, @c_Lottable02, @c_Lottable03, @d_Lottable04, @c_Lottable08   --WL01
                  END -- WHILE @@FETCH_STATUS <> -1
                  CLOSE PICK_CUR
                  DEALLOCATE PICK_CUR
               END
            END
         END --while
      END
      SET ROWCOUNT 0

      QUIT_SP:
      IF CURSOR_STATUS('LOCAL', 'PICK_CUR') IN (0 , 1)
      BEGIN
         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR   
      END
      
      IF @n_Continue = 3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_StartTranCnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_EAT'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END        
   END -- if continue = 1 or 2 001
END

GO