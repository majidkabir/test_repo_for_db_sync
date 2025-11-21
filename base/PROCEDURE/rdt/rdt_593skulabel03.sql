SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593SKULabel03                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-03-08 1.0  Ung        WMS-4239 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593SKULabel03] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LabelNo
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cDropID       NVARCHAR( 18)
   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cUPC          NVARCHAR( 30)
   DECLARE @cLottable04   NVARCHAR( 10)
   DECLARE @dLottable04   DATETIME
   DECLARE @cOrderKey     NVARCHAR( 10)
   DECLARE @cConsigneeKey NVARCHAR( 15)
   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cConsigneeSKU NVARCHAR( 15)
   DECLARE @nQTY          INT

   -- Parameter mapping
   SET @cDropID = @cParam1
   SET @cPickSlipNo = @cParam2
   SET @cUPC = @cParam3
   SET @cLottable04 = @cParam4

   -- Check blank
   IF @cPickSlipNo = '' AND @cDropID = ''
   BEGIN
      SET @nErrNo = 120901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/PSNO
      GOTO Quit
   END
   
   -- Drop ID
   IF @cDropID <> ''
   BEGIN
      -- Get PickDetail info
      SELECT TOP 1 
         @cOrderKey = OrderKey
      FROM PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND DropID = @cDropID
      
      -- Check ID picked
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 120902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
         GOTO Quit
      END
   END
   
   -- Pick slip
   IF @cPickSlipNo <> ''
   BEGIN
      -- Get pick header info
      SELECT TOP 1 
         @cOrderKey = OrderKey
      FROM PickHeader WITH (NOLOCK) 
      WHERE PickHeaderKey = @cPickSlipNo
      
      -- Check pick slip
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 120903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- PickSlipNo
         GOTO Quit
      END
   END   
   
   -- Get order info
   SELECT 
      @cChkStorerKey = StorerKey, 
      @cConsigneeKey = ConsigneeKey
   FROM Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
   -- Check order valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120904
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotFound
      GOTO Quit
   END
   
   -- Check order belong to storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 120905
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
      GOTO Quit
   END
   
   -- Check SKU blank
   IF @cUPC = ''
   BEGIN
      SET @nErrNo = 120906
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
      GOTO Quit
   END
   
   -- Get SKU/UPC
   DECLARE @nSKUCnt INT
   SET @nSKUCnt = 0

   EXEC RDT.rdt_GETSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT

   -- Check SKU valid
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 120907
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
      GOTO Quit
   END

   -- Check multi SKU barcode
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 120908
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
      GOTO Quit
   END
   
   -- Get SKU
   EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT
   
   SET @cSKU = @cUPC
   
   -- Check lottable04 blank
   IF @cLottable04 = ''
   BEGIN
      SET @nErrNo = 120909
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedLottable04
      EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
      GOTO Quit
   END
   
   -- Lottable04 format
   IF LEN( @cLottable04) = 4 -- YYMM
      SET @cLottable04 = '20' + LEFT( @cLottable04, 2) + '/' + SUBSTRING( @cLottable04, 3, 2) + '/01' -- YY/MM/DD

   -- Check valid lottable04
   IF rdt.rdtIsValidDate( @cLottable04) = 0
   BEGIN
      SET @nErrNo = 120910
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
      EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
      GOTO Quit
   END
   SET @dLottable04 = rdt.rdtConvertTodate( @cLottable04)
   
   -- Check PPA info
   DECLARE @nRowRef INT
   SET @nRowRef = 0
   IF @cPickSlipNo <> ''
      SELECT TOP 1 
         @nRowRef = RowRef, 
         @nQTY = CQTY
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
         AND SKU = @cSKU
         AND Lottable04 = @dLottable04
   ELSE
      SELECT TOP 1 
         @nRowRef = RowRef, 
         @nQTY = CQTY
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE DropID = @cDropID
         AND SKU = @cSKU
         AND Lottable04 = @dLottable04

   -- Check not yet PPA
   IF @nRowRef = 0
   BEGIN
      SET @nErrNo = 120911
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not yet PPA
      GOTO Quit
   END

   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cSKULabel NVARCHAR(10)
   SET @cSKULabel = rdt.rdtGetConfig( @nFunc, 'DCLabel', @cStorerKey)

   -- Report params
   DECLARE @tSKULabel AS VariableTable
   INSERT INTO @tSKULabel (Variable, Value) VALUES 
      ( '@cOrderKey',      @cOrderKey), 
      ( '@cDropID',        @cDropID), 
      ( '@cConsigneeSKU',  @cConsigneeSKU), 
      ( '@cSKU',           @cSKU), 
      ( '@cLottable04',    @cLottable04), 
      ( '@cQTY',           CAST( @nQTY AS NVARCHAR(10)))

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cSKULabel, -- Report type
      @tSKULabel, -- Report params
      'rdt_593SKULabel03', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit   
  
Quit:
      

GO