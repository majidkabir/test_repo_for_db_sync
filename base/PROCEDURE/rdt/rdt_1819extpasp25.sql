SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1819ExtPASP25                                   */  
/* Copyright: LF Logistics                                              */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-06-21  1.0  James    WMS-9392 Created                           */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1819ExtPASP25] (  
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
   DECLARE @nIdentifier       INT
   DECLARE @n                 INT
   DECLARE @cCode             NVARCHAR(10)  
   DECLARE @cPAStrategyKey    NVARCHAR(10)  
   DECLARE @cPalletType       NVARCHAR(15)  
   DECLARE @cParam1           NVARCHAR( 20)
   DECLARE @cParam2           NVARCHAR( 20)
   DECLARE @cParam3           NVARCHAR( 20)
   DECLARE @cParam4           NVARCHAR( 20)
   DECLARE @cParam5           NVARCHAR( 20)
   DECLARE @cColumnName       NVARCHAR( 60)
   DECLARE @cField2Validate   NVARCHAR( 100)


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
      SET @nErrNo = 140951  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet  
      GOTO Quit  
   END  
  
   -- Check putaway strategy valid  
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)  
   BEGIN  
      SET @nErrNo = 140952  
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
   SAVE TRAN rdt_1819ExtPASP25 -- For rollback or commit only our own transaction  
              
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
  
      COMMIT TRAN rdt_1819ExtPASP25 -- Only commit change made here  
   END  
   ELSE
   BEGIN  
      SET @nErrNo = 140953  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Sugg Loc  
      GOTO RollBackTran  
   END 

   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1819ExtPASP25 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  
  

GO