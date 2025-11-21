SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store procedure: rdt_600ExtUpd07                                         */    
/* Copyright: LF Logistics                                                    */    
/*                                                                            */    
/* Purpose: Print label                                                       */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 21-05-2020   YeeKung   1.0   WNS-12962 Created                              */    
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_600ExtUpd07] (    
   @nMobile      INT,    
   @nFunc        INT,    
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,    
   @nInputKey    INT,    
   @cFacility    NVARCHAR( 5),    
   @cStorerKey   NVARCHAR( 15),    
   @cReceiptKey  NVARCHAR( 10),    
   @cPOKey       NVARCHAR( 10),    
   @cLOC         NVARCHAR( 10),    
   @cID          NVARCHAR( 18),    
   @cSKU         NVARCHAR( 20),    
   @cLottable01  NVARCHAR( 18),    
   @cLottable02  NVARCHAR( 18),    
   @cLottable03  NVARCHAR( 18),    
   @dLottable04  DATETIME,    
   @dLottable05  DATETIME,    
   @cLottable06  NVARCHAR( 30),    
   @cLottable07  NVARCHAR( 30),    
   @cLottable08  NVARCHAR( 30),    
   @cLottable09  NVARCHAR( 30),    
   @cLottable10  NVARCHAR( 30),    
   @cLottable11  NVARCHAR( 30),    
   @cLottable12  NVARCHAR( 30),    
   @dLottable13  DATETIME,    
   @dLottable14  DATETIME,    
   @dLottable15  DATETIME,    
   @nQTY         INT,    
   @cReasonCode  NVARCHAR( 10),    
   @cSuggToLOC   NVARCHAR( 10),    
   @cFinalLOC    NVARCHAR( 10),    
   @cReceiptLineNumber NVARCHAR( 10),    
   @nErrNo       INT            OUTPUT,    
   @cErrMsg      NVARCHAR( 20)  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   IF @nFunc = 600 -- Normal receiving    
   BEGIN    
      IF @nStep = 6 -- SKU    
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN    
  
            DECLARE @cPrinter    NVARCHAR( 10)    
            DECLARE @cUCClabel NVARCHAR( 50)     
            DECLARE @tUCClabel AS VariableTable    
    
            SELECT @cPrinter = PRINTER     
            FROM rdt.rdtmobrec WITH (NOLOCK)    
            WHERE Mobile = @nMobile     
    
            SET @cUCClabel = rdt.rdtGetConfig( @nFunc, 'UccLabel', @cStorerKey)    
            IF @cUCClabel = '0'    
               SET @cUCClabel = ''    
            IF (@cUCClabel<>'')  
            BEGIN  
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cUserdefine01', @cLottable01)   
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cReceiptkey', @cReceiptKey)     
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cSKU', @cSKU)     
  
               -- Print label    
               EXEC RDT.rdt_Print    
                     @nMobile       = @nMobile    
                  , @nFunc         = @nFunc    
                  , @cLangCode     = @cLangCode    
                  , @nStep         = 0    
                  , @nInputKey     = 1    
                  , @cFacility     = @cFacility    
                  , @cStorerKey    = @cStorerKey    
                  , @cLabelPrinter = @cPrinter    
                  , @cPaperPrinter = ''   
                  , @cReportType   = @cUCClabel    
                  , @tReportParam  = @tUCClabel    
                  , @cSourceType   = 'rdtfnc_600ExtUpd07'    
                  , @nErrNo        = @nErrNo  OUTPUT    
                  , @cErrMsg       = @cErrMsg OUTPUT   
  
                  IF @cErrMsg<>''  
                     GOTO FAIL  
            END   
         END  
      END    
   END    
END  
Fail:  

GO