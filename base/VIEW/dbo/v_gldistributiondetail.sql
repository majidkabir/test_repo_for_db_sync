SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_GLDistributionDetail] 
AS 
SELECT [GLDistributionKey]
, [GLDistributionLineNumber]
, [ChartofAccountsKey]
, [GLDistributionPct]
, [Descrip]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
FROM [GLDistributionDetail] (NOLOCK) 

GO