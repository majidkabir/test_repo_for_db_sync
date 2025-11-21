SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP32                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 18-12-2020  1.0  Chermaine WMS-15800. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP32] (
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

   DECLARE @cSKU    NVARCHAR( 20)
   DECLARE @cLOT    NVARCHAR(10)
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
   -- Get pallet SKU  
   SELECT TOP 1   
      @cSKU = SKU,   
      @cLOT = LOT  
   FROM LOTxLOCxID LLI WITH (NOLOCK)   
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
   WHERE LOC.Facility = @cFacility  
      AND LLI.LOC = @cFromLOC   
      AND LLI.ID = @cID   
      AND LLI.QTY > 0 
   
   --SELECT @cPAStrategyKey = ISNULL( Short, '')  
   --FROM CodeLkup WITH (NOLOCK)  
   --WHERE ListName = 'RDTExtPA'  
   --   AND Code = @cPAType  
   --   AND StorerKey = @cStorerKey  
      
   ---- Check blank putaway strategy  
   --IF @cPAStrategyKey = ''  
   --BEGIN  
   --   SET @nErrNo = 107101  
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet  
   --   GOTO RollBackTran  
   --END  
   
   ---- Check putaway strategy valid  
   --IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)  
   --BEGIN  
   --   SET @nErrNo = 107102  
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey  
   --   GOTO RollBackTran  
   --END  
   
   -- Suggest LOC  
   EXEC @nErrNo = [dbo].[nspRDTPASTD]  
         @c_userid          = 'RDT'  
      , @c_storerkey       = @cStorerKey  
      , @c_lot             = @cLOT  
      , @c_sku             = @cSKU  
      , @c_id              = @cID  
      , @c_fromloc         = @cFromLOC  
      , @n_qty             = 0  
      , @c_uom             = '' -- not used  
      , @c_packkey         = '' -- optional, if pass-in SKU  
      , @n_putawaycapacity = 0  
      , @c_final_toloc     = @cSuggLOC OUTPUT 

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = -1
      GOTO Quit
   END
   
Quit:
END

GO