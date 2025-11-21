SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593PackSlipRpt                                        */
/*                                                                            */
/* Customer: Granite                                                          */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev    Author     Purposes                                      */
/* 2024-10-29 1.0.0  NLT03      FCR-1096 re-print Order Level labels          */
/* 2024-11-11 1.0.1  Dennis     PickDetail status >= picked status            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593PackSlipRpt] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2), 
   @cParam1    NVARCHAR(60), 
   @cParam2    NVARCHAR(60), 
   @cParam3    NVARCHAR(60), 
   @cParam4    NVARCHAR(60), 
   @cParam5    NVARCHAR(60), 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cDropID                   NVARCHAR( 20),
      @cLabelPrinterGroup        NVARCHAR( 10),
      @cPaperPrinter             NVARCHAR( 10),
      @cFacility                 NVARCHAR( 5),
      @cLabelName                NVARCHAR( 30),
      @cConsigneeKey             NVARCHAR(15),
      @cBillToKey                NVARCHAR(15),
      @cOrderKey                 NVARCHAR( 10),
      @cPickConfirmStatus        NVARCHAR( 1),
      @cMPOCFlag                 NVARCHAR(10),
      @cOLPSCode                 NVARCHAR(10),
      @tPackSlipList             VariableTable,
      @nRowCount                 INT,
      @cOLPSDescription          NVARCHAR(15) = 'OlpsPlacement'

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   SET @cOrderKey = ISNULL(@cParam1, '')

   IF TRIM(@cOrderKey) = ''
   BEGIN
      SET @nErrNo = 227951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderKeyNeeded
      GOTO Quit
   END

   SELECT @nRowCount = COUNT( DISTINCT CaseID ) 
   FROM dbo.PICKDETAIL WITH(NOLOCK) 
   WHERE OrderKey = @cOrderKey 
      AND Status >= @cPickConfirmStatus
      AND TRIM(CaseID) <> ''

   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 227956
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickNotStart
      GOTO Quit
   END

    IF (SELECT COUNT( DISTINCT CaseID ) 
      FROM dbo.PICKDETAIL WITH(NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey 
         AND Status IN ('5', '9')
         AND TRIM(CaseID) <> '')
      <>
      (SELECT COUNT( DISTINCT RefNo )
      FROM dbo.PICKDETAIL PKD WITH(NOLOCK)
      INNER JOIN dbo.PackInfo PI WITH(NOLOCK) ON ISNULL(PKD.CaseID, '-1') = ISNULL(PI.RefNo, '')
      WHERE PKD.StorerKey = @cStorerKey
         AND PKD.OrderKey = @cOrderKey 
         AND PI.CartonStatus = 'PACKED'
         AND TRIM(ISNULL(RefNo, '')) <> '')
   BEGIN
      SET @nErrNo = 227952
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackNotDone
      GOTO Quit
   END

   SELECT @cConsigneeKey = ISNULL(ConsigneeKey, ''),
      @cBillToKey = ISNULL(BillToKey, '')
   FROM dbo.ORDERS WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

   --If an order has consigneekey or billtokey associated with codelkup.code where codelkup.listname = MPOCPERMIT  and short ! = 0, short not NULL, short not blank  then exclude from auto-print logic
   SELECT @cMPOCFlag = ISNULL(Short, '')
   FROM dbo.CODELKUP WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LISTNAME = 'MPOCPERMIT'
      AND Code IN (@cConsigneeKey, @cBillToKey)
   ORDER BY IIF(Code = @cConsigneeKey, 1, 2)

   IF TRIM(ISNULL(@cMPOCFlag, '')) NOT IN ('', '0')
   BEGIN
      SET @nErrNo = 227953
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MPOCOrder
      GOTO Quit
   END

   -- codelkup.listname = ‘LVSCUSPREF’ not available for consigneekey/billtokey
   IF NOT EXISTS (SELECT 1  
      FROM dbo.CODELKUP WITH(NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LISTNAME = 'LVSCUSPREF' 
         AND ISNULL(code2, '') <> ''
         AND code2 IN (@cConsigneeKey, @cBillToKey))
   BEGIN
      SET @nErrNo = 227955
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOrder
      GOTO Quit
   END

   SELECT @cOLPSCode = ISNULL(Long, '')
   FROM dbo.CODELKUP WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LISTNAME = 'LVSCUSPREF' 
      AND Description = 'OlpsPlacement'
      AND ISNULL(code2, '') <> ''
      AND code2 IN (@cConsigneeKey, @cBillToKey)
   ORDER BY IIF(code2 = @cConsigneeKey, 1, 2)

   SET @nRowCount = @@ROWCOUNT

   -- If cOLPSCode is not one of ('1', '2', '3', '5'), no need to print logi report automatically
   IF @nRowCount = 0 OR TRIM(ISNULL(@cOLPSCode, '')) NOT IN ('1', '2', '3', '5')
   BEGIN
      SET @nErrNo = 227954
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvOLPSCode
      GOTO Quit
   END

   SELECT 
      @cLabelPrinterGroup = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SET @cLabelName = 'LVSPSORD'
   INSERT INTO @tPackSlipList (Variable, Value) 
   VALUES 
      ( '@cStorerKey', @cStorerKey),
      ( '@cOrderKey', @cOrderKey)

   -- Print Order Level packing list label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
      @cLabelName, -- Report type
      @tPackSlipList, -- Report params
      'rdt_593PackSlipRpt',
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @nNoOfCopy = 1

   IF @nErrNo <> 0
   BEGIN
      GOTO Quit
   END

Fail:
   RETURN
Quit:

GO