SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm09                                         */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Defy                                                              */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-07-29 1.0  JHU151    FCR-549 Created                                  */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1581RcptCfm09 (
   @nFunc            INT,  
   @nMobile          INT,  
   @cLangCode        NVARCHAR( 3), 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 10), 
   @cPOKey           NVARCHAR( 10),	
   @cToLOC           NVARCHAR( 10), 
   @cToID            NVARCHAR( 18), 
   @cSKUCode         NVARCHAR( 20), 
   @cSKUUOM          NVARCHAR( 10), 
   @nSKUQTY          INT, 
   @cUCC             NVARCHAR( 20), 
   @cUCCSKU          NVARCHAR( 20), 
   @nUCCQTY          INT, 
   @cCreateUCC       NVARCHAR( 1),  
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @nNOPOFlag        INT, 
   @cConditionCode   NVARCHAR( 10),
   @cSubreasonCode   NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo        NVARCHAR( 30) = '', 
   @nSerialQTY       INT = 0, 
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nQTY_Bal             INT,
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
        @cAddRCPTValidtn      NVARCHAR( 10),
        @cLOT                 NVARCHAR( 10)

      SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddRCPTValidtn', @cStorerKey)

      IF @cAddRCPTValidtn = '1'
      BEGIN
         SELECT @cLottable01 = ISNULL(UDF01,'')
         FROM CodeLkUp WITH(NOLOCK)
         WHERE Code = @nFunc 
         AND storerkey = @cStorerKey 
         AND ListName = 'LOT1_2LINK' 
         AND UDF02 = @cLottable02
      END
         
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1581RcptCfm09


      EXEC rdt.rdt_Receive    
         @nFunc          = @nFunc,
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cReceiptKey    = @cReceiptKey,
         @cPOKey         = @cPOKey,
         @cToLOC         = @cToLOC,
         @cToID          = @cTOID,
         @cSKUCode       = @cSKUCode,
         @cSKUUOM        = @cSKUUOM,
         @nSKUQTY        = @nSKUQTY,
         @cUCC           = @cUCC,
         @cUCCSKU        = @cUCCSKU,
         @nUCCQTY        = @nUCCQTY,
         @cCreateUCC     = @cCreateUCC,
         @cLottable01    = @cLottable01,
         @cLottable02    = @cLottable02,   
         @cLottable03    = @cLottable03,
         @dLottable04    = @dLottable04,
         @dLottable05    = @dLottable05,
         @nNOPOFlag      = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode, 
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT, 
         @cSerialNo      = @cSerialNo, 
         @nSerialQTY     = @nSerialQTY, 
         @nBulkSNO       = @nBulkSNO, 
         @nBulkSNOQTY    = @nBulkSNOQTY

         IF @nErrNo <> 0
         GOTO RollBackTran
 GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm09 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO