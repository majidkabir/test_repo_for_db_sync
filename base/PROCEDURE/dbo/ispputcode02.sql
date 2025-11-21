SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode02                                        */
/* Copyright: LF Logistic                                               */
/* Purpose: SKU Putaway                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-08-22   ChewKP    1.0   WMS-2694 Created.                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode02]
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
   DECLARE @cLOC     NVARCHAR(10)
          ,@cDPPLoc  NVARCHAR(10) 
   
   SELECT @cDPPLoc = Data
   FROM dbo.SKUConfig WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_SKU
   AND ConfigType = 'DefaultDPP'
   
   

   
   IF ISNULL(@cDPPLoc,'')  = ''  
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: ispPutCode02  SKUConfig Not Setup'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
   END
   
   IF @cDPPLoc <> @c_ToLoc
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: ispPutCode02  Does not match SKUConfig Setup'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
   END
   

QUIT:
--SELECT  @c_ToLoc '@c_ToLoc', @b_RestrictionsPassed '@b_RestrictionsPassed'  -- TESTING
END

GO