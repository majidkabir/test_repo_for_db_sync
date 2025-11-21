SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_511ExtValid04                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: UA custom move check                                              */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 26-03-2020  1.0  Ung      WMS-12635 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_511ExtValid04] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 18),    
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ''
               ,@cFromLOC 
               ,@cToLOC 
               ,'M' -- Type
               ,''  -- SwapLOT
               ,''  -- ChkQuality
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
         END
      END
   END

GO