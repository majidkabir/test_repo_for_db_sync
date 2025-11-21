SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_897ExtUpdSP01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Called from: rdtfnc_ReceiveByUCC                                     */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2017-10-09  1.0  ChewKP   WMS-3162 Created                           */
/* 2018-03-07  1.1  ChewKP   WMS-4228 Lottable08,09 Condition (ChewKP01)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_897ExtUpdSP01] (  
      @nMobile       INT,           
      @nFunc         INT,           
      @cLangCode     NVARCHAR( 3),  
      @nStep         INT,           
      @nInputKey     INT,         
      @cFacility     NVARCHAR( 5),  
      @cStorerKey    NVARCHAR( 15), 
      @cDropID       NVARCHAR( 20), 
      @cOutputText1  NVARCHAR( 20) OUTPUT,
      @cOutputText2  NVARCHAR( 20) OUTPUT,
      @cOutputText3  NVARCHAR( 20) OUTPUT,
      @cOutputText4  NVARCHAR( 20) OUTPUT,
      @cOutputText5  NVARCHAR( 20) OUTPUT,
      @nErrNo        INT           OUTPUT, 
      @cErrMsg       NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
             @nTranCount    INT
            , @bSuccess      INT
            , @cPOKey        NVARCHAR(10)
            , @cReceiptKey   NVARCHAR(10)
            , @cDefaultToLoc NVARCHAR(10)
            , @nMultiSKU_UCC INT
            , @nUCCRowRef    INT
            , @cCounter      NVARCHAR(19)
            , @cNewUCC       NVARCHAR(20) 
            , @cSKU          NVARCHAR(20) 
            , @nUCCQty       INT
            , @cUOM                NVARCHAR( 10)
            , @cReasonCode         NVARCHAR( 10)
            , @cReceiptLineNumber  NVARCHAR( 5)
            , @cLottable01         NVARCHAR( 18)
            , @cLottable02         NVARCHAR( 18)
            , @cLottable03         NVARCHAR( 18)
            , @dLottable04         DATETIME
            , @dLottable05         DATETIME
            , @cLottable06         NVARCHAR( 30)
            , @cLottable07         NVARCHAR( 30)
            , @cLottable08         NVARCHAR( 30)
            , @cLottable09         NVARCHAR( 30)
            , @cLottable10         NVARCHAR( 30)
            , @cLottable11         NVARCHAR( 30)
            , @cLottable12         NVARCHAR( 30)
            , @dLottable13         DATETIME
            , @dLottable14         DATETIME
            , @dLottable15         DATETIME
            , @cLot                NVARCHAR(10) 
            , @cLabelPrinter       NVARCHAR(10)
            , @cDataWindow         NVARCHAR( 50)
            , @cTargetDB           NVARCHAR( 20)
            , @cReportType         NVARCHAR( 10)
            , @cPrintJobName       NVARCHAR( 60)
            , @cExternReceiptKey   NVARCHAR( 20) 
            , @cUCCNo              NVARCHAR( 20) 
           
            

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_897ExtUpdSP01
   
   IF @nFunc = 897 
   BEGIN
   
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
           SET @cDefaultToLoc = ''
           SELECT @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'DefaultReceiptLoc', @cStorerKey) 
         
           

           SELECT TOP 1 @cExternReceiptKey = SourceKey 
           FROM dbo.UCC WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
           AND UCCNo = @cDropID
           AND Status = '0' 
           
           SELECT TOP 1 @cReceiptKey = ReceiptKey
           FROM dbo.Receipt WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
           AND ExternReceiptKey = @cExternReceiptKey
           AND Status < '9'

           SELECT @cPOKey = POKey
           FROM dbo.PO WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
           AND ExternPOKey = @cExternReceiptKey 

           
           
           SET @nMultiSKU_UCC = 0
           IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   UCCNo = @cDropID
                     GROUP BY UCCNO 
                     HAVING COUNT( DISTINCT SKU) > 1)
           SET @nMultiSKU_UCC = 1
           
           
           -- UCC contain multi SKU - Automatically create new UCC
           IF @nMultiSKU_UCC = 1
           BEGIN
             DECLARE CUR_SPLITUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
           
             SELECT UCC_RowRef, SKU, Qty
             FROM dbo.UCC WITH (NOLOCK)
             WHERE StorerKey = @cStorerKey
             AND   UCCNo = @cDropID
             AND   Status = '0'
             
             OPEN CUR_SPLITUCC
             FETCH NEXT FROM CUR_SPLITUCC INTO @nUCCRowRef, @cSKU, @nUCCQty
             WHILE @@FETCH_STATUS <> -1
             BEGIN
                 
                 EXECUTE nspg_getkey
                    @KeyName       = 'TripleUCC' ,
                    @fieldlength   = 19,    
                    @keystring     = @cCounter    Output,
                    @b_success     = @bSuccess    Output,
                    @n_err         = @nErrNo      Output,
                    @c_errmsg      = @cErrMsg     Output,
                    @b_resultset   = 0,
                    @n_batch       = 1
                 
                 IF @nErrNo <> 0 OR @bSuccess <> 1
                 BEGIN
                    SET @nErrNo = 115751
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetUCCKeyFail'  
                    GOTO RollBackTran
                 END

                 SET @cNewUCC = 'T' + @cCounter

                 -- Split multi sku UCC. Stamp userdefined09 with original UCC
                 INSERT INTO dbo.UCC (UCCNO, STORERKEY, EXTERNKEY, SKU, QTY, SOURCEKEY, SOURCETYPE, 
                 [Status], USERDEFINED01, USERDEFINED02, USERDEFINED03, USERDEFINED04, USERDEFINED05,
                 USERDEFINED06, USERDEFINED07, USERDEFINED08, USERDEFINED09, USERDEFINED10)
                 SELECT @cNewUCC, STORERKEY, EXTERNKEY, SKU, QTY, SOURCEKEY, SOURCETYPE, 
                 '0', USERDEFINED01, USERDEFINED02, USERDEFINED03, USERDEFINED04, USERDEFINED05,
                 USERDEFINED06, USERDEFINED07, USERDEFINED08, @cDropID, USERDEFINED10
                 FROM dbo.UCC WITH (NOLOCK)
                 WHERE StorerKey = @cStorerKey
                 AND   UCCNo = @cDropID
                 AND   SKU   = @cSKU
                 AND   Qty   = @nUCCQty 

                 IF @@ERROR <> 0
                 BEGIN
                    SET @nErrNo = 115752
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsUCCFail'  
                    GOTO RollBackTran
                 END

                 -- Dispose old UCC
                 UPDATE dbo.UCC WITH (ROWLOCK) SET 
                    [Status] = '6'
                 WHERE StorerKey = @cStorerKey
                 AND   UCCNo = @cDropID
                 AND   SKU = @cSKU
                 AND   [Status] = '0'
                 AND UCC_RowRef = @nUCCRowRef

                 IF @@ERROR <> 0
                 BEGIN
                    SET @nErrNo = 115753
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'  
                    GOTO RollBackTran
                 END
                 
                 FETCH NEXT FROM CUR_SPLITUCC INTO @nUCCRowRef, @cSKU, @nUCCQty
             END
             CLOSE CUR_SPLITUCC
             DEALLOCATE CUR_SPLITUCC
             
           END
           
           SET @nUCCRowRef = 0
           SET @cSKU = ''
           SET @nUCCQty = 0 
           
           
           IF @nMultiSKU_UCC = 1
           BEGIN
              
              DECLARE CUR_RECEIPTUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              
              SELECT UCC_Rowref, SKU, Qty, UCCNo
              FROM dbo.UCC WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   UserDefined09 = @cDropID
              AND   Status = '0'
           END
           ELSE
           BEGIN
              DECLARE CUR_RECEIPTUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              
              SELECT UCC_Rowref, SKU, Qty, UCCNo
              FROM dbo.UCC WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   UCCNo = @cDropID
              AND   Status = '0'
           END
           OPEN CUR_RECEIPTUCC
           FETCH NEXT FROM CUR_RECEIPTUCC INTO @nUCCRowref, @cSKU, @nUCCQty, @cUCCNo
           WHILE @@FETCH_STATUS <> -1
           BEGIN

              SELECT TOP 1 
                 --@cReceiptKey   = R.ReceiptKey,
                 --@cFromLoc      = ToLoc,
                 @cLottable01   = ISNULL(Lottable01,''),
                 @cLottable02   = ISNULL(Lottable02,''),
                 @cLottable03   = ISNULL(Lottable03,''),
                 @dLottable04   = Lottable04,
                 @cLottable06   = Lottable06,
                 @cLottable07   = ISNULL(Lottable07,''),
                 @cLottable08   = ISNULL(Lottable08,''),
                 @cLottable09   = ISNULL(Lottable09,''),
                 @cLottable10   = ISNULL(Lottable10,''),
                 @cLottable11   = ISNULL(Lottable11,''),
                 @cLottable12   = ISNULL(Lottable12,''),
                 @dLottable13   = Lottable13,
                 @dLottable14   = Lottable14,
                 @dLottable15   = Lottable15,
                 @cReasonCode   = ISNULL(ConditionCode,'')
              FROM dbo.ReceiptDetail RD WITH (NOLOCK)
              JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
              WHERE R.ReceiptKey = @cReceiptKey
              AND   R.ExternReceiptKey = @cExternReceiptKey
              AND   RD.SKU = @cSKU
              --AND   ( RD.QtyExpected - RD.BeforeReceivedQty) >= @nQty
              AND   R.Status = '0'
              
              -- (ChewKP01) 
              IF ISNULL(@cLottable08,'') = '' 
              BEGIN
                  SELECT @cLottable08 = CountryOfOrigin 
                  FROM dbo.SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
              END
               
              IF ISNULL(@cLottable09,'') = '' 
              BEGIN
                  SELECT @cLottable09 = ItemClass 
                  FROM dbo.SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
              END
              

              SELECT @cUOM = PackUOM3
              FROM dbo.SKU WITH (NOLOCK)
              JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
              WHERE StorerKey = @cStorerKey
              AND   SKU = @cSKU
                       
              --SELECT @cReceiptKey '@cReceiptKey' , @cPoKey '@cPoKey' , @cDefaultToLoc '@cDefaultToLoc' , @cSKU '@cSKU' , @cUOM '@cUOM' , @nUCCQTY '@nUCCQTY' 
              SET @dLottable05 = GETDATE() 
               
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
                 @cPOKey        = @cPoKey,  
                 @cToLOC        = @cDefaultToLoc,
                 @cToID         = '',
                 @cSKUCode      = @cSKU,
                 @cSKUUOM       = @cUOM,
                 @nSKUQTY       = @nUCCQTY,
                 @cUCC          = '',
                 @cUCCSKU       = '',
                 @nUCCQTY       = '',
                 @cCreateUCC    = '',
                 @cLottable01   = @cLottable01,
                 @cLottable02   = @cLottable02,
                 @cLottable03   = @cLottable03,
                 @dLottable04   = @dLottable04,
                 @dLottable05   = @dLottable05,
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
                 @nNOPOFlag     = 0,
                 @cConditionCode = @cReasonCode,
                 @cSubreasonCode = '', 
                 @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

              IF @nErrNo <> 0
              BEGIN
                 GOTO RollBackTran
              END
              
              -- Update ReceiptDetail with UCCNo 
              UPDATE dbo.ReceiptDetail WITH (ROWLOCK) 
                  SET UserDefine01 = @cUCCNo
                     ,TrafficCop   = NULL
              WHERE StorerKey = @cStorerKey
              AND ReceiptKey = @cReceiptKey
              AND ReceiptLineNumber = @cReceiptLineNumber
              
              IF @@ERROR <> 0 
              BEGIN
                  SET @nErrNo = 115759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdRecpDetFail'  
                  GOTO RollBackTran
              END
              
              
              -- Get LOT# from itrn to stamp into UCC table
              SELECT @cLot = Lot
              FROM dbo.ITRN WITH (NOLOCK)
              WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
              AND   TranType = 'DP'
              AND   StorerKey = @cStorerKey
              
              UPDATE dbo.UCC WITH (ROWLOCK) SET 
                 LOT = @cLot,
                 Loc = @cDefaultToLoc,
                 ID  = '',
                 [Status] = '1', 
                 ReceiptKey = @cReceiptKey, 
                 ReceiptLineNumber = @cReceiptLineNumber
              WHERE StorerKey = @cStorerKey
              AND   UCCNo = @cUCCNo
              AND   [Status] = '0'
              AND UCC_RowRef = @nUCCRowref

              IF @@ERROR <> 0
              BEGIN
                 SET @nErrNo = 115755
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'  
                 GOTO RollBackTran
              END
             
              -- Print Label
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
                     SET @nErrNo = 115756  
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

   --        IF @cDataWindow = ''
   --               BEGIN  
   --                  SET @nErrNo = 115757  
   --                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
   --                  GOTO RollBackTran  
   --               END  

                  IF @cTargetDB = ''
                  BEGIN  
                     SET @nErrNo = 115758  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TargetDBNotSet 
                     GOTO RollBackTran  
                  END  

                  
                  -- Insert print job 
                  SET @nErrNo = 0      
                  
                  --IF @nMultiSKU_UCC = 1 
                  --   SET @cDropID = @cNewUCC
                     
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
                     @cUCCNo

                  IF @nErrNo <> 0
                     GOTO RollBackTran  
              END
           
              FETCH NEXT FROM CUR_RECEIPTUCC INTO @nUCCRowref, @cSKU, @nUCCQty, @cUCCNo
           END
           CLOSE CUR_RECEIPTUCC
           DEALLOCATE CUR_RECEIPTUCC
        
           
         
           SET @cOutputText1 = ''
           SET @cOutputText2 = ''
           SET @cOutputText3 = ''
           SET @cOutputText4 = ''
           SET @cOutputText5 = ''
                     
         END
      END

   END
   
 
  
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_897ExtUpdSP01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_897ExtUpdSP01

  
Fail:  
END  


GO