SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispSKUBrandInPAZone                                 */
/* Copyright: IDS                                                       */
/* Purpose: Location after same SKU style                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-05-07   Ung       1.0   SOS292706 Created                       */
/* 2014-08-05   Ung       1.1   SOS317812 Find a friend customize       */
/* 2014-09-05   ChewKP    1.2   Cater for CN requirement by Gender      */
/*                              (ChewKP01)                              */
/* 2015-05-28   ChewKP    1.3   V7 Fixes (ChewKP02)                     */
/* 2018-05-22   ChewKP    1.4   WMS-5007 (ChewKP03)                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSKUBrandInPAZone]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey NVARCHAR(15)
   ,@c_SKU       NVARCHAR(20)
   ,@c_LOT       NVARCHAR(10)
   ,@c_FromLoc   NVARCHAR(10)
   ,@c_ID        NVARCHAR(18)
   ,@n_Qty       INT     
   ,@c_ToLoc     NVARCHAR(10)
   ,@c_Param1    NVARCHAR(20)
   ,@c_Param2    NVARCHAR(20)
   ,@c_Param3    NVARCHAR(20)
   ,@c_Param4    NVARCHAR(20)
   ,@c_Param5    NVARCHAR(20)
   ,@b_debug     INT
   ,@c_SQL       NVARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Reason NVARCHAR(80)
   DECLARE @cBUSR5   NVARCHAR(30)
   DECLARE @cPAZone  NVARCHAR(10)
   DECLARE @cPAType  NVARCHAR(5)
   DECLARE @cBrandInZone NVARCHAR(1)

   DECLARE @cpa_LocationCategoryInclude    NVARCHAR(100)
   DECLARE @cpa_LocationCategoryInclude01  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude02  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude03  NVARCHAR(10)
   
   DECLARE @cpa_LocationTypeRestriction    NVARCHAR(100)
   DECLARE @cpa_LocationTypeRestriction01  NVARCHAR(10)
   DECLARE @cpa_LocationTypeRestriction02  NVARCHAR(10)
   DECLARE @cpa_LocationTypeRestriction03  NVARCHAR(10)
   DECLARE @cCountry NVARCHAR(5) -- (ChewKP01) 
   DECLARE @cGender  NVARCHAR(5) -- (ChewKP01) 

   -- Get PutawayStrategy line info
   SELECT 
      @cPAType = PAType, 
      @cPAZone = Zone, 
      @cpa_LocationCategoryInclude01 = LocationCategoryInclude01,
      @cpa_LocationCategoryInclude02 = LocationCategoryInclude02,
      @cpa_LocationCategoryInclude03 = LocationCategoryInclude03,
      @cpa_LocationTypeRestriction01 = LocationTypeRestriction01,
      @cpa_LocationTypeRestriction02 = LocationTypeRestriction02,
      @cpa_LocationTypeRestriction03 = LocationTypeRestriction03
   FROM dbo.PutawayStrategyDetail WITH (NOLOCK)
   WHERE PutAwayStrategyKey = @c_PutawayStrategyKey 
       AND PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber

   SET @cpa_LocationCategoryInclude = ''
   IF @cpa_LocationCategoryInclude01 <> '' SET @cpa_LocationCategoryInclude = @cpa_LocationCategoryInclude + 'N''' + @cpa_LocationCategoryInclude01 + ''','
   IF @cpa_LocationCategoryInclude02 <> '' SET @cpa_LocationCategoryInclude = @cpa_LocationCategoryInclude + 'N''' + @cpa_LocationCategoryInclude02 + ''','
   IF @cpa_LocationCategoryInclude03 <> '' SET @cpa_LocationCategoryInclude = @cpa_LocationCategoryInclude + 'N''' + @cpa_LocationCategoryInclude03 + ''','
   IF RIGHT( @cpa_LocationCategoryInclude, 1) = ','
      SET @cpa_LocationCategoryInclude = LEFT( @cpa_LocationCategoryInclude, LEN( @cpa_LocationCategoryInclude) - 1)

   SET @cpa_LocationTypeRestriction = ''
   IF @cpa_LocationTypeRestriction01 <> '' SET @cpa_LocationTypeRestriction = @cpa_LocationTypeRestriction + 'N''' + @cpa_LocationTypeRestriction01 + ''','
   IF @cpa_LocationTypeRestriction02 <> '' SET @cpa_LocationTypeRestriction = @cpa_LocationTypeRestriction + 'N''' + @cpa_LocationTypeRestriction02 + ''','
   IF @cpa_LocationTypeRestriction03 <> '' SET @cpa_LocationTypeRestriction = @cpa_LocationTypeRestriction + 'N''' + @cpa_LocationTypeRestriction03 + ''','
   IF RIGHT( @cpa_LocationTypeRestriction, 1) = ','
      SET @cpa_LocationTypeRestriction = LEFT( @cpa_LocationTypeRestriction, LEN( @cpa_LocationTypeRestriction) - 1)

   -- Get SKU brand
   SET @cBUSR5 = ''
   SELECT @cBUSR5 = BUSR5 
         ,@cGender = Measurement
   FROM SKU WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU

   SELECT TOP 1 @cCountry = UDF02 FROM dbo.Codelkup WITH (NOLOCK) WHERE ListName = 'Brand2Zone' 
   
   IF ISNULL(RTRIM(@cCountry),'')  <> 'CN' -- (ChewKP02)
   BEGIN
      -- Check SKU brand in PAZone
      IF EXISTS( SELECT TOP 1 1  
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'Brand2Zone'
            AND Code = @cPAZone
            AND Short = @cBUSR5) -- Brand
            -- AND StorerKey = @c_StorerKey)
         SET @cBrandInZone = 'Y'
      ELSE
         SET @cBrandInZone = 'N'
   END
   ELSE IF ISNULL(RTRIM(@cCountry),'')  = 'CN'
   BEGIN
       -- Check SKU brand in PAZone
      IF EXISTS( SELECT TOP 1 1  
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'Brand2Zone'
            AND Code = @cPAZone
            AND Short = @cBUSR5 -- Brand  
            AND UDF01 = @cGender)
         SET @cBrandInZone = 'Y'
      ELSE
         SET @cBrandInZone = 'N'
   END
   
   -- Get Lottable02
   DECLARE @cLottable02 NVARCHAR(18)
   DECLARE @cLottable03 NVARCHAR(18)
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SELECT 
      @cLottable02 = Lottable02, 
      @cLottable03 = Lottable03 
   FROM LotAttribute WITH (NOLOCK) 
   WHERE LOT = @c_LOT

   -- Lottable02 condition
   DECLARE @cSameL02 NVARCHAR(1)
   IF LEN( @cLottable02) IN (1, 6)
      SET @cSameL02 = 'Y'
   ELSE
      SET @cSameL02 = 'N'

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = @c_SQL  + 
            ' AND LOC.PickZone IN ( ''1'', ''2'' ,''3'' ) ' + 
            CASE WHEN @c_FromLoc IN ('AF01-STAGE', 'AF02-STAGE') THEN ' AND (1=0) ' ELSE '' END + 
            CASE WHEN @cBrandInZone = 'N' THEN ' AND (1=0) ' ELSE '' END + 
            CASE WHEN @cpa_LocationCategoryInclude <> '' THEN ' AND LOC.LocationCategory IN (' + @cpa_LocationCategoryInclude + ')' ELSE '' END + 
            CASE WHEN @cpa_LocationTypeRestriction <> '' THEN ' AND LOC.LocationType IN (' + @cpa_LocationTypeRestriction + ')' ELSE '' END + 
            CASE WHEN @cPAType = '19' THEN ' AND NOT EXISTS( SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = LOC.LOC AND PendingMoveIn > 0)' ELSE '' END + 
            CASE WHEN @cPAType = '21' THEN ' AND EXISTS( ' + 
               ' SELECT TOP 1 1 ' + 
               ' FROM LOTxLOCxID LLI WITH (NOLOCK) ' + 
               '    JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT) ' + 
               ' WHERE LLI.LOC = LOC.LOC ' + 
               '    AND LLI.StorerKey = ''' + @c_StorerKey + '''' + 
               '    AND LLI.SKU = ''' + @c_SKU + '''' + 
               '    AND (QTY-QTYPicked > 0 OR PendingMoveIn > 0) ' + ')'
            
               --'    AND LA.Lottable03 = ''' + @cLottable03 + '''' + -- (ChewKP03) 
               --CASE WHEN @cSameL02 = 'Y' THEN -- (ChewKP03) 
               --'    AND LA.Lottable02 = ''' + @cLottable02 + '''' ELSE '' END + ')'  -- (ChewKP03) 
               ELSE '' 
            END
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @c_FromLoc IN ('AF01-STAGE', 'AF02-STAGE')
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SKUBrandInPAZone  FromLOC=AF01-STAGE/AF02-STAGE'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cBrandInZone = 'N'
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SKUBrandInPAZone  SKUBrand=' + RTRIM( @cBUSR5) + ' PAZone=' + RTRIM( @cPAZone)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cPAType = '19' AND EXISTS( SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @c_ToLoc AND PendingMoveIn > 0) 
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SKUBrandInPAZone  Empty LOC with PendingMoveIn'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cPAType = '21' AND NOT EXISTS( 
               SELECT TOP 1 1 
               FROM LOTxLOCxID LLI WITH (NOLOCK)  
                  JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT) 
               WHERE LLI.LOC = @c_ToLoc
                  AND LLI.StorerKey = @c_StorerKey
                  AND LLI.SKU = @c_SKU 
                  AND (QTY-QTYPicked > 0 OR PendingMoveIn > 0)
                  --AND LA.Lottable03 = @cLottable03 -- (ChewKP03) 
                  --AND LA.Lottable02 = CASE WHEN @cSameL02 = 'Y' THEN @cLottable02 ELSE LA.Lottable02 END -- (ChewKP03) 
                     )
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SKUBrandInPAZone  No match SKU/L2/L3'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cBrandInZone = 'Y'
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: SKUBrandInPAZone  SKUBrand=' + RTRIM( @cBUSR5) + ' PAZone=' + RTRIM( @cPAZone)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 1 --True
      END
      ELSE 
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SKUBrandInPAZone  Unknown error'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO