SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function       : fnc_CalcShelfLifeBUL                                */
/* Copyright      : Maersk Logistics                                    */
/*                                                                      */
/* Purpose: BUL has Finished Goods (FG) and Raw Material and Packaging  */
/*          Material (RMP). Need to calculate for 5 Shelf-Life rules.   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2012-04-13   1.0  Shong      Created UWP-22021                       */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_CalcShelfLifeBUL]   
(  
  @cStorerKey NVARCHAR(15),
  @cSKU       NVARCHAR(20),
  @dLottable04 DATETIME
)  
RETURNS NVARCHAR(30)   
AS  
BEGIN  
   DECLARE @cShelfLife  NVARCHAR(30) 
      
   SELECT @cShelfLife = 
      CASE
         WHEN SKU.SKUGROUP = 'FG' AND DATEDIFF (dd, GETDATE(),@dLottable04) > 180 THEN 'ML47'
         WHEN SKU.SKUGROUP = 'FG' AND DATEDIFF (dd, GETDATE(),@dLottable04)  <= 180 AND DATEDIFF (dd, GETDATE(), @dLottable04) > 0 THEN 'ML48'
         WHEN SKU.SKUGROUP = 'FG' AND DATEDIFF(dd, GETDATE(),@dLottable04)  <= 0 THEN 'ML49'
         WHEN SKU.SKUGROUP IN ('RM', 'PC') AND DATEDIFF(dd, GETDATE(),@dLottable04) > 0 THEN 'ML50'      
         WHEN SKU.SKUGROUP IN ('RM', 'PC') AND DATEDIFF(dd, GETDATE(),@dLottable04) <= 0 THEN 'ML51'
         ELSE ''
      END 
   FROM dbo.SKU SKU WITH (NOLOCK) 
   WHERE SKU.StorerKey = @cStorerKey
   AND SKU.Sku = @cSKU 

   RETURN  @cShelfLife
END

GO