SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jiralfl.atlassian.net/browse/JPPGLS-37
CREATE   VIEW  [BI].[V_Booking_In] AS
SELECT *
FROM dbo.Booking_In WITH (NOLOCK)

GO