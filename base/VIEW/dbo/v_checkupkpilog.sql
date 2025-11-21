SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CheckUpKPILog]
AS
SELECT [vx]          =CASE a.[Status] WHEN 0 THEN 'v' ELSE 'X' END
      ,               a.[LogDate]
      ,[LogWho]      =a.[UserId]
      ,[LogHost]     =a.[NotifyId]
      ,[LogSource]   =a.[ModuleName]
      ,[LogID]       =SUBSTRING(a.[AlertKey], patindex('%[^0]%',a.[AlertKey]), 18)
      ,[KPI]         =a.[UOMQty]
      ,               c.[KPICode]
      ,[DynamicSQL]  =a.[Resolution]
      ,[ResultCount] =a.[Qty]
      ,DurationSeconds=DATEDIFF(second,a.ResolveDate,a.LogDate)
      ,               a.Storerkey
      ,[Facility]    =a.Loc
      ,               a.[Severity]
      ,[ErrorNumber] =a.[Status]
      ,[ErrorMessage]=a.[AlertMessage]
FROM [dbo].[ALERT] AS a WITH (NOLOCK)
LEFT OUTER JOIN [dbo].[CheckUpKPI] AS c WITH (NOLOCK)
ON c.KPI = a.UOMQty
WHERE ModuleName='isp_CheckUpKPI'

GO