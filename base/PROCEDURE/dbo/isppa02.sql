SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: ispPA02                                             */
/* Copyright: LF                                                        */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-08-08   ChewKP    1.0   SOS#374910 Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPA02]
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
          ,@c_PutawayZoneCategory NVARCHAR(10) 
          ,@c_Facility            NVARCHAR(5)
          ,@n_MinQty              INT
          ,@n_LocQty              INT
          ,@n_CaseCnt             INT
          ,@c_PackKey             NVARCHAR(10) 
   -- Generate T-SQL
    
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      
      SELECT @c_Packkey = PackKey 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU 
      
      SELECT @n_CaseCnt = CaseCnt
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PacKKey = @c_PackKey 
      
      IF @n_Qty >= @n_CaseCnt 
      BEGIN 
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: Qty >= CaseCnt'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
--      
--      
--      SELECT @c_PutawayZoneCategory = ISNULL(PZ.ZoneCategory,'')
--      FROM dbo.Loc Loc WITH (NOLOCK) 
--      INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.PutawayZone
--      WHERE Loc.Loc = @c_ToLoc
--
--      SELECT @c_Facility = Facility 
--      FROM dbo.Loc WITH (NOLOCK) 
--      WHERE Loc = @c_FromLoc
--      
--      SELECT @n_MinQty = MIN(LLI.Qty) 
--      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc
--      INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.PutawayZone
--      WHERE LLI.StorerKey = @c_StorerKey
--      AND LLI.SKU = @c_SKU 
--      AND LOC.Facility = @c_Facility
--      AND PZ.ZoneCategory = 'VF'
--      AND LLI.Qty > 0 
--
--      SELECT @n_LocQty = LLI.Qty
--      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc
--      INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.PutawayZone
--      WHERE LLI.StorerKey = @c_StorerKey
--      AND LLI.SKU = @c_SKU 
--      AND LOC.Facility = @c_Facility
--      AND PZ.ZoneCategory = 'VF'
--      AND LLI.Qty > 0 
--      AND LLI.Loc = @c_ToLoc
--
--      
--      
--
--      IF @c_PutawayZoneCategory <> 'VF'
--      BEGIN
--         IF @b_debug = 1
--         BEGIN
--            SELECT @c_Reason = 'FAILED PutCode: Putaway ZoneCategory <> VF'
--            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
--         END
--         SET @b_RestrictionsPassed = 0 --False
--      END
--
--      IF @n_LocQty > @n_MinQty 
--      BEGIN
--         IF @b_debug = 1
--         BEGIN
--            SELECT @c_Reason = 'FAILED PutCode: Putaway Loc Not In Minimum Qty'
--            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
--         END
--         SET @b_RestrictionsPassed = 0 --False
--      END
 
   END
END


GO