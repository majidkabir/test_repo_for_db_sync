SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TRANSMITLOG3Alert_NIKE]
AS
SELECT [vx]          =CASE a.[Status] WHEN 0 THEN 'v' ELSE 'X' END
      ,               a.[LogDate]
      ,[LogWho]      =a.[UserId]
      ,[LogHost]     =a.[NotifyId]
      ,[LogSource]   =a.[ModuleName]
      ,[LogID]       =SUBSTRING(a.[AlertKey], patindex('%[^0]%',a.[AlertKey]), 18)
      ,               a.Storerkey
      ,[ConsigneeKey]=a.Sku
      ,Delivery      =a.[ResolveDate]
      ,[Subject]     =a.AlertMessage
      ,[RowCount]    =a.[UOMQty]
      ,DurationSeconds=a.[Qty]
      ,[SQLStmt]     =a.[Resolution]
      ,[ErrorNumber] =a.[Status]
      ,               a.[Severity]
      ,[ErrorMessage]=a.[ID]
FROM [dbo].[ALERT] AS a WITH (NOLOCK)
WHERE ModuleName='isp_TRANSMITLOG3Alert_NIKE'

GO