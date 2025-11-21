SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607RcptCfm01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 17-Nov-2016  Ung       1.0   WMS-586 Add Excess stock                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607RcptCfm01]
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
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 607 -- Return v7
   BEGIN
      DECLARE @nActQTY INT
      DECLARE @nExcessQTY INT
      DECLARE @nQTYExpected INT
      DECLARE @nBeforeReceivedQTY INT

      -- Get ReceiptDetail info
      SELECT 
         @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
         @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0) 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND SKU = @cSKUCode
      
      -- Calc excess stock
      IF @nQTYExpected < (@nBeforeReceivedQTY + @nSKUQTY)
      BEGIN
         IF @nQTYExpected > @nBeforeReceivedQTY
            SET @nActQTY = @nQTYExpected - @nBeforeReceivedQTY
         ELSE
            SET @nActQTY = 0
         
         SET @nExcessQTY = @nSKUQTY - @nActQTY
      END
      ELSE
      BEGIN 
         SET @nActQTY = @nSKUQTY
         SET @nExcessQTY = 0
      END

      -- Excess stock
      IF @nExcessQTY > 0
      BEGIN
         -- Get the excess PO
         DECLARE @cExcessPOKey NVARCHAR(10)
         SET @cExcessPOKey = ''
         SELECT TOP 1 @cExcessPOKey = POKey FROM PO WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND POGroup = @cReceiptKey

         -- Lookup PODetail
         DECLARE @cPOLineNumber NVARCHAR(5)
         SET @cPOLineNumber = ''
         SELECT @cPOLineNumber = POLineNumber 
         FROM PODetail WITH (NOLOCK) 
         WHERE POKey = @cExcessPOKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKUCode
            AND ToID = @cToID
            AND Lottable01 = @cLottable01
            AND Lottable02 = @cLottable02
            AND Lottable03 = @cLottable03
            AND Lottable04 = @dLottable04
            -- AND Lottable05 = @dLottable05
            AND Lottable06 = @cLottable06
            AND Lottable07 = @cLottable07
            AND Lottable08 = @cLottable08
            AND Lottable09 = @cLottable09
            AND Lottable10 = @cLottable10
            AND Lottable11 = @cLottable11
            AND Lottable12 = @cLottable12
            AND Lottable13 = @dLottable13
            AND Lottable14 = @dLottable14
            AND Lottable15 = @dLottable15
         
         IF @cPOLineNumber = ''
         BEGIN
            -- Get SKU info
            DECLARE @cPackKey NVARCHAR(10)
            SELECT
               @cPackKey = SKU.PackKey
            FROM dbo.SKU SKU (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKUCode
            
            -- Get new POLineNumber
            SELECT @cPOLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( POLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM PODetail (NOLOCK)
            WHERE POKey = @cExcessPOKey

            DECLARE @cExcessSuggID NVARCHAR(18)
            SET @cExcessSuggID = 'V' + @cLottable06 + @cReceiptKey + '1'
      
            -- Insert excess PO
            INSERT INTO PODetail (POKey, POLineNumber, ExternPOKey, StorerKey, SKU, QTYOrdered, UOM, PackKey, Facility, ToID,
               Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05, 
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
            VALUES( @cExcessPOKey, @cPOLineNumber, @cReceiptKey, @cStorerKey, @cSKUCode, @nExcessQTY, @cSKUUOM, @cPackKey, @cFacility, @cExcessSuggID, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05, 
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PODtl Fail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            UPDATE PODetail SET 
               QtyOrdered = QtyOrdered + @nExcessQTY
            WHERE POKey = @cExcessPOKey
               AND POLineNumber = @cPOLineNumber 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PODtl Fail
               GOTO Quit
            END
         END

         /*-------------------------------------------------------------------------------  
           
                                             Print label  
        
         -------------------------------------------------------------------------------*/  
         -- Get login info  
         DECLARE @cPrinter NVARCHAR(10)  
         SELECT @cPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()  
           
         -- Get report info  
         DECLARE @cDataWindow NVARCHAR(50)  
         DECLARE @cTargetDB   NVARCHAR(10)  
         SELECT  
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
         FROM RDT.RDTReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND ReportType ='IDLABEL01'  
  
         IF @cPrinter <> '' AND @cDataWindow <> '' AND @cTargetDB <> ''
         BEGIN
            -- Check label printed  
            IF NOT EXISTS( SELECT 1 FROM rdt.rdtPrintJob WITH (NOLOCK) WHERE ReportID = 'IDLABEL01' AND Parm1 = @cExcessPOKey AND Parm2 = @cExcessSuggID)  
            BEGIN  
               EXEC RDT.rdt_BuiltPrintJob  
                   @nMobile  
                  ,@cStorerKey  
                  ,'IDLABEL01'        -- ReportType   
                  ,'PRINT_IDLABEL01'  -- PrintJobName  
                  ,@cDataWindow  
                  ,@cPrinter  
                  ,@cTargetDB  
                  ,@cLangCode  
                  ,@nErrNo  OUTPUT  
                  ,@cErrMsg OUTPUT  
                  ,@cExcessPOKey  
                  ,@cExcessSuggID  
               -- IF @nErrNo <> 0  
               --    GOTO RollBackTran  
            END
         END  
      END
      
      IF @nActQTY > 0
      BEGIN
         -- Receive
         EXEC rdt.rdt_Receive_V7
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,  -- (ChewKP01)
            @cToLOC        = @cToLOC,
            @cToID         = @cToID,
            @cSKUCode      = @cSKUCode,
            @cSKUUOM       = @cSKUUOM,
            @nSKUQTY       = @nActQTY,
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
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO