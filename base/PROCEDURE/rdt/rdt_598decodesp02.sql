SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_598DecodeSP02                                         */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Decode SSCC, receive all Receipt Detail line (udf01)              */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2019-06-24   James     1.0   WMS9426 Created                               */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_598DecodeSP02]  
   @nMobile      INT,            
   @nFunc        INT,            
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 20),  
   @cColumnName  NVARCHAR( 20),  
   @cLOC         NVARCHAR( 10),  
   @cBarcode     NVARCHAR( 60),  
   @cFieldName   NVARCHAR( 10),  
   @cID          NVARCHAR( 18)  OUTPUT,  
   @cSKU         NVARCHAR( 20)  OUTPUT,  
   @nQTY         INT            OUTPUT,  
   @cLottable01  NVARCHAR( 18)  OUTPUT,  
   @cLottable02  NVARCHAR( 18)  OUTPUT,  
   @cLottable03  NVARCHAR( 18)  OUTPUT,  
   @dLottable04  DATETIME       OUTPUT,  
   @dLottable05  DATETIME       OUTPUT,  
   @cLottable06  NVARCHAR( 30)  OUTPUT,  
   @cLottable07  NVARCHAR( 30)  OUTPUT,  
   @cLottable08  NVARCHAR( 30)  OUTPUT,  
   @cLottable09  NVARCHAR( 30)  OUTPUT,  
   @cLottable10  NVARCHAR( 30)  OUTPUT,  
   @cLottable11  NVARCHAR( 30)  OUTPUT,  
   @cLottable12  NVARCHAR( 30)  OUTPUT,  
   @dLottable13  DATETIME       OUTPUT,  
   @dLottable14  DATETIME       OUTPUT,  
   @dLottable15  DATETIME       OUTPUT,  
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSSCC          NVARCHAR( 60)
   DECLARE @nTranCount     INT
   DECLARE @nQTYExpected   INT
   DECLARE @bSuccess       INT
   DECLARE @cFinalizeRD    NVARCHAR(1)
   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)

   SET @nErrNo = 0

   SELECT @cUserName = UserName,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 4 -- SKU    
   BEGIN  
      IF @nInputKey = 1 -- ENTER
      BEGIN  
         IF LEN( @cBarcode) = 20  
         BEGIN  
            SET @cSSCC = @cBarcode

            -- For ReceiptDetail
            DECLARE @tRD TABLE
            (
               ReceiptKey NVARCHAR( 10) NOT NULL,
               ReceiptLineNumber NVARCHAR( 5) NOT NULL,
               QTYExpected INT NOT NULL,
               BeforeReceivedQTY INT NOT NULL
            )

            INSERT INTO @tRD (ReceiptKey, ReceiptLineNumber, QTYExpected, BeforeReceivedQTY)
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected, RD.BeforeReceivedQTY
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.UserDefine01 = @cSSCC

            -- Validate SSCC
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 141101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid SSCC
               GOTO Fail
            END

            -- Validate SSCC double scan
            IF EXISTS( SELECT 1
               FROM @tRD
               WHERE BeforeReceivedQTY > 0)
            BEGIN
               SET @nErrNo = 141102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Double scan
               GOTO Fail
            END

            SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetail', @cStorerKey)

            -- Handling transaction
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_598DecodeSP02 -- For rollback or commit only our own transaction

            -- Prepare cursor for @tRD
            DECLARE @curRD CURSOR
            SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptKey, ReceiptLineNumber, QTYExpected
               FROM @tRD
            OPEN @curRD
            FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected

            -- Loop @tRD
            SET @nQTY = 0
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @cFinalizeRD = '0'
               BEGIN
                  -- Update ReceiptDetail
                  UPDATE dbo.ReceiptDetail SET
                     ToLOC = @cLOC, 
                     ToID = @cID, 
                     BeforeReceivedQTY = QTYExpected, 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  FROM dbo.ReceiptDetail RD
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
               END
               ELSE IF @cFinalizeRD = '1'
               BEGIN
                  UPDATE dbo.ReceiptDetail SET
                     ToLOC = @cLOC, 
                     ToID = @cID, 
                     BeforeReceivedQTY = QTYExpected, 
                     QTYReceived = QTYExpected, 
                     FinalizeFlag = 'Y', 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  FROM dbo.ReceiptDetail RD
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
               END
               ELSE IF @cFinalizeRD = '2'
               BEGIN
                  -- Update ReceiptDetail
                  UPDATE dbo.ReceiptDetail SET
                     ToLOC = @cLOC, 
                     ToID = @cID, 
                     BeforeReceivedQTY = QTYExpected, 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  FROM dbo.ReceiptDetail RD
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END

                  EXEC dbo.ispFinalizeReceipt
                      @c_ReceiptKey        = @cReceiptKey
                     ,@b_Success           = @bSuccess   OUTPUT
                     ,@n_err               = @nErrNo     OUTPUT
                     ,@c_ErrMsg            = @cErrMsg    OUTPUT
                     ,@c_ReceiptLineNumber = @cReceiptLineNumber
                  IF @nErrNo <> 0 OR @bSuccess = 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
               END
         
               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '2', -- Receiving
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cLocation     = @cLOC,
                  @cID           = @cID,
                  @nQTY          = @nQTYExpected,
                  @cReceiptKey    = @cReceiptKey,
                  @cUCC          = @cSSCC,
                  @nStep         = @nStep

               SET @nQTY = @nQTY + @nQTYExpected
               FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected
            END

            GOTO QUIT

            RollBackTran:
               ROLLBACK TRAN rdt_598DecodeSP02 -- Only rollback change made here

            Quit:
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN rdt_598DecodeSP02  

            IF @nErrNo = 0
               SET @nErrNo =-1   -- To stay in current sku/qty screen
         END  
         ELSE
            SET @cSKU = @cBarcode
      END  
   END  

   FAIL:
END  
 

GO