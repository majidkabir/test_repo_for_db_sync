SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP03                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Update receiptdetail.lottable01 = 'S'                       */
/*                                                                      */
/* Called from: rdtfnc_UCCInboundReceive                                */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 01-02-2019  1.0  James    WMS-7854 Created                           */
/* 24-01-2022  1.1  Ung      WMS-18776 Add CartonType and VariableTable */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP03] (
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

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP03   
   
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
          ,@cReceiptKey        NVARCHAR(10)
          ,@cUCCID             NVARCHAR(18) 
          
   IF @nFunc = 573 
   BEGIN
      IF @nStep = 4  
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @curRDExtUpd CURSOR
            SET @curRDExtUpd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptKey, ReceiptLineNumber
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE StorerKey   = @cStorerKey
               AND   Userdefine01  = @cUCC
               AND   BeforeReceivedQty > 0
               AND   FinalizeFlag <> 'Y'
            OPEN @curRDExtUpd
            FETCH NEXT FROM @curRDExtUpd INTO @cReceiptKey, @cReceiptLineNumber
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                  Lottable01 = 'S'
                 ,TrafficCop = NULL
               FROM dbo.ReceiptDetail RD
               WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNumber
                  
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 134251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdReceiptDetFail
                  GOTO RollBackTran
               END 
               
               FETCH NEXT FROM @curRDExtUpd INTO @cReceiptKey, @cReceiptLineNumber   
            END
            
         END
      END

   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO