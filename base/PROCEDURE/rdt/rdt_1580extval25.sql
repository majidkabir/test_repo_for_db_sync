SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal25                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID                                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 20-05-2022  1.0  yeekung     WMS-19640 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal25]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cItemClass NVARCHAR(20),
           @cRDLottable01 NVARCHAR(20),
           @cRDLottable02 NVARCHAR(20),
           @cCodelkupDesc NVARCHAR(60),
           @cSKUItemClass NVARCHAR(20)
    
    IF @nStep = 3
    BEGIN
      IF EXISTS(SELECT 1
                FROM DROPID (NOLOCK)
                WHERE DROPID=@ctoID
                AND status='9')
      BEGIN
         SET @nErrNo = 186702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDClosed
         GOTO Quit
      END
    END
   
   
   IF @nStep = 5 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM RECEIPTDETAIL (NOLOCK)
                     WHERE receiptkey=@cReceiptkey
                        AND ToID =@cToID
                        AND storerkey=@cStorerkey)
         BEGIN
            SELECT  TOP 1  @cItemClass=itemclass,
                     @cRDLottable01=RD.lottable01,
                     @cRDLottable02=RD.lottable02
            FROM RECEIPTDETAIL RD (NOLOCK) 
            JOIN SKU SKU (NOLOCK) ON RD.SKU=SKU.SKU AND RD.storerkey=SKU.storerkey
            WHERE receiptkey=@cReceiptkey
               AND ToID =@cToID
               AND SKU.storerkey=@cStorerkey

            SELECT @cCodelkupDesc=description
            FROM codelkup (NOLOCK)
            WHERE LISTNAME='Itemclass'
            AND storerkey=@cStorerkey
            AND code=@cItemClass

            SELECT @cSkuItemclass =itemclass
            FROM SKU (NOLOCK)
            WHERE SKU =@cSKU
            AND storerkey = @cStorerkey

            IF EXISTS(SELECT 1
                     FROM codelkup (NOLOCK)
                     WHERE LISTNAME='Itemclass'
                     AND storerkey=@cStorerkey
                     AND code=@cSkuItemclass
                     AND description <>@cCodelkupDesc) 
                 OR @cRDLottable01<>@cLottable01
                 OR @cRDLottable02<>@cLottable02
            BEGIN
               SET @nErrNo = 186701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot03<>HostWh
               GOTO Quit
            END
         END
      END
   END


Quit:
END

GO