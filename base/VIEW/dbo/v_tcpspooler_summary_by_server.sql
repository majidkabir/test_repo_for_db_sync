SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_TCPSpooler_Summary_By_Server] AS
   SELECT
      Spooler.IPAddress,
      CONVERT(VARCHAR(10), PrintJob.AddDate, 120) AS TranDate,
      COUNT(1) AS TotalTrans,
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) <= 3000 THEN 1 ELSE 0 END)  AS Within_3Sec,
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 3001 AND 4999 THEN 1 ELSE 0 END)  AS [3Sec-5Sec],
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) BETWEEN 5000 AND 9999 THEN 1 ELSE 0 END) AS [5Sec-10Sec],
      SUM(CASE WHEN DATEDIFF(millisecond, PrintJob.AddDate, PrintJob.EditDate) > 10000 THEN 1 ELSE 0 END) AS [10Sec_More]
   FROM rdt.rdtPrintJob_Log AS PrintJob WITH (NOLOCK)
      JOIN rdt.rdtPrinter Printer WITH (NOLOCK) ON (PrintJob.Printer = Printer.PrinterID)
      JOIN rdt.rdtSpooler Spooler WITH (NOLOCK) ON (Printer.SpoolerGroup = Spooler.SpoolerGroup)
   WHERE PrintJob.JobType = 'TCPSPOOLER'
   GROUP BY CONVERT(VARCHAR(10), PrintJob.AddDate, 120), Spooler.IPAddress

GO