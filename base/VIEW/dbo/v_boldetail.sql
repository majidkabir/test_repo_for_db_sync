SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_BOLDETAIL] 
AS 
SELECT [BolKey]
, [BolLineNumber]
, [OrderKey]
, [Description]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [TimeStamp]
FROM [BOLDETAIL] (NOLOCK) 

GO