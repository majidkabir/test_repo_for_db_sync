SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: fnc_BuildPutawayRestriction                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Speed up putaway                                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 01-06-2012  1.0  James       Make sure suggested LOC not exists in   */
/*                              the locking table(james01)              */
/* 01-06-2012  1.1  ChewKP      SOS#245272 - Bug Fix (ChewKP01)         */
/* 13-06-2012  1.2  Ung         SOS240955 Add dimention restriction     */
/*                              17-Fit by UCC cube                      */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_BuildPutawayRestriction] (    
   @c_PutawayStrategyKey         NVARCHAR(10),    
   @c_PutawayStrategyLineNumber  NVARCHAR(5),    
   @c_PutawayZoneFlag            NVARCHAR(1) = 'N',    
   @n_FromCube                   Float,     
   @c_StorerKey                  NVARCHAR( 15) = '',     
   @c_SKU                        NVARCHAR( 20) = '',     
   @c_LOT                        NVARCHAR( 10) = ''    
   )    
RETURNS NVARCHAR(MAX) AS    
BEGIN    
 DECLARE @cSQL NVARCHAR(MAX)    
    
 SET @cSQL = ''    
 SET @n_FromCube = ISNULL(@n_FromCube, 0)    
    
   DECLARE @b_RestrictionsPassed           INT,    
           @b_GotLoc                       INT,    
           @cpa_PAType                     NVARCHAR(5),    
           @cpa_FromLoc                    NVARCHAR(10),    
           @cpa_ToLoc                      NVARCHAR(10),    
           @cpa_AreaKey                    NVARCHAR(10),    
           @cpa_Zone                       NVARCHAR(10),    
           @cpa_LocType                    NVARCHAR(10),    
           @cpa_LocSearchType              NVARCHAR(10),    
           @cpa_DimensionRestriction01     NVARCHAR(5),    
           @cpa_DimensionRestriction02     NVARCHAR(5),    
           @cpa_DimensionRestriction03     NVARCHAR(5),    
           @cpa_DimensionRestriction04     NVARCHAR(5),    
           @cpa_DimensionRestriction05     NVARCHAR(5),    
           @cpa_DimensionRestriction06     NVARCHAR(5),    
           @cpa_LocationTypeExclude01      NVARCHAR(10),    
           @cpa_LocationTypeExclude02      NVARCHAR(10),    
           @cpa_LocationTypeExclude03      NVARCHAR(10),    
           @cpa_LocationTypeExclude04      NVARCHAR(10),    
           @cpa_LocationTypeExclude05      NVARCHAR(10),    
           @cpa_LocationFlagExclude01      NVARCHAR(10),    
           @cpa_LocationFlagExclude02      NVARCHAR(10),    
           @cpa_LocationFlagExclude03      NVARCHAR(10),    
           @cpa_LocationCategoryExclude01  NVARCHAR(10),    
           @cpa_LocationCategoryExclude02  NVARCHAR(10),    
           @cpa_LocationCategoryExclude03  NVARCHAR(10),    
           @cpa_LocationHandlingExclude01  NVARCHAR(10),    
           @cpa_LocationHandlingExclude02  NVARCHAR(10),    
           @cpa_LocationHandlingExclude03  NVARCHAR(10),    
           @cpa_LocationFlagInclude01      NVARCHAR(10),    
           @cpa_LocationFlagInclude02      NVARCHAR(10),    
           @cpa_LocationFlagInclude03      NVARCHAR(10),    
           @cpa_LocationCategoryInclude01  NVARCHAR(10),    
           @cpa_LocationCategoryInclude02  NVARCHAR(10),    
           @cpa_LocationCategoryInclude03  NVARCHAR(10),    
           @cpa_LocationHandlingInclude01  NVARCHAR(10),    
           @cpa_LocationHandlingInclude02  NVARCHAR(10),    
           @cpa_LocationHandlingInclude03  NVARCHAR(10),    
           @cpa_AreaTypeExclude01          NVARCHAR(10),    
           @cpa_AreaTypeExclude02          NVARCHAR(10),    
           @cpa_AreaTypeExclude03          NVARCHAR(10),    
           @cpa_LocationTypeRestriction01  NVARCHAR(5),    
           @cpa_LocationTypeRestriction02  NVARCHAR(5),    
           @cpa_LocationTypeRestriction03  NVARCHAR(5),    
           @cpa_LocationTypeRestriction04  NVARCHAR(5),    
           @cpa_LocationTypeRestriction05  NVARCHAR(5),    
           @cpa_LocationTypeRestriction06  NVARCHAR(5),    
           @cpa_FitFullReceipt             NVARCHAR(5),    
           @cpa_OrderType                  NVARCHAR(10),    
           @npa_NumberofDaysOffSet         INT,    
           @cpa_LocationStateRestriction1  NVARCHAR(5),    
           @cpa_LocationStateRestriction2  NVARCHAR(5),    
           @cpa_LocationStateRestriction3  NVARCHAR(5),    
           @cpa_AllowFullPallets           NVARCHAR(5),    
           @cpa_AllowFullCases             NVARCHAR(5),    
           @cpa_AllowPieces                NVARCHAR(5),    
           @cpa_CheckEquipmentProfileKey   NVARCHAR(5),    
           @cpa_CheckRestrictions          NVARCHAR(5)    
    
   DECLARE @npa_LocLevelInclude01          INT,    
           @npa_LocLevelInclude02          INT,    
           @npa_LocLevelInclude03          INT,    
           @npa_LocLevelInclude04          INT,    
           @npa_LocLevelInclude05          INT,    
           @npa_LocLevelInclude06          INT,    
           @npa_LocLevelExclude01          INT,    
           @npa_LocLevelExclude02          INT,    
           @npa_LocLevelExclude03          INT,    
           @npa_LocLevelExclude04          INT,    
           @npa_LocLevelExclude05          INT,    
           @npa_LocLevelExclude06          INT,    
           @cpa_LocAisleInclude01          NVARCHAR(10),    
           @cpa_LocAisleInclude02          NVARCHAR(10),    
           @cpa_LocAisleInclude03          NVARCHAR(10),    
           @cpa_LocAisleInclude04          NVARCHAR(10),    
           @cpa_LocAisleInclude05          NVARCHAR(10),    
           @cpa_LocAisleInclude06          NVARCHAR(10),    
           @cpa_LocAisleExclude01          NVARCHAR(10),    
           @cpa_LocAisleExclude02          NVARCHAR(10),    
           @cpa_LocAisleExclude03          NVARCHAR(10),    
           @cpa_LocAisleExclude04          NVARCHAR(10),    
           @cpa_LocAisleExclude05          NVARCHAR(10),    
           @cpa_LocAisleExclude06          NVARCHAR(10),    
           @cpa_PutAwayZone01              NVARCHAR(10),    
           @cpa_PutAwayZone02              NVARCHAR(10),    
           @cpa_PutAwayZone03              NVARCHAR(10),    
           @cpa_PutAwayZone04              NVARCHAR(10),    
           @cpa_PutAwayZone05              NVARCHAR(10)    
    
   DECLARE @c_LocFlagRestriction     NVARCHAR(1000)    
         , @c_LocTypeRestriction     NVARCHAR(1000)    
         , @c_LocCategoryRestriction NVARCHAR(1000)    
         , @n_NoOfInclude            INT    
         , @c_DimRestSQL             NVARCHAR(3000)    
         , @c_LocLevelRestriction    NVARCHAR(2000)    
         , @c_LocAisleRestriction    NVARCHAR(2000)    
         , @c_LocHandlingRestriction NVARCHAR(2000)    
         , @c_LocStateRestriction    NVARCHAR(2000)    
         , @c_PutawayZoneRestriction NVARCHAR(2000)    
         , @c_RFPutaway              NVARCHAR(2000)   -- (james01)    
    
    
      SELECT @c_PutawayStrategyLineNumber = putawaystrategylinenumber,    
             @cpa_PAType = PAType,    
             @cpa_FromLoc = FROMLOC,    
             @cpa_ToLoc = TOLOC,    
             @cpa_AreaKey = AreaKey,    
             @cpa_Zone = Zone,    
             @cpa_LocType = LocType,    
             @cpa_LocSearchType = LocSearchType,    
             @cpa_DimensionRestriction01 = DimensionRestriction01,    
             @cpa_DimensionRestriction02 = DimensionRestriction02,    
             @cpa_DimensionRestriction03 = DimensionRestriction03,    
             @cpa_DimensionRestriction04 = DimensionRestriction04,    
             @cpa_DimensionRestriction05 = DimensionRestriction05,    
             @cpa_DimensionRestriction06 = DimensionRestriction06,    
             @cpa_LocationTypeExclude01 = LocationTypeExclude01,    
             @cpa_LocationTypeExclude02 = LocationTypeExclude02,    
             @cpa_LocationTypeExclude03 = LocationTypeExclude03,    
             @cpa_LocationTypeExclude04 = LocationTypeExclude04,    
             @cpa_LocationTypeExclude05 = LocationTypeExclude05,    
             @cpa_LocationFlagExclude01 = LocationFlagExclude01,    
             @cpa_LocationFlagExclude02 = LocationFlagExclude02,    
             @cpa_LocationFlagExclude03 = LocationFlagExclude03,    
             @cpa_LocationCategoryExclude01 = LocationCategoryExclude01,    
             @cpa_LocationCategoryExclude02 = LocationCategoryExclude02,    
             @cpa_LocationCategoryExclude03 = LocationCategoryExclude03,    
             @cpa_LocationHandlingExclude01 = LocationHandlingExclude01,    
             @cpa_LocationHandlingExclude02 = LocationHandlingExclude02,    
             @cpa_LocationHandlingExclude03 = LocationHandlingExclude03,    
             @cpa_LocationFlagInclude01 = LocationFlagInclude01,    
             @cpa_LocationFlagInclude02 = LocationFlagInclude02,    
             @cpa_LocationFlagInclude03 = LocationFlagInclude03,    
             @cpa_LocationCategoryInclude01 = LocationCategoryInclude01,    
             @cpa_LocationCategoryInclude02 = LocationCategoryInclude02,    
             @cpa_LocationCategoryInclude03 = LocationCategoryInclude03,    
             @cpa_LocationHandlingInclude01 = LocationHandlingInclude01,    
             @cpa_LocationHandlingInclude02 = LocationHandlingInclude02,    
             @cpa_LocationHandlingInclude03 = LocationHandlingInclude03,    
             @cpa_AreaTypeExclude01 = AreaTypeExclude01,    
             @cpa_AreaTypeExclude02 = AreaTypeExclude02,    
             @cpa_AreaTypeExclude03 = AreaTypeExclude03,    
             @cpa_LocationTypeRestriction01 = LocationTypeRestriction01,    
             @cpa_LocationTypeRestriction02 = LocationTypeRestriction02,    
             @cpa_LocationTypeRestriction03 = LocationTypeRestriction03,    
             @cpa_FitFullReceipt = FitFullReceipt,    
             @cpa_OrderType = OrderType,    
             @npa_NumberofDaysOffSet = NumberofDaysOffSet,    
             @cpa_LocationStateRestriction1 = LocationStateRestriction01,    
             @cpa_LocationStateRestriction2 = LocationStateRestriction02,    
             @cpa_LocationStateRestriction3 = LocationStateRestriction03,    
             @cpa_AllowFullPallets = AllowFullPallets,    
             @cpa_AllowFullCases = AllowFullCases,    
             @cpa_AllowPieces = AllowPieces,    
             @cpa_CheckEquipmentProfileKey = CheckEquipmentProfileKey,    
             @cpa_CheckRestrictions = CheckRestrictions,    
             @npa_LocLevelInclude01 = LocLevelInclude01,    
             @npa_LocLevelInclude02 = LocLevelInclude02,    
             @npa_LocLevelInclude03 = LocLevelInclude03,    
             @npa_LocLevelInclude04 = LocLevelInclude04,    
             @npa_LocLevelInclude05 = LocLevelInclude05,    
             @npa_LocLevelInclude06 = LocLevelInclude06,    
             @npa_LocLevelExclude01 = LocLevelExclude01,    
             @npa_LocLevelExclude02 = LocLevelExclude02,    
             @npa_LocLevelExclude03 = LocLevelExclude03,    
             @npa_LocLevelExclude04 = LocLevelExclude04,    
             @npa_LocLevelExclude05 = LocLevelExclude05,    
             @npa_LocLevelExclude06 = LocLevelExclude06,    
             @cpa_LocAisleInclude01 = LocAisleInclude01,    
             @cpa_LocAisleInclude02 = LocAisleInclude02,    
             @cpa_LocAisleInclude03 = LocAisleInclude03,    
             @cpa_LocAisleInclude04 = LocAisleInclude04,    
             @cpa_LocAisleInclude05 = LocAisleInclude05,    
             @cpa_LocAisleInclude06 = LocAisleInclude06,    
             @cpa_LocAisleExclude01 = LocAisleExclude01,    
             @cpa_LocAisleExclude02 = LocAisleExclude02,    
             @cpa_LocAisleExclude03 = LocAisleExclude03,    
             @cpa_LocAisleExclude04 = LocAisleExclude04,    
             @cpa_LocAisleExclude05 = LocAisleExclude05,    
             @cpa_LocAisleExclude06 = LocAisleExclude06,    
             @cpa_PutAwayZone01     = PutAwayZone01,    
             @cpa_PutAwayZone02     = PutAwayZone02,    
             @cpa_PutAwayZone03     = PutAwayZone03,    
             @cpa_PutAwayZone04     = PutAwayZone04,    
             @cpa_PutAwayZone05     = PutAwayZone05    
       FROM  PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)    
       WHERE PutAwayStrategyKey = @c_PutawayStrategyKey AND    
             putawaystrategylinenumber = @c_PutawayStrategyLineNumber    
       ORDER BY putawaystrategylinenumber    
    
      IF ISNULL(RTRIM(@cpa_LocationFlagInclude01),'') <> ''    
      BEGIN    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude01) + ''''    
         SELECT @cpa_LocationFlagInclude01 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationFlagInclude02),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude02) + ''''    
         SELECT @cpa_LocationFlagInclude02 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationFlagInclude03),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude03) + ''''    
         SELECT @cpa_LocationFlagInclude03 = ''    
      END    
    
      IF @n_NoOfInclude = 1    
         SELECT @c_LocFlagRestriction = ' AND LOC.LocationFlag = ' + RTRIM(@c_LocFlagRestriction)    
      ELSE IF @n_NoOfInclude > 1    
         SELECT @c_LocFlagRestriction = ' AND LOC.LocationFlag IN (' + RTRIM(@c_LocFlagRestriction) + ') '    
      ELSE    
         SELECT @c_LocFlagRestriction = ''    
      -- END Build Location Flag    
    
------------------------------------------------------------------------------------------------------------------------    
--LocationFlagExclude    
      SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) +    
               CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 OR    
                         LEN(@cpa_LocationFlagExclude02) > 0 OR    
                         LEN(@cpa_LocationFlagExclude03) > 0 THEN    
                  ' AND LOC.LocationFlag NOT IN ('    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 THEN    
                  'N''' + RTRIM(@cpa_LocationFlagExclude01) + ''''    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationFlagExclude02) > 0 THEN    
                  ',N''' + RTRIM(@cpa_LocationFlagExclude02) + ''''    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationFlagExclude03) > 0 THEN    
                  ',N''' + RTRIM(@cpa_LocationFlagExclude03) + ''''    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 OR    
                         LEN(@cpa_LocationFlagExclude02) > 0 OR    
                         LEN(@cpa_LocationFlagExclude03) > 0 THEN    
                  ')'    
                  ELSE ''    
               END    
------------------------------------------------------------------------------------------------------------------------    
    
      SET @c_LocLevelRestriction = ''    
    
      IF ISNULL(@npa_LocLevelInclude01,0) <> 0 OR    
         ISNULL(@npa_LocLevelInclude02,0) <> 0 OR    
         ISNULL(@npa_LocLevelInclude03,0) <> 0 OR    
         ISNULL(@npa_LocLevelInclude04,0) <> 0 OR    
         ISNULL(@npa_LocLevelInclude05,0) <> 0 OR    
         ISNULL(@npa_LocLevelInclude06,0) <> 0    
      BEGIN    
         SET @c_LocLevelRestriction = ' AND LOC.LocLevel IN ('    
    
         IF ISNULL(@npa_LocLevelInclude01,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + RTRIM(CAST(@npa_LocLevelInclude01 AS NVARCHAR(10)))    
    
         IF ISNULL(@npa_LocLevelInclude02,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelInclude02 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelInclude03,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelInclude03 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelInclude04,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
     + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelInclude04 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelInclude05,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelInclude05 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelInclude06,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
 + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelInclude06 AS NVARCHAR(10)))    
    
         SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)    
      END    
    
      IF ISNULL(@npa_LocLevelExclude01,0) <> 0 OR    
         ISNULL(@npa_LocLevelExclude02,0) <> 0 OR    
         ISNULL(@npa_LocLevelExclude03,0) <> 0 OR    
         ISNULL(@npa_LocLevelExclude04,0) <> 0 OR    
         ISNULL(@npa_LocLevelExclude05,0) <> 0 OR    
         ISNULL(@npa_LocLevelExclude06,0) <> 0    
      BEGIN    
         SET @c_LocLevelRestriction = @c_LocLevelRestriction + ' AND LOC.LocLevel NOT IN ('    
    
         IF ISNULL(@npa_LocLevelExclude01,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + RTRIM(CAST(@npa_LocLevelExclude01 AS NVARCHAR(10)))    
    
         IF ISNULL(@npa_LocLevelExclude02,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelExclude02 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelExclude03,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelExclude03 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelExclude04,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelExclude04 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelExclude05,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelExclude05 AS NVARCHAR(10)))    
         IF ISNULL(@npa_LocLevelExclude06,0) <> 0    
            SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)    
                                       + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END    
                                       + RTRIM(CAST(@npa_LocLevelExclude06 AS NVARCHAR(10)))    
    
         SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + ')'  + master.dbo.fnc_GetCharASCII(13)    
      END    
    
      SET @c_LocAisleRestriction = ''    
    
      IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''    
      BEGIN    
         SET @c_LocAisleRestriction = ' AND LOC.LocAisle IN ('    
    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + 'N''' + ISNULL(RTRIM(@cpa_LocAisleInclude01), '')    
           + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleInclude02), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleInclude03), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleInclude04), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleInclude05), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleInclude06), '') + ''''    
    
         SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)    
      END    
    
      IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> '' OR    
         ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''    
      BEGIN    
         SET @c_LocAisleRestriction = @c_LocAisleRestriction + ' AND LOC.LocAisle NOT IN ('    
    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + 'N''' + ISNULL(RTRIM(@cpa_LocAisleExclude01), '')    
                                       + ''''    
    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleExclude02), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleExclude03), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleExclude04), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleExclude05), '') + ''''    
         IF ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''    
            SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)    
                                       + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',N''' END    
                                       + ISNULL(RTRIM(@cpa_LocAisleExclude06), '') + ''''    
    
         SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)    
      END    
    
      ---- Build Location LocationHandling Restriction SQL XXXX    
      SELECT @n_NoOfInclude = 0    
      SELECT @c_LocHandlingRestriction = ''    
    
      IF ISNULL(RTRIM(@cpa_LocationHandlingInclude01),'') <> ''    
      BEGIN    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocHandlingRestriction = RTRIM(@c_LocHandlingRestriction) + 'N''' + RTRIM(@cpa_LocationHandlingInclude01) + ''''    
     SELECT @cpa_LocationHandlingInclude01 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationHandlingInclude02),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocHandlingRestriction = RTRIM(@c_LocHandlingRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocHandlingRestriction = RTRIM(@c_LocHandlingRestriction) + 'N''' + RTRIM(@cpa_LocationHandlingInclude02) + ''''    
         SELECT @cpa_LocationHandlingInclude02 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationHandlingInclude03),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocHandlingRestriction = RTRIM(@c_LocHandlingRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocHandlingRestriction = RTRIM(@c_LocHandlingRestriction) + 'N''' + RTRIM(@cpa_LocationHandlingInclude03) + ''''    
         SELECT @cpa_LocationHandlingInclude03 = ''    
      END    
    
      IF @n_NoOfInclude = 1    
         SELECT @c_LocHandlingRestriction = ' AND LOC.LocationHandling = ' + RTRIM(@c_LocHandlingRestriction)    
      ELSE IF @n_NoOfInclude > 1    
         SELECT @c_LocHandlingRestriction = ' AND LOC.LocationHandling IN (' + RTRIM(@c_LocHandlingRestriction) + ') '    
      ELSE    
         SELECT @c_LocHandlingRestriction = ''    
    
      -- Build Location LocationHandling Restriction    
      -- Build Location Category Restriction SQL    
      SELECT @n_NoOfInclude = 0    
      SELECT @c_LocCategoryRestriction = ''    
    
      IF ISNULL(RTRIM(@cpa_LocationCategoryInclude01),'') <> ''    
      BEGIN    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude01) + ''''    
         SELECT @cpa_LocationCategoryInclude01 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationCategoryInclude02),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude02) + ''''    
         SELECT @cpa_LocationCategoryInclude02 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationCategoryInclude03),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude03) + ''''    
         SELECT @cpa_LocationCategoryInclude03 = ''    
      END    
    
      IF @n_NoOfInclude = 1    
         SELECT @c_LocCategoryRestriction = ' AND LOC.LocationCategory = ' + RTRIM(@c_LocCategoryRestriction)    
      ELSE IF @n_NoOfInclude > 1    
         SELECT @c_LocCategoryRestriction = ' AND LOC.LocationCategory IN (' + RTRIM(@c_LocCategoryRestriction) + ') '    
      ELSE    
         SELECT @c_LocCategoryRestriction = ''    
    
    
   SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) +    
               CASE WHEN LEN(@cpa_LocationCategoryExclude01) > 0 OR    
                         LEN(@cpa_LocationCategoryExclude02) > 0 OR    
                         LEN(@cpa_LocationCategoryExclude03) > 0 THEN    
                  ' AND LOC.LocationCategory NOT IN ('    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationCategoryexclude01) > 0 THEN    
                  'N''' + RTRIM(@cpa_LocationCategoryexclude01) + ''''    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationCategoryexclude02) > 0 THEN    
                  ',N''' + RTRIM(@cpa_LocationCategoryexclude02) + ''''    
                  ELSE ''    
               END +    
               CASE WHEN LEN(@cpa_LocationCategoryexclude03) > 0 THEN    
                  ',N''' + RTRIM(@cpa_LocationCategoryexclude03) + ''''    
                ELSE ''    
          END +    
               CASE WHEN LEN(@cpa_LocationCategoryexclude01) > 0 OR    
                         LEN(@cpa_LocationCategoryexclude02) > 0 OR    
                         LEN(@cpa_LocationCategoryexclude03) > 0 THEN    
                  ')'    
                  ELSE ''    
               END    
      -- END Build Location Category    
      -------------------    
    
      -- BEGIN Build Location Type Restriction    
      SELECT @n_NoOfInclude = 0    
      SELECT @c_LocTypeRestriction = ''    
    
      IF ISNULL(RTRIM(@cpa_LocationTypeExclude01),'') <> ''    
      BEGIN    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude01) + ''''    
         SELECT @cpa_LocationTypeExclude01 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationTypeExclude02),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude02) + ''''    
         SELECT @cpa_LocationTypeExclude02 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationTypeExclude03),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude03) + ''''    
         SELECT @cpa_LocationTypeExclude03 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationTypeExclude04),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude04) + ''''    
         SELECT @cpa_LocationTypeExclude04 = ''    
      END    
      IF ISNULL(RTRIM(@cpa_LocationTypeExclude05),'') <> ''    
      BEGIN    
         IF @n_NoOfInclude > 0    
            SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','    
    
         SELECT @n_NoOfInclude = @n_NoOfInclude + 1    
         SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude05) + ''''    
         SELECT @cpa_LocationTypeExclude05 = ''    
      END    
    
      IF @n_NoOfInclude = 1    
         SELECT @c_LocTypeRestriction = ' AND LOC.LOCATIONTYPE <> ' + RTRIM(@c_LocTypeRestriction)    
      ELSE IF @n_NoOfInclude > 1    
         SELECT @c_LocTypeRestriction = ' AND LOC.LOCATIONTYPE NOT IN (' + RTRIM(@c_LocTypeRestriction) + ') '    
      ELSE    
         SELECT @c_LocTypeRestriction = ''    
      -- END Build Location Type    
    
------------------------------------------------------------------------------------------------------------------------    
    SET @c_LocStateRestriction = ''    
        
    --Must Be Empty    
    IF '1' IN (@cpa_LocationStateRestriction1,    
               @cpa_LocationStateRestriction2,    
               @cpa_LocationStateRestriction3)    
    BEGIN    
       SET @c_LocStateRestriction = ' AND NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK) ' +    
                                    ' WHERE (SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0 AND SKUxLOC.LOC = LOC.LOC)'    
    END    
    
    --Do not Mix Skus    
    IF '2' IN (@cpa_LocationStateRestriction1,    
               @cpa_LocationStateRestriction2,    
               @cpa_LocationStateRestriction3) AND @c_StorerKey <> '' AND @c_SKU <> ''    
    BEGIN    
       SET @c_LocStateRestriction = @c_LocStateRestriction + ' AND NOT EXISTS( ' +     
         ' SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) ' +     
         ' WHERE LOTxLOCxID.LOC = LOC.LOC ' +     
         ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked> 0 OR LOTxLOCxID.PendingMoveIN > 0) ' +     -- (ChewKP01)
         ' AND (LOTxLOCxID.StorerKey <> N''' + RTRIM(@c_StorerKey) + ''' OR LOTxLOCxID.SKU <> N''' + RTRIM(@c_SKU) + '''))'    
    END    
        
    --Do not Mix Lots    
    IF '3' IN (@cpa_LocationStateRestriction1,    
               @cpa_LocationStateRestriction2,    
               @cpa_LocationStateRestriction3) AND @c_LOT <> ''    
    BEGIN    
       SET @c_LocStateRestriction = @c_LocStateRestriction + ' AND NOT EXISTS( ' +     
         ' SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) ' +     
         ' WHERE LOTxLOCxID.LOC = LOC.LOC ' +     
         ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked> 0 OR LOTxLOCxID.PendingMoveIN > 0) ' +  -- (ChewKP01)   
         ' AND (LOTxLOCxID.LOT <> N''' + RTRIM(@c_LOT) + '''))'    
    END    
    
------------------------------------------------------------------------------------------------------------------------    
    
   IF '1' IN (@cpa_DimensionRestriction01,    
              @cpa_DimensionRestriction02,    
              @cpa_DimensionRestriction03,    
              @cpa_DimensionRestriction04,    
              @cpa_DimensionRestriction05,    
              @cpa_DimensionRestriction06)    
   BEGIN    
      SET @c_DimRestSQL = ' AND NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK) ' +    
                          ' JOIN SKU WITH (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND ' +    
                          ' SKUxLOC.SKU = SKU.SKU ' +    
                          ' WHERE SKUxLOC.LOC = LOC.LOC ' +    
                          ' GROUP BY SKUxLOC.LOC ' +    
                          ' HAVING SUM((SKUxLOC.Qty - SKUxLOC.QtyPicked) * SKU.StdCube) + ' +    
                          CAST(@n_FromCube AS NVARCHAR(20)) + ' > LOC.CubicCapacity )' +    
                          ' AND LOC.CubicCapacity >= ' + CAST(@n_FromCube AS NVARCHAR(20))    
   END    

   IF '17' IN (@cpa_DimensionRestriction01,    
               @cpa_DimensionRestriction02,    
               @cpa_DimensionRestriction03,    
               @cpa_DimensionRestriction04,    
               @cpa_DimensionRestriction05,    
               @cpa_DimensionRestriction06)    
   BEGIN    
      SET @c_DimRestSQL = ' AND CASE WHEN EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE LOC = LOC.LOC AND Status = ''1'') THEN ' + 
                          --UCC cube on ToLOC
                          '    (SELECT ISNULL( SUM( Pack.CubeUOM1), 0) ' +  
                          '    FROM dbo.UCC WITH (NOLOCK) ' +  
                          '       JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU) ' +  
                          '       JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey) ' +  
                          '    WHERE UCC.LOC = LOC.LOC ' +  
                          '       AND Status = ''1'') ' +  
                          ' ELSE ' +  
                          -- NON-UCC cube on ToLOC
                          '    (SELECT ISNULL( SUM((LOTxLOCxID.QTY - LOTxLOCxID.QTYPicked + LOTxLOCxID.PendingMoveIn) * SKU.STDCube), 0) ' +  
                          '    FROM LOTxLOCxID WITH (NOLOCK) ' +  
                          '       JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.SKU = SKU.SKU) ' +  
                          '    WHERE LOTxLOCxID.LOC = LOC.LOC  ' + 
                          '       AND (LOTxLOCxID.QTY > 0 OR LOTxLOCxID.PendingMoveIn > 0) ) ' +  
                          ' END + ' +  
                          CAST(@n_FromCube AS NVARCHAR(20)) + ' <= LOC.CubicCapacity '     
   END 
    
    SET @c_PutawayZoneRestriction = ''    
    IF @c_PutawayZoneFlag = 'Y'    
    BEGIN    
       SET @c_PutawayZoneRestriction =    
       CASE WHEN LEN(@cpa_Zone) > 0 OR    
                 LEN(@cpa_PutAwayZone01) > 0 OR    
                 LEN(@cpa_PutAwayZone02) > 0 OR    
                 LEN(@cpa_PutAwayZone03) > 0 OR    
                 LEN(@cpa_PutAwayZone04) > 0 OR    
                 LEN(@cpa_PutAwayZone05) > 0 THEN    
                  ' AND LOC.PUTAWAYZONE IN ('    
                 ELSE ''    
             END +    
             CASE WHEN LEN(@cpa_Zone) > 0 THEN    
               'N''' + RTRIM(@cpa_Zone) + ''''    
               ELSE ''    
             END +    
             CASE WHEN LEN(@cpa_PutAwayZone01) > 0 THEN    
               CASE WHEN LEN(@cpa_Zone) > 0 THEN ',N''' ELSE '' END + RTRIM(@cpa_PutAwayZone01) + ''''    
               ELSE ''    
             END +    
             CASE WHEN LEN(@cpa_PutAwayZone02) > 0 THEN    
               ',N''' + RTRIM(@cpa_PutAwayZone02) + ''''    
               ELSE ''    
             END +    
             CASE WHEN LEN(@cpa_PutAwayZone03) > 0 THEN    
               ',N''' + RTRIM(@cpa_PutAwayZone03) + ''''    
               ELSE ''                 END +    
             CASE WHEN LEN(@cpa_PutAwayZone04) > 0 THEN    
               ',N''' + RTRIM(@cpa_PutAwayZone04) + ''''    
               ELSE ''    
             END +    
             CASE WHEN LEN(@cpa_PutAwayZone05) > 0 THEN    
               ',N''' + RTRIM(@cpa_PutAwayZone05) + ''''    
                ELSE ''    
             END    
             + ')'    
    END    
    
   -- Make sure suggested LOC not exists in the locking table (james01)    
    SET @c_RFPutaway = ' AND NOT EXISTS( ' +     
      ' SELECT 1 FROM RFPutaway WITH (NOLOCK) ' +     
      ' WHERE LOC.LOC = RFPutaway.SuggestedLoc )'     
             
  SET @cSQL = ISNULL( RTRIM(@c_LocFlagRestriction), '') +    
                ISNULL( RTRIM(@c_LocTypeRestriction), '') +    
                ISNULL( RTRIM(@c_LocLevelRestriction), '') +    
                ISNULL( RTRIM(@c_LocAisleRestriction), '') +    
                ISNULL( RTRIM(@c_LocHandlingRestriction),'') +    
                ISNULL( RTRIM(@c_LocCategoryRestriction), '') +    
                ISNULL( RTRIM(@c_PutawayZoneRestriction),'') +    
                ISNULL( RTRIM(@c_DimRestSQL),'') +    
                ISNULL( RTRIM(@c_LocStateRestriction), '') +     
                ISNULL( RTRIM(@c_RFPutaway), '')    
    
   RETURN @cSQL    
END    
  

GO