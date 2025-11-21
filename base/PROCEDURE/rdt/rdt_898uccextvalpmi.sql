SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_898UCCExtValPMI                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2024-10-30 1.0  PYU015  UWP-26527 Created                            */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898UCCExtValPMI]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cId            NVARCHAR(20)
          ,@cUserDefine07  NVARCHAR(30) 
          ,@cStorerKey     NVARCHAR(15)
          ,@nStep          INT
          ,@nInputKey      INT
          ,@cToLottable01    NVARCHAR(18)
          ,@cToLottable02    NVARCHAR(18)
          ,@cToLottable03    NVARCHAR(18)
          ,@dToLottable04    DATETIME

   SELECT @cStorerKey = StorerKey,
          @nStep = Step,
          @nInputKey = InputKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile 

   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nStep = 6 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
           SELECT @cId = ToId
                , @cLottable01 = dtl.Lottable01
                , @cLottable02 = dtl.Lottable02
                , @cLottable03 = dtl.Lottable03
                , @dLottable04 = dtl.Lottable04
             FROM UCC WITH (NOLOCK)
            INNER JOIN ReceiptDetail dtl WITH (NOLOCK) 
            ON UCC.Storerkey = dtl.StorerKey 
            AND UCC.ExternKey = dtl.ExternReceiptKey 
            AND UCC.Userdefined07 = dtl.ExternLineNo 
            AND dtl.DuplicateFrom IS NULL
            WHERE dtl.Storerkey = @cStorerKey
              AND dtl.ReceiptKey = @cReceiptKey
              AND UCC.UCCNo = @cUCC

           IF @@ROWCOUNT = 0
           BEGIN
              SET @nErrNo = 219926
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC
              GOTO Quit
           END

           SELECT TOP 1 
                  @cToLottable01 = dtl.Lottable01
                , @cToLottable02 = dtl.Lottable02
                , @cToLottable03 = dtl.Lottable03
                , @dToLottable04 = dtl.Lottable04
             FROM RECEIPTDETAIL dtl WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
             AND ReceiptKey = @cReceiptKey
             AND ToId = @cToID

             IF @@ROWCOUNT > 0
             BEGIN
               IF @cLottable01 <> @cToLottable01 
               OR @cLottable02 <> @cToLottable02 
               OR @cLottable03 <> @cToLottable03 
               OR @dLottable04 <> @dToLottable04
               BEGIN
                 SET @nErrNo = 219927
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DisallowMixLot
                 GOTO Quit
               END
             END
        END
      END
   END
   
Quit:

END


GO