SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_GetCartonsShipByPickUpDate                      */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Insert PackDetail after each scan of Case ID                */    
/*                                                                      */    
/* Called from: rdtfnc_Scan_And_Pack                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author Purposes                                     */   
/* 08-JUN-2010 1.0  Shong  Created                                      */    
/* 02-JUL-2010 1.1  Shong  Exclude Shipped Carton                       */
/************************************************************************/    
CREATE PROC [dbo].[isp_GetCartonsShipByPickUpDate]   
   @cFacility  NVARCHAR(5),  
   @cPrinciple NVARCHAR(15)   
AS   
SET NOCOUNT ON  
  
IF OBJECT_ID('tempdb..#t_OrdPlanning') IS NOT NULL  
   DROP TABLE #t_OrdPlanning  
     
CREATE TABLE   
#t_OrdPlanning (  
   StorerKey   NVARCHAR(15),  
   CompanyName NVARCHAR(45),  
   DayBefore   INT,  
   Day1        INT,  
   Day2        INT,  
   Day3        INT,  
   Day4        INT,  
   Day5        INT,  
   Day6        INT,  
   Day7        INT,  
   DayAfter    INT,  
   NoPickDt    INT,  
   DayBeforeCplt INT NULL DEFAULT 0,  
   Day1Cplt      INT NULL DEFAULT 0,  
   Day2Cplt      INT NULL DEFAULT 0,  
   Day3Cplt      INT NULL DEFAULT 0,  
   Day4Cplt      INT NULL DEFAULT 0,  
   Day5Cplt      INT NULL DEFAULT 0,  
   Day6Cplt      INT NULL DEFAULT 0,  
   Day7Cplt      INT NULL DEFAULT 0,  
   DayAfterCplt  INT NULL DEFAULT 0,  
   NoPickDtCplt  INT NULL DEFAULT 0      
)  
  
DECLARE @cStorerKey   NVARCHAR(15),  
   @cCompanyName NVARCHAR(45),  
   @nDayBefore   INT,  
   @nDay1        INT,  
   @nDay2        INT,  
   @nDay3        INT,  
   @nDay4        INT,  
   @nDay5        INT,  
   @nDay6        INT,  
   @nDay7        INT,  
   @nDayAfter    INT,  
   @nNoPickDt    INT,  
   @nDayBeforeCplt   INT,  
   @nDay1Cplt        INT,  
   @nDay2Cplt        INT,  
   @nDay3Cplt        INT,  
   @nDay4Cplt        INT,  
   @nDay5Cplt        INT,  
   @nDay6Cplt        INT,  
   @nDay7Cplt        INT,  
   @nDayAfterCplt    INT,  
   @nNoPickDtCplt    INT     
     
DECLARE @cOrderKey   NVARCHAR(10),  
        @dStartPickUpDate DATETIME,  
        @dEndPickUpDate   DATETIME,  
        @nCartons    INT,  
        @cParentSKU  NVARCHAR(20),  
        @nQty        INT,   
        @nPackQty    INT,   
        @nUOMQty     INT,  
        @cSKU        NVARCHAR(20),  
        @cSelect     NVARCHAR(MAX),   
        @nCartonLabels INT   
           
DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
SELECT o.StorerKey, CONVERT(Datetime, CONVERT(NVARCHAR(20), m.UserDefine07, 112)) AS StartPickUpDate,      
       CONVERT(Datetime, CONVERT(NVARCHAR(20), m.UserDefine07, 112)) + ' 23:59:59'   
FROM ORDERS o WITH (NOLOCK)  
LEFT OUTER JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = o.OrderKey   
LEFT OUTER JOIN MBOL m WITH (NOLOCK) ON m.MbolKey = md.MbolKey   
JOIN STORER s (NOLOCK) ON s.StorerKey = o.StorerKey   
WHERE o.Facility = @cFacility  
AND s.B_ISOCntryCode = CASE WHEN @cPrinciple = 'ALL' THEN s.B_ISOCntryCode ELSE @cPrinciple END        
AND o.Status <> 'CANC'  
GROUP BY o.StorerKey, CONVERT(Datetime, CONVERT(NVARCHAR(20), m.UserDefine07, 112)),      
       CONVERT(Datetime, CONVERT(NVARCHAR(20), m.UserDefine07, 112)) + ' 23:59:59'   
ORDER BY StartPickUpDate, o.StorerKey  
  
OPEN cur1  
  
FETCH NEXT FROM CUR1 INTO @cStorerKey, @dStartPickUpDate, @dEndPickUpDate   
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   SELECT @cCompanyName = Company  
   FROM   STORER s WITH (NOLOCK)  
   WHERE  s.StorerKey = @cStorerKey  
     
   SET @nDayBefore   =0  
   SET @nDay1        =0  
   SET @nDay2 =0  
   SET @nDay3        =0  
   SET @nDay4        =0  
   SET @nDay5        =0  
   SET @nDay6        =0  
   SET @nDay7        =0  
   SET @nDayAfter    =0  
   SET @nNoPickDt    =0  
   SET @nCartons     =0  
   SET @nCartonLabels=0  
   SET @nDayBeforeCplt =0  
   SET @nDay1Cplt      =0  
   SET @nDay2Cplt      =0  
   SET @nDay3Cplt      =0  
   SET @nDay4Cplt      =0  
   SET @nDay5Cplt      =0  
   SET @nDay6Cplt      =0  
   SET @nDay7Cplt      =0  
   SET @nDayAfterCplt  =0  
   SET @nNoPickDtCplt  =0     
   --Do they pack?  
   IF @dStartPickUpDate IS NOT NULL  
   BEGIN  
      SELECT @nCartonLabels = ISNULL(COUNT(DISTINCT pd.LabelNo),0)   
      FROM PackDetail pd WITH (NOLOCK)  
      JOIN PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo   
      JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey    
      LEFT OUTER JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = o.OrderKey   
      LEFT OUTER JOIN MBOL m WITH (NOLOCK) ON m.MbolKey = md.MbolKey   
      JOIN STORER s (NOLOCK) ON s.StorerKey = o.StorerKey   
      WHERE o.Facility = @cFacility   
      AND s.B_ISOCntryCode = CASE WHEN @cPrinciple = 'ALL' THEN s.B_ISOCntryCode ELSE @cPrinciple END         
      AND o.Status <> 'CANC'
      -- Change By SHONG on 02-07-2010 exclude Status 9 Orders  
      -- AND ( o.Status <> CASE WHEN GetDate() Between @dStartPickUpDate AND @dEndPickUpDate THEN 'CANC'  
      --                      ELSE '9'   
      --                 END)
      AND o.Status <> '9'      
      AND m.UserDefine07 BETWEEN @dStartPickUpDate AND @dEndPickUpDate    
      AND ph.StorerKey = @cStorerKey     
   END   
   ELSE  
   BEGIN  
      SELECT @nCartonLabels = COUNT(DISTINCT pd.LabelNo)   
      FROM PackDetail pd WITH (NOLOCK)  
      JOIN PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo   
      JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey    
      LEFT OUTER JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = o.OrderKey   
      LEFT OUTER JOIN MBOL m WITH (NOLOCK) ON m.MbolKey = md.MbolKey   
      JOIN STORER s (NOLOCK) ON s.StorerKey = o.StorerKey   
      WHERE o.Facility = @cFacility   
      AND s.B_ISOCntryCode = CASE WHEN @cPrinciple = 'ALL' THEN s.B_ISOCntryCode ELSE @cPrinciple END         
      AND o.Status NOT IN ('9','CANC')       
      AND m.UserDefine07 IS NULL     
      AND ph.StorerKey = @cStorerKey     
             
   END      
  
   IF @nCartons = 0   
   BEGIN  
      IF @dStartPickUpDate IS NULL  
      BEGIN        
         DECLARE CUR2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT od.SKU, ISNULL(l.Lottable03, '') AS ParentSKU,   
                SUM(ISNULL(p.Qty, od.OpenQty)) AS Qty   
         FROM ORDERS o WITH (NOLOCK)   
         JOIN ORDERDETAIL od WITH (NOLOCK) ON od.OrderKey = o.OrderKey  
         JOIN STORER s (NOLOCK) ON s.StorerKey = o.StorerKey   
         LEFT OUTER JOIN PICKDETAIL p WITH (NOLOCK) ON p.OrderKey = od.OrderKey AND p.OrderLineNumber = od.OrderLineNumber   
         JOIN LOTATTRIBUTE l WITH (NOLOCK) ON p.Lot = l.Lot          
         LEFT OUTER JOIN PackHeader ph WITH (NOLOCK) ON ph.OrderKey = o.OrderKey  
         LEFT OUTER JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = o.OrderKey   
         LEFT OUTER JOIN MBOL m WITH (NOLOCK) ON m.MbolKey = md.MbolKey   
         WHERE o.Facility = @cFacility   
         AND s.B_ISOCntryCode = CASE WHEN @cPrinciple = 'ALL' THEN s.B_ISOCntryCode ELSE @cPrinciple END         
         AND o.Status NOT IN ('9','CANC')        
         AND m.UserDefine07 IS NULL     
         AND o.StorerKey = @cStorerKey           
         AND ph.PickSlipNo IS NULL   
         GROUP BY od.SKU, ISNULL(l.Lottable03, '')  
           
      END  
      ELSE  
      BEGIN        
         DECLARE CUR2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT od.SKU, ISNULL(l.Lottable03, '') AS ParentSKU,   
                SUM(ISNULL(p.Qty, od.OpenQty)) AS Qty   
         FROM ORDERS o WITH (NOLOCK)   
         JOIN ORDERDETAIL od WITH (NOLOCK) ON od.OrderKey = o.OrderKey  
         JOIN STORER s (NOLOCK) ON s.StorerKey = o.StorerKey   
         LEFT OUTER JOIN PICKDETAIL p WITH (NOLOCK) ON p.OrderKey = od.OrderKey AND p.OrderLineNumber = od.OrderLineNumber   
         JOIN LOTATTRIBUTE l WITH (NOLOCK) ON p.Lot = l.Lot          
         LEFT OUTER JOIN PackHeader ph WITH (NOLOCK) ON ph.OrderKey = o.OrderKey   
         LEFT OUTER JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = o.OrderKey   
         LEFT OUTER JOIN MBOL m WITH (NOLOCK) ON m.MbolKey = md.MbolKey   
         WHERE o.Facility = @cFacility   
         AND s.B_ISOCntryCode = CASE WHEN @cPrinciple = 'ALL' THEN s.B_ISOCntryCode ELSE @cPrinciple END         
         AND o.Status <> 'CANC'
         -- Change By SHONG on 02-07-2010 exclude Status 9 Orders    
         -- AND ( o.Status <> CASE WHEN GetDate() Between @dStartPickUpDate AND @dEndPickUpDate THEN 'CANC'  
         --                      ELSE '9'   
         --                 END)
         AND o.Status <> '9'                 
         AND m.UserDefine07 BETWEEN @dStartPickUpDate AND @dEndPickUpDate      
         AND o.StorerKey = @cStorerKey           
         AND ph.PickSlipNo IS NULL   
         GROUP BY od.SKU, ISNULL(l.Lottable03, '')  
           
             
      END  
                          
      OPEN CUR2  
        
      FETCH NEXT FROM CUR2 INTO @cSKU, @cParentSKU, @nQty   
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @cParentSKU = ''  
         BEGIN  
            SELECT TOP 1   
               @cParentSKU = Lottable03  
            FROM  LOT L (NOLOCK)  
            JOIN  LOTATTRIBUTE LA (NOLOCK) ON L.Lot = LA.LOT   
            WHERE L.StorerKey = @cStorerKey AND L.SKU = @cSKU    
            ORDER BY Qty DESC  
         END  
  
  
              
         SELECT @nPackQty = ISNULL(SUM(Qty),1)  
         FROM   BillOfMaterial bom WITH (NOLOCK)  
         WHERE  bom.SKU = @cParentSKU  
         AND    bom.Storerkey = @cStorerKey  
           
         SET @nUOMQty = 1  
         SELECT @nUOMQty = ISNULL(p.CaseCnt,1)  
         FROM   UPC u WITH (NOLOCK)   
         JOIN   PACK p WITH (NOLOCK) ON p.PackKey = u.PackKey   
         WHERE  u.StorerKey = @cStorerKey   
         AND    u.SKU = @cParentSKU  
         AND    u.UOM = 'CS'   
           
         SET @nCartons = ISNULL(@nCartons,0) + (@nQty / (@nPackQty * @nUOMQty))  
              
         FETCH NEXT FROM CUR2 INTO @cSKU, @cParentSKU, @nQty  
      END  
      CLOSE CUR2  
      DEALLOCATE CUR2  
  
   END  
        
   SET @nCartons = ISNULL(@nCartons,0) + ISNULL(@nCartonLabels,0)   
     
   IF @nCartons = 0 GOTO SKIP_NEXT  
   IF @dStartPickUpDate IS NULL   
   BEGIN  
        
      SET @nNoPickDt = @nCartons  
      SET @nNoPickDtCplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) < 0   
   BEGIN  
      SET @nDayBefore = @nCartons  
      SET @nDayBeforeCplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 0   
   BEGIN  
      SET @nDay1 = @nCartons  
      SET @nDay1Cplt = @nCartonLabels  
        
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 1   
   BEGIN  
      SET @nDay2 = @nCartons  
      SET @nDay2Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 2   
   BEGIN  
      SET @nDay3 = @nCartons  
      SET @nDay3Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 3   
   BEGIN  
      SET @nDay4 = @nCartons  
      SET @nDay4Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 4   
   BEGIN  
      SET @nDay5 = @nCartons  
      SET @nDay5Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 5   
   BEGIN  
      SET @nDay6 = @nCartons  
      SET @nDay6Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) = 6   
   BEGIN  
      SET @nDay7 = @nCartons  
      SET @nDay7Cplt = @nCartonLabels  
   END  
   ELSE IF DATEDIFF(DAY, GETDATE(), @dStartPickUpDate) > 6   
   BEGIN  
      SET @nDayAfter = @nCartons  
      SET @nDayAfterCplt = @nCartonLabels  
   END  
     
   --SELECT @cStorerKey, @cOrderKey, @nDayBefore, @nDay1, @nDay2, @nDay3,  
   --           @nDay4, @nDay5, @nDay6, @nDay7, @nDayAfter, @nNoPickDt  
      
   IF NOT EXISTS(SELECT 1 FROM #t_OrdPlanning top1 WHERE top1.StorerKey = @cStorerKey)  
   BEGIN  
      INSERT INTO #t_OrdPlanning  
        (  
          StorerKey, CompanyName, DayBefore, Day1, Day2, Day3, Day4, Day5, Day6, Day7,   
          DayAfter, NoPickDt, DayBeforeCplt, Day1Cplt, Day2Cplt, Day3Cplt, Day4Cplt,   
          Day5Cplt, Day6Cplt, Day7Cplt, DayAfterCplt, NoPickDtCplt  
        )  
      VALUES  
        (  
          @cStorerKey, @cCompanyName, @nDayBefore, @nDay1, @nDay2, @nDay3, @nDay4, @nDay5,   
          @nDay6, @nDay7, @nDayAfter, @nNoPickDt, @nDayBeforeCplt, @nDay1Cplt,   
          @nDay2Cplt, @nDay3Cplt, @nDay4Cplt,   
          @nDay5Cplt, @nDay6Cplt, @nDay7Cplt, @nDayAfterCplt, @nNoPickDtCplt  
        )              
   END  
   ELSE  
   BEGIN  
      UPDATE #t_OrdPlanning   
         SET DayBefore = DayBefore + @nDayBefore,  
         Day1 = Day1 + @nDay1,  
         Day2 = Day2 + @nDay2,  
         Day3 = Day3 + @nDay3,  
         Day4 = Day4 + @nDay4,  
         Day5 = Day5 + @nDay5,  
         Day6 = Day6 + @nDay6,  
         Day7 = Day7 + @nDay7,  
         DayAfter = DayAfter + @nDayAfter,  
         NoPickDt = NoPickDt + @nNoPickDt,  
         DayBeforeCplt = ISNULL(DayBeforeCplt,0) + @nDayBeforeCplt,  
         Day1Cplt = ISNULL(Day1Cplt,0) + @nDay1Cplt,   
         Day2Cplt = ISNULL(Day2Cplt,0) + @nDay2Cplt,  
         Day3Cplt = ISNULL(Day3Cplt,0) + @nDay3Cplt,  
         Day4Cplt = ISNULL(Day4Cplt,0) + @nDay4Cplt,  
         Day5Cplt = ISNULL(Day5Cplt,0) + @nDay5Cplt,  
         Day6Cplt = ISNULL(Day6Cplt,0) + @nDay6Cplt,  
         Day7Cplt = ISNULL(Day7Cplt,0) + @nDay7Cplt,  
         DayAfterCplt = ISNULL(DayAfterCplt,0) + @nDayAfterCplt,  
         NoPickDtCplt = ISNULL(NoPickDtCplt,0) + @nNoPickDtCplt   
           
            
      WHERE StorerKey = @cStorerKey         
   END  
   SKIP_NEXT:  
   FETCH NEXT FROM CUR1 INTO @cStorerKey, @dStartPickUpDate, @dEndPickUpDate  
END  
CLOSE CUR1  
DEALLOCATE CUR1  
  
SELECT   
 StorerKey,   
 CompanyName,  
 DayBefore,  
 Day1,  
 Day2,  
 Day3,  
 Day4,  
 Day5,  
 Day6,   
 Day7,  
 DayAfter,   
 NoPickDt,  
 DayBeforeCplt,   
 Day1Cplt,       
 Day2Cplt,       
 Day3Cplt,       
 Day4Cplt,       
 Day5Cplt,       
 Day6Cplt,       
 Day7Cplt,       
 DayAfterCplt,   
 NoPickDtCplt,   
 GETDATE()                                    
 FROM #t_OrdPlanning    
ORDER BY StorerKey

GO