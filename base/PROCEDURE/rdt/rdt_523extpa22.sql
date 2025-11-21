SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_523ExtPA22                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-06-21  1.0  James    WMS-9392 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA22] (
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
   DECLARE @cPAStrategyKey NVARCHAR( 10)
   DECLARE @cSuggID     NVARCHAR( 18)
   DECLARE @nMaxPallet  INT
   DECLARE @nCount      INT

   -- Get putaway strategy  
   SET @cPAStrategyKey = ''  
   SELECT @cPAStrategyKey = Short   
   FROM CodeLKUP WITH (NOLOCK)  
   WHERE ListName = 'RDTExtPA'  
      AND StorerKey = @cStorerKey  
      AND Code2 = @cFacility  
      AND Code = @nFunc  

   -- Check blank putaway strategy  
   IF @cPAStrategyKey = ''  
   BEGIN  
      SET @nErrNo = 140901  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet  
      GOTO Quit  
   END  

   -- Check putaway strategy valid  
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)  
   BEGIN  
      SET @nErrNo = 140902  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey  
      GOTO Quit  
   END  

   SET @cSuggestedLOC = ''
   SET @cSuggID = ''

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
      , @c_final_toloc     = @cSuggestedLOC  OUTPUT  
      , @c_PAStrategyKey   = @cPAStrategyKey  

   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA22 -- For rollback or commit only our own transaction
   
   IF @cSuggestedLOC <> ''
   BEGIN
      SET @cSuggID = ''
      SELECT TOP 1 @cSuggID = ID
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
      WHERE LOC.Facility = @cFacility
      AND   LOC.LOC = @cSuggestedLOC
      AND   LLI.SKU = @cSKU
      GROUP BY LLI.ID
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) > 0
      ORDER BY ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) 

      IF @@ROWCOUNT = 0
         SET @cSuggID = @cID

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
         ,@cToID         = @cSuggID
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      COMMIT TRAN rdt_523ExtPA22 -- Only commit change made here
   END
   ELSE
   BEGIN 
      SET @nErrNo = 140903  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggested Loc  
      GOTO RollBackTran
   END
   
   GOTO Quit
   
   RollBackTran:
      ROLLBACK TRAN rdt_523ExtPA22 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
         --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES
         --('523', GETDATE(), @cSuggestedLOC, @cSuggID, @cID, @nCount, @nMaxPallet)
END

GO