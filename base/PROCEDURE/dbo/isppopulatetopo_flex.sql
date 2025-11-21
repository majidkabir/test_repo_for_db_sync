SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispPopulateTOPO_FLEX                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Populate PO Detail from ORDERS (Auto PO for Flextronics)    */
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
/* 27-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/* 27-Feb-2017  TLTING    1.2   Variable Nvarchar                       */  
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOPO_FLEX]
   @c_OrderKey Nvarchar(10)
AS
   SET NOCOUNT ON         -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pokey              NVARCHAR(18)          
         , @c_consigneekey       NVARCHAR(15)
         , @c_externorderkey     NVARCHAR(30)
         , @c_type               NVARCHAR(10)
         , @c_selleraddress1     NVARCHAR(45)
         , @c_selleraddress2     NVARCHAR(45)
         , @c_sellercity         NVARCHAR(45)
         , @c_sellerstate        NVARCHAR(45)
         , @c_sellerzip          NVARCHAR(18)
         , @c_storerkey          NVARCHAR(15)
         , @c_buyeraddress1      NVARCHAR(45)
         , @c_buyeraddress2      NVARCHAR(45)
         , @c_buyeraddress3      NVARCHAR(45)
         , @c_buyeraddress4      NVARCHAR(45)
         , @c_buyercity          NVARCHAR(45)
         , @c_buyerstate         NVARCHAR(45)
         , @c_buyerzip           NVARCHAR(18)
         , @c_notes              NVARCHAR(2000)
         , @c_facility           NVARCHAR(5)
         , @c_sku                NVARCHAR(20)
         , @n_qtyordered         int
         , @c_polinenumber       NVARCHAR(5)
         , @c_orderlinenumber    NVARCHAR(5)
         , @c_skudescr           NVARCHAR(60)
         , @c_packkey            NVARCHAR(10)
         , @c_uom                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @d_Lottable04         DATETIME
         , @d_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME
         , @c_toid               NVARCHAR(18)
         , @n_LineNo             int                              
         
   DECLARE @n_continue           int
         , @b_success            int
         , @n_err                int
         , @c_errmsg             NVARCHAR(255)
         , @n_starttcnt          int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      SELECT @c_consigneekey  = ORDERS.Consigneekey,
             @c_externorderkey = ORDERS.ExternOrderkey,
             @c_type = ORDERS.Type,
             @c_selleraddress1 = SELLER.Address1,
             @c_selleraddress2 = SELLER.Address2,
             @c_sellercity = SELLER.City,
             @c_sellerstate = SELLER.State,
             @c_sellerzip = SELLER.Zip,
             @c_storerkey = ORDERS.Storerkey, 
             @c_buyeraddress1 = BUYER.Address1,
             @c_buyeraddress2 = BUYER.Address2,
             @c_buyeraddress3 = BUYER.Address3,
             @c_buyeraddress4 = BUYER.Address4,
             @c_buyercity = BUYER.City,
             @c_buyerstate = BUYER.State,
             @c_buyerzip = BUYER.Zip,
             @c_notes = ORDERS.Notes,
             @c_facility = ORDERS.Facility
      FROM   ORDERS WITH (NOLOCK)
      JOIN   STORER SELLER WITH (NOLOCK) ON (SELLER.Storerkey = ORDERS.Consigneekey)
      JOIN   STORER BUYER WITH (NOLOCK) ON (BUYER.Storerkey = ORDERS.Storerkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_Consigneekey),'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Consigneekey is blank/invalid. '+'Order# '+ RTRIM(@c_orderkey) +' (ispPopulateTOPO_FLEX)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      IF ISNULL(RTRIM(@c_ExternOrderkey),'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63503
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ExternOrderNo is blank. '+ 'Order# '+ RTRIM(@c_orderkey) + ' (ispPopulateTOPO_FLEX)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
      
      IF (SELECT COUNT(1) FROM CODELKUP (NOLOCK) WHERE Listname = 'POTYPE' AND Code = @c_type) = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63504
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order type ' + RTRIM(@c_type)+ ' must maintain in POTYPE codelkup. ' + 'Order# '+ RTRIM(@c_orderkey) + ' (ispPopulateTOPO_FLEX)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END -- if continue = 1 or 2 

   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_storerkey,'') <> ''
   BEGIN
      -- get next receipt key
      SELECT @b_success = 0
      EXECUTE   nspg_getkey
               'PO'
               , 10
               , @c_POKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

      IF @b_success = 1
      BEGIN
         INSERT INTO PO (POKey, Externpokey, Potype, Sellername, Selleraddress1, Selleraddress2, Sellercity,
                              Sellerstate, Sellerzip, Storerkey, Buyeraddress1, Buyeraddress2, Buyeraddress3, Buyeraddress4,
                              Buyercity, Buyerstate, Buyerzip, Notes)
         VALUES (@c_POKey, @c_externorderkey, @c_type, @c_consigneekey, @c_selleraddress1, @c_selleraddress2, @c_sellercity,
                 @c_sellerstate, @c_sellerzip, @c_storerkey, @c_buyeraddress1, @c_buyeraddress2, @c_buyeraddress3, @c_buyeraddress4,
                 @c_buyercity, @c_buyerstate, @c_buyerzip, @c_notes)
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate PO Key Failed! (ispPopulateTOPO_FLEX)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END
   
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_storerkey,'') <> ''
   BEGIN
      SELECT @c_OrderLineNumber = SPACE(5), @n_LineNo = 1

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1

         SELECT @c_SKU             = ORDERDETAIL.Sku,
                @c_PackKey         = ORDERDETAIL.PackKey,
                @c_UOM             = ORDERDETAIL.UOM,
                @c_SKUDescr        = SKU.DESCR,
                @c_OrderLineNumber = ORDERDETAIL.OrderLineNumber
         FROM ORDERDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
         JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku )
         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) 
         AND ( ORDERDETAIL.OrderKey = @c_orderkey ) 
         AND ( ORDERDETAIL.OrderLineNumber > @c_OrderLineNumber )
         ORDER by ORDERDETAIL.OrderLineNumber

         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0

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
                LOTATTRIBUTE.Lottable15,
                PICKDETAIL.ID
         FROM PICKDETAIL   WITH (NOLOCK)
         JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
         WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                PICKDETAIL.OrderLineNumber = @c_OrderLineNumber)
         GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                  LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, 
                  LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                  LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                  PICKDETAIL.ID

         OPEN PICK_CUR

         FETCH NEXT FROM PICK_CUR
               INTO @n_QtyOrdered, 
                     @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                     @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                     @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_toid

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_POLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS Char(5))), 5)

            INSERT INTO PODETAIL      (POKey,               POLineNumber,     SKUDescription,
                                       ExternLineNo,        StorerKey,        SKU,
                                       QtyOrdered,          Facility,         UOM,              PackKey,          ToID,
                                       Lottable01,          Lottable02,       Lottable03,       Lottable04,       Lottable05,
                                       Lottable06,          Lottable07,       Lottable08,       Lottable09,       Lottable10,
                                       Lottable11,          Lottable12,       Lottable13,       Lottable14,       Lottable15,
                                       Userdefine01,        Userdefine02,     Userdefine03,     Userdefine06,     Userdefine07)
                        VALUES        (@c_POKey,            @c_POLineNumber,  @c_SKUDescr,
                                       @c_OrderLineNumber,  @c_StorerKey,     @c_SKU,
                                       @n_QtyOrdered,       @c_facility,      @c_UOM,           @c_Packkey,       @c_toid,
                                       @c_Lottable01,       @c_Lottable02,    @c_Lottable03,    @d_Lottable04,    @d_Lottable05,
                                       @c_Lottable06,       @c_Lottable07,    @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                       @c_Lottable11,       @c_Lottable12,    @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                       @c_Lottable01,       @c_Lottable02,    @c_Lottable03,    @d_Lottable04,    @d_Lottable05)

            SELECT @n_LineNo = @n_LineNo + 1

            FETCH NEXT FROM PICK_CUR
               INTO @n_QtyOrdered, 
                     @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                     @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                     @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_toid

         END -- WHILE @@FETCH_STATUS <> -1
         DEALLOCATE PICK_CUR
      END --while
   END -- continue
   SET ROWCOUNT 0

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN

      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
      BEGIN

         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOPO_FLEX'
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
   --END -- if continue = 1 or 2 001

-- end procedure

GO