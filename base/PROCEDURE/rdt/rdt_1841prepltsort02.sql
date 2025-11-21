SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1841PrePltSort02                                */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdt_PrePltSortGetPos                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-04-06  1.0  James      WMS-16725. Created                       */
/* 2022-09-29  1.1  James      WMS-20888 Enhance receiving logic to     */
/*                             cater UCC with multi line in RD (james01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_1841PrePltSort02] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerkey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cReceiptKey     NVARCHAR( 20),
   @cLane           NVARCHAR( 10),
   @cUCC            NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @cType           NVARCHAR( 10), 
   @cCreateUCC      NVARCHAR( 1),       
   @cLottable01     NVARCHAR( 18),      
   @cLottable02     NVARCHAR( 18),      
   @cLottable03     NVARCHAR( 18),      
   @dLottable04     DATETIME,           
   @dLottable05     DATETIME,           
   @cLottable06     NVARCHAR( 30),      
   @cLottable07     NVARCHAR( 30),      
   @cLottable08     NVARCHAR( 30),      
   @cLottable09     NVARCHAR( 30),      
   @cLottable10     NVARCHAR( 30),      
   @cLottable11     NVARCHAR( 30),      
   @cLottable12     NVARCHAR( 30),      
   @dLottable13     DATETIME,           
   @dLottable14     DATETIME,           
   @dLottable15     DATETIME,           
   @cPosition       NVARCHAR( 20)  OUTPUT,
   @cToID           NVARCHAR( 18)  OUTPUT,
   @cClosePallet    NVARCHAR( 1)   OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nTranCount          INT,
      @nUCCQty             INT,
      @cUCCSKU             NVARCHAR( 20),
      @nRowCount           INT,
      @nRowRef             INT,
      @cUserName           NVARCHAR( 18),
      @cID                 NVARCHAR( 18),
      @cPOKey              NVARCHAR( 10),
      @cSKUUOM             NVARCHAR( 10),
      @cReceiptLineNumber  NVARCHAR( 5),
      @cMixSKUUCC          NVARCHAR( 1),
      @nQtyExpected        INT = 0,
      @nQtyReceived        INT = 0,
      @cReceiptLineNumberOutput NVARCHAR( 5),
      @curRD               CURSOR
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1841PrePltSort02

   IF @cType = 'GET.POS'
   BEGIN
      IF EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND   UCCNo = @cUCC
                  AND   Func = @nFunc)
      BEGIN
         SET @nErrNo = 165651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
         GOTO RollBackTran
      END

      -- Check whether ucc is mix sku
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   UserDefine01 = @cUCC
                  GROUP BY UserDefine01
                  HAVING COUNT( DISTINCT SKU) > 1)
      BEGIN
         SET @cMixSKUUCC = 1
         
         -- UCC mix sku, always retrieve reserved loc
         SELECT @cPosition = Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'PreRcvLane'
         AND   Short = 'R'
         AND   Storerkey = @cStorerkey
         
         IF @@ROWCOUNT = 0 OR ISNULL( @cPosition, '') = ''
         BEGIN
            SET @nErrNo = 165652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMixSKULoc
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SET @cMixSKUUCC = '0'
         
         SELECT TOP 1 @cSKU = SKU
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine01 = @cUCC
         
         SELECT TOP 1 @cPosition = R.Position
         FROM rdt.rdtPreReceiveSort R WITH (NOLOCK)
         WHERE R.StorerKey = @cStorerkey
         AND   ReceiptKey = @cReceiptKey
         AND   R.SKU = @cSKU
         AND   R.[Status] = '1'
         AND   R.Func = @nFunc
         AND NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                          WHERE LISTNAME = 'PreRcvLane' 
                          AND   R.Position = C.Code
                          AND   Short = 'R' 
                          AND   Storerkey = @cStorerkey)
         ORDER BY 1
         
         -- New SKU, no position assign yet
         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1 @cPosition = Code
            FROM dbo.CODELKUP C WITH (NOLOCK)
            WHERE LISTNAME = 'PreRcvLane'
            AND   Short <> 'R'
            AND   Storerkey = @cStorerkey
            AND   NOT EXISTS ( SELECT 1 
                               FROM rdt.rdtPreReceiveSort R WITH (NOLOCK)
                               WHERE C.Code = R.Position
                               AND   R.ReceiptKey = @cReceiptKey
                               AND   R.[Status] = '1'
                               AND   R.Func = @nFunc)
            ORDER BY 1
            
            IF @@ROWCOUNT = 0 OR ISNULL( @cPosition, '') = ''
            BEGIN
               SET @nErrNo = 165653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup SKULoc
               GOTO RollBackTran
            END
         END
      END      
      
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU, ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC
      GROUP BY SKU
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQty
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                           WHERE UCCNo = @cUCC
                           AND   SKU = @cUCCSKU
                           AND   StorerKey = @cStorerKey
                           AND   Func = @nFunc)
         BEGIN
            INSERT INTO rdt.rdtPreReceiveSort
            (Mobile, Func, Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, 
            LOC, ID, Position, SourceType, UDF01, UDF02, [Status],
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
            AddWho, AddDate, EditWho, EditDate) VALUES 
            (@nMobile, @nFunc, @cFacility, @cStorerKey, @cReceiptKey, @cUCC, @cUCCSKU, @nUCCQty, 
            @cLane, '', @cPosition, 'rdt_1841PrePltSort02', '', '', '1',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cUserName, GETDATE(), @cUserName, GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 165654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Log Fail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE rdt.rdtPreReceiveSort WITH (ROWLOCK) SET 
               Position = @cPosition,
               EditWho = @cUserName, 
               EditDate = GETDATE()
            WHERE UCCNo = @cUCC
            AND   SKU = @cUCCSKU
            AND   StorerKey = @cStorerKey
            AND   ReceiptKey = @cReceiptKey
            AND   Loc = @cLane
            AND   [Status] = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 165655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
               GOTO RollBackTran
            END
         END
            
         FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQty
      END
      
      SET @nUCCQty = 0
      SELECT @nUCCQty = SUM( QtyExpected)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC
      
      SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ReceiptLineNumber
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE StorerKey = @cStorerkey
      AND   ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC 
      AND   FinalizeFlag <> 'Y'
      ORDER BY 1
      OPEN @curRD
      FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT  
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
            @cPOKey = POKey,
            @cUCCSKU = Sku, 
            @nQtyExpected = QtyExpected
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber

         SELECT @cSKUUOM = P.PackUOM3
         FROM dbo.SKU S WITH (NOLOCK)
         JOIN dbo.PACK P WITH (NOLOCK) ON ( S.PACKKey = P.PackKey) 
         WHERE s.StorerKey = @cStorerkey
         AND   S.Sku = @cUCCSKU

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
            @cSKUCode       = @cUCCSKU,
            @cSKUUOM        = @cSKUUOM,
            @nSKUQTY        = @nQtyExpected,
            @cUCC           = '',
            @cUCCSKU        = '',
            @nUCCQTY        = 0,
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
            @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT,  
            @cDebug         = '0'  

         IF @nErrNo <> 0
            GOTO RollBackTran

         SET @nQtyReceived = @nQtyReceived + @nQtyExpected
            
         IF @nQtyReceived > @nUCCQty
         BEGIN
            SET @nErrNo = 165671
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive
            GOTO RollBackTran
         END
      
         FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
      END

      SET @cToID = ''
      SELECT TOP 1 @cToID = ID
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   [Status] = '1'
      AND   Loc = @cLane
      ORDER BY 1 DESC
   END

   IF @cType = 'UPD.ID'
   BEGIN
      IF EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey 
                  AND   ID = @cToID 
                  AND   [Status] = '9')
      BEGIN
         SET @nErrNo = 165656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Closed
         GOTO RollBackTran
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
                  WHERE ReceiptKey <> @cReceiptKey 
                  AND   ID = @cToID 
                  AND   [Status] = '1')
      BEGIN
         SET @nErrNo = 165659
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet In Used
         GOTO RollBackTran
      END
      
      UPDATE RDT.rdtPreReceiveSort WITH (ROWLOCK) SET
         ID = @cToID
      WHERE ReceiptKey = @cReceiptKey
      AND   LOC = @cLane
      AND   UCCNo = @cUCC
      AND   [Status] = '1'
      SET @nRowCount = @@ROWCOUNT
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 165657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
         GOTO RollBackTran
      END
      
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 165658
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
         GOTO RollBackTran
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort PRE WITH (NOLOCK)
                                     WHERE RD.ReceiptKey = PRE.ReceiptKey
                                     AND   RD.UserDefine01 = PRE.UCCNo
                                     AND   PRE.[Status] = '1'))
         SET @cClosePallet = ''
      ELSE
         SET @cClosePallet = '1'
   END
   
   COMMIT TRAN rdt_1841PrePltSort02
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1841PrePltSort02
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO