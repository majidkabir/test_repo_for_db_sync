SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_COLUMBIA                                        */
/* Creation Date: 05-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19576 - Auto Create ASN for Columbia                    */
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
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 05-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_COLUMBIA] 
      @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey   NVARCHAR(20),
           @c_SKU                NVARCHAR(20),
           @c_AltSKU             NVARCHAR(20),
           @c_PackKey            NVARCHAR(10),
           @c_UOM                NVARCHAR(5),
           @c_StorerKey          NVARCHAR(15),
           @c_OrderLine          NVARCHAR(5),
           @c_ToFacility         NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
           @c_ID                 NVARCHAR(18),
           @c_Type               NVARCHAR(10),
           @c_WarehouseReference NVARCHAR(18),
           @c_RecType            NVARCHAR(20),
           @c_DocType            NVARCHAR(20),
           @c_RecGroup           NVARCHAR(20),
           @c_Notes              NVARCHAR(20)

   DECLARE @c_Lottable02         NVARCHAR(18),
           @n_ShippedQty         INT
            
   DECLARE @c_NewReceiptKey      NVARCHAR(10),
           @c_FoundReceiptKey    NVARCHAR(10),
           @c_ReceiptLine        NVARCHAR(5),
           @n_LineNo             INT,
           @n_QtyReceived        INT,
           @n_QtyExpected        INT
           
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
            @c_ExternReceiptKey   = ORDERS.ExternOrderKey, 
            @c_ToFacility         = ISNULL(CODELKUP.UDF03,''),            
            @c_Storerkey          = ORDERS.Storerkey,
            @c_RecType            = 'ST',
            @c_DocType            = 'A',
            @c_RecGroup           = 'Auto',
            @c_Notes              = 'DC->EC',
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_Lottable02         = ISNULL(CODELKUP.UDF02,'')
      FROM ORDERS WITH (NOLOCK)
      JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
      JOIN CODELKUP WITH (NOLOCK) ON ORDERS.[Type] = CODELKUP.Code 
                                 AND CODELKUP.ListName = 'ORDTYP2ASN' 
                                 AND ORDERS.StorerKey = CODELKUP.Storerkey
                                 AND ORDERS.Facility = CODELKUP.Notes
                                 AND ORDERS.ConsigneeKey = CODELKUP.Short
      WHERE ORDERS.OrderKey = @c_OrderKey
     
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN             
         IF ISNULL(RTRIM(@c_Storerkey),'') <> '' -- IS NOT NULL
         BEGIN
            SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
            FROM RECEIPT (NOLOCK)
            WHERE Externreceiptkey = @c_ExternReceiptKey
            AND Warehousereference = @c_WarehouseReference
            AND Storerkey = @c_Storerkey
            AND Rectype = @c_Type
            AND Facility = @c_ToFacility
            AND Doctype = @c_DocType              
            AND ISNULL(Externreceiptkey,'') <> ''
             
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, DocType, Facility, RoutingTool, ReceiptGroup, Notes)
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_Storerkey, @c_RecType, @c_DocType, @c_ToFacility, 'N', @c_RecGroup, @c_Notes)
              
                  SET @n_err = @@Error
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_COLUMBIA)' + ' ( ' + 
                                   ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
                  SET @n_err = 63499   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_COLUMBIA)' 
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END
         END    
         ELSE
         BEGIN
            GOTO QUIT_SP
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
                   @c_AltSKU     = SKU.ALTSKU,
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
            
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN                
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
                  ISNULL(RTRIM(@c_OrderLine),'') <> ''
               BEGIN
                  DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                     SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty
                     FROM PICKDETAIL   WITH (NOLOCK) 
                     JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                     WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                           PICKDETAIL.OrderLineNumber = @c_OrderLine)
                     GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU
                 
                  OPEN PICK_CUR
                   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived
                 
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
                 
                     IF @n_QtyReceived IS NULL
                        SELECT @n_QtyReceived = 0 
                                      
                     INSERT INTO RECEIPTDETAIL (ReceiptKey,             ReceiptLineNumber,      ExternReceiptkey,    
                                                ExternLineNo,           StorerKey,              SKU, 
                                                QtyExpected,            QtyReceived,            AltSku,
                                                UOM,                    PackKey,                Lottable02,             
                                                BeforeReceivedQty,      FinalizeFlag,           ToLoc)                                                   
                                        VALUES (@c_NewReceiptKey,       @c_ReceiptLine,         @c_ExternReceiptkey,   
                                                @c_ExternOrderLine,     @c_Storerkey,           @c_SKU,
                                                @n_QtyReceived,         0,                      @c_AltSKU,
                                                @c_UOM,                 @c_Packkey,             @c_Lottable02,     
                                                0,                      'N',                    '')  
                                                                  
                     SELECT @n_LineNo = @n_LineNo + 1
                 
                     FETCH NEXT FROM PICK_CUR
                        INTO @n_QtyReceived
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
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_COLUMBIA'
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