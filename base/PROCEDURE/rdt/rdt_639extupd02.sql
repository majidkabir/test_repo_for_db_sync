SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_639ExtUpd02                                     */    
/* Purpose: Update lottablexx = new ucc no using transfer               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2021-04-30   Chermaine 1.0   WMS-16886. Created (dup rdt_639ExtUpd01)*/    
/************************************************************************/    
CREATE PROCEDURE [RDT].[rdt_639ExtUpd02]    
   @nMobile         INT,   
   @nFunc           INT,   
   @cLangCode       NVARCHAR(3),   
   @nStep           INT,   
   @nInputKey       INT,   
   @cStorerKey      NVARCHAR(15),   
   @cFacility       NVARCHAR(5),   
   @cToLOC          NVARCHAR(10),   
   @cToID           NVARCHAR(18),   
   @cFromLOC        NVARCHAR(10),   
   @cFromID         NVARCHAR(18),   
   @cSKU            NVARCHAR(20),   
   @nQTY            INT,   
   @cUCC            NVARCHAR(20),   
   @cLottable01     NVARCHAR(18),  
   @cLottable02     NVARCHAR(18),  
   @cLottable03     NVARCHAR(18),  
   @dLottable04     DATETIME,  
   @dLottable05     DATETIME,  
   @cLottable06     NVARCHAR(18),  
   @cLottable07     NVARCHAR(18),  
   @cLottable08     NVARCHAR(18),  
   @cLottable09     NVARCHAR(18),  
   @cLottable10     NVARCHAR(18),  
   @cLottable11     NVARCHAR(18),  
   @cLottable12     NVARCHAR(18),  
   @dLottable13     DATETIME,  
   @dLottable14     DATETIME,  
   @dLottable15     DATETIME,     
   @tExtUpdateVar   VARIABLETABLE READONLY,   
   @nErrNo          INT OUTPUT,   
   @cErrMsg         NVARCHAR(20) OUTPUT       
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount           INT  
   DECLARE @cToLottable01        NVARCHAR( 18),   
           @cToLottable02        NVARCHAR( 18),   
           @cToLottable03        NVARCHAR( 18),   
           @dToLottable04        DATETIME,   
           @dToLottable05        DATETIME,   
           @cToLottable06        NVARCHAR( 30),   
           @cToLottable07        NVARCHAR( 30),   
           @cToLottable08        NVARCHAR( 30),   
           @cToLottable09        NVARCHAR( 30),   
           @cToLottable10        NVARCHAR( 30),   
           @cToLottable11        NVARCHAR( 30),   
           @cToLottable12        NVARCHAR( 30),   
           @dToLottable13        DATETIME,   
           @dToLottable14        DATETIME,   
           @dToLottable15        DATETIME,  
           @cLOT                 NVARCHAR( 10),  
           @cNewLOT              NVARCHAR( 10),  
           @cTransferLineNumber  NVARCHAR( 5),  
           @cTransferKey         NVARCHAR( 10),  
           @cPackkey             NVARCHAR( 10),  
           @cUOM                 NVARCHAR( 10),  
           @cLabelPrinter        NVARCHAR( 10),  
           @cDataWindow          NVARCHAR( 50),  
           @cTargetDB            NVARCHAR( 20),  
           @bSuccess             INT,  
           @nUCC_Qty             INT,  
           @nTempUCC_Qty         INT,  
           @nChvQty              INT,  
           @nSUM_ChnQty          INT,  
           @nTempChvQty          INT,  
           @ndebug               INT = 0  
  
  
   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   DECLARE @cLong       NVARCHAR( 30)  
  
   --IF SUSER_SNAME() = 'jameswong'  
   --   SET @ndebug = 1  
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_639ExtUpd02 -- For rollback or commit only our own transaction  
  
   -- Move To UCC   
   IF @nFunc = 639    
   BEGIN    
      IF @nStep = 7 -- UCC  
      BEGIN  
         SELECT @cLOT = LOT  
         FROM dbo.UCC WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   UCCNo = @cUCC  
         ORDER BY 1  
           
         -- Get tolottablexx  
         SELECT @cToLottable01 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '01'  
         AND   code2 = @nFunc  
  
         SELECT @cToLottable02 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '02'  
         AND   code2 = @nFunc  
                    
         SELECT @cToLottable03 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '03'  
         AND   code2 = @nFunc  
           
         SELECT @dToLottable05 = MIN( Lottable05)  
         FROM dbo.LOTATTRIBUTE WITH (NOLOCK)  
         WHERE Lot = @cLOT  
  
         SELECT @cToLottable06 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '06'  
         AND   code2 = @nFunc  
           
         SELECT @cToLottable07 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '07'  
         AND   code2 = @nFunc  
  
           
         SELECT @cToLottable09 = Long  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'UADLOT'  
         AND   StorerKey = @cStorerKey  
         AND   Code = '09'  
         AND   code2 = @nFunc  
         SET @cToLottable10 = CAST( @nQty AS NVARCHAR( 5))  
         SET @cToLottable11 = @cUCC  
  
         DECLARE CUR_TRANSFER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT LOT, ISNULL( SUM ( QTY), 0)  
         FROM dbo.UCC WITH (NOLOCK)   
         WHERE STORERKEY = @cStorerKey  
         AND   UCCNo = @cUCC  
         AND   SKU = @cSKU  
         AND   [Status] = '1'  
         GROUP BY LOT  
         OPEN CUR_TRANSFER  
         FETCH NEXT FROM CUR_TRANSFER INTO @cLOT, @nUCC_Qty  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF @nUCC_Qty > @nQty  
               SET @nQty = @nUCC_Qty  
  
            SELECT @cLottable01 = Lottable01,   
                   @cLottable02 = Lottable02,   
                   @cLottable03 = Lottable03,   
                   @dLottable04 = Lottable04,   
                   @dLottable05 = Lottable05,   
                   @cLottable06 = Lottable06,   
                   @cLottable07 = Lottable07,   
                   @cLottable08 = Lottable08,   
                   @cLottable09 = Lottable09,   
                   @cLottable10 = Lottable10,   
                   @cLottable11 = Lottable11,   
                   @cLottable12 = Lottable12,   
                   @dLottable13 = Lottable13,   
                   @dLottable14 = Lottable14,   
                   @dLottable15 = Lottable15  
            FROM dbo.LOTAttribute WITH (NOLOCK)  
            WHERE LOT = @cLOT  
  
            IF ISNULL( @cTransferKey, '') = ''  
            BEGIN  
               SELECT @bSuccess = 0  
               EXECUTE nspg_getkey  
                  @KeyName       = 'TRANSFER',  
                  @fieldlength   = 10,  
                  @keystring     = @cTransferKey   OUTPUT,  
                  @b_success     = @bSuccess       OUTPUT,  
                  @n_err         = @nErrNo         OUTPUT,  
                  @c_errmsg      = @cErrMsg        OUTPUT  
           
               IF @bSuccess = 1  
               BEGIN  
                  INSERT INTO dbo.TRANSFER   
                     (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, Remarks, Facility, ToFacility)  
                  VALUES   
                     (@cTransferKey, @cStorerkey, @cStorerkey, 'NIF', 'RDTMv2UCC', 'rdt_639ExtUpd02', @cFacility, @cFacility)  
                    
                IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 167201  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFER Fail  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  SET @nErrNo = 167202  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey Fail  
                  GOTO RollBackTran  
               END  
            END  
  
  
            SELECT @cPackkey = PACK.Packkey,  
                   @cUOM = PACK.PackUOM3  
            FROM SKU SKU WITH (NOLOCK)  
            join PACK PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey  
            WHERE SKU.STORERKEY = @cStorerKey  
            AND   SKU = @cSKU  
  
  
            -- Get next LineNumber  
            SELECT @cTransferLineNumber =   
               RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM dbo.TransferDetail (NOLOCK)  
            WHERE TransferKey = @cTransferKey  
  
            INSERT INTO dbo.TRANSFERDETAIL  
            (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId,   
            FromQty, FromPackKey, FromUOM,   
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,   
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,   
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,  
            ToStorerKey, ToSku, ToLoc, ToLot, ToId, ToQty, ToPackKey, ToUOM, Status, EffectiveDate,   
            ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05,   
            ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,   
            ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,  
            UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,   
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)  
            VALUES  
            (@cTransferKey, @cTransferLineNumber, @cStorerKey, @cSKU, @cToLOC, @cLot, @cTOID,   
            @nUCC_Qty, @cPackkey, @cUOM,   
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,   
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
            @cStorerKey, @cSKU, @cToLOC, '', @cToID, @nUCC_Qty, @cPackkey, @cUOM, '0', GETDATE(),   
            @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05,   
            @cToLottable06, @cToLottable07, @cLottable08, @cToLottable09, @cToLottable10,   
            @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,  
            '', '', '', '', '', '', '', '', '', '')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 167203  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail  
               GOTO RollBackTran  
            END  
              
            --IF @ndebug = 1  
            --   SELECT * FROM TRANSFERDETAIL (NOLOCK) WHERE TransferKey = @cTransferKey  
                 
            DECLARE @curFinalize CURSOR  
            SET @curFinalize = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TransferLineNumber  
            FROM dbo.TRANSFERDETAIL WITH (NOLOCK)  
            WHERE TransferKey = @cTransferKey  
            AND   [Status] <> '9'  
            OPEN @curFinalize  
            FETCH NEXT FROM @curFinalize INTO @cTransferLineNumber  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Finalize transfer  
               UPDATE dbo.TRANSFERDETAIL WITH (ROWLOCK) SET  
                  [Status] = '9'  
               WHERE TransferKey = @cTransferKey  
               AND   TransferLineNumber = @cTransferLineNumber  
           
               IF @@ERROR <> 0  
               BEGIN  
               SET @nErrNo = 167204  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail  
                  GOTO RollBackTran  
               END  
  
               FETCH NEXT FROM @curFinalize INTO @cTransferLineNumber  
            END  
  
            -- Get the new lot # after transfer  
            SELECT @cNewLOT = Lot  
            FROM dbo.Itrn WITH (NOLOCK)  
            WHERE SourceKey = @cTransferKey + @cTransferLineNumber  
            AND   SourceType = 'ntrTransferDetailUpdate'  
            AND   TranType = 'DP'  
            AND   StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
            AND   Lottable11 = @cUCC  
  
            IF ISNULL( @cNewLOT, '') = '' OR @cNewLOT = @cLOT  
            BEGIN  
               SET @nErrNo = 167205  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Relot Fail  
               GOTO RollBackTran  
            END  
  
            -- Update the ucc with new lot  
            UPDATE dbo.UCC WITH (ROWLOCK) SET   
               LOT = @cNewLOT  
            WHERE StorerKey = @cStorerKey  
            AND   UCCNo = @cUCC  
            AND   Lot = @cLOT  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 167206  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Relot Fail  
               GOTO RollBackTran  
            END  
              
            -- Reduce qty  
            SET @nQty = @nQty - @nUCC_Qty  
  
            IF @nQty = 0  
               BREAK  
  
            FETCH NEXT FROM CUR_TRANSFER INTO @cLOT, @nUCC_Qty  
         END  
         CLOSE CUR_TRANSFER  
         DEALLOCATE CUR_TRANSFER  
      END -- IF @nStep = 7  
      
   END  -- IF @nFunc = 639  
  
   GOTO Quit  
          
   RollBackTran:  
      ROLLBACK TRAN rdt_639ExtUpd02 -- Only rollback change made here  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END  

GO