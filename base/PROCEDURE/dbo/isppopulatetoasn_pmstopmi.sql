SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateTOASN_PMSTOPMI                                          */
/* Creation Date: 03-Feb-2020                                             */
/* Copyright: LFL                                                         */
/* Written by: WLChooi                                                    */
/*                                                                        */
/* Purpose: WMS-11861 -  Auto Create ASN From Orders When MBOL Ship       */
/*			   Storer PMS to PMI                                             */
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
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/*                                                                        */
/* Updates:                                                               */
/*Date        Author  Ver.   Purposes                                     */
/*2020-03-24  WLChooi v1.1   Error message show Orderkey & fix bugs(WL01) */
/**************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_PMSTOPMI]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE  @c_ExternReceiptKey   NVARCHAR(20),
            @c_SKU                NVARCHAR(20),
            @c_PackKey            NVARCHAR(10),
            @c_UOM                NVARCHAR(5),
            @c_StorerKey          NVARCHAR(15),
            @c_ToStorerKey        NVARCHAR(15),
            @c_OrderLine          NVARCHAR(5),
            @c_ToFacility         NVARCHAR(5),
            @c_ExternOrderLine    NVARCHAR(20),
            @c_ID                 NVARCHAR(18),
            @c_ToLoc              NVARCHAR(10),
            @c_PDToloc            NVARCHAR(10),
            @c_Type               NVARCHAR(20),
            @c_WarehouseReference NVARCHAR(18),
            @c_Pickdetailkey      NVARCHAR(10),
            @c_DocType            NCHAR(1),
            @c_UserDefine01       NVARCHAR(30),
            @dt_ReceiptDate       DATETIME

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
            @c_susr1              NVARCHAR(40),
            @c_POKey              NVARCHAR(18),
            @c_Consigneekey       NVARCHAR(15),
            @c_UDF05              NVARCHAR(60),
            @n_Count              INT,
            @c_CustomSQL          NVARCHAR(4000),
            @n_InnerPack          INT

   DECLARE  @n_continue           INT,
            @b_success            INT,
            @n_err                INT,
            @c_errmsg             NVARCHAR(255),
            @n_starttcnt          INT

   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END  

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt = @@TRANCOUNT
   SELECT @c_ID = '', @c_ToLoc = 'PMISTG', @c_FinalizeFlag = 'N', @c_Lottable01 = '', @c_Lottable12 = ''

   BEGIN TRAN
   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	   SELECT TOP 1
             @c_ExternReceiptKey   = ORDERS.ExternOrderkey,
             @c_UserDefine01       = ORDERS.Orderkey,
             @dt_ReceiptDate       = MBOL.ShipDate,
             @c_ToStorerkey        = ISNULL(CODELKUP.UDF01,''),
             @c_Storerkey          = ORDERS.Storerkey,
             @c_Type               = 'NORMAL',
             @c_Consigneekey       = LTRIM(RTRIM(ISNULL(ORDERS.ConsigneeKey,''))),
             @c_UDF05              = ISNULL(CODELKUP.UDF05,''),
             @c_CustomSQL          = ISNULL(CODELKUP.Notes,'')
      FROM  ORDERS WITH (NOLOCK)
      JOIN MBOLDETAIL WITH (NOLOCK) ON ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY
      JOIN MBOL WITH (NOLOCK) ON MBOL.MBOLKEY = MBOLDETAIL.MBOLKEY
      JOIN CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' AND CODELKUP.Storerkey = 'PMS' --WL01 - Use Join
      WHERE ORDERS.OrderKey = @c_OrderKey
            
      SELECT TOP 1 @c_ToFacility = ISNULL(STORER.Facility,'')
      FROM STORER (NOLOCK)
      WHERE STORER.Storerkey = @c_ToStorerkey

      --WL01 START
      IF LTRIM(RTRIM(@c_Storerkey)) NOT IN ('PMS','PMI')
      BEGIN
         GOTO QUIT_SP
      END
      --WL01 END

      --Check Consigneekey
      IF @c_Consigneekey = ''
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63494
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Consigneekey is empty, Orderkey = ' + @c_OrderKey +   --WL01
                       ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END

      --Check allowed consigneekey list
      IF @c_UDF05 = '' 
      BEGIN
         --SET @n_continue = 3
         --SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         --SET @n_err = 63495
         --SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Codelkup.UDF05 is empty or not setup' +
         --              ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END
      
      SELECT @n_Count = COUNT(1) 
      FROM dbo.fnc_delimsplit (',',LTRIM(RTRIM(@c_UDF05)))
      WHERE ColValue = @c_Consigneekey

      IF @n_Count <= 0
      BEGIN
         --SET @n_continue = 3
         --SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         --SET @n_err = 63496
         --SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Consigneekey: ' + @c_Consigneekey + ' not found in UDF05' +
         --              ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END

      --Check ToStorerkey if it exists since it is different from FromStorerkey
      IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
      BEGIN
      	SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63497
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                       ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
	       IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
	       BEGIN
	          SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
	      	  FROM RECEIPT(NOLOCK)
	      	  WHERE Externreceiptkey = @c_ExternReceiptKey
	      	  AND UserDefine01 = @c_UserDefine01
	      	  AND Storerkey = @c_ToStorerKey
	      	  AND Rectype = @c_Type
	      	  AND Facility = @c_ToFacility
              AND WarehouseReference = @c_Orderkey --WL01
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
	               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, UserDefine01
	                                  , StorerKey, RecType, Facility, ReceiptDate, WarehouseReference)  --WL01
	               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_UserDefine01
	                     , @c_ToStorerKey, @c_Type, @c_ToFacility, @dt_ReceiptDate, @c_Orderkey)     --WL01        

	               SET @n_err = @@Error
	               IF @n_err <> 0
	               BEGIN
	                  SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
                                  ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '     
                     GOTO QUIT_SP
	               END
	            END
	            ELSE
	            BEGIN
	               SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
					       SET @n_err = 63499
	   			       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_PMSTOPMI)'
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '      
                 GOTO QUIT_SP
	            END
	         END
	      END
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 63500
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
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
	                --@c_PackKey    = ORDERDETAIL.PackKey,
                   @c_PackKey    = LTRIM(RTRIM(ISNULL(STORER.SUSR3,''))),
                   @n_InnerPack  = ISNULL(PACK.InnerPack,0),
	                --@c_UOM        = PACK.PACKUOM3,
                   @c_UOM        = P1.PACKUOM3,
	                @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
	                @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),
	                @n_QtyExpected = ORDERDETAIL.ORIGINALQTY
	         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
	         JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
	         JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            JOIN STORER WITH (NOLOCK) ON STORER.StorerKey = @c_ToStorerKey
            LEFT JOIN PACK P1 WITH (NOLOCK) ON P1.PackKey = STORER.SUSR3
	         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND
	               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND
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
                           AND Long = 'ispPopulateTOASN_PMSTOPMI' AND Short = 'Y')
               BEGIN
                  IF @c_ToStorerkey = 'PMI' AND @c_CustomSQL <> ''
                  BEGIN
                     SET @c_CustomSQL = @c_CustomSQL + ', Strategykey = ''PMIFIFO'' '
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
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting to SKU Table. (ispPopulateTOASN_PMSTOPMI)'   
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                     GOTO QUIT_SP  
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 63502
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  GOTO QUIT_SP
               END
            END

            --Check if the UPC exists on ToStorerKey
            IF NOT EXISTS ( SELECT 1 FROM UPC WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku )
            BEGIN
               --If ReportCFG is turned on, Insert UPC for ToStorerkey
               IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'REPORTCFG' AND CODE = 'InsertUPCIfNotExists' AND STORERKEY = @c_ToStorerkey
                           AND Long = 'ispPopulateTOASN_PMSTOPMI' AND Short = 'Y')
               BEGIN
                  IF EXISTS (SELECT 1 FROM UPC (NOLOCK) WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU)
                  BEGIN
                     INSERT INTO UPC (UPC, StorerKey, SKU, PackKey, UOM)
                     SELECT UPC, @c_ToStorerkey, SKU, PackKey, UOM
                     FROM UPC (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     AND SKU = @c_SKU
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3  
                        SET @n_err = 63503  
                        SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting to UPC Table. (ispPopulateTOASN_PMSTOPMI)'   
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                        GOTO QUIT_SP  
                     END
                  END
                  ELSE
                  BEGIN
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3  
                        SET @n_err = 63504
                        SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPC Record Not Found in ' + @c_StorerKey + '. (ispPopulateTOASN_PMSTOPMI)'   
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                        GOTO QUIT_SP  
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 63505
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPC Record not found. SKU: ' + 
                                 RTRIM(@c_Sku) + ' Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  GOTO QUIT_SP
               END
            END

				IF @n_continue = 1 OR @n_continue = 2 --Based on Pickdetail
	   		BEGIN
		          IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND
		             ISNULL(RTRIM(@c_OrderLine),'') <> ''
		          BEGIN
		               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR
		               SELECT SUM(PICKDETAIL.Qty),
                          LOTATTRIBUTE.Lottable01,
                          LOTATTRIBUTE.Lottable02,
                          LOTATTRIBUTE.Lottable03,
                          LOTATTRIBUTE.Lottable04,
                          LOTATTRIBUTE.Lottable05,
                          LOTATTRIBUTE.Lottable06,
                          LOTATTRIBUTE.Lottable07,
                          LOTATTRIBUTE.Lottable08,
                          LOTATTRIBUTE.Lottable09,
                          LOTATTRIBUTE.Lottable10,
                          LOTATTRIBUTE.Lottable11,
                          LOTATTRIBUTE.Lottable13,
                          LOTATTRIBUTE.Lottable14,
                          LOTATTRIBUTE.Lottable15,
                          PICKDETAIL.ID,
                          PICKDETAIL.Loc  
                     FROM PICKDETAIL   WITH (NOLOCK)
                     JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                     WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND PICKDETAIL.OrderLineNumber = @c_OrderLine)
			            GROUP BY PICKDETAIL.OrderKey,
			                     PICKDETAIL.OrderLineNumber,
                              LOTATTRIBUTE.Lottable01,
			                     LOTATTRIBUTE.Lottable02,
			                     LOTATTRIBUTE.Lottable03,
			                     LOTATTRIBUTE.Lottable04,
                              LOTATTRIBUTE.Lottable05,
			                     LOTATTRIBUTE.Lottable06,
			                     LOTATTRIBUTE.Lottable07,
			                     LOTATTRIBUTE.Lottable08,
			                     LOTATTRIBUTE.Lottable09,
			                     LOTATTRIBUTE.Lottable10,
			                     LOTATTRIBUTE.Lottable11,
			                     LOTATTRIBUTE.Lottable13,
			                     LOTATTRIBUTE.Lottable14,
			                     LOTATTRIBUTE.Lottable15,
			                     PICKDETAIL.ID,
			                     PICKDETAIL.Loc  

			             OPEN PICK_CUR

			             FETCH NEXT FROM PICK_CUR
			             INTO    @n_ShippedQty, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
			                     @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
			                     @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_ID, @c_PDToloc 

			             WHILE @@FETCH_STATUS <> -1
			             BEGIN
			                SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

			                IF @c_FinalizeFlag = 'Y'
			                BEGIN
			                   SELECT @n_QtyExpected = CASE WHEN ISNULL(@n_InnerPack,0) > 0 THEN @n_ShippedQty / @n_InnerPack ELSE 0 END
			                   SELECT @n_BeforeReceivedQty = CASE WHEN ISNULL(@n_InnerPack,0) > 0 THEN @n_ShippedQty / @n_InnerPack ELSE 0 END
			                   SELECT @n_QtyReceived = CASE WHEN ISNULL(@n_InnerPack,0) > 0 THEN @n_ShippedQty / @n_InnerPack ELSE 0 END
			                END
			                ELSE
			                BEGIN
			                   SELECT @n_QtyExpected = CASE WHEN ISNULL(@n_InnerPack,0) > 0 THEN @n_ShippedQty / @n_InnerPack ELSE 0 END
			                   SELECT @n_BeforeReceivedQty = 0
			                   SELECT @n_QtyReceived = 0
			                END

			                INSERT INTO RECEIPTDETAIL (ReceiptKey,   			    ReceiptLineNumber,  ExternReceiptkey,
			                                           ExternLineNo, 			    StorerKey,          SKU,
			                                           QtyExpected,  			    QtyReceived,
			                                           UOM,          			    PackKey,            ToLoc,
			                                           Lottable01,				    Lottable02,   		Lottable03,
			                                           Lottable04,				    Lottable05,         Lottable06,        Lottable07,
			                                           Lottable08,				    Lottable09,			Lottable10,
			                                           Lottable11,				    Lottable12,			Lottable13,
			                                           Lottable14,				    Lottable15,			BeforeReceivedQty,
			                                           FinalizeFlag, 			    ToID)
			                            VALUES        (@c_NewReceiptKey, 	  	    @c_ReceiptLine,     @c_ExternReceiptkey,
			                                           @c_ExternOrderLine,		    @c_ToStorerKey,     @c_SKU,
			                                           @n_QtyExpected,      	    @n_QtyReceived,
			                                           @c_UOM,            		    @c_Packkey,         @c_ToLoc,
			                                           @c_Lottable01,       	    '',                 'G',
			                                           @d_Lottable04,			    NULL,               '',                @c_Lottable07,
			                                           '',                        @c_Lottable09,      @c_Lottable10,
			                                           @c_Lottable11,			    @c_Lottable12,      @d_Lottable13,
			                                           @d_Lottable14,			    @d_Lottable15,      @n_BeforeReceivedQty,
			                                           @c_FinalizeFlag, 		    @c_ID)

			                SELECT @n_LineNo = @n_LineNo + 1

			                SET @n_err = @@Error
			                IF @n_err <> 0
			                BEGIN
			                   SET @n_continue = 3
			                   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
			                   SET @n_err = 63506
			                   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table ReceiptDetail (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
                                      ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '       
			                   GOTO QUIT_SP
			                END

			                FETCH NEXT FROM PICK_CUR
			                   INTO @n_ShippedQty, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
			                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
			                        @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_ID, @c_PDToloc
			             END -- WHILE @@FETCH_STATUS <> -1
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
        
        SET @n_err = @@Error
        
        IF @n_err <> 0
        BEGIN
           SET @n_continue = 3
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
           SET @n_err = 63507
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_PMSTOPMI)' + ' ( ' +
                         ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '     
           GOTO QUIT_SP
        END
     END
END

QUIT_SP:

   /*IF @@TRANCOUNT < @n_StartTCnt        
   BEGIN
      BEGIN TRAN
   END*/

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt      
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_PMSTOPMI'
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