SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [RDT].[V_RDT_TraceSummary]
AS
SELECT CONVERT(datetime, CONVERT(char(8), StartTime, 112)) AS TransDate,
      DATEPART(hour, StartTime) AS Hour24,
      Usr,
      InFunc,
      InStep,
      OutStep,
      SUM(TimeTaken) / COUNT(1) AS AvgTime,
      COUNT(1) AS TotalTrans,
      MIN(TimeTaken) AS MinTime,
      MAX(TimeTaken) AS MaxTime,
      ISNULL(SUM(CASE WHEN TimeTaken <= 1000 THEN 1 ELSE 0 END), 0) AS MS0_1000,
      ISNULL(SUM(CASE WHEN TimeTaken > 1000 AND TimeTaken <= 2000 THEN 1 ELSE 0 END), 0) AS MS1000_2000,
      ISNULL(SUM(CASE WHEN TimeTaken > 2000 AND TimeTaken < 5000 THEN 1 ELSE 0 END), 0) AS MS2000_5000,
      ISNULL(SUM(CASE WHEN TimeTaken >= 5000 THEN 1 ELSE 0 END), 0) AS MS5000_UP,
      MAX(ISNULL(ROWREF,0)) AS RowRef
FROM RDT.RDTTRace WITH (NOLOCK)
WHERE NOT EXISTS (SELECT 1 FROM WMS_sysProcess (nolock) WHERE program_name <> 'jTDS' AND StartTime BETWEEN last_batch AND currenttime )
GROUP BY CONVERT(datetime, CONVERT(char(8), StartTime, 112)), DATEPART(hour, StartTime), Usr, InFunc, InStep, OutStep


GO