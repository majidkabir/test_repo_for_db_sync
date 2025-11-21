SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1823DecodeSP01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-03-2016  James     1.0   SOS365315 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1823DecodeSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
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

   IF @nFunc = 1823 -- Normal receiving
   BEGIN
      IF @nStep = 3 -- SSCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> '' 
            BEGIN
               -- SSCC
               IF LEN( @cBarcode) > 18
               BEGIN
                  DECLARE @cSSCC  NVARCHAR( 60)
                  DECLARE @cCode  NVARCHAR( 10)
                  DECLARE @cShort NVARCHAR( 10)
                  DECLARE @cLong  NVARCHAR( 250)
                  DECLARE @cUDF01 NVARCHAR( 60)
               
                  -- Get SSCC decode rule (SOS 361419)
                  SELECT 
                     @cCode = Code,                -- Prefix of barcode
                     @cShort = ISNULL( Short, 0),  -- Lenght of string to take, after the prefix 
                     @cLong = ISNULL( Long, ''),   -- String indicate don't need to decode (not used) 
                     @cUDF01 = ISNULL( UDF01, '')  -- Prefix of actual string after decode
                  FROM dbo.CodeLKUP WITH (NOLOCK) 
                  WHERE ListName = 'SSCCDECODE'
                     AND StorerKey = @cStorerKey

                  -- Check rule valid
                  IF @@ROWCOUNT <> 1
                  BEGIN
                     SET @nErrNo = 98651
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CodeLKUP
                     GOTO Quit
                  END

                  -- Check valid prefix
                  IF @cCode <> SUBSTRING( @cBarCode, 1, LEN( @cCode))
                  BEGIN
                     SET @nErrNo = 98652
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
                     GOTO Quit
                  END
                  
                  -- Check valid length
                  IF rdt.rdtIsValidQty( @cShort, 1) = 0
                  BEGIN
                     SET @nErrNo = 98653
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length
                     GOTO Quit
                  END
                  
                  -- Get actual string
                  SET @cSSCC = SUBSTRING( @cBarcode, LEN( @cCode) + 1, CAST( @cShort AS INT))
                  
                  -- Check valid length
                  IF LEN( @cSSCC) <> @cShort
                  BEGIN
                     SET @nErrNo = 98654
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length
                     GOTO Quit
                  END
               
                  -- Check actual string prefix
                  IF @cUDF01 <> SUBSTRING( @cSSCC, 1, LEN( @cUDF01))
                  BEGIN
                     SET @nErrNo = 98655
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid prefix
                     GOTO Quit
                  END      
                  
                  -- Check actual string is numeric
                  DECLARE @i INT
                  DECLARE @c NVARCHAR(1)
                  SET @i = 1
                  WHILE @i <= LEN( RTRIM( @cSSCC))
                  BEGIN
                     SET @c = SUBSTRING( @cSSCC, @i, 1)
                     IF NOT (@c >= '0' AND @c <= '9')
                     BEGIN
                        SET @nErrNo = 98656
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
                        GOTO Quit
                     END
                     SET @i = @i + 1
                  END   
                  
                  SET @cLottable09 = @cSSCC
               END
               ELSE
                  SET @cLottable09 = @cBarcode
            END

         END
      END
   END

Quit:

END

GO