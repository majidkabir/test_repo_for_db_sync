SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_WMS_Capacity_ARchive] 
   @cCountry   NVARCHAR(5), 
   @cArchiveDB NVARCHAR(20),
   @nMonth int = 0,
   @nYear  int = 0
AS
SET NOCOUNT ON
 
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
        @cSQL           nvarchar(1000) 

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
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(*) 
--FROM   ORDERS WITH (NOLOCK)
--WHERE  AddDate Between @dStartDate AND @dEndDate 
--AND    SOStatus <> 'CANC' 

SET @cSQL = N'
   SELECT @nArchivedQty = COUNT(*) 
   FROM   ' + @cArchiveDB + '.dbo.ORDERS WITH (NOLOCK)
   WHERE  AddDate Between @dStartDate AND @dEndDate 
   AND    SOStatus <> ''CANC'''

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT

SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0) 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Customer Orders', @nQty)

--  'Customer Order Lines'
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(*) 
--FROM   ORDERDETAIL WITH (NOLOCK) 
--JOIN   ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey 
--WHERE  ORDERDETAIL.AddDate Between @dStartDate AND @dEndDate 
--AND    ORDERS.SOStatus <> 'CANC' 

SET @cSQL = N'
   SELECT @nArchivedQty = COUNT(*) 
   FROM   ' + @cArchiveDB + '.dbo.ORDERDETAIL ORDERDETAIL WITH (NOLOCK) 
   JOIN   ' + @cArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey 
   WHERE  ORDERDETAIL.AddDate Between @dStartDate AND @dEndDate 
   AND    ORDERS.SOStatus <> ''CANC'''

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT

SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0) 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Customer Order Detail', @nQty)


--  'Receipts & Returns '
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(*) 
--FROM   RECEIPT WITH (NOLOCK)
--WHERE  AddDate Between @dStartDate AND @dEndDate 

SET @cSQL = N'
   SELECT @nArchivedQty = COUNT(*) 
   FROM   ' + @cArchiveDB + '.dbo.RECEIPT WITH (NOLOCK)
   WHERE  AddDate Between @dStartDate AND @dEndDate'

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT
   
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Receipts & Returns', @nQty)

-- units received & putaway 
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = SUM(QtyReceived) 
--FROM   RECEIPTDETAIL WITH (NOLOCK)
--WHERE  AddDate Between @dStartDate AND @dEndDate 

SET @cSQL = N'
   SELECT @nArchivedQty = SUM(QtyReceived) 
   FROM   ' + @cArchiveDB + '.dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE  AddDate Between @dStartDate AND @dEndDate'

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT
   
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0) 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units Received', @nQty)   --KH01

-- Units Picked & Shipped
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = SUM(Qty) 
--FROM   PICKDETAIL WITH (NOLOCK)
--WHERE  EditDate Between @dStartDate AND @dEndDate 
--AND    Status = '9' 

SET @cSQL = N'
   SELECT @nArchivedQty = SUM(Qty)  
   FROM   ' + @cArchiveDB + '.dbo.PICKDETAIL WITH (NOLOCK)
   WHERE  EditDate Between @dStartDate AND @dEndDate 
   AND    Status = ''9'' '

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT
   
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0)

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units Shipped', @nQty) --KH01

-- Deliveries
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(*) 
--FROM   LOADPLAN WITH (NOLOCK)
--WHERE  EditDate Between @dStartDate AND @dEndDate 
--AND    Status = '9' 

SET @cSQL = N'
   SELECT @nArchivedQty = COUNT(*)   
   FROM   ' + @cArchiveDB + '.dbo.LOADPLAN WITH (NOLOCK)
   WHERE  EditDate Between @dStartDate AND @dEndDate 
   AND    Status = ''9'' '

EXEC sp_ExecuteSql @cSQL, N'@dStartDate datetime, @dEndDate datetime, @nArchivedQty bigint OUTPUT',
   @dStartDate, @dEndDate, @nArchivedQty OUTPUT
   
SET @nQty = ISNULL(@nQty,0) + ISNULL(@nArchivedQty, 0) 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Deliveries', @nQty)

-- Active SKUs 
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(Distinct SKU) 
--FROM   LOT WITH (NOLOCK)
---- WHERE  Qty > 0 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Active SKUs', @nQty)


-- Number of SKUs 
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = COUNT(1) 
--FROM   SKU WITH (NOLOCK)

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of SKUs', @nQty)

-- Units of Stock on Hand 
SET @nQty = 0 
SET @nArchivedQty = 0 
--SELECT @nQty = SUM(Qty) 
--FROM   SKUxLOC WITH (NOLOCK)
--WHERE  Qty > 0 

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units of Stock on Hand', @nQty)

SELECT * FROM @Statistic

GO