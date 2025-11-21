SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_OriginAllocQty] 
AS 
SELECT [OrderKey]
, [OrderLineNumber]
, [QtyAllocated]
, [AddDate]
, [AddWho]
FROM [OriginAllocQty] (NOLOCK) 

GO