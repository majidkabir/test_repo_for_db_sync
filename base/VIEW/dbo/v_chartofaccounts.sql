SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ChartOfAccounts] 
AS 
SELECT [ChartofAccountsKey]
, [Descrip]
, [SupportFlag]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
FROM [ChartOfAccounts] (NOLOCK) 

GO