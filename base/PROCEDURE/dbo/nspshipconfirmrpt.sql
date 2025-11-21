SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 CREATE PROC [dbo].[nspShipConfirmRpt] (
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

 	DECLARE @StorerKey_tmp NVARCHAR(15), 
 			  @BatchNo		 NVARCHAR(20), 
 			  @ExternOrderKey NVARCHAR(30), 
 			  @OrderKey		 NVARCHAR(10), 
 			  @AddDate			DateTime,  
 			  @EditDate			DateTime, 
 			  @DeliveryDate	DateTime, 
 			  @Customer		 NVARCHAR(45), 
 			  @ReqQty			Int, 
 			  @ShipQty			Int, 
 			  @DiffQty			Int, 
 			  @Status		 NVARCHAR(8), 
 			  @Sku			 NVARCHAR(20), 
 			  @Sku_reqqty		Int, 
 			  @Sku_shipqty		Int 
 	CREATE TABLE #RESULT 
 					(StorerKey		 NVARCHAR(15), 
 					 BatchNo			 NVARCHAR(20), 
 					 ExternOrderKey NVARCHAR(30), 
 					 OrderKey		 NVARCHAR(10), 
 					 AddDate				DateTime,  
 					 EditDate			DateTime, 
 					 DeliveryDate		DateTime, 
 					 Customer		 NVARCHAR(45), 
 					 ReqQty				Int, 
 					 ShipQty				Int, 
 					 DiffQty				Int, 
 					 Status			 NVARCHAR(8))
 	CREATE TABLE #RESULT1 
 					(StorerKey		 NVARCHAR(15), 
 					 BatchNo			 NVARCHAR(20), 
 					 ExternOrderKey NVARCHAR(30), 
 					 OrderKey		 NVARCHAR(10), 
 					 AddDate				DateTime,  
 					 EditDate			DateTime, 
 					 DeliveryDate		DateTime, 
 					 Customer		 NVARCHAR(45), 
 					 ReqQty				Int, 
 					 ShipQty				Int, 
 					 DiffQty				Int, 
 					 Status			 NVARCHAR(8))
 	INSERT INTO #RESULT (StorerKey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 								DeliveryDate, Customer, ReqQty, ShipQty)
 					SELECT ORDERS.StorerKey, CONVERT(Char(20), ORDERS.Notes2), 
 					       ORDERS.ExternOrderKey, 
 					       ORDERS.OrderKey, 
 					       ORDERS.AddDate, 
 					       ORDERS.EditDate, 
 					       ORDERS.DeliveryDate, 
 					       ORDERS.C_Company, 
 					       SUM(ORDERDETAIL.OriginalQty), 
 					       SUM(ORDERDETAIL.ShippedQty + ORDERDETAIL.Qtypicked) 
 					  FROM ORDERDETAIL(nolock),
 					       ORDERS(nolock) 	     
 					 WHERE ORDERDETAIL.OrderKey = ORDERS.OrderKey 
 					   AND ORDERS.Status = '5'
 					   AND ORDERS.StorerKey = @StorerKey
 					   AND ORDERS.DeliveryDate >= @DateMin AND ORDERS.DeliveryDate < DateAdd(dd, 1, @DateMax)
 					   AND ORDERS.ORDERKEY >= @OrderKeyMin AND ORDERS.ORDERKEY <= @OrderKeyMax
 					   AND ORDERS.EXTERNORDERKEY >= @ExternOrderKeyMin AND ORDERS.EXTERNORDERKEY <= @ExternOrderKeyMax
 					GROUP BY ORDERS.StorerKey, CONVERT(Char(20), ORDERS.Notes2), 
 							 ORDERS.ExternOrderKey, ORDERS.OrderKey, 		  
 							 ORDERS.AddDate, ORDERS.EditDate, 
 					     	 ORDERS.DeliveryDate, ORDERS.C_Company, ORDERS.ConsigneeKey
 	DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY
 	FOR  	
 		SELECT Storerkey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 				  DeliveryDate, Customer, ReqQty, ShipQty 
 		  FROM #RESULT 
 		OPEN CUR_1
 		FETCH NEXT FROM CUR_1 INTO @Storerkey_tmp, @BatchNo, @ExternOrderKey, @OrderKey, @AddDate, @EditDate, 
 											@DeliveryDate, @Customer, @ReqQty, @ShipQty 
 	
 		WHILE (@@fetch_status <> -1)
 		BEGIN
 			IF @ReqQty > 0 
 			Begin
 				SELECT @DiffQty = @ReqQty - @ShipQty 
 			End
 			Else
 			Begin
 				SELECT @DiffQty = 0
 			End
 			IF @DiffQty = 0 AND @ShipQty > 0 
 			Begin
 				INSERT INTO #RESULT1 (StorerKey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 										 	 DeliveryDate, Customer, ReqQty, ShipQty, DiffQty, Status)
 								  VALUES (@Storerkey_tmp, @BatchNo, @ExternOrderKey, @OrderKey, @AddDate, @EditDate, 
 											 @DeliveryDate, @Customer, @ReqQty, @ShipQty, @DiffQty, 'COMPLETE')
 			End
 			ELSE IF @DiffQty <> 0 AND @ShipQty > 0 
 					Begin
 						INSERT INTO #RESULT1 (StorerKey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 													 DeliveryDate, Customer, ReqQty, ShipQty, DiffQty, Status)
 										  VALUES (@Storerkey_tmp, @BatchNo, @ExternOrderKey, @OrderKey, @AddDate, @EditDate, 
 													 @DeliveryDate, @Customer, @ReqQty, @ShipQty, @DiffQty, 'PARTIAL')				
 		
 						DECLARE SKUCUR_1 CURSOR FAST_FORWARD READ_ONLY
 						FOR  	
 							SELECT Sku, SUM(ORDERDETAIL.OriginalQty), SUM(ORDERDETAIL.ShippedQty + ORDERDETAIL.Qtypicked) 
 							  FROM ORDERDETAIL (nolock) 
 		 					 WHERE Orderkey = @OrderKey 
 							GROUP BY SKU 
 					
 							OPEN SKUCUR_1
 							FETCH NEXT FROM SKUCUR_1 INTO @Sku, @Sku_reqqty, @Sku_shipqty 
 		
 							WHILE (@@fetch_status <> -1)
 							BEGIN
 								IF @sku_reqqty - @Sku_shipqty > 0 
 								Begin
 									INSERT INTO #RESULT1 (BatchNo, Customer, ReqQty, ShipQty, DiffQty)
 													  VALUES ('*', @Sku, @Sku_reqqty, @Sku_shipqty, @Sku_reqqty - @Sku_shipqty)											
 								End
 		
 								FETCH NEXT FROM SKUCUR_1 INTO @Sku, @Sku_reqqty, @Sku_shipqty  
 					
 							END  /* cursor loop */
 						
 							CLOSE      SKUCUR_1
 							DEALLOCATE SKUCUR_1
 		
 					End
 					ELSE IF (@DiffQty = 0 AND @ShipQty = 0) OR (@DiffQty <> 0 AND @ShipQty = 0) 
 					Begin
 						INSERT INTO #RESULT1 (StorerKey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 												 	 DeliveryDate, Customer, ReqQty, ShipQty, DiffQty, Status)
 										  VALUES (@Storerkey_tmp, @BatchNo, @ExternOrderKey, @OrderKey, @AddDate, @EditDate, 
 													 @DeliveryDate, @Customer, @ReqQty, @ShipQty, @DiffQty, 'NONE')
 					End
 			FETCH NEXT FROM CUR_1 INTO @Storerkey_tmp, @BatchNo, @ExternOrderKey, @OrderKey, @AddDate, @EditDate, 
 												@DeliveryDate, @Customer, @ReqQty, @ShipQty 
 		END  /* cursor loop */
 	
 	CLOSE      CUR_1
 	DEALLOCATE CUR_1
 	SELECT storerkey, BatchNo, ExternOrderKey, OrderKey, AddDate, EditDate, 
 			 DeliveryDate, Customer, ReqQty, ShipQty, DiffQty, Status 
 	  FROM #RESULT1	
 	
 	DROP TABLE #RESULT
   	DROP TABLE #RESULT1
 END

GO