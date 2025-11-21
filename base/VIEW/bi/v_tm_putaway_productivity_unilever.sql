SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
--MYS–UNILEVER–Create new datasource for Task Manager Putaway Dashboard https://jiralfl.atlassian.net/browse/BI-309
/* Updates:                                                                */
/* Date          Author      Ver.  Purposes                                */
/* 01-Nov-2021   NicoleWong  1.0   Created Ticket                          */
/* 11-Nov-2021   JarekLim    1.0   Created View                            */
/***************************************************************************/
CREATE    VIEW [BI].[V_TM_Putaway_Productivity_UNILEVER]
AS
SELECT Storerkey
--, Facility
, DateWhen
, DayWhen
, ByWhom
, at00 = SUM(at00)
, at01 = SUM(at01)
, at02 = SUM(at02)
, at03 = SUM(at03)
, at04 = SUM(at04)
, at05 = SUM(at05)
, at06 = SUM(at06)
, at07 = SUM(at07)
, at08 = SUM(at08)
, at09 = SUM(at09)
, at10 = SUM(at10)
, at11 = SUM(at11)
, at12 = SUM(at12)
, at13 = SUM(at13)
, at14 = SUM(at14)
, at15 = SUM(at15)
, at16 = SUM(at16)
, at17 = SUM(at17)
, at18 = SUM(at18)
, at19 = SUM(at19)
, at20 = SUM(at20)
, at21 = SUM(at21)
, at22 = SUM(at22)
, at23 = SUM(at23)
, EventType
, ActionType
, FunctionID
FROM (
   SELECT Storerkey
   --, Facility = UPPER(Facility)
   , DateWhen  = CONVERT(VARCHAR(10), EventDateTime, 120)
   , DayWhen  = DATENAME(dw, EventDateTime)
   , ByWhom = UPPER(TRIM(UserID))
   , at00 = CASE WHEN DATEPART(HOUR, EventDateTime) = 0 THEN COUNT(ID) ELSE 0 END
   , at01 = CASE WHEN DATEPART(HOUR, EventDateTime) = 1 THEN COUNT(ID) ELSE 0 END
   , at02 = CASE WHEN DATEPART(HOUR, EventDateTime) = 2 THEN COUNT(ID) ELSE 0 END
   , at03 = CASE WHEN DATEPART(HOUR, EventDateTime) = 3 THEN COUNT(ID) ELSE 0 END
   , at04 = CASE WHEN DATEPART(HOUR, EventDateTime) = 4 THEN COUNT(ID) ELSE 0 END
   , at05 = CASE WHEN DATEPART(HOUR, EventDateTime) = 5 THEN COUNT(ID) ELSE 0 END
   , at06 = CASE WHEN DATEPART(HOUR, EventDateTime) = 6 THEN COUNT(ID) ELSE 0 END
   , at07 = CASE WHEN DATEPART(HOUR, EventDateTime) = 7 THEN COUNT(ID) ELSE 0 END
   , at08 = CASE WHEN DATEPART(HOUR, EventDateTime) = 8 THEN COUNT(ID) ELSE 0 END
   , at09 = CASE WHEN DATEPART(HOUR, EventDateTime) = 9 THEN COUNT(ID) ELSE 0 END
   , at10 = CASE WHEN DATEPART(HOUR, EventDateTime) = 10 THEN COUNT(ID) ELSE 0 END
   , at11 = CASE WHEN DATEPART(HOUR, EventDateTime) = 11 THEN COUNT(ID) ELSE 0 END
   , at12 = CASE WHEN DATEPART(HOUR, EventDateTime) = 12 THEN COUNT(ID) ELSE 0 END
   , at13 = CASE WHEN DATEPART(HOUR, EventDateTime) = 13 THEN COUNT(ID) ELSE 0 END
   , at14 = CASE WHEN DATEPART(HOUR, EventDateTime) = 14 THEN COUNT(ID) ELSE 0 END
   , at15 = CASE WHEN DATEPART(HOUR, EventDateTime) = 15 THEN COUNT(ID) ELSE 0 END
   , at16 = CASE WHEN DATEPART(HOUR, EventDateTime) = 16 THEN COUNT(ID) ELSE 0 END
   , at17 = CASE WHEN DATEPART(HOUR, EventDateTime) = 17 THEN COUNT(ID) ELSE 0 END
   , at18 = CASE WHEN DATEPART(HOUR, EventDateTime) = 18 THEN COUNT(ID) ELSE 0 END
   , at19 = CASE WHEN DATEPART(HOUR, EventDateTime) = 19 THEN COUNT(ID) ELSE 0 END
   , at20 = CASE WHEN DATEPART(HOUR, EventDateTime) = 20 THEN COUNT(ID) ELSE 0 END
   , at21 = CASE WHEN DATEPART(HOUR, EventDateTime) = 21 THEN COUNT(ID) ELSE 0 END
   , at22 = CASE WHEN DATEPART(HOUR, EventDateTime) = 22 THEN COUNT(ID) ELSE 0 END
   , at23 = CASE WHEN DATEPART(HOUR, EventDateTime) = 23 THEN COUNT(ID) ELSE 0 END
   , EventType
   , ActionType
   , FunctionID
   FROM rdt.RDTSTDEVENTLOG
   WHERE STORERKEY = 'UNILEVER'
   AND EVENTDATETIME >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0)
   AND ACTIONTYPE NOT IN ('1', '9')
   AND ACTIONTYPE = '4'
   AND FunctionID IN ('1797', '1814', '1849')
   GROUP BY Storerkey
   --, UPPER(Facility)
   , CONVERT(VARCHAR(10), EventDateTime, 120)
   , DATENAME(dw, EventDateTime)
   , DATEPART(HOUR, EventDateTime)
   , UserID
   , EventType
   , ActionType
   , FunctionID
) AS B
GROUP BY Storerkey
--, Facility
, DateWhen
, DayWhen
, ByWhom
, EventType
, ActionType
, FunctionID
--ORDER BY 1, 2, 3

GO