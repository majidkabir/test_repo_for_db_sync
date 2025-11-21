SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtHnMExtVal01                                      */
/* Purpose: Validate To LOC location category = 'Other'                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-02-28 1.0  James      SOS301646 Created                         */
/* 2016-12-07 1.0  Ung        WMS-751 Change parameter                  */
/************************************************************************/

CREATE PROC [RDT].[rdtHnMExtVal01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSuggestedLOC    NVARCHAR( 10),
   @cFinalLOC        NVARCHAR( 10),
   @cOption          NVARCHAR( 1),
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 4  -- Suggest LOC, final LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @nErrNo = 0
            IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                            WHERE LOC = @cFinalLOC
                            AND   Facility = @cFacility
                            AND   LocationCategory = 'OTHER')
            BEGIN
               SET @nErrNo = 999
               GOTO Quit
            END
         END
      END
   END

Quit:


GO