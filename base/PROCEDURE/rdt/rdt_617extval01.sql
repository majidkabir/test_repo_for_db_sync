SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_617ExtVal01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check commingle SKU                                               */
/*                                                                            */
/* Date       Ver  Author     Purposes                                        */
/* 2022-01-03 1.0  Ung        WMS-18656 created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_617ExtVal01]
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

   -- Move to LOC
   IF @nFunc = 617
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            DECLARE @cFrLOCCat      NVARCHAR(10)
            DECLARE @cFrStatus      NVARCHAR(10)
            DECLARE @cFrPutawayZone NVARCHAR(10)
            DECLARE @cToLOCCat      NVARCHAR(10)
            DECLARE @cToStatus      NVARCHAR(10)
            DECLARE @cToPutawayZone NVARCHAR(10)

            SELECT @cFrStatus = STATUS, @cFrPutawayZone = Putawayzone, @cFrLOCCat = locationcategory FROM Loc WITH (NOLOCK) WHERE LOC = @cFromLOC
            SELECT @cToStatus = STATUS, @cToPutawayZone = Putawayzone, @cToLOCCat = locationcategory FROM Loc WITH (NOLOCK) WHERE LOC = @cToLOC

            IF @cFrPutawayZone <> @cToPutawayZone
            BEGIN
               SET @nErrNo = 180501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff PAZone
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO