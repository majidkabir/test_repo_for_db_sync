SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_522ExtPPA01                                     */
/* Purpose: Validate if pallet need to create PA task                   */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-29 1.0  James      Created                                   */
/* 2014-11-07 1.1  James      Remove traceinfo                          */
/* 2015-07-31 1.2  James      SOS348965-Check duplicate sack id been    */
/*                            used (james01)                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_522ExtPPA01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nScn            INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,  
   @nAfterStep      INT           OUTPUT, 
   @nAfterScn       INT           OUTPUT, 
   @cFinalLoc       NVARCHAR( 10) OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

/*
For each sku, get Primary Piece Pick Location (PPPL)
If Found:
	If available quantity = 0 THEN
	   If total # cases on pallet for sku >= N
	      Create PA task(s) for N cases to go to PPPL
	      Create WCS Routing for Case(s)
	   ELSE
ELSE
   Continue with Putaway 
*/

   DECLARE @cLOT           NVARCHAR( 10), 
           @cPANoOfCase    NVARCHAR( 5), 
           @cPickLoc       NVARCHAR( 10), 
           @cCaseCnt       NVARCHAR( 5), 
           @nSKUxLocQTY    INT
           
   SELECT TOP 1 @cStorerkey = Storerkey,
                @cSKU = SKU,
                @cLot = LOT 
   From dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE ID = @cFromID
   AND   LOC = @cFromLOC
   AND   Qty > 0

   SET @cPANoOfCase = rdt.RDTGetConfig( @nFunc, 'PANoOfCase', @cStorerKey)
   IF CAST( @cPANoOfCase AS INT) = 0
      GOTO Quit
   
   -- Get piece pick loc
   SELECT @cPickLoc = Loc 
   FROM dbo.SKUxLOC WITH (NOLOCK) 
   WHERE SKU = @cSKU 
   AND   Storerkey = @cStorerkey 
   AND   Locationtype = 'PICK'
   
   IF ISNULL( @cPickLoc, '') = ''
      GOTO Quit

   SELECT @nSKUxLocQTY = ISNULL( SUM(QTY), 0)
   FROM dbo.SKUxLoc WITH (NOLOCK)
   WHERE SKU = @cSKU
   AND Storerkey = @cStorerkey
   AND LOC = @cPickLoc

   IF @nSKUxLocQTY = 0
   BEGIN
      SELECT @cCaseCnt = Lottable06
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE LOT = @cLOT
      
      IF CAST( @cCaseCnt AS INT) >= CAST( @cPANoOfCase AS INT)
      BEGIN
         --SET @cOutField01 = ''

         -- Go to next screen
         SET @nAfterScn = @nScn+3
         SET @nAfterStep = @nStep+3
         
         GOTO Quit
      END
   END
   ELSE
      GOTO Quit

QUIT:

GO