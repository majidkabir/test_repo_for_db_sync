SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_628Decode01                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: To update lottable02 value captured to Receipt.UserDefine09    */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-03-14 1.0  James   WMS-2605 Created                                */
/* 2019-06-11 1.1  James   Add checking on valid input (james01)           */
/***************************************************************************/

CREATE PROC [RDT].[rdt_628Decode01](
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 60),
   @cLOC           NVARCHAR( 10)  OUTPUT,
   @cID            NVARCHAR( 18)  OUTPUT,
   @cSKU           NVARCHAR( 20)  OUTPUT,
   @cLottable01    NVARCHAR( 18)  OUTPUT,
   @cLottable02    NVARCHAR( 18)  OUTPUT,
   @cLottable03    NVARCHAR( 18)  OUTPUT,
   @dLottable04    DATETIME       OUTPUT,
   @dLottable05    DATETIME       OUTPUT,
   @cLottable06    NVARCHAR( 30)  OUTPUT,
   @cLottable07    NVARCHAR( 30)  OUTPUT,
   @cLottable08    NVARCHAR( 30)  OUTPUT,
   @cLottable09    NVARCHAR( 30)  OUTPUT,
   @cLottable10    NVARCHAR( 30)  OUTPUT,
   @cLottable11    NVARCHAR( 30)  OUTPUT,
   @cLottable12    NVARCHAR( 30)  OUTPUT,
   @dLottable13    DATETIME       OUTPUT,
   @dLottable14    DATETIME       OUTPUT,
   @dLottable15    DATETIME       OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLot02_1   NVARCHAR( 18),
           @cLot02_2   NVARCHAR( 18),
           @cInField01 NVARCHAR( 60),
           @cInField02 NVARCHAR( 60),
           @cInField03 NVARCHAR( 60),
           @nLblLength INT,
           @nSKUCnt    INT,
           @bSuccess   INT

   IF @cBarcode = ''
      GOTO Quit

   SELECT @cInField01 = I_Field01,
          @cInField02 = I_Field02,
          @cInField03 = I_Field03
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- SKU not key in, no need decode. Exit as usual
   IF ISNULL( @cInField03, '') = ''
   BEGIN
      SET @cLOC = @cInField01
      SET @cID = @cInField02
      SET @cSKU = ''
      GOTO Quit
   END

   SET @nLblLength = 0
   SET @nLblLength = LEN(ISNULL(RTRIM(@cBarcode),''))

   IF @nLblLength = 0
   BEGIN
      SET @nErrNo = 140001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label
      GOTO Quit
   END

   SET @cLOC = ''
   SET @cID = ''
   SET @cSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13)

   IF @cSKU = ''
   BEGIN
      SET @nErrNo = 140002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label
      GOTO Quit
   END

   EXEC [RDT].[rdt_GETSKUCNT]
      @cStorerKey  = @cStorerKey,
      @cSKU        = @cSKU,
      @nSKUCnt     = @nSKUCnt       OUTPUT,
      @bSuccess    = @bSuccess      OUTPUT,
      @nErr        = @nErrNo        OUTPUT,
      @cErrMsg     = @cErrMsg       OUTPUT

   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 140003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label
      GOTO Quit
   END
   ELSE
   BEGIN
      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerkey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @bSuccess      OUTPUT,
         @nErr        = @nErrNo        OUTPUT,
         @cErrMsg     = @cErrMsg       OUTPUT
   END

   SET @cLot02_1 = SUBSTRING( RTRIM( @cBarcode), 16, 12)
   SET @cLot02_2 = SUBSTRING( RTRIM( @cBarcode), 28, 2)
   SET @cLottable02 = RTRIM( @cLot02_1) + '-' + RTRIM( @cLot02_2)
Quit:  


END

GO