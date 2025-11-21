SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1819ExtPASP17                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 06-02-2018  1.0  ChewKP   WMS-3841 Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1819ExtPASP17] (  
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
   DECLARE @cPalletType       NVARCHAR(10)  
   DECLARE @cPAType           NVARCHAR(10)  
   DECLARE @cPutawayZone      NVARCHAR(10)  
   DECLARE @cPAStrategyKey    NVARCHAR(10)  
   DECLARE @cSKU              NVARCHAR(20)  
   DECLARE @cSUSR1            NVARCHAR(18)  
   DECLARE @cCountryCode      NVARCHAR(10)  
   DECLARE @nQTYPicked        INT  
   DECLARE @cSuggPALogicalLOC NVARCHAR(10)  
          ,@cPalletSKU        NVARCHAR(20)  
          ,@nPalletQty        INT  
          ,@nPackPallet       INT  
          ,@cPackKey          NVARCHAR(10)   
          ,@cPAStrategyKey01  NVARCHAR(10)   
          ,@cPAStrategyKey02  NVARCHAR(10)   
          ,@cPAStrategyKey03  NVARCHAR(10)   
          ,@cPAStrategyKey04  NVARCHAR(10)   
          ,@cPAStrategyKey05  NVARCHAR(10)   
          ,@cPACode           NVARCHAR(10)   
          ,@cSUSR3            NVARCHAR(18)   
            
   DECLARE @tPAStrategyList TABLE (PAStrategyKey NVARCHAR(10) )   
         
           
   SET @cSuggLOC = ''  
   SET @cSuggPALogicalLOC = ''  
   sET @nPABookingKey = 0   
  
     
  
   SELECT TOP 1   @cPalletSKU = SKU  
                , @nPalletQty = SUM(Qty)   
   FROM dbo.LotxLocxID WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND ID = @cID  
   AND Loc = @cFromLOC  
   GROUP BY SKU  
     
   SELECT @cSUSR3 = SUSR3   
   FROM dbo.SKU WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND SKU = @cPalletSKU  
     
     
   SELECT @cPACode = Short   
   FROM dbo.Codelkup WITH (NOLOCK)   
   WHERE ListName = 'SKUGroup'  
   AND StorerKey = @cStorerKey   
   AND Code = @cSUSR3   
     
  
   -- Get putaway strategy  
   SELECT @cPAStrategyKey01 = ISNULL( Short, '')  
         ,@cPAStrategyKey02 = ISNULL( UDF01, '')  
         ,@cPAStrategyKey03 = ISNULL( UDF02, '')  
         ,@cPAStrategyKey04 = ISNULL( UDF03, '')  
         ,@cPAStrategyKey05 = ISNULL( UDF04, '')  
   FROM CodeLkup WITH (NOLOCK)  
   WHERE ListName = 'RDTExtPA'  
      AND Code = @cPACode  
      AND StorerKey = @cStorerKey  
     
   IF ISNULL(@cPAStrategyKey01,'') <> ''   
      INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey01 )   
        
   IF ISNULL(@cPAStrategyKey02,'') <> ''   
      INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey02 )   
     
   IF ISNULL(@cPAStrategyKey03,'') <> ''   
      INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey03 )   
     
   IF ISNULL(@cPAStrategyKey04,'') <> ''   
      INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey04 )   
     
   IF ISNULL(@cPAStrategyKey05,'') <> ''   
      INSERT INTO @tPAStrategyList ( PAStrategyKey ) VALUES ( @cPAStrategyKey05 )            
  
    
    
   -- Check blank putaway strategy  
   --IF @cPAStrategyKey = ''  
   --BEGIN  
   --   SET @nErrNo = 113951  
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet  
   --   GOTO Quit  
   --END  
     
   -- Check putaway strategy valid  
   --IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)  
   --BEGIN  
   --   SET @nErrNo = 113952  
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey  
   --   GOTO Quit  
   --END  
     
  
   DECLARE C_PAStrategy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT PAStrategyKey   
   FROM @tPAStrategyList  
   ORDER BY PAStrategyKey   
     
   OPEN C_PAStrategy    
   FETCH NEXT FROM C_PAStrategy INTO  @cPAStrategyKey  
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
           
      IF EXISTS ( SELECT 1 FROM dbo.PutawayStrategyDetail WITH (NOLOCK)   
                  WHERE PutawayStrategyKey = @cPAStrategyKey )   
      BEGIN     
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
            , @c_PAStrategyKey   = @cPAStrategyKey  
            , @n_PABookingKey    = @nPABookingKey     OUTPUT  
           
         IF ISNULL(@cSuggLoc,'')  <> ''   
            BREAK  
      END  
        
      FETCH NEXT FROM C_PAStrategy INTO  @cPAStrategyKey     
     
   END                         
   CLOSE C_PAStrategy    
   DEALLOCATE C_PAStrategy   
     
   --SELECT @cFromLOC '@cFromLOC' , @cID '@cID' , @cSuggLOC '@cSuggLOC' , @nPABookingKey '@nPABookingKey'   
  
   -- Lock suggested location  
   IF @cSuggLOC <> ''   
   BEGIN  
      -- Handling transaction  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_1819ExtPASP17 -- For rollback or commit only our own transaction  
        
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
     
      COMMIT TRAN rdt_1819ExtPASP17 -- Only commit change made here  
   END  
        
     
     
   IF @cSuggLOC = ''  
   BEGIN  
      SET @cPickAndDropLOC = ''  
      SET @nErrNo = 113953  
   END  
     
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1819ExtPASP17 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO