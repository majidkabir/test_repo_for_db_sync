SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtValid07                                   */
/* Purpose: Validate putaway no allow reput                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-07-03   1.0  yeekung  WMS-22916. Created                        */ 
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtValid07] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cUCCNo          NVARCHAR( 20),
   @cSuggestedLOC   NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cFromLOC      NVARCHAR( 10),
            @cFacility     NVARCHAR( 5),
            @cPutawayZone  NVARCHAR( 20)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   SELECT @cFacility = Facility FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @cSuggestedLOC <> @cToLOC
         BEGIN
            SELECT   @cPutawayZone = LOC.PutawayZone
            FROM  LOC (NOLOCK)
            WHERE  LOC = @cSuggestedLOC
               AND Facility = @cFacility


            IF EXISTS( SELECT   1
                     FROM LOC (NOLOCK)
                     WHERE loc = @cToLOC
                        AND PutawayZone <> @cPutawayZone
                        AND Facility = @cFacility
                        AND PutawayZone <> 'NIKEMY_FW')
            BEGIN
               SET @nErrNo = 203401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffPAZone
               GOTO Quit
            END
         END
      END
   END

QUIT:



GO