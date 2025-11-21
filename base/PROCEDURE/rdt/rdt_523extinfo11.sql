SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtInfo11                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-07-18 1.0  yeekung WMS-22301 Created                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtInfo11]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cLOC            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPAZone     NVARCHAR(20)
   DECLARE @cLocaisle     NVARCHAR(20)

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN

      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT   @cLocaisle = locaisle,
                     @cPAZone   = PutawayZone
            FROM  dbo.LOC LOC WITH (NOLOCK)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LOC = @cSuggestedLOC

            SET @cExtendedInfo1 = 'PAZone:' + @cPAZone +'-'+@cLocaisle
         END
      END
   END
END

GO