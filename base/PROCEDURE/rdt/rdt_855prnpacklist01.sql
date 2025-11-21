SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855PrnPackList01                                */  
/* Copyright: LFLogistics                                               */  
/*                                                                      */  
/* Purpose: Print dispatch label criteria                               */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-02-01 1.0  Ung        SOS331668. Created                        */  
/* 2015-08-10 1.1  Ung        SOS349900 Fix short pick                  */  
/* 2018-11-19 1.2  Ung        WMS-6932 Add ID param                     */  
/* 2019-03-29 1.3  James      WMS-8002 Add TaskDetailKey param (james01)*/  
/* 2021-09-14 1.4  YeeKung    WMS-17967 Add functionid for rdtreport    */
/*                            (yeekung01)                               */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_855PrnPackList01] (  
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
   @cID             NVARCHAR( 18) = '',  
   @cTaskDetailKey  NVARCHAR( 10) = ''  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cPaperPrinter NVARCHAR( 10)  
   DECLARE @cDataWindow   NVARCHAR( 50)   
   DECLARE @cTargetDB     NVARCHAR( 20)   
   DECLARE @cStorerKey    NVARCHAR( 15)   
  
   -- Get PickSlipNo    
   SELECT TOP 1 @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cDropID    
  
   -- Check whether need to print pack list  
   IF @cType = 'CHECK'  
   BEGIN  
      -- Get Order info  
      DECLARE @cSOStatus NVARCHAR(10)  
      SELECT @cSOStatus = O.SOStatus  
      FROM dbo.Orders O WITH (NOLOCK)   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
        
      -- Order cancel not print packing list  
      IF @cSOStatus = 'CANC'  
      BEGIN  
         SET @cPrintPackList = '0' -- No  
         GOTO Quit  
      END  
  
      -- Insert DropID  
      IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)  
      BEGIN  
         -- Insert DropID  
         INSERT INTO dbo.DropID (DropID, Status) VALUES (@cDropID, '9')  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 92804  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail  
            GOTO Fail  
         END  
      END  
     
      /*  
      Last carton logic:  
      1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton  
      2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton  
      */  
      DECLARE @cLastCarton NVARCHAR( 1)  
      -- 1. Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status IN ('0', '4') AND QTY > 0)  
         SET @cLastCarton = 'N'   
      ELSE  
         -- 2. Check manifest printed  
         IF EXISTS( SELECT TOP 1 1   
            FROM dbo.PackDetail PD WITH (NOLOCK)   
               LEFT JOIN dbo.DropID WITH (NOLOCK) ON (PD.DropID = DropID.DropID)  
            WHERE PD.PickSlipNo = @cPickSlipNo   
                  AND DropID.DropID IS NULL)  
            SET @cLastCarton = 'N'   
         ELSE  
            SET @cLastCarton = 'Y'   
     
      -- Last carton then only print pack list   
      IF @cLastCarton = 'Y'  
         SET @cPrintPackList = '1' -- Yes  
      ELSE  
      SET @cPrintPackList = '0' -- No  
   END  
  
   -- Print pack list  
   IF @cType = 'PRINT'  
   BEGIN  
      IF @cOption = '9' -- No  
      BEGIN  
         SET @nErrNo = 92806  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pack List  
         GOTO Fail  
      END  
        
      IF @cOption = '1' -- Yes  
      BEGIN  
         -- Get printer  
         SELECT   
            @cPaperPrinter = Printer_Paper,   
            @cStorerKey = StorerKey  
         FROM rdt.rdtMobRec WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
           
         -- Check paper printer blank  
         IF @cPaperPrinter = ''  
         BEGIN  
            SET @nErrNo = 92801  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq  
            EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label  
            GOTO Quit  
         END  
     
         -- Get packing list report info  
         SET @cDataWindow = ''  
         SET @cTargetDB = ''  
         SELECT   
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReportType = 'PACKLIST'  
            AND (Function_ID = @nFunc OR Function_ID = 0)  --(yeekung01)
              
         -- Check data window  
         IF ISNULL( @cDataWindow, '') = ''  
         BEGIN  
            SET @nErrNo = 92802  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
            GOTO Quit  
         END  
     
         -- Check database  
         IF ISNULL( @cTargetDB, '') = ''  
         BEGIN  
            SET @nErrNo = 92803  
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
            @cPaperPrinter,  
            @cTargetDB,  
            @cLangCode,  
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,   
            @cPickSlipNo  
     
         -- Update DropID  
         UPDATE dbo.DropID SET  
            ManifestPrinted = '1'  
         WHERE DropID = @cDropID  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 92805  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail  
            GOTO Fail  
         END  
      END  
   END  
     
Fail:    
   RETURN    
Quit:    
   SET @nErrNo = 0 -- Not stopping error 


GO