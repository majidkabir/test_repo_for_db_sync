SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispCheckLocMaxCarton                                */
/*                                                                      */
/* Purpose: Filter Loc.MaxCarton                                        */
/*                                                                      */
/* Called from: nspRDTPASTD                                             */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-09   1.0  James    WMS-12060. Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispCheckLocMaxCarton]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey                 NVARCHAR(15)
   ,@c_SKU                       NVARCHAR(20)
   ,@c_LOT                       NVARCHAR(10)
   ,@c_FromLoc                   NVARCHAR(10)
   ,@c_ID                        NVARCHAR(18)
   ,@n_Qty                       INT     
   ,@c_ToLoc                     NVARCHAR(10)
   ,@c_Param1                    NVARCHAR(20)
   ,@c_Param2                    NVARCHAR(20)
   ,@c_Param3                    NVARCHAR(20)
   ,@c_Param4                    NVARCHAR(20)
   ,@c_Param5                    NVARCHAR(20)
   ,@b_debug                     INT
   ,@c_SQL                       VARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed        INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Func      INT
   DECLARE @cPA_Type    NVARCHAR( 10)
   
   SELECT @n_Func = Func
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()
   
   SELECT @cPA_Type = PAType
   FROM dbo.PutawayStrategyDetail WITH (NOLOCK)
   WHERE PutawayStrategyKey = @c_PutawayStrategyKey
   AND   PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber

   SET @b_debug = 0
   
   IF @n_Func <> 521
      GOTO Quit

   
   IF @cPA_Type = '18'
      SET @c_SQL =
   ' AND ( SELECT COUNT( DISTINCT UCC.UCCNo) + 1' +
   '       FROM dbo.UCC UCC WITH (NOLOCK)  ' +
   '       WHERE LOTxLOCxID.Loc = UCC.Loc ' +
   '       AND  (LOTxLOCxID.QTY > 0 OR LOTxLOCxID.PendingMoveIN > 0)) <= LOC.MaxCarton  ' 
   ELSE   
      IF @cPA_Type = '19'
         SET @c_SQL =
      ' AND ( SELECT COUNT( DISTINCT UCC.UCCNo) + 1' +
      '       FROM dbo.UCC UCC WITH (NOLOCK)  ' +
      '       WHERE Loc.Loc = UCC.Loc) <= LOC.MaxCarton ' 
      ELSE
         SET @c_SQL = ''

   RETURN
                
      
   Quit:

END


GO