SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */

CREATE PROC [dbo].[isp_populate_receipt] (
@c_stdkey NVARCHAR(10),
@c_storer NVARCHAR(18),
@c_logwhse NVARCHAR(18),
@c_vessel NVARCHAR(10), 
@c_facility NVARCHAR(5),
@c_receiptkey NVARCHAR(10) OUTPUT
)
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
-- executed from PLS application when the final STD document is printed
-- Modified by MaryVong on 16-Apr-2004 (FBR21733) - requested by Claudia
-- UOM get from PACK.PackUOM1 instead of PACK.PackUOM3

	DECLARE @b_success 		int,
				@n_err 			int,
				@c_errmsg 	 NVARCHAR(250),
				@c_stdlineno  NVARCHAR(5),
				@c_sku 		 NVARCHAR(20),
				@n_qty 			int,
				@c_id 		 NVARCHAR(18),
				@c_batchno 	 NVARCHAR(18),
				@d_proddate 	datetime,
				@n_weight 		float,
				@c_toloc 	 NVARCHAR(10),
				@c_receiptloc  NVARCHAR(10), 
				@c_month 	 NVARCHAR(4),
				@c_day 		 NVARCHAR(4),
				@c_year 		 NVARCHAR(4),
				@c_packkey 	 NVARCHAR(10),
				@c_lottable02  NVARCHAR(18),
				@c_uom 		 NVARCHAR(10), 
				@c_storerkey  NVARCHAR(15) 

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
		INSERT RECEIPT (RecType, ReceiptKey, StorerKey, WarehouseReference, OriginCountry, Facility, DocType)
 			VALUES ('RPO', @c_receiptkey, @c_storer, @c_stdkey, @c_logwhse, @c_facility, 'A')


		IF @@ERROR = 0
		BEGIN -- no error for receipt header	
			COMMIT TRAN
			
			SELECT @c_stdlineno = ''
			WHILE (2=2)
			BEGIN
				SET ROWCOUNT 1
				SELECT @c_stdlineno = StdLineNo, 
						 @c_storerkey = StorerKey, 
  						 @c_sku = Sku , 
						 @n_qty = Qty, 
						 @c_id = Id, 
						 @c_batchno = BatchNo,
						 @d_proddate = CONVERT(datetime, CONVERT(char(10), productiondate, 101),101), @n_weight = Weight, 
						 @c_toloc = ToLoc
				  FROM idsStkTrfDocDetail (NOLOCK)
				 WHERE StdNo = @c_stdkey
				   AND StdLineNo > @c_stdlineno
				 ORDER BY StdLineNo

				IF @@ROWCOUNT = 0 BREAK

				SET ROWCOUNT 0
				SELECT @c_packkey = PACK.PackKey, 
						 @c_uom = PACK.PackUOM1  -- FBR21733
				  FROM PACK (NOLOCK) JOIN SKU (NOLOCK)
				    ON PACK.PackKey = SKU.PackKey
				 WHERE SKU.StorerKey = @c_storerkey
				   AND SKU.Sku = @c_sku

            SELECT @c_receiptloc = dbo.fnc_RTrim(UserDefine04)
              FROM FACILITY (NOLOCK)
             WHERE Facility = @c_facility

				BEGIN TRAN -- insert receipt details
 				INSERT RECEIPTDETAIL (ReceiptKey, ReceiptLineNumber, StorerKey, Sku, QtyExpected, Lottable03, 
 							  Lottable04, ToID, PackKey, UOM, ToLoc, GrossWgt, VoyageKey, Vesselkey, Lottable02)
 					VALUES (@c_receiptkey, @c_stdlineno, @c_storerkey, @c_sku, @n_qty, @c_logwhse, @d_proddate, @c_id, 
 							  @c_packkey, @c_uom, @c_receiptloc, @n_weight, @c_toloc, @c_vessel, @c_batchno)

				IF @@ERROR = 0
				BEGIN
					COMMIT TRAN
				END
				ELSE
				BEGIN
					SELECT @n_err = @@ERROR
					--RAISERROR @n_err 'FAILED : Receipt Detail Insert'
               RAISERROR ('FAILED : Receipt Detail Insert', 16, 1) WITH SETERROR    -- SQL2012
					ROLLBACK TRAN
			
					-- clean up successful details and header uploaded
					DELETE RECEIPT WHERE ReceiptKey = @c_receiptkey
					BREAK
				END
			END -- while (2=2)
			SET ROWCOUNT 0

			-- update finalized flag to 'Y' > successfully populated		
			UPDATE idsStkTrfDoc
			SET Finalized = 'Y'
			WHERE StdNo = @c_stdkey						

			-- return result
			SELECT @c_receiptkey 'receiptkey'

		END -- no error for receipt header
		ELSE
		BEGIN
			SELECT @n_err = @@ERROR
			--RAISERROR @n_err 'FAILED : Receipt Header Insert'
			RAISERROR ('FAILED : Receipt Header Insert', 16, 1) WITH SETERROR    -- SQL2012
			ROLLBACK TRAN
		END
	END -- @b_success = 1
END -- main

GO