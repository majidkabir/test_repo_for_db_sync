SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspDeadStockRpt] ( 
			@c_StorerKey_Start NVARCHAR(15), 
			@c_StorerKey_End NVARCHAR(15), 
			@c_Sku_Start	 NVARCHAR(20), 
			@c_Sku_End		 NVARCHAR(20),  
			@c_NoMvNumDays	 NVARCHAR(4)   
)

-- For Dead Stock Report (FBR6070).
-- Created By YokeBeen on 18-Jul-2002

AS 
BEGIN -- Main Proc
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

CREATE TABLE [#Temp_DSR] (
	[StorerKey] [char] (15),  
	[Sku] [char] (20), 
	[Descr] [char] (60),  
	[Casecnt] [float] (8),  
	[StockOnHand] [int],  
	[LastMovementdate] [datetime] NULL,  
	[LastTransDate] [datetime] NULL,  
	[FirstReceiptDate] [datetime] NULL,  
	[POSellerName] [char] (45) NULL, 
	[Company] [char] (45) NULL,  
	[StorerKey_Start] [char] (15) NULL, 
	[StorerKey_End]	[char] (15) NULL, 
	[Sku_Start] [char] (20) NULL, 
	[Sku_End] [char] (20) NULL,  
	[NoMvNumDays] [char] (4) NULL )  


/* 1. Get record set from SKUxLOC Table into a temp table */
/*		Insert the records into the Temp_DSR table for report generation */
INSERT INTO #Temp_DSR 
			( StorerKey, Sku, Descr, Casecnt, StockOnHand, 
			  StorerKey_Start, StorerKey_End, Sku_Start, Sku_End, NoMvNumDays )   
SELECT	SKUxLOC.StorerKey,   
			SKUxLOC.Sku,   
			SKU.Descr, 
			PACK.CaseCnt,  
			StockOnhand = CASE WHEN PACK.CaseCnt = 0 THEN 0 
									 ELSE ( SUM(SKUxLOC.Qty) / PACK.CaseCnt ) 
							  END, 
			StorerKey_Start = @c_StorerKey_Start, 
			StorerKey_End = @c_StorerKey_End, 
			Sku_Start = @c_Sku_Start, 
			Sku_End = @c_Sku_End, 
			NoMvNumDays = @c_NoMvNumDays    
  FROM	SKUxLOC (NOLOCK) 
  JOIN	SKU (NOLOCK) ON ( SKUxLOC.Storerkey = SKU.StorerKey AND SKUxLOC.Sku = SKU.Sku ) 
  JOIN	PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
 WHERE	( SKUxLOC.StorerKey >= @c_StorerKey_Start AND SKUxLOC.StorerKey <= @c_StorerKey_End ) 
	AND	( SKUxLOC.Sku >= @c_Sku_Start AND SKUxLOC.Sku <= @c_Sku_End ) 
	AND	( SKUxLOC.Qty > 0 ) 
GROUP BY SKUxLOC.StorerKey,   
			SKUxLOC.Sku,   
			SKU.Descr, 
			PACK.CaseCnt  

-- First Cursor used to update the entire fields for each record.
DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR

SELECT StorerKey, Sku, LastMovementdate, LastTransDate, FirstReceiptDate  
  FROM #Temp_DSR (NOLOCK)

OPEN CUR1

DECLARE	@c_STORERKEY NVARCHAR(10),	
			@c_Sku NVARCHAR(20),		
			@dt_LastMovementdate DATETIME,		
			@dt_LastTransDate DATETIME,	
			@dt_FirstReceiptDate DATETIME	

FETCH NEXT FROM CUR1 INTO  @c_StorerKey, @c_Sku, @dt_LastMovementDate, @dt_LastTransDate, @dt_FirstReceiptDate	 
 

WHILE @@FETCH_STATUS <> -1
BEGIN

	/* Get the Last Movement Date for the Sku */
	SELECT	@dt_LastMovementDate = MAX(ORDERS.EditDate)  
	  FROM	ORDERDETAIL (NOLOCK) 
	  LEFT OUTER JOIN	ORDERS (NOLOCK) ON ( ORDERS.StorerKey = ORDERDETAIL.StorerKey AND ORDERS.OrderKey = ORDERDETAIL.OrderKey )   
	 WHERE	ORDERS.Status = '9' 
-- 	AND	DATEDIFF( DAY, ORDERS.EditDate, GETDATE() ) > @c_NoMvNumDays 
		AND	ORDERDETAIL.StorerKey = @c_StorerKey 
		AND	ORDERDETAIL.Sku = @c_Sku 
	GROUP BY ORDERDETAIL.Sku     

	/* Get the Last Transaction Date for the Sku */
	SELECT	@dt_LastTransDate = MAX(ITRN.AddDate) 
	  FROM	ITRN (NOLOCK)  
	 WHERE	ITRN.TranType = 'WD' 
	 	AND	ITRN.SourceType = 'ntrPickDetailUpdate'
	 	AND	ITRN.StorerKey = @c_StorerKey 
		AND	ITRN.Sku = @c_Sku 
	GROUP BY ITRN.Sku  

	/* Get the First Receipt Date for the Sku */
	SELECT	@dt_FirstReceiptDate = MIN(ITRN.AddDate) 
	  FROM	ITRN (NOLOCK)  
	 WHERE	ITRN.TranType = 'DP'  
	 	AND	ITRN.StorerKey = @c_StorerKey 
		AND	ITRN.Sku = @c_Sku 
	GROUP BY ITRN.Sku  


	UPDATE	#Temp_DSR
		SET	#Temp_DSR.LastMovementDate = @dt_LastMovementDate,    
				#Temp_DSR.LastTransDate = @dt_LastTransDate, 
				#Temp_DSR.FirstReceiptDate = @dt_FirstReceiptDate  
	 WHERE	#Temp_DSR.StorerKey = @c_StorerKey 
		AND	#Temp_DSR.Sku = @c_Sku 


	FETCH NEXT FROM CUR1 INTO  @c_StorerKey, @c_Sku, @dt_LastMovementDate, @dt_LastTransDate, @dt_FirstReceiptDate	 

END	
DEALLOCATE CUR1
-- Ended First Cursor.


/* 3. Filter those records that have shipment (WD) within the specific No Movement # Days */
DELETE	#Temp_DSR 
  FROM	#Temp_DSR (NOLOCK) 
  JOIN	ITRN (NOLOCK) ON ( #Temp_DSR.StorerKey = ITRN.StorerKey AND #Temp_DSR.Sku = ITRN.Sku ) 
 WHERE	ITRN.TranType = 'WD' 
	AND	ITRN.SourceType = 'ntrPickDetailUpdate'
	AND	DATEDIFF( DAY, ITRN.AddDate, #Temp_DSR.LastMovementDate ) > 0  
	AND	DATEDIFF( DAY, ITRN.AddDate, #Temp_DSR.LastMovementDate ) < @c_NoMvNumDays  


/* 4. For records with Balnk Movement Date, match the First ReceiptDate with Today Date 
		If difference < @c_NoMvNumDays Then Filter the record */
DELETE	#Temp_DSR 
  FROM	#Temp_DSR (NOLOCK)  
 WHERE	( #Temp_DSR.LastMovementDate = '' OR #Temp_DSR.LastMovementDate = NULL ) 
	AND	DATEDIFF( DAY, #Temp_DSR.FirstReceiptDate, GETDATE() ) < @c_NoMvNumDays  


/* 5. Populate the Vendor (PO.SellerName) */
/* 	Update the field into the Temp_DSR table for report generation */

-- Second Cursor used to update the entire fields for each record.
DECLARE CUR2 CURSOR FAST_FORWARD READ_ONLY FOR

SELECT StorerKey, Sku, posellername, company  
  FROM #Temp_DSR (NOLOCK)

OPEN CUR2

DECLARE	@c_POSellerName NVARCHAR(45),   
			@c_Company NVARCHAR(45)	

FETCH NEXT FROM CUR2 INTO  @c_StorerKey, @c_Sku, @c_POSellerName, @c_Company	 
 

WHILE @@FETCH_STATUS <> -1
BEGIN

	UPDATE	#Temp_DSR 
		SET	#Temp_DSR.POSellerName = PO.SellerName, 
				#Temp_DSR.Company = Storer.Company 
	  FROM	#Temp_DSR (NOLOCK) 
	  JOIN	PODETAIL (NOLOCK) ON ( #Temp_DSR.StorerKey = PODETAIL.StorerKey AND #Temp_DSR.Sku = PODETAIL.Sku ) 
	  JOIN	PO (NOLOCK) ON ( PODETAIL.StorerKey = PO.StorerKey AND PODETAIL.POKey = PO.POKey 
									  AND #Temp_DSR.StorerKey = PO.StorerKey )  
	  JOIN	STORER (NOLOCK) ON ( PO.SellerName = STORER.StorerKey )  
	 WHERE	PODETAIL.POKey IN ( SELECT MAX(PODETAIL.POKey) FROM PODETAIL (NOLOCK) WHERE PODETAIL.Sku = @c_Sku )  
		AND	#Temp_DSR.Sku = @c_Sku


	FETCH NEXT FROM CUR2 INTO  @c_StorerKey, @c_Sku, @c_POSellerName, @c_Company	 

END	
DEALLOCATE CUR2
-- Ended Second Cursor.


-- Retrieve overall data for Dead Stock Reporting.
select * from #Temp_DSR
-- End Retrieve.

DROP TABLE #Temp_DSR 

END -- End Procedure


GO