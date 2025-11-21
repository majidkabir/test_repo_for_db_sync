SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_NSQLCONFIG] 
AS 
SELECT [ConfigKey]
, [NSQLValue]
, [NSQLDefault]
, [NSQLDescrip]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [Timestamp]
FROM [NSQLCONFIG] (NOLOCK) 

GO