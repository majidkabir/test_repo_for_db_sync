SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_AccessorialDetail] 
AS 
SELECT [Accessorialkey]
, [AccessorialDetailkey]
, [Descrip]
, [Rate]
, [Base]
, [MasterUnits]
, [UomShow]
, [TaxGroupKey]
, [GLDistributionKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [Timestamp]
, [CostRate]
, [CostBase]
, [CostMasterUnits]
, [CostUOMShow]
FROM [AccessorialDetail] (NOLOCK) 

GO