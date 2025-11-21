SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtValSP01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check commingle SKU                                               */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2015-08-13   Ung       1.0   SOS361506 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtValSP01]
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
            DECLARE @cCommingleSKU NVARCHAR(1)
            SELECT @cCommingleSKU = CommingleSKU FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC

            -- Not allow commingle SKU
            IF @cCommingleSKU = '0'
            BEGIN
               -- Check inventory balance (actual stock and booking)
               IF EXISTS( SELECT 1
                  FROM LOTxLOCxID WITH (NOLOCK)
                  WHERE LOC = @cToLOC
                     AND (QTY-QTYPicked > 0 OR PendingMoveIN > 0)
                     AND (StorerKey <> @cStorerKey OR SKU <> @cSKU))
               BEGIN
                  SET @nErrNo = 95901
                  SET @cErrMsg = rdt.rdtgetmessage( 60602, @cLangCode, 'DSP') --Loc CantMixSKU
               END

               -- Check RFPutaway booking
               IF EXISTS( SELECT 1
                  FROM RFPutaway WITH (NOLOCK)
                  WHERE SuggestedLOC = @cToLOC
                     AND (StorerKey <> @cStorerKey OR SKU <> @cSKU))
               BEGIN
                  SET @nErrNo = 95902
                  SET @cErrMsg = rdt.rdtgetmessage( 60602, @cLangCode, 'DSP') --Loc CantMixSKU
               END
            END
         END
      END
   END
END
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513ExtValSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_513ExtValSP01

GO