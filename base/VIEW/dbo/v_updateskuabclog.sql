SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_UpdateSkuABCLog]
AS
SELECT [vx]          =CASE a.[Status] WHEN 0 THEN 'v' ELSE 'X' END
      ,               a.[LogDate]
      ,[LogWho]      =a.[UserId]
      ,[LogHost]     =a.[NotifyId]
      ,[LogSource]   =a.[ModuleName]
      ,[LogID]       =SUBSTRING(a.[AlertKey], patindex('%[^0]%',a.[AlertKey]), 18)
      ,               a.Storerkey
      ,               a.Sku
      ,[Material]    =a.[Activity]
      ,[AbcFrom]     =a.[TaskDetailKey]
      ,[AbcTo]       =a.[TaskDetailKey2]
      ,[ProductModel]=a.[UCCNo]
      ,[ADays]       =a.[Severity]
      ,[BDays]       =a.[UOMQty]
      ,[DayDiff]     =a.[Qty]
      ,DurationSeconds=DATEDIFF(second,a.ResolveDate,a.LogDate)
      ,[Facility]    =a.Loc
      ,[UpdateStmt]  =a.[Resolution]
      ,[ErrorNumber] =a.[Status]
      ,[ErrorMessage]=a.[AlertMessage]
FROM [dbo].[ALERT] AS a WITH (NOLOCK)
WHERE ModuleName='ispUpdateSkuABC'

GO