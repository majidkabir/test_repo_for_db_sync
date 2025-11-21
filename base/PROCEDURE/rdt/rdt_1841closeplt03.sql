SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_1841ClosePlt03                                     */  
/*                                                                         */  
/* Purpose: Get UCC stat                                                   */  
/*                                                                         */  
/* Called from: rdt_PrePalletizeSort_ClosePallet                           */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date        Rev  Author     Purposes                                    */  
/* 2021-07-07  1.0  Chermaine  WMS-17254. Created (dup rdt_1841ClosePlt01) */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_1841ClosePlt03] (  
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
           @c_FinalLoc        NVARCHAR( 20),
           @cUdf06            NVARCHAR( 30),
           @cUdf07            NVARCHAR( 30),
           @cExternReceiptKey NVARCHAR( 20)

   
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
            @nFullPlt          NVARCHAR( 1),
            @cOldID            NVARCHAR( 18)
  
  SET @cToLoc = ''
  SET @cOldID = ''
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1841ClosePlt03  
  
   IF @cToID = '99'  
      SET @cToID = ''  
  
   SET @cCurUCC = ''  
   SET @cCurID = ''  
   
   IF @cLane <> ''
   BEGIN
   	IF NOT EXISTS  (SELECT TOP 1 1 
   	               FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
   	               WHERE ReceiptKey = @cReceiptKey  
                     AND Loc = @cLane
                     AND   [Status] = '1')
      BEGIN
      	SET @nErrNo = 170557  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lane
         GOTO RollBackTran  
      END
   END
  
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
   ORDER BY ID
   
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
            --@cExternReceiptKey = ExternReceiptKey  
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

      
      IF rdt.RDTGetConfig( @nFunc, 'CreatePATask', @cStorerkey) = '1'  
      BEGIN
      	IF @cOldID <> @cID --insert Task per ID
      	BEGIN
      		--IF (ISNULL(@cUdf06,'') = '') AND (ISNULL(@cUdf07,'') = '')
      	   IF NOT EXISTS (SELECT 1
                        FROM UCC U WITH (NOLOCK)
                        JOIN rdt.rdtPreReceiveSort PRL WITH (NOLOCK) ON (U.UCCNo = PRL.UCCNo AND U.SKU = PRL.SKU AND U.Storerkey = PRL.StorerKey)
                        WHERE PRL.StorerKey = @cStorerkey
                        AND PRL.ID = @cID
                        AND PRL.receiptKey = @cReceiptKey 
      	               AND (U.Userdefined07 = '1' OR U.Userdefined06 = '1'))
            BEGIN      
               EXECUTE dbo.nspg_getkey    
                  @KeyName       = 'TaskDetailKey',  
                  @fieldlength   = 10,  
                  @keystring     = @cTaskdetailkey   OUTPUT,  
                  @b_Success     = @bSuccess         OUTPUT,  
                  @n_err         = @nErrNo           OUTPUT,  
                  @c_errmsg      = @cErrMsg          OUTPUT    
  
               IF NOT @bSuccess = 1 OR ISNULL( @cTaskdetailkey, '') = ''  
               BEGIN  
                  SET @nErrNo = 170554  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
                  GOTO RollBackTran  
               END  
      
      	      INSERT dbo.TASKDETAIL   --(yeekung01)
               ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,  
                  FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,  
                  Status, LogicalFromLoc, LogicalToLoc,finalloc, PickMethod)    
               VALUES    
               ( @cTaskdetailkey, 'ASTPA', @cStorerkey, '', '', 0, 0, 0, '',   
                  @cLane, @cID, @cToLoc, @cID, 'rdt_1841ClosePlt03', '', '5', '9',  
                  '0', '', '','', 'FP')  
                  --'0', @cLogicalLocation, @cToLogicalLocation,'', 'FP')  
              
               IF @@ERROR <> 0    
               BEGIN  
                  SET @nErrNo = 170555  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreatePATaskE 
                  GOTO RollBackTran  
               END      
            END
            SET @cOldID = @cID
      	END
      END 

      UPDATE RDT.RDTPreReceiveSort SET   
         [Status] = '9',  
         EditWho = SUSER_SNAME(),  
         EditDate = GETDATE()  
      WHERE Rowref = @nRowRef  
  
      IF @@ERROR <> 0    
      BEGIN  
         SET @nErrNo = 170556  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail  
         GOTO RollBackTran  
      END   
           
      FETCH NEXT FROM @curPRL INTO @nRowRef, @cID, @cUCC, @cUCCSKU, @nUCCQty  
   END  
     
  
	GOTO Quit  

RollBackTran:  
   ROLLBACK TRAN rdt_1841ClosePlt03  

Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1841ClosePlt03  

Fail:  

GO