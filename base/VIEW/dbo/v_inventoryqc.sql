SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_InventoryQC] 
AS 
SELECT  [QC_Key]
, [StorerKey]
, [Reason]
, [TradeReturnKey]
, [Refno]
, [AddWho]
, [AddDate]
, [EditWho]
, [EditDate]
, [from_facility]
, [to_facility]
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
, [Notes]
, [FinalizeFlag]
, [ArchiveCop]
FROM [InventoryQC] (NOLOCK) 



GO