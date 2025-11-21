SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspNikePostOrderCCSheet](@c_loadkey   NVARCHAR(10))
AS
BEGIN	
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @c_size NVARCHAR(5),
				@c_size01 NVARCHAR(5),
				@c_size02 NVARCHAR(5),
				@c_size03 NVARCHAR(5),
				@c_size04 NVARCHAR(5),
				@c_size05 NVARCHAR(5),
				@c_size06 NVARCHAR(5),
				@c_size07 NVARCHAR(5),
				@c_size08 NVARCHAR(5),
				@c_size09 NVARCHAR(5),
				@c_size10 NVARCHAR(5), 
				@n_cnt int,
				@c_stylecolor NVARCHAR(9),
				@c_prevstylecolor NVARCHAR(9),
				@c_Storerkey  NVARCHAR(15)
	
	CREATE TABLE #TEMPREC
				(Style NVARCHAR(9) null,
             SizeDesc NVARCHAR(20) null,
				 DetailDesc NVARCHAR(20) null,
				 size01 NVARCHAR(6) null,
				 size02 NVARCHAR(6) null,
				 size03 NVARCHAR(6) null,
				 size04 NVARCHAR(6) null,
				 size05 NVARCHAR(6) null,
				 size06 NVARCHAR(6) null,
				 size07 NVARCHAR(6) null,
				 size08 NVARCHAR(6) null,
				 size09 NVARCHAR(6) null,
				 size10 NVARCHAR(6) null,
	          qty01 int null,
				 qty02 int null,
				 qty03 int null,
				 qty04 int null,
				 qty05 int null,
				 qty06 int null,
				 qty07 int null,
				 qty08 int null,
				 qty09 int null,
				 qty10 int null)	

	SELECT @n_cnt = 0 

	DECLARE SizeCur CURSOR FAST_FORWARD READ_ONLY FOR
		SELECT  Storerkey, SUBSTRING(Sku, 1,9), SUBSTRING(Sku, 10,5)
		FROM LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL (NOLOCK)
		WHERE LPD.Orderkey = ORDERDETAIL.Orderkey
		AND   LPD.LoadKey    = @c_loadkey
      UNION
		SELECT  Storerkey, SUBSTRING(Sku, 1,9), SUBSTRING(Sku, 10,5)
		FROM REPLENISHMENT (NOLOCK)
		WHERE ReplenishmentGroup = @c_loadkey
		AND   LEFT(Toloc,6) = '71FAST'
		AND   Confirmed = 'Y'
		GROUP BY Storerkey, SUBSTRING(Sku, 10,5),  SUBSTRING(Sku, 1,9)
		ORDER BY Storerkey, SUBSTRING(Sku, 1,9),  SUBSTRING(Sku, 10,5)

	OPEN SizeCur

   FETCH NEXT FROM SizeCur INTO @c_Storerkey, @c_stylecolor, @c_size
   WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @n_cnt = @n_cnt + 1

		SELECT @c_size01 = CASE @n_cnt WHEN 1
								 THEN @c_size
								 ELSE @c_size01
								 END 
		SELECT @c_size02 = CASE @n_cnt WHEN 2
								 THEN @c_size
								 ELSE @c_size02
								 END
		SELECT @c_size03 = CASE @n_cnt WHEN 3
								 THEN @c_size
								 ELSE @c_size03
								 END
		SELECT @c_size04 = CASE @n_cnt WHEN 4
		  						 THEN @c_size
								 ELSE @c_size04
								 END
		SELECT @c_size05 = CASE @n_cnt WHEN 5
								 THEN @c_size
								 ELSE @c_size05
								 END
		SELECT @c_size06 = CASE @n_cnt WHEN 6
								 THEN @c_size
								 ELSE @c_size06
								 END
		SELECT @c_size07 = CASE @n_cnt WHEN 7
								 THEN @c_size
								 ELSE @c_size07
								 END
		SELECT @c_size08 = CASE @n_cnt WHEN 8
								 THEN @c_size
								 ELSE @c_size08
								 END
		SELECT @c_size09 = CASE @n_cnt WHEN 9
								 THEN @c_size
								 ELSE @c_size09
								 END
		SELECT @c_size10 = CASE	@n_cnt WHEN 10
								 THEN @c_size
								 ELSE @c_size10
								 END

		SELECT @c_prevstylecolor = @c_stylecolor

		FETCH NEXT FROM SizeCur INTO @c_Storerkey, @c_stylecolor, @c_size

		IF (@c_stylecolor <> @c_prevstylecolor) OR (@n_cnt >= 10) OR (@@FETCH_STATUS = -1)
		BEGIN
			INSERT INTO #TEMPREC
         SELECT SUBSTRING(SL.Sku, 1,9) AS 'Style-Color', 
					 'Size----->',
					 'Replenished Qty',
					 @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size01
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  , 
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size02
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size03
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size04
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size05
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size06
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  , 
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size07
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size08
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size09
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END  ,
					 CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size10
														 THEN SUM(CASE WHEN LEFT(SL.LOC,6)= '71FAST' AND RP.SKU IS NOT NULL THEN SL.Qty ELSE 0 END )
														 ELSE 0
														 END 
			FROM SKUxLOC SL (NOLOCK)
					LEFT OUTER JOIN ( SELECT Storerkey, Sku FROM REPLENISHMENT (NOLOCK)
											WHERE ReplenishmentGroup = @c_loadkey
											AND   LEFT(Toloc,6) = '71FAST'
											AND   Confirmed = 'Y'
				                     GROUP BY Storerkey, Sku) RP ON (SL.Storerkey = RP.Storerkey) AND
																					 (SL.Sku = RP.Sku)
			WHERE SL.Storerkey           = @c_storerkey
			AND   SUBSTRING(SL.Sku, 1,9) = @c_prevstylecolor
			AND   1=	CASE SUBSTRING(SL.Sku, 10,5) WHEN @c_size01
																THEN 1
																WHEN @c_size02
																THEN 1
																WHEN @c_size03
																THEN 1
																WHEN @c_size04
																THEN 1
																WHEN @c_size05
																THEN 1
																WHEN @c_size06
																THEN 1
																WHEN @c_size07
																THEN 1
																WHEN @c_size08
																THEN 1
																WHEN @c_size09
																THEN 1
																WHEN @c_size10
																THEN 1
																ELSE 0
																END  
         GROUP BY SL.Storerkey, SUBSTRING(SL.Sku, 1,9), SUBSTRING(SL.Sku, 10,5), LEFT(SL.LOC,6)

			INSERT INTO #TEMPREC
         SELECT SUBSTRING(OD.Sku, 1,9) AS 'Style-Color', 
					 'Size----->',
					 'Sum Of Order Qty',
					 @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size01
															THEN SUM(OriginalQty)
															ELSE 0
															END  , 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size02
															THEN SUM(OriginalQty)
													  		ELSE 0
															END, 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size03
															THEN SUM(OriginalQty)
											  				ELSE 0
															END ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size04
															THEN SUM(OriginalQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size05
															THEN SUM(OriginalQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size06
															THEN SUM(OriginalQty)
															ELSE 0
															END  , 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size07
															THEN SUM(OriginalQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size08
															THEN SUM(OriginalQty)
															ELSE 0
															END ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size09
															THEN SUM(OriginalQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size10
															THEN SUM(OriginalQty)
															ELSE 0
															END  
			FROM  LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL OD (NOLOCK)
			WHERE LPD.Orderkey  = OD.Orderkey
			AND   LPD.Loadkey   = @c_loadkey
			AND   SUBSTRING(OD.Sku, 1,9) = @c_prevstylecolor
			AND   1=	CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size01
																THEN 1
																WHEN @c_size02
																THEN 1
																WHEN @c_size03
																THEN 1
																WHEN @c_size04
																THEN 1
																WHEN @c_size05
																THEN 1
																WHEN @c_size06
																THEN 1
																WHEN @c_size07
																THEN 1
																WHEN @c_size08
																THEN 1
																WHEN @c_size09
																THEN 1
																WHEN @c_size10
																THEN 1
																ELSE 0
																END  
			GROUP BY SUBSTRING(OD.Sku, 1,9), SUBSTRING(OD.Sku, 10,5)


			INSERT INTO #TEMPREC
         SELECT SUBSTRING(OD.Sku, 1,9) AS 'Style-Color', 
					 'Size----->',
					 'Sum Of Processed',
					 @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size01
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  , 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size02
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
													  		ELSE 0
															END, 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size03
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
											  				ELSE 0
															END ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size04
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size05
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size06
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  , 
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size07
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size08
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size09
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  ,
					 CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size10
															THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
															ELSE 0
															END  
			FROM  LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL OD (NOLOCK)
			WHERE LPD.Orderkey  = OD.Orderkey
			AND   LPD.Loadkey   = @c_loadkey
			AND   SUBSTRING(OD.Sku, 1,9) = @c_prevstylecolor
			AND   1=	CASE SUBSTRING(OD.Sku, 10,5) WHEN @c_size01
																THEN 1
																WHEN @c_size02
																THEN 1
																WHEN @c_size03
																THEN 1
																WHEN @c_size04
																THEN 1
																WHEN @c_size05
																THEN 1
																WHEN @c_size06
																THEN 1
																WHEN @c_size07
																THEN 1
																WHEN @c_size08
																THEN 1
																WHEN @c_size09
																THEN 1
																WHEN @c_size10
																THEN 1
																ELSE 0
																END  
			GROUP BY SUBSTRING(OD.Sku, 1,9), SUBSTRING(OD.Sku, 10,5)
	
			--RESet cnt = 0 
			SELECT @n_cnt =0,  @c_size01 = NULL, @c_size02 = NULL, @c_size03 = NULL, @c_size04 = NULL, @c_size05 = NULL, 
                @c_size06 = NULL, @c_size07 = NULL, @c_size08 = NULL, @c_size09 = NULL, @c_size10 = NULL
		END
	END

	CLOSE SizeCur
	DEALLOCATE SizeCur
	
	SELECT LEFT(Style,6) + '-' + RIGHT(Style,3) AS StyleColor, SizeDesc, DetailDesc, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10, 
	       SUM(qty01) qty01, SUM(qty02) qty02, SUM(qty03) qty03, SUM(qty04) qty04, SUM(qty05) qty05, 
			 SUM(qty06) qty06, SUM(qty07) qty70, SUM(qty08) qty08, SUM(qty09) qty09, SUM(qty10) qty10, @c_loadkey
	FROM #TEMPREC
	GROUP BY Style, SizeDesc, DetailDesc, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10
   ORDER BY Style, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10, DetailDesc 

     
	DROP TABLE #TEMPREC
END

GO