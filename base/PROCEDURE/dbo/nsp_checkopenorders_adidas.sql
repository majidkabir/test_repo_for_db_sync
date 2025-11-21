SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* STORE PROCEDURE: nsp_CheckOpenOrders_ADIDAS                          */        
/* CREATION DATE  : 13-July-2021                                        */        
/* WRITTEN BY     : LZG                                                 */        
/*                                                                      */        
/* PURPOSE: Check for ADIDAS orders which ready to wave                 */   
/*                                                                      */       
/* UPDATES:                                                             */        
/*                                                                      */       
/* DATE     AUTHOR   VER.  PURPOSES                                     */        
/*                                                                      */       
/************************************************************************/   
CREATE PROCEDURE [dbo].[nsp_CheckOpenOrders_ADIDAS]     
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE 
           @cOrderKey       NVARCHAR(10)
         , @cExternOrderKey NVARCHAR(50)
         , @cSKU            NVARCHAR(20)
         , @nOriginalQty    INT
         , @nOpenQty        INT 

   IF OBJECT_ID('TEMPDB..#OutResult') IS NOT NULL
       DROP TABLE #OutResult
   CREATE TABLE #OutResult (ID INT IDENTITY(1,1), OrderKey NVARCHAR(10) NULL, ExternOrderKey NVARCHAR(50), SKU NVARCHAR(20), OriginalQty INT, OpenQty INT)

   SELECT DISTINCT OD.OrderKey, OD.ExternOrderKey, SKU.SKU, OriginalQty, OpenQty INTO #TempTable FROM (
    SELECT ExternOrderKey, OrderKey, COUNT(DISTINCT SKU) 'SKUCount' FROM AUWMS..OrderDetail OD (NOLOCK) -- Get total SKU count in order
    WHERE StorerKey = 'ADIDAS'
    AND Status = '0'
    GROUP BY ExternOrderKey, OrderKey
   ) AS OD 
   JOIN (
       SELECT OrderKey, COUNT(DISTINCT LLI.SKU) 'InvCount' FROM AUWMS..OrderDetail OD (NOLOCK)  -- Get total SKU count after filter by 4PL locations
       LEFT JOIN AUWMS..LotxLocxID LLI (NOLOCK) ON LLI.SKU = OD.SKU AND LLI.StorerKey = OD.StorerKey AND LLI.Loc NOT IN ('4PLSTD','4PLQI') AND LLI.Loc NOT LIKE 'DRO%'
       WHERE OD.StorerKey = 'ADIDAS'
       AND OD.Status = '0'
       --AND OD.SKU NOT IN (SELECT SKU FROM AUWMS..LotxLocxID LLI (NOLOCK) WHERE StorerKey = 'ADIDAS' AND SKU = OD.SKU AND (LLI.Loc IN ('4PLSTD','4PLQI') OR LLI.Loc LIKE 'DRO%'))
       GROUP BY OrderKey
   ) AS INV ON INV.OrderKey = OD.OrderKey
   CROSS APPLY (
       SELECT DISTINCT OD.SKU, SUM(OriginalQty) 'OriginalQty', SUM(OpenQty) 'OpenQty' FROM AUWMS..OrderDetail OD (NOLOCK)
       --JOIN AUWMS..LotxLocxID LLI (NOLOCK) ON LLI.SKU = OD.SKU AND LLI.StorerKey = OD.StorerKey 
       WHERE OD.StorerKey = 'ADIDAS'
       AND OrderKey = INV.OrderKey
       --AND LLI.Loc NOT IN ('4PLSTD','4PLQI') 
       --AND LLI.Loc NOT LIKE 'DRO%'
       --AND Qty > 0
       GROUP BY OD.SKU
   ) SKU
   WHERE SKUCount = InvCount
   ORDER BY OD.OrderKey
   
   DECLARE CUR CURSOR FAST_FORWARD READ_ONLY FOR SELECT OrderKey, ExternOrderKey, SKU, OriginalQty, OpenQty FROM #TempTable
   OPEN CUR
   FETCH NEXT FROM CUR INTO @cOrderKey, @cExternOrderKey, @cSKU, @nOriginalQty, @nOpenQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN   
      
      IF NOT EXISTS (
         SELECT TOP 1 1 FROM AUWMS..OrderDetail OD (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND EXISTS (SELECT 1 FROM AUWMS..LotxLocxID (NOLOCK) WHERE SKU = OD.SKU AND (Loc IN ('4PLSTD','4PLQI') OR Loc LIKE 'DRO%'))
      )
      BEGIN 
         INSERT #OutResult (OrderKey, ExternOrderKey, SKU, OriginalQty, OpenQty) 
         VALUES (@cOrderKey, @cExternOrderKey, @cSKU, @nOriginalQty, @nOpenQty)
      END 
   
   FETCH NEXT FROM CUR INTO @cOrderKey, @cExternOrderKey, @cSKU, @nOriginalQty, @nOpenQty
   END
   CLOSE CUR
   DEALLOCATE CUR
   DROP TABLE #TempTable
   
   IF EXISTS (SELECT 1 FROM #OutResult)
   BEGIN 
       SELECT 
         OrderKey AS COLUMN_01, 
         ExternOrderKey AS COLUMN_02, 
         SKU AS COLUMN_03, 
         OriginalQty AS COLUMN_04, 
         OpenQty AS COLUMN_05, 
         '' AS COLUMN_06, 
         '' AS COLUMN_07, 
         '' AS COLUMN_08, 
         '' AS COLUMN_09, 
         '' AS COLUMN_10 FROM #OutResult ORDER BY ID 
   END
   
QUIT:
  
END  

GO