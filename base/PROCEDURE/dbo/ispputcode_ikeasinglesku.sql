SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode_IKEASingleSKU                            */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Filter IKEA single SKU pallet                               */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-08-08   Ung       1.0   WMS-5414 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode_IKEASingleSKU]
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
            ' AND EXISTS ' + 
            ' (SELECT 1 ' + 
            ' FROM dbo.LOTxLOCxID WITH (NOLOCK) ' + 
            ' WHERE StorerKey = ''' + @c_StorerKey + '''' + 
               ' AND LOC = ''' +  @c_FromLOC + '''' + 
               ' AND ID = ''' +  @c_ID + '''' + 
               ' AND QTY > 0 ' + 
            ' HAVING COUNT( DISTINCT SKU) = 1) '
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @nSKUCount INT
      SET @nSKUCount = 0

      -- Get SKU count on pallet
      SELECT @nSKUCount = COUNT( DISTINCT SKU)
      FROM dbo.LOTxLOCxID WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
         AND LOC = @c_FromLOC
         AND ID = @c_ID
         AND QTY > 0
            
      IF @nSKUCount > 1
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_IKEASingleSKU  SKU count = ' + CAST( @nSKUCount AS NVARCHAR(5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
      ELSE IF @nSKUCount = 1
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispPutCode_IKEASingleSKU  SKU count = ' + CAST( @nSKUCount AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_IKEASingleSKU  SKU count = ' + CAST( @nSKUCount AS NVARCHAR( 5))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO