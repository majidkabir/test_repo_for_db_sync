SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ADJUSTMENT] 
AS 
SELECT [AdjustmentKey]
, [StorerKey]
, [EffectiveDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [TimeStamp]
, [CustomerRefNo]
, [AdjustmentType]
, [Remarks]
, [FromToWhse]
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
, [FinalizedFlag]
, [DocType]
FROM [ADJUSTMENT] (NOLOCK) 



GO