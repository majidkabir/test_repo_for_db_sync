SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_RCMUsage]
AS
SELECT [UDF01] as DataWindowName,
       [UDF02] as EventName,
       [UDF03] as WindowName,
       [UDF05] as UserId,
       CAST( [UDF06] as Int) as UsageCount,
       Convert( Datetime, Convert(char(10), LogDate, 112) ) AS LogDate
  FROM [IDS_GeneralLog] WITH (NOLOCK)
WHERE UDF04 = 'RMCLICK'
AND [UDF02] NOT IN ('ue_modifymode','ue_standards',
 'ue_refresh','ue_viewdetail','ue_save','ue_viewmode',
 'ue_ShowFormorTab')


GO