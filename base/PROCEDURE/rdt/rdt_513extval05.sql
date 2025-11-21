SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtVal05                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check commingle SKU                                               */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-11-30   Ung       1.0   WMS-6467 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtVal05]
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

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            DECLARE @cLOCCat NVARCHAR(10)
            SELECT @cLOCCat = LocationCategory FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

            -- Receiving stage
            IF @cLOCCat = 'STAGING'
            BEGIN
               -- Check RFPutaway booking
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM RFPutaway WITH (NOLOCK)
                  WHERE FromLOC = @cFromLOC
                     AND StorerKey = @cStorerKey 
                     AND SKU = @cSKU
                     AND SuggestedLOC = @cToLOC)
               BEGIN
                  SET @nErrNo = 132701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
               END
            END
         END
      END
   END
END
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513ExtVal05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_513ExtVal05

GO