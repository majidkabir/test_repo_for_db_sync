SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Bartender]
AS
SELECT SUBSTRING(ISNULL(RTRIM(LTRIM(C.[Long])),''),1,30) AS ServerIP
     , ISNULL(RTRIM(C.[StorerKey]),'')                   AS StorerKey
     , ISNULL(RTRIM(P.[PrinterGroup]),'')                AS PrinterGroup
     , ISNULL(RTRIM(P.[PrinterId]),'')                   AS PrinterId
     , ISNULL(RTRIM(P.[WinPrinter]),'')                  AS WinPrinter
     , ISNULL(RTRIM(P.[Description]),'')                 AS PrinterDesc
     , P.AddDate
     , P.AddWho
     , P.EditDate
     , P.EditWho
FROM CodeLkUp C WITH (NOLOCK)
LEFT JOIN rdt.rdtPrinter P WITH (NOLOCK)
ON ISNULL(RTRIM(P.[PrinterGroup]),'') = ISNULL(RTRIM(C.[StorerKey]),'')
WHERE C.[ListName] = 'TCPClient'
AND C.[Short] = 'Bartender'

GO