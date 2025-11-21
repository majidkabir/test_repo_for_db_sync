SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Bartender_Summary_By_Day_Hour] AS
SELECT 
convert(char(10),tqt.AddDate,120) TransDate ,substring(convert(char(13),tqt.AddDate,120),12,2) Hour24,
COUNT (DISTINCT ip) Num_Prt , 
COUNT(1) AS TotalTrans, 
SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) <= 3000 THEN 1 ELSE 0 END)                AS [0-3Sec],
SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) BETWEEN 3001 AND 6000 THEN 1 ELSE 0 END)  AS [3-6Sec], 
SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) BETWEEN 6001 AND 10000 THEN 1 ELSE 0 END) AS [6-10Sec], 
SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) > 10000 THEN 1 ELSE 0 END)                AS [10Sec-More],
CAST (((SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) <= 3000 THEN 1 ELSE 0 END)) / (COUNT(1)*1.00)) *100 AS DECIMAL (5,1)) AS [Prc-Within-3Sec],
CAST (((SUM(CASE WHEN DATEDIFF(millisecond, tqt.AddDate, tqt.EditDate) <= 6000 THEN 1 ELSE 0 END)) / (COUNT(1)*1.00)) *100 AS DECIMAL (5,1)) AS [Prc-Within-6Sec]
FROM TCPSocket_QueueTask_Log AS tqt WITH (NOLOCK) 
WHERE tqt.CmdType='SQL' AND tqt.Cmd LIKE '%isp_BT_GenBartenderCommand%'
GROUP BY 
convert(char(10),tqt.AddDate,120)  ,substring(convert(char(13),tqt.AddDate,120),12,2) 


GO