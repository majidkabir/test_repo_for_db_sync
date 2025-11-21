SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_609ExtUpd01                                           */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Print label                                                       */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */
/* 2016-09-13 1.0  James    WMS288 Created                                    */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_609ExtUpd01] (  
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
  
   IF @nFunc = 609 -- Normal receiving  
   BEGIN  
      IF @nStep = 3 -- QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            DECLARE @cPrinter    NVARCHAR( 10)  
            DECLARE @cUserName   NVARCHAR( 18)  
            DECLARE @cDataWindow NVARCHAR( 50)  
            DECLARE @cTargetDB   NVARCHAR( 20)  
  
            -- Get login info  
            SELECT  
               @cPrinter = Printer,  
               @cUserName = SUSER_SNAME()   
            FROM rdt.rdtMobRec WITH (NOLOCK)  
            WHERE UserName = SUSER_SNAME()  
  
            SET @cDataWindow = ''  
            SET @cTargetDB = ''  
            SELECT TOP 1   
               @cDataWindow = DataWindow,   
               @cTargetDB = TargetDB  
            FROM rdt.rdtReport WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
               AND ReportType = 'PreRecv'  
               AND (Function_ID = @nFunc OR Function_ID = 0)  
  
            IF @cPrinter <> '' AND @cDataWindow <> ''  
            BEGIN  
               -- Print label  
               EXEC RDT.rdt_BuiltPrintJob  
                   @nMobile  
                  ,@cStorerKey  
                  ,'PreRecv'        -- ReportType   
                  ,'PRINT_PreRecv'  -- PrintJobName  
                  ,@cDataWindow  
                  ,@cPrinter  
                  ,@cTargetDB  
                  ,@cLangCode  
                  ,@nErrNo  OUTPUT  
                  ,@cErrMsg OUTPUT  
                  ,@cReceiptKey  
                  ,@cReceiptLineNumber  
                  ,@cReceiptLineNumber  
            END  
         END  
      END  
   END  
END  

GO