SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Holiday] 
AS 
SELECT [HolidayKey]
, [Holiday]
, [DayDesc]
, [DayOfWeek]
FROM [Holiday] (NOLOCK) 

GO