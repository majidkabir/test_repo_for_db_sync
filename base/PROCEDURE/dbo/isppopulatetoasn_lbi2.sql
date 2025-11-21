SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_LBI2                                            */
/* Creation Date: 10-Sep-2015                                           */
/* Copyright: LF                                                        */
/* Written by:               						                           */
/*                                                                      */
/* Purpose: CN-LBI MAST VSBA SO Populate to Asn SOS#351879              */
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
/*14-Jun-2016  NJOW01  1.0  371503-Group ASN by Loadkey                 */
/*29-Sep-2016  NJOW02  1.1  WMS-452 Add lottable13 mapping              */
/*30-Jan-2018  CSCHONG 1.3  WMS-3869 revise field logic (CS01)          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_LBI2]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	 DECLARE @c_ExternReceiptKey   NVARCHAR(20),
           @c_SKU                NVARCHAR(20),
           @c_ALTSKU             NVARCHAR(20),
           @c_PackKey            NVARCHAR(10),
           @c_UOM                NVARCHAR(5),
           @c_StorerKey          NVARCHAR(15),
           @c_ToStorerKey        NVARCHAR(15),
--           @c_OrderLine          NVARCHAR(5),
           @c_ToFacility         NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
	 			   @c_ToLoc				       NVARCHAR(10),
	 			   @c_Type               NVARCHAR(10),
	 			   @c_Carrierkey         NVARCHAR(15),
--	 			   @c_CarrierName        NVARCHAR(30),
--	 			   @c_CarrierAddress1    NVARCHAR(45),
--	 			   @d_ReceiptDate        DATETIME,
--	 			   @c_ReceiptGroup       NVARCHAR(20),
--	 			   @c_DestinationCountry NVARCHAR(30),
--	 			   @c_TermsNote          NVARCHAR(18),
	 			   @c_Containerkey       NVARCHAR(18),
	 			   @c_Userdefine02       NVARCHAR(30),
	 			   @c_Userdefine03       NVARCHAR(30),
--	 			   @c_Userdefine04       NVARCHAR(30),
--	 			   @c_Userdefine05       NVARCHAR(30),
--	 			   @d_Userdefine06       DATETIME,
--	 			   @c_Userdefine08       NVARCHAR(30),
--	 			   @c_Userdefine09       NVARCHAR(30),
	 			   @n_CTNQTY1            INT,
--	 			   @n_NoOfMasterCtn      INT,
	 			   @n_Weight             FLOAT,
	 			   @n_WeightUnit         NVARCHAR(20),
	 			   @n_CaseCnt            INT,
	 			   @c_ContainerkeyDet    NVARCHAR(18),
	 			   @n_GrossWgt           FLOAT,
	 			   @n_NetWgt             FLOAT,
--	 			   @c_SubReasonCode      NVARCHAR(10),
	 			   @c_ExternPokey        NVARCHAR(20),
	 			   @c_Userdefine01Det    NVARCHAR(30),
               @c_GetUserdefine01Det NVARCHAR(30),
	 			   @c_Userdefine02Det    NVARCHAR(30),
	 			   --@c_Userdefine03Det    NVARCHAR(30),
	 			   --@c_Userdefine04Det    NVARCHAR(30),
	 			   --@c_Userdefine05Det    NVARCHAR(30),
	 			   --@c_Userdefine08Det    NVARCHAR(30),
	 			   --@c_Userdefine09Det    NVARCHAR(30),
	 			   --@c_Userdefine10Det    NVARCHAR(30),
	 			   @c_Loadkey            NVARCHAR(10)

   DECLARE  @c_Lottable01        NVARCHAR(18),
            @c_Lottable02        NVARCHAR(18),
            @c_Lottable03        NVARCHAR(18),
            @d_Lottable04        datetime,
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @d_Lottable13        DATETIME --NJOW02
               --@d_Lottable05        datetime,
            --@n_ShippedQty        int

   DECLARE  @c_NewReceiptKey     NVARCHAR(10),
            @c_FoundReceiptKey   NVARCHAR(10),
            @c_ReceiptLine       NVARCHAR(5),
            @n_LineNo            int,
            @n_QtyReceived       INT,
            @b_debug             NVARCHAR(1)

   DECLARE  @n_continue          int,
            @b_success           int,
            @n_err               int,
            @c_errmsg            NVARCHAR(255),
            @n_starttcnt			   int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT, @b_debug = '0'

	--BEGIN TRAN

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SELECT TOP 1
            @c_ExternReceiptKey   = ORDERS.Loadkey,
            @c_ToFacility         = ISNULL(CL2.Short,''), --ISNULL(CL2.UDF04,''),       --CS01
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
            @c_Carrierkey         = ISNULL(CL.code,''),--ISNULL(CL.Short,''),            --CS01
				    @c_Userdefine03       = '25',
				    @n_WeightUnit         = 'KG',
				    @c_Loadkey            = ORDERS.Loadkey,
				    @c_Type               = 'NBD',
				    @c_Userdefine02       = ISNULL(CL.UDF03,'')--ISNULL(CL3.UDF03,'')                     --CS01
     FROM  ORDERS WITH (NOLOCK)
     JOIN  STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
     --LEFT JOIN CODELKUP CL (NOLOCK) ON Storer.Facility = CL.Code AND CL.Listname = 'MASTFAC'                 --CS01
     LEFT JOIN CODELKUP CL (NOLOCK) ON orders.Facility = CL.short AND CL.Listname = 'MASTFAC' AND CL.udf04=Orders.Doctype       --CS01
     LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL.UDF03 = CL2.Code AND CL2.Listname = 'MASTFAC' AND CL2.udf04=Orders.Doctype           --CS01
     --LEFT JOIN CODELKUP CL2 (NOLOCK) ON ORDERS.Facility = CL2.Short AND CL2.Listname = 'MASTFAC'                             --CS01
     --LEFT JOIN CODELKUP CL3 (NOLOCK) ON CL2.UDF04 = CL3.Short AND CL3.Listname = 'MASTFAC'                                   --CS01
     WHERE ORDERS.OrderKey = @c_OrderKey

     SELECT @n_CTNQTY1 = COUNT(DISTINCT DROPID)
     FROM PICKDETAIL PD WITH (NOLOCK)
     JOIN ORDERS O WITH (NOLOCK) ON PD.Orderkey = O.Orderkey
     WHERE O.Loadkey = @c_Loadkey
     GROUP By O.Loadkey

     SELECT @n_Weight = SUM(PD.QTY * S.STDGROSSWGT)
     FROM PICKDETAIL PD WITH (NOLOCK)
     JOIN SKU S WITH (NOLOCK) ON PD.SKU = S.SKU
     JOIN ORDERS O WITH (NOLOCK) ON PD.Orderkey = O.Orderkey
     WHERE O.Loadkey = @c_Loadkey
     GROUP By O.Loadkey
     
     SELECT @c_ToLoc = ISNULL(FACILITY.UserDefine04,'')
     FROM FACILITY (NOLOCK)
     WHERE Facility =  @c_ToFacility

     IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63490
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                        ' (ispPopulateTOASN_LBI2)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END

     IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)
		 BEGIN
		 	SET @n_continue = 3
		 	SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	SET @n_err = 63495
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                        ' (ispPopulateTOASN_LBI2)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END

     /*
		 IF NOT EXISTS ( SELECT 1 FROM STORER WITH (NOLOCK) WHERE Storerkey = @c_ToStorerkey )
		 BEGIN
		 	  SET @n_continue = 3
		 	  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		 	  SET @n_err = 63497
	    	SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Storer Key: ' + RTRIM(ISNULL(@c_ToStorerkey,'')) +
                        ' (ispPopulateTOASN_LBI2)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		 END
     */
     
	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN
	      IF ISNULL(RTRIM(@c_ToStorerKey),'') <> '' -- IS NOT NULL
	      BEGIN
	      	 SET @c_FoundReceiptKey = ''
	      	 
	      	 SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
	      	 FROM RECEIPT(NOLOCK)
	      	 WHERE Externreceiptkey = @c_ExternReceiptKey
	      	 AND storerkey = @c_ToStorerKey
	      	 AND Rectype = @c_Type
	      	 AND Facility = @c_ToFacility
	      	 AND Doctype = 'A'
	      	 AND POKey = @c_Loadkey
	      	 AND CarrierKey = @c_Carrierkey
	      	 AND ISNULL(Externreceiptkey,'') <> ''
	      	 AND ISNULL(POKey,'') <> ''
	      	 
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
	               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey, RecType, Facility, DocType, CarrierKey, POKey,
	                                    Userdefine02, Userdefine03, CTNQTY1, NoofMasterCtn, WEIGHT, WeightUnit )
	               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_ToStorerKey, @c_Type, @c_ToFacility, 'A', @c_Carrierkey, @c_Loadkey,
	                       @c_Userdefine02, @c_Userdefine03, @n_CTNQTY1, @n_CTNQTY1, @n_WEIGHT, @n_WeightUnit)

				      	 SET @n_err = @@Error
                 IF @n_err <> 0
                 BEGIN
 	            	   SET @n_continue = 3
	                 SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				           SET @n_err = 63498
	   		           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_LBI2)' + ' ( ' +
                                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                 END
	            END
	            ELSE
	            BEGIN
	               SET @n_continue = 3
	               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
					       SET @n_err = 63499
	   			       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_LBI2)'
	   			                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	            END
	         END
	      END
	      ELSE
	      BEGIN
	         SET @n_continue = 3
	         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 63500
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_LBI2)' + ' ( ' +
                         ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	      END
	   END -- if continue = 1 or 2

	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN
	      SELECT @n_LineNo = 1
	      
	      IF ISNULL(@c_FoundReceiptKey,'') <> ''
	      BEGIN
	      	 SELECT @n_LineNo = CONVERT(INT,MAX(ReceiptLineNumber)) + 1
	      	 FROM RECEIPTDETAIL (NOLOCK)
	      	 WHERE Receiptkey = @c_FoundReceiptKey

	      	 IF ISNULL(@n_LineNo,0) = 0
	      	    SET @n_LineNo = 1
	      END
	      
		    IF ISNULL(RTRIM(@c_OrderKey),'') <> '' 
		    BEGIN
		         DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR
                SELECT PICKDETAIL.SKU,
	                     PACK.PackKey,
	                     PACK.PACKUOM3,
	                     '', --ExternLineNo
	                     SKU.AltSku,
	                     '', --Lottable01
	                     LOTATTRIBUTE.Lottable02,
	                     --LOTATTRIBUTE.Lottable03,                 --CS01
	                     PICKDETAIL.Dropid,                         --CS01
	                     LOTATTRIBUTE.Lottable04,           
	                     LOTATTRIBUTE.Lottable06,
	                     LOTATTRIBUTE.Lottable07,
	                     LOTATTRIBUTE.Lottable08,
	                     LOTATTRIBUTE.Lottable09,
	                     LOTATTRIBUTE.Lottable10,
	                     LOTATTRIBUTE.Lottable13, --NJOW02
  			               ORDERDETAIL.Externorderkey,
				               ORDERDETAIL.UserDefine01,
				               PICKDETAIL.DropID,
				               ORDERDETAIL.UserDefine02,
                       SUM(PICKDETAIL.Qty) AS Qty
                FROM ORDERDETAIL WITH (NOLOCK)
	              JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
	              JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku)
	              JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey 
                                             AND PICKDETAIL.Orderlinenumber = ORDERDETAIL.Orderlinenumber
                JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = PICKDETAIL.LOT AND LOTATTRIBUTE.SKU = PICKDETAIL.SKU
                                                AND LOTATTRIBUTE.Storerkey = PICKDETAIL.Storerkey
	              WHERE ( PICKDETAIL.Qty > 0 ) AND
	                    ( ORDERDETAIL.OrderKey = @c_orderkey ) 
	              GROUP BY PICKDETAIL.SKU,
	                       PACK.PackKey,
	                       PACK.PACKUOM3,
	                       SKU.AltSku,
	                       LOTATTRIBUTE.Lottable02,
	                       --LOTATTRIBUTE.Lottable03,
	                       PICKDETAIL.Dropid,                         --CS01
	                       LOTATTRIBUTE.Lottable04,           
	                       LOTATTRIBUTE.Lottable06,
	                       LOTATTRIBUTE.Lottable07,
	                       LOTATTRIBUTE.Lottable08,
	                       LOTATTRIBUTE.Lottable09,
	                       LOTATTRIBUTE.Lottable10,
	                       LOTATTRIBUTE.Lottable13, 
  			                 ORDERDETAIL.Externorderkey,
				                 ORDERDETAIL.UserDefine01,
				                 PICKDETAIL.DropID,
				                 ORDERDETAIL.UserDefine02
	              ORDER BY PICKDETAIL.Sku

			       OPEN PICK_CUR

			       FETCH NEXT FROM PICK_CUR INTO @c_SKU,@c_PackKey,@c_UOM,@c_ExternOrderLine,@c_ALTSKU,@c_Lottable01,
                                           @c_Lottable02,@c_Lottable03,@d_Lottable04,@c_Lottable06, 
                                           @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@d_Lottable13,@c_ContainerkeyDet,
                                           @c_ExternPokey,@c_Userdefine01Det,@c_Userdefine02Det,@n_QtyReceived

			       WHILE @@FETCH_STATUS <> -1
			       BEGIN
			          SELECT @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)
			          
			          SELECT @c_ExternOrderLine = @c_ReceiptLine 

				        IF @n_QtyReceived IS NULL
			             SELECT @n_QtyReceived = 0

				        IF NOT EXISTS ( SELECT 1 FROM SKU WITH (NOLOCK) Where Storerkey = @c_ToStorerkey AND Sku = @c_sku AND ACTIVE='1' )
				        BEGIN
 	                 SET @n_continue = 3
	                 SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				           SET @n_err = 63501
	   		           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Sku: ' + RTRIM(@c_Sku) + 'Of Storer: '+ RTRIM(@c_ToStorerkey) + ' (ispPopulateTOASN_LBI2)' + ' ( ' +
                                 ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
				        END

                SET @n_CaseCnt = 0
                SET @n_GrossWgt = 0
                SET @n_NetWgt = 0
                
                SELECT  @n_CaseCnt = SUM(PD.QTY)
                       ,@n_GrossWgt = SUM(PD.QTY * S.STDGROSSWGT)
                       ,@n_NetWgt = SUM(PD.QTY * S.STDNETWGT)
                FROM PICKDETAIL PD WITH (NOLOCK)
                JOIN SKU S WITH (NOLOCK) ON PD.SKU = S.SKU
                JOIN ORDERS O WITH (NOLOCK) ON PD.Orderkey = O.Orderkey
                WHERE O.Loadkey = @c_Loadkey
                AND PD.Dropid = @c_Userdefine01Det
                GROUP By O.Loadkey, PD.DropID
                     
			          SET @c_GetUserdefine01Det = ''

                IF LEN(@c_Userdefine01Det) = 18
                BEGIN                                  
                   SET @c_GetUserdefine01Det = '00'+ @c_Userdefine01Det
                   IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Labelno = @c_GetUserdefine01Det)
                   BEGIN
                      SET @c_Userdefine01Det = @c_GetUserdefine01Det
                   END
			          END                            

			          INSERT INTO RECEIPTDETAIL (ReceiptKey,   			  ReceiptLineNumber,   ExternReceiptkey,
			                                     ExternLineNo, 			  StorerKey,           SKU,
			                                     QtyExpected,  			  QtyReceived,
			                                     UOM,          			  PackKey,              ToLoc,		lottable01,
			                                     Lottable02,              Lottable03,   			Lottable04,	Lottable06,
			                                     Lottable07,				  Lottable08,				Lottable09,	Lottable10,
				 							         	 Lottable13,				  BeforeReceivedQty,    FinalizeFlag, 
			                                     Containerkey,				  AltSku,					CaseCnt,		GrossWgt,		NetWgt,
			                                     Externpokey,				  Userdefine01,			Userdefine02,ConditionCode )
			                      VALUES        (@c_NewReceiptKey, 	 @c_ReceiptLine,      @c_ExternReceiptkey,
			                                     @c_ExternOrderLine,  @c_ToStorerKey,      @c_SKU,
			                                     @n_QtyReceived,      0,
			                                     @c_UOM,              @c_Packkey,          @c_Toloc,	@c_ExternPokey,
			                                     @c_Lottable02,       @c_Lottable03,   		 @d_Lottable04, @c_Lottable06,
			                                     @c_Lottable07,		 @c_Lottable08,			 @c_Lottable09,	@c_Lottable10,
				 								     		 @d_Lottable13,				0,                   'N', 
			                                     @c_ContainerkeyDet,	@c_ALTSKU,					 @n_CaseCnt,		@n_GrossWgt,	@n_NetWgt,
			                                     @c_ExternPokey,			@c_Userdefine01Det,  @c_Userdefine02Det, 'OK' )

			          SELECT @n_LineNo = @n_LineNo + 1

			          FETCH NEXT FROM PICK_CUR INTO @c_SKU,@c_PackKey,@c_UOM,@c_ExternOrderLine,@c_ALTSKU,@c_Lottable01,
                                              @c_Lottable02,@c_Lottable03,@d_Lottable04,@c_Lottable06, 
                                              @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@d_Lottable13,@c_ContainerkeyDet,
                                              @c_ExternPokey,@c_Userdefine01Det,@c_Userdefine02Det,@n_QtyReceived
			       END -- WHILE @@FETCH_STATUS <> -1
			       CLOSE PICK_CUR
			       DEALLOCATE PICK_CUR
		    END
     END

     /*
     IF @n_continue = 1 OR @n_continue = 2
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
     END
     */

		 QUIT_SP:

		 IF @n_continue = 3  -- Error Occured - Process And Return
	    BEGIN
	      SELECT @b_success = 0

	      --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	      --BEGIN
	         --ROLLBACK TRAN
	      --END
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_LBI2'
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