SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveByDropID_PrintPackList                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print Packing List From MoveByDropID                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2011-12-28  1.0  SHONG       Created                                 */
/* 2011-12-29  1.1  James       Bug fix on print packlist (james01)     */
/* 2011-12-29  1.2  ChewKP      Stamp PackHeader.ManifestPrinted = '1'  */
/*                              (ChewKP01)                              */
/* 2012-02-27  1.3  James       By pass packheader status checking when */
/*                              config DynamicPickSkipPackCfm turned on */
/*                              (james02)                               */
/* 2014-03-03  1.4  Ung         SOS303042 DataWindow base on RoutingTool*/
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveByDropID_PrintPackList] (
   @nMobile     INT,
--   @cFromDropID NVARCHAR( 18),
   @cToDropID   NVARCHAR( 20),    -- (james01)
   @cStorerKey  NVARCHAR( 15),
   @cLangCode   VARCHAR (3),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


-- Misc variable
DECLARE
   @cDataWindow NVARCHAR( 50),
   @cTargetDB   NVARCHAR( 20),
   @cOption     NVARCHAR( 1)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,

   @nInputKey   INT,
   @nMenu       INT,

   @cPickSlipNo     NVARCHAR( 10),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR( 18),
   @cLabelPrinter   NVARCHAR( 10),
   @cPaperPrinter   NVARCHAR( 10)

SELECT
   @cLabelPrinter = Printer,
   @cPaperPrinter = Printer_Paper
FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Check paper printer blank
IF @cPaperPrinter = ''
BEGIN
   SET @nErrNo = 74959
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
   EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label
   GOTO Quit
END

DECLARE @cManifestPrinted     NVARCHAR( 10)
DECLARE @cPackStatus          NVARCHAR( 1)
DECLARE @nPackingListRequired INT

-- Get PickSlipNo by DropID
SET @cPickSlipNo = ''
SELECT TOP 1
   @cPickSlipNo = PickSlipNo
FROM dbo.PackDetail WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
  AND DropID   = @cToDropID      -- (james01)

-- Get PackHeader info
SELECT
   @cPackStatus = Status,
   @cManifestPrinted = ManifestPrinted
FROM dbo.PackHeader WITH (NOLOCK)
WHERE PickSlipNo = @cPickSlipNo

-- If the configkey turned on then packcfm only happen after print packlist
-- We have to bypass the packheader status checking
IF rdt.RDTGetConfig( 0, 'DynamicPickSkipPackCfm', @cStorerKey) = '1'
BEGIN
   SET @cPackStatus = '5'
END

-- Check if packing list printed
IF @cManifestPrinted = '1' OR @cPackStatus < '5'
BEGIN
   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, STEP1, STEP2, STEP3, COL1) -- (james02)
   VALUES ('PRINT_PACK_LIST1', GETDATE(), @cPickSlipNo, @cManifestPrinted, @cPackStatus, @cToDropID)
   GOTO QUIT
END

-- Get packing list required
SET @nPackingListRequired = 0
SELECT TOP 1
     @nPackingListRequired = CASE WHEN SUBSTRING( O.B_Fax1, 9, 1) IN ('I', 'P', 'B') THEN 1 ELSE 0 END,
     @cStorerKey           = O.StorerKey,
     @cDataWindow          = O.RoutingTool
FROM dbo.PickDetail PD WITH (NOLOCK)
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
WHERE PD.PickSlipNo = @cPickSlipNo

-- Check if packing list printed, If Not do nothing
IF @nPackingListRequired <> 1
BEGIN
   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, STEP1, STEP2, STEP3, STEP4, COL1) -- (james02)
   VALUES ('PRINT_PACK_LIST2', GETDATE(), @cPickSlipNo, @cManifestPrinted, @cPackStatus, @nPackingListRequired, @cToDropID)
   GOTO QUIT
END

-- Print packing list
IF @nPackingListRequired = 1 AND -- Packing list required
   @cPackStatus >= '5' AND       -- Pack confirmed
   @cManifestPrinted <> '1'      -- Packing list not printed
BEGIN
   -- Get packing list info
   SET @cDataWindow = ''
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
      GOTO QUIT
   END

         -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      GOTO QUIT
   END

   -- Print packing list
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'PACKLIST',       -- ReportType
      'PRINT_PACKLIST', -- PrintJobName
      @cDataWindow,
      @cPaperPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cPickSlipNo

   -- Stamp packing list printed -- (ChewKP01)
   UPDATE dbo.PackHeader SET ManifestPrinted = '1' WHERE PickSlipNo = @cPickSlipNo

END

QUIT:

END -- Procedure

GO