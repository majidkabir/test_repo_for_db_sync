SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA05                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 16-Feb-2017  1.0  James    WMS1079. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA05] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SET @cSuggestedLOC = ''

   SELECT TOP 1 @cSuggestedLOC = SL.LOC
   FROM dbo.SKUxLOC SL WITH (NOLOCK) 
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
   WHERE SL.StorerKey = @cStorerKey
   AND   SL.LocationType = 'PICK'
   AND   SL.SKU = @cSKU
   AND   LOC.Facility = @cFacility

   QUIT:

END

GO