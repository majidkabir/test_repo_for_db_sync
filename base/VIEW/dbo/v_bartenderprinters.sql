SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_BartenderPrinters] AS
SELECT ISNULL(Long,'')  AS ServerIP,
       ISNULL(PrinterID,'') AS PrinterID,
       ISNULL(WinPrinter,'') AS WinPrinter,
       PrinterGroup,
       c.Storerkey,
       c.UDF02 AS ServerName
FROM CODELKUP c WITH (NOLOCK)
LEFT JOIN rdt.rdtPrinter p WITH (NOLOCK) ON  p.Printergroup = c.storerkey
WHERE  ListName = 'TCPClient'
AND c.Short = 'BARTENDER'

GO