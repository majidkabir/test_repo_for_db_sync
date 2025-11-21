SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855TempLabel01                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2025-01-23  1.0  Dennis       FCR-1824 Created                       */
/* 2025-02-05  1.1  CYU027   FCR-2630 Add Option=5 in step 5           */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_855TempLabel01
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @cValue01     NVARCHAR( 20),
   @cValue02     NVARCHAR( 20),
   @cValue03     NVARCHAR( 20),
   @cValue04     NVARCHAR( 20),
   @cValue05     NVARCHAR( 20),
   @cValue06     NVARCHAR( 20),
   @cValue07     NVARCHAR( 20),
   @cValue08     NVARCHAR( 20),
   @cValue09     NVARCHAR( 20),
   @cValue10     NVARCHAR( 20),
   @cTemplate    NVARCHAR( MAX),
   @cPrintData   NVARCHAR( MAX) OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount   INT
   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLabelNo    NVARCHAR(20)
   DECLARE @cExtTemplateSP    NVARCHAR(20),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cUserName      NVARCHAR( 20),
   @cReportType    NVARCHAR( 10),
   @cUDF02         NVARCHAR( 10)

   SELECT @cUserName = UserName FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @cExtTemplateSP = rdt.RDTGetConfig( @nFunc, 'ExtTemplateSP', @cStorerKey)

   -- Variable mapping
   SELECT @cLabelNo = @cValue01, @cReportType = @cValue02
   IF NOT EXISTS (
      SELECT 1 FROM dbo.ORDERS ord WITH(NOLOCK)
      INNER JOIN dbo.PickDetail pd WITH(NOLOCK) ON ord.OrderKey = pd.OrderKey
      INNER JOIN dbo.Wave w WITH(NOLOCK) ON ord.UserDefine09 = w.WaveKey
      WHERE ord.StorerKey = @cStorerKey
         AND pd.StorerKey = @cStorerKey
         AND pd.CaseID = @cLabelNo
         AND w.UserDefine09 = 'Y'
   )
      RETURN

   IF NOT EXISTS(
      SELECT 1 FROM RDT.RDTReporttoPrinter WITH(NOLOCK)
      WHERE Function_ID = @nFunc AND StorerKey = @cStorerKey AND PrinterID= 'PANDA' AND PrinterGroup = 'PANDA' AND ReportType = @cReportType
   )
      RETURN

   SELECT @cOrderKey = CASE WHEN COUNT( DISTINCT (OrderKey) ) = 1 THEN OrderKey ELSE 'MPOC' END
   FROM dbo.PickDetail WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND CaseID <> ''
      AND CaseID = @cLabelNo
   GROUP BY OrderKey

   EXECUTE [RDT].[rdt_LevisReplaceZPLCodeSP]
   @nMobile = @nMobile
   ,@nFunc = @nFunc
   ,@cLangCode = @cLangCode
   ,@cStorerKey = @cStorerKey
   ,@cValue01 = @cValue01
   ,@cValue02 = @cValue02
   ,@cValue03 = @cValue03
   ,@cValue04 = @cValue04
   ,@cValue05 = @cValue05
   ,@cValue06 = @cValue06
   ,@cValue07 = @cValue07
   ,@cValue08 = @cValue08
   ,@cValue09 = @cValue09
   ,@cValue10 = @cValue10
   ,@cTemplate = @cTemplate
   ,@cPrintData = @cPrintData OUTPUT
   ,@nErrNo = @nErrNo OUTPUT
   ,@cErrMsg = @cErrMSG OUTPUT

   IF @nErrNo <> 0
      GOTO QUIT

   IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtTemplateSP AND type = 'P')
   BEGIN
      -- Execute SP to merge data and template, output print data as ZPL code
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtTemplateSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, ' +
         ' @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, ' +
         ' @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMSG OUTPUT '

      SET @cSQLParam =
         '@nMobile      INT,            ' +
         '@nFunc        INT,            ' +
         '@cLangCode    NVARCHAR( 3),   ' +
         '@cStorerKey   NVARCHAR( 15),  ' +
         '@cValue01     NVARCHAR( 20),  ' +
         '@cValue02     NVARCHAR( 20),  ' +
         '@cValue03     NVARCHAR( 20),  ' +
         '@cValue04     NVARCHAR( 20),  ' +
         '@cValue05     NVARCHAR( 20),  ' +
         '@cValue06     NVARCHAR( 20),  ' +
         '@cValue07     NVARCHAR( 20),  ' +
         '@cValue08     NVARCHAR( 20),  ' +
         '@cValue09     NVARCHAR( 20),  ' +
         '@cValue10     NVARCHAR( 20),  ' +
         '@cTemplate    NVARCHAR( MAX), ' +
         '@cPrintData   NVARCHAR( MAX) OUTPUT, ' +
         '@nErrNo       INT            OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10,
         @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

   SELECT TOP 1 @cUDF02 = UDF02
   FROM dbo.CODELKUP WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LISTNAME = 'LVSCARTLBL'
      AND UDF01 = @cReportType
   ORDER BY ISNULL(Short, '99999')

   DELETE FROM dbo.CARTONTRACK WHERE TrackingNo = CONCAT(@cUDF02,@cLabelNo)
                                 AND CarrierName = 'MWMS_Label'
                                 AND Keyname = @cStorerKey
                                 AND LabelNo = @cOrderKey

   INSERT INTO dbo.CARTONTRACK (TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2,UDF01,UDF02,PrintData)
   VALUES (CONCAT(@cUDF02,@cLabelNo),'MWMS_Label',@cStorerKey,@cOrderKey,@cLabelNo,'',@cReportType,@cUDF02,@cPrintData)

Quit:

END


GO