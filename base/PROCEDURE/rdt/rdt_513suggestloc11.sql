SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC11                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show 1st Loc asc order: Min (LotxLocxID.Loc)                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-02-2019  1.0  James       WMS-8026 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC11] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerkey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLoc      NVARCHAR( 10),
   @cFromID       NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cToID         NVARCHAR( 18),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10), -- LOCK/UNLOCK
   @nPABookingKey INT           OUTPUT,
	@cOutField01   NVARCHAR( 20) OUTPUT,
	@cOutField02   NVARCHAR( 20) OUTPUT,
   @cOutField03   NVARCHAR( 20) OUTPUT,
   @cOutField04   NVARCHAR( 20) OUTPUT,
   @cOutField05   NVARCHAR( 20) OUTPUT,
   @cOutField06   NVARCHAR( 20) OUTPUT,
   @cOutField07   NVARCHAR( 20) OUTPUT,
   @cOutField08   NVARCHAR( 20) OUTPUT,
   @cOutField09   NVARCHAR( 20) OUTPUT,
   @cOutField10   NVARCHAR( 20) OUTPUT,
	@cOutField11   NVARCHAR( 20) OUTPUT,
	@cOutField12   NVARCHAR( 20) OUTPUT,
   @cOutField13   NVARCHAR( 20) OUTPUT,
   @cOutField14   NVARCHAR( 20) OUTPUT,
   @cOutField15   NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggestedLoc     NVARCHAR( 10)

   IF @cType = 'LOCK'
   BEGIN
      SET @cSuggestedLoc = ''
      SELECT TOP 1 @cSuggestedLoc = LOC.LOC
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      LEFT JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.Storerkey = @cStorerkey 
      AND LLI.SKU = @cSKU 
      AND ( LLI.Qty - LLI.QtyPicked) > 0 
      AND LOC.Facility  = @cFacility  
      AND LOC.LocationType = 'PICK'
      AND LOC.LOC <> @cFromLoc
      ORDER BY LOC.LOC

      IF ISNULL( @cSuggestedLoc, '') =  ''
         SET @cSuggestedLoc = '<Blank>'

      -- Output ExtendedField02
      SET @cOutField01 = @cSuggestedLoc
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   END

Quit:

END

GO