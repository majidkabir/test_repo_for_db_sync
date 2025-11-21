SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TRANSFER] 
AS 
SELECT [TransferKey]
, [FromStorerKey]
, [ToStorerKey]
, [Type]
, [OpenQty]
, [Status]
, [GenerateHOCharges]
, [GenerateIS_HICharges]
, [ReLot]
, [EffectiveDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [Timestamp]
, [ReasonCode]
, [CustomerRefNo]
, [Remarks]
, [Facility]
, [PrintFlag]
, [UserDefine01]
, [UserDefine02]
, [UserDefine03]
, [UserDefine04]
, [UserDefine05]
, [UserDefine06]
, [UserDefine07]
, [UserDefine08]
, [UserDefine09]
, [UserDefine10]
, [ToFacility]
FROM [TRANSFER] (NOLOCK) 

GO