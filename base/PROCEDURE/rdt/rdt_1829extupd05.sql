SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1829ExtUpd05                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-07-15  1.0  Ung      WMS-5728 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtUpd05] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nTranCount  INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1829ExtUpd05

   SET @cReceiptKey = @cParam1
   SET @cSKU = @cUCCNo

   IF @nStep = 3
   BEGIN
      IF @nInputKey = '1'
      BEGIN
         DECLARE @cRDLineNo NVARCHAR(5)
         DECLARE @cCartonNo NVARCHAR(5)
         DECLARE @cCartonID NVARCHAR(18)

         SELECT 
            @cCartonNo = O_Field03, 
            @cCartonID = I_Field11
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Get line with balance
         SET @cRDLineNo = ''
         SELECT @cRDLineNo = ReceiptLineNumber
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND QTYExpected > BeforeReceivedQTY
            AND UserDefine05 = @cCartonNo
         ORDER BY ReceiptLineNumber

         -- Receive
         IF @cRDLineNo = ''
         BEGIN
            SET @nErrNo = 126351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RDDtl changed
            GOTO Quit
         END
         ELSE
         BEGIN
            DECLARE @cConfirmPosition NVARCHAR(1)
            SET @cConfirmPosition = rdt.RDTGetConfig( @nFunc, 'ConfirmPosition', @cStorerKey)      

            UPDATE ReceiptDetail WITH (ROWLOCK) SET 
               BeforeReceivedQTY = BeforeReceivedQTY + 1,
               ToID = CASE WHEN @cConfirmPosition <> '0' THEN @cCartonID ELSE ToID END, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE Receiptkey = @cReceiptKey
               AND ReceiptLineNumber = @cRDLineNo
            SET @nErrNo = @@ERROR  
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            
            COMMIT TRAN rdt_1829ExtUpd05
         END
      END
   END

GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_1829ExtUpd05
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO