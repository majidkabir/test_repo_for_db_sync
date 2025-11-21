SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateTOASN_UARW                                              */
/* Creation Date: 21-Apr-2017                                             */
/* Copyright: LFL                                                         */
/* Written by:               						                                  */
/*                                                                        */
/* Purpose: WMS-1704 Auto Create ASN for UA Rework Orders                 */
/*          order type: UAREWORKA, UAREWORKU                              */
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

CREATE PROCEDURE [dbo].[ispPopulateTOASN_UARW] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE   @c_ExternReceiptKey   NVARCHAR(20),
            @c_SKU               NVARCHAR(20),
            @c_PackKey           NVARCHAR(10),
            @c_UOM               NVARCHAR(5),
            @c_StorerKey         NVARCHAR(15),
            @c_ToStorerKey       NVARCHAR(15),
            @c_OrderLine         NVARCHAR(5),
            @c_ToFacility        NVARCHAR(5),
            @c_ExternOrderLine   NVARCHAR(20),
				    @c_ID						     NVARCHAR(18),
				    @c_ToLoc					   NVARCHAR(10),
				    @c_Type              NVARCHAR(10),
				    @c_WarehouseReference NVARCHAR(18),
				    @c_Mbolkey           NVARCHAR(10),
				    @c_Wavekey           NVARCHAR(10),
				    @d_DeliveryDate      DATETIME,
				    @c_OrderType         NVARCHAR(10)

   DECLARE  @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable05        datetime,
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @c_Lottable11        NVARCHAR(30),
            @c_Lottable12        NVARCHAR(30),
            @n_ShippedQty        int,
            @c_Userdefine01      NVARCHAR(18),
            @c_Userdefine02      NVARCHAR(18),
            @c_Userdefine03      NVARCHAR(18),
            @c_Userdefine04      NVARCHAR(18),
            @c_Userdefine05      NVARCHAR(18),
            @c_Userdefine08      NVARCHAR(18),
            @c_Userdefine09      NVARCHAR(18),
            @c_Userdefine10      NVARCHAR(18)
            
   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_FoundReceiptKey   NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @n_QtyReceived       int
           
   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @n_starttcnt			   int
            
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT 
   SELECT @c_ID = ''
	
	--BEGIN TRAN	

   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
     SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.Orderkey, 
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_Type               = 'UAREWORK',
            @c_ToFacility         = ORDERS.Facility,             
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
            @c_Mbolkey            = ORDERS.Mbolkey,
            @d_DeliveryDate       = ORDERS.DeliveryDate,            
            @c_OrderType          = ORDERS.Type
     FROM  ORDERS WITH (NOLOCK)
     WHERE ORDERS.OrderKey = @c_OrderKey        
      
     /*     
     IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63490   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                        ' (ispPopulateTOASN_UARW)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
    		 	  	
    	 	  		 
     IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63495   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                        ' (ispPopulateTOASN_UARW)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
		
		 
		 IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
		 BEGIN
		 	  SET @n_continue = 3
		 	  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	  SET @n_err = 63497   
	    	SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                        ' (ispPopulateTOASN_UARW)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
		 */
     
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
	      	 AND Doctype = 'A' 	      	 
	      	 AND ISNULL(Externreceiptkey,'') <> ''
	      	 AND ISNULL(Warehousereference,'') <> ''
	      	 AND UserDefine01 = 'REWORK'
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
	               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, Facility, DocType, RoutingTool, Mbolkey, EffectiveDate, UserDefine01)
	               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ToFacility, 'A', 'N', @c_Mbolkey, @d_DeliveryDate, 'REWORK')
              
				      	 SET @n_err = @@Error
                 IF @n_err <> 0
                 BEGIN
 	            			 SET @n_continue = 3
	                   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				             SET @n_err = 63498   
	   		             SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_UARW)' + ' ( ' + 
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                 END
	            END
	            ELSE
	            BEGIN
	               SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
					       SET @n_err = 63499   
	   			       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_UARW)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	            END
	         END
	      END    
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 63500   
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_UARW)' + ' ( ' + 
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
	                @c_UOM        = 'EA', --PACK.PACKUOM3,   
	                @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	         	      @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
	                @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''), 
	                @c_Lottable01 = ORDERDETAIL.Lottable01,
	                @c_Lottable02 = 'RETAIL',
	                @c_Lottable03 = ORDERDETAIL.Lottable03,	                
	                @c_Lottable06 = ORDERDETAIL.Lottable06,	                
	                @c_Lottable07 = 'STANDARD',
	                @c_Lottable08 = ORDERDETAIL.Lottable08,	                
	                @c_Lottable09 = ORDERDETAIL.Lottable09,	                
                  @c_Userdefine02 = 'REWORK', --ORDERDETAIL.Userdefine01
                  @c_Userdefine03 = ORDERDETAIL.Userdefine02,
                  @c_Userdefine04 = ORDERDETAIL.Userdefine03,
                  @c_Userdefine05 = ORDERDETAIL.Lottable03, --ORDERDETAIL.Userdefine04
                  @c_Userdefine08 = ORDERDETAIL.Userdefine05,	                	                
                  @c_Userdefine09 = ORDERDETAIL.Userdefine04, --ORDERDETAIL.Userdefine06                	                
                  @c_Userdefine10 = ORDERDETAIL.Userdefine01
	         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
	         JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku) 
	         JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	         WHERE ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
				    		 ( ORDERDETAIL.OrderLineNumber > @c_OrderLine ) AND
				    		 ( ORDERDETAIL.Userdefine06 = 'TO' )
	         ORDER by ORDERDETAIL.OrderLineNumber
           
	         IF @@ROWCOUNT = 0
	            BREAK
	         
	         SET ROWCOUNT 0 
	         
	         /*
				   IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku ) 
				   BEGIN 				   	  
 	         		SET @n_continue = 3
	            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				      SET @n_err = 63501   
	   		      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_UARW)' + ' ( ' + 
                         ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
				   END
				   */
           
				   IF @n_continue = 1 OR @n_continue = 2
	   		   BEGIN 	   		   
		          IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
		             ISNULL(RTRIM(@c_OrderLine),'') <> ''
		          BEGIN
	                 IF @c_OrderType = 'UAREWORKU'   
	                 BEGIN	                 	
		                  DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
			                   SELECT ORDERDETAIL.OriginalQty,
			                          ORDERDETAIL.Packkey,
				   		     		          NULL, --Lottable05
				   		     		          '0', --Lottable10
				   		     		          '', --Lottable11
				   		     		          '', --Lottable12
				   		     		          '', --ID
				   		     		          'UASTAGE' --loc
			                   FROM ORDERDETAIL  WITH (NOLOCK) 
			                   WHERE ORDERDETAIL.OrderKey = @c_OrderKey
			                   AND ORDERDETAIL.OrderLineNumber = @c_OrderLine 
			                   AND ORDERDETAIL.Userdefine06 = 'TO'
	                 END		          	    
	                 ELSE
	                 BEGIN
  	                 	--UAREWORKA
		                  DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
			                   SELECT SUM(PICKDETAIL.Qty),
			                          MAX(PICKDETAIL.Packkey),
				   		     		         LOTATTRIBUTE.Lottable05,
				   		     		         LOTATTRIBUTE.Lottable10,
				   		     		         LOTATTRIBUTE.Lottable11,
				   		     		         LOTATTRIBUTE.Lottable12,
				   		     		         PICKDETAIL.ID,
				   		     		         PICKDETAIL.Loc
			                   FROM ORDERDETAIL  WITH (NOLOCK) 
			                   JOIN PICKDETAIL   WITH (NOLOCK) ON ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
			                   JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
			                   WHERE ORDERDETAIL.OrderKey = @c_OrderKey
			                   AND ORDERDETAIL.ExternLineNo = @c_ExternOrderLine
			                   AND ORDERDETAIL.Userdefine06 = 'FROM'
				   		     		  GROUP BY LOTATTRIBUTE.Lottable05,
				   		     		           LOTATTRIBUTE.Lottable10,
				   		     		           LOTATTRIBUTE.Lottable11,
				   		     		           LOTATTRIBUTE.Lottable12,
				   		     		           PICKDETAIL.ID,
				   		     		           PICKDETAIL.Loc			    
				   		     END                  
				   		 			           			       
			             OPEN PICK_CUR
			             
			             FETCH NEXT FROM PICK_CUR
			                INTO @n_QtyReceived, @c_Packkey, @d_Lottable05, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_ID, @c_Toloc
			                    	        
			             WHILE @@FETCH_STATUS <> -1
			             BEGIN
			                SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
			        
				   		        IF @n_QtyReceived IS NULL
			                   SELECT @n_QtyReceived = 0 
			                
			                IF @c_OrderType = 'UAREWORKU'   
			                BEGIN
			                   SET @c_Userdefine01 = '' 
			                END
			                ELSE
			                BEGIN --UAREWORKA
			                   SET @c_Userdefine01 = @c_Lottable11   
			                END
			                   			                                
			                INSERT INTO RECEIPTDETAIL (ReceiptKey,   			  ReceiptLineNumber,   ExternReceiptkey,    
			                                           ExternLineNo, 			  StorerKey,           SKU, 
			                                           QtyExpected,  			  QtyReceived,          
			                                           UOM,          			  PackKey,             ToLoc,
			                                           Lottable01,          Lottable02,   			 Lottable03,	  
				   		 										               Lottable05,					Lottable06,
				   		 										               Lottable07,					Lottable08,					 Lottable09,
				   		 										               Lottable10,					Lottable11,					 Lottable12,
				   		 										               BeforeReceivedQty,   FinalizeFlag, 			 ToID,
				   		 										               Userdefine01,				Userdefine02,				 Userdefine03,
				   		 										               Userdefine04,				Userdefine05,				 
				   		 										               Userdefine08,				Userdefine09,				 Userdefine10)			                                          
			                            VALUES        (@c_NewReceiptKey, 	  @c_ReceiptLine,      @c_ExternReceiptkey,   
			                                           @c_ExternOrderLine,  @c_ToStorerKey,      @c_SKU,
			                                           @n_QtyReceived,      0,					
			                                           @c_UOM,            	@c_Packkey,          @c_Toloc,			                                           
			                                           @c_Lottable01,       @c_Lottable02, 			 @c_Lottable03,       
				   		 																	 @d_Lottable05,			  @c_Lottable06,
				   		 																	 @c_Lottable07,				@c_Lottable08,			 @c_Lottable09,
				   		 																	 @c_Lottable10,				@c_Lottable11,			 @c_Lottable12,
				   		 																	 0,     						  'N', 								 @c_ID,
				   		 																	 @c_Userdefine01,			@c_Userdefine02,  	 @c_Userdefine03,
				   		 																	 @c_Userdefine04,			@c_Userdefine05,		 
				   		 																	 @c_Userdefine08,			@c_Userdefine09,		 @c_Userdefine10)	
			                                           			        
			                SELECT @n_LineNo = @n_LineNo + 1
			        
			                FETCH NEXT FROM PICK_CUR
   			                INTO @n_QtyReceived, @c_Packkey, @d_Lottable05, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_ID, @c_Toloc
			             
			             END -- WHILE @@FETCH_STATUS <> -1
			             DEALLOCATE PICK_CUR
		          END
				   END
	      END --while
     END
     SET ROWCOUNT 0
     
     /*IF @n_continue = 1 OR @n_continue = 2
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
	   		    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_UARW)' + ' ( ' + 
                       ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END              
     END*/
		
		 QUIT_SP:

		 IF @n_continue = 3  -- Error Occured - Process And Return
	   BEGIN
	      SELECT @b_success = 0
	   
	      --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	      --BEGIN
	         --ROLLBACK TRAN
	      --END
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_UARW'
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