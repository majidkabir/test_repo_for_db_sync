SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 09-Apr-2015  KHLim      1.1   Add Total_UnitShipped (KHLim01)        */   
/* 2015-07-13  TLTING      1.2   Add NOLOCK                             */
/* 03-Dec-2015  JayLim     1.3   Changing #tables to declared tables    */
/* 20-Dec-2015  KHLim      1.4   Move out Insert stmt from dynamic SQL  */
/* 12-May-2017  JayLim     1.5   Add Company Column (jay01)             */
/* 15-May-2017 JayLim      1.6   Add New column (jay02)                 */   
/*                              -FacilityAddress -Vertical -Default_UOM */
/*                           -Total_UnitReceipt_CS,Total_UnitShipped_CS */
/* 24-May-2017 JayLim      1.7   Add New Column (jay03)                 */
/*                               customergroupcode, customergroupname   */
/* 19-Jun-2017 JayLim      1.8  Column datalength bug fix (jay04)       */
/************************************************************************/
     
CREATE PROC [dbo].[isp_WMS_Capacity_statistic]     
  -- @cServer    NVARCHAR(20),  
   @cCountry   NVARCHAR(10),  
   @cArchiveDB NVARCHAR(20),    
   @nMonth int = 0,    
   @nYear  int = 0    
AS    
  SET NOCOUNT ON   
   SET ANSI_WARNINGS ON  
--  SET QUOTED_IDENTIFIER OFF   
--  SET ANSI_NULLS OFF     
--  SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @t_Statistic TABLE (   
   [Country]         NVARCHAR(10),  
   [Month]           int,   
   [Year]            int,   
   [Facility]        NVARCHAR(5),
   [StorerKey]       NVARCHAR(15),  
   Total_SKU         BigInt,  
   Total_ActiveSKU   BigInt,  
   Total_Receipts    BigInt,   
   Total_UnitReceipt BigInt,   
   Total_Orders      BigInt,   
   Total_OrderLines  BigInt,   
   Total_UnitPicked  BigInt,   
   Total_Deliveries  BigInt,  
   AddDate           Datetime  
   ,Total_UnitShipped BigInt --KHLim01
   ,[Company]         NVARCHAR(50)  --(jay01) --(jay04) NVARCHAR(45)
   ,[FacilityAddress] NVARCHAR(50)  --(jay02)
   ,[Vertical]        NVARCHAR(20)  --(jay02) --Marketsegment
   ,[Default_UOM]     NVARCHAR(10)  --(jay02)
   ,[Total_UnitReceipt_CS] BIGINT   --(jay02)
   ,[Total_UnitShipped_CS] BIGINT   --(jay02)
   ,[CustomerGroupCode] NVARCHAR(20) --(jay03)
   ,[CustomerGroupName] NVARCHAR(120) --(jay03)
)    
  
DECLARE @Temp_Item  TABLE
(      
     [StorerKey]  NVARCHAR(15),
     [Facility]   NVARCHAR(5),  
      Type        NVARCHAR(10),  
      Source      NVARCHAR(1),  
      Qty         BigInt,
      UOM         NVARCHAR(10) DEFAULT '', --(jay02)
     [Qty_CS]     BIGINT      default 0   --(jay02)
) 
    
Declare @dStartDate     datetime,    
        @dEndDate       datetime,     
        @nQty           bigint,     
        @nArchivedQty   bigint,     
        @cSQL           nvarchar(4000)  --KHLim01
  
Declare @cStorerkey     NVARCHAR(15),   
        @cFacility      NVARCHAR(5),  
        @cType          NVARCHAR(10),
        @cCompany       NVARCHAR(50),   --(jay01)
        @cFacilityAddress NVARCHAR(50), --(jay02)  
        @cVertical      NVARCHAR(20),   --(jay02)
        @cUOM           NVARCHAR(10),    --(jay02) --(jay04) NVARCHAR(5)
        @nQty_CS        BIGINT
       ,@cCustomerGroupCode NVARCHAR(20) --(jay03)
       ,@cCustomerGroupName NVARCHAR(120) --(jay03)
    
IF @nMonth = 0 AND @nYear=0     
BEGIN     
   SET @dStartDate = CONVERT(Datetime, Cast(Year(GetDate()) as NVARCHAR(4)) +     
                     RIGHT('0' + RTRIM(Cast(Month(GetDate()) as NVARCHAR(2))),2) +      
                           '01')    
                               
   SET @dEndDate   = DateAdd(month, 1, @dStartDate)     
   SET @dEndDate   = DateAdd(day, -1, @dEndDate)   
   SET @nMonth     = Month(@dStartDate)  
   SET @nYear      = Year(@dStartDate)  
   
END    
ELSE    
BEGIN    
   SET @dStartDate = CONVERT(Datetime, Cast(@nYear as NVARCHAR(4)) +     
                     RIGHT('0' + RTRIM(Cast(@nMonth as NVARCHAR(2))),2) +      
                           '01')    
   
   SET @dEndDate   = DateAdd(month, 1, @dStartDate)     
   SET @dEndDate   = DateAdd(day, -1, @dEndDate)    
END    
  
-- Total SKUs     
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )  
SELECT SKU.StorerKey, '', 'SKU', 'A',  COUNT(1)     
FROM   SKU WITH (NOLOCK)   
Group by SKU.Storerkey 
ORDER by SKU.Storerkey  
  
-- Active SKUs     
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )  
SELECT LOT.StorerKey, ISNULL(Loc.Facility, ''), 'AS', 'A',  COUNT(Distinct Lot.SKU)     
FROM   LOT WITH (NOLOCK)   
   JOIN LotxLoc WITH (NOLOCK) on ( LotxLoc.Lot = LOT.LOT )  
   JOIN Loc WITH (NOLOCK)     on ( Loc.Loc = LotxLoc.Loc  )  
Group by LOT.StorerKey, Loc.Facility  
  
  
--  'Receipts & Returns '    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )  
SELECT r.StorerKey, ISNULL(r.Facility, ''), 'RH', 'A', COUNT(1)     
FROM   RECEIPT r WITH (NOLOCK)
INNER JOIN Storer s WITH (NOLOCK) ON (r.StorerKey=s.StorerKey) 
WHERE  r.AddDate Between @dStartDate AND @dEndDate    
Group by r.StorerKey, ISNULL(r.Facility, '')    
   
SET @cSQL = N' SELECT StorerKey, ISNULL(Facility, ''''), ''RH'', ''B'', COUNT(1)      
   FROM   ' + @cArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)    
   WHERE  AddDate Between @dStartDate AND @dEndDate  
   Group by StorerKey, ISNULL(Facility, '''') '    
    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )  
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime',    
   @dStartDate, @dEndDate  
  
-- units received & putaway     
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty, UOM, Qty_CS )  
SELECT Receipt.StorerKey, ISNULL(Receipt.Facility, '') , 'RD', 'A', SUM(Cast(RECEIPTDETAIL.QtyReceived as Bigint)) ,
MIN(PACK.PackUOM3), 
SUM(CASE WHEN PACK.Casecnt > 0 
             THEN CAST((CAST(RECEIPTDETAIL.QtyReceived AS BIGINT)/PACK.Casecnt) AS BIGINT)
             ELSE 0 END ) 
FROM   RECEIPTDETAIL WITH (NOLOCK)    
   JOIN Receipt WITH (NOLOCK) on (Receipt.Receiptkey = RECEIPTDETAIL.Receiptkey )
   JOIN PACK WITH (NOLOCK) ON RECEIPTDETAIL.PackKey = PACK.PackKey
WHERE  RECEIPTDETAIL.AddDate Between @dStartDate AND @dEndDate     
Group by Receipt.StorerKey, ISNULL(Receipt.Facility, '')   
    
SET @cSQL = N' SELECT Receipt.StorerKey, ISNULL(Receipt.Facility, ''''), ''RD'', ''B'', '+
             ' SUM(Cast(RECEIPTDETAIL.QtyReceived as Bigint)), '+ 
             ' MIN(PACK.PackUOM3), '+
             ' SUM(CASE WHEN PACK.Casecnt > 0  '+
             ' THEN CAST((CAST(RECEIPTDETAIL.QtyReceived AS BIGINT)/PACK.Casecnt) AS BIGINT) '+
             ' ELSE 0 END )  '+
             ' FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK) '+
             ' JOIN ' + @cArchiveDB + '.dbo.Receipt Receipt WITH (NOLOCK) on (Receipt.Receiptkey = RECEIPTDETAIL.Receiptkey )  '+
             ' JOIN  dbo.PACK PACK WITH (NOLOCK) ON RECEIPTDETAIL.PackKey = PACK.PackKey ' +
             ' WHERE  RECEIPTDETAIL.AddDate Between @dStartDate AND @dEndDate  '+
             ' Group by Receipt.StorerKey, ISNULL(Receipt.Facility, '''')   '    
    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty, UOM, Qty_CS )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime',    
   @dStartDate, @dEndDate    
  
    
--  'Customer Orders'    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )  
SELECT StorerKey, ISNULL(Facility, ''), 'OH', 'A' as Source, COUNT(1) as Qty   
FROM   ORDERS WITH (NOLOCK)    
WHERE  AddDate Between @dStartDate AND @dEndDate     
AND    SOStatus <> 'CANC'    
Group by StorerKey, ISNULL(Facility, '')   
    
SET @cSQL = N'    SELECT StorerKey, ISNULL(Facility, ''''), ''OH'', ''B'', COUNT(1)     
   FROM   ' + @cArchiveDB + '.dbo.ORDERS WITH (NOLOCK)    
   WHERE  AddDate Between @dStartDate AND @dEndDate     
   AND    SOStatus <> ''CANC''  
 Group by StorerKey, ISNULL(Facility, '''') '    
    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime',    
   @dStartDate, @dEndDate  
  
--  'Customer Order Lines'    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, '') , 'OD', 'A' as Source, COUNT(1) as qty     
FROM   ORDERDETAIL WITH (NOLOCK)     
JOIN   ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey     
WHERE  ORDERDETAIL.AddDate Between @dStartDate AND @dEndDate     
AND    ORDERS.SOStatus <> 'CANC'     
Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '')  
    
SET @cSQL = N'     SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''''), ''OD'', ''B'',  COUNT(1)     
   FROM   ' + @cArchiveDB + '.dbo.ORDERDETAIL ORDERDETAIL WITH (NOLOCK)     
   JOIN   ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey     
   WHERE  ORDERDETAIL.AddDate Between @dStartDate AND @dEndDate     
   AND    ORDERS.SOStatus <> ''CANC''  
   Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '''') '    
    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime',    
   @dStartDate, @dEndDate  
  
-- Units Picked & Shipped    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty, UOM, Qty_CS )   
 SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''),  'PD', 'A', SUM(CAST(PICKDETAIL.Qty as Bigint)) ,  
MIN(PACK.PackUOM3), 
SUM(CASE WHEN PACK.Casecnt > 0 
             THEN CAST((CAST(PICKDETAIL.Qty AS BIGINT)/PACK.Casecnt) AS BIGINT)
             ELSE 0 END ) 
FROM   PICKDETAIL WITH (NOLOCK)  
   JOIN dbo.ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = PICKDETAIL.Orderkey)    
   JOIN dbo.MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey)   
   JOIN dbo.MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey)   
   JOIN Pack WITH (NOLOCK) ON ( Pack.Packkey = PICKDETAIL.Packkey)   
WHERE  MBOL.ShipDate Between @dStartDate AND @dEndDate    
AND    MBOL.Status = '9'  
GROUP BY  ORDERS.StorerKey, ISNULL(ORDERS.Facility, '')

SET @cSQL = N'    SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''''), ''PD'', ''B'',  SUM(CAST(PICKDETAIL.Qty as Bigint)), ' +    
      ' MIN(PACK.PackUOM3), ' +
      ' SUM(CASE WHEN PACK.Casecnt > 0 ' +
      '             THEN CAST((CAST(PICKDETAIL.Qty AS BIGINT)/PACK.Casecnt) AS BIGINT) ' +
      '             ELSE 0 END ) ' +              
      ' FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL PICKDETAIL WITH (NOLOCK) ' +
      ' JOIN ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = PICKDETAIL.Orderkey) ' +
      ' JOIN ' + @cArchiveDB + '.dbo.MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey) ' +   
      ' JOIN ' + @cArchiveDB + '.dbo.MBOL MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey) ' +   
      ' JOIN  dbo.Pack PACK WITH (NOLOCK) ON ( PACK.Packkey = PICKDETAIL.Packkey)  ' +    
      ' WHERE MBOL.ShipDate Between @dStartDate AND @dEndDate ' +      
      ' AND   MBOL.Status= ''9''  ' +  
      ' Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '''') '    

   
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty, UOM, Qty_CS )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime ',    
   @dStartDate, @dEndDate  
 

-- Units Shipped by reporting quantity    --KHLim01 start

INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''),  'SR', 'A', SUM(CAST(p.Qty
      /(CASE WHEN OB_RPT_UOM=PackUOM1 AND pk.CaseCnt>0 THEN pk.CaseCnt
            WHEN OB_RPT_UOM=PackUOM2 AND pk.InnerPack>0 THEN pk.InnerPack
            WHEN OB_RPT_UOM=PackUOM3 AND pk.Qty>0 THEN pk.Qty
            WHEN OB_RPT_UOM=PackUOM4 AND pk.Pallet>0 THEN pk.Pallet
            WHEN OB_RPT_UOM=PackUOM5 AND pk.[Cube]>0 THEN pk.[Cube]
            WHEN OB_RPT_UOM=PackUOM6 AND pk.GrossWgt>0 THEN pk.GrossWgt
            WHEN OB_RPT_UOM=PackUOM7 AND pk.NetWgt>0 THEN pk.NetWgt
            WHEN OB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN pk.OtherUnit1
            WHEN OB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN pk.OtherUnit2 ELSE 1 END) as Bigint))     
FROM   PICKDETAIL AS p WITH (NOLOCK)  
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = p.Orderkey)   
   JOIN dbo.MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey)   
   JOIN dbo.MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey)      
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
WHERE  MBOL.ShipDate Between @dStartDate AND @dEndDate    
AND    MBOL.Status = '9'       
AND EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '')     
UNION ALL
SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''),  'SR', 'A', SUM(CAST(p.Qty as Bigint))     
FROM   PICKDETAIL AS p WITH (NOLOCK)  
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = p.Orderkey)   
   JOIN dbo.MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey)   
   JOIN dbo.MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey)      
   JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
   JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
WHERE  MBOL.ShipDate Between @dStartDate AND @dEndDate    
AND    MBOL.Status = '9'      
AND NOT EXISTS ( SELECT 1 FROM SKU (nolock)
               JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
               WHERE OB_RPT_UOM <> ''
               AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
               AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '')     

SET @cSQL = N'    SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''''), ''SR'', ''B'',  SUM(CAST(p.Qty
      /(CASE WHEN OB_RPT_UOM=PackUOM1 AND pk.CaseCnt>0 THEN pk.CaseCnt
            WHEN OB_RPT_UOM=PackUOM2 AND pk.InnerPack>0 THEN pk.InnerPack
            WHEN OB_RPT_UOM=PackUOM3 AND pk.Qty>0 THEN pk.Qty
            WHEN OB_RPT_UOM=PackUOM4 AND pk.Pallet>0 THEN pk.Pallet
            WHEN OB_RPT_UOM=PackUOM5 AND pk.[Cube]>0 THEN pk.[Cube]
            WHEN OB_RPT_UOM=PackUOM6 AND pk.GrossWgt>0 THEN pk.GrossWgt
            WHEN OB_RPT_UOM=PackUOM7 AND pk.NetWgt>0 THEN pk.NetWgt
            WHEN OB_RPT_UOM=PackUOM8 AND pk.OtherUnit1>0 THEN pk.OtherUnit1
            WHEN OB_RPT_UOM=PackUOM9 AND pk.OtherUnit2>0 THEN pk.OtherUnit2 ELSE 1 END) as Bigint))     
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL AS p WITH (NOLOCK)    
      JOIN ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = p.Orderkey)    
      JOIN ' + @cArchiveDB + '.dbo.MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey)   
      JOIN ' + @cArchiveDB + '.dbo.MBOL MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey)      
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
   WHERE  MBOL.ShipDate Between @dStartDate AND @dEndDate     
   AND    MBOL.Status = ''9''  
   AND EXISTS ( SELECT 1 FROM SKU (nolock)
                  JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
                  WHERE OB_RPT_UOM <> ''''
                  AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
                  AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
   Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '''') 
   UNION ALL
   SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''''), ''SR'', ''B'',  SUM(CAST(p.Qty as Bigint))     
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL AS p WITH (NOLOCK)    
      JOIN ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ( ORDERS.Orderkey = p.Orderkey)    
      JOIN ' + @cArchiveDB + '.dbo.MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.Orderkey = MBOLDETAIL.Orderkey)   
      JOIN ' + @cArchiveDB + '.dbo.MBOL MBOL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey)      
      JOIN SKU AS sk (nolock)  ON sk.StorerKey = p.StorerKey AND sk.Sku = p.Sku
      JOIN PACK AS pk (nolock) ON pk.PackKey = p.PackKey
   WHERE  MBOL.ShipDate Between @dStartDate AND @dEndDate     
   AND    MBOL.Status = ''9'' 
   AND NOT EXISTS ( SELECT 1 FROM SKU (nolock)
                  JOIN  PACK (nolock) ON Sku.PackKey = PACK.PackKey
                  WHERE OB_RPT_UOM <> ''''
                  AND   OB_RPT_UOM IN (PackUOM1, PackUOM2, PackUOM3, PackUOM4, PackUOM5, PackUOM6, PackUOM7, PackUOM8, PackUOM9)
                  AND   SKU.StorerKey = p.StorerKey AND SKU.Sku = p.Sku )
   Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '''')    '    

INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime ',    
   @dStartDate, @dEndDate  

--KHLim01 end

-- Deliveries    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )   
SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''), 'DL', 'A', COUNT(1)     
FROM   LOADPLAN WITH (NOLOCK)    
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERS.Loadkey = LOADPLAN.Loadkey )    
WHERE  LOADPLAN.EditDate Between @dStartDate AND @dEndDate     
AND    LOADPLAN.Status = '9'   
Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '')    
    
SET @cSQL = N'    SELECT ORDERS.StorerKey, ISNULL(ORDERS.Facility, ''''), ''DL'', ''B'', COUNT(1)       
   FROM   ' + @cArchiveDB + '.dbo.LOADPLAN LOADPLAN WITH (NOLOCK)    
      JOIN ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ( ORDERS.Loadkey = LOADPLAN.Loadkey)    
   WHERE  LOADPLAN.EditDate Between @dStartDate AND @dEndDate     
   AND    LOADPLAN.Status = ''9''   
   Group by ORDERS.StorerKey, ISNULL(ORDERS.Facility, '''')  '    
    
INSERT INTO @Temp_Item (StorerKey, Facility, Type, Source, Qty )    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime ',    
   @dStartDate, @dEndDate    

    
DECLARE CUR_Item CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT T1.StorerKey, T1.Facility, ISNULL(MAX(T2.Company),''), T1.Type,  Sum(ISNULL(T1.Qty, 0)), Sum(ISNULL(T1.Qty_CS, 0)), 
          ISNULL(MAX(T3.Descr),''), ISNULL(NULLIF(MAX(T2.MarketSegment ),''), 'Oth'), 
          ISNULL(MAX(T2.CustomerGroupCode),'') , ISNULL(MAX(T2.CustomerGroupName),'')
  FROM  @Temp_Item T1
  INNER JOIN Storer T2 (NOLOCK) ON (T1.storerkey = T2.Storerkey) --(jay01)
  LEFT JOIN Facility T3 (NOLOCK) ON (T1.Facility  =T3.Facility ) --(jay02)
  Group by T1.StorerKey, T1.Facility, T1.Type   
  Order by T1.StorerKey, T1.Facility, T1.Type 
  
OPEN CUR_Item     
    
FETCH NEXT FROM CUR_Item INTO @cStorerkey, @cFacility, @cCompany,  --(jay01)
                              @cType, @nQty, @nQty_CS,
                              @cFacilityAddress, @cVertical  --(jay02)
                             ,@cCustomerGroupCode , @cCustomerGroupName  --(jay03)
    
WHILE @@FETCH_STATUS <> -1    
BEGIN    
  
   IF Not Exists (Select 1 from @t_Statistic
               WHERE Country = @cCountry  
               AND Facility  = @cFacility  
               AND Storerkey = @cStorerkey  
               AND Company   = @cCompany               --(jay01)
               AND FacilityAddress = @cFacilityAddress
               AND Vertical = @cVertical
    AND Year      = @nYear  
               AND Month     = @nMonth )  
   BEGIN 

      SELECT @cUOM = ''
     
      SELECT  @cUOM = ISNULL(MIN(UOM ), 'PC')
      FROM  @Temp_Item
      WHERE Facility  = @cFacility  
               AND Storerkey = @cStorerkey  
               AND UOM <> ''
      
      IF @cUOM = ''
      BEGIN
         SELECT @cUOM = 'PC'
      END

      INSERT INTO @t_Statistic  
      ( Country, Year, Month, Facility, StorerKey,
        Total_SKU, Total_ActiveSKU, Total_Receipts, Total_UnitReceipt,   
        Total_Orders, Total_OrderLines, Total_UnitPicked, Total_Deliveries, AddDate, Total_UnitShipped, 
        Company,  --(jay01)
        FacilityAddress, Vertical, Default_UOM, Total_UnitReceipt_CS, Total_UnitShipped_CS --(jay02) 
        ,CustomerGroupCode ,CustomerGroupName --(jay03) 
       ) 
      VALUES  
      ( @cCountry, @nYear, @nMonth, @cFacility,   
         @cStorerkey, 0, 0, 0, 0,   
         0, 0 , 0, 0,  getdate() , 0, --KHLim01
         @cCompany,     --(jay01)
         @cFacilityAddress, @cVertical, @cUOM, 0 , 0  --(jay02)
        ,@cCustomerGroupCode, @cCustomerGroupName --(jay03)
       ) 
   END  
   IF @cType = 'SKU'  
   BEGIN  
      Update @t_Statistic   
      SET Total_SKU = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'AS'  
   BEGIN  
      Update @t_Statistic   
      SET Total_ActiveSKU = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'RH'  
   BEGIN  
      Update @t_Statistic   
      SET Total_Receipts = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'RD'  
   BEGIN  
      Update @t_Statistic   
      SET Total_UnitReceipt = @nQty  ,
          Total_UnitReceipt_CS =  @nQty_CS
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'OH'  
   BEGIN  
      Update @t_Statistic   
      SET Total_Orders = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'OD'  
   BEGIN  
      Update @t_Statistic   
      SET Total_OrderLines = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'PD'  --KHLim01
   BEGIN  
      Update @t_Statistic   
      SET Total_UnitPicked = @nQty ,
          Total_UnitShipped_CS =  @nQty_CS
      WHERE Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'SR'  --KHLim01
   BEGIN  
      Update @t_Statistic   
      SET Total_UnitShipped = @nQty
      WHERE Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  
  
   IF @cType = 'DL'  
   BEGIN  
      Update @t_Statistic   
      SET Total_Deliveries = @nQty  
      WHERE Country = @cCountry  
      AND Facility = @cFacility  
      AND Storerkey  = @cStorerkey  
      AND Year       = @nYear  
      AND Month      = @nMonth   
   END  

 
       
   FETCH NEXT FROM CUR_Item INTO @cStorerkey, @cFacility, @cCompany,  --(jay01)
                              @cType, @nQty, @nQty_CS,
                              @cFacilityAddress, @cVertical  --(jay02)
                             ,@cCustomerGroupCode, @cCustomerGroupName  --(jay03)
END    
CLOSE CUR_Item     
DEALLOCATE CUR_Item     

SELECT Country, Month, Year,  Facility, StorerKey,     
          Total_SKU, Total_ActiveSKU, Total_Receipts, Total_UnitReceipt,   
         Total_Orders, Total_OrderLines, Total_UnitPicked, Total_Deliveries,   
         AddDate  
        ,Total_UnitShipped --KHLim01 
        ,Company --(jay01)
        ,FacilityAddress, Vertical, Default_UOM, Total_UnitReceipt_CS, Total_UnitShipped_CS --(jay02)
        ,CustomerGroupCode ,CustomerGroupName --(jay03)
FROM @t_Statistic

GO