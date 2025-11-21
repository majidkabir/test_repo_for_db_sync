SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispAftStyleLastLOC                                  */
/* Copyright: IDS                                                       */
/* Purpose: Location after same SKU style                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-02-28   Ung       1.0   SOS257227 Created                       */
/* 2019-12-10   Chermaine 1.1   WMS-11424 Add Location 'VFECCDSTG'(cc01)*/
/* 2020-01-14   Chermaine 1.2   WMS-11746 Add CODELKUP PutawayLoc (cc02)*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispAftStyleLastLOC]
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

   DECLARE @c_Reason      NVARCHAR(80)
   DECLARE @cStyle        NVARCHAR( 20)
   DECLARE @cSKUZone      NVARCHAR( 10)
   DECLARE @cStyleLastLOC NVARCHAR( 10)
   DECLARE @nPutawayLoc   INT
   
   SET @nPutawayLoc = 0
   -- check loc list --(cc02)
   IF EXISTS (SELECT TOP 1 1 FROM CODELKUP (NOLOCK) WHERE storerKey = @c_StorerKey AND LISTNAME = 'PutawayLoc' AND code = @c_FromLOC)
   BEGIN
   	SET @nPutawayLoc = 1
   END
   
   -- Get style
   SET @cStyle = ''
   SET @cSKUZone = ''
   SELECT 
      @cStyle = Style, 
      @cSKUZone = PutawayZone
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey 
      AND SKU = @c_SKU

   -- Get Max location of SKU style
   SELECT @cStyleLastLOC = ISNULL( MAX( LOC.LOC), '')
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE SKU.StorerKey = @c_StorerKey
      AND SKU.Style = @cStyle
      AND LOC.PutawayZone = @cSKUZone
      AND LOC.LocationType = 'DYNPPICK'
      AND ((LLI.QTY > 0) OR (LLI.PendingMoveIn > 0))         

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = 
            --CASE WHEN @c_FromLOC NOT IN ('IND1001', 'PTL1001','VFECCDSTG') THEN ' AND (1=0) '  --(cc01)
            CASE WHEN @nPutawayLoc = 0 THEN ' AND (1=0) '  --(cc02)
                 WHEN @cStyle = '' THEN ' AND (1=0) ' 
                 ELSE ' AND LOC.LOC > ''' + @cStyleLastLOC + ''''
            END + 
            -- LOC is not assign with any SKU
            ' AND NOT EXISTS( SELECT TOP 1 1 ' + 
               ' FROM SKUxLOC WITH (NOLOCK) ' + 
               ' WHERE StorerKey = ''' + @c_StorerKey + '''' + 
                  ' AND SKUxLOC.LOC = LOC.LOC ' + 
                  ' AND LocationType IN (''CASE'', ''PICK'')) ' 
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      -- Check FromLOC
      --IF @c_FromLOC NOT IN ('IND1001', 'PTL1001','VFECCDSTG') --(cc01)
      IF @nPutawayLoc = 0 --(cc01)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: AftStyleLastLOC  from LOC <> IND/PTL1001' + RTRIM( @cStyleLastLOC) + ' From LOC = ' + RTRIM( @c_FromLOC)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      
      -- Check Style
      IF @cStyle = ''
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: AftStyleLastLOC  SKU = ' + RTRIM( @c_SKU) + ' Style = ' + RTRIM( @cStyle)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      
      -- Check LOC assigned SKU
      DECLARE @cAssignedSKU NVARCHAR(20)
      SET @cAssignedSKU = ''
      SELECT TOP 1 @cAssignedSKU = SKU
      FROM SKUxLOC WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
         AND LOC = @c_ToLoc
         AND LocationType IN ('PICK', 'CASE')
      IF @cAssignedSKU <> ''
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: AftStyleLastLOC  Pick face assigned SKU = ' + RTRIM( @c_SKU)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      
      -- Check after style last LOC
      IF @c_ToLoc > @cStyleLastLOC
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: AftStyleLastLOC  Style last loc = ' + RTRIM( @cStyleLastLOC) + ' Style = ' + RTRIM( @cStyle)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         RETURN
      END

      -- Check unknown error
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: AftStyleLastLOC  Style last loc = ' + RTRIM( @cStyleLastLOC) + ' Style = ' + RTRIM( @cStyle)
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
   END
END

GO