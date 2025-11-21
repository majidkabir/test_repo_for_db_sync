SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc10                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-03-17  1.0  James       WMS-16555. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveSKUSuggLoc10] (
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

   DECLARE @cCur_PickLoc   CURSOR
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @nCount         INT = 1
   
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''
   SET @cOutField12 = ''
   SET @cOutField13 = ''
   SET @cOutField14 = ''
   SET @cOutField15 = ''
   
   SET @cCur_PickLoc = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT SL.LOC  
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.StorerKey = LLI.StorerKey AND SL.Loc = LLI.Loc AND SL.SKU = LLI.SKU)  
   WHERE LOC.Facility = @cFacility  
   AND LLI.StorerKey = @cStorerkey  
   AND SL.LocationType = 'PICK'  
   AND LLI.SKU = @cSKU        
   ORDER BY 1
   OPEN @cCur_PickLoc
   FETCH NEXT FROM @cCur_PickLoc INTO @cLOC
   WHILE @@FETCH_STATUS = 0
   BEGIN
      
      IF @nCount = 1 SET @cOutField01 = @cLOC
      IF @nCount = 2 SET @cOutField02 = @cLOC
      IF @nCount = 3 SET @cOutField03 = @cLOC
      IF @nCount = 4 SET @cOutField04 = @cLOC
      IF @nCount = 5 SET @cOutField05 = @cLOC
      
      SET @nCount = @nCount + 1
      
      IF @nCount > 5
         BREAK
         
      FETCH NEXT FROM @cCur_PickLoc INTO @cLOC
   END
 
END

SET QUOTED_IDENTIFIER OFF


SET QUOTED_IDENTIFIER OFF

GO