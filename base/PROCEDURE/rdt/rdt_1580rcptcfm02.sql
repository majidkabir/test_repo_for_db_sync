SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580RcptCfm02                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive the line and create UCC per SKU                           */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-06-15 1.0  James      SOS371418 Created                               */
/* 2018-09-25 1.1  Ung        WMS-5722 Add param                              */ 
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcptCfm02] (
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
        @cLOT                 NVARCHAR( 10)
        
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1580RcptCfm02

      EXEC rdt.rdt_Receive
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo   OUTPUT,
         @cErrMsg       = @cErrMsg  OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
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
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran
      ELSE
      BEGIN
         -- Get LOT# from itrn to stamp into UCC table
         SELECT @cLOT = Lot
         FROM dbo.ITRN WITH (NOLOCK)
         WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
         AND   TranType = 'DP'
         AND   StorerKey = @cStorerKey

         EXECUTE nspg_getkey
            @KeyName       = 'NIKEUCC' ,
            @fieldlength   = 19,    
            @keystring     = @cCounter    Output,
            @b_success     = @bSuccess    Output,
            @n_err         = @nErrNo      Output,
            @c_errmsg      = @cErrMsg     Output,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @nErrNo <> 0 OR @bSuccess <> 1
         BEGIN
            SET @nErrNo = 101601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get ucc fail'  
            GOTO RollBackTran
         END

         SET @cNewUCC = 'N' + @cCounter

         INSERT INTO dbo.UCC 
         (UCCNO, STORERKEY, EXTERNKEY, SKU, QTY, SOURCEKEY, SOURCETYPE, [Status], Receiptkey, ReceiptLineNumber, Loc, Lot) 
         VALUES 
         (@cNewUCC, @cStorerKey, ' ', @cSKUCode, @nSKUQTY, '', 'Piece Receiving', '1', @cReceiptKey, @cReceiptLineNumber, @cToLOC, @cLOT)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 101602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Insert ucc fail'  
            GOTO RollBackTran
         END         
      END

      IF EXISTS ( SELECT 1 FROM rdt.RDTReport WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = 'CUSTOMLBL')
      BEGIN
         -- Get printer info  
         SELECT @cLabelPrinter = Printer
         FROM rdt.rdtMobRec WITH (NOLOCK)  
         WHERE Mobile = @nMobile  

         -- Check label printer blank  
         IF @cLabelPrinter = ''  
         BEGIN  
            SET @nErrNo = 101603  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
            GOTO RollBackTran  
         END  

         -- Get report info  
         SET @cDataWindow = ''  
         SET @cTargetDB = ''  
         SET @cReportType = 'CUSTOMLBL'
         SET @cPrintJobName = 'PRINT_CUSTOMLBL'

         SELECT   
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReportType = @cReportType  

         IF @cDataWindow = ''
         BEGIN  
            SET @nErrNo = 101604  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
            GOTO RollBackTran  
         END  

         IF @cTargetDB = ''
         BEGIN  
            SET @nErrNo = 101605  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET  
            GOTO RollBackTran  
         END  

         -- Insert print job 
         SET @nErrNo = 0                    
         EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            @cReportType,                    
            @cPrintJobName,                    
            @cDataWindow,                    
            @cLabelPrinter,                    
            @cTargetDB,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cNewUCC

         IF @nErrNo <> 0
            GOTO RollBackTran  
      END

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1580RcptCfm02 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO