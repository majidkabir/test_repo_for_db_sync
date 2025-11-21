SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1841ClosePlt01                                  */  
/*                                                                      */  
/* Purpose: Get UCC stat                                                */  
/*                                                                      */  
/* Called from: rdt_PrePalletizeSort_ClosePallet                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2020-01-29  1.0  James      WMS11430. Created                        */  
/* 2020-08-01  1.1  YeeKung    WMS14059 Change toloc from finalloc      */
/*                              to PND_IN(yeekung01)                    */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1841ClosePlt01] (  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cStorerkey      NVARCHAR( 15),  
   @cFacility       NVARCHAR( 5),  
   @cReceiptKey     NVARCHAR( 20),  
   @cLane           NVARCHAR( 10),  
   @cPosition       NVARCHAR( 20),  
   @cToID           NVARCHAR( 18),  
   @nErrNo          INT            OUTPUT,  
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount        INT,  
           @bSuccess          INT,  
           @nRowCount         INT,  
           @cDefaultUOM       NVARCHAR( 10),  
           @cLocationCategory NVARCHAR( 10),  
           @cTaskdetailkey    NVARCHAR( 10),  
           @cToLoc            NVARCHAR( 10),  
           @cToLogicalLocation   NVARCHAR( 10),  
           @cLogicalLocation     NVARCHAR( 10),  
           @nPABookingKey     INT,  
           @nRowRef           INT,  
           @nUCCQty           INT,  
           @cUserName         NVARCHAR( 18),  
           @cPOKey            NVARCHAR( 10),  
           @cReceiptLineNumber   NVARCHAR( 5),  
           @cUCCSKU           NVARCHAR( 20),  
           @cID               NVARCHAR( 18),  
           @cUCC              NVARCHAR( 20),  
           @cCurID            NVARCHAR( 18),  
           @cCurUCC           NVARCHAR( 20),  
           @cLottable01       NVARCHAR( 18),  
           @cLottable02       NVARCHAR( 18),  
           @cLottable03       NVARCHAR( 18),  
           @dLottable04       DATETIME,  
           @dLottable05       DATETIME,  
           @cLottable06       NVARCHAR( 30),  
           @cLottable07       NVARCHAR( 30),  
           @cLottable08       NVARCHAR( 30),  
           @cLottable09       NVARCHAR( 30),  
           @cLottable10       NVARCHAR( 30),  
           @cLottable11       NVARCHAR( 30),  
           @cLottable12       NVARCHAR( 30),  
           @dLottable13       DATETIME,  
           @dLottable14       DATETIME,  
           @dLottable15       DATETIME,  
           @cUOM              NVARCHAR( 10),  
           @cUOM_Desc         NVARCHAR( 10),
           @c_LOCAisle        NVARCHAR( 20),--(yeekung01)  
           @c_FinalLoc        NVARCHAR( 20)

   
   DECLARE  @cPutawayZone nvarchar(20),
            @cPAStrategyKey nvarchar(20),
            @cProductCategory nvarchar(5),
            @cCode NVARCHAR(10),
            @cPltMaxCnt INT,
            @nPltCtnCount INT,    
            @cPickAndDropLOC   NVARCHAR( 10),
            @cFitCasesInAisle  NVARCHAR( 1) ,
            @cParam1           NVARCHAR(10)  ,
            @cParam2           NVARCHAR( 20) ,
            @cParam3           NVARCHAR( 20) ,
            @cParam4           NVARCHAR( 20) ,
            @cParam5           NVARCHAR( 20) ,
            @nFullPlt          NVARCHAR( 1)
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1841ClosePlt01  
  
   IF @cToID = '99'  
      SET @cToID = ''  
  
   SET @cCurUCC = ''  
   SET @cCurID = ''  
  
   SELECT @cUserName = USERNAME,   
          @cUOM = V_UOM   
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
     
   DECLARE @curPRL CURSOR  
   SET @curPRL = CURSOR FOR  
   SELECT RowRef, ID, UCCNo, SKU, Qty  
   FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
   AND   (( @cLane = '') OR ( Loc = @cLane))  
   AND   (( @cToID = '') OR ( ID = @cToID))  
   AND   [Status] = '1'  
   OPEN @curPRL  
   FETCH NEXT FROM @curPRL INTO @nRowRef, @cID, @cUCC, @cUCCSKU, @nUCCQty  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @nUCCQty = 0  
         SELECT @nUCCQty = Qty  
         FROM dbo.UCC WITH (NOLOCK)  
         WHERE Storerkey = @cStorerkey  
         AND   UCCNo = @cUCC  
  
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                  WHERE ReceiptKey = @cReceiptKey  
                  AND   Lottable10 = @cUCC)  
      BEGIN  
         SELECT TOP 1   
            @cLottable01 = Lottable01,  
            @cLottable02 = Lottable02,  
            @cLottable03 = Lottable03,  
            @dLottable04 = Lottable04,  
            @cLottable06 = Lottable06,  
            @cLottable07 = Lottable07,  
            @cLottable08 = Lottable08,  
            @cLottable09 = Lottable09,  
            @cLottable11 = Lottable11,  
            @cLottable12 = Lottable12,  
            @dLottable13 = Lottable13,  
            @dLottable14 = Lottable14,  
            @dLottable15 = Lottable15,  
            @cPOKey = POKey  
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   Sku = @cUCCSKU  
         AND   FinalizeFlag <> 'Y'  
         ORDER BY 1  
      END  
      ELSE  
      BEGIN  
         SELECT @cLottable01 = Lottable01,  
                @cLottable02 = Lottable02,  
                @cLottable03 = Lottable03,  
                @dLottable04 = Lottable04,  
                @cLottable06 = Lottable06,  
                @cLottable07 = Lottable07,  
                @cLottable08 = Lottable08,  
                @cLottable09 = Lottable09,  
                @cLottable11 = Lottable11,  
                @cLottable12 = Lottable12,  
                @dLottable13 = Lottable13,  
                @dLottable14 = Lottable14,  
                @dLottable15 = Lottable15  
         FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
         WHERE Rowref = @nRowRef  
      END  
  
      SET @cLottable10 = @cUCC  
                 
      SET @nErrNo = 0  
      EXEC rdt.rdt_Receive_V7      
         @nFunc          = @nFunc,  
         @nMobile        = @nMobile,  
         @cLangCode      = @cLangCode,  
         @nErrNo         = @nErrNo  OUTPUT,  
         @cErrMsg        = @cErrMsg OUTPUT,  
         @cStorerKey     = @cStorerKey,  
         @cFacility      = @cFacility,  
         @cReceiptKey    = @cReceiptKey,  
         @cPOKey         = @cPOKey,  
         @cToLOC         = @cLane,  
         @cToID          = @cID,   
         @cSKUCode       = '',  
         @cSKUUOM        = '',  
         @nSKUQTY        = 0,  
         @cUCC           = @cUCC,  
         @cUCCSKU        = @cUCCSKU,  
         @nUCCQTY        = @nUCCQTY,  
         @cCreateUCC     = '0',  
         @cLottable01    = @cLottable01,  
         @cLottable02    = @cLottable02,     
         @cLottable03    = @cLottable03,  
         @dLottable04    = @dLottable04,  
         @dLottable05    = NULL,  
         @cLottable06    = @cLottable06,  
         @cLottable07    = @cLottable07,  
         @cLottable08    = @cLottable08,  
         @cLottable09    = @cLottable09,  
         @cLottable10    = @cLottable10,  
         @cLottable11    = @cLottable11,  
         @cLottable12    = @cLottable12,  
         @dLottable13    = @dLottable13,  
         @dLottable14    = @dLottable14,  
         @dLottable15    = @dLottable15,  
         @nNOPOFlag      = 1,  
         @cConditionCode = 'OK',  
         @cSubreasonCode = '',  
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT,    
         @cDebug         = '0'    
  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      --SELECT @cUOM_Desc = Pack.PackUOM3  
      --FROM dbo.SKU S WITH (NOLOCK)   
      --JOIN dbo.Pack Pack WITH (NOLOCK) ON ( S.PackKey = Pack.PackKey)  
      --WHERE StorerKey = @cStorerKey  
      --AND   SKU = @cUCCSKU  
        
      --SET @nErrNo = 0  
      --UPDATE dbo.RECEIPTDETAIL SET   
      --   UOM = @cUOM_Desc,   
      --   EditDate = GETDATE(),   
      --   EditWho = SUSER_SNAME()  
      --WHERE ReceiptKey = @cReceiptKey  
      --AND   ReceiptLineNumber = @cReceiptLineNumber  
      --SET @nErrNo = @@ERROR  
        
      --IF @nErrNo <> 0  
      --   GOTO RollBackTran  
  
      IF @cCurID <> @cID  
      BEGIN  
         -- Create PA Task  
         IF rdt.RDTGetConfig( @nFunc, 'CreatePATask', @cStorerkey) = '1'  
         BEGIN 
                         
            SELECT TOP 1 @cToLoc = LOC.LOC  
            FROM LOC LOC WITH (NOLOCK)  
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC )   
            WHERE LOC.Facility = @cFacility  
            AND LOC.LocationCategory IN( 'PND'  ,'PND_IN')
            AND LOC.STATUS = 'OK'  
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            HAVING ISNULL(SUM(LLI.QTY+LLI.PendingMoveIn),0)  = 0   
            ORDER BY LOC.LogicalLocation, LOC.Loc  

            --IF @@ROWCOUNT = 0  
            --BEGIN  
            --   SET @nErrNo = 148101  
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PALoc Found  
            --   GOTO RollBackTran  
            --END 

            SELECT 
                  @cProductCategory = BUSR7,  
                  @cPutawayZone = PutawayZone  
            FROM dbo.SKU WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cUCCSKU  

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
            AND   UCC.LOC = @cLane  
            AND   UCC.ID = @cID  
            AND   UCC.Status = '1'  
            AND   LOC.Facility = @cFacility 

            -- Define full or loose pallet  
            IF @nPltCtnCount < @cPltMaxCnt  
            BEGIN  
               SET @nFullPlt = 0  
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
                  , @c_fromloc         = @cLane    
                  , @n_qty             = 0    
                  , @c_uom             = '' -- not used    
                  , @c_packkey         = '' -- optional, if pass-in SKU    
                  , @n_putawaycapacity = 0    
                  , @c_final_toloc     = @c_FinalLoc        OUTPUT    
                  , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT    
                  , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT    
                  , @c_Param1          = @cParam1  
                  , @c_Param2          = @cParam2  
                  , @c_Param3          = @cParam3  
                  , @c_Param4          = @cParam4  
                  , @c_Param5          = @cParam5  
                  , @c_PAStrategyKey   = @cPAStrategyKey   

            --SELECT @cToLoc=code
            --FROM dbo.CODELKUP WITH (NOLOCK)  
            --WHERE LISTNAME = 'PND'  
            --AND storerkey=@cStorerkey
            --AND code2=@c_FinalLoc   

            SELECT @cToLogicalLocation = LogicalLocation  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE LOC = @cToLoc  
  
            SELECT @cLogicalLocation = LogicalLocation  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE LOC = @cLane  
  
            -- Booking  
            SET @nPABookingKey = 0  
            EXEC rdt.rdt_Putaway_PendingMoveIn   
               @cUserName     = @cUserName  
               ,@cType         = 'LOCK'  
               ,@cFromLOC      = @cLane  
               ,@cFromID       = @cToID  
               ,@cSuggestedLOC = @cToLOC  
               ,@cStorerKey    = @cStorerKey  
               ,@nErrNo        = @nErrNo  OUTPUT  
               ,@cErrMsg       = @cErrMsg OUTPUT  
               ,@cSKU          = ''  
               ,@nPutawayQTY   = 0  
               ,@cUCCNo        = ''  
               ,@cFromLOT      = ''  
               ,@cToID         = @cToID  
               ,@cTaskDetailKey = ''  
               ,@nFunc         = @nFunc  
               ,@nPABookingKey = @nPABookingKey OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBackTran  
     
            SELECT @bSuccess = 1    
            EXECUTE dbo.nspg_getkey    
               @KeyName       = 'TaskDetailKey',  
               @fieldlength   = 10,  
               @keystring     = @cTaskdetailkey   OUTPUT,  
               @b_Success     = @bSuccess         OUTPUT,  
               @n_err         = @nErrNo           OUTPUT,  
               @c_errmsg      = @cErrMsg          OUTPUT    
  
            IF NOT @bSuccess = 1 OR ISNULL( @cTaskdetailkey, '') = ''  
            BEGIN  
               SET @nErrNo = 148102  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
               GOTO RollBackTran  
            END  
  
            INSERT dbo.TASKDETAIL   --(yeekung01)
            ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,  
               FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,  
               Status, LogicalFromLoc, LogicalToLoc,finalloc, PickMethod)    
            VALUES    
            ( @cTaskdetailkey, 'ASTPA', @cStorerkey, '', '', 0, 0, 0, '',   
               @cLane, @cToID, @cToLoc, @cToID, 'rdt_1841ClosePlt01', '', '5', '9',  
               '0', @cLogicalLocation, @cToLogicalLocation,@c_FinalLoc, 'FP')  
              
            IF @@ERROR <> 0    
            BEGIN  
               SET @nErrNo = 148103  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreatePATaskFail  
               GOTO RollBackTran  
            END         
         END  
     
         SET @cCurID = @cID  
      END  
  
      UPDATE RDT.RDTPreReceiveSort SET   
         [Status] = '9',  
         EditWho = SUSER_SNAME(),  
         EditDate = GETDATE()  
      WHERE Rowref = @nRowRef  
  
      IF @@ERROR <> 0    
      BEGIN  
         SET @nErrNo = 148104  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail  
         GOTO RollBackTran  
      END   
           
      FETCH NEXT FROM @curPRL INTO @nRowRef, @cID, @cUCC, @cUCCSKU, @nUCCQty  
   END  
     
  
	GOTO Quit  

RollBackTran:  
   ROLLBACK TRAN rdt_1841ClosePlt01  

Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1841ClosePlt01  

Fail:  

GO