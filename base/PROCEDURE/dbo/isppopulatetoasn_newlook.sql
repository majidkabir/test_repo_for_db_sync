SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateTOASN_NEWLOOK                                           */
/* Creation Date: 20-JUN-2016                                             */
/* Copyright: LF                                                          */
/* Written by:               						                                  */
/*                                                                        */
/* Purpose: 372249-CN-New Look-Auto Create ASN From Orders When MBOL Ship */
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
/**************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_NEWLOOK] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE   @c_ExternReceiptKey   NVARCHAR(20),
            @c_SKU                NVARCHAR(20),
            @c_PackKey            NVARCHAR(10),
            @c_UOM                NVARCHAR(5),
            @c_StorerKey          NVARCHAR(15),
            @c_ToStorerKey        NVARCHAR(15),
            @c_OrderLine          NVARCHAR(5),
            @c_ToFacility         NVARCHAR(5),
            @c_ExternOrderLine    NVARCHAR(20),
				    @c_ID						      NVARCHAR(18),
				    @c_ToLoc					    NVARCHAR(10),
				    @c_ToLoc2					    NVARCHAR(10),
				    @c_Type               NVARCHAR(10),
				    @c_WarehouseReference NVARCHAR(18),
			 		  @c_DocType            NCHAR(1),
            @c_Lottable02         NVARCHAR(18)
                                  
   DECLARE  @c_NewReceiptKey      NVARCHAR(10),
            @c_FoundReceiptKey    NVARCHAR(10),
            @c_ReceiptLine        NVARCHAR(5),
            @n_LineNo             INT,
            @n_QtyReceived        INT,
            @n_QtyExpected        INT,        
            @n_ShippedQty         INT,
            @n_BeforeReceivedQty  INT,
            @c_FinalizeFlag       NCHAR(1),
            @c_ReceiptGroup       NVARCHAR(20),
            @c_Consigneekey       NVARCHAR(15),
            @c_SellerAddress1     NVARCHAR(45),
            @c_SellerAddress2     NVARCHAR(45),
            @c_SellerAddress3     NVARCHAR(45),
            @c_SellerAddress4     NVARCHAR(45),
            @c_SellerCompany      NVARCHAR(45),
            @c_SellerName         NVARCHAR(45),
            @c_Userdefine01       NVARCHAR(30)            
                                  
   DECLARE  @n_continue           INT,
            @b_success            INT,
            @n_err                INT,
            @c_errmsg             NVARCHAR(255),
            @n_starttcnt			    INT
            
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT 
   SELECT @c_ID = '', @c_ToLoc = '', @c_FinalizeFlag = 'N'

	 --IF @@TRANCOUNT  = 0
	 --   BEGIN TRAN	

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN     	        
     SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.ExternOrderkey, 
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_Type               = ISNULL(C3.UDF03,''),
            @c_ToFacility         = ORDERS.Facility,             
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
            @c_DocType            = 'A',
            @c_ReceiptGroup       = CASE WHEN ISNULL(ORDERS.Userdefine05,'') <> '' THEN ORDERS.Userdefine05 ELSE ISNULL(CODELKUP.UDF01,'') END,
            @c_Consigneekey       = ORDERS.Consigneekey,
            @c_SellerCompany      = RTRIM(ISNULL(ORDERS.Userdefine01,'')) + LTRIM(ISNULL(ORDERS.Userdefine02,'')),
            @c_SellerName         = RTRIM(ISNULL(ORDERS.Userdefine03,'')) + LTRIM(ISNULL(ORDERS.Userdefine04,'')),
            @c_SellerAddress1     = ORDERS.M_Address1,
            @c_SellerAddress2     = ORDERS.M_Address2,
            @c_SellerAddress3     = ORDERS.M_Address3,
            @c_SellerAddress4     = ORDERS.M_Address4,
            @c_Toloc = CASE WHEN ISNULL(C1.Short,'') <> ISNULL(C2.Short,'') THEN
                          ''
                       ELSE
                          FACILITY.Userdefine04    
                       END                       
     FROM  ORDERS WITH (NOLOCK)
     JOIN  FACILITY WITH (NOLOCK) ON ORDERS.Facility = FACILITY.Facility
     LEFT JOIN CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND CODELKUP.ListName = 'ORDTYP2ASN' 
     LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON ORDERS.M_Address2 = C1.Code AND C1.ListName = 'NLDC' 
     LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON ORDERS.M_Address4 = C2.Code AND C2.ListName = 'NLDC' 
     LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON ORDERS.Consigneekey = C3.Code AND C3.ListName = 'NLDC' 
     WHERE ORDERS.OrderKey = @c_OrderKey             
      
    	 	  		 
     IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) AND ISNULL(@c_ToLoc,'') <> ''
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63495   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                        ' (ispPopulateTOASN_NEWLOOK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
		     
	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN 				
	      IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
	      BEGIN
	      	 SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
	      	 FROM RECEIPT(NOLOCK)
	      	 WHERE Externreceiptkey = @c_ExternReceiptKey
	      	 AND Warehousereference = @c_WarehouseReference
	      	 AND storerkey = @c_ToStorerKey
	      	 AND Rectype = @c_Type
	      	 AND Facility = @c_ToFacility
	      	 AND Doctype = @c_DocType 	      	 
	      	 AND ISNULL(Externreceiptkey,'') <> ''
	      	 AND ISNULL(Warehousereference,'') <> ''
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
	               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, Facility, DocType, RoutingTool, ReceiptGroup,
	                                    SellerCompany, SellerName, SellerAddress1, SellerAddress2, SellerAddress3, SellerAddress4)
	               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ToFacility, @c_DocType, 'N', @c_ReceiptGroup,
                         @c_SellerCompany, @c_SellerName, @c_SellerAddress1, @c_SellerAddress2, @c_SellerAddress3, @c_SellerAddress4)
              
				      	 SET @n_err = @@Error
                 IF @n_err <> 0
                 BEGIN
 	            			 SET @n_continue = 3
	                   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				             SET @n_err = 63498   
	   		             SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_NEWLOOK)' + ' ( ' + 
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                 END
	            END
	            ELSE
	            BEGIN
	               SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
					       SET @n_err = 63499   
	   			       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_NEWLOOK)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	            END
	         END
	      END    
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 63500   
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_NEWLOOK)' + ' ( ' + 
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
			
	      WHILE 1=1
	      BEGIN
	 			   SET ROWCOUNT 1
	         
	         SELECT @c_SKU        = SKU.SKU,   
	                @c_PackKey    = ORDERDETAIL.PackKey,   
	                @c_UOM        = PACK.PACKUOM3,   
	                @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	         	      @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
	                @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),
	                @c_Userdefine01 = ORDERDETAIL.Userdefine01
	         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
	         JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku) 
	         JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
	               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
				    		 ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
	         ORDER by ORDERDETAIL.OrderLineNumber
           
	         IF @@ROWCOUNT = 0
	            BREAK
	         
	         SET ROWCOUNT 0 
	         				   						              
				   IF @n_continue = 1 OR @n_continue = 2 --Based on Pickdetail
	   		   BEGIN 	   		   
		          IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
		             ISNULL(RTRIM(@c_OrderLine),'') <> ''
		          BEGIN
		               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
			                SELECT SUM(PICKDETAIL.Qty),
			                       @c_Consigneekey, --Lottable02
				   		 			         '', --ID
				   		 			         CASE WHEN ISNULL(@c_ToLoc,'') <> '' THEN
				   		 			            @c_Toloc
				   		 			         ELSE PICKDETAIL.Loc END
			                FROM PICKDETAIL   WITH (NOLOCK)
			                JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
			                WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
			                       PICKDETAIL.OrderLineNumber = @c_OrderLine)
			                GROUP BY CASE WHEN ISNULL(@c_ToLoc,'') <> '' THEN
				   		 			              @c_Toloc
				   		 			           ELSE PICKDETAIL.Loc END
			       
			             OPEN PICK_CUR
			             
			             FETCH NEXT FROM PICK_CUR
			                INTO @n_ShippedQty,  @c_Lottable02, @c_ID, @c_Toloc2
			        
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
			                   SELECT @n_BeforeReceivedQty = @n_ShippedQty
			                   SELECT @n_QtyReceived = 0 
			                END
			                   			                   			                                
			                INSERT INTO RECEIPTDETAIL (ReceiptKey,   			  	ReceiptLineNumber,   ExternReceiptkey,    
			                                           ExternLineNo, 			  	StorerKey,           SKU, 
			                                           QtyExpected,  			  	QtyReceived,          
			                                           UOM,          			  	PackKey,             ToLoc,
			                                           Lottable02,   		
				   		 										               BeforeReceivedQty,   	FinalizeFlag, 			 ToID,	 Userdefine01)			                                          
			                            VALUES        (@c_NewReceiptKey, 	  	@c_ReceiptLine,      @c_ExternReceiptkey,   
			                                           @c_OrderLine,		    	@c_ToStorerKey,      @c_SKU,
			                                           @n_QtyExpected,      	@n_QtyReceived,					
			                                           @c_UOM,            		@c_Packkey,          @c_Toloc2,			                                           
			                                           @c_Lottable02, 
				   		 																	 @n_BeforeReceivedQty,	@c_FinalizeFlag, 		 @c_ID,		@c_Userdefine01)	
			                                           			        
			                SELECT @n_LineNo = @n_LineNo + 1
			        
			                FETCH NEXT FROM PICK_CUR
   			                 INTO @n_ShippedQty,  @c_Lottable02, @c_ID, @c_Toloc2
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
				    SET @n_err = 63492   
	   		    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_NEWLOOK)' + ' ( ' + 
                       ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END              
     END
		
		 QUIT_SP:

		 IF @n_continue = 3  -- Error Occured - Process And Return
	   BEGIN
	      SELECT @b_success = 0
	   
	      --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	      --BEGIN
	         --ROLLBACK TRAN
	      --END
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_NEWLOOK'
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