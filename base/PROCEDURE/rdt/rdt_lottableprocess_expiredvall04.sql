SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_ExpiredValL04                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: validate lottable04                                               */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 15-Aug-2019  YeeKung   1.0   WMS10111 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_ExpiredValL04]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cLoc          NVARCHAR( 10),
            @cReceiptKey   NVARCHAR( 10),
            @cShelflife    INT
 

   IF @cType = 'POST'
   BEGIN
      
      IF @nLottableNo = 4 
      BEGIN
         IF ISNULL( @dLottable04Value, '') = ''
         BEGIN
            SET @nErrNo = 143351 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable04 req
            GOTO Quit
         END

         SELECT @cLoc=V_Loc,
         @cReceiptKey =V_receiptkey
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE MOBILE=@nMobile
            AND STORERKEY=@cStorerKey

         SELECT @cShelflife = SHELFLIFE
         FROM SKU WITH (NOLOCK)
         WHERE SKU=@cSKU
            AND STORERKEY=@cStorerKey

         IF (@cLoc <> 'THHLDSTG')
         BEGIN
            
            IF EXISTS(SELECT 1 FROM receiptdetail WITH (NOLOCK) 
                     WHERE Receiptkey=@cReceiptKey 
                        AND toloc='THGSTAGE') AND (@dLottable04Value <= GETDATE())
            BEGIN
               SET @nErrNo = 143352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock Exp
               GOTO Quit
            END 

            IF @cShelflife <>''
            BEGIN
               IF EXISTS(SELECT 1 FROM receiptdetail WITH (NOLOCK) 
                  WHERE Receiptkey=@cReceiptKey 
                     AND toloc='THGSTAGE' )AND(@dLottable04Value <= GETDATE()+@cShelflife)
               BEGIN
                  SET @nErrNo = 143353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock Exp
                  GOTO Quit
               END  
            END         
            
         END

      END
      
   END

QUIT:
END

SET QUOTED_IDENTIFIER OFF

GO