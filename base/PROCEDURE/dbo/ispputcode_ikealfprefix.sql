SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode_IKEALFPrefix                             */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Filter pallet prefix = LF                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-08-08   Ung       1.0   WMS-5414 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode_IKEALFPrefix]
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

   DECLARE @cPrefix  NVARCHAR(2)
   DECLARE @c_Reason NVARCHAR(80)
   DECLARE @c_Notes1 NVARCHAR(10)

   -- Get prefix
   SET @cPrefix = LEFT( @c_ID, 2)
      
   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
         SET @c_SQL = 
            CASE WHEN @cPrefix = 'PL' THEN '' ELSE ' AND (1=0) ' END 
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      IF @cPrefix = 'PL'
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED PutCode: ispPutCode_IKEALFPrefix  Prefix = PL'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_IKEALFPrefix  Prefix = ' + @cPrefix
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
      END
   END
END

GO