SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateTOASN_NIKTOMOT                                          */
/* Creation Date: 07-Feb-2022                                             */
/* Copyright: LFL                                                         */
/* Written by: WLChooi                                                    */
/*                                                                        */
/* Purpose: WMS-18842 -  Auto Create ASN From Orders When MBOL Ship       */
/*          Storer NIK to MOT                                             */
/*                                                                        */
/* Input Parameters: Orderkey                                             */
/*                                                                        */
/* Output Parameters: NONE                                                */
/*                                                                        */
/* Return Status: NONE                                                    */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Local Variables:                                                       */
/*                                                                        */
/*                                                                        */
/* Called By: ntrMBOLHeaderUpdate                                         */
/*                                                                        */
/* GitLab Version: 1.0                                                    */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author  Ver. Purposes                                     */
/* 07-Feb-2022  WLChooi 1.0  DevOps Combine Script                        */
/* 01-Sep-2022  WyeChun 1.1  JSM-89774 Remove remark (WC01)               */
/**************************************************************************/
CREATE   PROCEDURE [dbo].[ispPopulateTOASN_NIKTOMOT]
   @c_Orderkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @c_ExternReceiptKey   NVARCHAR(20),
             @c_SKU                NVARCHAR(20),
             @c_PackKey            NVARCHAR(10),
             @c_UOM                NVARCHAR(5),
             @c_StorerKey          NVARCHAR(15),
             @c_ToStorerKey        NVARCHAR(15),
             @c_OrderLine          NVARCHAR(5),
             @c_ToFacility         NVARCHAR(5),
             @c_ExternOrderLine    NVARCHAR(20),
             @c_Pickheaderkey      NVARCHAR(10),
             @c_ToLoc              NVARCHAR(10),
             @c_Type               NVARCHAR(20),
             @c_WarehouseReference NVARCHAR(18),
             @c_Pickdetailkey      NVARCHAR(10),
             @c_DocType            NVARCHAR(1),
             @c_CustomSQL          NVARCHAR(4000)

   DECLARE  @c_Lottable01         NVARCHAR(18),
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
            @d_Lottable15         DATETIME

   DECLARE  @c_NewReceiptKey      NVARCHAR(10),
            @c_FoundReceiptKey    NVARCHAR(10),
            @c_ReceiptLine        NVARCHAR(5),
            @n_LineNo             INT,
            @n_QtyReceived        INT,
            @n_QtyExpected        INT,
            @n_ShippedQty         INT,
            @n_BeforeReceivedQty  INT,
            @c_FinalizeFlag       NCHAR(1),
            @c_SUSR4              NVARCHAR(20),
            @c_UDF05              NVARCHAR(4000),
            @c_UDF01              NVARCHAR(50),
            @c_POKey              NVARCHAR(18),
            @c_Carrierkey         NVARCHAR(15)

   DECLARE  @n_continue           INT,
            @b_success            INT,
            @n_err                INT,
            @c_errmsg             NVARCHAR(255),
            @n_starttcnt          INT

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt = @@TRANCOUNT
   SELECT @c_Pickheaderkey = '', @c_ToLoc = '', @c_FinalizeFlag = 'N', @c_Lottable01 = '', @c_Lottable12 = ''

   BEGIN TRAN       

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
         SELECT TOP 1
             @c_ExternReceiptKey    = ORDERS.MBOLKey,                   
             @c_WarehouseReference  = ORDERS.Orderkey,
             @c_ToStorerkey         = ISNULL(CODELKUP.UDF01,''),
             @c_Storerkey           = ORDERS.Storerkey,
             @c_DocType             = 'A',   
             @c_ToLoc               = ISNULL(CODELKUP.UDF04,''),
             @c_Type                = ISNULL(CODELKUP.SHORT,''),
             @c_UDF01               = ISNULL(ORDERS.ExternOrderKey,''),    
             @c_UDF05               = ISNULL(CODELKUP.UDF05,''),   
             @c_Carrierkey          = ORDERS.ConsigneeKey,
             @c_CustomSQL           = ISNULL(CODELKUP.Notes,'')
      FROM ORDERS WITH (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY
      JOIN CODELKUP WITH (NOLOCK) ON ORDERS.[Type] = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN'
                                 AND ORDERS.StorerKey = CODELKUP.Storerkey
      WHERE ORDERS.OrderKey = @c_Orderkey

      SELECT TOP 1 @c_ToFacility = ISNULL(LOC.Facility,'')
      FROM LOC (NOLOCK)
      WHERE LOC.Loc = @c_ToLoc
      
      SELECT @c_SUSR4 = ISNULL(ST.SUSR4,'')
      FROM STORER ST (NOLOCK)
      JOIN ORDERS ORD (NOLOCK) ON ORD.ConsigneeKey = ST.Storerkey
      WHERE ORD.OrderKey = @c_Orderkey
      
      IF (@c_SUSR4 = @c_UDF05)
      BEGIN
         SET @c_UDF05 = @c_SUSR4   --Continue
      END
      ELSE
      BEGIN
         GOTO QUIT_SP
      END
      
      --Check ToStorerkey if it exists since it is different from FromStorerkey
      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63497
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                       ' (ispPopulateTOASN_NIKTOMOT)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
         BEGIN
            SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
            FROM RECEIPT(NOLOCK)
            WHERE Externreceiptkey = @c_ExternReceiptKey
            --AND Warehousereference = @c_WarehouseReference
            AND Storerkey = @c_ToStorerKey
            AND Rectype = @c_Type
            AND Facility = @c_ToFacility
            AND Doctype = @c_DocType
            AND CarrierKey = @c_Carrierkey
            AND ISNULL(Externreceiptkey,'') <> ''
            AND ISNULL(Warehousereference,'') <> ''
            AND Status <> '9'
            
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference
                                     , StorerKey, RecType, Facility, DocType, RoutingTool
                                     , CarrierKey) 
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference
                        , @c_ToStorerKey, @c_Type, @c_ToFacility, @c_DocType, 'N'
                        , @c_Carrierkey)           

                  SET @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_NIKTOMOT)' + ' ( ' +
                                   ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '      
                     GOTO QUIT_SP
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 63499
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_NIKTOMOT)'
                               +' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '       
                  GOTO QUIT_SP
               END
            END
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 63500
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_NIKTOMOT)' + ' ( ' +
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '     
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
                   @c_PackKey    = ORDERDETAIL.PackKey,
                   @c_UOM        = ORDERDETAIL.UOM,
                   @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                   @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
                   @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),
                   @n_QtyExpected = ORDERDETAIL.ORIGINALQTY
            FROM ORDERDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
            JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
            JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND
                  ( ORDERDETAIL.OrderKey = @c_Orderkey ) AND
                       ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
            ORDER by ORDERDETAIL.OrderLineNumber

            IF @@ROWCOUNT = 0
               BREAK

            SET ROWCOUNT 0

            --Check if the SKU exists on ToStorerKey
            IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku )
            BEGIN
               --If ReportCFG is turned on, Insert SKU for ToStorerkey
               IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'REPORTCFG' AND CODE = 'InsertSKUIfNotExists' AND STORERKEY = @c_ToStorerkey
                           AND Long = 'ispPopulateTOASN_NIKTOMOT' AND Short = 'Y')
               BEGIN
                  IF ISNULL(@c_CustomSQL,'') = ''
                  BEGIN
                     SET @c_CustomSQL = ''
                  END

                  EXEC ispDuplicateSKUByStorer
                       @c_FromStorerkey     =   @c_Storerkey
                    ,  @c_ToStorerkey       =   @c_ToStorerkey 
                    ,  @c_SKU               =   @c_SKU         
                    ,  @b_Success           =   @b_Success     OUTPUT 
                    ,  @n_Err               =   @n_Err         OUTPUT 
                    ,  @c_ErrMsg            =   @c_ErrMsg      OUTPUT
                    ,  @c_CustomSQL         =   @c_CustomSQL

                  IF @b_Success <> 1
                  BEGIN
                     SET @n_continue = 3  
                     SET @n_err = 63501  
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting to SKU Table. (ispPopulateTOASN_NIKTOMOT)'   
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                     GOTO QUIT_SP  
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 63502
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_NIKTOMOT)' + ' ( ' +
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  GOTO QUIT_SP
               END
            END

            IF @n_continue = 1 OR @n_continue = 2 --Based on Pickdetail
            BEGIN
               IF ISNULL(RTRIM(@c_Orderkey),'') <> '' AND
                  ISNULL(RTRIM(@c_OrderLine),'') <> ''
               BEGIN
                  DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR
                  SELECT SUM(PICKDETAIL.Qty),
                         LOTATTRIBUTE.Lottable02,
                         LOTATTRIBUTE.Lottable03,
                         LOTATTRIBUTE.Lottable04,
                         LOTATTRIBUTE.Lottable06,
                         LOTATTRIBUTE.Lottable07,
                         LOTATTRIBUTE.Lottable08,
                         LOTATTRIBUTE.Lottable09,
                         LOTATTRIBUTE.Lottable10,
                         LOTATTRIBUTE.Lottable11,
                         LOTATTRIBUTE.Lottable13,
                         LOTATTRIBUTE.Lottable14,
                         LOTATTRIBUTE.Lottable15,
                         PICKHEADER.PickHeaderKey
                  FROM PICKDETAIL   WITH (NOLOCK)
                  JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                  JOIN PICKHEADER   WITH (NOLOCK) ON (PICKHEADER.OrderKey = PICKDETAIL.OrderKey)
                  WHERE (PICKDETAIL.OrderKey = @c_Orderkey AND PICKDETAIL.OrderLineNumber = @c_OrderLine)
                  GROUP BY PICKDETAIL.OrderKey,
                           PICKDETAIL.OrderLineNumber,
                           LOTATTRIBUTE.Lottable02,
                           LOTATTRIBUTE.Lottable03,
                           LOTATTRIBUTE.Lottable04,
                           LOTATTRIBUTE.Lottable06,
                           LOTATTRIBUTE.Lottable07,
                           LOTATTRIBUTE.Lottable08,
                           LOTATTRIBUTE.Lottable09,
                           LOTATTRIBUTE.Lottable10,
                           LOTATTRIBUTE.Lottable11,
                           LOTATTRIBUTE.Lottable13,
                           LOTATTRIBUTE.Lottable14,
                           LOTATTRIBUTE.Lottable15,
                           PICKHEADER.PickHeaderKey
                  
                  OPEN PICK_CUR
                  
                  FETCH NEXT FROM PICK_CUR INTO @n_ShippedQty, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                                @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                                                @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Pickheaderkey 
                  
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
                  
                     IF @c_FinalizeFlag = 'Y'
                     BEGIN
                        SELECT @n_QtyExpected = @n_ShippedQty
                        SELECT @n_BeforeReceivedQty = @n_ShippedQty
                        SELECT @n_QtyReceived = @n_ShippedQty
                     END
                     ELSE
                     BEGIN
                        SELECT @n_QtyExpected = @n_ShippedQty  --WC01
                        SELECT @n_BeforeReceivedQty = @n_ShippedQty
                        SELECT @n_QtyReceived = 0
                     END
                  
                     INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,      ExternReceiptkey,
                                                ExternLineNo,        StorerKey,              SKU,
                                                QtyExpected,         QtyReceived,
                                                UOM,                 PackKey,                ToLoc,
                                                Lottable01,          Lottable02,             Lottable03,
                                                Lottable04,          Lottable06,             Lottable07,
                                                Lottable08,          Lottable09,             Lottable10,
                                                Lottable11,          Lottable12,             Lottable13,
                                                Lottable14,          Lottable15,             BeforeReceivedQty,
                                                FinalizeFlag,        ToID,                   UserDefine01) 
                     VALUES   (@c_NewReceiptKey,      @c_ReceiptLine,      @c_ExternReceiptkey,
                               @c_ExternOrderLine,    @c_ToStorerKey,      @c_SKU,
                               @n_QtyExpected,        @n_QtyReceived,
                               @c_UOM,                @c_Packkey,          @c_Toloc,
                               @c_Lottable01,         '',                  @c_Lottable03,
                               @d_Lottable04,         @c_Lottable06,       @c_Lottable07,
                               @c_Lottable08,         @c_Lottable09,       @c_Lottable10,
                               @c_Lottable11,         '',                  @d_Lottable13,
                               @d_Lottable14,         @d_Lottable15,       @n_BeforeReceivedQty,
                               @c_FinalizeFlag,       @c_Pickheaderkey,    @c_UDF01) 
                  
                     SELECT @n_LineNo = @n_LineNo + 1
                  
                     SET @n_err = @@ERROR
                  
                     IF @n_err <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                        SET @n_err = 63503
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table ReceiptDetail (ispPopulateTOASN_NIKTOMOT)' + ' ( ' +
                                      ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                        GOTO QUIT_SP
                     END
                  
                     FETCH NEXT FROM PICK_CUR INTO @n_ShippedQty, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                                   @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                                                   @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Pickheaderkey
                  END -- WHILE @@FETCH_STATUS <> -1
                  CLOSE PICK_CUR
                  DEALLOCATE PICK_CUR
               END
            END
         END --while
      END
      SET ROWCOUNT 0

      IF (@n_continue = 1 OR @n_continue = 2) AND @c_FinalizeFlag = 'Y'
      BEGIN
         UPDATE RECEIPT WITH (ROWLOCK)
         SET ASNStatus = '9',
             Status    = '9'
         WHERE ReceiptKey = @c_NewReceiptKey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 63504
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_NIKTOMOT)' + ' ( ' +
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '      
            GOTO QUIT_SP
         END
      END

      WHILE @@TRANCOUNT > 0        
         COMMIT TRAN

   END -- if continue = 1 or 2 001

QUIT_SP:
   IF @@TRANCOUNT < @n_StartTCnt        
   BEGIN
      BEGIN TRAN
   END  

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
       BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPopulateTOASN_NIKTOMOT'      
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO