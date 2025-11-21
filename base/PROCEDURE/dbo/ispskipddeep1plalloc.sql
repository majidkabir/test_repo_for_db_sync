SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispSkipDDeep1PLAlloc                                */
/* Copyright: IDS                                                       */
/* Purpose: Exclude double deep loc with 1 PL alloc and 1 pallet free   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-10-02   Ung       1.0   SOS321584 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSkipDDeep1PLAlloc]
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
            ' AND NOT EXISTS ' + 
               ' (SELECT 1 ' + 
               ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
               ' WHERE LLI.LOC = LOC.LOC ' + 
                  ' AND LLI.QTYAllocated > 0 ' + 
               ' HAVING COUNT( DISTINCT ID) = 1 ' + 
                  ' AND LOC.MaxPallet = 2) '
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @nIDCount INT
      DECLARE @nMaxPallet INT
      SET @nIDCount = 0
      SET @nMaxPallet = 0

      -- Get LOC info
      SELECT @nMaxPallet = MaxPallet FROM LOC WITH (NOLOCK) WHERE LOC = @c_FromLOC
      
      -- Get allocated pallet count, for double deep
      IF @nMaxPallet = 2
         SELECT @nIDCount = COUNT( DISTINCT ID)
         FROM dbo.LOTxLOCxID WITH (NOLOCK) 
         WHERE LOC = @c_ToLoc
            AND QTYAllocated > 0
            
      IF @nMaxPallet = 2 AND @nIDCount = 1
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SkipDDeep1PLAlloc  MaxPallet=' + CAST( @nMaxPallet AS NVARCHAR(5)) + ' IDCnt=' +  CAST( @nIDCount AS NVARCHAR(5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: SkipDDeep1PLAlloc  MaxPallet=' + CAST( @nMaxPallet AS NVARCHAR(5)) + ' IDCnt=' +  CAST( @nIDCount AS NVARCHAR(5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
   END
END

GO