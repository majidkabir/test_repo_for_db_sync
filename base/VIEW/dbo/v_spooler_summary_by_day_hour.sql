SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Spooler_Summary_By_Day_Hour] AS
   SELECT
      convert(char(10),PrintJob.AddDate,120) TransDate,
      substring(convert(char(13),PrintJob.AddDate,120),12,2) Hour24,
      COUNT (DISTINCT Spooler.IPAddress) Num_Prt ,
      COUNT(1) AS TotalTrans,
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) <= 3000 THEN 1 ELSE 0 END)                AS [0-3Sec],
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 3001 AND 6000 THEN 1 ELSE 0 END)  AS [3-6Sec],
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 6001 AND 10000 THEN 1 ELSE 0 END) AS [6-10Sec],
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) > 10000 THEN 1 ELSE 0 END)                AS [10Sec-More],
      CAST (((SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) <= 3000 THEN 1 ELSE 0 END)) / (COUNT(1)*1.00)) *100 AS DECIMAL (5,1)) AS [Prc-Within-3Sec],
      CAST (((SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) <= 6000 THEN 1 ELSE 0 END)) / (COUNT(1)*1.00)) *100 AS DECIMAL (5,1)) AS [Prc-Within-6Sec]
   FROM rdt.rdtPrintJob_Log AS PrintJob WITH (NOLOCK)
      JOIN rdt.rdtPrinter Printer WITH (NOLOCK) ON (PrintJob.Printer = Printer.PrinterID)
      JOIN rdt.rdtSpooler Spooler WITH (NOLOCK) ON (Printer.SpoolerGroup = Spooler.SpoolerGroup)
   WHERE PrintJob.JobType IN ('QCOMMANDER', 'TCPSPOOLER')
   GROUP BY
   convert(char(10),PrintJob.AddDate,120)  ,substring(convert(char(13),PrintJob.AddDate,120),12,2)

GO