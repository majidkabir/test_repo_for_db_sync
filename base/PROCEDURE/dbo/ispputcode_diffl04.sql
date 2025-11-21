SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode_DiffL04                                  */
/* Copyright: IDS                                                       */
/* Purpose: Location after same SKU style                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-02-07   Ung       1.0   WMS-1025 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode_DiffL04]
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
   DECLARE @dLottable04 DATETIME
   DECLARE @cPutawayZone NVARCHAR(10)
   DECLARE @cLOC NVARCHAR(10)
   
   -- Get current L04
   SELECT TOP 1 
      @dLottable04 = LA.Lottable04
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LLI.LOC = @c_FromLOC
      AND LLI.ID = @c_ID
      AND LLI.StorerKey = @c_StorerKey
      AND LLI.SKU = @c_SKU
      AND LLI.QTY - LLI.QTYPicked > 0
   
   -- Get putaway strategy info
   SELECT @cPutawayZone = Zone
   FROM PutawayStrategyDetail WITH (NOLOCK)
   WHERE PutawayStrategyKey = @c_PutawayStrategyKey
      AND PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber
   
   -- Get SKU info
   DECLARE @n_PalletWoodHeight FLOAT
   DECLARE @n_CaseHeight FLOAT
   DECLARE @n_PutawayHI INT
   SELECT 
      @n_PalletWoodHeight = PACK.PalletWoodHeight, 
      @n_CaseHeight       = PACK.HeightUOM1,
      @n_PutawayHI        = PACK.PalletHI
   FROM SKU WITH (NOLOCK)
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @c_StorerKey
      AND SKU.SKU = @c_SKU
   
   -- Get lowest L04 within zone
   SELECT TOP 1 
      @cLOC = LOC.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
   WHERE LOC.PutawayZone = @cPutawayZone
      AND LLI.StorerKey = @c_StorerKey
      AND LLI.SKU = @c_SKU
      AND LLI.QTY - LLI.QTYPicked > 0
      AND LA.Lottable04 <> @dLottable04
      AND LOC.CommingleLOT = 1
      AND LOC.LocationType <> 'CASE'
      AND LOC.LocationType <> 'PICK'
      AND LOC.LocationFlag <> 'DAMAGE'
      AND LOC.LocationFlag <> 'HOLD'
      AND (LOC.MaxPallet = 0 OR LOC.MaxPallet > 
          (SELECT COUNT( DISTINCT LLI2.ID) 
          FROM LOTxLOCxID LLI2 WITH (NOLOCK) 
          WHERE LLI2.LOC = LLI.LOC
            AND LLI2.QTY - LLI2.QTYPicked > 0))
   ORDER BY LA.Lottable04, LOC.PALogicalLOC, LOC.LOC
   
   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = ' AND LOC.LOC = ''' + @cLOC + ''''
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @c_ToLoc = @cLOC
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispPutCode_DiffL04. SuggestedLOC = ' + @cLOC
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_DiffL04. SuggestedLOC = ' + @cLOC
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO