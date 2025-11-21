SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_LOTxBILLDATE] 
AS 
SELECT [Lot]
, [TariffKey]
, [LotBillThruDate]
, [LastActivity]
, [QtyBilledBalance]
, [QtyBilledGrossWeight]
, [QtyBilledNetWeight]
, [QtyBilledCube]
, [AnniversaryStartDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [LOTxBILLDATE] (NOLOCK) 

GO