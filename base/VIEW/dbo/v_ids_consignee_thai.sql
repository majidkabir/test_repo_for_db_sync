SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_IDS_CONSIGNEE_THAI] 
AS 
SELECT [customer_id]
, [customer_number]
, [customer_name]
, [location_number]
, [address6]
, [address1]
, [address2]
, [address3]
, [address4]
FROM [IDS_CONSIGNEE_THAI] (NOLOCK) 

GO