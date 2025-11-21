SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CALENDARDETAIL] 
AS 
SELECT [CalendarGroup]
, [PeriodEnd]
, [SplitDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [CALENDARDETAIL] (NOLOCK) 

GO