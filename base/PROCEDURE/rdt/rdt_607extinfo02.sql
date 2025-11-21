SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_607ExtInfo02                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Show balance QTY                                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 05-02-2017  1.0  Ung          WMS-1006. Created                      */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_607ExtInfo02]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 20), 
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
   @cReasonCode   NVARCHAR( 10), 
   @cSuggToID     NVARCHAR( 18), 
   @cSuggToLOC    NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cExtendedInfo NVARCHAR(20)  OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 607 -- Return V7
   BEGIN
      IF @nAfterStep = 3 -- QTY
      BEGIN
         DECLARE @cSQL NVARCHAR( MAX)
         DECLARE @cSQLParam NVARCHAR( MAX)
         DECLARE @cLabel NVARCHAR(20)
         DECLARE @cField SYSNAME
         DECLARE @cValue NVARCHAR(20)
         
         SELECT 
            @cLabel = LEFT( ISNULL( Long, ''), 20), 
            @cField = ISNULL( Notes, '')
         FROM CodeLkup WITH (NOLOCK) 
         WHERE ListName = 'RDTExtInfo'
            AND Code = @nFunc
            AND StorerKey = @cStorerKey 
         
         -- Check field exists
         IF NOT EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ReceiptDetail' AND COLUMN_NAME = @cField)
            GOTO Quit
         
         SET @cSQL = 'SELECT TOP 1 ' + 
            '    @cValue = ' + @cField + 
            ' FROM ReceiptDetail WITH (NOLOCK) ' + 
            ' WHERE ReceiptKey = @cReceiptKey ' + 
            '    AND StorerKey = @cStorerKey ' + 
            '    AND SKU = @cSKU '
         SET @cSQLParam =
            '@cReceiptKey   NVARCHAR( 10), ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cValue        NVARCHAR( 20) OUTPUT '
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cReceiptKey, 
            @cStorerKey, 
            @cSKU, 
            @cValue OUTPUT
            
         SET @cExtendedInfo = LEFT( RTRIM( @cLabel) + RTRIM( @cValue), 20)
      END
   END
   
Quit:
   
END

GO