SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_ReplenishmentTaskAlert] (  
   @cRecipientList NVARCHAR(max)  )  
AS  
SET NOCOUNT ON  
  
DECLARE @cLoadKey    NVARCHAR(10),  
        @cStorer     NVARCHAR(10),  
        @cSKU        NVARCHAR(20),  
        @cLOC        NVARCHAR(10),  
        @cAddWho     NVARCHAR(18),  
        @nQty           INT,  
        @nQtyPicked     INT,  
        @nQtyAllocated  INT,  
        @nPAQty         INT,  
        @dAddDate       DATETIME,  
        @cLOT           NVARCHAR(10),  
        @cFromLoc       NVARCHAR(10),   
        @cID            NVARCHAR(18),  
        @nReplenQty     INT,   
        @tableHTML      NVarChar(MAX),  
        @dLastMoveDt    DATETIME,   
        @nSendAlert     INT  
  
DECLARE @Mailitem_id  INT  
  
SET @nSendAlert = 0   
IF ISNULL(RTRIM(@cRecipientList),'') = ''   
   RETURN  
     
IF OBJECT_ID('tempdb..#Result') IS NOT NULL  
   DROP TABLE #RESULT  
     
CREATE TABLE #Result (LOT NVARCHAR(10), FromLoc NVARCHAR(10), Qty INT, LastMoveDt DateTime)  
   
SET @tableHTML =    
       N'<STYLE TYPE="text/css"> ' + CHAR(13) +  
       N'<!--' + CHAR(13) +  
       N'TR{font-family: verdana; font-size: 10pt;}' + CHAR(13) +  
       N'TD{font-family: verdana; font-size: 9pt;}' + CHAR(13) +  
       N'--->' + CHAR(13) +  
       N'</STYLE>' + CHAR(13) +        
       N'<H4>IDS UK Task Release with No Replenishment Task Alert  </H4>'  
               
UPDATE Temp_ReplenTrace  
SET AlertStatus = 1  
WHERE AlertStatus = 0   
  
DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT trt.LoadKey, trt.AddDate, trt.StorerKey, trt.SKU, trt.LOC, trt.Qty,  
       trt.PATaskQty, trt.QtyAllocated, trt.QtyPicked, trt.AddWho  
FROM Temp_ReplenTrace trt (NOLOCK)   
JOIN SKUxLOC sl (NOLOCK) ON sl.StorerKey = trt.StorerKey AND sl.SKU = trt.SKU AND sl.LOC = trt.LOC AND  
      sl.Qty - sl.QtyAllocated - sl.QtyPicked < 0   
WHERE AlertStatus = 1  
  
OPEN CUR1  
  
FETCH NEXT FROM CUR1  
INTO @cLoadKey, @dAddDate, @cStorer, @cSKU, @cLOC, @nQty,   
     @nPAQty, @nQtyAllocated, @nQtyPicked, @cAddWho  
       
WHILE @@FETCH_STATUS <> -1  
BEGIN  
  TRUNCATE TABLE #Result  
    
    DECLARE CUR_AvailableQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT lli.LOT, lli.LOC, lli.Id,  
           (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 THEN lli.QtyReplen ELSE 0 END) -- (Shong03)  
    FROM   LOTxLOCxID lli WITH (NOLOCK)  
    JOIN   SKUxLOC sl WITH (NOLOCK) ON sl.StorerKey = lli.StorerKey AND sl.Sku = lli.Sku AND sl.Loc = lli.Loc  
    JOIN   LOC WITH (NOLOCK) ON LOC.Loc = lli.Loc  
    JOIN   ID WITH (NOLOCK) ON ID.ID = lli.Id AND ID.[Status] = 'OK'  
    JOIN   LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.[Status] = 'OK'  
    WHERE  lli.StorerKey = @cStorer   
    AND    lli.Sku = @cSKU  
    AND    sl.LocationType NOT IN ('PICK', 'CASE')  
    AND    LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','PICK') -- (Shong04)  
    AND    LOC.[Status] = 'OK'  
    AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
    AND    (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 THEN lli.QtyReplen ELSE 0 END) > 0 --(Shong03)  
  
    OPEN CUR_AvailableQty  
  
    FETCH NEXT FROM CUR_AvailableQty INTO @cLOT, @cFromLoc, @cID, @nReplenQty  
    WHILE @@FETCH_STATUS <> -1  
    BEGIN   
      IF NOT EXISTS(  
         SELECT 1 FROM ITRN (NOLOCK)  
         WHERE SourceType = 'DRP'  
         AND   AddDate > @dAddDate  
         AND   TranType ='MV'   
         AND   StorerKey = @cStorer   
         AND   Sku = @cSKU)  
      BEGIN  
       IF @nPAQty = 0   
       BEGIN  
        SELECT TOP 1 @dLastMoveDt = i.AddDate  
        FROM ITRN i (NOLOCK)  
        WHERE i.Lot = @cLOT   
        AND i.ToLoc = @cFromLoc   
        AND i.ToID = @cID   
        AND i.TranType IN ('MV','DP')  
        ORDER BY i.ItrnKey DESC  
         
          
        INSERT INTO #Result (LOT, FromLoc, Qty, LastMoveDt)  
        VALUES(@cLOT, @cFromLoc, @nReplenQty, @dLastMoveDt)  
          
          --SELECT @cLOT '@cLOT', @cFromLoc '@cFromLoc', @cID '@cID', @nReplenQty '@nReplenQty', @cSKU 'SKU'   
       END  
      END  
        
      FETCH NEXT FROM CUR_AvailableQty INTO @cLOT, @cFromLoc, @cID, @nReplenQty  
    END  
    CLOSE CUR_AvailableQty  
    DEALLOCATE CUR_AvailableQty   
      
    IF EXISTS(SELECT 1 FROM #Result)  
    BEGIN  
      SELECT @tableHTML = @tableHTML +   
            N'</b><table border="1" cellspacing="0" cellpadding="5">' +  
             N'<tr BGCOLOR="cornsilk">' +      
             N'<th>Load</th><th>SKU</th><th>AddDate</th><th>Location</th><th>Qty</th><th>Alloc</th><th>Picked</th></tr>' +        
             CAST ( ( SELECT td = @cLoadKey,  '', 'td/@align' = 'left',   
                             td = @cSKU,'', 'td/@align' = 'left',   
                             td = @dAddDate,'', 'td/@align' = 'left',   
                             td = @cLOC,  '', 'td/@align' = 'left',  
                             td = @nQty,  '', 'td/@align' = 'left',  
                             td = @nQtyAllocated,  '', 'td/@align' = 'left',                                                            
                             td = @nQtyPicked    
               FOR XML PATH('tr'), TYPE       
             ) AS NVarChar(MAX) ) +      
             N'</table>'   
       
           SELECT @tableHTML = @tableHTML + '<br/>'+   
           N'<H4>Found Available Quantity For Replenishment  </H4>' +  
            N'</b><table border="1" cellspacing="0" cellpadding="5">' +  
             N'<tr BGCOLOR="cornsilk">' +      
             N'<th>LOT</th><th>From Location</th><th>Qty</th><th>Last Tran</th></tr>' +        
             CAST ( ( SELECT td = LOT,  '', 'td/@align' = 'left',   
                             td = FromLoc,'', 'td/@align' = 'left',   
                             td = Qty,'', 'td/@align' = 'left',  
                             td = LastMoveDt  
                      FROM #Result   
               FOR XML PATH('tr'), TYPE       
             ) AS NVarChar(MAX) ) +      
             N'</table>' + '</br></br>'  
               
       SET @nSendAlert = 1  
    END  
    
   FETCH NEXT FROM CUR1 INTO @cLoadKey, @dAddDate, @cStorer, @cSKU, @cLOC, @nQty,   
        @nPAQty, @nQtyAllocated, @nQtyPicked, @cAddWho  
END  
CLOSE CUR1  
DEALLOCATE CUR1       
  
IF @nSendAlert = 1  
BEGIN  
   EXEC msdb.dbo.sp_send_dbmail       
                @recipients=@cRecipientList,  
                @copy_recipients = '',       
                @subject = 'Task Release Replenishment Tracking Email Alert' ,      
                @body = @tableHTML,      
                @body_format = 'HTML',      
                @mailitem_id = @Mailitem_id OUTPUT;   
  
END  
  
UPDATE Temp_ReplenTrace  
SET AlertStatus = 9  
WHERE AlertStatus = 1   
       
DELETE FROM Temp_ReplenTrace  
WHERE DATEDIFF(DAY, AddDate, GETDATE()) > 3   
AND AlertStatus = 9

GO