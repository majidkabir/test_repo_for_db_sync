SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_523ExtPA19                                            */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date        Rev  Author   Purposes                                         */  
/* 26-04-2019  1.0  James    WMS-8753 Created                                 */  
/* 17-05-2019  1.1  James    INC0704795 Bug fix                               */  
/* 23-05-2019  1.1  CKY      INC0704795 Correct for Display ErrorMsg (CKY01)  */         
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtPA19] (  
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
   @nQTY             INT,  
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,  
   @nPABookingKey    INT            OUTPUT,  
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nTranCount  INT  
   DECLARE @cReturn     NVARCHAR( 1)  
  
   SET @nTranCount = @@TRANCOUNT  
     
   SET @cSuggestedLOC = ''  
   SET @cReturn = '0'  
  
   IF EXISTS (  
      SELECT 1  
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
      WHERE LLI.ID = @cID  
      AND   Loc.LocationType = 'FASTPICK'  
      AND   Loc.Loc = @cLOC  
      AND   Loc.Facility = @cFacility  
      GROUP BY LOC.Loc  
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) > 0)  
      SET @cReturn = '1'  
  
   IF @cReturn = '1'  
   BEGIN  
      -- Find a friend  
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC   
      FROM dbo.LOC LOC WITH (NOLOCK)   
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)   
      WHERE LOC.Facility = @cFacility   
      AND   LOC.Status <> 'HOLD'  
      AND   Loc.LocationType = 'FASTPICK'  
      AND   Loc.Locationflag = 'NONE'  
      AND   LOC.LOC <> @cLOC   
      AND   LLI.SKU = @cSKU  
      GROUP BY LOC.LOC   
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked + LLI.PendingMoveIn), 0) > 0  
      ORDER BY SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) DESC, -- Loc with max qty  
               LOC.LOC  
  
      IF ISNULL( @cSuggestedLOC, '') = ''  
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC  
         FROM dbo.LOC LOC WITH (NOLOCK)   
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
         WHERE LOC.Facility = @cFacility     
         AND   LOC.Status <> 'HOLD'  
         AND   Loc.LocationType = 'FASTPICK'  
         AND   Loc.Locationflag = 'NONE'  
         GROUP BY LOC.LOC  
         -- Empty LOC  
         HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked + LLI.PendingMoveIn), 0) = 0  
         ORDER BY LOC.LOC  
   END  
   ELSE  
   BEGIN  
      -- Suggest LOC  
      EXEC @nErrNo = [dbo].[nspRDTPASTD]  
           @c_userid          = 'RDT'  
         , @c_storerkey       = @cStorerKey  
         , @c_lot             = @cLOT  
         , @c_sku             = @cSKU  
         , @c_id              = @cID  
         , @c_fromloc         = @cLOC  
         , @n_qty             = @nQTY  
         , @c_uom             = '' -- not used  
         , @c_packkey         = '' -- optional, if pass-in SKU  
         , @n_putawaycapacity = 0  
         , @c_final_toloc     = @cSuggestedLOC OUTPUT  
   END  
       
   /*-------------------------------------------------------------------------------  
                                 Book suggested location  
   -------------------------------------------------------------------------------*/  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_523ExtPA19 -- For rollback or commit only our own transaction  
     
   IF @cSuggestedLOC <> ''  
   BEGIN  
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
         ,@cLOC  
         ,@cID  
         ,@cSuggestedLOC  
         ,@cStorerKey  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
         ,@cSKU          = @cSKU  
         ,@nPutawayQTY   = @nQTY  
         ,@cFromLOT      = @cLOT  
         ,@cUCCNo        = @cUCC  
         ,@nPABookingKey = @nPABookingKey OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      COMMIT TRAN rdt_523ExtPA19 -- Only commit change made here  
   END  
   ELSE  
   BEGIN   
      IF @cReturn = '1'    --(CKY01)  
      BEGIN    
         SET @nErrNo = 138001    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggested Loc    
      END    
      ELSE    
         SET @nErrNo = -1  -- Set -1 here to allow non return type PA      
                           -- can go to suggested loc screen to enter empty loc    
      GOTO RollBackTran  
   END  
     
   GOTO Quit  
     
   RollBackTran:  
      ROLLBACK TRAN rdt_523ExtPA19 -- Only rollback change made here  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END  

GO