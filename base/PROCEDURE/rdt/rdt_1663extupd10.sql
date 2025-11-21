SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd10                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: only for ECOM order, 1 order 1 carton                             */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-08-09 1.0  Ung      WMS-20200 Base on rdt_1663ExtUpd06                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtUpd10](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20),
   @cPalletLOC    NVARCHAR( 10),
   @cMBOLKey      NVARCHAR( 10),
   @cTrackNo      NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @cShipperKey   NVARCHAR( 15),
   @cCartonType   NVARCHAR( 10),
   @cWeight       NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1663ExtUpd10 -- For rollback or commit only our own transaction

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 6 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = 1 -- YES
            BEGIN
               IF rdt.rdtGetConfig( @nFunc, 'MoveCarton', @cStorerKey) = '1'
               BEGIN
                  DECLARE @cFromLOT       NVARCHAR(10)
                  DECLARE @cFromLOC       NVARCHAR(10)
                  DECLARE @cFromID        NVARCHAR(18)
                  DECLARE @cSKU           NVARCHAR(20)
                  DECLARE @nQTY           INT
                  DECLARE @cCaseID        NVARCHAR(20)

                  DECLARE @curPL CURSOR
                  DECLARE @curPD CURSOR

                  -- Loop pallet detail
                  SET @curPL = CURSOR FOR
                     SELECT CaseID
                     FROM PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND PalletKey = @cPalletKey
                     ORDER BY PalletLineNumber
                  OPEN @curPL
                  FETCH NEXT FROM @curPL INTO @cCaseID
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Get Order
                     SELECT @cOrderKey = OrderKey
                     FROM Orders WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND TrackingNo = @cCaseID

                     -- Move carton
                     SET @curPD = CURSOR FOR
                        SELECT LOT, LOC, ID, SKU, SUM( QTY)
                        FROM PickDetail WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                           AND Status = '5'
                           AND QTY > 0
                           AND (LOC <> @cPalletLOC OR ID <> @cPalletKey) -- Change LOC / ID
                        GROUP BY LOT, LOC, ID, SKU
                     OPEN @curPD
                     FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- EXEC move
                        EXECUTE rdt.rdt_Move
                           @nMobile     = @nMobile,
                           @cLangCode   = @cLangCode,
                           @nErrNo      = @nErrNo  OUTPUT,
                           @cErrMsg     = @cErrMsg OUTPUT,
                           @cSourceType = 'rdt_1663ExtUpd10',
                           @cStorerKey  = @cStorerKey,
                           @cFacility   = @cFacility,
                           @cFromLOC    = @cFromLOC,
                           @cToLOC      = @cPalletLOC,
                           @cFromID     = @cFromID,
                           @cToID       = @cPalletKey,
                           @cFromLOT    = @cFromLOT,
                           @cSKU        = @cSKU,
                           @nQTY        = @nQTY,
                           @nQTYAlloc   = 0,
                           @nQTYPick    = @nQTY,
                           @nFunc       = @nFunc, 
                           @cOrderKey   = @cOrderKey
                        IF @nErrNo <> 0
                           GOTO RollbackTran

                        FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
                     END

                     FETCH NEXT FROM @curPL INTO @cCaseID
                  END

                  COMMIT TRAN rdt_1663ExtUpd10
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1663ExtUpd10
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO