SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP07                                 */  
/* Purpose: Check barcode scanned must be altsku or retailsku           */
/*                                                                      */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2019-11-04 1.0  James     WMS-10987. Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP07] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,  
   @cSuggestedLOC   NVARCHAR( 10), 
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1),  
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cBarcode       NVARCHAR( 60)
   DECLARE @nIsRetailSKU   INT = 0
   DECLARE @nIsAltSKU      INT = 0
   DECLARE @nPABookingKey  INT = 0
   DECLARE @nTranCount     INT
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cSuggLOT       NVARCHAR( 10)
   DECLARE @cUserName      NVARCHAR( 18)

   
   
   SELECT @cBarcode = V_String11, 
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
         
   IF @nStep = 2  
   BEGIN  
      IF @nInputKey = 1
      BEGIN
         SET @cSKU = ''
         SELECT TOP 1 @cSKU = SKU 
         FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
         WHERE AltSku = @cBarcode 
         AND   StorerKey = @cStorerKey
         ORDER BY 1
               
         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1 @cSKU = SKU 
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
            WHERE RetailSku = @cBarcode 
            AND   StorerKey = @cStorerKey
            ORDER BY 1

            IF @@ROWCOUNT = 1
               SET @nIsRetailSKU = 1
         END
         ELSE
            SET @nIsAltSKU = 1
            
         IF @nIsRetailSKU = 0 AND @nIsAltSKU = 0
         BEGIN
            SET @nErrNo = 145851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO Quit
         END
         
         IF NOT EXISTS (
            SELECT 1  
            FROM dbo.LOTxLOCxID AS lli WITH (NOLOCK) 
            JOIN dbo.LOTATTRIBUTE AS la WITH (NOLOCK) ON (lli.Lot = la.Lot)
            JOIN dbo.LOC AS l WITH (NOLOCK) ON ( lli.LOC = l.LOC)
            WHERE lli.StorerKey = @cStorerKey
            AND   lli.Loc = @cFromLOC
            AND   lli.Id = @cFromID
            AND   lli.Sku = @cSKU
            AND   ( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
            AND   l.Facility = @cFacility
            AND   (( @nIsAltSKU = 1 AND la.Lottable03 = 'KR') OR ( @nIsRetailSKU = 1 AND la.Lottable03 = 'CN')))
         BEGIN
            SET @nErrNo = 145852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO Quit
         END
      END
   END
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cSuggestedLOC = ''
         BEGIN
            -- Check the product category (KR/CN)
            SET @cSKU = ''
            SELECT TOP 1 @cSKU = SKU 
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            WHERE AltSku = @cBarcode 
            AND   StorerKey = @cStorerKey
            ORDER BY 1
               
            IF @@ROWCOUNT = 0
            BEGIN
               SELECT TOP 1 @cSKU = SKU 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE RetailSku = @cBarcode 
               AND   StorerKey = @cStorerKey
               ORDER BY 1

               IF @@ROWCOUNT = 1
                  SET @nIsRetailSKU = 1
            END
            ELSE
               SET @nIsAltSKU = 1

            -- Get from lot# of the product category
            SELECT TOP 1 @cLOT = LLI.Lot 
            FROM dbo.LOTxLOCxID AS lli WITH (NOLOCK) 
            JOIN dbo.LOTATTRIBUTE AS la WITH (NOLOCK) ON (lli.Lot = la.Lot)
            JOIN dbo.LOC AS l WITH (NOLOCK) ON ( lli.LOC = l.LOC)
            WHERE lli.StorerKey = @cStorerKey
            AND   lli.Loc = @cFromLOC
            AND   lli.Id = @cFromID
            AND   lli.Sku = @cSKU
            AND   ( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) >= @nQty
            AND   l.Facility = @cFacility
            AND   (( @nIsAltSKU = 1 AND la.Lottable03 = 'KR') OR ( @nIsRetailSKU = 1 AND la.Lottable03 = 'CN'))
            ORDER BY 1

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 145853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PAQty not enuf
               GOTO Quit
            END

            /*-------------------------------------------------------------------------------
                                          Book suggested location
            -------------------------------------------------------------------------------*/
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_523ExtValidSP07 -- For rollback or commit only our own transaction

            SET @nErrNo = 0
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cFromLOC
               ,@cFromID
               ,@cFinalLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU          = @cSKU
               ,@nPutawayQTY   = @nQTY
               ,@cFromLOT      = @cLOT
               ,@nPABookingKey = @nPABookingKey OUTPUT
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END

            COMMIT TRAN rdt_523ExtValidSP07 -- Only commit change made here
            
            GOTO Commit_PMV

         RollBackTran:
            ROLLBACK TRAN rdt_523ExtValidSP07 -- Only rollback change made here
         Commit_PMV:
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
         END
      END
   END
    
   QUIT:
 

GO