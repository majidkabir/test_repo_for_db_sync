SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600DecodeSP15                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-05-04  Yeekung   1.0   WMS-22369 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP15] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 2000)  OUTPUT,
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
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUCnt INT
   DECLARE @cUOM NVARCHAR(20)
   DECLARE @cPackKey NVARCHAR(20)
   DECLARE @2DBarcode NVARCHAR(MAX)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @2DBarcode = V_MAX
            FROM RDT.RDTMOBREC
            WHERE mobile = @nMobile

 
             
            DECLARE @tUCCtbl Table 
            ( 
            ROW INT NOT NULL identity(1,1),
            Value NVARCHAR(MAX)
            )
            DECLARE @cPatindex INT

            set @2DBarcode = replace(@2DBarcode,'<rs>','')

            set @2DBarcode = replace(@2DBarcode,'<eot>','')


            set @2DBarcode = replace(@2DBarcode,'<gs>',' ')


            set @2DBarcode = replace(@2DBarcode,'-','&')

            WHILE (1 = 1)
            BEGIN
               select  @cPatindex= patindex('%[^A-Z|0-9|/|&|'' '']%',@2DBarcode) 

               IF @cPatindex <>0
               BEGIN
                  SET @2DBarcode = replace(@2DBarcode,substring(@2DBarcode,@cPatindex,1),' ')  
               END
               ELSE
                  BREAK
            END


            set @2DBarcode = replace(@2DBarcode,'&','-')


            insert into @tUCCtbl (Value)
            select value from string_split(@2DBarcode,' ') where value<>''

            SELECT @cSKU = Value
            FROM @tUCCtbl
            WHERE ROW = '1'

            SELECT @cLottable02 = Value
            FROM @tUCCtbl
            WHERE ROW = '2'

            
            SELECT @nQTY = value
            FROM @tUCCtbl
            WHERE ROW = '10'

            IF NOT EXISTS( SELECT 1 
                           FROm RECEIPTDETAIL (NOLOCK)
                           WHERE SKU =@cSKU
                           AND Lottable02 = @cLottable02
                           AND ReceiptKey =@cReceiptKey
                           AND Storerkey = @cStorerKey)
            BEGIN
               SET @nErrNo = 200601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Receipt
               GOTO QUIT
            END

            
            IF EXISTS( SELECT 1 
                           FROm RECEIPTDETAIL (NOLOCK)
                           WHERE SKU <> @cSKU
                           AND ReceiptKey =@cReceiptKey
                           AND Storerkey = @cStorerKey
                           AND toid = @cID) 
              OR  EXISTS ( SELECT 1 
                           FROm RECEIPTDETAIL (NOLOCK)
                           WHERE Lottable02 <> @cLottable02
                           AND SKU =  @cSKU
                           AND ReceiptKey =@cReceiptKey
                           AND Storerkey = @cStorerKey
                           AND toid = @cID) 
            BEGIN
               SET @nErrNo = 200602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicatePallet
               GOTO QUIT
            END



            SELECT @cLottable01 = Lottable01,
                   @cLottable06 = Lottable06,
                   @cLottable07 = Lottable07,
                   @cLottable08 = Lottable08,
                   @cLottable09 = Lottable09
            FROm RECEIPTDETAIL (NOLOCK)
            WHERE SKU =@cSKU
               AND Lottable02 = @cLottable02
               AND ReceiptKey =@cReceiptKey
               AND Storerkey = @cStorerKey

         END
           
      END
   END

Quit:

END

GO