SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_StockAgingByExpiry07C			                  */
/* Creation Date:  20-Oct-2004                                          */
/* Copyright: IDS                                                       */
/* Written by:  MaryVong                                                */
/*                                                                      */
/* Purpose:  Stock Aging by Expiry Date Report.								   */
/*                                                                      */
/* Input Parameters:  																	*/
/*                                                                      */
/* Output Parameters:  				                                       */
/*                                                                      */
/* Usage:  Stock Aging by Expiry Date Report.              					*/
/*                                                                      */
/* Called By: r_dw_stock_aging_by_expiry_date07c		                  */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 04-May-2006  ONG01	  SOS48954 - Add Batch No & Expiry Date			*/
/************************************************************************/

-- Duplicate from nsp_StockAgingByExpiry07 and modified
CREATE PROCEDURE [dbo].[nsp_StockAgingByExpiry07C] (
			@c_storerkey NVARCHAR(15),
		 	@c_fr_skugroup NVARCHAR(10),
			@c_to_skugroup NVARCHAR(10),
			@c_fr_sku NVARCHAR(20),
			@c_to_sku NVARCHAR(20),
			@c_agency_start NVARCHAR(18), 	-- Added By Vicky 10 June 2003 SOS#11541
         @c_agency_end NVARCHAR(18),  	-- Added By Vicky 10 June 2003 SOS#11541
			@c_facility_start NVARCHAR(5),	-- Added by MaryVong on 20Oct04 (SOS27265)	
			@c_facility_end NVARCHAR(5)		-- Added by MaryVong on 20Oct04 (SOS27265)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
            
DECLARE @c_storer 		 NVARCHAR(15), 
			@c_company 		 NVARCHAR(20),
			@c_product_group NVARCHAR(10),
			@c_product 		 NVARCHAR(20),
			@c_descr 		 NVARCHAR(60),
			@c_packkey 		 NVARCHAR(10),
			@d_expiry_date 	datetime,
			@i_total_qty 		int,
			@i_expired_qty		int,
			@c_lot 			 NVARCHAR(10),
			@c_agency 		 NVARCHAR(18),
			@c_location 	 NVARCHAR(10),	-- Added by MaryVong on 20Oct04 (SOS27265)
			@c_batch			 NVARCHAR(18),		-- ONG01
			@c_expiry_date		datetime			-- ONG01

DECLARE @i_lesstwo 		int,
			@i_twomth 		int,
			@i_threemth 	int,
			@i_fourmth 		int,
			@i_fivemth 		int,
			@i_sixmth		int,
			@i_moresix 		int,
			@i_morenine 	int,
			@i_moretwelve 	int,
			@i_days_apart	int

IF OBJECT_ID('tempdb..#temp_age') 		IS NOT NULL 	DROP TABLE #temp_age		-- ONG01

CREATE TABLE #temp_age
(
	storerkey  NVARCHAR(15) null,
	skugroup  NVARCHAR(20) null,
	sku 		 NVARCHAR(20) null,
	lot 		 NVARCHAR(10) null,
	descr 	 NVARCHAR(60) null,
	packkey 	 NVARCHAR(10) null,
	totalqty 	int null,
	expiredqty 	int null,
	lesstwo 		int null,
	twomth 		int null,	
	threemth		int null,
	fourmth 		int null,
	fivemth 		int null,
	sixmth 		int null,
	moresix 		int null,
	morenine 	int null,
	moretwelve	int null,
	agency 	 NVARCHAR(18) null,	-- Added By Vicky 10 June 2003 SOS#11541
	location  NVARCHAR(10) null,	-- Added by MaryVong on 20Oct04 (SOS27265)
	batchno	 NVARCHAR(18) null,	-- ONG01
	expirydate	datetime null	-- ONG01
)

SET NOCOUNT ON		-- ONG01
/** (1) cursor for getting the total quantity for each sku **/
DECLARE sku_stock CURSOR
LOCAL DYNAMIC
FOR
  SELECT STORER.StorerKey, STORER.Company,   
         SKU.SKUGROUP,   
         LOTxLOCxID.Sku,   
         SKU.DESCR,   
         SKU.PACKKey,     
			LOTxLOCxID.Lot,	
         SUM(LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)), -- Added By Vicky 05 Aug 2003 SOS#6811
         SKU.SUSR3,  	-- Added By Vicky 10 June 2003 SOS#11541
			LOC.Loc			-- Added by MaryVong on 20Oct04 (SOS27265)
			,LOTATTRIBUTE.Lottable02		-- ONG01
			,LOTATTRIBUTE.Lottable04		-- ONG01
    FROM SKU (NOLOCK),   
         STORER (NOLOCK),   
         LOTxLOCxID (NOLOCK),   
         LOTATTRIBUTE (NOLOCK),
			LOC (NOLOCK)	-- Added by MaryVong on 20Oct04 (SOS27265)
   WHERE ( STORER.StorerKey = SKU.StorerKey ) AND  
         ( LOTxLOCxID.StorerKey = SKU.StorerKey ) AND  
         ( LOTxLOCxID.Sku = SKU.Sku ) AND  
         ( LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey ) AND  
         ( LOTxLOCxID.Sku = LOTATTRIBUTE.Sku ) AND  
         ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) AND  
         ( LOTxLOCxID.StorerKey = @c_storerkey ) AND
			( LOTxLOCxID.Loc = LOC.Loc) AND 	-- Added by MaryVong on 20Oct04 (SOS27265)  
         ( SKU.SKUGROUP BETWEEN @c_fr_skugroup AND @c_to_skugroup ) AND  
         ( LOTxLOCxID.Sku BETWEEN @c_fr_sku AND @c_to_sku ) AND
         ( ISNULL(SKU.SUSR3,'') BETWEEN @c_agency_start AND @c_agency_end ) AND 	-- Added By Vicky 10 June 2003 SOS#11541
			( LOC.Facility BETWEEN @c_facility_start AND @c_facility_end ) 			-- Added by MaryVong on 20Oct04 (SOS27265)
   GROUP BY STORER.StorerKey, STORER.Company,   
         SKU.SKUGROUP,   
         LOTxLOCxID.Sku,   
         SKU.DESCR,   
         SKU.PACKKey,
			LOTXLOCXID.Lot,
			SKU.SUSR3,  -- Added By Vicky 10 June 2003 SOS#11541
			LOC.Loc		-- Added by MaryVong on 20Oct04 (SOS27265)
			,LOTATTRIBUTE.Lottable02		-- ONG01
			,LOTATTRIBUTE.Lottable04		-- ONG01

OPEN sku_stock

FETCH NEXT FROM sku_stock INTO	@c_storer, @c_company
				,@c_product_group
				,@c_product
				,@c_descr
				,@c_packkey
				,@c_lot
				,@i_total_qty
				,@c_agency 		-- Added By Vicky 10 June 2003 SOS#11541
				,@c_location	-- Added by MaryVong on 20Oct04 (SOS27265)
				,@c_batch 			-- ONG01
				,@c_expiry_date	-- ONG01
 
WHILE (@@fetch_status=0)
BEGIN
   SELECT	@i_expired_qty = NULL,
            @i_lesstwo		= NULL,
   			@i_twomth		= NULL,
   			@i_threemth		= NULL,
   			@i_fourmth		= NULL,
   			@i_fivemth		= NULL,
   			@i_sixmth		= NULL,
   			@i_moresix		= NULL,
   			@i_morenine		= NULL,
   			@i_moretwelve	= NULL,
				@d_expiry_date = NULL		-- ONG01	


   SELECT @d_expiry_date = LOTATTRIBUTE.Lottable04,   
          @i_expired_qty = SUM(LOTxLOCxID.qty - (LOTxLOCxID.Qtyallocated + LOTxLOCxID.QtyPicked)) -- Added By Vicky 05 Aug 2003 SOS#6811			 
       FROM SKU (NOLOCK),   
            STORER (NOLOCK),   
            LOTxLOCxID (NOLOCK),   
            LOTATTRIBUTE (NOLOCK),
				LOC (NOLOCK)	-- Added by MaryVong on 20Oct04 (SOS27265)  
      WHERE ( STORER.StorerKey = SKU.StorerKey ) AND  
            ( LOTxLOCxID.StorerKey = SKU.StorerKey ) AND  
            ( LOTxLOCxID.Sku = SKU.Sku ) AND  
            ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) AND  
            ( LOTxLOCxID.StorerKey = @c_storer ) AND
				( LOTxLOCxID.Loc = LOC.Loc) AND	-- Added by MaryVong on 20Oct04 (SOS27265)
            ( SKU.SKUGROUP = @c_product_group ) AND  
            ( LOTxLOCxID.Sku = @c_product ) AND  
   			( LOTXLOCXID.Lot = @c_lot) AND 
            ( LOTATTRIBUTE.Lottable04 > GETDATE() ) AND
            ( SKU.SUSR3 = @c_agency ) AND	-- Added By Vicky 10 June 2003 SOS#11541
				( LOC.Loc = @c_location )		-- Added by MaryVong on 20Oct04 (SOS27265)
   GROUP BY LOTATTRIBUTE.Lottable04   

   IF (@@FETCH_STATUS=0)
   BEGIN
   	SELECT @i_days_apart = DATEDIFF(DAY,@d_expiry_date,GETDATE())
   	
   	IF ABS(@i_days_apart) < 60 
   		SELECT @i_lesstwo = @i_expired_qty

		IF @i_lesstwo = 0
			SELECT @i_lesstwo = NULL
   	ELSE 
   		IF ((ABS(@i_days_apart) >= 60 ) AND (ABS(@i_days_apart) < 90 ))

		SELECT @i_twomth = @i_expired_qty

		IF @i_twomth = 0 
			SELECT @i_twomth = NULL
   	ELSE 
   		IF ((ABS(@i_days_apart) >= 90 ) AND (ABS(@i_days_apart) < 120))
      		SELECT @i_threemth = @i_expired_qty

		IF @i_threemth = 0
			SELECT @i_threemth = NULL
   	ELSE
   		IF ((ABS(@i_days_apart) >= 120 ) AND (ABS(@i_days_apart) < 150))

		SELECT @i_fourmth = @i_expired_qty

		IF @i_fourmth=0
			SELECT @i_fourmth = NULL
   	ELSE
   		IF ((ABS(@i_days_apart) >= 150 ) AND (ABS(@i_days_apart) < 180))

		SELECT @i_fivemth = @i_expired_qty

		IF @i_fivemth=0
			SELECT @i_fivemth = NULL
   	ELSE
   		IF ((ABS(@i_days_apart) >= 180) AND (ABS(@i_days_apart) < 210))

		SELECT @i_sixmth = @i_expired_qty

		IF @i_sixmth=0
			SELECT @i_sixmth = NULL

   	-- another if statement for qty more than 6, 9 , 12 months
   	IF ((ABS(@i_days_apart) >= 210) and (ABS(@i_days_apart) < 270))
   		SELECT @i_moresix = @i_expired_qty
   
   	ELSE
   		IF ((ABS(@i_days_apart) >= 270) AND (ABS(@i_days_apart) < 360))
      		SELECT @i_morenine = @i_expired_qty
      	ELSE
      		IF ABS(@i_days_apart) >= 360 
            	SELECT @i_moretwelve = @i_expired_qty

      	INSERT INTO #temp_age
      		VALUES(	@c_storer, 
      					@c_product_group,
      					@c_product,
      					@c_lot,
      					@c_descr,
      					@c_packkey,
      					@i_total_qty,
      					@i_expired_qty,
      					@i_lesstwo,
      					@i_twomth,
      					@i_threemth,
      					@i_fourmth,
      					@i_fivemth,
      					@i_sixmth,
      					@i_moresix,
      					@i_morenine,
      					@i_moretwelve,
      					@c_agency,		-- Added By Vicky 10 June 2003 SOS#11541
							@c_location, 	-- Added by MaryVong on 20Oct04 (SOS27265)              
							@c_batch,			-- ONG01
							@c_expiry_date	)	-- ONG01
							
   END
   
   FETCH NEXT FROM sku_stock INTO	@c_storer, @c_company
   				,@c_product_group
   				,@c_product
   				,@c_descr
   				,@c_packkey
   				,@c_lot
   				,@i_total_qty
   				,@c_agency 		-- Added By Vicky 10 June 2003 SOS#11541
					,@c_location	-- Added by MaryVong on 20Oct04 (SOS27265)
					,@c_batch 			-- ONG01
					,@c_expiry_date	-- ONG01
END

--close stock_age
--deallocate stock_age

CLOSE sku_stock
DEALLOCATE sku_stock

-- Added by SHONG
-- SOS# 8277
-- Replace the code I commented above
-- Remove all the sku that have ZERO qty expired
DELETE #temp_age
FROM #temp_age
JOIN ( SELECT storerkey, sku, SUM( ISNULL(expiredqty,0)) AS expiredqty
       FROM  #temp_age 
       GROUP BY storerkey, sku
       HAVING SUM( ISNULL(expiredqty,0)) = 0) AS non_expired
   ON non_expired.storerkey = #temp_age.storerkey AND non_expired.sku = #temp_age.sku 
-- End

SELECT * FROM #temp_age 

DROP TABLE #temp_age

END

GO