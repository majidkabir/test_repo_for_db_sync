SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPMBOLBK]   
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
FROM [WMSEXPMBOLBK] (NOLOCK)   
GO