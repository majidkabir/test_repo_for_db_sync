SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jiralfl.atlassian.net/browse/JPPGLS-37
CREATE   VIEW  [BI].[V_Booking_Out] AS
SELECT *
FROM dbo.Booking_Out WITH (NOLOCK)

GO