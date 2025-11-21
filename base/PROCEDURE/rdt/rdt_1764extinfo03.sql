SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo03                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-10-19   Ung       1.0   WMS-3258 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtInfo03]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTY   INT
   DECLARE @cUCCNo NVARCHAR(20)

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 5 -- NEXT TASK / CLOSE PALLET
      BEGIN
         -- Get UCC on task not yet pick
         DECLARE @cToLOC NVARCHAR(10)
         DECLARE @cFinalLOC NVARCHAR(10)
         SELECT 
            @cToLOC = ToLOC, 
            @cFinalLOC = FinalLoC
         FROM TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@ROWCOUNT = 1
            SET @cExtendedInfo1 = 'FINALLOC: ' + CASE WHEN @cFinalLOC <> '' THEN @cFinalLOC ELSE @cToLOC END
      END
   END
END

GO