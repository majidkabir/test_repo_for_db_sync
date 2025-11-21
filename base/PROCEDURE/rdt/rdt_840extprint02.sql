SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint02                                   */
/* Purpose: Print BAGMANFEST label upon confirm pack                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-06-27 1.0  James      WMS455. Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint02] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cReportType    NVARCHAR( 10),
           @cPrintJobName  NVARCHAR( 50),
           @cDataWindow    NVARCHAR( 50),
           @cTargetDB      NVARCHAR( 20),
           @cLabelNo       NVARCHAR( 20),
           @cPaperPrinter  NVARCHAR( 10)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   OrderKey = @cOrderKey
         AND   [Status] = '9'

         -- Print only if pack confirm
         IF ISNULL( @cPickSlipNo, '') = ''
            GOTO Quit

         SET @cReportType = 'BAGMANFEST'

         -- Report type not setup then no need print
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   ReportType = @cReportType
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
                                 ELSE 0 END)
            GOTO Quit

         SELECT @cDataWindow = DataWindow,  
                @cTargetDB = TargetDB  
         FROM rdt.rdtReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = @cReportType

         SELECT @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF ISNULL( @cPaperPrinter, '') = ''
         BEGIN
            SET @nErrNo = 104501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
            GOTO Quit
         END

         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 104502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP
            GOTO Quit
         END

         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 104503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET
            GOTO Quit
         END

         EXEC RDT.rdt_BuiltPrintJob  
            @nMobile,  
            @cStorerKey,  
            @cReportType,              -- ReportType  
            'ANF_CUSTOMERMANIFEST',    -- PrintJobName  
            @cDataWindow,  
            @cPaperPrinter,  
            @cTargetDB,  
            @cLangCode,  
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,  
            @cOrderkey,  
            ''  

         IF @nErrNo <> 0
            GOTO Quit

      END   --  @nStep = 4
   END   -- @nInputKey = 1

QUIT:

SET QUOTED_IDENTIFIER OFF

GO