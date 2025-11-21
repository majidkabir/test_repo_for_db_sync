SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispSKUMinQTYLOC                                     */
/* Copyright: LF Logistic                                               */
/* Purpose: SKU MIN QTY LOC                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-04-17   Ung       1.0   SOS309951 Min QTY LOC                   */
/* 2015-05-11   ChewKP    1.1   SOS#340776 - Order By Loc (ChewKP01)    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSKUMinQTYLOC]
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
   DECLARE @cLOC     NVARCHAR(10)
   DECLARE @cZone    NVARCHAR(10)
   
   SET @cLOC = ''
   SET @cZone = ''
   
   -- Get Zone
   SELECT @cZone = Zone 
   FROM PutawayStrategyDetail WITH (NOLOCK) 
   WHERE PutawayStrategyKey = @c_PutawayStrategyKey
      AND PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber

   -- Get SKU MIN QTY LOC
   IF @cZone <> ''
      SELECT TOP 1 
         @cLOC = LOC.LOC
      FROM dbo.SKUxLOC SL WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @c_StorerKey
         AND SL.SKU = @c_SKU
         AND (SL.QTY - SL.QTYPicked) > 0
         AND LOC.PutawayZone = @cZone
         AND Loc.Loc <> @c_FromLoc
         AND LOC.LocationFlag <> 'HOLD'
      --ORDER BY QTY - QTYPicked
      ORDER BY LOC.Loc -- (ChewKP02)
      
   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = ' AND LOC.LOC = ''' +  @cLOC + ''''
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @cLOC = ''
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispSKUMinQTYLOC  MIN QTY LOC not found'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cLOC <> @c_ToLOC
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispSKUMinQTYLOC  LOC not match. MIN QTY LOC = ' + @cLOC
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cLOC = @c_ToLOC
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispSKUMinQTYLOC  LOC matched. MIN QTY LOC = ' + @cLOC
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispSKUMinQTYLOC  Unknown error. MIN QTY LOC = ' + @cLOC
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO