SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd07                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Print Label                                                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 04-Dec-2017  ChewKP    1.0   WMS-3418 Created                              */
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd07]
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
   @cRefNo        NVARCHAR( 60), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cMethod       NVARCHAR( 1), 
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
   @cRDLineNo     NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
   DECLARE @tOutBoundList AS VariableTable      
          ,@cDocType      NVARCHAR(1) 
          ,@cShort        NVARCHAR(10)
          ,@cShort2       NVARCHAR(10)
          ,@cSUSR3        NVARCHAR(18)
      
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF @nStep = 4 -- ID, LOC
      BEGIN
         IF @nInputKey = 1 -- ESC
         BEGIN
            SELECT @cDocType = ISNULL(DocType ,'') 
            FROM dbo.Receipt WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND ReceiptKey = @cReceiptKey
            
            SET @cShort  = ''
            SET @cShort2 = ''
          
            SELECT @cShort = ISNULL(Short,'')
            FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE ListName = 'RDT608PRNT'
            AND StorerKey = @cStorerKey
            AND Code = @cDocType
            
            IF @cShort = 'R'
               GOTO QUIT
            
            
            SELECT @cSUSR3 = SUSR3 
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU 
            
            SELECT @cShort2 = ISNULL(Short,'')
            FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE ListName = 'NOSKULABEL'
            AND StorerKey = @cStorerKey
            AND Code = @cSUSR3
                            
            IF @cShort2 = ''
            BEGIN
               
               DELETE FROM @tOutBoundList
               
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCartonID', @cLottable07)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKU)
               
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  'PALLETLBL4', -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_608ExtUpd07', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               
            END
            
         END
      END
   END

   Quit:
END

SET QUOTED_IDENTIFIER OFF

GO