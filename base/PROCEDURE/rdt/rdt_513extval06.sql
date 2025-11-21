SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtVal06                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: UA custom move check                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 26-03-2020  1.0  Ung      WMS-12636 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtVal06]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 513 -- Move by SKU
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
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
END

GO