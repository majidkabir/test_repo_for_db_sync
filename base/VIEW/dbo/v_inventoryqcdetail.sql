SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--InventoryQCDetail
CREATE VIEW [dbo].[V_InventoryQCDetail]   
AS   
SELECT [QC_Key]  
, [QCLineNo]  
, [StorerKey]  
, [SKU]  
, [PackKey]  
, [UOM]  
, [OriginalQty]  
, [Qty]  
, [FromLoc]  
, [FromLot]  
, [FromID]  
, [ToQty]  
, [ToID]  
, [ToLoc]  
, [Reason]  
, [Status]  
, [AddWho]  
, [AddDate]  
, [EditWho]  
, [EditDate]  
, [TrafficCop]  
, [ArchiveCop]  
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
, [FinalizeFlag]  
, [Channel]
, [Channel_ID]
FROM [InventoryQCDetail] (NOLOCK)  

GO