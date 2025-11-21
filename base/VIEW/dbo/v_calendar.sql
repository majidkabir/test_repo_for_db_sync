SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CALENDAR] 
AS 
SELECT [CalendarGroup]
, [Description]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [CALENDAR] (NOLOCK) 

GO