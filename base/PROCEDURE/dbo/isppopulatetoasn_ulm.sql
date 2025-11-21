SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: ispPopulateTOASN_ULM                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: KC                                                       */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS (Auto ASN for COPACK)       */
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
/* Date         Author    Ver.  Purposes                                */
/* 09-Nov-2009  Leong     1.1   SOS#152909 - Check OrderLineNumber      */
/*                                           instead of ExternLineNo    */
/* 27-May-2014  TKLIM     1.2   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_ULM]
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON         -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_ExternReceiptKey NVARCHAR(20),
           @c_SKU              NVARCHAR(20),
           @c_PackKey          NVARCHAR(10),
           @c_UOM              NVARCHAR(5),
           @c_SKUDescr         NVARCHAR(60),
           @c_StorerKey        NVARCHAR(15),
           @c_RecType          NVARCHAR(10),
           @c_Listname         NVARCHAR(10),
           @c_OrderLine        NVARCHAR(5),
           @c_Facility         NVARCHAR(5),
           @c_ExternOrderLine  NVARCHAR(10)

   DECLARE @c_Lottable01       NVARCHAR(18),
           @c_Lottable02       NVARCHAR(18),
           @c_Lottable03       NVARCHAR(18),
           @d_Lottable04       DATETIME,
           @d_Lottable05       DATETIME,
           @c_Lottable06       NVARCHAR(30), 
           @c_Lottable07       NVARCHAR(30), 
           @c_Lottable08       NVARCHAR(30), 
           @c_Lottable09       NVARCHAR(30), 
           @c_Lottable10       NVARCHAR(30), 
           @c_Lottable11       NVARCHAR(30), 
           @c_Lottable12       NVARCHAR(30), 
           @d_Lottable13       DATETIME,     
           @d_Lottable14       DATETIME,     
           @d_Lottable15       DATETIME

   DECLARE @c_NewReceiptKey    NVARCHAR(10),
           @c_ReceiptLine      NVARCHAR(5),
           @n_LineNo           int,
           @c_CarrierKey       NVARCHAR(15),
           @c_CarrierName      NVARCHAR(30),
           @c_CarrierAddress1  NVARCHAR(45),
           @c_CarrierAddress2  NVARCHAR(45),
           @c_CarrierCity      NVARCHAR(45),
           @c_CarrierState     NVARCHAR(2),
           @c_CarrierZip       NVARCHAR(10),
           @n_QtyReceived      int

   DECLARE @n_continue         int,
           @b_success          int,
           @n_err              int,
           @c_errmsg           NVARCHAR(255),
           @n_starttcnt        int,
           @n_check            int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT
   -- set constant values
   SET @c_RecType = 'IntFacWhs'
   SET @c_Listname = 'RECTYPE'

   -- ensure RecType has been setup
   SELECT @n_Check = Count(1) FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = ISNULL(RTRIM(@c_Listname), '')
   AND Code = ISNULL(RTRIM(@c_RecType), '')

   IF @n_Check <> 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+ ': CODELKUP Setup not exists(For Type). Listname:' + ISNULL(RTRIM(@c_Listname), '')
                     + ', Code:' + ISNULL(RTRIM(@c_RecType), '') + ' (ispPopulateTOASN_ULM)'  + ' ( '
                     + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO QUIT_SP
   END

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN

      SELECT @c_StorerKey        = ISNULL(RTRIM(ORDERS.Storerkey),''),
             @c_ExternReceiptKey = ISNULL(RTRIM(ORDERS.ExternOrderkey),''),
             @c_Facility         = ISNULL(RTRIM(STORER.Facility),''),
             @c_CarrierKey       = ISNULL(RTRIM(ORDERS.ConsigneeKey),''),
             @c_CarrierName      = ISNULL(RTRIM(STORER.Company),''),
             @c_CarrierAddress1  = ISNULL(RTRIM(STORER.Address1),''),
             @c_CarrierAddress2  = ISNULL(RTRIM(STORER.Address2),''),
             @c_CarrierCity      = ISNULL(RTRIM(STORER.City),''),
             @c_CarrierState     = ISNULL(RTRIM(STORER.State),''),
             @c_CarrierZip       = ISNULL(RTRIM(STORER.Zip),'')
      FROM   ORDERS      WITH (NOLOCK)
      JOIN   MBOL        WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN   STORER      WITH (NOLOCK) ON (STORER.Storerkey = ORDERS.Consigneekey)
      WHERE  ORDERS.OrderKey = @c_OrderKey

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_CarrierKey),'') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CarrierKey is blank (ispPopulateTOASN_ULM)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         IF ISNULL(RTRIM(@c_Facility),'') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63503
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility is blank (ispPopulateTOASN_ULM)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF ISNULL(RTRIM(@c_StorerKey),'') <> ''
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey, RecType, Facility, DocType, Carrierkey,
                                       CarrierName, CarrierAddress1, CarrierAddress2, CarrierCity, CarrierState, CarrierZip)
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, @c_RecType , @c_Facility, 'A', @c_CarrierKey,
                          @c_CarrierName, @c_CarrierAddress1, @c_CarrierAddress2, @c_CarrierCity, @c_CarrierState, @c_CarrierZip)
               END
               ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_ULM)' + ' ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO QUIT_SP
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63506
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_ULM)' + ' ( ' +
                                ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END -- if continue = 1 or 2
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
         SELECT @c_ExternOrderLine = SPACE(5)


         WHILE 1=1
         BEGIN
            SET ROWCOUNT 1

            SELECT @c_SKU             = ORDERDETAIL.Sku,
                   @c_PackKey         = ORDERDETAIL.PackKey,
                   @c_UOM             = ORDERDETAIL.UOM,
                   @c_SKUDescr        = SKU.DESCR,
                   @c_OrderLine       = ORDERDETAIL.OrderLineNumber,
                   @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,'')
             FROM ORDERDETAIL WITH (NOLOCK)
                  JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
                  JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku )
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND
                  ( ORDERDETAIL.OrderKey = @c_orderkey ) AND
                --( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )  -- SOS#152909
          --ORDER by ORDERDETAIL.ExternLineNo
                  ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )      -- SOS#152909
            ORDER by ORDERDETAIL.OrderLineNumber

            IF @@ROWCOUNT = 0
               BREAK

            SET ROWCOUNT 0
            IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND ISNULL(RTRIM(@c_OrderLine), '') <> ''
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
                     LOTATTRIBUTE.Lottable15
               FROM PICKDETAIL   WITH (NOLOCK)
               JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
               WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                      PICKDETAIL.OrderLineNumber = @c_OrderLine)
               GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                        LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                        LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                        LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15

               OPEN PICK_CUR

               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)


                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0

                  INSERT INTO RECEIPTDETAIL (ReceiptKey,                ReceiptLineNumber,   ExternReceiptkey,
                                             ExternLineNo,              StorerKey,           SKU,
                                             QtyExpected,               QtyReceived,         ToLoc,
                                             UOM,                       PackKey,
                                             Lottable01,                Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                             Lottable06,                Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                             Lottable11,                Lottable12,          Lottable13,       Lottable14,       Lottable15)

                              VALUES        (@c_NewReceiptKey,          @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_ExternOrderLine,        @c_StorerKey,        @c_SKU,
                                             ISNULL(@n_QtyReceived,0),  0,                         '',
                                             @c_UOM,                    @c_Packkey,
                                             @c_Lottable01,             @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05,
                                             @c_Lottable06,             @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                             @c_Lottable11,             @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15)

                  SELECT @n_LineNo = @n_LineNo + 1

                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
            END
         END   -- WHILE
      END 
      SET ROWCOUNT 0

      QUIT_SP:

      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN

         SELECT @b_success = 0

         IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         BEGIN

            ROLLBACK TRAN
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_ULM'
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

-- end procedure

GO