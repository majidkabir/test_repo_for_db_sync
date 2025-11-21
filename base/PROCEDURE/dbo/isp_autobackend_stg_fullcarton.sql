SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_AutoBackend_Stg_FullCarton                     */
/* Creation Date: 2018-10-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2018-10-08       1.0      Initial Version								      */
/************************************************************************/
CREATE PROC [dbo].[isp_AutoBackend_Stg_FullCarton] 
   @cStrategyType       CHAR(2) = ''
 , @cBL_ParameterCode   NVARCHAR(30)
 , @nAllocBatchNo       BIGINT 
 , @nErr                INT = 0 OUTPUT
 , @cErrMsg             NVARCHAR(250) = '' OUTPUT
 , @bDebug              INT = 0 
AS
BEGIN
	SET NOCOUNT ON 
	
	DECLARE 
		  @cStorerKey     NVARCHAR(15) = ''
	   , @cSKU           NVARCHAR(20) = ''
	   , @nSecondaryQty      INT = 0 
	   , @cPrimarySKU    NVARCHAR(20) = ''
	   , @nPrimaryQty    INT = 0 
	   , @cOrderKey      NVARCHAR(10) = '' 
	   , @nA_Qty         INT = 0
	   , @nB_Qty         INT = 0

	   
	   , @nOriginAllocBatchNo INT = 0 
	   , @nNewAllocBatchNo    INT = 0
	   , @nAABD_RowRef        INT = 0 
	   , @nContinue           INT = 0 
	   , @nPrimaryCaseCnt     INT = 0 
	   , @nSecondaryCaseCnt   INT = 0	   
	
	IF @bDebug = 2
	   SET @bDebug = 1
	   
	SET @nOriginAllocBatchNo = @nAllocBatchNo
	
	IF OBJECT_ID('tempdb..#PAIR_ORDERS') IS NOT NULL
	   DROP TABLE #PAIR_ORDERS
	
	CREATE TABLE #PAIR_ORDERS (
		ID          INT IDENTITY(1,1),
		AABD_RowRef BIGINT, 
		OrderKey    NVARCHAR(10), 
		A_Qty       INT, 
		B_Qty       INT)

	IF OBJECT_ID('tempdb..#PRIMARY_SKU') IS NOT NULL
	   DROP TABLE #PRIMARY_SKU
	   
   CREATE TABLE #PRIMARY_SKU (
   	ID             INT IDENTITY(1,1),
   	Storerkey      NVARCHAR(15), 
   	SKU 	         NVARCHAR(20) 
   	)   
	   

	IF OBJECT_ID('tempdb..#Orders_Success') IS NOT NULL
	   DROP TABLE #Orders_Success
   
   CREATE TABLE #Orders_Success (OrderKey NVARCHAR(10))
   	   	   
   IF NOT EXISTS(SELECT 1 FROM AutoAllocBatch AS aab WITH(NOLOCK)
                 WHERE aab.AllocBatchNo = @nAllocBatchNo)
   BEGIN
      SELECT @nContinue = 3 
      SELECT @cErrMsg = CONVERT(char(250),@nErr), @nErr=500041 
      SELECT @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+':Record not exists in AutoAllocBatch (isp_AutoBackend_Stg_FullCarton)'   
      GOTO EXIT_SP 	
   END
   
   IF NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aab WITH(NOLOCK)
                 WHERE aab.AllocBatchNo = @nAllocBatchNo)
   BEGIN
      SELECT @nContinue = 3 
      SELECT @cErrMsg = CONVERT(char(250),@nErr), @nErr=500042 
      SELECT @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+':Record not exists in AutoAllocBatchDetail (isp_AutoBackend_Stg_FullCarton)'
      GOTO EXIT_SP    
   END
      		   
   SET @cPrimarySKU = ''	   
	SET @cSKU = ''
		            	   
	WHILE 1=1
	BEGIN
		GET_NEXT_PRIMARY:
		IF @cPrimarySKU = ''
		BEGIN
			TRUNCATE TABLE #PAIR_ORDERS
			
		   SELECT TOP 1 
		       @cStorerKey = OD.StorerKey, 
		       @cPrimarySKU = OD.Sku, 
		       @nPrimaryQty =  SUM(OD.OpenQty),
		       @nPrimaryCaseCnt = P.CaseCnt 	 
         FROM  AutoAllocBatch AAB WITH (NOLOCK)
         JOIN AutoAllocBatchDetail    AS AABD WITH (NOLOCK)
            ON  AABD.AllocBatchNo = AAB.AllocBatchNo
         JOIN ORDERS AS OH WITH (NOLOCK)
            ON  OH.OrderKey = AABD.OrderKey
         JOIN ORDERDETAIL AS OD WITH (NOLOCK)
            ON  OD.OrderKey = AABD.OrderKey 
         JOIN PACK AS p WITH(NOLOCK) ON p.PackKey = OD.PackKey 
		   WHERE AAB.AllocBatchNo = @nAllocBatchNo  
         AND   AAB.[Status] <> '9'
         AND P.CaseCnt > 0 
         AND NOT EXISTS(SELECT 1 FROM #PRIMARY_SKU AS ps WITH(NOLOCK)
                        WHERE ps.Storerkey = OD.StorerKey 
                          AND ps.SKU = OD.Sku)
         AND NOT EXISTS (SELECT 1 FROM #Orders_Success AS os WITH(NOLOCK)
                         WHERE os.OrderKey = AABD.OrderKey)                          
		   GROUP BY OD.StorerKey, OD.Sku, P.CaseCnt
		   HAVING SUM(OD.OpenQty) / (P.CaseCnt * 1.00) >= 1 
		   ORDER BY CEILING(SUM(OD.OpenQty) / P.CaseCnt) DESC		
		   
		   IF @bDebug = 1
		   BEGIN
		   	PRINT ''
		   	PRINT '------------------------------------------------'
		   	PRINT '>>> PrimarySKU: ' + @cPrimarySKU + ' Qty: ' + CAST(@nPrimaryQty AS CHAR(5)) + ', Case Cnt: ' + CAST(@nPrimaryCaseCnt AS CHAR(5))		   	 
		   END
		   
		   IF @cPrimarySKU <> ''
		   BEGIN 
		   	IF NOT EXISTS (SELECT 1 FROM #PRIMARY_SKU AS ps WITH(NOLOCK)
		   	               WHERE ps.Storerkey = @cStorerKey
		   	               AND ps.SKU = @cPrimarySKU)
		   	BEGIN
		   		INSERT INTO #PRIMARY_SKU
		   		( Storerkey, SKU )
		   		VALUES
		   		( @cStorerKey, @cPrimarySKU )
		   	END	   	
		   	
		      INSERT INTO #PAIR_ORDERS( AABD_RowRef, OrderKey, A_Qty, B_Qty ) 
		      SELECT AABD.RowRef, AABD.OrderKey, SUM(OD.OpenQty), 0
		      FROM  AutoAllocBatch AAB WITH (NOLOCK)
            JOIN AutoAllocBatchDetail AS AABD WITH (NOLOCK) ON  AABD.AllocBatchNo = AAB.AllocBatchNo
            JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = AABD.OrderKey 
		      WHERE AAB.AllocBatchNo = @nAllocBatchNo
            AND   AAB.[Status] <> '9'
            AND   OD.StorerKey = @cStorerKey 
		      AND   OD.Sku = @cPrimarySKU 
            AND NOT EXISTS (SELECT 1 FROM #Orders_Success AS os WITH(NOLOCK)
                            WHERE os.OrderKey = AABD.OrderKey)   		      
		      GROUP BY AABD.RowRef, AABD.OrderKey 		   	
		   END
		   ELSE
		   	BREAK
		   	
		END -- IF @cPrimarySKU = ''
		GET_NEXT_SECONDARY:
		IF @cSKU = ''
		BEGIN   			
		   SELECT TOP 1 
		       @cStorerKey = OD.StorerKey, 
		       @cSKU = OD.Sku, 
		       @nSecondaryQty =  SUM(OD.OpenQty),
		       @nSecondaryCaseCnt = p.CaseCnt  
         FROM  AutoAllocBatch AAB WITH (NOLOCK) 
         JOIN AutoAllocBatchDetail AS AABD WITH (NOLOCK)
            ON  AABD.AllocBatchNo = AAB.AllocBatchNo
         JOIN #PAIR_ORDERS AS OH WITH (NOLOCK) 
            ON  OH.OrderKey = AABD.OrderKey
         JOIN ORDERDETAIL AS OD WITH (NOLOCK) 
            ON  OD.OrderKey = AABD.OrderKey 
         JOIN PACK AS p WITH(NOLOCK) ON p.PackKey = OD.PackKey 
		   WHERE P.CaseCnt > 0 
		   AND AAB.AllocBatchNo = @nAllocBatchNo
		   AND OD.Sku <> @cPrimarySKU   
         AND   AAB.[Status] <> '9'  
		   GROUP BY OD.StorerKey, OD.Sku, P.CaseCnt
		   HAVING SUM(OD.OpenQty) >= CASE WHEN @cStrategyType ='FC' THEN P.CaseCnt ELSE 1 END  
		   ORDER BY SUM(OD.OpenQty) DESC		
		   
		   IF @cSKU <> ''
		   BEGIN
		   	IF @bDebug = 1
		   	BEGIN
		   	   PRINT '>>>        SKU: ' + @cSKU + ' Qty: ' + CAST(@nSecondaryQty AS CHAR(5)) + ', Case Cnt: ' + CAST(@nSecondaryCaseCnt AS CHAR(5))		
		   	END
		   	
		      UPDATE PAIR_ORDER
		         SET B_Qty = Qty
		      FROM #PAIR_ORDERS PAIR_ORDER
		      JOIN (SELECT AABD.RowRef, AABD.OrderKey, SUM(OD.OpenQty) AS Qty
		            FROM AutoAllocBatch AAB WITH (NOLOCK)
                  JOIN AutoAllocBatchDetail AS AABD WITH (NOLOCK) ON  AABD.AllocBatchNo = AAB.AllocBatchNo 
                  JOIN #PAIR_ORDERS AS OH WITH (NOLOCK) ON  OH.OrderKey = AABD.OrderKey AND OH.AABD_RowRef = AABD.RowRef           
                  JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = AABD.OrderKey 
		            WHERE AAB.AllocBatchNo = @nAllocBatchNo 
                  AND   AAB.[Status] <> '9'
                  AND   OD.StorerKey = @cStorerKey 
		            AND   OD.Sku = @cSKU 
		            GROUP BY AABD.RowRef, AABD.OrderKey) AS SO ON SO.OrderKey = PAIR_ORDER.OrderKey AND SO.RowRef = PAIR_ORDER.AABD_RowRef   		   	
		   END			
		   ELSE 
		   BEGIN
				SET @cPrimarySKU = ''
				SET @cSKU = ''
				SET @nPrimaryQty = 0
				GOTO GET_NEXT_PRIMARY   	
		   END		   	 
		END
		
		IF @cPrimarySKU <> '' AND @cSKU <> ''
		BEGIN 
			IF @cStrategyType = 'FC' 
			BEGIN
				SET @nPrimaryQty = FLOOR(@nPrimaryQty / @nPrimaryCaseCnt) * @nPrimaryCaseCnt 
				SET @nSecondaryQty = FLOOR(@nSecondaryQty / @nSecondaryCaseCnt) * @nSecondaryCaseCnt 				
			END
			
			WHILE @nPrimaryQty > 0 AND @nSecondaryQty > 0 
			BEGIN
				IF @bDebug = 1
				BEGIN
					PRINT ''
					PRINT '** #PAIR_ORDERS **'
				   SELECT AABD_RowRef, OrderKey, A_Qty, B_Qty
				   FROM #PAIR_ORDERS
				   WHERE A_Qty > 0 AND B_Qty > 0 
				   ORDER BY AABD_RowRef					
				END
				
				IF CURSOR_STATUS('local','CUR_SKU_ORDERS') = 1
				BEGIN
					CLOSE CUR_SKU_ORDERS
					DEALLOCATE CUR_SKU_ORDERS					
				END
				
				DECLARE CUR_SKU_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
				SELECT AABD_RowRef, OrderKey, A_Qty, B_Qty
				FROM #PAIR_ORDERS
				WHERE A_Qty > 0 AND B_Qty > 0 
				ORDER BY AABD_RowRef
				
				OPEN CUR_SKU_ORDERS
				
				FETCH FROM CUR_SKU_ORDERS INTO @nAABD_RowRef, @cOrderKey, @nA_Qty, @nB_Qty
				
				WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @bDebug = 1
					BEGIN
					   PRINT '>>>   @nPrimaryQty:    ' + CAST(@nPrimaryQty AS CHAR(10))   + ' @nA_Qty     : ' + CAST(@nA_Qty AS VARCHAR(10)) 
					   PRINT '>>>   @nSecondaryQty:  ' + CAST(@nSecondaryQty AS CHAR(10)) + ' @nB_Qty     : ' + CAST(@nB_Qty AS VARCHAR(10))						
					END
					
					IF @nA_Qty <= @nPrimaryQty AND @nB_Qty <= @nSecondaryQty
					BEGIN
						DELETE FROM #PAIR_ORDERS WHERE AABD_RowRef = @nAABD_RowRef
						
						IF @bDebug = 1
						   PRINT '>>>   Order Found: ' + @cOrderKey
						
						IF NOT EXISTS (SELECT 1 FROM #Orders_Success OS 
						               WHERE OS.OrderKey = @cOrderKey)
					   BEGIN
						   INSERT INTO #Orders_Success (OrderKey)
						   VALUES (@cOrderKey)					   	
					   END     
						
						IF @nNewAllocBatchNo = 0 
						BEGIN
   	               INSERT INTO AutoAllocBatch 
   	               (  Facility,   		Storerkey,   		BuildParmGroup,
   		               BuildParmCode, 	BuildParmString,  Duration,
   		               TotalOrderCnt, 	UDF01,   		   UDF02,
   		               UDF03,   		   UDF04,    		   UDF05,
   		               [Status],         StrategyKey,      [Priority] )
                     SELECT 
                        Facility,   		Storerkey,   		BuildParmGroup,
   		               BuildParmCode, 	BuildParmString,  Duration,
   		               TotalOrderCnt, 	UDF01,   		   UDF02,
   		               UDF03,   		   UDF04,    		   UDF05,
   		               [Status],         StrategyKey,      [Priority]
                     FROM AutoAllocBatch WITH (NOLOCK)
                     WHERE AllocBatchNo =  @nOriginAllocBatchNo
                  
   	               SET @nNewAllocBatchNo = @@IDENTITY   					
   	               
   	               IF OBJECT_ID('tempdb..#AllocBatch') IS NOT NULL
   	               BEGIN
   	               	INSERT INTO #AllocBatch( AllocBatchNo ) VALUES (@nNewAllocBatchNo)
   	               	
   	               	IF @bDebug=1
   	               	   PRINT 'INSERT INTO #AllocBatch'   	               	
   	               END
   	               ELSE 
   	               BEGIN
   	               	IF @bDebug=1
   	               	   PRINT '#AllocBatch NOT EXISTS'   	               	   	               	
   	               END
   	                  
   	                  
   	               IF @bDebug=1
   	               BEGIN
   	               	PRINT '-----------------------------------------------------------------'
   	               	PRINT '>>>  Insert into AutoAllocBatch, New AllocBatchNo = ' + CAST(@nNewAllocBatchNo AS VARCHAR(10)) 
   	               END				
						END
   	            
   	            INSERT INTO AutoAllocBatchDetail
   	            (
   	            	AllocBatchNo,     OrderKey,         [Status],
   	            	TotalSKU,         SKUAllocated,     NoStockFound,
   	            	AllocErrorFound,  AddDate,         	EditDate
   	            )
   	            SELECT
   	            	@nNewAllocBatchNo, OrderKey,         [Status],
   	            	TotalSKU,          SKUAllocated,     NoStockFound,
   	            	AllocErrorFound,   GETDATE(),        GETDATE()         
   	            FROM AutoAllocBatchDetail AS aabd WITH(NOLOCK)
   	            WHERE aabd.RowRef = @nAABD_RowRef
   	            
   	            IF @@ERROR = 0
   	            BEGIN
   	               DELETE AutoAllocBatchDetail
   	               WHERE RowRef = @nAABD_RowRef 	
   	               
   	               SET @nPrimaryQty = @nPrimaryQty - @nA_Qty
   	               SET @nSecondaryQty = @nSecondaryQty - @nB_Qty 
   	            END    	            
					END -- IF @nA_Qty >= @nPrimaryQty AND @nB_Qty >= @nSecondaryQty
					
					IF @nPrimaryQty <= 0 
					BEGIN
						SET @cPrimarySKU = ''
						SET @nPrimaryQty = 0
						GOTO GET_NEXT_PRIMARY 
					END
					
					IF @nSecondaryQty <= 0 
					BEGIN
						SET @cSKU = ''
						SET @nSecondaryQty = 0 
					   GOTO GET_NEXT_SECONDARY
					END					
				
					FETCH FROM CUR_SKU_ORDERS INTO @nAABD_RowRef, @cOrderKey, @nA_Qty, @nB_Qty
				END
				
				CLOSE CUR_SKU_ORDERS
				DEALLOCATE CUR_SKU_ORDERS				
			END
			BREAK 
		END -- IF @cPrimarySKU <> '' AND @cSKU <> ''		
		BREAK 
	END -- WHILE 1=1

   EXIT_SP:
   
   IF @bDebug = 1
   BEGIN
   	PRINT ''
   	PRINT 'Full Carton Orders'
   	SELECT * FROM #Orders_Success 
   END
      
END

GO