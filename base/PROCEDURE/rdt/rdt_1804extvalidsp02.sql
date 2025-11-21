SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtValidSP02                                */  
/* Purpose: Validate UCC only single SKU                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-03-10 1.0  James      WMS1318. Created                          */  
/* 2017-09-11 1.1  James      WMS1890-Not allow mix Lot01 (james01)     */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1804ExtValidSP02] (  
     @nMobile         INT, 
     @nFunc           INT, 
     @cLangCode       NVARCHAR(3), 
     @nStep           INT, 
     @cStorerKey      NVARCHAR(15),
     @cFacility       NVARCHAR(5), 
     @cFromLOC        NVARCHAR(10),
     @cFromID         NVARCHAR(18),
     @cSKU            NVARCHAR(20),
     @nQTY            INT, 
     @cUCC            NVARCHAR(20),
     @cToID           NVARCHAR(18),
     @cToLOC          NVARCHAR(10),
     @nErrNo          INT OUTPUT, 
     @cErrMsg         NVARCHAR(20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cUCCSKU     NVARCHAR( 20)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLottable01 NVARCHAR( 18)

   IF @nFunc = 1804  
   BEGIN  
      IF @nStep = 7 -- UCC
      BEGIN  
         SELECT TOP 1 @cUCCSKU = SKU, @cLOT = Lot
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC

         -- No Record 
         IF @@ROWCOUNT = 0
            GOTO Quit

         IF @cUCCSKU <> @cSKU
         BEGIN
            SET @nErrNo = 106801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Multi SKU UCC
            GOTO Quit
         END

         SELECT @cLottable01 = Lottable01
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE Lot = @cLOT

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.SKU = @cSKU
                     AND   LLI.LOC = @cFromLOC
                     AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = @cFromID))
                     AND   LOC.Facility = @cFacility
                     AND   ISNULL( LA.Lottable01, '') <> @cLottable01
                     GROUP BY LA.LOT
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
         BEGIN
            SET @nErrNo = 106802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix SKU grade
            GOTO Quit
         END
      END
   END
  
QUIT:  

 

GO