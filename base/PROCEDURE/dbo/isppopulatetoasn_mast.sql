SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_MAST                                            */
/* Creation Date: 29-MAY-2023                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22667 CN MAST Exceed Auto Create ASN by MBOL Ship       */
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
/*Date         Author   Ver. Purposes                                   */
/*31-MAY-2023  CSCHONG  1.0  Devops Scripts Combine                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateTOASN_MAST]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @c_ExternReceiptKey   NVARCHAR(20),
            @c_SKU                NVARCHAR(20),
            @c_ALTSKU             NVARCHAR(20),
            @c_PackKey            NVARCHAR(10),
            @c_UOM                NVARCHAR(5),
            @c_StorerKey          NVARCHAR(15),
            @c_ToStorerKey        NVARCHAR(15),
            @c_ToFacility         NVARCHAR(5),
            @c_ExternOrderLine    NVARCHAR(10),
            @c_ToLoc              NVARCHAR(10),
            @c_ToLot              NVARCHAR(10),
            @c_Type               NVARCHAR(10),
            @c_Carrierkey         NVARCHAR(15),
            @c_CarrierName        NVARCHAR(30),
            @c_ReceiptGroup       NVARCHAR(20),
            @c_Containerkey       NVARCHAR(18),
            @c_dropid             NVARCHAR(30),
            @n_CaseCnt            INT,
            @c_ContainerkeyDet    NVARCHAR(18),
            @n_GrossWgt           FLOAT,
            @n_NetWgt             FLOAT,
            @c_ExternPokey        NVARCHAR(20),
            @c_Userdefine01       NVARCHAR(30),
            @c_GetUserdefine01Det NVARCHAR(30),
            @c_Userdefine02Det    NVARCHAR(30),
            @c_Loadkey            NVARCHAR(10)

   DECLARE  @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        datetime,
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @c_Lottable11        NVARCHAR(30)='',
            @c_Lottable12        NVARCHAR(30)='',
            @d_Lottable13        DATETIME,
            @d_Lottable14        DATETIME,
            @d_Lottable15        DATETIME,
            @d_Lottable05        datetime


   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_FoundReceiptKey   NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @n_QtyReceived       INT,
            @b_debug             NVARCHAR(1)

   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @n_starttcnt         int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT, @b_debug = '0'

   --BEGIN TRAN

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SELECT TOP 1
            @c_ExternReceiptKey   = ORDERS.Loadkey,
            @c_ToFacility         = 'VSZTO',
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
            @c_Carrierkey         = 'Maersk',
            @c_CarrierName        = ORDERS.consigneekey,
            @c_Loadkey            = ORDERS.Loadkey,
            @c_Type               = 'ZTO',
            @c_Userdefine01       = ORDERS.Facility
     FROM  ORDERS WITH (NOLOCK)
     JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
     WHERE ORDERS.OrderKey = @c_OrderKey

     IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
       BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63490
       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                        ' (ispPopulateTOASN_MAST)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
       END



      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
         BEGIN
             SET @c_FoundReceiptKey = ''

             SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
             FROM RECEIPT(NOLOCK)
             WHERE Externreceiptkey = @c_ExternReceiptKey
             AND storerkey = @c_ToStorerKey
             AND Rectype = @c_Type
             AND Facility = @c_ToFacility
             AND Doctype = 'A'
       --    AND POKey = @c_Loadkey
             AND CarrierKey = @c_Carrierkey
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey,ReceiptGroup, RecType, Facility, DocType, CarrierKey, POKey,
                                       Userdefine01, CarrierName )
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_ToStorerKey, @c_Type, @c_Type, @c_ToFacility, 'A', @c_Carrierkey, '',
                          @c_Userdefine01, @c_CarrierName)

                      SET @n_err = @@Error
                 IF @n_err <> 0
                 BEGIN
                     SET @n_continue = 3
                    SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                       SET @n_err = 63498
                       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_MAST)' + ' ( ' +
                                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                 END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                      SET @n_err = 63499
                      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_MAST)'
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 63500
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_MAST)' + ' ( ' +
                         ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         END
      END -- if continue = 1 or 2

         IF EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL (NOLOCK) WHERE ExternReceiptKey = @c_ExternReceiptkey)
         BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 63502
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExternReceiptKey: ' + RTRIM(@c_ExternReceiptkey) + ' exists in Receiptdetail table. (ispPopulateTOASN_MAST)' + ' ( ' +
                                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @n_LineNo = 1


         IF ISNULL(@c_FoundReceiptKey,'') <> ''
         BEGIN
             SELECT @n_LineNo = CONVERT(INT,MAX(ReceiptLineNumber)) + 1
             FROM RECEIPTDETAIL (NOLOCK)
             WHERE Receiptkey = @c_FoundReceiptKey

             IF ISNULL(@n_LineNo,0) = 0
                SET @n_LineNo = 1
         END

          IF ISNULL(RTRIM(@c_OrderKey),'') <> ''
          BEGIN
               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR
                SELECT PICKDETAIL.SKU,
                        ORDERDETAIL.PackKey,
                        ORDERDETAIL.UOM,
                        '', --ExternLineNo
                       -- SKU.AltSku,
                        LOTATTRIBUTE.Lottable01, 
                        LOTATTRIBUTE.Lottable02,
                        LOTATTRIBUTE.Lottable03,                                 
                        LOTATTRIBUTE.Lottable04,
                        LOTATTRIBUTE.Lottable06,
                        LOTATTRIBUTE.Lottable07,
                        LOTATTRIBUTE.Lottable08,
                        LOTATTRIBUTE.Lottable09,
                        LOTATTRIBUTE.Lottable10,
                        LOTATTRIBUTE.Lottable13, 
                        LOTATTRIBUTE.Lottable14,
                        LOTATTRIBUTE.Lottable15,
                        LOTATTRIBUTE.Lottable05,
                        PICKDETAIL.Dropid, 
                        SUBSTRING(ISNULL(C.udf04,''),1,10),
                        PICKDETAIL.lot,
                       SUM(PICKDETAIL.Qty) AS Qty
                FROM ORDERDETAIL WITH (NOLOCK)
                 JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
                 JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
                 JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey
                                             AND PICKDETAIL.Orderlinenumber = ORDERDETAIL.Orderlinenumber
                JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = PICKDETAIL.LOT AND LOTATTRIBUTE.SKU = PICKDETAIL.SKU
                                                AND LOTATTRIBUTE.Storerkey = PICKDETAIL.Storerkey
                JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME ='VSFAC' AND C.short = 'VSZTO'
                 WHERE ( PICKDETAIL.Qty > 0 ) AND
                       ( ORDERDETAIL.OrderKey = @c_orderkey )
                 GROUP BY PICKDETAIL.SKU,
                          ORDERDETAIL.PackKey,
                          ORDERDETAIL.UOM,
                        --  SKU.AltSku,
                          LOTATTRIBUTE.Lottable01,
                          LOTATTRIBUTE.Lottable02,
                          LOTATTRIBUTE.Lottable03,                        
                          LOTATTRIBUTE.Lottable04,
                          LOTATTRIBUTE.Lottable06,
                          LOTATTRIBUTE.Lottable07,
                          LOTATTRIBUTE.Lottable08,
                          LOTATTRIBUTE.Lottable09,
                          LOTATTRIBUTE.Lottable10,
                          LOTATTRIBUTE.Lottable13,
                          LOTATTRIBUTE.Lottable14,
                          LOTATTRIBUTE.Lottable15,
                          LOTATTRIBUTE.Lottable05,
                          PICKDETAIL.Dropid,
                          SUBSTRING(ISNULL(C.udf04,''),1,10),
                          PICKDETAIL.lot
                 ORDER BY PICKDETAIL.Sku

                OPEN PICK_CUR

                FETCH NEXT FROM PICK_CUR INTO @c_SKU,@c_PackKey,@c_UOM,@c_ExternOrderLine,--@c_ALTSKU,
                                              @c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@c_Lottable06,
                                              @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@d_Lottable13,
                                              @d_Lottable14,@d_Lottable15,@d_Lottable05,@c_dropid,@c_toloc,@c_tolot,
                                              @n_QtyReceived

                WHILE @@FETCH_STATUS <> -1
                BEGIN
                   SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

                   SELECT @c_ExternOrderLine = @c_ReceiptLine

                    IF @n_QtyReceived IS NULL
                      SELECT @n_QtyReceived = 0

                    IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku AND ACTIVE='1' )
                    BEGIN
                    SET @n_continue = 3
                    SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                       SET @n_err = 63501
                       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_MAST)' + ' ( ' +
                                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                    END




                   INSERT INTO RECEIPTDETAIL (ReceiptKey,              ReceiptLineNumber,   ExternReceiptkey,
                                              ExternLineNo,            StorerKey,           SKU,
                                              QtyExpected,             Tolot,               UserDefine01, 
                                              UOM,                     PackKey,              ToLoc,                lottable01,
                                              Lottable02,              Lottable03,           Lottable04,           Lottable05,
                                              Lottable06,              Lottable07,           Lottable08,           Lottable09,   
                                              Lottable10,              Lottable11,           Lottable12,           Lottable13,
                                              Lottable14,              Lottable15,           BeforeReceivedQty,    FinalizeFlag )
                               VALUES        (@c_NewReceiptKey,        @c_ReceiptLine,       @c_ExternReceiptkey,
                                              @c_ExternOrderLine,      @c_ToStorerKey,       @c_SKU,
                                              @n_QtyReceived,          @c_ToLot,             @c_dropid,   
                                              @c_UOM,                  @c_Packkey,           @c_Toloc,             @c_Lottable01,
                                              @c_Lottable02,           @c_Lottable03,        @d_Lottable04,        @d_Lottable05,
                                              @c_Lottable06,           @c_Lottable07,        @c_Lottable08,        @c_Lottable09,
                                              @c_Lottable10,           @c_Lottable11,        @c_Lottable12,        @d_Lottable13,
                                              @d_Lottable14,           @d_Lottable15,        @n_QtyReceived,       'N' )

                   SELECT @n_LineNo = @n_LineNo + 1

                       FETCH NEXT FROM PICK_CUR INTO @c_SKU,@c_PackKey,@c_UOM,@c_ExternOrderLine,--@c_ALTSKU,
                                              @c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@c_Lottable06,
                                              @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@d_Lottable13,
                                              @d_Lottable14,@d_Lottable15,@d_Lottable05,@c_dropid,@c_toloc,@c_tolot,
                                              @n_QtyReceived
                END -- WHILE @@FETCH_STATUS <> -1
                CLOSE PICK_CUR
                DEALLOCATE PICK_CUR
          END
     END
   --Finalize
          EXEC dbo.ispFinalizeReceipt      
               @c_ReceiptKey        = @c_NewReceiptKey      
              ,@b_Success           = @b_Success  OUTPUT      
              ,@n_err               = @n_err     OUTPUT      
              ,@c_ErrMsg            = @c_ErrMsg    OUTPUT       
                                   
         IF @b_Success <> 1      
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg='ASN Finalize Error (ispPopulateTOASN_MAST): ' +  RTRIM(ISNULL(@c_errmsg,'')) 
         END       

       QUIT_SP:

       IF @n_continue = 3  -- Error Occured - Process And Return
       BEGIN
         SELECT @b_success = 0

         --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         --BEGIN
            --ROLLBACK TRAN
         --END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_MAST'
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