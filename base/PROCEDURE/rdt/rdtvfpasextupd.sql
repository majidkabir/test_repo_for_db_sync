SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFPASExtUpd                                      */
/* Purpose: Send command to Junheinrich direct equipment to location    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-09-27   Ung       1.0   SOS257047 Created                       */
/* 2018-08-13   James     1.1   Add params Inputkey (james01)           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFPASExtUpd]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,   
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cID             NVARCHAR( 18),
   @cUCC            NVARCHAR( 20),
   @cLOC            NVARCHAR( 10),
   @cSuggestSKU     NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Putaway by SKU
   IF @nFunc = 523
   BEGIN
      IF @nStep = 1 -- ID or UCC, LOC
      BEGIN
         -- VF only allow putaway case
         IF @cUCC = '' AND (LEFT( @cID, 1) = 'P' OR LEFT( @cID, 2) = 'VF')
         BEGIN
            SET @nErrNo = 82952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan UCC
            GOTO Quit
         END

         -- UCC
         IF @cUCC <> ''
         BEGIN
            -- Check whether it is replenish UCC
            IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCC AND Status < '9')
            BEGIN
               SET @nErrNo = 82951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCCIsForReplen
               
            END
         END
      END
   END
   
Quit:

END

GO