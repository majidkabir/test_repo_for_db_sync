SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PrintPackingListAndGS1_PL                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print packing list                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 28-05-2012 1.0  Ung      SOS245083 change master and child carton    */
/*                          on tracking no, print GS1                   */
/* 2014-03-03 1.4  Ung      SOS303042 DataWindow base on RoutingTool    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PrintPackingListAndGS1_PL] (
   @nMobile     INT,
   @cLangCode   NVARCHAR( 3),
   @cPrinter    NVARCHAR(10),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cPickSlipNo NVARCHAR( 10),  
   @nErrNo      INT  OUTPUT,
   @cErrMsg     NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @b_success   INT,
   @b_Debug     INT,
   @cLabelNo    NVARCHAR( 20),
   @cTCPGS1Sent NVARCHAR( 1),
   @cRefNo      NVARCHAR( 20),
   @cRefNo2     NVARCHAR( 20),
   @cBatchNo    NVARCHAR( 20),
   @cDropIDType NVARCHAR( 10),
   @cGS1TemplatePath NVARCHAR(120),
   @cEtcTemplateID   NVARCHAR( 60), 
   @cDataWindow NVARCHAR( 50),  
   @cTargetDB   NVARCHAR( 20)

-- Get DataWindow
SET @cDataWindow = ''
SELECT TOP 1
     @cDataWindow = O.RoutingTool
FROM dbo.PickDetail PD WITH (NOLOCK)
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
WHERE PD.PickSlipNo = @cPickSlipNo

-- Get packing list info
SET @cTargetDB = ''
SELECT TOP 1
   -- @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
FROM RDT.RDTReport WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND ReportType = 'PACKLIST'
   -- AND DataWindow = @cDataWindow

-- Check data window
IF ISNULL( @cDataWindow, '') = ''
BEGIN
   SET @nErrNo = 76751
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
   GOTO Quit
END

-- Check database
IF ISNULL( @cTargetDB, '') = ''
BEGIN
   SET @nErrNo = 76752
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
   GOTO Quit
END

-- Insert print job
EXEC RDT.rdt_BuiltPrintJob
   @nMobile,
   @cStorerKey,
   'PACKLIST',       -- ReportType
   'PRINT_PACKLIST', -- PrintJobName
   @cDataWindow,
   @cPrinter,
   @cTargetDB,
   @cLangCode,
   @nErrNo  OUTPUT,
   @cErrMsg OUTPUT,
   @cPickSlipNo

-- Stamp packing list printed
UPDATE dbo.PackHeader SET ManifestPrinted = '1' WHERE PickSlipNo = @cPickSlipNo
IF @@ERROR <> 0
BEGIN
   SET @nErrNo = 76753
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackHdrFail
   GOTO Quit
END

Quit:

GO