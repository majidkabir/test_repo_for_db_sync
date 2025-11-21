SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_MHD                                             */
/* Creation Date: 09th DEC 2020                                         */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS                             */
/*                                                                      */
/* Usage: WMS-15797 - CN_MHS_AutoCreateASN _New                         */
/*                                                                      */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 04-JAN-2020  CSCHONG    WMS-15797 fix field format (CS01)            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_MHD]
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
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
           @n_ShippedQty            int

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_ConsigneeKey          NVARCHAR(15),
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @n_RemainExpectedQty     int,
           @c_Toloc                 NVARCHAR(30),
           @c_ToID                  NVARCHAR(30) ,
           @c_ToLot                 NVARCHAR(30),
           @c_rhudf01               NVARCHAR(10),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_UDF01                 NVARCHAR(50),
           @c_UDF02                 NVARCHAR(50),
           @c_ExternLineNo          NVARCHAR(20),
           @c_AltSKU                NVARCHAR(20),
           @c_Dropid                NVARCHAR(20),
           @c_channel               NVARCHAR(80),
           @c_Salesman              NVARCHAR(45),
           @c_Address1              NVARCHAR(45),
           @c_Address2              NVARCHAR(45),
           @c_CContact1             NVARCHAR(45),
           @c_CPhone1               NVARCHAR(45),
           @c_packuom3              NVARCHAR(20)
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @c_salesofftake          NVARCHAR(1) -- Add by June 27.Mar.02

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   -- insert into Receipt Header
   
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN         
    
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.externorderkey,
             @c_rhudf01 = CONVERT(NVARCHAR(10),ORDERS.UserDefine07,120) , --ORDERS.UserDefine07,   --CS01
             @c_facility = ORDERS.Facility, 
             @c_address1  = ORDERS.c_Address1,
             @c_address2  = ORDERS.c_Address2, 
             @c_CContact1 = ORDERS.C_Contact1,
             @c_CPhone1   = ORDERS.C_phone1,
             @c_channel = CASE WHEN ORDERDETAIL.Channel = 'B2B' THEN 'B2C'
                               WHEN ORDERDETAIL.Channel = 'B2C' THEN 'B2B'
                           ELSE '' END
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
      AND    ORDERS.UserDefine01 = 'Y'

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
     
    IF NOT EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE externreceiptkey = @c_ExternReceiptKey and userdefine01 = @c_rhudf01)
    BEGIN 
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
      BEGIN
         -- get next receipt key
         SELECT @b_success = 0
         EXECUTE   nspg_getkey
         "RECEIPT"
         , 10
         , @c_NewReceiptKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptGroup, Facility,RecType,DocType, carriername,CarrierAddress1,
                                 CarrierAddress2,CarrierReference,UserDefine01,UserDefine02)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, '',@c_facility,'NIF','R',@c_CContact1,@c_address1,@c_Address2,@c_CPhone1,@c_rhudf01,'')
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTOASN_MHD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTOASN_MHD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   ELSE
   BEGIN
    
    SELECT @c_NewReceiptKey = RECEIPTKEY
    FROM RECEIPT WITH (NOLOCK) WHERE UserDefine02 = @c_OrderKey

   END   
   END -- if continue = 1 or 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN       
   
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
      SELECT @c_ExternOrderLine = SPACE(5)

         SET ROWCOUNT 1
         SET ROWCOUNT 0      

              DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
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
                     PICKDETAIL.lot,PICKDETAIL.SKU,
                     PICKDETAIL.ID,PICKDETAIL.loc,P.Packuom3,Pickdetail.packkey 
                  FROM PICKDETAIL (NOLOCK) 
                  JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                  JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.sku
                  JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
                  WHERE PICKDETAIL.OrderKey = @c_OrderKey 
                  GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                           LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                           LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                           LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                           PICKDETAIL.lot,PICKDETAIL.SKU,PICKDETAIL.ID,PICKDETAIL.loc,P.packuom3,pickdetail.packkey

               OPEN PICK_CUR
               
               FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                             @c_tolot,@c_sku,@c_toid,@c_toloc , @c_packuom3 , @c_packkey
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN

              SELECT @n_LineNo = MAX(RD.ReceiptLineNumber)
              FROM RECEIPT RH WITH (NOLOCK)
              JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.receiptkey = RH.receiptkey
              WHERE RH.externreceiptkey = @c_ExternReceiptKey and RH.userdefine01 = @c_rhudf01

              IF ISNULL(@n_LineNo,'0') = 0
              BEGIN
                SET @n_LineNo = 1

              END
              ELSE
              BEGIN
                 SET @n_LineNo = @n_LineNo + 1
              END

                  SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)
   
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptKey, 
                                             StorerKey,           SKU, 
                                             QtyExpected,         QtyReceived,
                                             ToLoc,
                                             Lottable01,          Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                             Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                             Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                             BeforeReceivedQty,   Toid,                Tolot,             Channel,UOM,Packkey)
                              VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_StorerKey,        @c_SKU,
                                             ISNULL(@n_QtyReceived,0),   0,              
                                             @c_Toloc,
                                             @c_Lottable01,       @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05, 
                                             @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                             @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                             0,                   @c_ToID,             @c_tolot,         @c_channel,       @c_packuom3,@c_PackKey)
                                             
   
                  SELECT @n_LineNo = @n_LineNo + 1
   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                          @c_Tolot,@c_sku,@c_ToID,@c_Toloc,@c_packuom3, @c_packkey
               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
            --END
         END
      --END -- WHILE

     
      SET ROWCOUNT 0
   END -- if continue = 1 or 2 001

GO