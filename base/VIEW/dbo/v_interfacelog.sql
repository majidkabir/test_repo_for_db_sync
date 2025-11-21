SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_InterfaceLog] 
AS 
SELECT [InterfaceKey]
, [SourceKey]
, [StorerKey]
, [ExternSourceKey]
, [Tablename]
, [Sku]
, [Qty]
, [UOM]
, [UserID]
, [TranCode]
, [TranStatus]
, [TranDate]
, [Userdefine01]
, [Userdefine02]
, [Userdefine03]
, [Userdefine04]
, [Userdefine05]
, [Userdefine06]
, [Userdefine07]
, [Userdefine08]
, [Userdefine09]
, [Userdefine10]
, [Status]
, [AddWho]
, [AddDate]
, [EditWho]
, [EditDate]
, [Msgtext]
FROM [InterfaceLog] (NOLOCK) 

GO