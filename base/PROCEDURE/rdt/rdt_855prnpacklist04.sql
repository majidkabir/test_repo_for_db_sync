SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_855PrnPackList04                                */  
/* Copyright: LFLogistics                                               */  
/*                                                                      */  
/* Purpose: Print dispatch label criteria                               */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-06-12 1.0  YeeKung    WMS-10273. Created                        */    
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_855PrnPackList04] (  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cRefNo          NVARCHAR( 10),  
   @cPickSlipNo     NVARCHAR( 10),  
   @cLoadKey        NVARCHAR( 10),  
   @cOrderKey       NVARCHAR( 10),  
   @cDropID         NVARCHAR( 20),  
   @cSKU            NVARCHAR( 20),  
   @nQTY            INT,  
   @cOption         NVARCHAR( 1),  
   @cType           NVARCHAR( 10),  
   @nErrNo          INT                OUTPUT,   
   @cErrMsg         NVARCHAR( 20)      OUTPUT,   
   @cPrintPackList  NVARCHAR( 1)  = '' OUTPUT,   
   @cID             NVARCHAR( 18) = '' ,
   @cTaskDetailKey  NVARCHAR( 10) = ''
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cLabelPrinter NVARCHAR( 10)   
   DECLARE @cDataWindow   NVARCHAR( 50)   
   DECLARE @cTargetDB     NVARCHAR( 20)   
   DECLARE @cStorerKey    NVARCHAR( 15)
   DECLARE @cPPAPromptDiscrepancy NVARCHAR( 1)
   DECLARE @cFacility NVARCHAR(20)
   
   -- Print pack list  
   IF @cType = 'PRINT'  
   BEGIN  
      
      IF @cOption = '1' -- Yes  
      BEGIN 
         -- Get printer  
         SELECT   
            @cLabelPrinter = Printer,   
            @cStorerKey = StorerKey, 
            @cPPAPromptDiscrepancy =  V_String21,
            @cFacility    = facility
         FROM rdt.rdtMobRec WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
           
         -- Check paper printer blank  
         IF @cLabelPrinter = ''  
         BEGIN  
            SET @nErrNo = 143651   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
            EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label  
            GOTO Quit  
         END  
     
         IF @cPPAPromptDiscrepancy <> ''
         BEGIN

            DECLARE @tPacklist AS VariableTable  
            DECLARE @cStartCartonNo INT
            DECLARE @cEndCartonNo INT

            DECLARE @cCartonManifest NVARCHAR(20)
            SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
            IF @cCartonManifest = '0'
               SET @cCartonManifest = ''

            -- Carton manifest
            IF @cCartonManifest <> ''
            BEGIN
               -- Get carton info
               DECLARE @cLabelNo NVARCHAR(20)
               DECLARE @cSite    NVARCHAR( 20)
               SELECT TOP 1
                  @cOrderKey = PH.Orderkey
               FROM dbo.Packheader PH (NOLOCK) JOIN
                  dbo.PackDetail PD WITH (NOLOCK) ON PH.pickslipno=PD.pickslipno
               WHERE PH.StorerKey = @cStorerKey
                  AND PD.Dropid = @cDropID

               -- Get session info
               SELECT
                  @cPaperPrinter = Printer_Paper,
                  @cLabelPrinter = Printer,
                  @cStorerKey = StorerKey
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               DECLARE @tCartonManifest AS VariableTable
               INSERT INTO @tCartonManifest (Variable, Value) VALUES
                  ( '@cOrderkey',    @cOrderKey),
                  ( '@cDropID',      @cDropID)

               -- Print Carton manifest
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cCartonManifest, -- Report type
                  @tCartonManifest, -- Report params
                  'rdt_855PrnPackList04',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  SET @nErrNo = 0 -- Bypass error to prevent stuck in screen cannot ESC
            END

            -- Update DropID  
            UPDATE dbo.DropID SET  
               ManifestPrinted = '1'  
            WHERE DropID = @cDropID  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 143654  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail  
               GOTO Fail  
            END 
         END 
      END  
   END  
   ELSE IF @cType ='CHECK'
   BEGIN
      SET @cPrintPackList = '1'
   END 

Fail:    
   RETURN    
Quit:    
   SET @nErrNo = 0 -- Not stopping error 


GO