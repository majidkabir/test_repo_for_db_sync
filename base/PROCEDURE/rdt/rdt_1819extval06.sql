SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal06                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-05-14   James     1.0   WMS9081. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal06]
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey NVARCHAR( 15),
           @cSKU       NVARCHAR( 20),
           @cUCC       NVARCHAR( 20),
           @cFacility  NVARCHAR( 10)

   SELECT @cStorerKey = StorerKey, 
          @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 2
      BEGIN
         -- If SuggestedLOC exist, not allow user input toloc <> suggestedloc.
         IF ISNULL( @cSuggLOC, '') <> '' AND ( @cSuggLOC <> @cToLOC)
         BEGIN
            SET @nErrNo = 138501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Loc Not Match
            GOTO Quit
         END

         -- If SuggestedLOC not exist, only allow user input empty loc where SKUXLOC.qty = 0
         IF ISNULL( @cSuggLOC, '') = ''
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.SKUxLOC SL WITH (NOLOCK)
                            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.Loc = LOC.Loc)
                            WHERE SL.Loc = @cToLOC
                            AND   SL.StorerKey = @cStorerKey
                            AND   LOC.Facility = @cFacility
                            GROUP BY SL.Loc
                            HAVING ISNULL(SUM( SL.Qty - SL.QtyAllocated - SL.QtyPicked), 0) = 0)
            BEGIN
               SET @nErrNo = 138502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLoc
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO