SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_850ExtUpdSP02                                   */
/*                                                                      */
/* Purpose: Print discrepancy report                                    */
/*                                                                      */
/* Called from: rdtfnc_PostPickAudit                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2016-Apr-07 1.0  James      SOS366903 - Created                      */
/* 2017-Jun-02 1.1  James      Add new param (james01)                  */
/* 2018-Nov-19 1.2  Ung        WMS-6932 Add ID param                    */
/* 2019-Mar-29 1.3  James      WMS-8002 Add TaskDetailKey param(james02)*/
/* 2021-Jul-06 1.4  YeeKung     WMS-17278 Add Reasonkey (yeekung01)     */
/************************************************************************/

CREATE PROC [RDT].[rdt_850ExtUpdSP02] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15),
   @cRefNo      NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nQty        INT, 
   @cOption     NVARCHAR( 1), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cID         NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT

)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)


   -- Get MISC info  
   SELECT @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         -- Check label printer blank  
         IF @cPaperPrinter = ''  
         BEGIN  
            SET @nErrNo = 98551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq  
            GOTO Quit  
         END  

         -- Get report info  
         SET @cDataWindow = ''  
         SET @cTargetDB = ''  
         SET @cReportType = 'PPADISCRPT'
         SET @cPrintJobName = 'PRINT PPA DISCREPANCY REPORT'

         SELECT   
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReportType = @cReportType  

         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 98552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Quit
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 98553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Quit
         END

         -- Insert print job 
         SET @nErrNo = 0                    
         EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            @cReportType,                    
            @cPrintJobName,                    
            @cDataWindow,                    
            @cPaperPrinter,                    
            @cTargetDB,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cStorerKey,
            @cDropID

         IF @nErrNo <> 0
            GOTO Quit  
      END
   END
   
QUIT:


GO