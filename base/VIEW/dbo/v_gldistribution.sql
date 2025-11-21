SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_GLDistribution] 
AS 
SELECT [GLDistributionKey]
, [SupportFlag]
, [Descrip]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
FROM [GLDistribution] (NOLOCK) 

GO