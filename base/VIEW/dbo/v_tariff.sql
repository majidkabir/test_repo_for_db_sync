SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Tariff] 
AS 
SELECT [TariffKey]
, [Descrip]
, [SupportFlag]
, [InitialStoragePeriod]
, [RecurringStoragePeriod]
, [SplitMonthDay]
, [SplitMonthPercent]
, [PeriodType]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [CalendarGroup]
, [RSPeriodType]
, [SplitMonthPercentBefore]
, [CaptureEndOfMonth]
FROM [Tariff] (NOLOCK) 

GO