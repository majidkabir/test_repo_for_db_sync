SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal13                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-07-03  1.0  yeekung   WMS-22905. Created                        */ 
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1819ExtVal13]
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
   DECLARE @cPutawayZone   NVARCHAR(10)  
   DECLARE @cStorerKey NVARCHAR(20)

   -- Change ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLoc
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get Facility
            SELECT   @cFacility = Facility, 
                     @cStorerKey = Storerkey
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE UserName = SUSER_SNAME()

            IF @cToLOC <> @cSuggLOC
            BEGIN
               SELECT   @cPutawayZone = LOC.PutawayZone
               FROM  LOC LOC (NOLOCK)
               WHERE LOC = @cSuggLOC
                  AND Facility = @cFacility


               IF EXISTS( SELECT   1
                        FROM LOC (NOLOCK)
                        WHERE loc = @cToLOC
                           AND PutawayZone <> @cPutawayZone
                           AND Facility = @cFacility
                           AND PutawayZone <> 'NIKEMY_FW' )
               BEGIN
                  SET @nErrNo = 203351
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffPAZone
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO