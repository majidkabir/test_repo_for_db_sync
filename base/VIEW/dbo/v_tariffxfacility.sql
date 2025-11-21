SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TARIFFxFACILITY] 
AS 
SELECT [Facility]
, [StorerKey]
, [Sku]
, [Tariffkey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [TARIFFxFACILITY] (NOLOCK) 

GO