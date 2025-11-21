SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspInsertIntoASNForCTO                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 03-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nspInsertIntoASNForCTO]
      @c_orderkey    NVARCHAR(10)  ,
      @n_err         int OUTPUT,
      @c_errmsg      NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue    int,
            @n_starttcnt   int,     -- Holds the current transaction count
            @b_success     int

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg=""
   IF NOT EXISTS( SELECT 1 FROM ORDERS(NOLOCK) WHERE OrderKey = @c_orderkey and status = '9' and type = 'CTO')
   BEGIN
      RETURN
   END

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      -- Upon Shipped for Order Type 'CTO', create a new ASN document with Receipt type of 'CT' - Consignee Transfer.
      DECLARE @c_receiptkey NVARCHAR(10)

      -- Insert Receipt Header
      EXECUTE nspg_getkey
            "Receipt",
            10,
            @c_receiptkey OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 99901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get ReceiptKey (ntrOrderHeaderUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE
      BEGIN
         BEGIN TRAN
         -- insert header.
         INSERT INTO RECEIPT (
               ReceiptKey,
               Externreceiptkey,
               StorerKey,
               ReceiptDate,
               RECType,
               Status )
         SELECT @c_receiptkey,
               ORDERS.ExternOrderkey,
               ORDERS.StorerKey,
               DATEADD(day, 1, ORDERS.EditDate),
               'CT',
               '0'
         FROM   ORDERS(NOLOCK)
         WHERE   ORDERS.OrderKey = @c_orderkey

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 99902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Fail to insert into ASN Header (ntrOrderHeaderUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT ORDERDETAIL.OrderKey,
                  ORDERDETAIL.OrderLineNumber,
                  ORDERDETAIL.Storerkey,
                  ORDERDETAIL.SKU,
                  ORDERDETAIL.Packkey,
                  ORDERDETAIL.UOM,
                  SUM(PICKDETAIL.QTY) ShippedQty,
                  PICKDETAIL.LOT,
                  LOTATTRIBUTE.Lottable01,
                  LOTATTRIBUTE.Lottable02,
                  LOTATTRIBUTE.Lottable03,
                  LOTATTRIBUTE.Lottable04,
                  LOTATTRIBUTE.Lottable06,
                  LOTATTRIBUTE.Lottable07,
                  LOTATTRIBUTE.Lottable08,
                  LOTATTRIBUTE.Lottable09,
                  LOTATTRIBUTE.Lottable10,
                  LOTATTRIBUTE.Lottable11,
                  LOTATTRIBUTE.Lottable12,
                  LOTATTRIBUTE.Lottable13,
                  LOTATTRIBUTE.Lottable14,
                  LOTATTRIBUTE.Lottable15
            INTO   #cto_shippedorderdetail
            FROM    ORDERDETAIL(NOLOCK), PICKDETAIL(NOLOCK), LOTATTRIBUTE(NOLOCK)
            WHERE   ORDERDETAIL.Orderkey = @c_orderkey
            AND   ORDERDETAIL.OrderKey = PICKDETAIL.Orderkey
            AND   ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
            AND   PICKDETAIL.LOT = LOTATTRIBUTE.LOT
            GROUP BY ORDERDETAIL.OrderKey
                  ,ORDERDETAIL.OrderLineNumber
                  ,ORDERDETAIL.Storerkey
                  ,ORDERDETAIL.SKU
                  ,ORDERDETAIL.Packkey
                  ,ORDERDETAIL.UOM
                  ,PICKDETAIL.LOT
                  ,LOTATTRIBUTE.Lottable01
                  ,LOTATTRIBUTE.Lottable02
                  ,LOTATTRIBUTE.Lottable03
                  ,LOTATTRIBUTE.Lottable04
                  ,LOTATTRIBUTE.Lottable06
                  ,LOTATTRIBUTE.Lottable07
                  ,LOTATTRIBUTE.Lottable08
                  ,LOTATTRIBUTE.Lottable09
                  ,LOTATTRIBUTE.Lottable10
                  ,LOTATTRIBUTE.Lottable11
                  ,LOTATTRIBUTE.Lottable12
                  ,LOTATTRIBUTE.Lottable13
                  ,LOTATTRIBUTE.Lottable14
                  ,LOTATTRIBUTE.Lottable15
            ORDER BY ORDERDETAIL.OrderKey,
                  ORDERDETAIL.OrderLineNumber,
                  PICKDETAIL.LOT

            DECLARE  @c_ctoorderkey          NVARCHAR(10),
                     @c_ctoorderlinenumber   NVARCHAR(5),
                     @c_ctolot               NVARCHAR(10),
                     @n_receiptlinenumber    int,
                     @c_receiptlinenumber    NVARCHAR(5)

            SELECT @n_receiptlinenumber = 0
            WHILE EXISTS( SELECT * FROM #cto_shippedorderdetail )
            BEGIN
               SET ROWCOUNT 1
               -- For the first time.
               SELECT @c_ctoorderkey = orderkey,
                     @c_ctoorderlinenumber = orderlinenumber,
                     @c_ctolot = lot
               FROM   #cto_shippedorderdetail
               SET ROWCOUNT 0

               SELECT @n_receiptlinenumber = @n_receiptlinenumber + 1
               SELECT @c_receiptlinenumber = CONVERT(CHAR(5), @n_receiptlinenumber)
               SELECT @c_receiptlinenumber = REPLICATE('0', 5-LEN(@c_receiptlinenumber)) + @c_receiptlinenumber

               INSERT INTO RECEIPTDETAIL (
                     Receiptkey,
                     ReceiptLineNumber,
                     Storerkey,
                     SKU,
                     Packkey,
                     UOM,
                     QtyExpected,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable04,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12,
                     Lottable13,
                     Lottable14,
                     Lottable15,
                     ToLoc,
                     TrafficCop )
               SELECT @c_receiptkey,
                     @c_receiptlinenumber,
                     cto.Storerkey,
                     cto.SKU,
                     cto.Packkey,
                     cto.UOM,
                     cto.shippedqty,
                     cto.Lottable01,
                     cto.Lottable02,
                     cto.Lottable03,
                     cto.Lottable04,
                     cto.Lottable06,
                     cto.Lottable07,
                     cto.Lottable08,
                     cto.Lottable09,
                     cto.Lottable10,
                     cto.Lottable11,
                     cto.Lottable12,
                     cto.Lottable13,
                     cto.Lottable14,
                     cto.Lottable15,
                     '',
                     NULL
               FROM  #cto_shippedorderdetail cto
               WHERE cto.orderkey = @c_ctoorderkey
               AND   cto.orderlinenumber = @c_ctoorderlinenumber
               AND   cto.lot = @c_ctolot

               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 99903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Fail to insert into ASN Detail (ntrOrderHeaderUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  DELETE FROM #cto_shippedorderdetail
                  BREAK
               END
               ELSE
               BEGIN
                  DELETE FROM #cto_shippedorderdetail
                  WHERE orderkey = @c_ctoorderkey
                  AND   orderlinenumber = @c_ctoorderlinenumber
                  AND   lot = @c_ctolot
               END
            END -- WHILE
         END -- Insert into ASN detail
      END -- Insert into ASN Header & Detail
   END -- IF Order Shipped (CTO type)
   -- END FBR046 IDSHK

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, "nspInsertIntoASNForCTO"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO