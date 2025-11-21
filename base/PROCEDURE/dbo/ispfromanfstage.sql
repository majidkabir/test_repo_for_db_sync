SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispFromANFStage                                     */
/* Copyright: IDS                                                       */
/* Purpose: Location after same SKU style                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-05-07   Ung       1.0   SOS292706 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispFromANFStage]
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

   DECLARE @cpa_LocationCategoryInclude    NVARCHAR(100)
   DECLARE @cpa_LocationCategoryInclude01  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude02  NVARCHAR(10)
   DECLARE @cpa_LocationCategoryInclude03  NVARCHAR(10)
   
   DECLARE @cpa_LocationTypeRestriction    NVARCHAR(100)
   DECLARE @cpa_LocationTypeRestriction01  NVARCHAR(10)
   DECLARE @cpa_LocationTypeRestriction02  NVARCHAR(10)
   DECLARE @cpa_LocationTypeRestriction03  NVARCHAR(10)

   -- Get PutawayStrategy line info
   SELECT 
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

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = @c_SQL + 
            CASE WHEN @c_FromLoc NOT IN ('AF01-STAGE', 'AF02-STAGE') THEN ' AND (1=0) ' ELSE '' END + 
            CASE WHEN @cpa_LocationCategoryInclude <> '' THEN ' AND LOC.LocationCategory IN (' + @cpa_LocationCategoryInclude + ')' ELSE '' END + 
            CASE WHEN @cpa_LocationTypeRestriction <> '' THEN ' AND LOC.LocationType IN (' + @cpa_LocationTypeRestriction + ')' ELSE '' END
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @c_FromLoc IN ('AF01-STAGE', 'AF02-STAGE')
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: FromANFStage  FromLOC=' + RTRIM( @c_FromLoc)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 1 --True
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: FromANFStage  FromLOC=' + RTRIM( @c_FromLoc)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO