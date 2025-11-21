SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_LotxIdDetail] 
AS 
SELECT [LotxIdDetailKey]
, [ReceiptKey]
, [ReceiptLineNumber]
, [PickDetailKey]
, [IOFlag]
, [Lot]
, [ID]
, [Wgt]
, [OrderKey]
, [OrderLineNumber]
, [Other1]
, [Other2]
, [Other3]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [LotxIdDetail] (NOLOCK) 

GO