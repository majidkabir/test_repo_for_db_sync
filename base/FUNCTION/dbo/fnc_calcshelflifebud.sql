SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function       : fnc_CalcShelfLifeBUD                                */
/* Copyright      : Maersk Logistics                                    */
/*                                                                      */
/* Purpose: BUD has Finished Goods (FG). Need to calculate Shelf-Life.  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev   Author   Purposes                                  */
/* 2024-09-02  1.0   SBA757   Created UWP-23707                         */
/* 2024-01-23  1.1   Wan01    UWP-29372 - [FCR-1953] [Unilever] Modify  */
/*                            Shelf Life Code Calculation Function      */
/*                            - UDF04 value with delimiter fix          */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_CalcShelfLifeBUD]   
(
  @cStorerKey NVARCHAR(15),
  @cSKU       NVARCHAR(20),
  @dLottable04 DATETIME,
  @dLottable13 DATETIME
)  
RETURNS NVARCHAR(30)   
AS  
BEGIN  
   DECLARE @cShelfLife  NVARCHAR(30) = ''
   , @c_ItemClass       NVARCHAR(30) = ''
   , @cFrozenFood       NVARCHAR(16) = 'FROZEN_FOOD'
   , @cCabinets         NVARCHAR(16) = 'CABINETS'
   
   
   DECLARE @t_Codelkup  TABLE
   (  RowID       INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
   ,  ListName    NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  Code        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Short       NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  UDF01       NVARCHAR(60)   NOT NULL DEFAULT('')
   ,  UDF02       NVARCHAR(60)   NOT NULL DEFAULT('')
   ,  UDF03       NVARCHAR(60)   NOT NULL DEFAULT('')
   ,  UDF04       NVARCHAR(60)   NOT NULL DEFAULT('')
   ,  UDF05       NVARCHAR(60)   NOT NULL DEFAULT('')
   ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Code2       NVARCHAR(30)   NOT NULL DEFAULT('')
   )
   IF @dLottable04 IS NOT NULL AND @dLottable13 IS NOT NULL
   BEGIN
      SELECT @c_ItemClass = s.BUSR3
      FROM Sku s (NOLOCK)
      WHERE s.Storerkey = @cStorerKey
      AND   s.Sku = @cSKU

      INSERT INTO @t_Codelkup (ListName, Code, Short, UDF01, UDF02, UDF03, UDF04, UDF05, Storerkey, Code2)
      SELECT cl.ListName, cl.Code
           , Short = ISNULL(cl.Short,'')
           , cl.UDF01
           , UDF02 = IIF(ISNUMERIC(cl.UDF02)=0 AND (cl.UDF02 ='' AND cl.UDF03=''),'X',cl.UDF02)
           , UDF03 = IIF(ISNUMERIC(cl.UDF03)=0 AND (cl.UDF02 ='' AND cl.UDF03=''),'X',cl.UDF03)
           , [Value] As UDF04                                                       --Fixed
           , cl.UDF05
           , cl.Storerkey, cl.Code2 
      FROM dbo.Codelkup cl(NOLOCK) 
      CROSS APPLY STRING_SPLIT(cl.UDF04, ',')                                       --Fixed
      WHERE cl.ListName = 'SLCode'
      AND   cl.Storerkey= @cStorerkey
      AND   RTRIM(LTRIM([Value])) IN (@c_ItemClass, '')                             --Fixed

      SELECT TOP 1 @cShelfLife = CASE WHEN cl.UDF03 = '' AND DATEDIFF(dd, GETDATE(),@dLottable04) <  cl.UDF02 THEN cl.Code
                                      WHEN cl.UDF02 = '' AND DATEDIFF(dd, GETDATE(),@dLottable04) >= cl.UDF03 THEN cl.Code
                                      WHEN cl.UDF02 > '' AND cl.UDF03 > ''
                                      AND DATEDIFF(dd, GETDATE(),@dLottable04) >= cl.UDF03 
                                      AND DATEDIFF(dd, GETDATE(),@dLottable04) <  cl.UDF02 THEN cl.Code
                                      ELSE ''
                                      END
      FROM @t_Codelkup cl
      WHERE cl.UDF02 <> 'X'
      AND   cl.UDF03 <> 'X'
      ORDER BY CASE WHEN cl.UDF04 = @c_ItemClass THEN 1 ELSE 9 END
            ,  CASE WHEN cl.UDF03 = '' AND DATEDIFF(dd, GETDATE(),@dLottable04) <  cl.UDF02 THEN 1
                    WHEN cl.UDF02 = '' AND DATEDIFF(dd, GETDATE(),@dLottable04) >= cl.UDF03 THEN 1
                    WHEN cl.UDF02 <> '' AND cl.UDF03 <> ''
                    AND DATEDIFF(dd, GETDATE(),@dLottable04) >= cl.UDF03 
                    AND DATEDIFF(dd, GETDATE(),@dLottable04) <  cl.UDF02 THEN 1
                    ELSE 5
                    END 
            ,  cl.UDF03 DESC
            ,  cl.UDF02
            ,  cl.Code

      IF @cShelfLife = '' SET @cShelfLife = 'ML12'
      --SELECT @cShelfLife = 
      --   CASE
      --      WHEN CAST(DATEDIFF(dd, GETDATE(), @dLottable04) AS FLOAT) >= CAST(0.6 * DATEDIFF(dd, @dLottable13, @dLottable04) AS FLOAT) THEN 'ML11'
      --      WHEN SKU.BUSR3 = @cFrozenFood
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) > 210
      --         AND CAST(DATEDIFF(dd, GETDATE(),@dLottable04) AS FLOAT) < CAST(0.6 * DATEDIFF(dd, @dLottable13, @dLottable04) AS FLOAT)
      --      THEN 'ML19'
      --      WHEN SKU.BUSR3 = @cCabinets
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) > 390
      --         AND (CAST(DATEDIFF(dd, GETDATE(),@dLottable04) AS FLOAT)) < CAST(0.6 * DATEDIFF(dd, @dLottable13, @dLottable04) AS FLOAT)
      --      THEN 'ML19'
      --      WHEN SKU.BUSR3 = @cFrozenFood
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) > 60
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) < 211
      --         AND CAST(DATEDIFF(dd,GETDATE(),@dLottable04) AS FLOAT) < CAST(0.6 * DATEDIFF(dd, @dLottable13, @dLottable04) AS FLOAT)
      --      THEN 'ML18'
      --      WHEN SKU.BUSR3 = @cCabinets
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) > 60
      --         AND DATEDIFF(dd, GETDATE(),@dLottable04) < 391
      --         AND CAST(DATEDIFF(dd, GETDATE(),@dLottable04) AS FLOAT) < CAST(0.6 * DATEDIFF(dd, @dLottable13, @dLottable04) AS FLOAT)
      --      THEN 'ML18'
      --      WHEN DATEDIFF(dd, GETDATE(),@dLottable04) < 61 THEN 'ML13'
      --      ELSE 'ML12'
      --   END
      --FROM dbo.SKU SKU WITH (NOLOCK) 
      --WHERE SKU.StorerKey = @cStorerKey
      --AND SKU.Sku = @cSKU 
   END
   RETURN  @cShelfLife
END

GO