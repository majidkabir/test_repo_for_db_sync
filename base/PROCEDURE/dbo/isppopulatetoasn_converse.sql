SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateTOASN_CONVERSE                                          */
/* Creation Date: 07-MAY-2019                                             */
/* Copyright: LF                                                          */
/* Written by: WLCHOOI                                                    */
/*                                                                        */
/* Purpose: WMS-8885 - Auto Create ASN From Orders When MBOL Ship For     */
/*                     Converse                                           */
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
/*Date         Author  Ver. Purposes                                      */
/*2019-Jul-24  WLCHOOI 1.1  Fixes repeated records - Restructure (WL01)   */
/**************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_CONVERSE] 
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
            @c_Type               NVARCHAR(10),
            @c_WarehouseReference NVARCHAR(18),
            @c_Pickdetailkey      NVARCHAR(10),
            @c_DocType            NCHAR(1),
            @c_Facility           NVARCHAR(5)

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
            @c_RecType            NVARCHAR(10),
            @c_AltSku             NVARCHAR(20),
            @c_UPC                NVARCHAR(30), 
            @c_LabelNo            NVARCHAR(30),
            @c_Mode               NVARCHAR(20),
            @c_GetMode            NVARCHAR(20),
            @c_UserDefine01       NVARCHAR(30)  
                                  
   DECLARE  @n_continue           INT,
            @b_success            INT,
            @n_err                INT,
            @c_errmsg             NVARCHAR(255),
            @n_starttcnt			 INT,
            @n_rowcnt             INT
            
     CREATE TABLE #Temp_UPC
     (
        UPC             NVARCHAR(30),
        Mode            NVARCHAR(20) 
     )

     SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt = @@TRANCOUNT 
     SELECT @c_ID = '', @c_ToLoc = '', @c_FinalizeFlag = 'N'
     
     SELECT TOP 1 @c_Facility = ISNULL(CODELKUP.UDF03,'')     
     FROM ORDERS WITH (NOLOCK)
     JOIN CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' AND CODELKUP.Storerkey = ORDERS.StorerKey
                                AND CODELKUP.Short = ORDERS.Consigneekey
     WHERE ORDERS.OrderKey = @c_OrderKey  

     IF @c_Facility = 'CD08' --Facility CD08 only distinguish mode
     BEGIN
        --Get UPC and mode (Single or Mixed) and insert into temp table
        INSERT INTO #Temp_UPC
        SELECT DISTINCT PACKDETAIL.UPC
                       ,CASE WHEN SUBSTRING(PACKDETAIL.UPC,1,5) = '00000' THEN 'Single' ELSE 'Mixed' END AS Mode
        FROM  ORDERS WITH (NOLOCK) 
        JOIN PACKHEADER (NOLOCK) ON PACKHEADER.OrderKey = ORDERS.OrderKey
        JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
        WHERE ORDERS.OrderKey = @c_OrderKey
        GROUP BY PACKDETAIL.UPC
     END
     ELSE
     BEGIN
        INSERT INTO #Temp_UPC
        SELECT DISTINCT PACKDETAIL.UPC
                       ,'ALL'
        FROM  ORDERS WITH (NOLOCK) 
        JOIN PACKHEADER (NOLOCK) ON PACKHEADER.OrderKey = ORDERS.OrderKey
        JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
        WHERE ORDERS.OrderKey = @c_OrderKey
        GROUP BY PACKDETAIL.UPC
     END

     DECLARE cur_Mode CURSOR FAST_FORWARD READ_ONLY FOR
     SELECT DISTINCT Mode
     FROM #Temp_UPC
     ORDER BY Mode DESC --Do single first

     OPEN cur_Mode

     FETCH NEXT FROM cur_Mode INTO @c_Mode

     WHILE @@FETCH_STATUS <> -1 --cur_Mode
     BEGIN
     	-- BEGIN TRAN	
     	-- insert into Receipt Header    	        
        SELECT TOP 1 
                 @c_ExternReceiptKey   = ORDERS.Orderkey + CASE WHEN @c_Mode = 'Single' THEN '01' WHEN @c_Mode = 'Mixed' THEN '02' ELSE '' END,
                 @c_ToFacility         = ISNULL(CODELKUP.UDF03,''),            
                 @c_ToStorerkey        = ISNULL(CODELKUP.UDF01,''),
                 @c_Storerkey          = ORDERS.Storerkey,
                 @c_DocType            = 'A',
                 @c_RecType            = ISNULL(CODELKUP.UDF02,'N')
        FROM ORDERS WITH (NOLOCK)
        JOIN CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' AND CODELKUP.Storerkey = ORDERS.StorerKey
                                   AND CODELKUP.Short = ORDERS.Consigneekey
        WHERE ORDERS.OrderKey = @c_OrderKey  
        
        SELECT @n_rowcnt = @@ROWCOUNT

        IF @n_rowcnt = 0
           GOTO EXITLOOP
        
        IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
        BEGIN
           SET @n_continue = 3
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
           SET @n_err = 63490   
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                          ' (ispPopulateTOASN_CONVERSE)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END
     
        SELECT @c_ToLoc = ISNULL(F.UserDefine04,'')
        FROM FACILITY F (NOLOCK)
        WHERE F.Facility = @c_ToFacility
     
        IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
        BEGIN
           SET @n_continue = 3
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
           SET @n_err = 63495   
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                          ' (ispPopulateTOASN_CONVERSE)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END

		  IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
		  BEGIN
           SET @n_continue = 3
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
           SET @n_err = 63497   
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                        ' (ispPopulateTOASN_CONVERSE)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		  END
       
        IF @n_continue = 1 OR @n_continue = 2
        BEGIN
           IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
           BEGIN
              SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
              FROM RECEIPT(NOLOCK)
              WHERE Externreceiptkey = @c_ExternReceiptKey
              AND Storerkey = @c_ToStorerKey
              AND Rectype   = @c_RecType
              AND Facility  = @c_ToFacility
              AND Doctype   = @c_DocType 	      	 
              AND ISNULL(Externreceiptkey,'') <> ''
              AND Status <> '9'

              SET @c_FoundReceiptKey = ''
	       	 
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
                    INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey, POKey, RecType, Facility, DocType)
                    VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_ToStorerKey, @c_Orderkey, @c_RecType, @c_ToFacility, @c_DocType)
           
                    SET @n_err = @@Error
                    IF @n_err <> 0
                    BEGIN
                       SET @n_continue = 3
                       SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                       SET @n_err = 63498   
                       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_CONVERSE)' + ' ( ' + 
                                     ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                    END
                 END
	            ELSE
	            BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
                  SET @n_err = 63499   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_CONVERSE)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	            END
	          END
	       END    
          ELSE
	       BEGIN
              SET @n_continue = 3
              SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
              SET @n_err = 63500   
              SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_CONVERSE)' + ' ( ' + 
                           ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
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
         --WL01        
       /*     DECLARE cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR
	         SELECT DISTINCT SKU.SKU,   
	                         SKU.AltSku,
	                         ORDERDETAIL.PackKey,   
	                         PACK.PACKUOM3,   
	                         --(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	                         ORDERDETAIL.OrderLineNumber,
	                         ISNULL(ORDERDETAIL.ExternLineNo,''),
	                         #Temp_UPC.Mode        
	         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
	         JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku) 
	         JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            JOIN PACKHEADER (NOLOCK) ON PACKHEADER.OrderKey = ORDERS.OrderKey
            JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
            JOIN #Temp_UPC ON #Temp_UPC.UPC = PACKDETAIL.UPC
            WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
	                ( ORDERDETAIL.OrderKey = @c_orderkey ) AND (#Temp_UPC.Mode = @c_Mode)   
	          ORDER by #Temp_UPC.Mode DESC, ORDERDETAIL.OrderLineNumber ASC

            OPEN cur_ReceiptDetail

            FETCH NEXT FROM cur_ReceiptDetail INTO @c_SKU, @c_AltSku, @c_PackKey, @c_UOM, @c_OrderLine, @c_ExternOrderLine, @c_GetMode

            WHILE @@FETCH_STATUS <> -1
            BEGIN
            	
               IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku ) 
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 63501   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + ' Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_CONVERSE)' + ' ( ' + 
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END*/

               IF @n_continue = 1 OR @n_continue = 2 --Based on Packdetail
               BEGIN 	   		   
                  IF ISNULL(RTRIM(@c_OrderKey),'') <> ''-- AND   
                    -- ISNULL(RTRIM(@c_OrderLine),'') <> ''           --WL01
                  BEGIN
                     DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                        SELECT  SUM(PACKDETAIL.QTY)
                               ,PACKDETAIL.UPC
                               ,PACKDETAIL.LabelNo
                               ,SKU.SKU
                               ,SKU.AltSku
                               ,SKU.PackKey
                               ,PACK.PACKUOM3  
                               ,PACKDETAIL.CartonNo 
                               ,#Temp_UPC.Mode
                        FROM PACKDETAIL (NOLOCK)
                        JOIN PACKHEADER (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
                        JOIN #Temp_UPC ON #Temp_UPC.UPC = PACKDETAIL.UPC
                        JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey) 
                        JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERS.StorerKey AND SKU.Sku = PACKDETAIL.Sku) 
                        JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                        WHERE PACKHEADER.OrderKey = @c_Orderkey AND #Temp_UPC.Mode = @c_Mode
                        GROUP BY PACKDETAIL.UPC
                                ,PACKDETAIL.LabelNo
                                ,SKU.SKU
                                ,SKU.AltSku
                                ,SKU.PackKey
                                ,PACK.PACKUOM3  
                                ,PACKDETAIL.CartonNo 
                                ,#Temp_UPC.Mode
                        ORDER BY PACKDETAIL.CartonNo
                 
                       OPEN PICK_CUR
                       
                       FETCH NEXT FROM PICK_CUR INTO @n_ShippedQty, @c_UPC, @c_LabelNo,
                                                     @c_SKU, @c_AltSku, @c_PackKey, @c_UOM, @c_OrderLine, @c_GetMode
                  
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
                             SELECT @n_QtyExpected = @n_ShippedQty 
                             SELECT @n_BeforeReceivedQty = 0
                             SELECT @n_QtyReceived = 0 
                          END

                          SELECT @c_UserDefine01 = CASE WHEN @c_GetMode IN ('Single','Mixed') THEN 
                                                   CASE WHEN SUBSTRING(LTRIM(@c_UPC),1,5) = '00000' THEN @c_UPC ELSE @c_LabelNo END
                                                   ELSE '' END
         
                          INSERT INTO RECEIPTDETAIL (ReceiptKey,           ReceiptLineNumber,      ExternReceiptkey,    
                                                     ExternLineNo,         StorerKey,              SKU, 
                                                     QtyExpected,          QtyReceived,          
                                                     UOM,                  PackKey,                ToLoc,
                                                     BeforeReceivedQty,    FinalizeFlag,           ToID,
                                                     UserDefine01,         AltSku)			                                          
                                           VALUES(   @c_NewReceiptKey,     @c_ReceiptLine,         @c_ExternReceiptkey,   
                                                     @c_OrderLine,         @c_ToStorerKey,         @c_SKU,
                                                     @n_QtyExpected,       @n_QtyReceived,					
                                                     @c_UOM,               @c_Packkey,             @c_Toloc,			                                           
                                                     @n_BeforeReceivedQty, @c_FinalizeFlag,        @c_ID,
                                                     @c_UserDefine01,      @c_AltSku)	
                     			        
                          SELECT @n_LineNo = @n_LineNo + 1
                  
                          FETCH NEXT FROM PICK_CUR INTO @n_ShippedQty, @c_UPC, @c_LabelNo,
                                                        @c_SKU, @c_AltSku, @c_PackKey, @c_UOM, @c_OrderLine, @c_GetMode
                       END -- WHILE @@FETCH_STATUS <> -1
                       CLOSE PICK_CUR
                       DEALLOCATE PICK_CUR
                  END
               END
            --WL01   
           /*    FETCH NEXT FROM cur_ReceiptDetail INTO @c_SKU, @c_AltSku, @c_PackKey, @c_UOM, @c_OrderLine, @c_ExternOrderLine, @c_GetMode
            END
            CLOSE cur_ReceiptDetail
            DEALLOCATE cur_ReceiptDetail */
      END -- if continue = 1 or 2

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
              SET @n_err = 63492   
              SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_CONVERSE)' + ' ( ' + 
                            ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
           END              
        END -- if continue = 1 or 2
EXITLOOP:
        FETCH NEXT FROM cur_Mode INTO @c_Mode
     END --cur_Mode
     CLOSE cur_Mode
     DEALLOCATE cur_Mode
		
QUIT_SP:

		IF @n_continue = 3  -- Error Occured - Process And Return
	   BEGIN
	      SELECT @b_success = 0
	   
	      --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	      --BEGIN
	         --ROLLBACK TRAN
	      --END
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_CONVERSE'
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
	
END


GO