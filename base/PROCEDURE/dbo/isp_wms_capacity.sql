SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_WMS_Capacity]     
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

DECLARE @Statistic TABLE (    
   [Country] NVARCHAR(5),    
   [Year]    int,    
   [Month]   int,    
   [Title]   NVARCHAR(100),     
   [Qty]     bigint     
)    
    
Declare @dStartDate     datetime,    
        @dEndDate       datetime,     
        @nQty           bigint,     
        @nArchivedQty   bigint,     
        @cSQL           nvarchar(4000)     
  
  
Declare @nDebug   int  
Set @nDebug = 0  
    
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
  
IF @nDebug = '1'  
BEGIN  
Select  'Country', @cCountry, 'Year', Year(@dStartDate), 'Month', Month(@dStartDate)  
    
END  
  
--  'Customer Orders'    
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = COUNT(1)     
FROM   ORDERS WITH (NOLOCK)    
WHERE  AddDate Between @dStartDate AND @dEndDate     
AND    SOStatus <> 'CANC'     
AND    Status <> 'CANC'

SET @cSQL = N'    
   SELECT @nArchivedQty = ISNULL(COUNT(1), 0) 
   FROM   ' + @cArchiveDB + '.dbo.ORDERS WITH (NOLOCK)    
   WHERE  AddDate Between @dStartDate AND @dEndDate     
   AND    SOStatus <> ''CANC''
   AND    Status   <> ''CANC'''  

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
    
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)     
  
IF @nDebug = 1  
BEGIN  
   Select  'Customer Orders', @nQty  
END  
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Customer Orders', @nQty)    
    
--  'Customer Order Lines'    
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = ISNULL(COUNT(1), 0) 
FROM   ORDERDETAIL WITH (NOLOCK)     
JOIN   ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey     
WHERE  ORDERDETAIL.AddDate Between @dStartDate AND @dEndDate     
AND    ORDERS.SOStatus <> 'CANC'     
AND    ORDERS.Status   <> 'CANC'  

SET @cSQL = N'    
   SELECT @nArchivedQty = ISNULL(COUNT(1), 0)  
   FROM   ' + @cArchiveDB + '.dbo.ORDERDETAIL OD WITH (NOLOCK)     
   JOIN   ' + @cArchiveDB + '.dbo.ORDERS O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey     
   WHERE  O.AddDate Between @dStartDate AND @dEndDate     
   AND    O.SOStatus <> ''CANC''
   AND    O.Status   <> ''CANC'''
    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
    
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)     
  
IF @nDebug = 1  
BEGIN  
   Select 'Customer Order Detail', @nQty  
END  
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Customer Order Detail', @nQty)    
    
    
--  'Receipts & Returns '    
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = ISNULL(COUNT(1), 0)  
FROM   RECEIPT WITH (NOLOCK)    
WHERE  AddDate Between @dStartDate AND @dEndDate     
    
SET @cSQL = N'    
   SELECT @nArchivedQty = ISNULL(COUNT(1), 0)   
   FROM   ' + @cArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)    
   WHERE  AddDate Between @dStartDate AND @dEndDate'    
    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
  
  
IF @nDebug = 1  
BEGIN  
   Select 'Receipts & Returns', @nQty  
END  
       
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Receipts & Returns', @nQty)    
    
-- units received & putaway     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = SUM(Cast(isnull(QtyReceived, 0)as bigint) ) 
FROM   RECEIPTDETAIL WITH (NOLOCK)    
WHERE  AddDate Between @dStartDate AND @dEndDate     
    
SET @cSQL = N'    
   SELECT @nArchivedQty = isnull(SUM(Cast(isnull(QtyReceived, 0)as bigint) ), 0)
   FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL WITH (NOLOCK)    
   WHERE  AddDate Between @dStartDate AND @dEndDate'    
    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
       
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)     
  
IF @nDebug = 1  
BEGIN  
   Select 'Units Received', @nQty  --KH02
END  
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units Received by base quantity', @nQty)    --KH02 KH03
    
-- Units Picked & Shipped    
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = SUM(Cast(isnull(Qty, 0)as bigint))        
FROM   PICKDETAIL WITH (NOLOCK)    
WHERE  EditDate Between @dStartDate AND @dEndDate     
AND    Status = '9'     
    
SET @cSQL = N'    
   SELECT @nArchivedQty = ISNULL(SUM(Cast(isnull(Qty, 0)as bigint)), 0)
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL WITH (NOLOCK)    
   WHERE  EditDate Between @dStartDate AND @dEndDate     
   AND    Status = ''9'' '    
    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
       
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)    
  
IF @nDebug = 1  
BEGIN  
   Select 'Units Shipped', @nQty  --KH02
END  
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units Shipped by base quantity', @nQty)    --KH02 KH03
    
-- Deliveries    
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = isnull(COUNT(1), 0)
FROM   LOADPLAN WITH (NOLOCK)    
WHERE  EditDate Between @dStartDate AND @dEndDate     
AND    Status = '9'     
    
SET @cSQL = N'    
   SELECT @nArchivedQty = isnull(COUNT(1), 0)
   FROM   ' + @cArchiveDB + '.dbo.LOADPLAN WITH (NOLOCK)    
   WHERE  EditDate Between @dStartDate AND @dEndDate     
   AND    Status = ''9'' '    
    
EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',    
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT    
       
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)     
  
IF @nDebug = 1  
BEGIN  
   Select 'Deliveries', @nQty  
END  
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Deliveries', @nQty)    

IF @nMonth = DatePart(month, GetDate()) AND @nYear = DatePart(year, GetDate())  -- Active, number of SKUs & Unit of SOH are all current stat only (KH01)
BEGIN
   -- Active SKUs     
   SET @nQty = 0     
   SET @nArchivedQty = 0     
   SELECT @nQty = isnull(COUNT(Distinct SKU), 0)     
   FROM   LOT WITH (NOLOCK)    
   -- WHERE  Qty > 0     
  
   IF @nQty IS NULL   
      SET @nQty = 0  
  
   IF @nDebug = 1  
   BEGIN  
      Select 'Active SKUs', @nQty  
   END  
    
   INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Active SKUs', @nQty)    
    
    
   -- Number of SKUs     
   SET @nQty = 0     
   SET @nArchivedQty = 0     
   SELECT @nQty = isnull(COUNT(1), 0)
   FROM   SKU WITH (NOLOCK)    
  
   IF @nQty IS NULL   
      SET @nQty = 0  
  
   IF @nDebug = 1  
   BEGIN  
      Select 'Number of SKUs', @nQty  
   END  
    
   INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of SKUs', @nQty)    
    
   -- Units of Stock on Hand     
   SET @nQty = 0     
   SET @nArchivedQty = 0     
   SELECT @nQty = isnull(SUM(cast(Qty as bigint)), 0)
   FROM   SKUxLOC WITH (NOLOCK)    
   WHERE  Qty > 0     
  
   IF @nQty IS NULL   
      SET @nQty = 0  
  
   IF @nDebug = 1  
   BEGIN  
      Select 'Units of Stock on Hand', @nQty  
   END  
    
   INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units of Stock on Hand', @nQty)    
END

SELECT [Country], [Year], [Month], [Title], [Qty]=Cast([Qty] as bigint) FROM @Statistic

GO