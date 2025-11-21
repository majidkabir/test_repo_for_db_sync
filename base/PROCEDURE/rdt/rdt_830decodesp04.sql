SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_830DecodeSP04                                  */
/*                                                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode for PMI case                                         */
/*                                                                      */
/* Date        Author   Ver.  Purposes                                  */
/* 2024-10-29  PXL009   1.0   FCR-759 ID and UCC Length Issue           */
/************************************************************************/
CREATE   PROC [RDT].[rdt_830DecodeSP04]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cDropid      NVARCHAR( 20),
   @cPickSlipNo  NVARCHAR( 20),
   @cBarcode     NVARCHAR( 60),
   @cFieldName   NVARCHAR( 10),
   @cUPC         NVARCHAR( 20)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @cDefaultQTY  INT            OUTPUT,
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
   @cUserDefine01 NVARCHAR(30)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN   
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @cID              NVARCHAR( 18)
   DECLARE  @cTrimedBarcode   NVARCHAR( 60)

   IF @nFunc = 830 
   BEGIN
      IF @nStep = 2 -- LOC, DropID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cTrimedBarcode = LTRIM(RTRIM(@cBarcode))
               IF LEN(@cTrimedBarcode) <> 25
               BEGIN
                  SET @nErrNo = 226951
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
                  GOTO Quit
               END

               SET @cID = RIGHT(@cTrimedBarcode, 18)
               SET @cUserDefine01 = LEFT(@cTrimedBarcode, 7)
               SET @cUPC = @cID
               GOTO Quit
            END
         END
      END

      IF @nStep = 9 -- Verify ID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cTrimedBarcode = LTRIM(RTRIM(@cBarcode))
               IF LEN(@cTrimedBarcode) <= 18
               BEGIN
                  SET @cID = @cTrimedBarcode
                  SET @cUPC = @cID
                  GOTO Quit
               END

               IF LEN(@cTrimedBarcode) <> 25
               BEGIN
                  SET @nErrNo = 226952
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
                  GOTO Quit
               END

               SET @cID = RIGHT(@cTrimedBarcode, 18)
               SET @cUPC = @cID
               GOTO Quit
            END
         END
      END

   END

Quit:
END

GO