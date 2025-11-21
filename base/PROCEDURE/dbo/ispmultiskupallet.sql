SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMultiSKUPallet                                   */
/* Copyright: IDS                                                       */
/* Purpose: Fit by user input pallet size                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-01-10   Ung       1.0   SOS257227 Fit by pallet size            */
/* 2013-08-15   Shong     1.1   Performance Tuning (VF-CDC)             */   
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMultiSKUPallet]
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
            CASE WHEN @c_FromLOC IN ('IND1001', 'PTL1001') THEN ' AND (1=0) ' END + 
            ' AND EXISTS ' + 
            ' (SELECT 1 ' + 
            ' FROM dbo.UCC WITH (NOLOCK) ' + 
            ' WHERE StorerKey = N''' + @c_StorerKey + '''' +
               ' AND LOC = N''' +  @c_FromLOC + '''' +   
               ' AND ID = N''' +  @c_ID + '''' +   
               ' AND UCC.Status = N''1''' +   
            ' HAVING COUNT( DISTINCT UCC.SKU) > 1 ' + -- Multi SKU on pallet  
               ' OR (COUNT( DISTINCT UCC.SKU) = 1 AND COUNT( DISTINCT QTY) > 1)) ' +  -- Same SKU diff QTY pallet
            ' AND NOT EXISTS ' +   
            ' (SELECT 1 ' +   
            ' FROM dbo.UCC WITH (NOLOCK) ' +   
            ' WHERE UCC.StorerKey = N''' + @c_StorerKey + '''' +
               ' AND UCC.LOC = N''' +  @c_FromLOC + '''' +   
               ' AND UCC.ID = N''' +  @c_ID + '''' +   
               ' AND UCC.Status = N''1''' +   
            ' GROUP BY UCCNo ' +   
            ' HAVING COUNT( DISTINCT UCC.SKU) > 1) ' -- But no multi SKU UCC  
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @nSKUCount INT
      DECLARE @nQTYCount INT
      DECLARE @nMultiSKUUCC INT

      -- Count SKU on pallet
      SET @nSKUCount = 0
      SELECT @nSKUCount = COUNT( DISTINCT SKU)
      FROM dbo.LOTxLOCxID WITH (NOLOCK) 
      WHERE LOC = @c_FromLOC
         AND ID = @c_ID
         AND (QTY - QTYAllocated - QTYPicked) > 0

      -- Count QTY on pallet
      SET @nQTYCount = 0
      SELECT @nQTYCount = COUNT( DISTINCT QTY)
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE Storerkey = @c_StorerKey 
         AND LOC = @c_FromLOC
         AND ID = @c_ID
         AND Status = '1'

      -- Count multi SKU UCC on pallet
      SELECT @nMultiSKUUCC = COUNT( A.UCCNo)
      FROM 
      (
         SELECT UCCNo
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE Storerkey = @c_StorerKey 
            AND LOC = @c_FromLOC
            AND ID = @c_ID
            AND Status = '1'
         GROUP BY UCCNo
         HAVING COUNT( DISTINCT SKU) > 1
      ) A
            
      IF @c_FromLOC IN ('IND1001', 'PTL1001')
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: MultiSKUPallet  from LOC = IND/PTL1001'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF (@nSKUCount > 1 OR                       -- Multi SKU on pallet or
              (@nSKUCount = 1 AND @nQTYCount > 1)) AND -- Same SKU diff QTY pallet and
              @nMultiSKUUCC = 0                        -- Not multi SKU UCC pallet
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: MultiSKUPallet  ' + 
               ' SKUCount=' + CAST( @nSKUCount AS NVARCHAR( 5)) + 
               ' QTYCount=' + CAST( @nQTYCount AS NVARCHAR( 5)) + 
               ' MultiSkuUccCount = ' + CAST( @nMultiSKUUCC AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: MultiSKUPallet  ' + 
               ' SKUCount=' + CAST( @nSKUCount AS NVARCHAR( 5)) + 
               ' QTYCount=' + CAST( @nQTYCount AS NVARCHAR( 5)) + 
               ' MultiSkuUccCount = ' + CAST( @nMultiSKUUCC AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO