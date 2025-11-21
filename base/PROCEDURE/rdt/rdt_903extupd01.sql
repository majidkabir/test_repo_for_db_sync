SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_903ExtUpd01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 13-03-2018  1.0  Ung         WMS-4238 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_903ExtUpd01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cType          NVARCHAR( 10),
   @cRefNo         NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT,
   @cLottableCode  NVARCHAR( 30),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nRowRef        INT,
   @cQTY_PPA       NVARCHAR( 10), 
   @cQTY_CHK       NVARCHAR( 10), 
   @cCHK_SKU       NVARCHAR( 10), 
   @cCHK_QTY       NVARCHAR( 10), 
   @cPPA_SKU       NVARCHAR( 10), 
   @cPPA_QTY       NVARCHAR( 10), 
   @nErrNo         INT          OUTPUT,     
   @cErrMsg        NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR(10)
   DECLARE @cPaperPrinter NVARCHAR(10)

   IF @nFunc = 903 -- PPA lottable
   BEGIN
      IF @nStep = 4 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cDropID <> '' -- PPA by carton ID
            BEGIN
               DECLARE @nCQTY INT
               DECLARE @nPQTY INT
               DECLARE @cPickConfirmStatus NVARCHAR( 1)
               
               -- Get storer config
               SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
               IF @cPickConfirmStatus = '0'
                  SET @cPickConfirmStatus = '5'
               
               SELECT @nPQTY =  ISNULL( SUM( QTY), 0)
               FROM PickDetail WITH (NOLOCK)  
               WHERE DropID = @cDropID  
                  AND StorerKey = @cStorerKey 
                  AND SKU = @cSKU
                  AND Status <> '4'
                  AND Status >= @cPickConfirmStatus

               -- Check exceed QTY (SKU level)
               SELECT @nCQTY =  ISNULL( SUM( CQTY), 0)
               FROM rdt.rdtPPA LA WITH (NOLOCK)  
               WHERE DropID = @cDropID  
                  AND StorerKey = @cStorerKey 
                  AND SKU = @cSKU

               IF @nCQTY > @nPQTY
               BEGIN
                  SET @nErrNo = 122101
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU QTY Excess
                  GOTO Quit
               END
            END
            
            -- Storer configure
            DECLARE @cDCLabel NVARCHAR(10)
            SET @cDCLabel = rdt.rdtGetConfig( @nFunc, 'DCLabel', @cStorerKey)

            IF @cDCLabel <> '0'
            BEGIN
               DECLARE @cConsigneeKey  NVARCHAR(15)
               DECLARE @cConsigneeSKU  NVARCHAR(15)

               -- Get login info
               SELECT
                  @cLabelPrinter = Printer,
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Get order info
               SELECT TOP 1
                  @cOrderKey = OrderKey
               FROM PickDetail WITH (NOLOCK)
               WHERE DropID = @cDropID
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- Get order info
               SELECT @cConsigneeKey = ConsigneeKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               -- Get consignee SKU
               SET @cConsigneeSKU = ''
               SELECT @cConsigneeSKU = ConsigneeSKU
               FROM ConsigneeSKU WITH (NOLOCK)
               WHERE ConsigneeKey = @cConsigneeKey
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- Report params
               DECLARE @tDCLabel AS VariableTable
               INSERT INTO @tDCLabel (Variable, Value) VALUES
                  ( '@cOrderKey',      @cOrderKey),
                  ( '@cDropID',        @cDropID),
                  ( '@cConsigneeSKU',  @cConsigneeSKU),
                  ( '@cSKU',           @cSKU),
                  ( '@cLottable04',    rdt.rdtFormatDate(@dLottable04)),
                  ( '@cQTY',           CAST( @nQTY AS NVARCHAR(5)))

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cDCLabel, -- Report type
                  @tDCLabel, -- Report params
                  'rdt_903ExtUpd01',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               
               IF @nErrNo <> 0
                  SET @nErrNo = 0
            END
         END
      END

      IF @nStep = 5  -- Statistic
      BEGIN
         -- Status = complete
         IF CAST( @cPPA_SKU AS INT) = CAST( @cCHK_SKU AS INT) AND
            CAST( @cPPA_QTY AS INT) = CAST( @cCHK_QTY AS INT)
         BEGIN
            -- Storer configure
            DECLARE @cPalletManifest NVARCHAR(10)
            SET @cPalletManifest = rdt.rdtGetConfig( @nFunc, 'PalletManifest', @cStorerKey)

            IF @cPalletManifest <> '0'
            BEGIN
               -- Get login info
               SELECT
                  @cLabelPrinter = Printer,
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Get order info
               SELECT TOP 1
                  @cOrderKey = OrderKey
               FROM PickDetail WITH (NOLOCK)
               WHERE DropID = @cDropID
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- Report params
               DECLARE @tPalletManifest AS VariableTable
               INSERT INTO @tPalletManifest (Variable, Value) VALUES
                  ( '@cOrderKey', @cOrderKey),
                  ( '@cDropID',   @cDropID)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cPalletManifest, -- Report type
                  @tPalletManifest, -- Report params
                  'rdt_903ExtUpd01',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               
               IF @nErrNo <> 0
                  SET @nErrNo = 0
            END
         END
      END
   END

Quit:

END

GO