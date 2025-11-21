SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_SBUXM                                           */
/* Creation Date: 29-May-2013                                           */
/* Copyright: IDS                                                       */
/* Written by:               						                                */
/*                                                                      */
/* Purpose: Populate SO to Trade Return ASN by SKU Group SOS#278809     */
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
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_SBUXM] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE   @c_ExternReceiptKey  NVARCHAR(20),
            @c_SKU               NVARCHAR(20),
            @c_PackKey           NVARCHAR(10),
            @c_UOM               NVARCHAR(5),
            @c_StorerKey         NVARCHAR(15),
            @c_CarrierKey        NVARCHAR(15),
            @c_OrderLine         NVARCHAR(5),
            @c_Facility          NVARCHAR(5),
            @c_ExternOrderLine   NVARCHAR(10),
				    @c_ID						     NVARCHAR(18),
				    @c_ToLoc					   NVARCHAR(10),
				    @c_Type              NVARCHAR(10),
				    @c_WarehouseReference NVARCHAR(18)

   DECLARE  @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        datetime,
            @n_ShippedQty        int
            
   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @n_QtyReceived       int
           
   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @n_starttcnt			   int
            
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT 
	
	--BEGIN TRAN	
   
   -- insert into Receipt Header

   IF NOT EXISTS (SELECT 1 
                  FROM ORDERS (NOLOCK)
                  JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
                  JOIN SKU (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku
                  JOIN CODELKUP CL1 (NOLOCK) ON SKU.Skugroup = CL1.Code AND CL1.Listname = 'SO2ASNSKU' AND CL1.Storerkey = ORDERS.Storerkey
                  JOIN CODELKUP CL2 (NOLOCK) ON ORDERS.Type = CL2.Code AND CL2.ListName = 'ORDTYP2ASN' AND CL2.Storerkey = ORDERS.Storerkey 
                  WHERE ORDERS.OrderKey = @c_OrderKey)
   BEGIN
   	  GOTO QUIT_SP
   END

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN     	   	   	         
     SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.Mbolkey, 
            @c_Carrierkey         = ORDERS.Consigneekey,
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_Type               = ORDERS.Type,
            @c_Facility           = ORDERS.Facility,             
            @c_Storerkey          = ORDERS.Storerkey,
            @c_ToLoc              = 'SBUXM01'
     FROM  ORDERS WITH (NOLOCK)
     WHERE ORDERS.OrderKey = @c_OrderKey
         		 	   		 
     IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc) 
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63495   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc: ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                        ' (ispPopulateTOASN_SBUXM)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
     
	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN 				
	      IF ISNULL(RTRIM(@c_StorerKey),'') <> '' -- IS NOT NULL
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
	            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, WarehouseReference, CarrierKey, StorerKey, RecType, Facility, DocType, RoutingTool)
	            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_CarrierKey, @c_StorerKey, 'NORMAL', @c_Facility, 'R', 'N')
           
				   	 SET @n_err = @@Error
              IF @n_err <> 0
              BEGIN
 	         			 SET @n_continue = 3
	                SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				          SET @n_err = 63498   
	   		          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_SBUXM)' + ' ( ' + 
                             ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
              END
	         END
	         ELSE
	         BEGIN
	            SET @n_continue = 3
	            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
				      SET @n_err = 63499   
	   		      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_SBUXM)' 
	   		                + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	         END
	      END    
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 63500   
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_SBUXM)' + ' ( ' + 
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	      END
	   END -- if continue = 1 or 2

	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN         
	      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
	      SELECT @c_ExternOrderLine = SPACE(5)
	      SELECT @c_ID = ''
	      			
	      WHILE 1=1
	      BEGIN
	 			   SET ROWCOUNT 1
	         
	         SELECT @c_SKU        = SKU.SKU,   
	                @c_PackKey    = ORDERDETAIL.PackKey,   
	                @c_UOM        = ORDERDETAIL.UOM,   
	                @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	         	      @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
	                @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,'')
	         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
	         JOIN SKU    WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
	         JOIN CODELKUP CL1 (NOLOCK) ON SKU.Skugroup = CL1.Code AND CL1.Listname = 'SO2ASNSKU' AND CL1.Storerkey = ORDERS.Storerkey
	         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
	               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
				    		 ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
	         ORDER by ORDERDETAIL.OrderLineNumber
           
	         IF @@ROWCOUNT = 0
	            BREAK
	         
	         SET ROWCOUNT 0 
	                    
				   IF @n_continue = 1 OR @n_continue = 2
	   		   BEGIN 	   		   
		          IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND   
		             ISNULL(RTRIM(@c_OrderLine),'') <> ''
		          BEGIN
		               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
			                SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty
			                       --ISNULL(LOTATTRIBUTE.Lottable02,''),
				   		 			         --ISNULL(LOTATTRIBUTE.Lottable03,''),
				   		 			         --LOTATTRIBUTE.Lottable04
			                FROM PICKDETAIL   WITH (NOLOCK) 
			                --JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
			                WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
			                       PICKDETAIL.OrderLineNumber = @c_OrderLine)
			                GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU  
			                         --LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04
			        
			             OPEN PICK_CUR
			             
			             FETCH NEXT FROM PICK_CUR
			                INTO @n_QtyReceived--, @c_Lottable02, @c_Lottable03, @d_Lottable04 
			        
			             WHILE @@FETCH_STATUS <> -1
			             BEGIN
			                SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
			        
				   		    IF @n_QtyReceived IS NULL
			                   SELECT @n_QtyReceived = 0 
			                                
			                INSERT INTO RECEIPTDETAIL (ReceiptKey,   			  ReceiptLineNumber,   ExternReceiptkey,    
			                                           ExternLineNo, 			  StorerKey,           SKU, 
			                                           QtyExpected,  			  QtyReceived,          
			                                           UOM,          			  PackKey,             ToLoc,
			                                           --Lottable02,          Lottable03,   			 Lottable04,	  
				   		 										               BeforeReceivedQty,   FinalizeFlag, ID)			                                          
			                            VALUES        (@c_NewReceiptKey, 	  @c_ReceiptLine,      @c_ExternReceiptkey,   
			                                           @c_ExternOrderLine,  @c_StorerKey,      @c_SKU,
			                                           @n_QtyReceived,      0,					
			                                           @c_UOM,            	@c_Packkey,          @c_Toloc,			                                           
			                                           --@c_Lottable02,       @c_Lottable03,   		 @d_Lottable04,       
				   		 																	 0,                   'N', @c_ID)	
			                                           			        
			                SELECT @n_LineNo = @n_LineNo + 1
			        
			                FETCH NEXT FROM PICK_CUR
			                   INTO @n_QtyReceived--, @c_Lottable02, @c_Lottable03, @d_Lottable04 
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
	   		    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_SBUXM)' + ' ( ' + 
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
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_SBUXM'
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