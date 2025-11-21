SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP08                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 17-02-2023  1.0  Ung      WMS-21436 base on rdt_573ExtUpdSP02        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP08] (
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
   @cLOC          NVARCHAR(20),
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

   DECLARE @nTranCount         INT
   DECLARE @cReceiptKey        NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cSKU               NVARCHAR( 20)
   DECLARE @nBeforeReceivedQTY INT
   DECLARE @cFinalizeFlag      NVARCHAR( 1)
   DECLARE @cLOT               NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP08   
   
   IF @nFunc = 573 -- UCC inbound receiving
   BEGIN
      IF @nStep = 4 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Loop ReceiptDetail
            DECLARE @curRD CURSOR 
            SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.SKU, RD.BeforeReceivedQTY, RD.FinalizeFlag
               FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                  JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON (RD.ReceiptKey = CR.ReceiptKey)
               WHERE RD.UserDefine01 = @cUCC
                  AND CR.Mobile = @nMobile
            OPEN @curRD
            FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @cSKU, @nBeforeReceivedQTY, @cFinalizeFlag
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- UCC not yet created
               IF NOT EXISTS( SELECT 1 
                  FROM dbo.UCC WTIH (NOLOCK)
                  WHERE UCCNo = @cUCC
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU)
               BEGIN
                  -- Get LOT
                  IF @cFinalizeFlag = 'Y'
                     SELECT @cLOT = LOT
                     FROM dbo.ITRN WITH (NOLOCK)
                     WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
                        AND SourceType = 'ntrReceiptDetailUpdate'
                  ELSE
                     SET @cLOT = ''

                  -- UCC
                  INSERT INTO dbo.UCC 
                     (UCCNo, StorerKey, ExternKey, SKU, QTY, SourceType, 
                      ReceiptKey, ReceiptLineNumber, [Status], LOT, LOC, ID)
                  VALUES
                     (@cUCC, @cStorerKey, '', @cSKU, @nBeforeReceivedQTY, 'rdt_573ExtUpdSP08', 
                      @cReceiptKey, @cReceiptLineNumber, '1', @cLOT, @cLOC, @cID)
                  IF @@ERROR <> 0
                  BEGIN  
                     SET @nErrNo = 196651  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS UCC Fail  
                     GOTO RollBackTran
                  END 
               END

               FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @cSKU, @nBeforeReceivedQTY, @cFinalizeFlag
            END
         END
      END
   END
   
   COMMIT TRAN rdt_573ExtUpdSP08
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP08 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO