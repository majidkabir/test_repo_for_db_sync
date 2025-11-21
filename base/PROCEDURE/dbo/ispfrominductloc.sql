SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispFromInductLOC                                    */
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

CREATE PROCEDURE [dbo].[ispFromInductLOC]
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
   DECLARE @nPutawayLoc   INT
   
   SET @nPutawayLoc = 0
   -- check loc list --(cc02)
   IF EXISTS (SELECT TOP 1 1 FROM CODELKUP (NOLOCK) WHERE storerKey = @c_StorerKey AND LISTNAME = 'PutawayLoc' AND code = @c_FromLOC)
   BEGIN
   	SET @nPutawayLoc = 1
   END

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = 
            --CASE WHEN @c_FromLOC NOT IN ('IND1001', 'PTL1001','VFECCDSTG') THEN ' AND (1=0) ' END --(cc01)
            CASE WHEN @nPutawayLoc = 0 THEN ' AND (1=0) ' END --(cc02)
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      --IF @c_FromLOC IN ('IND1001', 'PTL1001','VFECCDSTG') --(cc01)
      IF @nPutawayLoc = 1 --(cc02)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: FromInductLOC  FromLOC = IND/PTL1001'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: FromInductLOC  FromLOC <> IND/PTL1001'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO