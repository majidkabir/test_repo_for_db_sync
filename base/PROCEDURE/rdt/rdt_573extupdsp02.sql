SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP02                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 15-10-2018  1.0  James    WMS-6612 Created                           */
/* 24-01-2022  1.1  Ung      WMS-18776 Add CartonType and VariableTable */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP02] (
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
          ,@cUCCLot            NVARCHAR( 10)
          ,@cUCCLOC            NVARCHAR( 10)
          ,@cUCCID             NVARCHAR( 18) 
          ,@cUCCSKU            NVARCHAR( 20) 
          ,@cTempUCC           NVARCHAR( 20) 
          ,@nUCCQty            INT
          ,@nTranCount         INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP02   
   
          
   IF @nStep = 4  
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Truncate 1st 2 chars when insert into ucc table
         SET @cTempUCC = SUBSTRING( @cUCC, 3, 18)

         DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber
         FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON ( RD.ReceiptKey = CR.ReceiptKey)
         WHERE RD.UserDefine01 = @cUCC
         AND   RD.FinalizeFlag = 'Y'
         AND   CR.Mobile = @nMobile
         OPEN CUR
         FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @cUCCLOC = ToLOC, 
                   @cUCCID = ToID, 
                   @cUCCLot = LOT, 
                   @cUCCSKU = SKU, 
                   @nUCCQty = QTY
            FROM dbo.ITRN WITH (NOLOCK)
            WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
            AND   SourceType = 'ntrReceiptDetailUpdate'

            IF @@ROWCOUNT > 0
            BEGIN
               INSERT INTO dbo.UCC (UCCNO, STORERKEY, EXTERNKEY, SKU, QTY, SOURCETYPE, 
               Receiptkey, ReceiptLineNumber, [Status], Lot, Loc, Id)
               VALUES
               (@cUCC, @cStorerKey, '', @cUCCSKU, @nUCCQty, 'rdt_573ExtUpdSP02', 
               @cReceiptKey, @cReceiptLineNumber, '1', @cUCCLot, @cUCCLOC, @cUCCID)

               IF @@ERROR <> 0
               BEGIN  
                  SET @nErrNo = 130151  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllScanned  
                  GOTO RollBackTran
               END 
            END

            FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber
         END
         CLOSE CUR
         DEALLOCATE CUR
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO