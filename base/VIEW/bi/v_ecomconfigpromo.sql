SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW  [BI].[V_eComConfigPromo]
AS
WITH CTE AS (
   SELECT TOP 1 StartDate, EndDate, Descr FROM BI.eComPromo WITH (NOLOCK) WHERE StartDate<=GETDATE() ORDER BY PromoID DESC
)
SELECT e.[StorerKey]
      ,e.[Brand]
      ,e.[Facility]
      ,e.[FacilityDesc]
      ,e.[IsActive]
      ,e.[OrdersForecast]
      ,e.[OpsDays]
      ,e.[PickHours]
      ,e.[AllocHours]
      ,e.[PresaleStart]
      ,[PromoStart] = CASE WHEN e.[PromoStart]     IS NULL THEN CTE.StartDate ELSE e.[PromoStart] END
      ,[CompletionDate] = CASE WHEN e.[CompletionDate] IS NULL THEN CTE.EndDate   ELSE e.[CompletionDate] END
      ,e.[HoursOverrun]
      ,e.[SLADescription]
      ,e.[SLAMinimum]
      ,e.[ShowPreSales]
      ,[DashboardDescription] = CASE WHEN e.[DashboardDescription] = '' THEN CTE.Descr ELSE e.[DashboardDescription] END
      ,e.[ShowCourier]
      ,e.[UnitsForecast]
      ,e.[DocType]
      ,e.[AddDate]
      ,e.[AddWho]
      ,e.[EditDate]
      ,e.[EditWho]
FROM BI.eComConfig AS e WITH (NOLOCK)
CROSS JOIN CTE
WHERE e.IsActive = 1;

GO