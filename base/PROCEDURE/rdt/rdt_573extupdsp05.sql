SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP05                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2020-10-13  1.0  James    WMS-15269 Created                          */
/* 2022-01-24  1.1  Ung      WMS-18776 Add CartonType and VariableTable */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP05] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR(3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5),
   @cReceiptKey1  NVARCHAR(20),
   @cReceiptKey2  NVARCHAR(20),
   @cReceiptKey3  NVARCHAR(20),
   @cReceiptKey4  NVARCHAR(20),
   @cReceiptKey5  NVARCHAR(20),
   @cLoc          NVARCHAR(20),
   @cID           NVARCHAR(18),
   @cUCC          NVARCHAR(20),
   @cCartonType   NVARCHAR(10),
   @tExtUpdate    VariableTable READONLY,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR(1024) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptLineNumber NVARCHAR( 5)
          ,@cReceiptKey        NVARCHAR( 10)
          ,@cUCCSKU            NVARCHAR( 20) 
          ,@nTranCount         INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP05   
          
   IF @nStep = 4  
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.Sku
         FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON ( RD.ReceiptKey = CR.ReceiptKey)
         WHERE RD.UserDefine01 = @cUCC
         AND   CR.Mobile = @nMobile
         OPEN CUR
         FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber, @cUCCSKU
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               Receiptkey = @cReceiptKey, 
               ReceiptLineNumber = @cReceiptLineNumber, 
               [Status] = '1', 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE UCCNo = @cUCC
            AND   Storerkey = @cStorerKey
            AND   SKU = @cUCCSKU
            AND   [Status] = '0'
               
            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 159951  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDATE UCC ERR  
               GOTO RollBackTran
            END 

            FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber, @cUCCSKU
         END
         CLOSE CUR
         DEALLOCATE CUR
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO