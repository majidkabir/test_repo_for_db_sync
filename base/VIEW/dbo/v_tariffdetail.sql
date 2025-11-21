SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TariffDetail] 
AS 
SELECT [TariffDetailKey]
, [TariffKey]
, [ChargeType]
, [Descrip]
, [Rate]
, [Base]
, [MasterUnits]
, [RoundMasterUnits]
, [UOMShow]
, [TaxGroupKey]
, [GLDistributionKey]
, [MinimumCharge]
, [MinimumGroup]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [CostRate]
, [CostBase]
, [CostMasterUnits]
, [CostUOMShow]
, [UOM1Mult]
, [UOM2Mult]
, [UOM3Mult]
, [UOM4Mult]
FROM [TariffDetail] (NOLOCK) 

GO