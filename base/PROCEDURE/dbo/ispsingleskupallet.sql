SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispSingleSKUPallet                                  */
/* Copyright: IDS                                                       */
/* Purpose: Fit by user input pallet size                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-11-28   Ung       1.0   SOS257227 Fit by pallet size            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispSingleSKUPallet]
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
   DECLARE @c_Notes1 NVARCHAR(10)

   -- Get SKU notes1
   SET @c_Notes1 = ''
   SELECT TOP 1 
      @c_Notes1 = 'ODDSIZE'
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
   WHERE LLI.LOC = @c_FromLOC
      AND LLI.ID = @c_ID
      AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE'
      
   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = 
            CASE WHEN @c_FromLOC IN ('IND1001', 'PTL1001') THEN ' AND (1=0) ' END + 
            CASE WHEN @c_Notes1 = 'ODDSIZE' THEN ' AND (1=0) ' END +  
            ' AND EXISTS ' + 
            ' (SELECT 1 ' + 
            ' FROM dbo.UCC WITH (NOLOCK) ' + 
            ' WHERE StorerKey = ''' + @c_StorerKey + '''' + 
               ' AND LOC = ''' +  @c_FromLOC + '''' + 
               ' AND ID = ''' +  @c_ID + '''' + 
               ' AND Status = ''1'' ' + 
            ' HAVING COUNT( DISTINCT SKU) = 1 ' + 
               ' AND COUNT( DISTINCT QTY) = 1) '
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @nSKUCount INT
      DECLARE @nQTYCount INT
      SET @nSKUCount = 0
      SET @nQTYCount = 0

      -- Get SKU, QTY count on pallet
      SELECT 
         @nSKUCount = COUNT( DISTINCT SKU), 
         @nQTYCount = COUNT( DISTINCT QTY)
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
         AND LOC = @c_FromLOC
         AND ID = @c_ID
         AND Status = '1'
            
      IF @c_FromLOC IN ('IND1001', 'PTL1001')
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SingleSKUPallet  from LOC = IND/PTL1001'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @c_Notes1 = 'ODDSIZE'
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SingleSKUPallet  SKU.Notes1 = ODDSIZE'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @nSKUCount <> 1 OR @nQTYCount <> 1
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SingleSKUPallet  SKU count = ' + CAST( @nSKUCount AS NVARCHAR( 5)) + ' QTY count = ' + CAST( @nQTYCount AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @nSKUCount = 1 AND @nQTYCount = 1
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: SingleSKUPallet  SKU count = ' + CAST( @nSKUCount AS NVARCHAR( 5)) + ' QTY count = ' + CAST( @nQTYCount AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: SingleSKUPallet  SKU count = ' + CAST( @nSKUCount AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO