SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtUpd10                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2023-07-26 1.0  yeekung  WMS-23057. Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtUpd10] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),    
   @nQty         INT,    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT           OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT,   
   @cID          NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',        
   @cReasonCode  NVARCHAR(20) OUTPUT         
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  

   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
   DECLARE @cFacility      NVARCHAR( 5)  
   DECLARE @cLabelPrinter  NVARCHAR( 10)  
   DECLARE @cPaperPrinter  NVARCHAR( 10)  
   DECLARE @cLblPrinterLK  NVARCHAR( 10)  
   DECLARE @cPprPrinterLK  NVARCHAR( 10)  
   DECLARE @cDiscrepancyLabel        NVARCHAR( 20)  
   DECLARE @cShipLabel               NVARCHAR( 10)  
   DECLARE @cUserName                NVARCHAR( 128)  
   DECLARE @nPDQTY         INT
   DECLARE @nPPAQTY         INT
     
   SELECT   
      @cFacility = Facility,   
      @cLabelPrinter = Printer,  
      @cPaperPrinter = Printer_Paper,  
      @cUserName = UserName  
   FROM RDT.RDTMobRec WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
    
   IF @nFunc = 855 -- PPA (carton ID)  
   BEGIN  

      IF @nStep = 3 -- SKU
      BEGIN  
         IF @nInputKey ='1'
         BEGIN
         
            SELECT @nPDQTY = SUM(PD.QTY)
            FROM pickdetail PD (nolock)
            where PD.dropid= @cDropID
               and PD.Storerkey = @cStorerKey
               AND PD.Status <=9

            SELECT @nPPAQTY = SUM(ISNULL(PPA.CQty,0))
            FROM  rdt.rdtppa PPA (NOLOCK)
            WHERE PPA.dropid= @cDropID
               AND PPA.Storerkey = @cStorerKey

            IF ISNULL(@nPPAQTY,'')  IN ('',0)
               SET @nPPAQTY = 0

            IF @nPPAQTY = @nPDQTY
            BEGIN

               DECLARE @cCartonManifest NVARCHAR(20)
               SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
               IF @cCartonManifest = '0'
                  SET @cCartonManifest = ''

               -- Carton manifest
               IF @cCartonManifest <> ''
               BEGIN

                  -- Get session info
                  SELECT
                     @cPaperPrinter = Printer_Paper,
                     @cLabelPrinter = Printer
                  FROM rdt.rdtMobRec WITH (NOLOCK)
                  WHERE Mobile = @nMobile

                  DECLARE @tCartonManifest AS VariableTable
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES
                     ( '@cStorerKey',    @cStorerKey),
                     ( '@cDropID',      @cDropID)

                  -- Print Carton manifest
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cCartonManifest, -- Report type
                     @tCartonManifest, -- Report params
                     'rdt_855ExtUpd10',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO QUIT
               END
            END
         END
      END  

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
  
Quit:  
  
END  

GO