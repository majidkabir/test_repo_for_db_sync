SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- Store in WMS_Volumetrics2 that not overwrite every run.  
  
CREATE PROC [dbo].[isp_WMS_Capacity2]     
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
  
  
-- # of Facility     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = count(1)  
FROM   Facility WITH (NOLOCK)  
Where Exists (Select 1 from  LOC WITH (NOLOCK) where (LOC.Facility = Facility.Facility) )  

IF @nQty is NULL
   SET @nQty = 0
  
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of Facility', @nQty)    
    
-- # of Storer     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = count(1)  
FROM   Storer WITH (NOLOCK)    
WHERE  type = '1'     

IF @nQty is NULL
   SET @nQty = 0

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of Storer', @nQty)    
  
-- Number of SKUs     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = COUNT(1)     
FROM   SKU WITH (NOLOCK)    

IF @nQty is NULL
   SET @nQty = 0

INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of SKUs', @nQty)    
  
-- Active SKUs     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = COUNT(Distinct SKU)     
FROM   LOT WITH (NOLOCK)    
-- WHERE  Qty > 0     

IF @nQty is NULL
   SET @nQty = 0
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Active SKUs', @nQty)    
   
-- Units of Stock on Hand     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = SUM(Cast(ISNULL(Qty, 0) as bigint))     
FROM   SKUxLOC WITH (NOLOCK)    
WHERE  Qty > 0     

IF @nQty is NULL
   SET @nQty = 0
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Units of Stock on Hand', @nQty)    
  
  
-- # of LOC     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = count(1)  
FROM LOC WITH (NOLOCK)  

IF @nQty is NULL
   SET @nQty = 0
    
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'Number of LOC', @nQty)    
  
  
-- Used LOC     
SET @nQty = 0     
SET @nArchivedQty = 0     
SELECT @nQty = count(1)  
FROM LOC WITH (NOLOCK)  
Where Exists (Select 1 from  SKUXLOC WITH (NOLOCK) where (LOC.LOC = SKUXLOC.LOC) )  

IF @nQty is NULL
   SET @nQty = 0
  
INSERT INTO @Statistic VALUES (@cCountry, Year(@dStartDate), Month(@dStartDate), 'LOC in Use', @nQty)    
  
    
SELECT * FROM @Statistic

GO