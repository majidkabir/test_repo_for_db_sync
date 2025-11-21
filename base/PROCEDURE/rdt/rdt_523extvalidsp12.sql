SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtValidSP12                                 */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2023-07-04 1.0  James     WMS-22929. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtValidSP12] (
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

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 4
      BEGIN
         -- If SuggestedLOC exist, not allow user input toloc <> suggestedloc.
         IF ISNULL( @cSuggestedLOC, '') <> '' AND ( @cSuggestedLOC <> @cFinalLOC)
         BEGIN
            SET @nErrNo = 203501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Loc Not Match
            GOTO Quit
         END

         -- If SuggestedLOC not exist, only allow user input empty loc where SKUXLOC.qty = 0
         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.SKUxLOC SL WITH (NOLOCK)
                            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.Loc = LOC.Loc)
                            WHERE SL.Loc = @cFinalLOC
                            AND   SL.StorerKey = @cStorerKey
                            AND   LOC.Facility = @cFacility
                            GROUP BY SL.Loc
                            HAVING ISNULL(SUM( SL.Qty - SL.QtyAllocated - SL.QtyPicked), 0) = 0)
            BEGIN
               SET @nErrNo = 203502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLoc
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO