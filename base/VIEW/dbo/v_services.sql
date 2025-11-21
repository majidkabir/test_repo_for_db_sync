SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Services] 
AS 
SELECT [Servicekey]
, [Descrip]
, [SupportFlag]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [Timestamp]
FROM [Services] (NOLOCK) 

GO