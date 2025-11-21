SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispGetPNDLOC                                        */
/* Copyright: LF Logistics                                              */
/* Purpose: Find PND loc assign for the aisle                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-07-07   Ung       1.0   SOS346284 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetPNDLOC]
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

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = ''
      ELSE
         SET @c_SQL = 
            ' AND LOC.LOCAisle <> '''' ' +
              -- Get PND location
            ' AND EXISTS ' +
            '    (SELECT 1 ' +
            '    FROM dbo.CodeLKUP C WITH (NOLOCK) ' +
            '    WHERE C.ListName = ''PND'' ' +
            '       AND C.StorerKey = N' + QUOTENAME( @c_StorerKey, '''') +
            '       AND C.Code2 = LOC.LOCAisle ' +
                    -- Check max pallet
            '       AND EXISTS( ' +
            '          SELECT 1 ' +
            '          FROM LOC LOC_PND WITH (NOLOCK) ' +
            '             LEFT JOIN LOTxLOCxID LLI_PND WITH (NOLOCK) ON (' +
            '                LLI_PND.LOC = LOC_PND.LOC AND ' +
            '                LLI_PND.ID <> '''' AND ' +
            '                (LLI_PND.QTY > 0 OR LLI_PND.PendingMoveIn > 0)) ' +
            '          WHERE LOC_PND.LOC = C.Code ' +
            '          GROUP BY LOC_PND.MaxPallet ' +
            '          HAVING (COUNT( DISTINCT LLI_PND.ID) < LOC_PND.MaxPallet) OR LOC_PND.MaxPallet = 0))'
      RETURN
   END

   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @cLOCAisle  NVARCHAR(10)
      DECLARE @cPNDLOC    NVARCHAR(10)
      DECLARE @nMaxPallet INT
      DECLARE @nPalletCNT INT

      -- Get LOC aisle
      SELECT @cLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc

      -- Get PND
      SET @cPNDLOC = ''
      SELECT TOP 1 @cPNDLOC = Code
      FROM dbo.CodeLKUP C WITH (NOLOCK)
      WHERE C.ListName = 'PND'
         AND C.StorerKey = @c_StorerKey
         AND C.Code2 = @cLOCAisle

      -- Get max pallet
      SELECT @nMaxPallet = MaxPallet FROM LOC WITH (NOLOCK) WHERE LOC = @cPNDLOC

      -- Check max pallet
      IF @nMaxPallet > 0
      BEGIN
         SELECT @nPalletCNT = COUNT( DISTINCT LLI_PND.ID)
         FROM LOC LOC_PND WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI_PND WITH (NOLOCK) ON (
               LLI_PND.LOC = LOC_PND.LOC AND
               LLI_PND.ID <> '' AND
               (LLI_PND.QTY > 0 OR LLI_PND.PendingMoveIn > 0))
         WHERE LOC_PND.LOC = @cPNDLOC
      END
      ELSE
         SET @nPalletCNT = 0

      IF @cLOCAisle = ''
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispGetPNDLOC  LOCAisle = blank'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @cPNDLOC = ''
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispGetPNDLOC  CodeLKUP PND not setup for LOCAisle=' + @cLOCAisle
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @nMaxPallet > 0 AND @nPalletCNT >= @nMaxPallet
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispGetPNDLOC  Exceeded MaxPallet=' + CAST( @nMaxPallet AS NVARCHAR( 5)) + ' Pallet count=' + CAST( @nPalletCNT AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispGetPNDLOC  MaxPallet=' + CAST( @nMaxPallet AS NVARCHAR( 5)) + ' Pallet count=' + CAST( @nPalletCNT AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
   END
END

GO