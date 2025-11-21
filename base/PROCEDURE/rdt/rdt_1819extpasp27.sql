SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Store procedure: rdt_1819ExtPASP27                                   */
/*                                                                      */
/* Purpose: Use RDT config to get suggested loc else return blank loc   */
/*                                                                      */
/* Called from: rdt_PutawayByID_GetSuggestLOC                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-09   1.0  James    WMS-12060. Created                        */
/************************************************************************/
  
CREATE PROC [RDT].[rdt_1819ExtPASP27] (  
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
   DECLARE @cCode             NVARCHAR(10)  
   DECLARE @cPAStrategyKey    NVARCHAR(10)  
   DECLARE @cParam1           NVARCHAR( 20)
   DECLARE @cParam2           NVARCHAR( 20)
   DECLARE @cParam3           NVARCHAR( 20)
   DECLARE @cParam4           NVARCHAR( 20)
   DECLARE @cParam5           NVARCHAR( 20)
   DECLARE @cProductCategory  NVARCHAR( 30)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cPltMaxCnt        NVARCHAR( 5)
   DECLARE @nPltCtnCount      INT
   DECLARE @nFullPlt          INT

   -- Get sku from pallet
   SELECT TOP 1 @cSKU = SKU
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cFromLOC
   AND   LLI.ID = @cID
   AND   LLI.Qty > 0
   AND   LOC.Facility = @cFacility
   ORDER BY 1
   
   -- Get product category, 10 = footwear; 20 = apparel; 30 = equipment
   SELECT @cProductCategory = BUSR7, 
          @cPutawayZone = PutawayZone
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU
   
   -- Get pallet can store how many carton
   SELECT @cPltMaxCnt = Short
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'PAPltMxCnt'
   AND   Code = @cProductCategory
   AND   Storerkey = @cStorerKey
   
   -- Get total carton on pallet
   SELECT @nPltCtnCount = COUNT( DISTINCT UCCNo)
   FROM dbo.UCC UCC WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( UCC.Loc = LOC.Loc)
   WHERE UCC.Storerkey = @cStorerKey
   AND   UCC.LOC = @cFromLOC
   AND   UCC.ID = @cID
   AND   UCC.Status = '1'
   AND   LOC.Facility = @cFacility

   -- Define full or loose pallet
   IF @nPltCtnCount < @cPltMaxCnt
   BEGIN
      SET @nFullPlt = 0
      
      SET @nErrNo = 149251  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NotFull Pallet  
      GOTO Quit  
   END
   ELSE
      SET @nFullPlt = 1

   -- Get product category from codelkup
   SET @cCode = RTRIM( @cProductCategory) + CAST( @nFullPlt AS NVARCHAR( 1))
   
   -- Get putaway strategy  
   SET @cPAStrategyKey = ''  
   SELECT @cPAStrategyKey = Short   
   FROM CodeLKUP WITH (NOLOCK)  
   WHERE ListName = 'NKRDTExtPA'  
      AND StorerKey = @cStorerKey  
      AND Long = @cFacility  
      AND Code = @cCode  
      AND code2 = @cPutawayZone
  
   -- Check blank putaway strategy  
   IF @cPAStrategyKey = ''  
   BEGIN  
      SET @nErrNo = 149252  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet  
      GOTO Quit  
   END  
  
   -- Check putaway strategy valid  
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)  
   BEGIN  
      SET @nErrNo = 149253  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey  
      GOTO Quit  
   END  

   -- Suggest LOC  
   EXEC @nErrNo = [dbo].[nspRDTPASTD]  
        @c_userid          = 'RDT'  
      , @c_storerkey       = @cStorerKey  
      , @c_lot             = ''  
      , @c_sku             = ''  
      , @c_id              = @cID  
      , @c_fromloc         = @cFromLOC  
      , @n_qty             = 0  
      , @c_uom             = '' -- not used  
      , @c_packkey         = '' -- optional, if pass-in SKU  
      , @n_putawaycapacity = 0  
      , @c_final_toloc     = @cSuggLOC          OUTPUT  
      , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT  
      , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT  
      , @c_Param1          = @cParam1
      , @c_Param2          = @cParam2
      , @c_Param3          = @cParam3
      , @c_Param4          = @cParam4
      , @c_Param5          = @cParam5
      , @c_PAStrategyKey   = @cPAStrategyKey  

   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1819ExtPASP27 -- For rollback or commit only our own transaction  
              
   -- Lock suggested location  
   IF @cSuggLOC <> ''   
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
  
      COMMIT TRAN rdt_1819ExtPASP27 -- Only commit change made here  
   END  
   ELSE
   BEGIN  
      SET @nErrNo = 149254  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Sugg Loc  
      GOTO RollBackTran  
   END 

   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1819ExtPASP27 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  
  

GO