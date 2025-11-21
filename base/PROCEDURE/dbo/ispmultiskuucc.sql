SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMultiSKUUCC                                      */
/* Copyright: IDS                                                       */
/* Purpose: Fit by user input pallet size                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-01-10   Ung       1.0   SOS257227 Fit by pallet size            */
/* 2013-08-15   Shong     1.1   Performance Tuning (VF-CDC)             */   
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMultiSKUUCC]
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
            ' WHERE StorerKey = ''' +  @c_StorerKey + '''' +
               ' AND UCC.LOC = ''' +  @c_FromLOC + '''' + 
               ' AND UCC.ID = ''' +  @c_ID + '''' + 
               ' AND UCC.Status = ''1''' + 
            ' GROUP BY UCCNo ' + 
            ' HAVING COUNT( DISTINCT UCC.SKU) > 1) ' -- Multi SKU UCC
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @nMultiSKUUCC INT
      SET @nMultiSKUUCC = 0
      
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
            SELECT @c_Reason = 'FAILED PutCode: MultiSKUUCC  from LOC = IND/PTL1001'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @nMultiSKUUCC > 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: MultiSKUUCC  Multi SKU UCC count = ' + CAST( @nMultiSKUUCC AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: MultiSKUUCC  Multi SKU UCC count = ' + CAST( @nMultiSKUUCC AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO