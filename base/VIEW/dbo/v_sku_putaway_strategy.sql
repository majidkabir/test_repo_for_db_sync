SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_SKU_Putaway_Strategy] 
AS
SELECT s.StorerKey, 
       s.Sku, 
       s.StrategyKey,
       psd.PutawayStrategyKey,  
       psd.PutawayStrategyLineNumber, 
       psd.PAType, 
       c.[Description] AS PA_Description,
       psd.FROMLOC, 
       psd.TOLOC,
       psd.AreaKey, psd.Zone, psd.LocType, psd.LocSearchType,
       psd.DimensionRestriction01, psd.DimensionRestriction02,
       psd.DimensionRestriction03, psd.DimensionRestriction04,
       psd.DimensionRestriction05, psd.DimensionRestriction06,
       psd.LocationTypeExclude01, psd.LocationTypeExclude02,
       psd.LocationTypeExclude03, psd.LocationTypeExclude04,
       psd.LocationTypeExclude05, psd.LocationFlagExclude01,
       psd.LocationFlagExclude02, psd.LocationFlagExclude03,
       psd.LocationFlagInclude01, psd.LocationFlagInclude02,
       psd.LocationFlagInclude03, psd.LocationHandlingExclude01,
       psd.LocationHandlingExclude02 , psd.LocationHandlingExclude03,
       psd.LocationHandlingInclude01, psd.LocationHandlingInclude02,
       psd.LocationHandlingInclude03, psd.LocationCategoryInclude01,
       psd.LocationCategoryInclude02, psd.LocationCategoryInclude03,
       psd.LocationCategoryExclude01, psd.LocationCategoryExclude02,
       psd.LocationCategoryExclude03, psd.AreaTypeExclude01, psd.AreaTypeExclude02,
       psd.AreaTypeExclude03, psd.LocationTypeRestriction01,
       psd.LocationTypeRestriction02, psd.LocationTypeRestriction03,
       psd.FitFullReceipt, psd.OrderType, psd.NumberofDaysOffSet,
       psd.LocationStateRestriction01, psd.LocationStateRestriction02,
       psd.LocationStateRestriction03, psd.AllowFullPallets, psd.AllowFullCases,
       psd.AllowPieces, psd.CheckEquipmentProfileKey, psd.CheckRestrictions,
       psd.LocLevelInclude01, psd.LocLevelInclude02, psd.LocLevelInclude03,
       psd.LocLevelInclude04, psd.LocLevelInclude05, psd.LocLevelInclude06,
       psd.LocLevelExclude01, psd.LocLevelExclude02, psd.LocLevelExclude03,
       psd.LocLevelExclude04, psd.LocLevelExclude05, psd.LocLevelExclude06,
       psd.LocAisleInclude01, psd.LocAisleInclude02, psd.LocAisleInclude03,
       psd.LocAisleInclude04, psd.LocAisleInclude05, psd.LocAisleInclude06,
       psd.LocAisleExclude01, psd.LocAisleExclude02, psd.LocAisleExclude03,
       psd.LocAisleExclude04, psd.LocAisleExclude05, psd.LocAisleExclude06,
       psd.PutawayZone01, psd.PutawayZone02, psd.PutawayZone03, psd.PutawayZone04,
       psd.PutawayZone05
FROM SKU s WITH (NOLOCK) 
JOIN Strategy STG WITH (NOLOCK) ON STG.StrategyKey = s.StrategyKey 
JOIN PutawayStrategyDetail psd WITH (NOLOCK) ON psd.PutawayStrategyKey = STG.PutawayStrategyKey 
LEFT OUTER JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'PATYPE' AND c.Code = psd.PAType 


GO