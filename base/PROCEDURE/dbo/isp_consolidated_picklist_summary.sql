SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_Consolidated_Picklist_Summary					                  */
/* Creation Date: 17 Jan 2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Wally																		*/
/*                                                                      */
/* Purpose: Retrieve records for consolidated picklist summary				*/
/*				from the customized report module                 				*/
/*                                                                      */
/* Input Parameters: 20 Pickslip numbers											*/
/*						   Storerkey                                         	*/
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage: Print Consolidated PickList Summary                           */
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
/* 17-Jan-2004                Initial Version                           */
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_Consolidated_Picklist_Summary] (
 		@ac_pickslipno1 NVARCHAR(10),
		@ac_pickslipno2 NVARCHAR(10),	
		@ac_pickslipno3 NVARCHAR(10),
		@ac_pickslipno4 NVARCHAR(10),
		@ac_pickslipno5 NVARCHAR(10),
		@ac_pickslipno6 NVARCHAR(10),
		@ac_pickslipno7 NVARCHAR(10),
		@ac_pickslipno8 NVARCHAR(10),
		@ac_pickslipno9 NVARCHAR(10),
		@ac_pickslipno10 NVARCHAR(10),
		@ac_pickslipno11 NVARCHAR(10),
		@ac_pickslipno12 NVARCHAR(10),	
		@ac_pickslipno13 NVARCHAR(10),
		@ac_pickslipno14 NVARCHAR(10),
		@ac_pickslipno15 NVARCHAR(10),
		@ac_pickslipno16 NVARCHAR(10),
		@ac_pickslipno17 NVARCHAR(10),
		@ac_pickslipno18 NVARCHAR(10),
		@ac_pickslipno19 NVARCHAR(10),
		@ac_pickslipno20 NVARCHAR(10),
		@ac_storerkey NVARCHAR(18)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @c_sku NVARCHAR(20),
		@c_barcode  NVARCHAR(30),
		@c_barcode1 NVARCHAR(30),
		@c_barcode2 NVARCHAR(30),
		@c_barcode3 NVARCHAR(30),
		@c_barcode4 NVARCHAR(30),
		@c_barcode5 NVARCHAR(30),
		@n_cnt int

	-- create a temp result table
	CREATE TABLE #CONSOLIDATED (
		storerkey NVARCHAR(18),
		sku NVARCHAR(20),
		loc NVARCHAR(10),
		descr NVARCHAR(60),
		lottable01 NVARCHAR(18) NULL,
		lottable02 NVARCHAR(18) NULL,
		lottable03 NVARCHAR(18) NULL,
		lottable04 datetime NULL,
		qty int,
		packkey NVARCHAR(10),
		packuom3 NVARCHAR(10),
		logicallocation NVARCHAR(18) NULL,
		pickheaderkey NVARCHAR(10) NULL,
		externorderkey NVARCHAR(30) NULL,
		packuom1 NVARCHAR(10),
		casecnt int,
		barcode1 NVARCHAR(30),
		barcode2 NVARCHAR(30),
		barcode3 NVARCHAR(30),
		barcode4 NVARCHAR(30),
		barcode5 NVARCHAR(30)
	)
	
	-- insert records into temp result table #CONSOLIDATED
	INSERT #CONSOLIDATED
		SELECT PICKDETAIL.StorerKey, 
				PICKDETAIL.Sku,   
			   PICKDETAIL.LOC,  
	         SKU.DESCR,   
	         LOTATTRIBUTE.Lottable01,   
	         LOTATTRIBUTE.Lottable02,   
	         LOTATTRIBUTE.Lottable03,   
	         LOTATTRIBUTE.Lottable04,   
	         Qty=SUM(PICKDETAIL.Qty),   
	         SKU.PACKKey,   
	         PACK.PackUOM3, 
				LOC.LogicalLocation,
				PICKHEADER.PickHeaderKey,
				PICKHEADER.ExternOrderKey,
				PACK.PackUOM1,
				PACK.CaseCnt,
				'' as BarCode1,
				'' as BarCode2,
				'' as BarCode3,
				'' as BarCode4,
				'' as BarCode5
	    FROM LOTATTRIBUTE (NOLOCK),   
	         PICKDETAIL (NOLOCK),   
	         SKU (NOLOCK),   
	         PACK (NOLOCK), 
				LOC (NOLOCK),
				PICKHEADER (NOLOCK)   									
	   WHERE ( LOTATTRIBUTE.LOT = PICKDETAIL.LOT ) AND  
	         ( SKU.StorerKey = PICKDETAIL.Storerkey ) AND  
	         ( SKU.Sku = PICKDETAIL.Sku ) AND
	         ( SKU.PackKey = PACK.PackKey ) AND
				( PICKDETAIL.LOC = LOC.LOC ) AND
				( PICKHEADER.PickHeaderKey = PICKDETAIL.PickSlipNo ) AND
				( PICKDETAIL.PickSlipNo IN (@ac_pickslipno1, @ac_pickslipno2, @ac_pickslipno3, @ac_pickslipno4,
													@ac_pickslipno5, @ac_pickslipno6, @ac_pickslipno7, @ac_pickslipno8,
													@ac_pickslipno9, @ac_pickslipno10, @ac_pickslipno11, @ac_pickslipno12,	
													@ac_pickslipno13, @ac_pickslipno14, @ac_pickslipno15, @ac_pickslipno16,
													@ac_pickslipno17, @ac_pickslipno18, @ac_pickslipno19, @ac_pickslipno20) ) AND
				( PICKDETAIL.StorerKey = CASE 
													WHEN @ac_storerkey > '' THEN @ac_storerkey
													ELSE PICKDETAIL.StorerKey
												 END )
		GROUP BY PICKDETAIL.StorerKey,
				PICKDETAIL.Sku,   
			   PICKDETAIL.LOC,
	         SKU.DESCR,   
	         LOTATTRIBUTE.Lottable01,   
	         LOTATTRIBUTE.Lottable02,   
	         LOTATTRIBUTE.Lottable03,   
	         LOTATTRIBUTE.Lottable04,   
	         SKU.PACKKey,   
	         PACK.PackUOM3, 
				LOC.LogicalLocation,
				PICKHEADER.PickHeaderKey,
				PICKHEADER.ExternOrderKey,
				PACK.PackUOM1,
				PACK.CaseCnt

		
	CREATE TABLE #TEMPBARCODE
	    (Storerkey NVARCHAR(15) NULL,
		 SKU NVARCHAR(20) NULL,
	    Barcode NVARCHAR(30) NULL,
		 Rowid int NOT NULL IDENTITY (1, 1))

	-- process each distinct sku from #CONSOLIDATED to determine the barcodes
	SELECT @c_sku = ''
	WHILE (1=1)
	BEGIN -- while
		SELECT @c_sku = MIN(sku)
		FROM #CONSOLIDATED
		WHERE sku > @c_sku

		IF ISNULL(@c_sku,'') = ''
			BREAK

		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, MANUFACTURERSKU 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @ac_Storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(MANUFACTURERSKU)) IS NOT NULL
	
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, ALTSKU 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @ac_Storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(ALTSKU)) IS NOT NULL
			
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, RetailSku 
		FROM SKU (NOLOCK)
		WHERE Storerkey = @ac_Storerkey
			AND Sku = @c_sku
			AND dbo.fnc_LTrim(dbo.fnc_RTrim(RetailSku)) IS NOT NULL

		SET ROWCOUNT 5
		INSERT INTO #TEMPBARCODE (Storerkey, SKU, Barcode)
		SELECT StorerKey, SKU, UPC 
		FROM UPC (NOLOCK)
		WHERE Storerkey = @ac_Storerkey
			AND Sku = @c_sku
		SET ROWCOUNT 0
		
		DECLARE bc_cursor CURSOR FAST_FORWARD READ_ONLY FOR
		 SELECT DISTINCT Storerkey, Sku 
		 FROM   #TEMPBARCODE 
		OPEN bc_cursor
		FETCH NEXT FROM bc_cursor INTO @ac_storerkey, @c_Sku 
		WHILE @@FETCH_STATUS <> -1
		BEGIN 
			SELECT @c_barcode1 = '', @c_barcode2 = '', @c_barcode3 = '', @c_barcode4 = '', @c_barcode5 = ''
		
			SELECT @n_cnt = 1
			DECLARE bc1_cursor CURSOR FAST_FORWARD READ_ONLY FOR
			    SELECT Barcode 
			    FROM   #TEMPBARCODE 
				 WHERE  Storerkey = @ac_storerkey
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
		
			UPDATE #CONSOLIDATED
			    SET Barcode1=@c_barcode1,
			        Barcode2=@c_barcode2,
			        Barcode3=@c_barcode3,
			        Barcode4=@c_barcode4,
					  Barcode5=@c_barcode5
			WHERE Storerkey = @ac_storerkey
			AND SKU = @c_Sku
			CLOSE  bc1_cursor
			DEALLOCATE bc1_cursor
		
			FETCH NEXT FROM bc_cursor INTO @ac_storerkey, @c_Sku 
		END 
		CLOSE  bc_cursor 
		DEALLOCATE bc_cursor
	END -- while
	 
	Drop table #TEMPBARCODE
	
	SELECT * FROM #CONSOLIDATED
	
	DROP TABLE #CONSOLIDATED

END /* main procedure */

GO