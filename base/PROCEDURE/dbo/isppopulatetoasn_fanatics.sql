SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_Fanatics                                        */
/* Creation Date: 15th JUL 2019                                         */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS                             */
/*                                                                      */
/* Usage: WMS-9698 - [CN] Fanatics Exceed AutoASN Configuration         */
/*        Copy from ispPopulateTOASN for Storerkey = 'Fanatics'         */
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
/* Date         Author  Ver.  Purposes                                  */
/* 20-JUL-2023  NJOW01  1.0   WMS-23138 Change mbolkey mapping          */
/* 20-JUL-2023  NJOW01  1.0   DEVOPS Combine Script                     */
/* 02-AUG-2023  NJOW02  1.1   Fix mapping                               */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateTOASN_Fanatics] 
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
           @c_loclast               NVARCHAR(30),
           @c_userdefine08          NVARCHAR(30) ,
           @c_userdefine07          NVARCHAR(30),
           @c_warehousereference    NVARCHAR(10),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_UDF01                 NVARCHAR(50),
           @c_UDF02                 NVARCHAR(50),
           @c_ExternLineNo          NVARCHAR(20),
           @c_AltSKU                NVARCHAR(20),
           @c_Dropid                NVARCHAR(20)
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @c_salesofftake          NVARCHAR(1) -- Add by June 27.Mar.02

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   SET @n_CtnOrder = 1
   SET @c_mbolkey  = ''
   SET @c_UDF01    = ''
   SET @c_UDF02    = ''

   -- insert into Receipt Header
   
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN             
      SELECT TOP 1 @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_ExternOrderLine = ORDERDETAIL.Orderlinenumber,
             @c_facility = MBOL.Facility, 
             @c_mbolkey  = MBOL.MBOLKey,
             @c_ExternLineNo = ORDERDETAIL.ExternLineNo,  
             @c_AltSKU  = ORDERDETAIL.AltSKU,
			       @c_PackKey = ORDERDETAIL.PackKey,   
             @c_UOM     = ORDERDETAIL.UOM,   
             @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY)
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
	    AND ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 )

      SELECT @n_CtnOrder = COUNT(1)
      FROM MBOLDETAIL WITH (NOLOCK)
      WHERE mbolkey=@c_mbolkey
      
      IF @n_CtnOrder > 1
      BEGIN
        SET @c_ExternReceiptKey = ''
      END
  
      SELECT @c_UDF01 = ISNULL(C.UDF01,'')
            ,@c_UDF02 = ISNULL(C.UDF02,'')
      FROM CODELKUP C WITH (NOLOCK)
      WHERE C.LISTNAME = 'FNCFAC'
      AND C.Short = @c_facility
     
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_loclast = Userdefine01,
                @c_userdefine08 = Userdefine08,
                @c_userdefine07 = userdefine07
         FROM FACILITY (NOLOCK)
         WHERE Facility = @c_Facility
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN       
         IF NOT EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                        WHERE POKEY = @c_mbolkey
                        AND Storerkey = @c_Storerkey) --NJOW02
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
                  INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, appointment_no, DOCTYPE,POKEY)
                  VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_UDF02, @c_UDF01,@c_facility, 'A',@c_mbolkey)
               END
               ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTOASN_Fanatics)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END    
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTOASN_Fanatics)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
	       END
	       ELSE
	       BEGIN	     
	          SELECT @c_NewReceiptKey = RECEIPTKEY
	          FROM RECEIPT WITH (NOLOCK) 
	          WHERE POKEY = @c_mbolkey      
	          AND Storerkey = @c_Storerkey --NJOW02
	       END   
      END -- if continue = 1 or 2
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN          
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
         SELECT @c_ExternOrderLine = SPACE(5)
      
         --WHILE 1=1
         --BEGIN
         SET ROWCOUNT 1
         --      select '1'
		     --select @c_OrderKey '@c_OrderKey'
            --SELECT @c_SKU    = ORDERDETAIL.Sku,   
         --    SELECT  @c_PackKey = ORDERDETAIL.PackKey,   
         --          @c_UOM     = ORDERDETAIL.UOM,   
         --          @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
         --         -- @c_SKUDescr  = SKU.DESCR,   
         --          @c_OrderLine = ORDERDETAIL.OrderLineNumber,
         --          @c_ExternOrderLine = ORDERDETAIL.ExternLineNo
         --    FROM ORDERDETAIL (NOLOCK)
         --         JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
         --         JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
         --   WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
         --         ( ORDERDETAIL.OrderKey = @c_orderkey ) 
		   	   --AND             
         --         ( ORDERDETAIL.ExternLineNo <= @c_ExternOrderLine )
         --   ORDER by ORDERDETAIL.ExternLineNo
            --IF @@ROWCOUNT = 0
            --   BREAK
      
         SET ROWCOUNT 0      
            --IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND 
            --   dbo.fnc_RTrim(@c_OrderLine) IS NOT NULL 
            --BEGIN
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
                   PICKDETAIL.DropID,PICKDETAIL.SKU,
		   		          S.DESCR 
            FROM PICKDETAIL (NOLOCK) 
            JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
		   		  JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.sku
            WHERE PICKDETAIL.OrderKey = @c_OrderKey 
		   		   --AND
            -- PICKDETAIL.OrderLineNumber = @c_OrderLine
            GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                     LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                     LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                     LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                     PICKDETAIL.DropID,PICKDETAIL.SKU,S.DESCR
      
         OPEN PICK_CUR
         
         FETCH NEXT FROM PICK_CUR
            INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                 @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                 @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                 @c_Dropid,@c_sku,@c_SKUDescr  
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
		   	    SELECT @n_LineNo = MAX(RD.ReceiptLineNumber)
		   		  FROM RECEIPTDETAIL RD WITH (NOLOCK)
		   		  WHERE RD.Receiptkey = @c_NewReceiptKey --NJOW02
		   		  --WHERE POKEY = @c_mbolkey
            
		   		  IF ISNULL(@n_LineNo,'0') = 0
		   		  BEGIN
		   		     SET @n_LineNo = 1            
		   		  END
		   		  ELSE
		   		  BEGIN
		   		     SET @n_LineNo = @n_LineNo + 1
		   		  END
      
            SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)
      
            -- select @n_RemainExpectedQty '@n_RemainExpectedQty', @n_QtyReceived '@n_QtyReceived',
            --       @c_ExternPOKey '@c_ExternPOKey' 
            IF @n_QtyReceived IS NULL
               SELECT @n_QtyReceived = 0                      
      
            INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptKey, 
                                       ExternLineNo,        StorerKey,           POKEY,          SKU, 
                                       Altsku ,             QtyExpected,         QtyReceived,
                                       UOM,                 PackKey,             ToLoc,
                                       Lottable01,          Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                       Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                       Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                       BeforeReceivedQty,   ExternPoKey,         UserDefine01,     Userdefine02)
                        VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptKey,
                                       @c_ExternLineNo,     @c_StorerKey,        '',      				 @c_SKU,  --NJOW01
                                       @c_AltSKU,           ISNULL(@n_QtyReceived,0),   0,               -- ONG01 
                                       @c_UOM,              @c_Packkey,          @c_loclast,
                                       @c_Lottable01,       @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05, 
                                       @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                       @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                       0,                   @c_OrderKey,         @c_Dropid,				 @c_mbolkey) --NJOW01
                                       
      
            SELECT @n_LineNo = @n_LineNo + 1
      
            FETCH NEXT FROM PICK_CUR
               INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                    @c_Dropid,@c_sku,@c_SKUDescr
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR
               --END
      END
      --END -- WHILE
	  
      SET ROWCOUNT 0
   END -- if continue = 1 or 2 001

GO