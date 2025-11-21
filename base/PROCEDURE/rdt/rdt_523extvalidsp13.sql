SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtValidSP13                                 */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2023-09-08 1.0  yeekung    WMS-22301. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtValidSP13] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cUCC       NVARCHAR( 20)
   DECLARE @cPutawayzone NVARCHAR(20)

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 4
      BEGIN

         SELECT @cPutawayzone =putawayzone 
         FROM SKU (NOLOCK)
         WHERE SKU = @cSKU 
            AND STorerkey = @cStorerKey

         IF  EXISTS ( SELECT 1
                     FROM loc (Nolock)
                     WHERE LOC.Loc = @cFinalLOC
                     AND loc.locationgroup <> 'PMOVERFLOW'
                     AND Facility = @cFacility)
         BEGIN
              IF NOT EXISTS ( SELECT 1
                     FROM loc (Nolock)
                     WHERE LOC.Loc = @cFinalLOC
                     AND loc.locationgroup =@cPutawayzone
                     AND Facility = @cFacility)
            BEGIN
               SET @nErrNo = 206101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ZoneNotMatch
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO