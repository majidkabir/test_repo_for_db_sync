SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_522ExtInfo01                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display PND location                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-02-06 1.0  Ung      SOS332294 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_522ExtInfo01] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5), 
   @cID             NVARCHAR( 18),
   @cFromLOC        NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,          
   @cSuggestedLOC   NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT,
   @nAfterStep      INT 
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nAfterStep = 4 -- Successful putaway
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cPickAndDropLOC <> ''
            SET @cExtendedInfo1 = 'FINAL LOC: ' + @cFinalLOC
      END
   END

GO