SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_LBI                                             */
/* Creation Date: 07-Aug-2014                                           */
/* Copyright: LF                                                        */
/* Written by:               						                           */
/*                                                                      */
/* Purpose: Auto Create ASN for CN-LBI Orders SOS#316910                */
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
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/*05-FEB-2015  SPChin  1.1  SOS332739 - Add Filter By SKU and           */
/* 												 ExternLineno                    */
/*10-Aug-2015  CSCHONG 1.2  SOS349238 (CS01)                            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_LBI]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE   @c_ExternReceiptKey   NVARCHAR(20),
             @c_SKU                NVARCHAR(20),
             @c_ALTSKU             NVARCHAR(20),
             @c_PackKey            NVARCHAR(10),
             @c_UOM                NVARCHAR(5),
             @c_StorerKey          NVARCHAR(15),
             @c_ToStorerKey        NVARCHAR(15),
             @c_OrderLine          NVARCHAR(5),
             @c_ToFacility         NVARCHAR(5),
             @c_ExternOrderLine    NVARCHAR(10),
				 @c_ID					  NVARCHAR(18),
				 @c_ToLoc				  NVARCHAR(10),
				 @c_Type               NVARCHAR(10),
				 @c_WarehouseReference NVARCHAR(18),
				 @c_Carrierkey         NVARCHAR(15),
				 @c_CarrierName        NVARCHAR(30),
				 @c_CarrierAddress1    NVARCHAR(45),
				 @d_ReceiptDate        DATETIME,
				 @c_ReceiptGroup       NVARCHAR(20),
				 @c_DestinationCountry NVARCHAR(30),
				 @c_TermsNote          NVARCHAR(18),
				 @c_Containerkey       NVARCHAR(18),
				 @c_Userdefine02       NVARCHAR(30),
				 @c_Userdefine03       NVARCHAR(30),
				 @c_Userdefine04       NVARCHAR(30),
				 @c_Userdefine05       NVARCHAR(30),
				 @d_Userdefine06       DATETIME,
				 @c_Userdefine08       NVARCHAR(30),
				 @c_Userdefine09       NVARCHAR(30),
				 @n_CTNQTY1            INT,
				 @n_NoOfMasterCtn      INT,
				 @n_Weight             FLOAT,
				 @n_WeightUnit         NVARCHAR(20),
				 @n_CaseCnt            INT,
				 @c_ContainerkeyDet    NVARCHAR(18),
				 @n_GrossWgt           FLOAT,
				 @n_NetWgt             FLOAT,
				 @c_SubReasonCode      NVARCHAR(10),
				 @c_ExternPokey        NVARCHAR(20),
				 @c_Userdefine01Det    NVARCHAR(30),
				 @c_Userdefine02Det    NVARCHAR(30),
				 @c_Userdefine03Det    NVARCHAR(30),
				 @c_Userdefine04Det    NVARCHAR(30),
				 @c_Userdefine05Det    NVARCHAR(30),
				 @c_Userdefine08Det    NVARCHAR(30),
				 @c_Userdefine09Det    NVARCHAR(30),
				 @c_Userdefine10Det    NVARCHAR(30)

   DECLARE  @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        datetime,
            @d_Lottable05        datetime,
            @n_ShippedQty        int

   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_FoundReceiptKey   NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @n_QtyReceived       INT

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
   	 SELECT @c_Type = 'NBD'

     SELECT TOP 1
            @c_ExternReceiptKey   = ORDERS.ExternOrderkey,
            @c_WarehouseReference = RECEIPT.WarehouseReference,
            @c_ToFacility         = STORER.Facility,
            @c_ToStorerkey        = '18455',
            @c_Storerkey          = ORDERS.Storerkey,
            @c_Carrierkey         = ISNULL(CL.Short,''),
            @c_CarrierName        = ISNULL(CAR.Company,''),
            @c_CarrierAddress1    = ISNULL(CAR.Address1,''),
				@d_ReceiptDate        = RECEIPT.ReceiptDate,
				@c_ReceiptGroup       = RECEIPT.ReceiptGroup,
				@c_DestinationCountry = RECEIPT.DestinationCountry,
				@c_TermsNote          = RECEIPT.TermsNote,
				@c_Containerkey       = RECEIPT.Containerkey,
				@c_Userdefine02       = RECEIPT.Userdefine02,
				@c_Userdefine03       = RECEIPT.Userdefine03,
				@c_Userdefine04       = RECEIPT.Userdefine04,
				@c_Userdefine05       = RECEIPT.Userdefine05,
				@d_Userdefine06       = RECEIPT.Userdefine06,
				@c_Userdefine08       = RECEIPT.Userdefine08,
				@c_Userdefine09       = RECEIPT.Userdefine09,
				@n_CTNQTY1            = RECEIPT.CTNQTY1,
				@n_NoOfMasterCtn      = RECEIPT.NoOfMasterCtn,
				@n_Weight             = RECEIPT.Weight,
				@n_WeightUnit         = RECEIPT.WeightUnit
     FROM  ORDERS WITH (NOLOCK)
     JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
     JOIN  RECEIPT WITH (NOLOCK) ON ORDERS.ExternOrderkey = RECEIPT.ExternReceiptKey
     LEFT JOIN CODELKUP CL (NOLOCK) ON Storer.Facility = CL.Code AND CL.Listname = 'MASTFAC'
     LEFT JOIN STORER CAR WITH (NOLOCK) ON CL.Short = CAR.Storerkey
     WHERE ORDERS.OrderKey = @c_OrderKey

     SELECT @c_ToLoc = ISNULL(FACILITY.UserDefine04,'')
     FROM FACILITY (NOLOCK)
     WHERE Facility =  @c_ToFacility

     IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63490
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                        ' (ispPopulateTOASN_LBI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END

     IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63495
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                        ' (ispPopulateTOASN_LBI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END

		 IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
		 BEGIN
		 	  SET @n_continue = 3
		 	  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	  SET @n_err = 63497
	    	SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                        ' (ispPopulateTOASN_LBI)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END

	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN
	      IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
	      BEGIN
	      	 SET @c_FoundReceiptKey = ''
	      	 /*
	      	 SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
	      	 FROM RECEIPT(NOLOCK)
	      	 WHERE Externreceiptkey = @c_ExternReceiptKey
	      	 AND Warehousereference = @c_WarehouseReference
	      	 AND storerkey = @c_ToStorerKey
	      	 AND Rectype = @c_Type
	      	 AND Facility = @c_ToFacility
	      	 AND Doctype = 'A'
	      	 AND POKey = @c_Orderkey
	      	 AND CarrierKey = @c_Carrierkey
	      	 AND ISNULL(Externreceiptkey,'') <> ''
	      	 AND ISNULL(Warehousereference,'') <> ''
	      	 */

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
	               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, Facility, DocType, RoutingTool, CarrierKey, POKey,
	                                    ReceiptDate, ReceiptGroup, DestinationCountry, TermsNote, Containerkey, Userdefine02, Userdefine03, Userdefine04,
	                                    Userdefine05, Userdefine06, Userdefine08, Userdefine09, CTNQTY1, NoofMasterCtn, WEIGHT, WeightUnit, CarrierName, CarrierAddress1)
	               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ToFacility, 'A', 'N', @c_Carrierkey, @c_OrderKey,
	                       @d_ReceiptDate, @c_ReceiptGroup, @c_DestinationCountry, @c_TermsNote, @c_Containerkey, @c_Userdefine02, @c_Userdefine03, @c_Userdefine04,
	                       @c_Userdefine05, @d_Userdefine06, @c_Userdefine08, @c_Userdefine09, @n_CTNQTY1, @n_NoofMasterCtn, @n_WEIGHT, @n_WeightUnit, @c_CarrierName, @c_CarrierAddress1)

				      	 SET @n_err = @@Error
                 IF @n_err <> 0
                 BEGIN
 	            	   SET @n_continue = 3
	                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				         SET @n_err = 63498
	   		         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_LBI)' + ' ( ' +
                                ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                 END
	            END
	            ELSE
	            BEGIN
	               SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
					   SET @n_err = 63499
	   			   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_LBI)'
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	            END
	         END
	      END
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				SET @n_err = 63500
	   		SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_LBI)' + ' ( ' +
                          ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	      END
	   END -- if continue = 1 or 2

	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN
	      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
	      SELECT @c_ExternOrderLine = SPACE(5)

	      /*
	      IF ISNULL(@c_FoundReceiptKey,'') <> ''
	      BEGIN
	      	 SELECT @n_LineNo = CONVERT(INT,MAX(ReceiptLineNumber)) + 1
	      	 FROM RECEIPTDETAIL (NOLOCK)
	      	 WHERE Receiptkey = @c_FoundReceiptKey

	      	 IF ISNULL(@n_LineNo,0) = 0
	      	    SET @n_LineNo = 1
	      END
	      */

	      WHILE 1=1
	      BEGIN
	 			   SET ROWCOUNT 1

	         SELECT @c_SKU        = SKU.SKU,
	                @c_PackKey    = PACK.PackKey,
	                @c_UOM        = PACK.PACKUOM3,
	                @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
	         	    @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
	                @c_ExternOrderLine = ISNULL(ORDERDETAIL.ExternLineNo,''),
	                @c_ALTSKU     = ORDERDETAIL.AltSku,
	                @c_Lottable01 = RECEIPTDETAIL.Lottable01,
	                @c_Lottable02 = RECEIPTDETAIL.Lottable02,
	                @c_Lottable03 = RECEIPTDETAIL.Lottable03,
	                --@d_Lottable04 = RECEIPTDETAIL.Lottable04,           --(CS01)
                   @d_Lottable04 =CASE WHEN CONVERT(NVARCHAR(8), RECEIPTDETAIL.Userdefine06, 112) <> '19000101' AND RECEIPTDETAIL.Userdefine06 IS NOT NULL THEN
                                     RECEIPTDETAIL.Userdefine06 ELSE RECEIPTDETAIL.Lottable04 END,   --(CS01)
				       @n_CaseCnt         = RECEIPTDETAIL.CaseCnt,
				       @c_ContainerkeyDet = RECEIPTDETAIL.Containerkey,
				       @n_GrossWgt        = RECEIPTDETAIL.GrossWgt,
				       @n_NetWgt          = RECEIPTDETAIL.NetWgt,
				       @c_SubReasonCode   = RECEIPTDETAIL.SubReasonCode,
				       @c_ExternPokey     = RECEIPTDETAIL.ExternPokey,
				       @c_Userdefine01Det = RECEIPTDETAIL.Userdefine01,
				       @c_Userdefine02Det = RECEIPTDETAIL.Userdefine02,
				       @c_Userdefine03Det = RECEIPTDETAIL.Userdefine03,
				       @c_Userdefine04Det = RECEIPTDETAIL.Userdefine04,
				       @c_Userdefine05Det = RECEIPTDETAIL.Userdefine05,
				       @c_Userdefine08Det = RECEIPTDETAIL.Userdefine08,
				       @c_Userdefine09Det = RECEIPTDETAIL.Userdefine09,
				       @c_Userdefine10Det = RECEIPTDETAIL.Userdefine10
         FROM ORDERDETAIL WITH (NOLOCK)
	         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
	         JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
	         JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	         JOIN RECEIPT WITH (NOLOCK) ON (ORDERS.ExternOrderKey = RECEIPT.ExternReceiptKey)
	         JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.Receiptkey = RECEIPTDETAIL.ReceiptKey
	                                              AND ORDERDETAIL.OrderLineNumber = RECEIPTDETAIL.ReceiptLineNumber
	                                              AND ORDERDETAIL.ExternLineNo = RECEIPTDETAIL.ExternLineNo	--SOS332739
	                                              AND ORDERDETAIL.SKU = RECEIPTDETAIL.SKU)							--SOS332739
	         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND
	               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND
				    		 ( ORDERDETAIL.OrderLineNumber > @c_OrderLine )
	         ORDER by ORDERDETAIL.OrderLineNumber

	         IF @@ROWCOUNT = 0
	            BREAK

	         SET ROWCOUNT 0

				   IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku )
				   BEGIN
 	         		SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				      SET @n_err = 63501
	   		      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_LBI)' + ' ( ' +
                         ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
				   END

				   IF @n_continue = 1 OR @n_continue = 2
	   		   BEGIN
		          IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND
		             ISNULL(RTRIM(@c_OrderLine),'') <> ''
		          BEGIN
		          	   SET @c_ID = ''

		               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR
			                SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty
			                FROM PICKDETAIL   WITH (NOLOCK)
			                JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
			                WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
			                       PICKDETAIL.OrderLineNumber = @c_OrderLine)
			                GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU

			             OPEN PICK_CUR

			             FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived

			             WHILE @@FETCH_STATUS <> -1
			             BEGIN
			                SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

				   		    IF @n_QtyReceived IS NULL
			                   SELECT @n_QtyReceived = 0

			                INSERT INTO RECEIPTDETAIL (ReceiptKey,   			  ReceiptLineNumber,   ExternReceiptkey,
			                                           ExternLineNo, 			  StorerKey,           SKU,
			                                           QtyExpected,  			  QtyReceived,
			                                           UOM,          			  PackKey,             ToLoc,		lottable01,
			                                           Lottable02,          Lottable03,   			 Lottable04,
				   		 							          BeforeReceivedQty,   FinalizeFlag, ToID,
			                                           Containerkey,				AltSku,			CaseCnt,		GrossWgt,		NetWgt,
			                                           SubReasonCode,				Externpokey,	Userdefine01,	Userdefine02, Userdefine03,
			                                           Userdefine04,				Userdefine05,	Userdefine08, Userdefine09, Userdefine10)
			                            VALUES        (@c_NewReceiptKey, 	  @c_ReceiptLine,      @c_ExternReceiptkey,
			                                           @c_ExternOrderLine,  @c_ToStorerKey,      @c_SKU,
			                                           @n_QtyReceived,      0,
			                                           @c_UOM,            	@c_Packkey,          @c_Toloc,	@c_Lottable01,
			                                           @c_Lottable02,       @c_Lottable03,   		 @d_Lottable04,
				   		 								       0,                   'N', @c_ID,
			                                           @c_ContainerkeyDet,	@c_ALTSKU,	@n_CaseCnt,		@n_GrossWgt,	@n_NetWgt,
			                                           @c_SubReasonCode,	  @c_ExternPokey,	@c_Userdefine01Det, @c_Userdefine02Det, @c_Userdefine03Det,
			                                           @c_Userdefine04Det, @c_Userdefine05Det, @c_Userdefine08Det, @c_Userdefine09Det, @c_Userdefine10Det )

			                SELECT @n_LineNo = @n_LineNo + 1

			             FETCH NEXT FROM PICK_CUR  INTO @n_QtyReceived
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
	   		    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateTOASN_LBI)' + ' ( ' +
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
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_LBI'
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