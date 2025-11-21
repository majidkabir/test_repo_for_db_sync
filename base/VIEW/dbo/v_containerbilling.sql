SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ContainerBilling] 
AS 
SELECT [ContainerBillingKey]
, [DocType]
, [ContainerType]
, [Descr]
, [Rate]
, [Base]
, [TaxGroupKey]
, [GLDistributionKey]
, [CostRate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [ContainerBilling] (NOLOCK) 

GO