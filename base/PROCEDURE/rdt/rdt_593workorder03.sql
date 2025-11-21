SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593WorkOrder03                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-03-15 1.0  Ung        WMS-8243 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593WorkOrder03] (
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

   DECLARE @cLabelPrinter   NVARCHAR( 10)
   DECLARE @cPaperPrinter   NVARCHAR( 10)
   DECLARE @cOrderKey       NVARCHAR( 10)
   DECLARE @cFacility       NVARCHAR( 5)
   DECLARE @cPrintFlag      NVARCHAR( 1)

   -- Parameter mapping
   SET @cOrderKey = @cParam1

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 136551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END
   
   -- Get order info
   SELECT @cPrintFlag = PrintFlag
   FROM Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey 
      AND StorerKey = @cStorerKey
   
   -- Check order valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 136552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END

   -- Check order picked
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status <> '5')
   BEGIN
      SET @nErrNo = 136553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order not pick
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END
      
   -- Check need workorder
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey 
         AND Lottable07 = 'Y')
   BEGIN
      SET @nErrNo = 136554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No workorder
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
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
      'rdt_593WorkOrder03', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit   
  
   -- Update order as printed
   IF @cPrintFlag <> 'Y'
   BEGIN
      UPDATE Orders SET
         PrintFlag = 'Y', 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 136555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail
         GOTO Quit
      END
   END
   
Quit:
      

GO