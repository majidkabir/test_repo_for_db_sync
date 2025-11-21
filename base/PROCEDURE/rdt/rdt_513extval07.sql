SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtVal07                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check commingle SKU                                               */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2020-08-27   Chermaine 1.0   WMS-14688 Created                             */
/* 2021-01-27   James     1.1   WMS-16185 Add To Loc check (james01)          */
/* 2022-10-13   YeeKung   1.2   WMS-20987 Add To Loc check (yeekung01)        */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_513ExtVal07]
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

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
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

            IF @cFrPutawayZone <>'CRWZONE'
            BEGIN
               -- (james01)
               IF @cFrStatus = 'OK' AND @cFrLOCCat = 'STAGING'
               BEGIN
                  IF @cToStatus <> 'OK' OR @cToLOCCat NOT IN ('MEZZNINE','HB') OR @cFrPutawayZone <> @cToPutawayZone
            	   BEGIN
            		   SET @nErrNo = 158051
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
                     GOTO Quit
            	   END
               END
            END
            ELSE
            BEGIN

               -- Receiving stage
               IF @cFrLOCCat = 'STAGING'
               BEGIN
                  -- Check RFPutaway booking
                  IF NOT EXISTS( SELECT TOP 1 1
                     FROM RFPutaway WITH (NOLOCK)
                     WHERE FromLOC = @cFromLOC
                        AND StorerKey = @cStorerKey 
                        AND SKU = @cSKU
                        AND SuggestedLOC = @cToLOC)
                  BEGIN
                     SET @nErrNo = 158052
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
                     GOTO QUIT
                  END
               END
            END
         END
      END
   END
END

Quit:

GO