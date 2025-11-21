SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   VIEW [dbo].[V_Printers]
AS
SELECT PT.PrinterID, PT.Description, 'TCPSPOOLER' AS PrinterType, PT.PrinterGroup, PT.SpoolerGroup, ISNULL(PT.TPPrintergroup,'') AS TPPrintergroup, S.IPAddress, S.PortNo, 'LFL' AS PrinterPlatform
FROM rdt.RDTPrinter PT WITH (NOLOCK)  
JOIN rdt.rdtSpooler S WITH (NOLOCK) ON S.SpoolerGroup = PT.SpoolerGroup
UNION ALL
SELECT PT.PrinterID, PT.Description, 'BARTENDER' AS PrinterType, PT.PrinterGroup, PT.SpoolerGroup, ISNULL(PT.TPPrintergroup,'') AS TPPrintergroup , SUBSTRING(c.Long, 1, CHARINDEX(':', c.Long) -1) AS IPAddress,
SUBSTRING(c.Long, CHARINDEX(':', c.Long) +1, 4) AS PortNo, 'LFL' AS PrinterPlatform
FROM   dbo.CODELKUP c WITH (NOLOCK)          
JOIN   rdt.RDTPrinter PT WITH (NOLOCK) ON PT.PrinterGroup = C.StorerKey          
WHERE  C.ListName = 'TCPClient'          
AND    c.Short = 'BARTENDER'       
AND    CHARINDEX(':', c.Long) > 0
AND    PT.PrinterID > ''
UNION ALL
SELECT PT.PrinterID, PT.Description, 'TPPRINTER' AS PrinterType, PT.PrinterGroup, PT.SpoolerGroup, PT.TPPrintergroup, TPP.IPAddress, TPP.PortNo, TPP.PrinterPlatform
FROM rdt.RDTPrinter PT WITH (NOLOCK)  
JOIN dbo.TPPRINTERGROUP TPP WITH (NOLOCK) ON TPP.TPPrinterGroup  = PT.TPPrinterGroup

GO