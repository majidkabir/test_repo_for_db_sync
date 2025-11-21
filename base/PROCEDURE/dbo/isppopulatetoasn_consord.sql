SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispPopulateToASN_CONSORD] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE  @c_ExternReceiptKey  NVARCHAR(20),
            @c_SKU               NVARCHAR(20),
            @c_PackKey           NVARCHAR(10),
            @c_UOM               NVARCHAR(5),
            @c_SKUDescr          NVARCHAR(60),
            @c_StorerKey         NVARCHAR(15),
            @c_OrderLine         NVARCHAR(5),
            @c_Facility          NVARCHAR(5),
            @c_ExternOrderLine   NVARCHAR(10)

   DECLARE  @c_Lottable02        NVARCHAR(18),
            @d_Lottable04        datetime,
            @n_ShippedQty        int

   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @c_ConsigneeKey      NVARCHAR(15),
            @n_ExpectedQty       int,
            @n_QtyReceived       int
    
   DECLARE @n_continue        int,
           @b_success         int,
           @n_err             int,
           @c_errmsg          NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN         
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.Orderkey,
             @c_Facility = FACILITY.UserDefine02     
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
      WHERE  ORDERS.OrderKey = @c_OrderKey
  
	   IF @n_continue = 1 OR @n_continue = 2
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
	            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, RecType, Facility, DOCTYPE)
	            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, 'CONSRCP', @c_Facility, 'A')
	         END
	         ELSE
	         BEGIN
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
	   			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateToASN_CONSORD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	         END
	      END    
	      ELSE
	      BEGIN
	         SELECT @n_continue = 3
	         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
	   		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateToASN_CONSORD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	      END
	   END -- if continue = 1 or 2

	   IF @n_continue = 1 OR @n_continue = 2 --002
	   BEGIN         
	      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
	      SELECT @c_ExternOrderLine = SPACE(5)
	
	      WHILE 1=1
	      BEGIN
	         SET ROWCOUNT 1
	      
	         SELECT @c_SKU    = ORDERDETAIL.Sku,   
	               @c_PackKey = ORDERDETAIL.PackKey,   
	               @c_UOM     = ORDERDETAIL.UOM,   
	               @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	               @c_SKUDescr  = SKU.DESCR,   
	      			@c_OrderLine = ORDERDETAIL.OrderLineNumber,
	               @c_ExternOrderLine = ORDERDETAIL.ExternLineNo,
	               @c_Lottable02 = CASE WHEN (SKU.Lottable02Label IS NOT NULL AND SKU.Lottable02Label <> '')
                                    THEN 'NOLOT' ELSE '' END,
	               @d_Lottable04 = CASE WHEN (SKU.Lottable04Label IS NOT NULL AND SKU.Lottable04Label <> '')
                                    THEN '2000-01-01' ELSE '' END
	          FROM ORDERDETAIL (NOLOCK)
	      			JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
	               JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
	         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
	               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
						( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )
	         ORDER by ORDERDETAIL.ExternLineNo
	
	         IF @@ROWCOUNT = 0
	            BREAK
	
	         SET ROWCOUNT 0     
 
            SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)                   

            INSERT INTO RECEIPTDETAIL (ReceiptKey,    				ReceiptLineNumber,	ExternReceiptKey, 
                                       ExternLineNo,  				StorerKey,				SKU, 
                                       QtyExpected,   				QtyReceived,			UOM,          
                                       PackKey,       				ToLoc,					Lottable03,    
													BeforeReceivedQty,         Lottable02,          Lottable04)
                        		VALUES  (@c_NewReceiptKey, 			@c_ReceiptLine,		@c_ExternReceiptKey,
                                       @c_OrderLine,     			@c_StorerKey,			@c_SKU,
                                       ISNULL(@n_ShippedQty,0),	0,							@c_UOM,
                                       @c_Packkey,      				@c_ConsigneeKey,		@c_ConsigneeKey,  
													ISNULL(@n_ShippedQty,0),   @c_Lottable02,       @d_Lottable04)
                                       
            SELECT @n_LineNo = @n_LineNo + 1

	      END -- WHILE 1=1
      END -- if continue = 1 or 2 --002

      SET ROWCOUNT 0
   END -- if continue = 1 or 2 --001

GO