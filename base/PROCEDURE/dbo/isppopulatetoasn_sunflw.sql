SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispPopulateTOASN_SUNFLW                                          */
/* Creation Date: 02-Oct-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Auto Create ASN for Sunflower Orders  SOS#257749            */
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
/* 30-Apr-2013  Leong     1.1   SOS# 276517 - Revise logic.             */
/* 27-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_SUNFLW]
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
           @c_NewPackKey         NVARCHAR(10),
           @c_UOM                NVARCHAR(5),
           @c_NewUOM             NVARCHAR(5),
           @c_SKUDescr           NVARCHAR(60),
           @c_StorerKey          NVARCHAR(15),
           @c_ToStorerKey        NVARCHAR(15),
           @c_OrderLine          NVARCHAR(5),
           @c_ToFacility         NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
           @c_ID                 NVARCHAR(18),
           @c_ToLoc              NVARCHAR(10),
           @c_Type               NVARCHAR(10),
           @c_consigneekey       NVARCHAR(15),
           @c_Strategykey        NVARCHAR(10),
           @c_RetailSku          NVARCHAR(20),
           @c_ALTSku             NVARCHAR(20),
           @c_ManufacturerSku    NVARCHAR(20),
           @n_StdNetWgt          FLOAT,
           @n_StdCube            FLOAT,
           @c_SkuGroup           NVARCHAR(10),
           @n_Price              MONEY,
           @c_Style              NVARCHAR(20),
           @c_Color              NVARCHAR(10),
           @c_Size               NVARCHAR(5),
           @c_Lottable05Label    NVARCHAR(20),
           @c_OWITF_Config       NVARCHAR(10),
           @c_BillTokey          NVARCHAR(15)

   DECLARE @c_Lottable01         NVARCHAR(18),
           @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18),
           @d_Lottable04         DATETIME,
           @d_Lottable05         DATETIME,
           @n_ShippedQty         INT,
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
           @c_Lot                NVARCHAR(10)


   DECLARE @c_NewReceiptKey      NVARCHAR(10),
           @c_ReceiptLine        NVARCHAR(5),
           @n_LineNo             INT,
           @n_QtyReceived        INT
          , @n_TotShippedQty     INT -- SOS# 276517
          , @n_TotQtyReceived    INT -- SOS# 276517

   DECLARE @n_starttcnt          INT

   DECLARE @n_continue           INT,
           @b_success            INT,
           @n_err                INT,
           @c_errmsg             NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT

   --BEGIN TRAN

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      SET @c_id = ''

      SELECT TOP 1 @c_ExternReceiptKey = CASE WHEN ISNULL(STORER.Susr5,'') = '1' THEN
                                             ISNULL(ORDERS.Buyerpo,'')
                                          ELSE
                                             LEFT(ISNULL(ORDERS.ExternOrderkey,''),20) END, --NJOW01
                  @c_Type               = ORDERS.Type,
                  @c_ToFacility         = ISNULL(STORER.Susr4,''),
                  @c_ToStorerkey        = ISNULL(STORER.Susr2,''),
                  @c_Storerkey          = ORDERS.Storerkey,
                  @c_Consigneekey       = ORDERS.Consigneekey,
                  @c_ToLoc              = ISNULL(FACILITY.UserDefine04,''),
                  @c_Strategykey        = ISNULL(STORER.Susr3,''),
                  @c_OWITF_Config       = ISNULL(STORERCONFIG.Svalue,''),
                  @c_BillToKey          = ORDERS.BillToKey,
                  @c_NewPackkey         = ISNULL(STORER.Susr1,'')
     FROM  ORDERS WITH (NOLOCK)
     JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
     LEFT JOIN FACILITY WITH (NOLOCK) ON STORER.Susr4 = FACILITY.Facility
     LEFT JOIN STORERCONFIG WITH (NOLOCK) ON ORDERS.Storerkey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = 'OWITF'
     WHERE ORDERS.OrderKey = @c_OrderKey

     IF NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'LFA2LFK' AND Code = @c_BillToKey)
     BEGIN
          GOTO QUIT_SP
     END

      IF @c_OWITF_Config <> '1'
      BEGIN
          GOTO QUIT_SP
      END

      IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63490
         SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err) + ': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                         '. OrderKey = ' + RTRIM(ISNULL(@c_OrderKey,'')) + '. (ispPopulateTOASN_SUNFLW)'
      END

      IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63495
         SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid To Loc: ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                         '. OrderKey = ' + RTRIM(ISNULL(@c_OrderKey,'')) + '. (ispPopulateTOASN_SUNFLW)'
      END

      IF NOT EXISTS ( SELECT 1 FROM STRATEGY WITH (NOLOCK) WHERE StrategyKey = @c_StrategyKey)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63497
         SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Strategy: ' + RTRIM(ISNULL(@c_StrategyKey,'')) +
                         '. OrderKey = ' + RTRIM(ISNULL(@c_OrderKey,'')) + '. (ispPopulateTOASN_SUNFLW)'
      END

      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63500
         SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                         '. OrderKey = ' + RTRIM(ISNULL(@c_OrderKey,'')) + '. (ispPopulateTOASN_SUNFLW)'
      END

      IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE ExternReceiptkey = @c_ExternReceiptkey AND Storerkey = @c_ToStorerkey) AND @c_ExternReceiptkey <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63501
         SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': ASN ExternReceiptkey Already Exist In System: ' + RTRIM(ISNULL(@c_ExternReceiptkey,'')) +
                         '. ToStorerkey = ' + RTRIM(ISNULL(@c_ToStorerkey,'')) + ', OrderKey = ' + RTRIM(ISNULL(@c_OrderKey,'')) + ' (ispPopulateTOASN_SUNFLW)'
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
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
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey, RecType, Facility, DocType, RoutingTool, UserDefine02)
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_ToStorerKey, @c_Type, @c_ToFacility, 'A', 'N', @c_Consigneekey)

               SET @n_err = @@Error
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63481
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_SUNFLW)' + ' ( ' +
                             ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63502
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_SUNFLW)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63503
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': To StorerKey is BLANK! (ispPopulateTOASN_SUNFLW)' + ' ( ' +
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

            SELECT @c_SKU              = SKU.SKU,
                   @c_PackKey          = ORDERDETAIL.PackKey,
                   @c_UOM              = ORDERDETAIL.UOM,
                   @n_ShippedQty       = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                   @c_SKUDescr         = SKU.DESCR,
                   @c_OrderLine        = ORDERDETAIL.OrderLineNumber,
                   @c_ExternOrderLine  = ISNULL(ORDERDETAIL.ExternLineNo,''),
                   @c_RetailSku        = SKU.RetailSku,
                   @c_ALTSku           = SKU.ALTSku,
                   @c_ManufacturerSku  = SKU.Manufacturersku,
                   @n_StdNetWgt        = SKU.StdNetWgt,
                   @n_StdCube          = SKU.StdCube,
                   @c_SkuGroup         = SKU.SkuGroup,
                   @n_Price            = SKU.Price,
                   @c_Style            = SKU.Style,
                   @c_Color            = SKU.Color,
                   @c_Size             = SKU.Size,
                   @c_Lottable05Label  = SKU.Lottable05Label
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
               IF ISNULL(RTRIM(@c_NewPackkey),'') <> ''
               BEGIN
                  SELECT @c_NewUOM = PackUOM3
                  FROM PACK WITH (NOLOCK)
                  WHERE Packkey = @c_NewPackkey

                  IF ISNULL(RTRIM(@c_NewUOM),'') <> ''
                  BEGIN
                     SET @c_Packkey = @c_NewPackkey
                     SET @c_UOM = @c_NewUOM
                  END
               END

               INSERT INTO SKU (Storerkey, SKU, Descr, ManufacturerSku, RetailSku, ALTSku, PackKey, StdNetWgt,
                                StdCube, SkuGroup, Price, Style, Color, Size, Strategykey, Lottable05Label)
                        VALUES (@c_ToStorerkey, @c_Sku, @c_SkuDescr, @c_ManufacturerSku, @c_RetailSku, @c_ALTSku, @c_PackKey, @n_StdNetWgt,
                                @n_StdCube, @c_SkuGroup, @n_Price, @c_Style, @c_Color, @c_Size, @c_StrategyKey, @c_Lottable05Label)

               SET @n_err = @@Error

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63491
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Sku (ispPopulateTOASN_SUNFLW)' + ' ( ' +
                             ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND
                   ISNULL(RTRIM(@c_OrderLine),'') <> ''
               BEGIN
                  DECLARE PICK_CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty
                        --ISNULL(LOTATTRIBUTE.Lottable01,''),
                        --ISNULL(LOTATTRIBUTE.Lottable02,''),
                        --ISNULL(LOTATTRIBUTE.Lottable03,''),
                        --LOTATTRIBUTE.Lottable04,
                        --LOTATTRIBUTE.Lottable05,
                        --PICKDETAIL.Lot,
                        --PICKDETAIL.Loc,
                        --PICKDETAIL.Id
                  FROM PICKDETAIL   WITH (NOLOCK)
                  JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                  WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                         PICKDETAIL.OrderLineNumber = @c_OrderLine)
                  GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU--, LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02,
                           --LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                           --PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.Id

                  OPEN PICK_CUR

                  FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived--, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lot, @c_ToLoc, @c_id

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

                     IF @n_QtyReceived IS NULL
                        SELECT @n_QtyReceived = 0

                     INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,
                                                ExternLineNo,        StorerKey,           SKU,
                                                QtyExpected,         QtyReceived,
                                                UOM,                 PackKey,             ToLoc,
                                                --Lottable01,        Lottable02,
                                                --Lottable03,        Lottable04,          Lottable05,
                                                --ToID,              ToLot,
                                                Lottable03,          BeforeReceivedQty,   FinalizeFlag)
                                 VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptkey,
                                                @c_ExternOrderLine,  @c_ToStorerKey,      @c_SKU,
                                                @n_QtyReceived,      @n_QtyReceived,
                                                @c_UOM,              @c_Packkey,          @c_Toloc,
                                                --@c_Lottable01,     @c_Lottable02,
                                                --@c_Lottable03,     @d_Lottable04,       @d_Lottable05,
                                                --@c_id,             @c_Lot,
                                                @c_ExternReceiptkey, @n_QtyReceived,      'Y')


                     SELECT @n_LineNo = @n_LineNo + 1

                     FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived--, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lot, @c_ToLoc, @c_id
                  END -- WHILE @@FETCH_STATUS <> -1
                  CLOSE PICK_CUR
                  DEALLOCATE PICK_CUR
               END
            END
         END --while
      END
      SET ROWCOUNT 0

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         -- SOS# 276517
         SET @n_TotShippedQty  = 0
         SET @n_TotQtyReceived = 0

         SELECT @n_TotShippedQty = SUM(Qty)
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey

         SELECT @n_TotQtyReceived = SUM(QtyReceived)
         FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @c_NewReceiptKey

         IF ISNULL(@n_TotShippedQty, 0) = ISNULL(@n_TotQtyReceived, 0)
         BEGIN
            UPDATE RECEIPT WITH (ROWLOCK)
            SET ASNStatus = '9',
               Status    = '9'
            WHERE ReceiptKey = @c_NewReceiptKey

            SET @n_err = @@Error

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63492
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_SUNFLW)' + ' ( ' +
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            END
         END
      END -- if continue = 1 or 2

      QUIT_SP:

      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0

         --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         --BEGIN
            --ROLLBACK TRAN
         --END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_SUNFLW'
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