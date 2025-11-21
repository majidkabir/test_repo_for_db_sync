SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Store procedure: rdt_1819ExtPASP28                                   */
/*                                                                      */
/* Purpose: Use RDT config to get suggested loc else return error msg   */
/*                                                                      */
/* Called from: rdt_PutawayByID_GetSuggestLOC                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-11   1.0  James    WMS-12314. Created                        */
/************************************************************************/
  
CREATE PROC [RDT].[rdt_1819ExtPASP28] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @cUserName        NVARCHAR( 18),  
   @cStorerKey       NVARCHAR( 15),   
   @cFacility        NVARCHAR( 5),   
   @cFromLOC         NVARCHAR( 10),  
   @cID              NVARCHAR( 18),  
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,  
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,  
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,  
   @nPABookingKey    INT            OUTPUT,   
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount        INT  
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cReceiptKey       NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cSKUPutawayZone   NVARCHAR( 10)
   DECLARE @cLOCPutawayZone   NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)
   DECLARE @nPltLeft4Putaway  INT = 0
   DECLARE @nTtl_PalletQty    INT = 0
   DECLARE @nPallet           INT = 0
   DECLARE @nTtl_QtyExpected  INT = 0
   DECLARE @nTtl_ASNPallet    INT = 0
   DECLARE @ndebug            INT = 0
   
   IF SUSER_SNAME() = 'jameswong'
      SET @ndebug = 1

   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   SET @cFitCasesInAisle = ''
   
   -- Get sku from pallet
   SELECT  
      @cLOT = LLI.Lot, 
      @cSKU = LLI.SKU,
      @nTtl_PalletQty = ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                      ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cFromLOC
   AND   LLI.ID = @cID
   AND   ( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
         ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   GROUP BY LLI.Lot, LLI.Sku
   
   SELECT @cSKUPutawayZone = SKU.PutawayZone,
          @nPallet = PACK.Pallet
   FROM dbo.SKU SKU WITH (NOLOCK)
   JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.SKU = @cSKU
   
   IF @nTtl_PalletQty <> @nPallet
   BEGIN  
      SET @nErrNo = 149301  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NotFull Pallet  
      SET @nErrNo = -1  -- Allow to go to next screen
      GOTO Fail  
   END 

   SELECT @cLOCPutawayZone = Long
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'DYSONPZG'
   AND   Code = @cSKUPutawayZone
   AND   Storerkey = @cStorerKey
   
   -- Get ASN
   SELECT TOP 1 @cReceiptKey = SUBSTRING( SourceKey, 1, 10)
   FROM dbo.ITRN WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   TranType = 'DP'
   AND   SourceType = 'ntrReceiptDetailUpdate'
   AND   ToLoc = @cFromLOC
   AND   ToID = @cID
   AND   SKU = @cSKU
   ORDER BY 1

   -- Get qty expected 
   SELECT @nTtl_QtyExpected = ISNULL( SUM( QtyExpected), 0)
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   SKU = @cSKU -- Only single SKU pallet
   
   -- Get how many pallets left to putaway. This need to use
   -- to deletermine whether the shuttle loc best fit to putaway 
   -- to fully utilize shuttle loc
   --SELECT @nTtl_ASNPallet = COUNT ( DISTINCT LLI.ID)
   --FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   --WHERE LLI.StorerKey = @cStorerKey
   --AND   LLI.Id IN 
   --    ( SELECT DISTINCT ToId 
   --      FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK) 
   --      WHERE LLI.Id = RD.ToId 
   --      AND   LLI.Loc = RD.ToLoc
   --      AND   RD.ReceiptKey = @cReceiptKey
   --      AND   RD.FinalizeFlag = 'Y')
   --AND   LLI.Qty > 0

   SET @nTtl_ASNPallet = @nTtl_QtyExpected / @nPallet

   -- Get pallet already booked or putaway  
   DECLARE @nPalletPutaway INT  
   SELECT @nPalletPutaway = COUNT( DISTINCT RD.ToID)   
   FROM ReceiptDetail RD WITH (NOLOCK)   
   JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (RD.StorerKey = LLI.StorerKey AND RD.SKU = LLI.SKU AND RD.ToID = LLI.ID)  
   JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
   WHERE RD.ReceiptKey = @cReceiptKey  
   AND RD.ToID <> ''  
   AND RD.StorerKey = @cStorerKey  
   AND RD.SKU = @cSKU  
   AND LOC.Facility = @cFacility  
   AND LOC.LocationCategory = 'SHUTTLE' 

   -- Minus out pallet booked or putaway  
   SET @nPltLeft4Putaway = @nTtl_ASNPallet - @nPalletPutaway  

   -- Find a friend
   SELECT TOP 1 @cSuggLOC = LOC.Loc
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( LOC.PutawayZone = CLK.Long)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC <> @cFromLOC
   AND   LLI.SKU = @cSKU
   AND   LLI.Lot = @cLOT
   AND   LOC.LocationCategory = 'SHUTTLE'
   AND   LOC.Facility = @cFacility
   AND   CLK.ListName = 'DYSONPZG'
   AND   CLK.Code = @cSKUPutawayZone
   GROUP BY LOC.Loc, LOC.ChargingPallet, LOC.LogicalLocation, LOC.MaxPallet
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                  ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
         AND ( LOC.MaxPallet >= ( COUNT( DISTINCT LLI.ID) + 1))
   ORDER BY LOC.ChargingPallet DESC, LOC.LogicalLocation, LOC.Loc
   
   IF @@ROWCOUNT = 0
   BEGIN
      -- Find empty loc in SHUTTLE area
      SELECT TOP 1 @cSuggLOC = LOC.Loc
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
      JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( LOC.PutawayZone = CLK.Long)
      WHERE LOC.Facility = @cFacility
      AND   LOC.Locationflag = 'NONE'
      AND   LOC.LocationCategory = 'SHUTTLE'
      AND   CLK.ListName = 'DYSONPZG'
      AND   CLK.Code = @cSKUPutawayZone
      AND   LOC.ChargingPallet <= @nPltLeft4Putaway  -- best fit shuttle loc
      GROUP BY LOC.LOC, CLK.Short, LOC.ChargingPallet, LOC.LogicalLocation, CLK.code2
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                     ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
      ORDER BY CLK.Short, LOC.ChargingPallet DESC, LOC.LogicalLocation, LOC.Loc, CLK.code2

      IF @@ROWCOUNT = 0
      BEGIN
         -- Find empty loc in non SHUTTLE area
         SELECT TOP 1 @cSuggLOC = LOC.Loc
         FROM dbo.LOC LOC WITH (NOLOCK)
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( LOC.PutawayZone = CLK.Long)
         WHERE LOC.Facility = @cFacility
         AND   LOC.Locationflag = 'NONE'
         AND   LOC.LocationCategory <> 'SHUTTLE'
         AND   CLK.ListName = 'DYSONPZG'
         AND   CLK.Code = @cSKUPutawayZone
         GROUP BY LOC.LOC, CLK.Short, LOC.ChargingPallet, LOC.LogicalLocation, CLK.code2
         HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                        ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
         ORDER BY CLK.Short, LOC.ChargingPallet DESC, LOC.LogicalLocation, LOC.Loc, CLK.code2
      END
   END

   IF @ndebug = 1
   BEGIN
      SELECT @cFromLOC '@cFromLOC', @cID '@cID', @cSKU '@cSKU', @cFacility '@cFacility'
      SELECT @cSKUPutawayZone '@cSKUPutawayZone', @nPallet '@nPallet', @cLOCPutawayZone '@cLOCPutawayZone'
      SELECT @cReceiptKey '@cReceiptKey', @nTtl_QtyExpected '@nTtl_QtyExpected', @nTtl_ASNPallet '@nTtl_ASNPallet'
      SELECT @nPalletPutaway '@nPalletPutaway', @nPltLeft4Putaway '@nPltLeft4Putaway'
      SELECT @cLocationCategory = LocationCategory FROM dbo.LOC (NOLOCK) WHERE loc = @cSuggLOC AND Facility = @cFacility
      SELECT @cLocationCategory '@cLocationCategory'
   END
   
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1819ExtPASP28 -- For rollback or commit only our own transaction  
              
   -- Lock suggested location  
   IF ISNULL( @cSuggLOC, '') <> ''   
   BEGIN  
      IF @cFitCasesInAisle <> 'Y'  
      BEGIN  
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
            ,@cFromLOC  
            ,@cID  
            ,@cSuggLOC  
            ,@cStorerKey  
            ,@nErrNo  OUTPUT  
            ,@cErrMsg OUTPUT  
            ,@nPABookingKey = @nPABookingKey OUTPUT  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
  
      -- Lock PND location  
      IF @cPickAndDropLOC <> ''  
      BEGIN  
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
            ,@cFromLOC  
            ,@cID  
            ,@cPickAndDropLOC  
            ,@cStorerKey  
            ,@nErrNo  OUTPUT  
            ,@cErrMsg OUTPUT  
            ,@nPABookingKey = @nPABookingKey OUTPUT  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
  
      COMMIT TRAN rdt_1819ExtPASP28 -- Only commit change made here  
   END  
   ELSE
   BEGIN  
      SET @nErrNo = 149302  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Sugg Loc  
      SET @nErrNo = -1  -- Return "No Suggested Loc" and go to next screen
      GOTO RollBackTran  
   END 

   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1819ExtPASP28 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN

Fail:

   --INSERT INTO traceinfo ( TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES 
   --('12345', GETDATE(), @cSuggLOC, @cSKU, @cSKUPutawayZone, @cFacility, @cFromLOC)
      
END  
  

GO