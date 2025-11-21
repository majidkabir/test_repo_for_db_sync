SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Accessorial] 
AS 
SELECT [Accessorialkey]
, [Descrip]
, [SupportFlag]
, [StorerKey]
, [SKU]
, [ServiceKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [Timestamp]
FROM [Accessorial] (NOLOCK) 

GO