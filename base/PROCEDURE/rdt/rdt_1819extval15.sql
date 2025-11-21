SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1819ExtVal15                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 08-09-2023 1.0  yeekung   WMS-22299. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtVal15] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1819 -- Putaway by ID
   BEGIN
      IF @nStep = 2 -- ToLoc
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN

            DECLARE  @cSKU NVARCHAR(20),
                     @cStorerkey NVARCHAR(20),
                     @cPutawayzone  NVARCHAR(20),
                     @cFacility  NVARCHAR(20)

            SELECT @cStorerkey = Storerkey,
                   @cFacility = Facility
            FROM RDT.RDTMobrec (nolock)
            Where mobile = @nMobile

            SELECT @cSKU = SKU
            FROM LOTXLOCXID (NOLOCK)
            WHERE id = @cFromID
               AND Storerkey = @cStorerkey
            GROUP BY SKU
            HAVING SUM(QTY) >0

            SELECT @cPutawayzone =putawayzone 
            FROM SKU (NOLOCK)
            WHERE SKU = @cSKU 
               AND STorerkey = @cStorerKey

            IF  EXISTS ( SELECT 1
                        FROM loc (Nolock)
                        WHERE LOC.Loc = @cToLOC
                        AND loc.locationgroup <> 'PMOVERFLOW'
                        AND Facility = @cFacility)
            BEGIN
                 IF NOT EXISTS ( SELECT 1
                        FROM loc (Nolock)
                        WHERE LOC.Loc = @cToLOC
                        AND loc.locationgroup =@cPutawayzone
                        AND Facility = @cFacility)
               BEGIN
                  SET @nErrNo = 206201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ZoneNotMatch
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO