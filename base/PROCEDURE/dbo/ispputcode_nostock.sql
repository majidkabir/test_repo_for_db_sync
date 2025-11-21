SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode_NoStock                                  */
/* Copyright: IDS                                                       */
/* Purpose: Location after same SKU style                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-02-07   Ung       1.0   WMS-1025 Created                        */
/* 2018-05-23   LZG       1.1   INC0237427 - Caters for both EXceed &   */
/*                              RDT (ZG01)                              */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode_NoStock]
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
   DECLARE @cStock NVARCHAR(1)
   DECLARE @cFacility NVARCHAR( 5)
   --SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
   SELECT @cFacility = Facility FROM Loc WITH (NOLOCK) WHERE Loc = @c_FromLoc                         -- ZG01
   
   IF EXISTS( SELECT 1 
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.StorerKey = @c_StorerKey
         AND LLI.SKU = @c_SKU
         AND LLI.QTY - LLI.QTYPicked > 0
         AND LOC.LocationType <> 'RCVG'
         AND LOC.LocationType <> 'RETURN')
      SET @cStock = 'Y'
   ELSE
      SET @cStock = 'N'

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
      BEGIN
         IF @cStock = 'Y'
            SET @c_SQL = ' AND (1=0) '
      END
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @cStock = 'N'
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispPutCode_NoStock. No stock '
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 1 --True
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_NoStock. Have stock '
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO