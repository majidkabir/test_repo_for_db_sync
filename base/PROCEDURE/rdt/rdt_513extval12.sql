SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_513ExtVal12                                     */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-10-22 1.0  Vikas      UWP-26273 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513ExtVal12] (
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
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF


IF @nFunc = 513 -- Move by SKU
BEGIN
   IF @nStep = 5 -- TO ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS( SELECT TOP 1 1
               FROM dbo.LOTXLOCXID WITH (NOLOCK)
               WHERE ID = @cToID
                  AND StorerKey = @cStorerKey 
                  AND (QTY > 0 OR PendingMoveIN > 0)
              )
         BEGIN
            SET @nErrNo = 227801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToID in used
            GOTO Quit
         END
      END
   END
END

Quit:

GO