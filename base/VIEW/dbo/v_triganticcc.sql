SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TriganticCC] 
AS 
SELECT [CCKey]
, [Facility]
, [StorerKey]
, [SKU]
, [Qty_Before]
, [Qty_After]
, [Adddate]
, [AdjCode]
, [AdjCodeDesc]
, [AdjType]
FROM [TriganticCC] (NOLOCK) 

GO