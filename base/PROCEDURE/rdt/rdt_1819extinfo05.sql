SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1819ExtInfo05                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display final location                                      */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-07-18 1.0  yeekung WMS-22299. Created                           */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1819ExtInfo05] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cPAZone     NVARCHAR(20)
   DECLARE @cLocaisle     NVARCHAR(20)

   SELECT @cFacility = Facility FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nAfterStep = 2 -- Successful putaway
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT   @cLocaisle = locaisle,
                  @cPAZone   = PutawayZone
         FROM  dbo.LOC LOC WITH (NOLOCK)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC = @cSuggLOC

         SET @cExtendedInfo = 'PAZone:' + @cPAZone +'-'+@cLocaisle
      END
   END

GO