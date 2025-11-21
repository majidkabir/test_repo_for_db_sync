SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_Pick_Accuracy_Check] (
 		@ac_loadkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/************************************************************************/
/* SP: isp_Pick_Accuracy_Check					                  			*/
/* Creation Date: 28 Jan 2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Wally																		*/
/*                                                                      */
/* Purpose: Retrieve records for consolidated picklist summary				*/
/*				from the customized report module                 				*/
/*                                                                      */
/* Input Parameters: loadkey															*/
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage: Print Picking Accuracy Check Sheet (loadplan reports)			*/
/*			 Designed for C4LGMY         												*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: Customized Report					                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */
/*                                                                      */
/*                                                                      */
/************************************************************************/

	DECLARE @c_storerkey NVARCHAR(18),
		@c_sku NVARCHAR(20),
		@c_barcode  NVARCHAR(30),
		@c_barcode1 NVARCHAR(30),
		@c_barcode2 NVARCHAR(30),
		@c_barcode3 NVARCHAR(30),
		@c_barcode4 NVARCHAR(30),
		@c_barcode5 NVARCHAR(30),
		@n_cnt int

	-- create a temp result table
	CREATE TABLE #RESULT (
		storerkey NVARCHAR(18),
		loadkey NVARCHAR(10),
		consigneekey NVARCHAR(15) NULL,
		company NVARCHAR(45) NULL,
		adddate datetime,
		sku NVARCHAR(20),
		casecnt int,
		descr NVARCHAR(60),
		barcode1 NVARCHAR(30),
		barcode2 NVARCHAR(30),
		barcode3 NVARCHAR(30),
		barcode4 NVARCHAR(30),
		barcode5 NVARCHAR(30)
	)
	
	-- insert records into temp result table #RESULT
	INSERT #RESULT
		SELECT ORDERS.StorerKey,
			LoadPlan.LoadKey,   
         ORDERS.ConsigneeKey,   
			STORER.Company,
         LoadPlan.AddDate,   
         ORDERDETAIL.Sku,   
         PACK.CaseCnt,
			SKU.Descr,
			'', -- barcode1
			'', -- barcode2
			'', -- barcode3
			'', -- barcode4
			'' -- barcode5
    FROM LoadPlan (NOLOCK),   
         ORDERDETAIL (NOLOCK),   
         ORDERS (NOLOCK)
         LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey),
         PACK (NOLOCK),   
         SKU (NOLOCK)
   WHERE ( LoadPlan.LoadKey = ORDERDETAIL.LoadKey ) and  
         ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) and  
         ( SKU.PackKey = PACK.PACKKey ) and  
         ( SKU.StorerKey = ORDERDETAIL.StorerKey ) and  
         ( SKU.Sku = ORDERDETAIL.Sku ) and  
         ( LoadPlan.LoadKey = @ac_loadkey )    

	-- assume 1 loadplan = 1 storer
	SELECT @c_storerkey = MAX(storerkey)
	FROM #RESULT

	CREATE TABLE #TEMPBARCODE
	    (Storerkey NVARCHAR(15) NULL,
		 SKU NVARCHAR(20) NULL,
	    Barcode NVARCHAR(30) NULL,
		 Rowid int NOT NULL IDENTITY (1, 1))

	-- process each distinct sku from #RESULT to determine the barcodes
	SELECT @c_sku = ''
	WHILE (1=1)
	BEGIN -- while
		SELECT @c_sku = MIN(sku)
		FROM #RESULT
		WHERE sku > @c_sku

		IF ISNULL(@c_sku,'') = ''
			BREAK

		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, MANUFACTURERSKU 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @c_storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(MANUFACTURERSKU)) IS NOT NULL
	
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, ALTSKU 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @c_storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(ALTSKU)) IS NOT NULL
			
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, RetailSku 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @c_storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(RetailSku)) IS NOT NULL

		SET ROWCOUNT 5
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, UPC 
		FROM UPC (NOLOCK)
		WHERE Storerkey = @c_storerkey
			AND Sku = @c_sku
		SET ROWCOUNT 0
		
		DECLARE bc_cursor CURSOR FAST_FORWARD READ_ONLY FOR
		 SELECT DISTINCT Storerkey, Sku 
		 FROM   #TEMPBARCODE 
		OPEN bc_cursor
		FETCH NEXT FROM bc_cursor INTO @c_storerkey, @c_Sku 
		WHILE @@FETCH_STATUS <> -1
		BEGIN 
			SELECT @c_barcode1 = '', @c_barcode2 = '', @c_barcode3 = '', @c_barcode4 = '', @c_barcode5 = ''
		
			SELECT @n_cnt = 1
			DECLARE bc1_cursor CURSOR FAST_FORWARD READ_ONLY FOR
			    SELECT Barcode 
			    FROM   #TEMPBARCODE 
				 WHERE  Storerkey = @c_storerkey
				 AND    Sku = @c_Sku 
				 order  by rowid
			OPEN bc1_cursor
			FETCH NEXT FROM bc1_cursor INTO @c_barcode
			WHILE @@FETCH_STATUS <> -1
			BEGIN 
					IF @n_cnt = 1
						SELECT @c_barcode1 = @c_barcode
					IF @n_cnt = 2
						SELECT @c_barcode2 = @c_barcode
					IF @n_cnt = 3
						SELECT @c_barcode3 = @c_barcode
					IF @n_cnt = 4
						SELECT @c_barcode4 = @c_barcode
					IF @n_cnt = 5
					BEGIN
						SELECT @c_barcode5 = @c_barcode
						BREAK
					END
					Select @n_cnt = @n_cnt + 1
		
					FETCH NEXT FROM bc1_cursor INTO @c_barcode
			END
		
			UPDATE #RESULT
			    SET Barcode1=@c_barcode1,
			        Barcode2=@c_barcode2,
			        Barcode3=@c_barcode3,
			        Barcode4=@c_barcode4,
					  Barcode5=@c_barcode5
			WHERE SKU = @c_Sku
			CLOSE  bc1_cursor
			DEALLOCATE bc1_cursor
		
			FETCH NEXT FROM bc_cursor INTO @c_storerkey, @c_Sku 
		END 
		CLOSE  bc_cursor 
		DEALLOCATE bc_cursor
	END -- while
	 
	Drop table #TEMPBARCODE
	
	SELECT * FROM #RESULT
	
	DROP TABLE #RESULT

END /* main procedure */

GO