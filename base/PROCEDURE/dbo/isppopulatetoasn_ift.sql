SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_IFT                                             */
/* Creation Date: 14th Oct 2008                                         */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS (Inter Warehouse transfer)  */
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
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 9-Dec-2010   KHLim01   1.1   make Receipt.ExternReceiptKey =         */
/*                                               Orders.ExternOrderKey  */
/* 13-Apr-2011  AQSKC     1.2   SOS#211694 Populate OD.Externlineno to  */
/*                              RD.ExternLineno if not blank and cater  */
/*                              for Swire requirements (Kc01)           */
/* 18-Jul-2011  YTWan     1.3   SOS#220711 Populate (Wan01)             */
/*                              - O.BuyerPO to R.WarehouseReference     */
/*                              - O.Userdefine02 to R.UserDefine02      */
/* 18-Jul-2011  YTWan     1.3   - 1) Fixed to raise error. (Wan02)      */
/*                                2) Extend Warehousereference to       */
/*                                   NVARCHAR(18).                      */
/* 14-MAr-2012  YTWan     1.3   - Add mapping - Populate OD.Userdefine02*/
/*                                to RD.Userdefine02.(wan03)            */
/* 28-May-2014  TKLIM     1.4    Added Lottables 06-15                  */ 
/* 28-Jan-2019  TLTING_ext 1.5   enlarge externorderkey field length     */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispPopulateTOASN_IFT] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        


   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10),
           @c_id                    NVARCHAR(18),
           @c_ODExternOrderkey      NVARCHAR(50)   --tlting_ext    --(Kc01)


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
           @c_userdefine04          NVARCHAR(30),
           --@c_warehousereference  NVARCHAR(10),         --(Wan02)     
           @c_warehousereference    NVARCHAR(18),        --(Wan02)    

           @c_ordertype             NVARCHAR(10),
           @c_OHUserDefine01        NVARCHAR(20),        --(Kc01)
           @c_ODUserDefine01        NVARCHAR(18),        --(Kc01)
           @c_OHUserDefine02        NVARCHAR(20),        --(Wan01)
           @c_ODUserDefine02        NVARCHAR(18)         --(Wan01)
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @c_salesofftake          NVARCHAR(1) -- Add by June 27.Mar.02

   DECLARE @n_starttcnt             INT                     --(Wan02)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   SET @n_starttcnt      = @@TRANCOUNT                --(Wan02)
   SET @c_OHUserDefine02 = ''                         --(Wan01)
   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN  

      SET @c_id = ''
      SET @c_OHUserDefine01 = ''
       
      SELECT @c_ConsigneeKey       = ISNULL(ORDERS.ConsigneeKey,''),
             @c_StorerKey          = ORDERS.Storerkey,  
             @c_ExternReceiptKey   = ISNULL(ORDERS.ExternOrderkey,''),
--             @c_WarehouseReference = ORDERS.ExternOrderKey,                 --(Wan01)
             @c_WarehouseReference = ORDERS.BuyerPO,                          --(Wan01)
--             @c_ExternOrderLine    = ORDERDETAIL.Orderlinenumber,           --(Kc01)
             @c_facility           = ISNULL(ORDERS.Consigneekey, ''),
             @c_userdefine04       = ISNULL(FACILITY.UserDefine04,''),
             @c_ordertype          = ORDERS.Type,
             @c_OHUserDefine01     = ISNULL(ORDERS.UserDefine01,''),
             @c_OHUserDefine02     = ISNULL(ORDERS.UserDefine02,'')           --(Wan01)         
      FROM   ORDERS      WITH (NOLOCK)
      JOIN   MBOL        WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)   
      LEFT OUTER JOIN   FACILITY    WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Consigneekey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    
      IF ISNULL(RTRIM(@c_ConsigneeKey),'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility is blank (ispPopulateTOASN_IFT)' + ' ( ' 
                               + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         GOTO QUIT_SP                                                      --(Wan02)
      END 
      IF NOT EXISTS (SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE FACILITY = @c_ConsigneeKey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility not Exists (ispPopulateTOASN_IFT)' + ' ( ' 
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         GOTO QUIT_SP                            --(Wan02)
      END 

     
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
            --(Kc01)
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, DocType, UserDefine01
                               , UserDefine02)                                                       --(Wan01)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_ordertype, @c_consigneekey, 'A', @c_OHUserDefine01 
                               , @c_OHUserDefine02)                                                  --(Wan01)
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_IFT)' + ' ( ' 
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
            GOTO QUIT_SP
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_IFT)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         GOTO QUIT_SP
      END

   END -- if continue = 1 or 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
      SELECT @c_ExternOrderLine = SPACE(5)
      

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1
         SET @c_ODUserDefine01 = ''          --(Kc01)
         SET @c_ODExternOrderkey = ''        --(Kc01)
         SET @c_ExternOrderLine = ''         --(Kc01)
      
         SELECT @c_SKU    = ORDERDETAIL.Sku,   
               @c_PackKey = ORDERDETAIL.PackKey,   
               @c_UOM     = ORDERDETAIL.UOM,   
               @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
               @c_SKUDescr  = SKU.DESCR,   
               @c_OrderLine = ORDERDETAIL.OrderLineNumber,
               @c_ExternOrderLine = CASE WHEN ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'') <> '' 
                                    THEN ORDERDETAIL.ExternLineNo ELSE ORDERDETAIL.OrderLineNumber END,        --(Kc01)
               @c_ODUserDefine01 = ISNULL(ORDERDETAIL.UserDefine01,''),                                        --(Kc01)
               @c_ODExternOrderkey = ISNULL(ORDERDETAIL.ExternOrderkey,''),                                     --(Kc01)
               @c_ODUserDefine02 = ISNULL(ORDERDETAIL.UserDefine02,'')                                         --(Wan03)
         FROM ORDERDETAIL WITH (NOLOCK)
               JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
               JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
               ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )        --(Kc01)
         ORDER by ORDERDETAIL.OrderLineNumber                     --(Kc01)
         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0      
         IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND 
            ISNULL(RTRIM(@c_OrderLine), '') <> ''
         BEGIN
              DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                  SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                     ISNULL(LOTATTRIBUTE.Lottable01,''),
                     ISNULL(LOTATTRIBUTE.Lottable02,''),
                     ISNULL(LOTATTRIBUTE.Lottable03,''),
                     LOTATTRIBUTE.Lottable04,
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
                           LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,
                           LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                           LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15
               OPEN PICK_CUR
               
               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
            

                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,    ReceiptLineNumber,    
                                             ExternLineNo,  StorerKey,           SKU, 
                                             QtyExpected,   QtyReceived,
                                             UOM,           PackKey,             ToLoc,
                                             Lottable01,    Lottable02,          Lottable03,    Lottable04, 
                                             Lottable06,    Lottable07,          Lottable08,    Lottable09,    Lottable10,
                                             Lottable11,    Lottable12,          Lottable13,    Lottable14,    Lottable15,
                                             ToID,          UserDefine01, 
                                             ExternReceiptkey, UserDefine02)                       --(Wan03) 
                                             
                              VALUES        (@c_NewReceiptKey, @c_ReceiptLine,   
                                             @c_ExternOrderLine, @c_StorerKey,     @c_SKU,         --(Kc01)
                                             --@c_OrderLine,     @c_StorerKey,     @c_SKU,         --(Kc01)
                                             ISNULL(@n_QtyReceived,0),   0,               
                                             @c_UOM,           @c_Packkey,       @c_userdefine04,
                                             @c_Lottable01,    @c_Lottable02,    @c_Lottable03, @d_Lottable04,    
                                             @c_Lottable06,    @c_Lottable07,    @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                             @c_Lottable11,    @c_Lottable12,    @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                             @c_id,            @c_ODUserDefine01,--(Kc01)
                                             @c_ODExternOrderkey,                                  --(Kc01)
                                             @c_ODUserDefine02)                                    --(Wan03)
                                             
   
                  SELECT @n_LineNo = @n_LineNo + 1
   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
         END
      END
      END -- WHILE
      SET ROWCOUNT 0

      --(Wan02) - START
      QUIT_SP:
      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN
         SET @b_success = 0
   
         IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_ITF'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SET @b_success = 1
         RETURN
      END   
      --(Wan02) - END
   END -- if continue = 1 or 2 001


GO