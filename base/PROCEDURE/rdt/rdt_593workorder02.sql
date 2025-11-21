SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593WorkOrder02                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-03-15 1.0  Ung        WMS-8243 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593WorkOrder02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @cParam1Label  NVARCHAR( 20) OUTPUT,
   @cParam2Label  NVARCHAR( 20) OUTPUT,
   @cParam3Label  NVARCHAR( 20) OUTPUT,
   @cParam4Label  NVARCHAR( 20) OUTPUT,
   @cParam5Label  NVARCHAR( 20) OUTPUT,
   @cParam1Value  NVARCHAR( 60) OUTPUT,
   @cParam2Value  NVARCHAR( 60) OUTPUT,
   @cParam3Value  NVARCHAR( 60) OUTPUT,
   @cParam4Value  NVARCHAR( 60) OUTPUT,
   @cParam5Value  NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess        INT
   DECLARE @cOrderKey       NVARCHAR( 10)
   DECLARE @cDropID         NVARCHAR( 20)
   DECLARE @cUPC            NVARCHAR( 30)
   DECLARE @cSKU            NVARCHAR( 20)
   DECLARE @cECOMSingleFlag NVARCHAR( 1)
   DECLARE @cPrintFlag      NVARCHAR( 1)
   DECLARE @cReprint        NVARCHAR( 1)

   -- Parameter mapping
   SET @cDropID = @cParam1Value
   SET @cUPC = @cParam2Value

   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 135901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      GOTO Quit
   END

   -- Get order info
   SET @cOrderKey = ''
   SELECT TOP 1
      @cOrderKey = PD.OrderKey
   FROM Orders O WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE O.StorerKey = @cStorerKey
      AND PD.DropID = @cDropID
      AND O.ECOM_Single_Flag = 'S' -- Single
      AND O.PrintFlag <> 'Y'       -- Not yet printed
      AND OD.Lottable07 = 'Y'      -- Workorder

   -- Check order
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 135902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      SET @cParam1Value = ''
      GOTO Quit
   END

   -- Check blank
   IF @cUPC = ''
   BEGIN
      -- SET @nErrNo = 135903
      -- SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @nErrNo = -1
      GOTO Quit
   END

   -- Get SKU count
   DECLARE @nSKUCnt INT
   SET @nSKUCnt = 0
   EXEC RDT.rdt_GetSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC
      ,@nSKUCnt     = @nSKUCnt   OUTPUT
      ,@bSuccess    = @bSuccess  OUTPUT
      ,@nErr        = @nErrNo    OUTPUT
      ,@cErrMsg     = @cErrMsg   OUTPUT

   -- Check SKU valid
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 135904
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @cParam2Value = ''
      GOTO Quit
   END

   -- Check barcode return multi SKU
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 135905
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @cParam2Value = ''
      GOTO Quit
   END

   IF @nSKUCnt = 1
      EXEC rdt.rdt_GetSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

   SET @cSKU = @cUPC

   -- Get order info
   SET @cOrderKey = ''
   SELECT TOP 1
      @cOrderKey = PD.OrderKey, 
      @cPrintFlag = PrintFlag
   FROM Orders O WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cDropID
      AND O.ECOM_Single_Flag = 'S' -- Single
      -- AND O.PrintFlag <> 'Y'    -- Not yet printed
      AND OD.Lottable07 = 'Y'      -- Workorder
      AND PD.SKU = @cSKU
   ORDER BY CASE WHEN PrintFlag <> 'Y' THEN 1 ELSE 2 END

   -- Check SKU in drop ID
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 135906
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @cParam2Value = ''
      GOTO Quit
   END

   -- Check printed
   IF @cPrintFlag = 'Y'
   BEGIN
      SET @nErrNo = 135907
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU printed
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @cParam2Value = ''
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
   DECLARE @cWorkOrder NVARCHAR(10)
   SET @cWorkOrder = rdt.rdtGetConfig( @nFunc, 'WORKORDER', @cStorerKey)

   -- Report params
   DECLARE @tWorkOrder AS VariableTable
   INSERT INTO @tWorkOrder (Variable, Value) VALUES
      ( '@cOrderKey', @cOrderKey)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
      @cWorkOrder, -- Report type
      @tWorkOrder, -- Report params
      'rdt_593WorkOrder02',
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Update order as printed
   UPDATE Orders SET
      PrintFlag = 'Y',
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(),
      TrafficCop = NULL
   WHERE OrderKey = @cOrderKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 135908
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail
      GOTO Quit
   END

   -- Get order info
   SET @cOrderKey = ''
   SELECT TOP 1
      @cOrderKey = PD.OrderKey
   FROM Orders O WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE O.StorerKey = @cStorerKey
      AND PD.DropID = @cDropID
      AND O.ECOM_Single_Flag = 'S' -- Single
      AND O.PrintFlag <> 'Y'       -- Not yet printed
      AND OD.Lottable07 = 'Y'      -- Workorder

   -- Check order
   IF @cOrderKey = ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      SET @cParam1Value = '' -- DropID
      SET @cParam2Value = '' -- SKU
   END
   ELSE
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      SET @cParam2Value = '' -- SKU
   END

Quit:


GO