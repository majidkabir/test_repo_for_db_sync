SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPutCode_SamePAZone                               */  
/* Copyright: IDS                                                       */  
/* Purpose: Location after same SKU style                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2019-09-03   Ung       1.0   WMS-10056 Created                       */  
/* 2020-05-22   Shong     1.1   Bug Fixed (SWT01)                       */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPutCode_SamePAZone]  
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
  
   DECLARE @c_Reason NVARCHAR( 80)  
  
   DECLARE @cFromPAZone NVARCHAR( 10)  
   SELECT @cFromPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @c_FromLOC  
     
   -- Generate T-SQL  
   IF @c_ToLoc = ''  
   BEGIN  
      IF @b_debug = 1  
         -- Putaway trace turn on, LOC is not pre-filter out  
         SET @c_SQL = ''   
      ELSE  
         SET @c_SQL = ' AND LOC.PutawayZone = ''' + @cFromPAZone + ''''  -- SWT01
      RETURN  
   END  
     
   -- Restriction test  
   IF @c_ToLoc <> ''  
   BEGIN  
      DECLARE @cToPAZone NVARCHAR( 10)  
      SELECT @cToPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLOC  
  
      IF @cFromPAZone = @cToPAZone  
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            SELECT @c_Reason = 'PASSED PutCode: ispPutCode_SamePAZone. PAZone = ' + @cToPAZone  
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason  
         END  
      END  
      ELSE  
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_SamePAZone. FromZone = ' + @cToPAZone + ' ToZone = ' + @cToPAZone  
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason  
         END  
         SET @b_RestrictionsPassed = 0 --False  
      END  
   END  
END  

GO