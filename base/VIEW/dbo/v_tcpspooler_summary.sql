SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_TCPSpooler_Summary] AS
   SELECT
      Spooler.IPAddress,
      CONVERT(VARCHAR(10), PrintJob.AddDate, 120) AS TranDate,
      COUNT(1) AS TotalTrans,
      SUM(CASE WHEN DATEDIFF(second, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 0 AND 3 THEN 1 ELSE 0 END)  AS Within_3Sec,
      SUM(CASE WHEN DATEDIFF(second, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 4 AND 6 THEN 1 ELSE 0 END)  AS [4Sec-6Sec],
      SUM(CASE WHEN DATEDIFF(second, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 7 AND 9 THEN 1 ELSE 0 END) AS  [7Sec-9Sec],
      SUM(CASE WHEN DATEDIFF(second, PrintJob.AddDate, PrintJob.EditDate) > 10 THEN 1 ELSE 0 END) AS [10Sec_More]
   FROM rdt.rdtPrintJob_Log AS PrintJob WITH (NOLOCK)
      JOIN rdt.rdtPrinter Printer WITH (NOLOCK) ON (PrintJob.Printer = Printer.PrinterID)
      JOIN rdt.rdtSpooler Spooler WITH (NOLOCK) ON (Printer.SpoolerGroup = Spooler.SpoolerGroup)
   WHERE PrintJob.JobType = 'TCPSPOOLER'
   GROUP BY CONVERT(VARCHAR(10), PrintJob.AddDate, 120), Spooler.IPAddress

GO