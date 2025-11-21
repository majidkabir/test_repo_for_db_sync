SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

      
/******************************************************************************/      
/* Store procedure: rdt_607ExtPA04                                            */      
/* Copyright      : LF Logistics                                              */      
/*                                                                            */      
/* Purpose: Extended putaway                                                  */      
/*                                                                            */      
/* Date         Author    Ver.  Purposes                                      */      
/* 08-02-2017   ChewKP    1.0   WMS-3836 Created                              */ 
/* 18-05-2018   SPChin    1.1   INC0235582 - Bug Fixed                        */     
/******************************************************************************/      
      
CREATE PROCEDURE [RDT].[rdt_607ExtPA04]      
   @nMobile      INT,      
   @nFunc        INT,      
   @cLangCode    NVARCHAR( 3),      
   @nStep        INT,      
   @nInputKey    INT,      
   @cStorerKey   NVARCHAR( 15),      
   @cReceiptKey  NVARCHAR( 10),      
   @cPOKey       NVARCHAR( 10),      
   @cRefNo       NVARCHAR( 20),      
   @cSKU         NVARCHAR( 20),      
   @nQTY         INT,      
   @cLottable01  NVARCHAR( 18),      
   @cLottable02  NVARCHAR( 18),      
   @cLottable03  NVARCHAR( 18),      
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30),      
   @cLottable07  NVARCHAR( 30),      
   @cLottable08  NVARCHAR( 30),      
   @cLottable09  NVARCHAR( 30),      
   @cLottable10  NVARCHAR( 30),      
   @cLottable11  NVARCHAR( 30),      
   @cLottable12  NVARCHAR( 30),      
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME,      
   @cReasonCode  NVARCHAR( 10),      
   @cID          NVARCHAR( 18),      
   @cLOC         NVARCHAR( 10),      
   @cReceiptLineNumber NVARCHAR( 10),      
   @cSuggID      NVARCHAR( 18)  OUTPUT,      
   @cSuggLOC     NVARCHAR( 10)  OUTPUT,      
   @nErrNo       INT            OUTPUT,      
   @cErrMsg      NVARCHAR( 20)  OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
         
   DECLARE @cPackKey          NVARCHAR(10)      
          ,@cRTNPA01          NVARCHAR(10)      
          ,@cABC              NVARCHAR(5)      
          ,@cPAStrategyKey01  NVARCHAR(10)       
          ,@cPAStrategyKey02  NVARCHAR(10)       
          ,@cPAStrategyKey03  NVARCHAR(10)       
          ,@cPAStrategyKey04  NVARCHAR(10)       
          ,@cPAStrategyKey05  NVARCHAR(10)       
          ,@cPACode           NVARCHAR(10)       
          ,@nCasceCnt         INT      
          ,@nPallet           INT       
          ,@nCaseCnt          INT      
          ,@cPAStrategyKey    NVARCHAR(10)      
          ,@cPickAndDropLOC   NVARCHAR( 10)        
          ,@cFitCasesInAisle  NVARCHAR( 1)         
          ,@nPABookingKey     INT                   
          ,@cUserName         NVARCHAR(18)       
          ,@nTranCount        INT      
          ,@cLot              NVARCHAR(10)
          ,@bSuccess          INT
          
                
                
   DECLARE @tPAStrategyList TABLE (PAStrategyKey NVARCHAR(10) )       
      
      
      
   IF @nFunc = 607 -- Return v7      
   BEGIN      
      IF EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND RecType = 'LOGIUT')
      BEGIN
         SET @cSuggLOC = '' 
         GOTO QUIT
      END   
      
      -- Create Visual Location Before FinalizeReceipt
      -- LOT lookup    
      SET @cLOT = ''    
      EXECUTE dbo.nsp_LotLookUp    
          @cStorerKey    
        , @cSKU    
        , @cLottable01  --''            -- @cLottable01  
        , @cLottable02  --''            -- @cLottable02  
        , @cLottable03  --''            -- @cLottable03  
        , @dLottable04  --NULL          -- @dLottable04  
        , @dLottable05  --NULL          -- @dLottable05  
        , @cLottable06  --''            -- @cLottable06  
        , @cLottable07  --''            -- @cLottable07  
        , @cLottable08  --''            -- @cLottable08  
        , @cLottable09  --''            -- @cLottable09  
        , @cLottable10  --''            -- @cLottable10  
        , @cLottable11  --''            -- @cLottable11  
        , @cLottable12  --''            -- @cLottable12  
        , @dLottable13  --NULL          -- @dLottable13  
        , @dLottable14  --NULL          -- @dLottable14  
        , @dLottable15  --NULL          -- @dLottable15  
        , @cLOT      OUTPUT    
        , @bSuccess  OUTPUT    
        , @nErrNo    OUTPUT    
        , @cErrMsg   OUTPUT    
      
      -- Create LOT if not exist    
      IF @cLOT IS NULL    
      BEGIN    
         EXECUTE dbo.nsp_LotGen    
            @cStorerKey    
          , @cSKU    
          , @cLottable01  --''            -- @cLottable01  
          , @cLottable02  --''            -- @cLottable02  
          , @cLottable03  --''            -- @cLottable03  
          , @dLottable04  --NULL          -- @dLottable04  
          , @dLottable05  --NULL          -- @dLottable05  
          , @cLottable06  --''            -- @cLottable06  
          , @cLottable07  --''            -- @cLottable07  
          , @cLottable08  --''            -- @cLottable08  
          , @cLottable09  --''            -- @cLottable09  
          , @cLottable10  --''            -- @cLottable10  
          , @cLottable11  --''            -- @cLottable11  
          , @cLottable12  --''            -- @cLottable12  
          , @dLottable13  --NULL          -- @dLottable13  
          , @dLottable14  --NULL          -- @dLottable14  
          , @dLottable15  --NULL          -- @dLottable15            
          , @cLOT     OUTPUT    
          , @bSuccess OUTPUT    
          , @nErrNo   OUTPUT    
          , @cErrMsg  OUTPUT    
      
         IF @bSuccess <> 1    
          GOTO RollbackTran    
      
         IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)    
         BEGIN    
            INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @cStorerKey, @cSKU)    
      
            IF @@ERROR <> 0    
            BEGIN    
--               SET @nErrNo = 53053    
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail    
               GOTO RollbackTran    
            END    
         END    
      END    

      
      
      -- Create ToID if not exist    
      IF @cID <> ''    
      BEGIN    
         IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID)    
         BEGIN    
            INSERT INTO ID (ID) VALUES (@cID)    
      
            IF @@ERROR <> 0    
            BEGIN    
               --SET @nErrNo = 53054    
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail    
               GOTO RollbackTran    
            END    
         END    
      END  

      ---- Create LotxLocxID 
      --IF NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
      --                WHERE StorerKey = @cStorerKey
      --                AND ID = @cID
      --                AND SKU = @cSKU
      --                AND Lot = @cLot
      --                AND Loc = @cLoc ) 
      --BEGIN
      --   INSERT INTO LotxLocxID (Lot, Loc, ID, StorerKey, SKU, Qty, QtyAllocated, QtyPicked, QtyExpected, QtyPickInProcess, PendingMoveIn, QtyReplen ) 
      --   VALUES ( @cLot, @cLoc, @cID, @cStorerKey, @cSKU, 0 , 0 , 0 , 0 , 0 , 0, 0  ) 
         
      --   IF @@ERROR <> 0    
      --   BEGIN    
      --         --SET @nErrNo = 53054    
      --         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail    
      --         GOTO RollbackTran    
      --   END  
      --END
         
      SELECT @cUserName = UserName       
      FROM rdt.rdtMobrec WITH (NOLOCK)       
      WHERE Mobile = @nMobile      
          
      SELECT TOP 1 @cLoc = ToLoc
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey 
      ORDER BY Editdate 
      
      -- Get suggested LOC, ID      
      SELECT @cPackKey = PackKey       
            ,@cABC     = ABC      
      FROM dbo.SKU WITH (NOLOCK)      
      WHERE StorerKey = @cStorerKey      
      AND SKU = @cSKU       
            
      SELECT @nPallet = Pallet       
            ,@nCaseCnt = CaseCnt       
      FROM dbo.Pack WITH (NOLOCK)      
      WHERE PackKey = @cPackKey       
            
      --SELECT @nQty '@nQty' , @nCaseCnt '@nCaseCnt'  ,@cABC '@cABC' , @nPallet '@nPallet'   
            
            
      IF @nQty < @nCaseCnt       
      BEGIN      
         SET @cPACode = 'LOGIRTN05'      
      END      
      ELSE IF @cABC = 'A' AND @nQty = @nPallet       
      BEGIN     
         SET @cPACode = 'LOGIRTN01'      
      END      
      ELSE IF @cABC = 'A' AND (@nQty < @nPallet AND @nQty >= @nCaseCnt )			--INC0235582      
      BEGIN      
         SET @cPACode = 'LOGIRTN02'      
      END      
      ELSE IF @cABC IN ('B','C') AND @nQty = @nPallet      
      BEGIN      
         SET @cPACode = 'LOGIRTN03'      
      END      
      ELSE IF @cABC IN ('B','C') AND (@nQty < @nPallet AND @nQty >= @nCaseCnt )	--INC0235582      
      BEGIN      
         SET @cPACode = 'LOGIRTN04'      
      END      
           
            
  
            
            
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
            --Update NSQLCONFIG WITH (rOwLOCK)          
            --SET NSQLValue = 2      
            --WHERE  ConfigKey = 'PutawayTraceReport'          
      
            --delete from PTRACEDETAIL where  pa_putawaystrategykey = @cPAStrategyKey    
            
            
      
            -- Suggest LOC      
            EXEC @nErrNo = [dbo].[nspRDTPASTD]      
                 @c_userid          = 'RDT'      
               , @c_storerkey       = @cStorerKey      
               , @c_lot             = ''      
               , @c_sku             = ''      
               , @c_id              = @cID      
               , @c_fromloc         = @cLOC      
               , @n_qty             = 0      
               , @c_uom             = '' -- not used      
               , @c_packkey         = '' -- optional, if pass-in SKU      
               , @n_putawaycapacity = 0      
               , @c_final_toloc     = @cSuggLOC          OUTPUT      
               , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT      
               , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT      
               , @c_PAStrategyKey   = @cPAStrategyKey      
               , @n_PABookingKey    = @nPABookingKey     OUTPUT      
                  
            --SELECT * FROM  PTRACEDETAIL  (nolocK)       
            --where pa_putawaystrategykey = @cPAStrategyKey      
      
            IF ISNULL(@cSuggLoc,'')  <> ''       
               BREAK      
         END      
               
         FETCH NEXT FROM C_PAStrategy INTO  @cPAStrategyKey         
            
      END                             
      CLOSE C_PAStrategy        
      DEALLOCATE C_PAStrategy       
  
      
  
      IF @cSuggLOC <> ''       
      BEGIN      
          
         -- Handling transaction      
         SET @nTranCount = @@TRANCOUNT      
         BEGIN TRAN  -- Begin our own transaction      
         SAVE TRAN rdt_607ExtPA04 -- For rollback or commit only our own transaction  
         
-- Update RFPutaway    
         INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)    
         VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cSuggLOC, @cID, @cUserName, @nQTY, '')    
  
        
         IF @@ERROR <> 0    
         BEGIN    
            --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
            GOTO RollbackTran    
         END    

         INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)    
         VALUES (@cLOT, @cSuggLOC, @cID, @cStorerKey, @cSKU, @nQTY)    
  
         IF @@ERROR <> 0    
         BEGIN    
            --SET @nErrNo = 53056    
            --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail    
            GOTO RollbackTran    
         END   
           
               
         --IF @cFitCasesInAisle <> 'Y'      
         --BEGIN      
         --   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'      
         --      ,@cLOC      
         --      ,@cID      
         --      ,@cSuggLOC     
         --      ,@cStorerKey      
         --      ,@nErrNo  OUTPUT      
         --      ,@cErrMsg OUTPUT      
         --      ,@nPABookingKey = @nPABookingKey OUTPUT      
         --   IF @nErrNo <> 0      
         --      GOTO RollBackTran      
         --END      
            
            
            
         COMMIT TRAN rdt_607ExtPA04 -- Only commit change made here      
      END      
   END      
      
GOTO Quit      
      
RollBackTran:      
   ROLLBACK TRAN rdt_607ExtPA04 -- Only rollback change made here      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN      
      
      
      
END 

GO