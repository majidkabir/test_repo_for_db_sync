SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jiralfl.atlassian.net/browse/JPPGLS-69
CREATE   VIEW [BI].[V_HolidayHeader]
AS
SELECT * FROM dbo.HolidayHeader

GO