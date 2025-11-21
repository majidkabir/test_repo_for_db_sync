SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2013-06-03  KHLim       1.1   Title name changes (KH01)                         */
/* 2013-07-18  KHLim       1.2   Units by Reporting Quantity (KH02)                */
/* 2013-09-10  KHLim       1.3   Deliveries by Market Segment (KH03)               */
/* 2013-09-26  KHLim       1.4   SOS#283492, 283395: Facilities, Storers (KH04)    */
/* 2013-11-26  KHLim       1.5   Replace  s.MarketSegment  with  ISNULL(s.MarketSegment,'')  */
/* 2014-01-06  KHLim       1.6   Replace  NULL  with ''                            */
/* 2014-03-20  KHLim       1.7   Active SKUs added (KH05)                          */
/* 2015-04-02  KHLim       1.8   Toggle off debugging script (KHLim06)             */
/* 2015-07-13  TLTING      1.9   Add NOLOCK                                        */
/* 2015-07-13  KHLim       1.9   Correct syntax in dynamic SQL                     */
/* 2015-11-20  JayLim      2.0   Script Enhancement for SQL2012 compatible         */
/* 2016-11-22  KHLim       2.1   Increase precision when divided by large numbers  */
/***********************************************************************************/

CREATE PROC [dbo].[isp_WMS_CapacityMktSgmt]  
   @cCountry   NVARCHAR(5),         
   @cArchiveDB NVARCHAR(20),        
   @nMonth int = 0,        
   @nYear  int = 0        
AS        
SET NOCOUNT ON        
SET ANSI_WARNINGS OFF     
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF    
SET CONCAT_NULL_YIELDS_NULL OFF      
    
DECLARE @Statistic TABLE(        
   [Country] NVARCHAR(5),        
   [Year]    int,        
   [Month]   int,        
   [Title]   NVARCHAR(100),         
   [Qty]     bigint         
   ,[MarketSegment]  NVARCHAR(20)  
   ,[Db]             NVARCHAR(3)  
   ,[FacilityType]   NVARCHAR(20) NULL
)        
        
Declare @dStartDate     datetime,        
        @dEndDate       datetime,         
        @cSQL           nvarchar(4000)         
      
      
Declare @nDebug   int      
Set @nDebug = 0      -- KHLim06
        
IF @nMonth = 0 AND @nYear=0         
BEGIN         
   SET @dStartDate = CONVERT(Datetime, Cast(Year(GetDate()) as NVARCHAR(4)) +         
                     RIGHT('0' + RTRIM(Cast(Month(GetDate()) as NVARCHAR(2))),2) +          
                           '01')        
                                   
   SET @dEndDate   = DateAdd(month, 1, @dStartDate)         
   SET @dEndDate   = DateAdd(day, -1, @dEndDate)        
END        
ELSE        
BEGIN        
   SET @dStartDate = CONVERT(Datetime, Cast(@nYear as NVARCHAR(4)) +         
                     RIGHT('0' + RTRIM(Cast(@nMonth as NVARCHAR(2))),2) +          
                           '01')        
        
   SET @dEndDate   = DateAdd(month, 1, @dStartDate)         
   SET @dEndDate   = DateAdd(day, -1, @dEndDate)        
   SET @dEndDate   = CONVERT(varchar(10), @dEndDate, 112) + ' 23:59:59'        
END        
  
  
  
--  'Customer Orders'        
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Customer Orders',   
       Qty=COUNT(1), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   ORDERS AS o WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON o.StorerKey = s.StorerKey  
WHERE  o.AddDate Between @dStartDate AND @dEndDate         
AND    o.SOStatus <> 'CANC'         
AND    o.Status <> 'CANC'   
GROUP BY ISNULL(s.MarketSegment,'')  
    
SET @cSQL = N'        
   
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Customer Orders'',   
          Qty=ISNULL(COUNT(1), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.ORDERS AS o WITH (NOLOCK)  
   LEFT JOIN   STORER AS s (NOLOCK) ON o.StorerKey = s.StorerKey  
   WHERE  o.AddDate Between @dStartDate AND @dEndDate         
   AND    o.SOStatus <> ''CANC''    
   AND    o.Status   <> ''CANC''  
   GROUP BY ISNULL(s.MarketSegment,'''')'      
      
IF @nDebug = '1'      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry  
  
  
--  'Customer Order Lines'        
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Customer Order Detail',   
       Qty=COUNT(1), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   ORDERDETAIL AS od WITH (NOLOCK)         
JOIN   ORDERS AS o WITH (NOLOCK) ON od.OrderKey = o.OrderKey         
LEFT JOIN   STORER AS s (NOLOCK) ON o.StorerKey = s.StorerKey  
WHERE  od.AddDate Between @dStartDate AND @dEndDate         
AND    o.SOStatus <> 'CANC'         
AND    o.Status   <> 'CANC'      
GROUP BY ISNULL(s.MarketSegment,'')  
  
SET @cSQL = N'          
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Customer Order Detail'',   
          Qty=ISNULL(COUNT(1), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.ORDERDETAIL od WITH (NOLOCK)       
   JOIN   ' + @cArchiveDB + '.dbo.ORDERS o WITH (NOLOCK) ON od.OrderKey = o.OrderKey         
   LEFT JOIN   STORER AS s (NOLOCK) ON o.StorerKey = s.StorerKey  
   WHERE  od.AddDate Between @dStartDate AND @dEndDate         
   AND    o.SOStatus <> ''CANC''    
   AND    o.Status   <> ''CANC''  
   GROUP BY ISNULL(s.MarketSegment,'''')'    
      
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic  (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )        
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry  
  
        
--  'Receipts & Returns '        
INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  ) 
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Receipts & Returns',   
       Qty=COUNT(1), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   RECEIPT AS r WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON r.StorerKey = s.StorerKey  
WHERE  r.AddDate Between @dStartDate AND @dEndDate         
GROUP BY ISNULL(s.MarketSegment,'')  
  
SET @cSQL = N'        
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Receipts & Returns'',   
          Qty=ISNULL(COUNT(1), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.RECEIPT AS r WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON r.StorerKey = s.StorerKey  
   WHERE  r.AddDate Between @dStartDate AND @dEndDate  
   GROUP BY ISNULL(s.MarketSegment,'''')'        
      
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )        
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry  
  
    
-- units received by base quantity
INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  ) 
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Units Received by base quantity',   --KH01 KH04
       Qty=ISNULL(SUM(Cast(isnull(QtyReceived, 0)as bigint)),0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   RECEIPTDETAIL AS rd WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
WHERE  rd.AddDate Between @dStartDate AND @dEndDate         
GROUP BY ISNULL(s.MarketSegment,'')  
  
SET @cSQL = N'        
    
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Units Received by base quantity'',   
          Qty=ISNULL(SUM(Cast(isnull(QtyReceived, 0)as bigint)),0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL AS rd WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
   WHERE  rd.AddDate Between @dStartDate AND @dEndDate  
   GROUP BY ISNULL(s.MarketSegment,'''')'           --KH01
           
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )        
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry        


-- units received by reporting quantity      KH02
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  ) 
SELECT Cty=@cCountry, Yr=Year(rd.AddDate), Mth=Month(rd.AddDate), Title='Units Received by reporting quantity',
       Qty=ISNULL(Cast(SUM(isnull(rd.QtyReceived, 0)
     /(CASE WHEN IB_RPT_UOM=PackUOM1 AND pk.CaseCnt   >0 THEN (pk.CaseCnt   *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM2 AND pk.InnerPack >0 THEN (pk.InnerPack *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM3 AND pk.Qty       >0 THEN (pk.Qty       *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM4 AND pk.Pallet    >0 THEN (pk.Pallet    *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM5 AND pk.Cube      >0 THEN (pk.Cube      *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM6 AND pk.GrossWgt  >0 THEN (pk.GrossWgt  *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM7 AND pk.NetWgt    >0 THEN (pk.NetWgt    *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN (pk.OtherUnit1*1.0000000000)
            WHEN IB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN (pk.OtherUnit2*1.0000000000) ELSE 1 END)) as bigint),0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   RECEIPTDETAIL AS rd WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = rd.StorerKey AND sk.Sku = rd.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = rd.PackKey
WHERE EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (NOLOCK) ON Sku.PackKey = PACK.PackKey
               WHERE IB_RPT_UOM <> ''
               AND   IB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = rd.StorerKey AND SKU.Sku = rd.Sku )
AND rd.AddDate Between @dStartDate AND @dEndDate         
GROUP BY Year(rd.AddDate), Month(rd.AddDate), ISNULL(s.MarketSegment,'')  
UNION
SELECT Cty=@cCountry, Yr=Year(rd.AddDate), Mth=Month(rd.AddDate), Title='Units Received by reporting quantity',   --KH01
       Qty=ISNULL(SUM(Cast(isnull(rd.QtyReceived, 0) as bigint)),0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   RECEIPTDETAIL AS rd WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = rd.StorerKey AND sk.Sku = rd.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = rd.PackKey
WHERE NOT EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (NOLOCK) ON Sku.PackKey = PACK.PackKey
               WHERE IB_RPT_UOM <> ''
               AND   IB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = rd.StorerKey AND SKU.Sku = rd.Sku )
AND rd.AddDate Between @dStartDate AND @dEndDate         
GROUP BY Year(rd.AddDate), Month(rd.AddDate), ISNULL(s.MarketSegment,'')  


SET @cSQL = N'        
     
   SELECT Cty=@cCountry, Yr=Year(rd.AddDate), Mth=Month(rd.AddDate), Title=''Units Received by reporting quantity'',   
          Qty=ISNULL(Cast(SUM(isnull(rd.QtyReceived, 0)
     /(CASE WHEN IB_RPT_UOM=PackUOM1 AND pk.CaseCnt   >0 THEN (pk.CaseCnt   *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM2 AND pk.InnerPack >0 THEN (pk.InnerPack *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM3 AND pk.Qty       >0 THEN (pk.Qty       *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM4 AND pk.Pallet    >0 THEN (pk.Pallet    *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM5 AND pk.Cube      >0 THEN (pk.Cube      *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM6 AND pk.GrossWgt  >0 THEN (pk.GrossWgt  *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM7 AND pk.NetWgt    >0 THEN (pk.NetWgt    *1.0000000000)
            WHEN IB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN (pk.OtherUnit1*1.0000000000)
            WHEN IB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN (pk.OtherUnit2*1.0000000000) ELSE 1 END)) as bigint),0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL AS rd WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = rd.StorerKey AND sk.Sku = rd.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = rd.PackKey
   WHERE EXISTS ( SELECT 1 FROM SKU (nolock)
                  JOIN  PACK (NOLOCK) ON Sku.PackKey = PACK.PackKey
                  WHERE IB_RPT_UOM <> ''''
                  AND   IB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
                  AND   SKU.StorerKey = rd.StorerKey AND SKU.Sku = rd.Sku )
   AND  rd.AddDate Between @dStartDate AND @dEndDate  
   GROUP BY Year(rd.AddDate), Month(rd.AddDate), ISNULL(s.MarketSegment,'''')
   UNION
   SELECT Cty=@cCountry, Yr=Year(rd.AddDate), Mth=Month(rd.AddDate), Title=''Units Received by reporting quantity'',   --KH01
          Qty=ISNULL(SUM(Cast(isnull(rd.QtyReceived, 0) as bigint)),0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL AS rd WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON rd.StorerKey = s.StorerKey  
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = rd.StorerKey AND sk.Sku = rd.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = rd.PackKey
   WHERE NOT EXISTS ( SELECT 1 FROM SKU (nolock)
                  JOIN  PACK (NOLOCK) ON Sku.PackKey = PACK.PackKey
                  WHERE IB_RPT_UOM <> ''''
                  AND   IB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
                  AND   SKU.StorerKey = rd.StorerKey AND SKU.Sku = rd.Sku )
   AND  rd.AddDate Between @dStartDate AND @dEndDate  
   GROUP BY Year(rd.AddDate), Month(rd.AddDate), ISNULL(s.MarketSegment,'''') '
           
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic  (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )        
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry        



-- Units Shipped by base quantity
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Units Shipped by base quantity',   --KH01 KH04
       Qty=ISNULL(SUM(Cast(isnull(Qty, 0)as bigint)), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   PICKDETAIL AS p WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
WHERE  p.EditDate Between @dStartDate AND @dEndDate         
AND    p.Status = '9'         
GROUP BY ISNULL(s.MarketSegment,'')  
  
SET @cSQL = N'        
  
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Units Shipped by base quantity'',   
         Qty=ISNULL(SUM(Cast(isnull(Qty, 0)as bigint)), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL AS p WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
   WHERE  p.EditDate Between @dStartDate AND @dEndDate         
   AND    p.Status = ''9''  
   GROUP BY ISNULL(s.MarketSegment,'''') '        --KH01
      
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
   INSERT INTO @Statistic         
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry        


-- Units Shipped by reporting quantity       KH02
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(p.EditDate), Mth=Month(p.EditDate), Title='Units Shipped by reporting quantity',
       Qty=ISNULL(Cast(SUM(isnull(p.Qty, 0)
     /(CASE WHEN OB_RPT_UOM=PackUOM1 AND pk.CaseCnt   >0 THEN (pk.CaseCnt   *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM2 AND pk.InnerPack >0 THEN (pk.InnerPack *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM3 AND pk.Qty       >0 THEN (pk.Qty       *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM4 AND pk.Pallet    >0 THEN (pk.Pallet    *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM5 AND pk.Cube      >0 THEN (pk.Cube      *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM6 AND pk.GrossWgt  >0 THEN (pk.GrossWgt  *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM7 AND pk.NetWgt    >0 THEN (pk.NetWgt    *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN (pk.OtherUnit1*1.0000000000)
            WHEN OB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN (pk.OtherUnit2*1.0000000000) ELSE 1 END))as bigint), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   PICKDETAIL AS p WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
WHERE  p.Status = '9' 
AND EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
AND  p.EditDate Between @dStartDate AND @dEndDate         
GROUP BY Year(p.EditDate), Month(p.EditDate), ISNULL(s.MarketSegment,'')  
UNION
SELECT Cty=@cCountry, Yr=Year(p.EditDate), Mth=Month(p.EditDate), Title='Units Shipped by reporting quantity',   --KH01
       Qty=ISNULL(SUM(Cast(isnull(p.Qty, 0) as bigint)) , 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   PICKDETAIL AS p WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
WHERE  p.Status = '9' 
AND NOT EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
AND  p.EditDate Between @dStartDate AND @dEndDate         
GROUP BY Year(p.EditDate), Month(p.EditDate), ISNULL(s.MarketSegment,'')  


SET @cSQL = N'         
   SELECT Cty=@cCountry, Yr=Year(p.EditDate), Mth=Month(p.EditDate), Title=''Units Shipped by reporting quantity'',   
         Qty=ISNULL(Cast(SUM(isnull(p.Qty, 0)
     /(CASE WHEN OB_RPT_UOM=PackUOM1 AND pk.CaseCnt   >0 THEN (pk.CaseCnt   *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM2 AND pk.InnerPack >0 THEN (pk.InnerPack *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM3 AND pk.Qty       >0 THEN (pk.Qty       *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM4 AND pk.Pallet    >0 THEN (pk.Pallet    *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM5 AND pk.Cube      >0 THEN (pk.Cube      *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM6 AND pk.GrossWgt  >0 THEN (pk.GrossWgt  *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM7 AND pk.NetWgt    >0 THEN (pk.NetWgt    *1.0000000000)
            WHEN OB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN (pk.OtherUnit1*1.0000000000)
            WHEN OB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN (pk.OtherUnit2*1.0000000000) ELSE 1 END)) as bigint), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL AS p WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
   WHERE  p.Status = ''9''  
   AND EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
   AND  p.EditDate Between @dStartDate AND @dEndDate         
   GROUP BY Year(p.EditDate), Month(p.EditDate), ISNULL(s.MarketSegment,'''')
   UNION
   SELECT Cty=@cCountry, Yr=Year(p.EditDate), Mth=Month(p.EditDate), Title=''Units Shipped by reporting quantity'',   
         Qty=ISNULL(SUM(Cast(isnull(p.Qty, 0) as bigint)), 0), ISNULL(s.MarketSegment,''''), Db=''ARC'', ''''
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL AS p WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON p.StorerKey = s.StorerKey  
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
   WHERE  p.Status = ''9''  
   AND NOT EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
   AND  p.EditDate Between @dStartDate AND @dEndDate         
   GROUP BY Year(p.EditDate), Month(p.EditDate), ISNULL(s.MarketSegment,'''') '
      
IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
 INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )        
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',        
   @dStartDate, @dEndDate, @cCountry    


-- Deliveries    
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Deliveries',   --KH01 KH03 KH04
       Qty=ISNULL(COUNT(1), 0),  ISNULL(s.MarketSegment,'') ,  Db='WMS', ''
FROM
(  SELECT l.LoadKey, MAX(a.StorerKey) AS StorerKey
   FROM   LOADPLAN AS l WITH (NOLOCK)
   LEFT JOIN ORDERS AS a (NOLOCK)
   ON l.LoadKey = a.LoadKey
   WHERE  l.EditDate Between @dStartDate AND @dEndDate
   AND    l.Status = '9'
   GROUP BY l.LoadKey   ) AS o
LEFT JOIN STORER AS s (NOLOCK) 
ON o.StorerKey = s.StorerKey
GROUP BY ISNULL(s.MarketSegment,'')

SET @cSQL = N'    
    
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title=''Deliveries'',   
         Qty=ISNULL(COUNT(1), 0),  ISNULL(s.MarketSegment,'''') ,  Db=''ARC'', ''''
   FROM   
   (  SELECT l.LoadKey, MAX(a.StorerKey) AS StorerKey
      FROM   ' + @cArchiveDB + '.dbo.LOADPLAN AS l WITH (NOLOCK)
      LEFT JOIN ' + @cArchiveDB + '.dbo.ORDERS AS a (NOLOCK) 
      ON l.LoadKey = a.LoadKey
      WHERE  l.EditDate Between @dStartDate AND @dEndDate
      AND    l.Status = ''9''
      GROUP BY l.LoadKey   ) AS o
   LEFT JOIN STORER AS s (NOLOCK)
   ON o.StorerKey = s.StorerKey
   GROUP BY ISNULL(s.MarketSegment,'''') '    --KH03 KH04

IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END      
INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @cCountry NVARCHAR(5)',    
   @dStartDate, @dEndDate, @cCountry    
       


--  'Facilities '          --KH04 start
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Facilities',   
       Qty=COUNT(1), '', Db='WMS', ISNULL(Type,'')
FROM   FACILITY AS f WITH (NOLOCK)
WHERE  f.AddDate Between @dStartDate AND @dEndDate
GROUP BY Type

IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END


--  'Storers ' --KH04 end
INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Storers',   
       --Qty=COUNT(DISTINCT CASE WHEN CustomerGroupCode = '' THEN StorerKey ELSE CustomerGroupCode END), ISNULL(s.MarketSegment,''), Db='WMS'  
       Qty=COUNT(1), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   STORER AS s (NOLOCK) 
WHERE  s.AddDate Between @dStartDate AND @dEndDate
AND    Type = '1'
GROUP BY ISNULL(s.MarketSegment,'')  

IF @nDebug = 1      
BEGIN      
   PRINT @cSQL  
END


-- Active SKUs added
INSERT INTO @Statistic   (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  ) 
SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Active SKUs added',   
         Qty=ISNULL(COUNT(Distinct l.SKU), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
FROM   LOT AS l WITH (NOLOCK)        
LEFT JOIN   STORER AS s (NOLOCK) ON l.StorerKey = s.StorerKey  
LEFT JOIN   SKU   AS sk (NOLOCK) ON l.StorerKey = sk.StorerKey  AND  l.Sku = sk.Sku  
WHERE  sk.AddDate Between @dStartDate AND @dEndDate
-- WHERE  Qty > 0  
GROUP BY ISNULL(s.MarketSegment,'')  


IF @nMonth = DatePart(month, GetDate()) AND @nYear = DatePart(year, GetDate())  -- Active, number of SKUs & Unit of SOH are all current stat only  
BEGIN  
   -- Active SKUs         
   INSERT INTO @Statistic  (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )  
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Active SKUs',   
          Qty=ISNULL(COUNT(Distinct SKU), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
   FROM   LOT AS l WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON l.StorerKey = s.StorerKey  
   -- WHERE  Qty > 0  
  GROUP BY ISNULL(s.MarketSegment,'')  
  
  
   -- Number of SKUs  
   INSERT INTO @Statistic  (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )  
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Number of SKUs',   
          Qty=ISNULL(COUNT(1), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
   FROM   SKU AS sk WITH (NOLOCK)  
   LEFT JOIN   STORER AS s (NOLOCK) ON sk.StorerKey = s.StorerKey  
   GROUP BY ISNULL(s.MarketSegment,'')  
  
  
   -- Units of Stock on Hand         
   INSERT INTO @Statistic    (  [Country],  [Year],   [Month],    [Title],   [Qty],[MarketSegment]   ,[Db]  ,[FacilityType]  )
   SELECT Cty=@cCountry, Yr=Year(@dStartDate), Mth=Month(@dStartDate), Title='Units of Stock on Hand',   
          Qty=ISNULL(SUM(cast(Qty as bigint)), 0), ISNULL(s.MarketSegment,''), Db='WMS', ''
   FROM   SKUxLOC AS sl WITH (NOLOCK)        
   LEFT JOIN   STORER AS s (NOLOCK) ON sl.StorerKey = s.StorerKey  
   WHERE  sl.Qty > 0         
   GROUP BY ISNULL(s.MarketSegment,'')  
END  
  
  
SELECT [Country], [Year], [Month], [Title], [Qty]=SUM(Cast([Qty] as bigint)), [MarketSegment], [FacilityType]
FROM @Statistic    
GROUP BY [Country], [Year], [Month], [Title], [MarketSegment], [FacilityType]
ORDER BY [Title], [MarketSegment], [FacilityType]
  


GO