SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_ANTA                                            */
/* Creation Date: 08-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23093 - CN ANTA AutoCreateASN New                       */
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
/* 08-Jun-2023  WLChooi 1.0  DevOps Combine Script                      */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispPopulateTOASN_ANTA] 
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
           @n_OriginalQty           INT

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                INT,
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           INT,
           @n_QtyReceived           INT,
           @n_RemainExpectedQty     INT,
           @c_ToLoc                 NVARCHAR(30),
           @c_ToID                  NVARCHAR(30),
           @c_ToLot                 NVARCHAR(30),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_UDF01                 NVARCHAR(50),
           @c_UDF05                 NVARCHAR(50),
           @c_WarehouseReference    NVARCHAR(10),
           @c_Dropid                NVARCHAR(20),
           @c_Channel               NVARCHAR(80),
           @c_ReceiptLineNo         NVARCHAR(5),
           @c_ReceiptGroup          NVARCHAR(10),
           @c_RecType               NVARCHAR(10),
           @c_DocType               NVARCHAR(10),
           @c_Notes                 NVARCHAR(MAX),
           @n_cnt                   INT,
           @c_SellerName            NVARCHAR(100),
           @c_SellerCompany         NVARCHAR(100),
           @c_ExternOrderkey        NVARCHAR(50),
           @c_UDF02                 NVARCHAR(50),
           @n_BeforeReceivedQty     INT,
           @c_CLShort               NVARCHAR(10)
    
   DECLARE @n_continue              INT,
           @b_success               INT,
           @n_err                   INT,
           @c_errmsg                NVARCHAR(255),
           @n_StartTranCnt          INT

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = N'', @n_StartTranCnt = @@TRANCOUNT

   --Retrieve info
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN             
      SELECT TOP 1 @c_ExternReceiptKey   = ORDERS.ExternOrderKey
                 , @c_RecType            = ORDERS.[Type]
                 , @c_DocType            = N'A'
                 , @c_StorerKey          = ORDERS.StorerKey
                 , @c_UDF01              = ORDERS.UserDefine01
                 , @c_Facility           = ORDERS.UserDefine05
                 , @c_UDF05              = ORDERS.Facility
                 , @c_WarehouseReference = ORDERS.OrderKey
      FROM ORDERS (NOLOCK)
      WHERE ORDERS.OrderKey = @c_OrderKey   
      
      IF @@ROWCOUNT = 0
         GOTO QUIT_SP
         
      SET @c_ToLoc = N''

      SELECT @c_ToLoc = CODELKUP.Short
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'IQCRECLOC'
      AND Code = @c_Facility
      AND Storerkey = @c_StorerKey

      IF NOT EXISTS ( SELECT 1
                      FROM LOC (NOLOCK)
                      WHERE LOC = @c_ToLoc )
      BEGIN
         GOTO QUIT_SP
      END

      IF @c_RecType <> 'IQC'
      BEGIN
         GOTO QUIT_SP
      END
   END   

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   IF @@TRANCOUNT = 0
      BEGIN TRAN

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
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, RECType, StorerKey
                               , Facility, DOCTYPE, UserDefine01, UserDefine05)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_RecType, @c_StorerKey
                  , @c_Facility, @c_DocType, @c_UDF01, @c_UDF05)
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520   
            SELECT @c_errmsg=N'NSQL'+CONVERT(char(5),@n_err)+N': Generate Receipt Key Failed! (ispPopulateTOASN_ANTA)' + N' ( ' + N' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + N' ) '
            GOTO QUIT_SP
         END
      END
   END 
   
   -- Create receiptdetail    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
      SELECT @c_ExternOrderLine = SPACE(5)

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1

         SELECT @c_SKU = SKU.Sku
              , @c_PackKey = ORDERDETAIL.PackKey
              , @c_UOM = ORDERDETAIL.UOM
              , @n_OriginalQty = (ORDERDETAIL.OriginalQty)
              , @c_OrderLine = ORDERDETAIL.OrderLineNumber
              , @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo, '')
         FROM ORDERDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
         JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
         WHERE (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty > 0)
         AND   (ORDERDETAIL.OrderKey = @c_OrderKey)
         AND   (ORDERDETAIL.OrderLineNumber > @c_OrderLine)
         ORDER BY ORDERDETAIL.OrderLineNumber

         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF ISNULL(TRIM(@c_OrderKey), '') <> '' AND ISNULL(TRIM(@c_OrderLine), '') <> ''
            BEGIN
               DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                   SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                          LOTATTRIBUTE.Lottable01,
                          PICKDETAIL.Lot,
                          PICKDETAIL.SKU,
                          CASE WHEN PICKDETAIL.UOM = '1' THEN PICKDETAIL.ID ELSE PICKDETAIL.DropID END
                   FROM PICKDETAIL (NOLOCK) 
                   JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)
                   JOIN SKU S WITH (NOLOCK) ON (S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.SKU)
                   JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber 
                                            AND ORDERDETAIL.StorerKey = PICKDETAIL.Storerkey AND ORDERDETAIL.Sku = PICKDETAIL.Sku)
                   WHERE PICKDETAIL.OrderKey = @c_OrderKey AND PICKDETAIL.OrderLineNumber = @c_OrderLine
                   GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                            LOTATTRIBUTE.Lottable01, PICKDETAIL.Lot, PICKDETAIL.SKU, CASE WHEN PICKDETAIL.UOM = '1' THEN PICKDETAIL.ID ELSE PICKDETAIL.DropID END
               
               OPEN PICK_CUR
                  
               FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable01, @c_ToLot, @c_SKU, @c_ToID
               
               WHILE @@FETCH_STATUS <> -1
               BEGIN         
                  SET @n_LineNo = @n_LineNo + 1
               
                  SELECT @c_ReceiptLine = RIGHT( '0000' + LTRIM(TRIM(CAST(@n_LineNo AS NVARCHAR(5 )))), 5)
               
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0   
                  
                  SET @n_BeforeReceivedQty = @n_QtyReceived
                  SET @n_ExpectedQty = @n_QtyReceived
               
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,                ReceiptLineNumber,   ExternReceiptKey, 
                                             StorerKey,                 SKU,                 ExternLineNo,
                                             QtyExpected,               QtyReceived,         UOM,
                                             ToLoc,                     
                                             Lottable01,                UserDefine01,        BeforeReceivedQty,         
                                             ToID,                      ToLot,               Packkey)
                              VALUES        (@c_NewReceiptKey,          @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_StorerKey,              @c_SKU,              @c_ExternOrderLine,
                                             ISNULL(@n_ExpectedQty, 0), 0,                   @c_UOM,
                                             ISNULL(@c_ToLoc,''),
                                             @c_Lottable01,             @n_OriginalQty,      ISNULL(@n_BeforeReceivedQty, 0),
                                             @c_ToID,                   @c_ToLot,            @c_PackKey)
               
                  FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable01, @c_ToLot, @c_SKU, @c_ToID
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE PICK_CUR
               DEALLOCATE PICK_CUR
            END
         END
      END
   END
   SET ROWCOUNT 0

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN

   --Finalize
   /*
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
         SET @c_errmsg = 'Create ASN Failed. ASN and Order Qty Not Tally. (ispPopulateTOASN_ANTA)'
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM RECEIPTDETAIL (NOLOCK)
                         WHERE ReceiptKey = @c_NewReceiptKey
                         AND ToLoc = '' ) AND @c_CLShort = '1'
         BEGIN
            EXEC dbo.ispFinalizeReceipt      
                  @c_ReceiptKey        = @c_NewReceiptKey      
                 ,@b_Success           = @b_Success  OUTPUT      
                 ,@n_err               = @n_err     OUTPUT      
                 ,@c_ErrMsg            = @c_ErrMsg    OUTPUT       
                                   
            IF @b_Success <> 1      
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = 'ASN Finalize Error (ispPopulateTOASN_ANTA): ' +  TRIM(ISNULL(@c_errmsg,'')) 
               GOTO QUIT_SP
            END 
         END
      END
   END*/

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_ANTA'
      --RAISERROR @n_err @c_errmsg
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
   
   WHILE @@TRANCOUNT < @n_StartTranCnt
      BEGIN TRAN
END

GO