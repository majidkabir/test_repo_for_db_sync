SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1819ExtVal12                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check multi SKU pallet                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2022-11-16   yeekung   1.0   WMS-21191 Created                        */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1819ExtVal12]
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

   DECLARE @cFacility NVARCHAR(5)

   -- Change ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 1 -- FromID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get Facility
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            -- Check multi SKU pallet
            IF EXISTS( SELECT 1
               FROM LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LLI.ID = @cFromID
               HAVING COUNT( DISTINCT LLI.SKU) > 1)
            BEGIN
               SET @nErrNo = 194051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU ID
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO