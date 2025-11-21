SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtVal08                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check if pallet id to move has pendingmovein task                 */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2020-10-23  1.0  James    WMS-15449 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtVal08]
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

   DECLARE @nPendingMoveIn    INT
   
   IF @nFunc = 513 -- Move by SKU
   BEGIN
      IF @nStep = 2 -- From ID
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'DisallowMoveWithPMV', @cStorerKey) = '1'
            BEGIN
               SELECT @nPendingMoveIn = ISNULL( SUM( LLI.PendingMoveIN), 0)
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.Id = @cFromID
               AND   LOC.Facility = @cFacility

               IF @nPendingMoveIn > 0
               BEGIN
                  SET @nErrNo = 160151
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --IDHas PendMvIn
                  GOTO Quit  
               END
            END
         END
      END
   END
   
   Quit:
END

GO