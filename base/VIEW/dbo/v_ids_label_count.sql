SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ids_label_count] 
AS 
SELECT [storerkey]
, [salesord]
, [shipdate]
, [consigneekey]
, [company]
, [addr1]
, [addr2]
, [addr3]
, [addr4]
, [city]
, [zip]
, [phone]
, [nocarton]
, [printdate]
FROM [ids_label_count] (NOLOCK) 

GO