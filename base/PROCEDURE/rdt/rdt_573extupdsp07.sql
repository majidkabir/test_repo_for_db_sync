SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP07                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2022-11-23  1.0  James    WMS-21207 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP07] (
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
          ,@cLottable03        NVARCHAR( 18) 
          ,@cUserName          NVARCHAR( 18)
          ,@nTranCount         INT
          ,@nAlphaCnt          INT = 0
          ,@cXdockKey          NVARCHAR( 18) = ''
          ,@cPrevReceiptKey    NVARCHAR( 10) = ''
          
   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP07   
          
   IF @nStep = 1  
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.Lottable03
         FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON ( RD.ReceiptKey = CR.ReceiptKey)
         WHERE CR.Mobile = @nMobile
         AND   RD.Lottable06 <> ''
         AND   LEN( RD.Lottable06) >= 10
         ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
         OPEN CUR
         FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber, @cLottable03
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	IF @cPrevReceiptKey <> @cReceiptKey
         	BEGIN
         	   SET @cXdockKey = @cLottable03 + '-' + CHAR( ASCII( 'A' ) + @nAlphaCnt )
         	   SET @nAlphaCnt = @nAlphaCnt + 1
         	   SET @cPrevReceiptKey = @cReceiptKey
         	END
         	
         	UPDATE dbo.ReceiptDetail SET 
         	   XdockKey = @cXdockKey, 
         	   EditWho = @cUserName, 
         	   EditDate = GETDATE()
         	WHERE ReceiptKey = @cReceiptKey
         	AND   ReceiptLineNumber = @cReceiptLineNumber
         	   
            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 194151  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdSortCodeErr  
               GOTO RollBackTran
            END 

            FETCH NEXT FROM CUR INTO @cReceiptKey, @cReceiptLineNumber, @cLottable03
         END
         CLOSE CUR
         DEALLOCATE CUR
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP07 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO