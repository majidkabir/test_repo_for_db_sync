SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770CustLOT01                                   */
/* Purpose: Custom display lottables                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-08-04   Ung       1.0   SOS311415 Created                       */
/* 2014-10-08   Ung       1.1   SOS322481 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770CustLOT01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cLottable01     NVARCHAR( 18) OUTPUT 
   ,@cLottable02     NVARCHAR( 18) OUTPUT
   ,@cLottable03     NVARCHAR( 18) OUTPUT 
   ,@dLottable04     DATETIME      OUTPUT 
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      -- Get TaskDetail info
      SELECT
         @cLottable01 = Message01, 
         @cLottable02 = Message02, 
         @cLottable03 = Message03
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   END
END

GO