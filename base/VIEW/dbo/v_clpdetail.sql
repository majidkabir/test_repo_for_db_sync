SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CLPDETAIL] 
AS 
SELECT [CLPOrderKey]
, [CLPOrderLineNumber]
, [POKey]
, [POLineNumber]
, [Qty]
, [CaseId]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [TimeStamp]
FROM [CLPDETAIL] (NOLOCK) 

GO