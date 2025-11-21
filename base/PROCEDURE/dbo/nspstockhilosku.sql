SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Stored Procedure: nspStockHiLoSku                                    */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspStockHiLoSku] (  
@StorerKeyMin   NVARCHAR(15),  
@StorerKeyMax   NVARCHAR(15),  
@SkuMin         NVARCHAR(20),  
@SkuMax         NVARCHAR(20),  
@DateMin        DATETIME,  
@DateMax        DATETIME  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
       
   SELECT DISTINCT  
   StorerKey,  
   Sku,  
   LTRIM(STR(DATEPART(YEAR,effectivedate))) + LTrim(STR(DATEPART(MONTH,effectivedate))) + LTrim(STR(DATEPART(DAY,effectivedate))) Date ,  
   0 Balance  
   INTO #BF  
   FROM ITRN  
   WHERE  
   StorerKey BETWEEN @StorerKeyMin AND @StorerKeyMax  
   AND Sku BETWEEN @SkuMin AND @SkuMax
   AND DATEDIFF(Day, @DateMin, effectivedate) >= 0
   AND DATEDIFF(Day, effectivedate, @DateMax) >= 0  
   --AND effectivedate >= Convert( datetime, @DateMin )  
   --AND effectivedate <  DateAdd( day, 1, Convert( datetime, @DateMax ) )  
   
   UPDATE #BF  
   SET Balance =  
   (SELECT ISNULL(SUM(qty), 0) -- Changed by June 18.Jul.03 (Add ISNULL) SOS12483  
   FROM ITRN  
   WHERE LTrim(STR(DATEPART(YEAR,effectivedate))) + LTrim(STR(DATEPART(MONTH,effectivedate))) + LTrim(STR(DATEPART(DAY,effectivedate))) <= #BF.Date  
   AND StorerKey = #BF.StorerKey  
   AND SKU = #BF.Sku  
   AND TranType IN ('DP', 'WD', 'AJ'))  
   SELECT *  
   FROM #BF  
   ORDER BY StorerKey, Sku, Date  
END  


GO