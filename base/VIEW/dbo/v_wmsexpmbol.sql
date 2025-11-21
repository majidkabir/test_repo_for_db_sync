SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPMBOL]   
AS   
SELECT [ExternOrderkey]  
, [Consigneekey]  
, [ExternLineNo]  
, [SKU]  
, [OriginalQty]  
, [ShippedQty]  
, [Shortqty]  
, [TRANSFLAG]  
, [MBOLKey]  
, [AddDate]  
, [EditDate]  
, [TotalCarton]  
, [StorerKey]  
FROM [WMSEXPMBOL] (NOLOCK)   
GO