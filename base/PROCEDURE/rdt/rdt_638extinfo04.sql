SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtInfo04                                       */
/* Purpose: Print IT69 label, display total ASN and QTY                    */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-02-07 1.0  Ung        WMS-22017 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo04] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT ,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cData1        NVARCHAR( 60),
   @cData2        NVARCHAR( 60),
   @cData3        NVARCHAR( 60),
   @cData4        NVARCHAR( 60),
   @cData5        NVARCHAR( 60),
   @cOption       NVARCHAR( 1),
   @dArriveDate   DATETIME,
   @tExtInfoVar   VariableTable READONLY,
   @cExtendedInfo NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL         NVARCHAR( MAX)
   DECLARE @cSQLParam    NVARCHAR( MAX)
   DECLARE @cColumnName  NVARCHAR( 20)
   DECLARE @nQTYExpected INT
   DECLARE @cReceiptLineNumber NVARCHAR( 5)

   IF @nFunc = 638 -- ECOM return
   BEGIN
      -- Print IT69 label
      IF @nStep = 1 AND  -- ASN
         @nAfterStep = 3 -- SKU
      BEGIN
         -- Get session info
         DECLARE @cLabelPrinter NVARCHAR( 10)
         DECLARE @cPaperPrinter NVARCHAR( 10)
         SELECT 
            @cLabelPrinter = Printer, 
            @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 
         
         -- Get lookup info
         SELECT @cColumnName = Code
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'REFNOLKUP'
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility
         
         -- Loop ASN
         DECLARE @curASN CURSOR
         IF @cRefNo <> ''
         BEGIN
            SET @cSQL = 
               ' SET @curASN = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR ' + 
                  ' SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected ' + 
                  ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
                     'JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' + 
                  ' WHERE R.Facility = @cFacility ' + 
                     ' AND R.StorerKey = @cStorerKey ' + 
                     ' AND R.Status <> ''9'' ' + 
                     ' AND R.ASNStatus <> ''CANC'' ' + 
                     ' AND R.' + @cColumnName + ' = @cRefNo ' + 
                  ' ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber ' + 
               ' OPEN @curASN '

            SET @cSQLParam = 
               ' @cFacility    NVARCHAR( 5),  ' + 
               ' @cStorerKey   NVARCHAR( 20), ' + 
               ' @cRefNo       NVARCHAR( 20), ' + 
               ' @curASN       CURSOR OUTPUT     '  
         
            EXEC sp_executeSQL @cSQL, @cSQLParam, 
                @cFacility    = @cFacility   
               ,@cStorerKey   = @cStorerKey  
               ,@cRefNo       = @cRefNo      
               ,@curASN       = @curASN OUTPUT
         END
         ELSE
         BEGIN
            SET @curASN = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptKey, ReceiptLineNumber, QTYExpected
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               ORDER BY ReceiptKey, ReceiptLineNumber
            OPEN @curASN
         END
         FETCH NEXT FROM @curASN INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Common params
            DECLARE @tIT69Label AS VariableTable
            DELETE @tIT69Label 
            INSERT INTO @tIT69Label (Variable, Value) VALUES
               ( '@cParam1', @cReceiptKey),
               ( '@cParam2', @cReceiptLineNumber),
               ( '@cParam4', CAST( @nQTYExpected AS NVARCHAR( 5))),
               ( '@cParam5', '1')

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               'IT69LABEL', -- Report type
               @tIT69Label, -- Report params
               'rdt_638ExtInfo04',
               0, --@nErrNo  OUTPUT,
               '' --@cErrMsg OUTPUT
         
            FETCH NEXT FROM @curASN INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected
         END
      END
        
      IF @nAfterStep = 3 -- SKU
      BEGIN
         DECLARE @nTotalASN    INT
         
         -- Get lookup info
         SELECT @cColumnName = Code
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'REFNOLKUP'
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility
         
         IF @cRefNo <> '' -- Tracking no
         BEGIN
            SET @cSQL = 
               ' SELECT ' + 
                  ' @nTotalASN = COUNT( DISTINCT R.ReceiptKey), ' + 
                  ' @nQTYExpected = ISNULL( SUM( QTYExpected), 0) ' + 
               ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
                  ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' + 
               ' WHERE R.Facility = @cFacility ' + 
                  ' AND R.StorerKey = @cStorerKey ' + 
                  -- ' AND R.Status <> ''9'' ' +  -- ASN could be finalized one by one
                  ' AND R.ASNStatus <> ''CANC'' ' + 
                  ' AND R.' + @cColumnName + ' = @cRefNo ' 
            SET @cSQLParam = 
               ' @cFacility    NVARCHAR( 5),  ' + 
               ' @cStorerKey   NVARCHAR( 20), ' + 
               ' @cRefNo       NVARCHAR( 20), ' + 
               ' @nTotalASN    INT OUTPUT,    ' + 
               ' @nQTYExpected INT OUTPUT     '  
         
            EXEC sp_executeSQL @cSQL, @cSQLParam, 
                @cFacility    = @cFacility   
               ,@cStorerKey   = @cStorerKey  
               ,@cRefNo       = @cRefNo      
               ,@nTotalASN    = @nTotalASN    OUTPUT
               ,@nQTYExpected = @nQTYExpected OUTPUT

            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = rdt.rdtgetmessage( 197951, @cLangCode, 'DSP') --REF ASN/QTY:
            
            SET @cExtendedInfo = 
               RTRIM( @cMsg) + ' ' + 
               CAST( @nTotalASN AS NVARCHAR(2)) + '/' + 
               CAST( @nQTYExpected AS NVARCHAR(5))
         END
         ELSE
            SET @cExtendedInfo = ''
      END
   END

Quit:


GO