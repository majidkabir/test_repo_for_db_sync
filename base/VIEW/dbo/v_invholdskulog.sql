SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_InvHoldSkuLog] 
AS 
SELECT [StorerKey]
, [Sku]
, [Facility]
, [PreHoldQty]
, [OnHoldQty]
, [TranStatus]
, [AddWho]
, [AddDate]
, [EditWho]
, [EditDate]
, [Msgtext]
FROM [InvHoldSkuLog] (NOLOCK) 

GO