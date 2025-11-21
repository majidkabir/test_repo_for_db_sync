SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_populate_receipt_nzmm									*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Mary Vong                                                */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Feb-2007	 June				SOS68834 - Fonterra NZMM, default lot03   */
/*										with 'HOLD' if SKUConfig setup exists		*/
/************************************************************************/

CREATE PROC [dbo].[isp_populate_receipt_nzmm] (
@c_stdkey NVARCHAR(10),
@c_storer NVARCHAR(18),
@c_logwhse NVARCHAR(18),
@c_vessel NVARCHAR(10), 
@c_facility NVARCHAR(5),
@c_receiptkey NVARCHAR(10) OUTPUT
)
AS
-- executed from PLS application when the final STD document is printed
BEGIN -- main
	 SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
	DECLARE @b_success int,
				@n_err int,
				@c_errmsg NVARCHAR(250),
				@c_stdlineno NVARCHAR(5),
				@c_sku NVARCHAR(20),
				@n_qty int,
				@c_id NVARCHAR(18),
				@c_batchno NVARCHAR(18),
				@d_proddate datetime,
				@n_weight float,
				@c_toloc NVARCHAR(10), 
				@c_month NVARCHAR(4),
				@c_day NVARCHAR(4),
				@c_year NVARCHAR(4),
				@c_packkey NVARCHAR(10),
				@c_lottable02 NVARCHAR(18),
				@c_uom NVARCHAR(10),
      		@c_storerkey NVARCHAR(15),
				@c_Lottable03 NVARCHAR(18),  -- SOS68834
				@c_HoldByLottable02 NVARCHAR(1)  -- SOS68834

	SET NOCOUNT ON

	EXECUTE nspg_getkey
		'receipt'
		, 10
		, @c_receiptkey OUTPUT
		, @b_success OUTPUT
		, @n_err OUTPUT
		, @c_errmsg OUTPUT	

	IF @b_success = 1
	BEGIN -- @b_success = 1
		BEGIN TRAN -- create receipt header
		-- Modified by MaryVong on 18-Jun-2004 (SOS24373 - Change RecType from 'NORMAL' to 'STD')
		INSERT receipt (rectype, receiptkey, externreceiptkey, storerkey, origincountry, facility, carrierkey, doctype)
 		VALUES ('STD', @c_receiptkey, @c_stdkey, @c_storer, @c_logwhse, @c_facility, @c_storer, 'A')


		IF @@error = 0
		BEGIN -- no error for receipt header	
			COMMIT TRAN
			
			SELECT @c_stdlineno = ''
			WHILE (2=2)
			BEGIN
				SET ROWCOUNT 1
				SELECT @c_stdlineno = stdlineno, 
		             			@c_storerkey = storerkey, 
          		    			@c_sku = sku , 
			          		@n_qty = qty, 
               	 			@c_id = id, 
		             			@c_batchno = batchno,
					    	@d_proddate = CONVERT(datetime, convert(char(10), productiondate, 101),101), @n_weight = weight
				FROM 	  idsStkTrfDocDetail (NOLOCK)
				WHERE stdno = @c_stdkey
				AND 	 stdlineno > @c_stdlineno
				ORDER BY stdlineno

				IF @@rowcount = 0 BREAK

				SET ROWCOUNT 0
				SELECT @c_packkey = pack.packkey
				FROM 	 PACK (nolock) 
				JOIN   SKU (NOLOCK) ON PACK.packkey = SKU.packkey
				WHERE  storerkey = @c_storerkey
				AND 	 sku = @c_sku

				SELECT @c_toloc = dbo.fnc_RTrim(userdefine04)
				FROM 	   Facility (nolock)
				WHERE  Facility = @c_facility

				SELECT @c_uom = uom
				FROM 	   idsPallet (NOLOCK)
				WHERE  id = @c_id

				-- Start : SOS68834
				SELECT @c_HoldByLottable02 = ISNULL(Data, '0')
				FROM   SKUConfig (NOLOCK)
				WHERE  StorerKey = @c_storerkey
				AND    SKU = @c_sku 
				AND    ConfigType = 'HoldByLottable02'
				AND    Data = '1'

				IF @c_HoldByLottable02 = '1'
					SET @c_Lottable03 = 'HOLD'
				ELSE
					SET @c_Lottable03 = ''
				-- End : SOS68834

				BEGIN TRAN -- insert receipt details
 				INSERT RECEIPTDETAIL (ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, Sku, 
						 QtyExpected, Lottable02, Lottable03, Lottable04, ToId, Packkey, Uom, toloc, grosswgt, Vesselkey)
 				VALUES (@c_receiptkey, @c_stdlineno, @c_stdkey, @c_stdlineno, @c_storerkey, @c_sku, 
						 @n_qty, @c_batchno, @c_Lottable03, @d_proddate, @c_id, @c_packkey, @c_uom, @c_toloc, @n_weight, @c_vessel)

				IF @@error = 0
				BEGIN
					COMMIT TRAN
				END
				ELSE
				BEGIN
					SELECT @n_err = @@error
					--RAISERROR @n_err 'FAILED : Receipt Detail Insert'
					RAISERROR ('FAILED : Receipt Detail Insert', 16, 1) WITH SETERROR    -- SQL2012 
					ROLLBACK TRAN
			
					-- clean up successful details and header uploaded
					DELETE RECEIPT WHERE receiptkey = @c_receiptkey
					BREAK
				END
			END -- WHILE (2=2)
			SET ROWCOUNT 0

			-- update finalized flag to 'Y' > successfully populated		
			UPDATE idsStkTrfDoc
			SET finalized = 'Y'
			WHERE stdno = @c_stdkey						

			-- return result
			SELECT @c_receiptkey 'receiptkey'

		END -- no error for receipt header
		ELSE
		BEGIN
			SELECT @n_err = @@error
			--RAISERROR @n_err 'FAILED : Receipt Header Insert'
			RAISERROR ('FAILED : Receipt Header Insert', 16, 1) WITH SETERROR    -- SQL2012 
			ROLLBACK TRAN
		END
	END -- @b_success = 1
END -- main

GO