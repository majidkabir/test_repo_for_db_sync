SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_609RcptCfm01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive the line and create UCC per SKU                           */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-06-15 1.0  James      SOS371418 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_609RcptCfm01] (
   @nFunc          INT,            
   @nMobile        INT,            
   @cLangCode      NVARCHAR( 3),   
   @cStorerKey     NVARCHAR( 15),  
   @cFacility      NVARCHAR( 5),   
   @cReceiptKey    NVARCHAR( 10),  
   @cPOKey         NVARCHAR( 10),  
   @cToLOC         NVARCHAR( 10),  
   @cToID          NVARCHAR( 18),  
   @cSKUCode       NVARCHAR( 20),  
   @cSKUUOM        NVARCHAR( 10),  
   @nSKUQTY        INT,            
   @cUCC           NVARCHAR( 20),  
   @cUCCSKU        NVARCHAR( 20),  
   @nUCCQTY        INT,            
   @cCreateUCC     NVARCHAR( 1),   
   @cLottable01    NVARCHAR( 18),  
   @cLottable02    NVARCHAR( 18),  
   @cLottable03    NVARCHAR( 18),  
   @dLottable04    DATETIME,       
   @dLottable05    DATETIME,       
   @cLottable06    NVARCHAR( 30),  
   @cLottable07    NVARCHAR( 30),  
   @cLottable08    NVARCHAR( 30),  
   @cLottable09    NVARCHAR( 30),  
   @cLottable10    NVARCHAR( 30),  
   @cLottable11    NVARCHAR( 30),  
   @cLottable12    NVARCHAR( 30),  
   @dLottable13    DATETIME,       
   @dLottable14    DATETIME,       
   @dLottable15    DATETIME,       
   @nNOPOFlag      INT,            
   @cConditionCode NVARCHAR( 10),  
   @cSubreasonCode NVARCHAR( 10),  
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT 
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTY_Bal             INT,
           @nNew_QtyBal          INT,
           @nQTY                 INT,
           @nTranCount           INT,
           @bSuccess             INT,
           @cLabelPrinter        NVARCHAR( 10),
           @cReportType          NVARCHAR( 10),
           @cPrintJobName        NVARCHAR( 60),
           @cDataWindow          NVARCHAR( 50),
           @cTargetDB            NVARCHAR( 20),
           @cNewUCC              NVARCHAR( 20),
           @cCounter             NVARCHAR( 20),
           @cReceiptLineNo       NVARCHAR( 5),
           @cOri_ReceiptLineNo   NVARCHAR( 5), 
           @cOri_POLineNumber    NVARCHAR( 5), 
           @cOri_UserDefine04    NVARCHAR( 30),  
           @cOri_UserDefine10    NVARCHAR( 30), 
           @cOri_Lottable12      NVARCHAR( 30) 

   DECLARE @cLottable01Required NVARCHAR( 1)
   DECLARE @cLottable02Required NVARCHAR( 1)
   DECLARE @cLottable03Required NVARCHAR( 1)
   DECLARE @cLottable04Required NVARCHAR( 1)
   DECLARE @cLottable05Required NVARCHAR( 1)
   DECLARE @cLottable06Required NVARCHAR( 1)
   DECLARE @cLottable07Required NVARCHAR( 1)
   DECLARE @cLottable08Required NVARCHAR( 1)
   DECLARE @cLottable09Required NVARCHAR( 1)
   DECLARE @cLottable10Required NVARCHAR( 1)
   DECLARE @cLottable11Required NVARCHAR( 1)
   DECLARE @cLottable12Required NVARCHAR( 1)
   DECLARE @cLottable13Required NVARCHAR( 1)
   DECLARE @cLottable14Required NVARCHAR( 1)
   DECLARE @cLottable15Required NVARCHAR( 1)
   DECLARE @cLottableCode       NVARCHAR( 30)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_609RcptCfm01

   -- Get SKU info
   SELECT @cLottableCode = LottableCode
   FROM dbo.SKU SKU (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKUCode

   IF @cLottable01 IS NULL SET @cLottable01 = ''
   IF @cLottable02 IS NULL SET @cLottable02 = ''
   IF @cLottable03 IS NULL SET @cLottable03 = ''
   IF @dLottable04 = 0     SET @dLottable04 = NULL
   IF @dLottable05 = 0     SET @dLottable05 = NULL
   IF @cLottable06 IS NULL SET @cLottable06 = ''
   IF @cLottable07 IS NULL SET @cLottable07 = ''
   IF @cLottable08 IS NULL SET @cLottable08 = ''
   IF @cLottable09 IS NULL SET @cLottable09 = ''
   IF @cLottable10 IS NULL SET @cLottable10 = ''
   IF @cLottable11 IS NULL SET @cLottable11 = ''
   IF @cLottable12 IS NULL SET @cLottable12 = ''
   IF @dLottable13 = 0     SET @dLottable13 = NULL
   IF @dLottable14 = 0     SET @dLottable14 = NULL
   IF @dLottable15 = 0     SET @dLottable15 = NULL

   SET @cOri_ReceiptLineNo = ''
   SET @cOri_UserDefine04 = ''
   SET @cOri_UserDefine10 = ''
   SET @cOri_POLineNumber = ''

   SELECT
      @cLottable01Required = '0', @cLottable02Required = '0', @cLottable03Required = '0', @cLottable04Required = '0', @cLottable05Required = '0',
      @cLottable06Required = '0', @cLottable07Required = '0', @cLottable08Required = '0', @cLottable09Required = '0', @cLottable10Required = '0',
      @cLottable11Required = '0', @cLottable12Required = '0', @cLottable13Required = '0', @cLottable14Required = '0', @cLottable15Required = '0'

   -- Get LottableCode info
   SELECT
      @cLottable01Required = CASE WHEN LottableNo =  1 THEN Required ELSE @cLottable01Required END,
      @cLottable02Required = CASE WHEN LottableNo =  2 THEN Required ELSE @cLottable02Required END,
      @cLottable03Required = CASE WHEN LottableNo =  3 THEN Required ELSE @cLottable03Required END,
      @cLottable04Required = CASE WHEN LottableNo =  4 THEN Required ELSE @cLottable04Required END,
      @cLottable05Required = CASE WHEN LottableNo =  5 THEN Required ELSE @cLottable05Required END,
      @cLottable06Required = CASE WHEN LottableNo =  6 THEN Required ELSE @cLottable06Required END,
      @cLottable07Required = CASE WHEN LottableNo =  7 THEN Required ELSE @cLottable07Required END,
      @cLottable08Required = CASE WHEN LottableNo =  8 THEN Required ELSE @cLottable08Required END,
      @cLottable09Required = CASE WHEN LottableNo =  9 THEN Required ELSE @cLottable09Required END,
      @cLottable10Required = CASE WHEN LottableNo = 10 THEN Required ELSE @cLottable10Required END,
      @cLottable11Required = CASE WHEN LottableNo = 11 THEN Required ELSE @cLottable11Required END,
      @cLottable12Required = CASE WHEN LottableNo = 12 THEN Required ELSE @cLottable12Required END,
      @cLottable13Required = CASE WHEN LottableNo = 13 THEN Required ELSE @cLottable13Required END,
      @cLottable14Required = CASE WHEN LottableNo = 14 THEN Required ELSE @cLottable14Required END,
      @cLottable15Required = CASE WHEN LottableNo = 15 THEN Required ELSE @cLottable15Required END
   FROM rdt.rdtLottableCode WITH (NOLOCK)
   WHERE LottableCode = @cLottableCode
   AND   Function_ID = @nFunc
   AND   StorerKey = @cStorerKey

   -- Not required but pass-in value, need in matching logic below
   IF @cLottable01Required = '0' AND @cLottable01 <> ''       SET @cLottable01Required = '1'
   IF @cLottable02Required = '0' AND @cLottable02 <> ''       SET @cLottable02Required = '1'
   IF @cLottable03Required = '0' AND @cLottable03 <> ''       SET @cLottable03Required = '1'
   IF @cLottable04Required = '0' AND @dLottable04 IS NOT NULL SET @cLottable04Required = '1'
   IF @cLottable05Required = '0' AND @dLottable05 IS NOT NULL SET @cLottable05Required = '1'
   IF @cLottable06Required = '0' AND @cLottable06 <> ''       SET @cLottable06Required = '1'
   IF @cLottable07Required = '0' AND @cLottable07 <> ''       SET @cLottable07Required = '1'
   IF @cLottable08Required = '0' AND @cLottable08 <> ''       SET @cLottable08Required = '1'
   IF @cLottable09Required = '0' AND @cLottable09 <> ''       SET @cLottable09Required = '1'
   IF @cLottable10Required = '0' AND @cLottable10 <> ''       SET @cLottable10Required = '1'
   IF @cLottable11Required = '0' AND @cLottable11 <> ''       SET @cLottable11Required = '1'
   IF @cLottable12Required = '0' AND @cLottable12 <> ''       SET @cLottable12Required = '1'
   IF @cLottable13Required = '0' AND @dLottable13 IS NOT NULL SET @cLottable13Required = '1'
   IF @cLottable14Required = '0' AND @dLottable14 IS NOT NULL SET @cLottable14Required = '1'
   IF @cLottable15Required = '0' AND @dLottable15 IS NOT NULL SET @cLottable15Required = '1'

   -- Get the detail from original receipt line
   SELECT TOP 1 @cOri_ReceiptLineNo = ReceiptLineNumber, 
                @cOri_UserDefine04 = UserDefine04,
                @cOri_UserDefine10 = UserDefine10,
                @cOri_POLineNumber = POLineNumber
   FROM ReceiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   SKU = @cSKUCode
   AND   ToLOC = @cToLOC
   AND   ToID = @cToID
   AND (@cLottable01Required = '0' OR Lottable01 = @cLottable01)
   AND (@cLottable02Required = '0' OR Lottable02 = @cLottable02)
   AND (@cLottable03Required = '0' OR Lottable03 = @cLottable03)
   AND (@cLottable04Required = '0' OR IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
   AND (@cLottable05Required = '0' OR IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0))
   AND (@cLottable06Required = '0' OR Lottable06 = @cLottable06)
   AND (@cLottable07Required = '0' OR Lottable07 = @cLottable07)
   AND (@cLottable08Required = '0' OR Lottable08 = @cLottable08)
   AND (@cLottable09Required = '0' OR Lottable09 = @cLottable09)
   AND (@cLottable10Required = '0' OR Lottable10 = @cLottable10)
   AND (@cLottable11Required = '0' OR Lottable11 = @cLottable11)
   AND (@cLottable12Required = '0' OR Lottable12 = @cLottable12)
   AND (@cLottable13Required = '0' OR IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0))
   AND (@cLottable14Required = '0' OR IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0))
   AND (@cLottable15Required = '0' OR IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0))
   AND BeforeReceivedQTY > 0
   ORDER BY 1

   SET @cOri_Lottable12 = ''

   IF ISNULL( @cOri_ReceiptLineNo, '') <> ''
   BEGIN
      -- If the original line received before then need to update
      -- one of the line to make it create new line
      SET @cOri_Lottable12 = @cLottable12
      SET @cLottable12 = @cReceiptKey
   END
   ELSE
   BEGIN
      SELECT @cOri_UserDefine04 = UserDefine04,
             @cOri_UserDefine10 = UserDefine10,
             @cOri_POLineNumber = POLineNumber
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine04 = @cToLOC
      AND   SKU = @cSKUCode
   END

   --Receive
   EXEC rdt.rdt_Receive_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo   OUTPUT,
      @cErrMsg       = @cErrMsg  OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = @cPoKey,  
      @cToLOC        = @cToLOC,
      @cToID         = @cToID,
      @cSKUCode      = @cSKUCode,
      @cSKUUOM       = @cSKUUOM,
      @nSKUQTY       = @nSKUQTY,
      @cUCC          = '',
      @cUCCSKU       = '',
      @nUCCQTY       = '',
      @cCreateUCC    = '',
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = NULL,
      @cLottable06   = @cLottable06,
      @cLottable07   = @cLottable07,
      @cLottable08   = @cLottable08,
      @cLottable09   = @cLottable09,
      @cLottable10   = @cLottable10,
      @cLottable11   = @cLottable11,
      @cLottable12   = @cLottable12,
      @dLottable13   = @dLottable13,
      @dLottable14   = @dLottable14,
      @dLottable15   = @dLottable15,
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '', 
      @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

      IF ISNULL( @cOri_ReceiptLineNo, '') <> ''
      BEGIN
         -- The new receipt line will be created if the line received before
         -- Those customised field will not copy over to new file from original receipt line
         -- Need to customise the update here
         UPDATE DBO.RECEIPTDETAIL WITH (ROWLOCK) SET 
            Lottable12 = @cOri_Lottable12, 
            DuplicateFrom = @cOri_ReceiptLineNo,
            POLineNumber = @cOri_POLineNumber,
            UserDefine04 = @cOri_UserDefine04,
            UserDefine10 = @cOri_UserDefine10,
            TrafficCop = NULL
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumberOutput

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 104601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Receive fail'  
            GOTO RollBackTran
         END
      END

         -- If over receive will create new receiptdetail line
         -- For this storer, every receive need to print a receive label
         -- If split new line then need to combile them at the end
         SELECT @nNew_QtyBal = BeforeReceivedQty
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumberOutput

         IF @nNew_QtyBal < @nSKUQTY
         BEGIN
            SET @cReceiptLineNo = ''
            SELECT TOP 1 @cReceiptLineNo = ReceiptLineNumber
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   UserDefine04 = @cOri_UserDefine04
            AND   UserDefine10 = @cOri_UserDefine10
            AND   SKU = @cSKUCode
            AND   ToLOC = @cToLOC
            AND   ToID = @cToID
            AND   ReceiptLineNumber <> @cReceiptLineNumberOutput
            ORDER BY 1 DESC

            IF ISNULL( @cReceiptLineNo, '') <> ''
            BEGIN
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
                  BeforeReceivedQty = BeforeReceivedQty + @nNew_QtyBal,
                  QtyExpected = BeforeReceivedQty,
                  Lottable12 = @cOri_Lottable12,
                  TrafficCop = NULL
               WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 104602
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Receive fail'  
                  GOTO RollBackTran
               END

               DELETE FROM ReceiptDetail 
               WHERE ReceiptKey = @cReceiptKey 
               AND   ReceiptLineNumber = @cReceiptLineNumberOutput

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 104603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Receive fail'  
                  GOTO RollBackTran
               END

               SET @cReceiptLineNumberOutput = @cReceiptLineNo
            END

      END

      GOTO Quit

      RollBackTran:  
         ROLLBACK TRAN rdt_609RcptCfm01 

      Quit:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  


GO