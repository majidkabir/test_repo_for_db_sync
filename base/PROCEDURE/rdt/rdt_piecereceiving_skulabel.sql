SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_PieceReceiving_SKULabel                            */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2017-05-04 1.0  Ung     WMS-1817 Created                                */
/* 2017-06-30 1.1  SPChin  IN00391361 - Bug Fixed                          */
/* 2020-04-15 1.2  Ung     WMS-13140 Surpress error (bypass printing)      */
/***************************************************************************/
CREATE PROC [RDT].[rdt_PieceReceiving_SKULabel](
   @nFunc         INT,
   @nMobile       INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPrinter      NVARCHAR( 10), 
   @cReceiptKey   NVARCHAR( 10),
   @cToLOC        NVARCHAR( 10),
   @cToID         NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL               NVARCHAR( MAX)
   DECLARE @cSQLParam          NVARCHAR( MAX)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cDataWindow        NVARCHAR( 50)
   DECLARE @cTargetDB          NVARCHAR( 20)
   DECLARE @cSKULabelSP        NVARCHAR( 20)

   -- Find receipt detai line
   -- if not, need to pass-in too many params like storer, sku, lottable1-5, loc, id... etc
   SET @cReceiptLineNumber = ''
   SELECT TOP 1
      @cReceiptLineNumber = ReceiptLineNumber
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND SKU = @cSKU
      AND ToID = @cToID
      AND ToLOC = @cToLOC
      AND Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END
      AND Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END
      AND Lottable03 = CASE WHEN ISNULL(@cLottable03, '') = '' THEN Lottable03 ELSE @cLottable03 END
      AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)

   -- Get report info
   SELECT
      @cDataWindow = DataWindow,
      @cTargetDB = TargetDB
   FROM RDT.RDTReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportType = 'SKULABEL'
   
   -- Get storer configure
   SET @cSKULabelSP = rdt.RDTGetConfig( @nFunc, 'SKULabelSP', @cStorerKey)
   IF @cSKULabelSP = '0'
      SET @cSKULabelSP = ''

   -- SKU label SP
   IF @cSKULabelSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSKULabelSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSKULabelSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cDataWindow, @cPrinter, @cTargetDB, @cReceiptKey, @cReceiptLineNumber, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile            INT,           ' +
            '@nFunc              INT,           ' +
            '@nStep              INT,           ' +	--IN00391361
            '@cLangCode          NVARCHAR( 3),  ' +	--IN00391361
            '@cStorerKey         NVARCHAR( 15), ' +
            '@cDataWindow        NVARCHAR( 60), ' +
            '@cPrinter           NVARCHAR( 10), ' +
            '@cTargetDB          NVARCHAR( 20), ' +
            '@cReceiptKey        NVARCHAR( 10), ' +
            '@cReceiptLineNumber NVARCHAR(  5), ' +
            '@nQTY               INT,           ' +
            '@nErrNo             INT           OUTPUT, ' +
            '@cErrMsg            NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cDataWindow, @cPrinter, @cTargetDB, @cReceiptKey, @cReceiptLineNumber, @nQTY,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
      END
   END
   ELSE
   BEGIN
      -- Print
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'SKULABEL',       -- ReportType
         'PRINT_SKULABEL', -- PrintJobName
         @cDataWindow,
         @cPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cReceiptKey,
         @cReceiptLineNumber,
         @nQTY
   END
   
   IF @nErrNo <> 0   
   BEGIN
      IF @nErrNo = -1 -- Skip print
         SET @nErrNo = 0
      ELSE
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg
      END
   END
      
Quit:

END

GO