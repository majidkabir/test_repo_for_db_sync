SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_diageosg_deliverylabel									*/
/* Creation Date: 15-May-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Diageo SG - RCM Delivery Case Label printing.					*/
/*          It generates x number of label according to allocated qty	*/
/*				converted to cases. Say, SKU A allocated 100EA=10CS			*/
/*				with lot01 CH01 40, CH02 50 & CH03 10. The label shall be	*/
/* 			SKU A, lot01 CH01 1 of 10, 2 of 10 to 4 of 10, 					*/
/*			   CH02 5 of 10 to 9 of 10 & CH03 10 of 10.							*/
/* Assumption: Lot# always allocated in full cases, there shall be no   */
/*             remainder after Total Qty / CaseCnt.							*/
/*             Case label printed after allocation.							*/
/*             Reprint done in Report module, input parameter				*/
/*             is Orderkey, SKU & range of label.								*/
/*             Both RCM & report share same script.							*/    
/*                                                                      */
/* Called By: 																				*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
 
CREATE PROC [dbo].[isp_diageosg_deliverylabel]
   @c_orderkey   NVARCHAR(10)
  ,@c_SKU	 NVARCHAR(20)
  ,@c_fromlabel  NVARCHAR(5)
  ,@c_tolabel    NVARCHAR(5)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_externOrderkey NVARCHAR(30)	
		  , @C_Company NVARCHAR(60)
		  , @C_prevsku NVARCHAR(20)
		  , @c_casesku NVARCHAR(20)	
		  , @c_Descr   NVARCHAR(60)	
		  , @c_lottable01 NVARCHAR(18)
		  , @c_lottable02 NVARCHAR(18)
		  , @c_CaseNo 	 NVARCHAR(20)
		  , @n_qty INT
		  , @n_qtyincase INT
		  , @n_totalcase INT
		  , @n_LotCaseNo INT
		  , @n_CaseNo INT
		  , @n_casecnt INT		
		  , @n_fromlabel INT
		  , @n_tolabel INT		
		  , @b_debug INT

  SELECT @b_debug = 0
  SELECT	@n_fromlabel = CONVERT(INT, @c_fromlabel)
  SELECT	@n_tolabel = CONVERT(INT, @c_tolabel)

  SELECT ORDERS.Orderkey,
			ORDERS.ExternOrderkey,
			ORDERS.C_Company,
			PD.SKU,
			LA.Lottable01,
			LA.Lottable02,
			PACK.CASECNT,
			QTY = SUM(PD.QTY),
			QtyInCase = CASE WHEN PACK.Casecnt > 0 THEN SUM(PD.QTY) / PACK.Casecnt ELSE SUM(PD.QTY) END,
			TotalCase = 0,
			Descr = SKU.DESCR
	INTO  #RESULT1
	FROM  ORDERS (NOLOCK)
	JOIN  PICKDETAIL PD (NOLOCK) ON PD.Orderkey = ORDERS.Orderkey
	JOIN  Lotattribute LA (NOLOCK) ON LA.LOT = PD.LOT
	JOIN  SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU
	JOIN  PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey		
   WHERE ORDERS.Orderkey = @c_Orderkey
	GROUP BY ORDERS.Orderkey,
			ORDERS.C_Company,
			ORDERS.ExternOrderkey,
			PD.SKU,
			LA.Lottable01,
			LA.Lottable02,
			PACK.CASECNT,
			SKU.DESCR

  IF @c_sku <> '?' AND @c_sku > ''
  BEGIN
	 	DELETE FROM #RESULT1	WHERE SKU <> @c_sku
  END

	-- Calculate Total Case Per SKU
	DECLARE case_cur CURSOR FAST_FORWARD READ_ONLY FOR
	SELECT r.SKU, r.Casecnt, QTY = SUM(r.Qty)
	FROM   #RESULT1 r (NOLOCK)	
	WHERE  TotalCase = 0
	GROUP BY r.SKU, r.Casecnt
	ORDER BY r.SKU
	
	OPEN case_cur 	

	FETCH NEXT FROM case_cur INTO @c_casesku, @n_casecnt, @n_qty

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SELECT @n_totalcase = CASE WHEN @n_casecnt > 0 THEN @n_qty / @n_casecnt ELSE @n_qty END

		UPDATE #RESULT1
		SET	 TotalCase = @n_totalcase	
		WHERE  Orderkey = @c_orderkey
		AND    Sku = @c_casesku		

		FETCH NEXT FROM case_cur INTO @c_casesku, @n_casecnt, @n_qty
	END
	CLOSE case_cur
	DEALLOCATE case_cur
	-- End : Calculate Total Case Per SKU

   -- Write the label line 
   SELECT @n_totalcase = 0, @c_casesku = SPACE(20), @c_prevsku = SPACE(20)

   SELECT Orderkey,
			ExternOrderkey,
			C_Company,
			SKU,
			Lottable01,
			Lottable02,
			CASECNT,
			QTY,
			QtyInCase,
			TotalCase,
			CaseNo = SPACE(20),
			labelNo = 0,
			Descr
	INTO  #RESULT
	FROM  #RESULT1
	WHERE 1=2
	
	IF @c_sku = '?'
	BEGIN
		DECLARE skulabel_cur CURSOR FAST_FORWARD READ_ONLY FOR
		SELECT r.ExternOrderkey, r.C_Company, r.sku, r.lottable01, r.lottable02, r.Casecnt, r.Qty, 
				 qtyincase = MAX(r.QtyInCase),
				 totalcase = MAX(r.TotalCase),
				 Descr = MAX(Descr)
		FROM   #RESULT1 r (NOLOCK)	
		WHERE  Orderkey = @c_orderkey
		GROUP BY r.ExternOrderkey, r.C_Company, r.sku, r.lottable01, r.lottable02, r.Casecnt, r.Qty 
		ORDER BY r.sku, r.lottable01, r.lottable02
	END
	ELSE
	BEGIN
		DECLARE skulabel_cur CURSOR FAST_FORWARD READ_ONLY FOR
		SELECT r.ExternOrderkey, r.C_Company, r.sku, r.lottable01, r.lottable02, r.Casecnt, r.Qty, 
				 qtyincase = MAX(r.QtyInCase),
				 totalcase = MAX(r.TotalCase),
				 Descr = MAX(Descr)
		FROM   #RESULT1 r (NOLOCK)	
		WHERE  Orderkey = @c_orderkey
		AND    SKU = @c_sku
		GROUP BY r.ExternOrderkey, r.C_Company, r.sku, r.lottable01, r.lottable02, r.Casecnt, r.Qty 
		ORDER BY r.sku, r.lottable01, r.lottable02
	END
	
	OPEN skulabel_cur 	
	FETCH NEXT FROM skulabel_cur INTO @c_ExternOrderkey, @c_Company, @c_casesku, 
												 @c_lottable01, @c_lottable02, @n_casecnt, @n_qty, @n_qtyincase, @n_totalcase, @c_descr

	WHILE @@FETCH_STATUS = 0 
	BEGIN 	
		IF @c_prevsku = '' OR @c_prevsku <> @c_casesku 
		BEGIN
			SELECT @n_CaseNo = 0
			SELECT @c_prevsku = @c_casesku
		END

		SELECT @n_LotCaseNo = 0

		IF @b_debug = 1
		BEGIN
			select @c_casesku '@c_casesku' , @n_qty '@n_qty' , @n_qtyincase '@n_qtyincase' , @n_totalcase '@n_totalcase' , @n_CaseNo '@n_CaseNo' , @n_LotCaseNo '@n_LotCaseNo' 
		END

		WHILE @n_CaseNo < @n_totalcase AND @n_LotCaseNo < @n_qtyincase
		BEGIN
			SELECT @n_CaseNo = @n_CaseNo + 1
			SELECT @n_LotCaseNo = @n_LotCaseNo + 1

			SELECT @c_CaseNo = dbo.fnc_RTrim(dbo.fnc_LTrim(Convert(char, @n_CaseNo))) + ' of ' + dbo.fnc_RTrim(dbo.fnc_LTrim(Convert(char, @n_totalcase)))

			IF @b_debug = 1
			BEGIN
				select @n_CaseNo '@n_CaseNo' , @n_LotCaseNo '@n_LotCaseNo', @c_CaseNo '@c_CaseNo'
			END
	
			INSERT INTO #RESULT (Orderkey, ExternOrderkey, C_Company, SKU, Lottable01, Lottable02, Casecnt, Qty, QtyInCase, TotalCase, CaseNo, LabelNo, Descr)
			VALUES (@c_orderkey, @c_ExternOrderkey, @c_Company, @c_casesku, @c_lottable01, @c_lottable02, @n_casecnt, @n_qty, @n_QtyInCase, @n_totalcase, @c_CaseNo, @n_CaseNo, @c_descr)			
		END			
	
		FETCH NEXT FROM skulabel_cur INTO @c_ExternOrderkey, @c_Company, @c_casesku, 
												 @c_lottable01, @c_lottable02, @n_casecnt, @n_qty, @n_qtyincase, @n_totalcase, @c_descr
	END

	CLOSE skulabel_cur
	DEALLOCATE skulabel_cur
   -- End : Write the label line 


	IF @c_sku <> '?' AND @c_sku > '' AND @n_fromlabel > 0 AND @n_tolabel > 0 
	BEGIN
		SELECT * 
		FROM  #RESULT
		WHERE Sku = @c_sku
		AND   LabelNo between @n_fromlabel and @n_tolabel
		ORDER BY SKU, Lottable01, Lottable02
	END
	ELSE
	BEGIN
		SELECT * FROM #RESULT
		ORDER BY SKU, Lottable01, Lottable02
	END

   IF OBJECT_ID('tempdb..Result1') IS NOT NULL 
	BEGIN
      DROP TABLE #Result1
	END
	IF OBJECT_ID('tempdb..Result') IS NOT NULL 
	BEGIN
      DROP TABLE #Result
	END
END


SET QUOTED_IDENTIFIER OFF 

GO