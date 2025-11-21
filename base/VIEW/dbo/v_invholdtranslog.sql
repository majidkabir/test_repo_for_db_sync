SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_InvHoldTransLog] 
AS 
SELECT [StorerKey]
, [Sku]
, [Facility]
, [SourceKey]
, [SourceType]
, [UserID]
, [RowID]
, [Status]
, [AddWho]
, [AddDate]
, [EditWho]
, [EditDate]
, [Msgtext]
FROM [InvHoldTransLog] (NOLOCK) 

GO