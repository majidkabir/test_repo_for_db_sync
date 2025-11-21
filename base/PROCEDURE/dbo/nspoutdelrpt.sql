SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspOutDelRpt] (
 @StorerKey	        NVARCHAR(15),
 @DateMin	        NVARCHAR(10),
 @DateMax	        NVARCHAR(10),
 @OrderKeyMin            NVARCHAR(10),
 @OrderKeyMax            NVARCHAR(10),
 @ExternOrderKeyMin      NVARCHAR(30),
 @ExternOrderKeyMax      NVARCHAR(30)
 ) AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 	DECLARE	@OrderKey		 NVARCHAR(10), 
 		@DeliveryDate			DateTime, 
 		@BatchNo		 NVARCHAR(20), 
 		@ExternOrderKey		 NVARCHAR(30), 
 		@CustCode		 NVARCHAR(15), 
 		@CustName		 NVARCHAR(45), 
 		@Sku			 NVARCHAR(20), 
 		@OriginQty			Int, 
 		@Carton				Int, 
 		@PickDate			DateTime,  
 		@CompleteDate			DateTime, 
 		@scandate			DateTime, 
 		@CaseCnt			Float, 
 --		@ProdCat		 NVARCHAR(2), 
 		@ProdCat		 NVARCHAR(10), 
 		@ProdClass1		 NVARCHAR(1), 
 		@ProdClass2		 NVARCHAR(1), 
 		@FW				Int, 
  		@APP				Int, 
  		@EQ				Int, 
  		@ACC				Int, 
  		@BSSA				Int,
  		@FWqty				Int, 
  		@APPqty				Int, 
  		@EQqty				Int, 
  		@ACCqty				Int, 
  		@BSSAqty			Int,
 		@CTN				Int 
 	SELECT @FW = 0, @APP = 0, @EQ = 0, @ACC = 0, @BSSA = 0
 	SELECT @FWqty = 0, @APPqty = 0, @EQqty = 0, @ACCqty = 0, @BSSAqty = 0
 	CREATE TABLE #RESULT 
 					(OrderKey	 NVARCHAR(10), 
 					 DeliveryDate		DateTime, 
 					 BatchNo	 NVARCHAR(20), 
 					 ExternOrderKey	 NVARCHAR(30), 
 					 CustCode	 NVARCHAR(15), 
 					 CustName	 NVARCHAR(45), 
 					 Sku		 NVARCHAR(10), 
 					 OriginQty		Int, 
 					 Carton			Int, 
 					 PickDate		DateTime,  
 					 CompleteDate		DateTime)
 	CREATE TABLE #RESULT1 
 					(OrderKey	 NVARCHAR(10), 
 					 DeliveryDate		DateTime, 
 					 BatchNo	 NVARCHAR(20), 
 					 ExternOrderKey	 NVARCHAR(30), 
 					 CustCode	 NVARCHAR(15), 
 					 CustName	 NVARCHAR(45), 
 					 Sku		 NVARCHAR(10), 
 					 OriginQty		Int, 
 					 Carton			Int, 
 					 PickDate		DateTime,  
 					 CompleteDate		DateTime)
 					
 	DECLARE CUR_1 CURSOR
 	FOR  	
 		SELECT Distinct DeliveryDate, CONVERT(Char(20), ORDERS.Notes2) AS BatchNo, 
 				 ExternOrderKey, OrderKey, ConsigneeKey, C_Company
 		  FROM ORDERS(nolock)  
 		 WHERE StorerKey = @StorerKey
 			AND DeliveryDate >= @DateMin AND DeliveryDate < DATEADD(dd, 1, @DateMax)
 			AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
 			AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
 			AND SOStatus <> 'CANC' 
 			and status <> '9'
 		ORDER BY DeliveryDate, CONVERT(Char(20), ORDERS.Notes2), ExternOrderKey, OrderKey
 		OPEN CUR_1
 		FETCH NEXT FROM CUR_1 INTO @DeliveryDate, @BatchNo, @ExternOrderKey, @OrderKey, @CustCode, @CustName
 	
 		WHILE (@@fetch_status <> -1)
 		BEGIN
 			/* Get ScanDate for PickConfirmed */
 			select @ctn = max(cartonno)
 			from packdetail pd (nolock), packheader ph (nolock), orders o (nolock)
 			where pd.pickslipno = ph.pickslipno
 			and o.orderkey = ph.orderkey
 			and o.orderkey = @orderkey
 			DECLARE SKUCUR_1 CURSOR
 			FOR  	
 				SELECT Sku, SUM(OriginalQty) 
 				  FROM ORDERDETAIL (nolock) 
 				 WHERE Orderkey = @OrderKey
 			   GROUP BY SKU 
 				OPEN SKUCUR_1
 				FETCH NEXT FROM SKUCUR_1 INTO @Sku, @OriginQty  
 			
 				WHILE (@@fetch_status <> -1)
 				BEGIN 
 						SELECT @CaseCnt = CaseCnt From PACK (Nolock), SKU (Nolock)  
 						 WHERE PACK.Packkey = SKU.Packkey 
 						   AND SKU.Storerkey = @Storerkey 
 						   AND SKU.Sku = @Sku
 						
 						IF @Casecnt > 0 
 						Begin
 							SELECT @Casecnt = @Casecnt 
 						End
 						Else
 						Begin
 							SELECT @Casecnt = 1
 						End
 					/*	SELECT @ProdCat = Susr4, 
 								 @ProdClass1 = CASE Substring(Class, 3, 1) 
 														WHEN 'Y' THEN 'Y' 
 														WHEN 'N' THEN 'N' 
 														ELSE 'N'
 													END, 
 								 @ProdClass2 = CASE Substring(Class, 4, 1)
 														WHEN 'Y' THEN 'Y' 
 														WHEN 'N' THEN 'N' 
 														ELSE 'N'
 													END 
 						  FROM SKU (nolock) 
 						 WHERE Storerkey = @Storerkey 
 						   AND Sku = @Sku 
 						IF @ProdCat = '02' AND @ProdClass1 = 'N' AND @ProdClass2 = 'N' 
 						Begin
 							--SELECT @FW = @FW + Floor(@OriginQty/@Casecnt)
 							select @FW = isnull(@ctn,0)
 							SELECT @FWqty = @FWqty + @OriginQty
 						End
 						IF @ProdCat = '03' AND @ProdClass1 = 'N' AND @ProdClass2 = 'N' 
 						Begin 
 							--SELECT @APP = @APP + Floor(@OriginQty/@Casecnt)										
 							select @APP = isnull(@ctn,0)
 							SELECT @APPqty = @APPqty + @OriginQty										
 						End
 						IF @ProdCat = '02' AND @ProdClass1 = 'Y' AND @ProdClass2 = 'N' 
 						Begin 
 							--SELECT @EQ = @EQ + Floor(@OriginQty/@Casecnt)										
 							select @EQ = isnull(@ctn,0)
 							SELECT @EQqty = @EQqty + @OriginQty										
 						End
 						IF @ProdCat = '03' AND @ProdClass1 = 'N' AND @ProdClass2 = 'Y' 
 						Begin 
 							--SELECT @ACC = @ACC + Floor(@OriginQty/@Casecnt)										
 							select @ACC = isnull(@ctn,0)
 							SELECT @ACCqty = @ACCqty + @OriginQty									
 						End
 						IF @ProdCat = '03' AND @ProdClass1 = 'Y' AND @ProdClass2 = 'N' 
 						Begin 
 							--SELECT @BSSA = @BSSA + Floor(@OriginQty/@Casecnt)										
 							select @BSSA = isnull(@ctn,0)
 							SELECT @BSSAqty = @BSSAqty + @OriginQty									
 						End
 						*/
 						SELECT @ProdCat = busr5 
 						  FROM SKU (nolock) 
 						 WHERE Storerkey = @Storerkey 
 						   AND Sku = @Sku 
 						IF @ProdCat = 'FOOTWEAR'
 						Begin
 							select @FW = isnull(@ctn,0)
 							SELECT @FWqty = @FWqty + @OriginQty
 						End
 						IF @ProdCat = 'APPAREL'
 						Begin 
 							select @APP = isnull(@ctn,0)
 							SELECT @APPqty = @APPqty + @OriginQty										
 						End
 						IF @ProdCat = 'EQUIP'
 						Begin 
 							select @EQ = isnull(@ctn,0)
 							SELECT @EQqty = @EQqty + @OriginQty										
 						End
 						IF @ProdCat = 'ACCESSORY'
 						Begin 
 							select @ACC = isnull(@ctn,0)
 							SELECT @ACCqty = @ACCqty + @OriginQty									
 						End
 						IF @ProdCat = 'BSSA'
 						Begin 
 							select @BSSA = isnull(@ctn,0)
 							SELECT @BSSAqty = @BSSAqty + @OriginQty									
 						End
 		
 					FETCH NEXT FROM SKUCUR_1 INTO @Sku, @OriginQty 
 		
 				END  /* cursor loop */
 			
 			CLOSE      SKUCUR_1
 			DEALLOCATE SKUCUR_1
 			
 			select @completedate = NULL, @scandate = NULL
 			IF (SELECT Status FROM LOADPLANDETAIL (Nolock) Where OrderKey = @OrderKey) >= '3' 
 			Begin
 				SELECT @scandate = ScanOutDate 
 				 FROM PickingInfo (Nolock) 
 --				WHERE PickSlipNo IN (SELECT Distinct PickHeaderKey 
 --				FROM PICKHeader (Nolock) Where ExternOrderKey IN (SELECT Distinct LoadKey 
 --							FROM LoadPlanDetail (Nolock)
 --							WHERE OrderKey = @OrderKey))
 				where pickslipno in (select pickheaderkey
 				from pickheader (nolock) where orderkey = @orderkey)
 				--SELECT @CompleteDate = DepartureDate 
 				select @completedate = mbol.editdate
 				 FROM MBOL (Nolock), ORDERS (nolock) 
 				WHERE MBOL.MBOLKEY = ORDERS.MBOLKEY 
 				  AND ORDERS.OrderKey = @OrderKey 
 			End
 			/*Else
 			Begin
 				SELECT @scandate = NULL
 				SELECT @CompleteDate = NULL
 			End*/
 			IF @FWqty > 0 
 			Begin 
 				INSERT INTO #RESULT (OrderKey, DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, 
 											Sku, OriginQty, Carton, PickDate, CompleteDate) 
 								 VALUES (@OrderKey, @DeliveryDate, @BatchNo, @ExternOrderKey, @CustCode, @CustName, 
 											'FW', @FWqty, @FW, @scandate, @CompleteDate)
 			End
 			IF @APPqty > 0 
 			Begin 
 				INSERT INTO #RESULT (OrderKey, DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, 
 											Sku, OriginQty, Carton, PickDate, CompleteDate) 
 								 VALUES (@OrderKey, @DeliveryDate, @BatchNo, @ExternOrderKey, @CustCode, @CustName, 
 											'APP', @APPqty, @APP, @scandate, @CompleteDate)
 			End
 			IF @EQqty > 0 
 			Begin 
 				INSERT INTO #RESULT (OrderKey, DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, 
 											Sku, OriginQty, Carton, PickDate, CompleteDate) 
 								 VALUES (@OrderKey, @DeliveryDate, @BatchNo, @ExternOrderKey, @CustCode, @CustName, 
 											'EQ', @EQqty, @EQ, @scandate, @CompleteDate)
 			End
 			IF @ACCqty > 0 
 			Begin 
 				INSERT INTO #RESULT (OrderKey, DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, 
 											Sku, OriginQty, Carton, PickDate, CompleteDate) 
 								 VALUES (@OrderKey, @DeliveryDate, @BatchNo, @ExternOrderKey, @CustCode, @CustName, 
 											'ACC', @ACCqty, @ACC, @scandate, @CompleteDate)
 			End
 			IF @BSSAqty > 0 
 			Begin 
 				INSERT INTO #RESULT (OrderKey, DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, 
 											Sku, OriginQty, Carton, PickDate, CompleteDate) 
 								 VALUES (@OrderKey, @DeliveryDate, @BatchNo, @ExternOrderKey, @CustCode, @CustName, 
 											'BSSA', @BSSAqty, @BSSA, @scandate, @CompleteDate)
 			End
 			SELECT @FW = 0, @APP = 0, @EQ = 0, @ACC = 0, @BSSA = 0
 			SELECT @FWqty = 0, @APPqty = 0, @EQqty = 0, @ACCqty = 0, @BSSAqty = 0
 			FETCH NEXT FROM CUR_1 INTO @DeliveryDate, @BatchNo, @ExternOrderKey, @OrderKey, @CustCode, @CustName 
 		END  /* cursor loop */
 	
 	CLOSE      CUR_1
 	DEALLOCATE CUR_1
 select deliverydate, orderkey, ttl_sku = count(sku) into #tempresult from #result
 group by deliverydate, orderkey
 having count(sku) > 1
 insert #result1 
 select Orderkey, DeliveryDate, max(BatchNo), max(ExternOrderKey), max(CustCode), max(CustName), max(Sku), 
 		 sum(OriginQty), sum(Carton), max(PickDate), max(CompleteDate)
 from #RESULT
 group by deliverydate, orderkey	
 update #result1
 set sku = '*'
 from #tempresult a
 where #result1.deliverydate = a.deliverydate
 and #result1.orderkey = a.orderkey
 drop table #tempresult
 drop table #result
 SELECT DeliveryDate, BatchNo, ExternOrderKey, CustCode, CustName, Sku, 
 		 OriginQty, Carton, PickDate, CompleteDate 
 FROM #RESULT1
 DROP TABLE #RESULT1
 END

GO