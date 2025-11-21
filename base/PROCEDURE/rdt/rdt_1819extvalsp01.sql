SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtValSP01                                  */
/*                                                                      */
/* Purpose: Check multi SKU UCC                                         */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 01-02-2016  1.0  Ung      SOS360340. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtValSP01] (
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
      IF @nStep = 1 -- ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get login info
            DECLARE @cFacility  NVARCHAR( 5)
            DECLARE @cStorerKey NVARCHAR( 15)
            SELECT 
               @cFacility = Facility, 
               @cStorerKey = StorerKey
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile

            -- Check multi SKU UCC
            IF EXISTS( SELECT 1 
               FROM UCC WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (UCC.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND UCC.StorerKey = @cStorerKey
                  AND UCC.ID = @cFromID
                  AND UCC.Status = '1'
               GROUP BY UCCNo
               HAVING COUNT( 1) > 1)
            BEGIN
               SET @nErrNo = 59801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
               GOTO Quit
            END
            
            -- Check putaway from PND
            IF EXISTS( SELECT 1 
               FROM LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LLI.StorerKey = @cStorerKey
                  AND LLI.ID = @cFromID
                  AND LLI.QTY > 0
                  AND LOC.LocationCategory = 'PND_IN')
            BEGIN
               SET @nErrNo = 59802
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PND no putaway
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO