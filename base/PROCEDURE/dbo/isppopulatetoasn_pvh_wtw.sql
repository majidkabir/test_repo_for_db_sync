SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_PVH_WTW                                         */
/* Creation Date: 21-Jul-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20266 - CN_PVH_AutoCreateASN for WTW                    */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 21-Jul-2022  WLChooi 1.0  DevOps Combine Script                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_PVH_WTW] 
      @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
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
           @n_ShippedQty            INT

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                INT,
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           INT,
           @n_QtyReceived           INT,
           @n_RemainExpectedQty     INT,
           @c_Toloc                 NVARCHAR(30),
           @c_ToID                  NVARCHAR(30),
           @c_ToLot                 NVARCHAR(30),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_UDF01                 NVARCHAR(50),
           @c_UDF10                 NVARCHAR(50),
           @c_ExternLineNo          NVARCHAR(20),
           @c_WarehouseReference    NVARCHAR(10),
           @c_Dropid                NVARCHAR(20),
           @c_Channel               NVARCHAR(80),
           @c_ReceiptLineNo         NVARCHAR(5),
           @c_ReceiptGroup          NVARCHAR(10),
           @c_RecType               NVARCHAR(10),
           @c_DocType               NVARCHAR(10),
           @c_CarrierName           NVARCHAR(15),
           @n_cnt                   INT
    
   DECLARE @n_continue              INT,
           @b_success               INT,
           @n_err                   INT,
           @c_errmsg                NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   --Retrieve info
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN             
      SELECT TOP 1 @c_StorerKey          = ORDERS.StorerKey
                 , @c_ExternReceiptKey   = ORDERS.ExternOrderKey
                 , @c_ReceiptGroup       = 'ECOM'
                 , @c_RecType            = 'WTW'
                 , @c_DocType            = 'A'
                 , @c_CarrierName        = ORDERS.ConsigneeKey
                 , @c_Facility           = ORDERS.ConsigneeKey
                 , @c_Channel            = 'B2C'
                 , @c_UDF01              = ORDERS.Facility
                 , @c_UDF10              = ORDERS.UserDefine10
                 , @c_PackKey            = ORDERDETAIL.PackKey
                 , @c_UOM                = ORDERDETAIL.UOM
                 , @c_WarehouseReference = ORDERS.OrderKey
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      WHERE ORDERS.OrderKey = @c_OrderKey
      ORDER BY ORDERDETAIL.OrderLineNumber       
      
      IF @@ROWCOUNT = 0
         GOTO QUIT_SP
         
      SELECT @c_Toloc = ISNULL(CL.Long,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'PVHECOMFAC'
      AND CL.Code = @c_Facility
      AND CL.Storerkey = @c_StorerKey
   END   

   -- Create receipt
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
      IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                 WHERE WarehouseReference = @c_WarehouseReference
                 AND ExternReceiptKey = @c_ExternReceiptKey
                 AND StorerKey = @c_StorerKey)
      BEGIN
          GOTO QUIT_SP
      END
      ELSE
      BEGIN 
         -- get next receipt key
         SELECT @b_success = 0
         EXECUTE nspg_getkey
            'RECEIPT'
            , 10
            , @c_NewReceiptKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptGroup, Facility
                               , RecType, DocType, Carriername, UserDefine01, Userdefine10, WarehouseReference)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, @c_ReceiptGroup, @c_facility
                  , @c_RecType, @c_DocType, @c_CarrierName, @c_UDF01, @c_UDF10, @c_WarehouseReference)
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_PVH_WTW)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END 
   
   -- Create receiptdetail    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
      SELECT @c_ExternOrderLine = SPACE(5)

      DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                 LOTATTRIBUTE.Lottable01,
                 LOTATTRIBUTE.Lottable02,
                 LOTATTRIBUTE.Lottable03,
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
                 PICKDETAIL.lot,
                 PICKDETAIL.SKU,
                 PICKDETAIL.CaseID
          FROM PICKDETAIL (NOLOCK) 
          JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
          JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.sku
          WHERE PICKDETAIL.OrderKey = @c_OrderKey 
          GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                   LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                   LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                   LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                   PICKDETAIL.lot, PICKDETAIL.SKU, PICKDETAIL.CaseID

      OPEN PICK_CUR
            
      FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                    @c_tolot, @c_sku, @c_toid

      WHILE @@FETCH_STATUS <> -1
      BEGIN         
         SET @n_LineNo = @n_LineNo + 1

         SELECT @c_ReceiptLine = RIGHT( '0000' + LTRIM(RTRIM(CAST(@n_LineNo AS NVARCHAR(5 )))), 5)
   
         IF @n_QtyReceived IS NULL
            SELECT @n_QtyReceived = 0                      
   
         INSERT INTO RECEIPTDETAIL (ReceiptKey,                ReceiptLineNumber,   ExternReceiptKey, 
                                    StorerKey,                 SKU, 
                                    QtyExpected,               QtyReceived,
                                    ToLoc,                     
                                    Lottable01,                Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                    Lottable06,                Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                    Lottable11,                Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                    BeforeReceivedQty,         Toid,                Tolot,            Channel,          Packkey,
                                    UOM)
                     VALUES        (@c_NewReceiptKey,          @c_ReceiptLine,      @c_ExternReceiptKey,
                                    @c_StorerKey,              @c_SKU,
                                    ISNULL(@n_QtyReceived,0),  0,              
                                    @c_Toloc,
                                    @c_Lottable01,             @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05, 
                                    @c_Lottable06,             @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                    @c_Lottable11,             @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                    ISNULL(@n_QtyReceived,0),  @c_toid,                  @c_tolot,         @c_Channel,       @c_PackKey,
                                    @c_UOM)
     
         FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                       @c_tolot, @c_sku, @c_toid
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE PICK_CUR
      DEALLOCATE PICK_CUR
   END

   --Finalize
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN                                                       
      SET @n_cnt = 0
                
      ;WITH ORD AS (SELECT PD.Sku, SUM(PD.Qty) AS Qty
                   FROM PICKDETAIL PD (NOLOCK)
                   WHERE PD.Orderkey = @c_Orderkey
                   GROUP BY PD.Sku),    
           REC AS (SELECT RD.Sku, SUM(BeforeReceivedQty) AS Qty
                   FROM RECEIPT R (NOLOCK)
                   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
                   WHERE R.Receiptkey = @c_NewReceiptKey
                   GROUP BY RD.Sku)
      SELECT @n_cnt = COUNT(1)
      FROM ORD 
      LEFT JOIN REC ON ORD.Sku = REC.Sku
      WHERE ORD.Qty <> ISNULL(REC.Qty,0)

      IF ISNULL(@n_cnt,0) <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63530 
         SET @c_errmsg = 'Create ASN Failed. ASN and Order Qty Not Tally. (ispPopulateTOASN_PVH_WTW)'
      END
      ELSE
      BEGIN
         EXEC dbo.ispFinalizeReceipt      
               @c_ReceiptKey        = @c_NewReceiptKey      
              ,@b_Success           = @b_Success  OUTPUT      
              ,@n_err               = @n_err     OUTPUT      
              ,@c_ErrMsg            = @c_ErrMsg    OUTPUT       
                                   
         IF @b_Success <> 1      
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg='ASN Finalize Error (ispPopulateTOASN_PVH_WTW): ' +  RTRIM(ISNULL(@c_errmsg,'')) 
         END       
      END
   END

 QUIT_SP:

    IF @n_continue = 3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
    
       --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
       --BEGIN
          --ROLLBACK TRAN
       --END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_PVH_WTW'
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
END

GO