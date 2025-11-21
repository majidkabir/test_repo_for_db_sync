SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_593Print12                                         */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-08-11 1.0  ChewKP   WMS-2601 Created                               */  
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_593Print12] (    
   @nMobile    INT,    
   @nFunc      INT,    
   @nStep      INT,    
   @cLangCode  NVARCHAR( 3),    
   @cStorerKey NVARCHAR( 15),    
   @cOption    NVARCHAR( 1),    
   @cParam1    NVARCHAR(20),  -- OrderKey 
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),     
   @cParam4    NVARCHAR(20),    
   @cParam5    NVARCHAR(20),    
   @nErrNo     INT OUTPUT,    
   @cErrMsg    NVARCHAR( 20) OUTPUT    
)    
AS    
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @b_Success     INT    
       
   DECLARE @cDataWindow   NVARCHAR( 50)  
         , @cManifestDataWindow NVARCHAR( 50)  
         , @nTranCount    INT

   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @cPaperPrinter NVARCHAR( 10)    
   DECLARE @cUserName     NVARCHAR( 18)     
   DECLARE @cLabelType    NVARCHAR( 20)    
   
   DECLARE @cPalletKey    NVARCHAR( 20)
          ,@cShipmentNo   NVARCHAR( 60)
          ,@cTruckID      NVARCHAR( 20)
          ,@cFacility     NVARCHAR( 5)
          ,@nFocusParam   INT

   SET @nFocusParam = 1 
   
   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank    
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''    
   BEGIN    
      SET @nErrNo = 95251    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq    
      GOTO Quit    
   END    

   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_593Print12      
   
  
   IF @cOption ='2'
   BEGIN
      SET @cPalletKey   = @cParam1
      
      IF ISNULL(@cPalletKey,'')  = '' 
      BEGIN
         SET @nErrNo = 113701    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PalletIDReq  
         GOTO RollBackTran    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
                      WHERE PalletKey = @cPalletKey  ) 
      BEGIN
         SET @nErrNo = 113702  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvPalletID
         GOTO RollBackTran  
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      
      IF EXISTS ( SELECT 1
                  FROM rdt.rdtReport WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = 'OTMPLTLBL1'    ) 
      BEGIN 
         

         SELECT @cDataWindow = DataWindow,     
                @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'OTMPLTLBL1'   
             
         EXEC RDT.rdt_BuiltPrintJob      
             @nMobile,      
             @cStorerKey,      
             'OTMPLTLBL1',    -- ReportType      
             'OTMPLTLBL1',    -- PrintJobName      
             @cDataWindow,      
             @cLabelPrinter,      
             @cTargetDB,      
             @cLangCode,      
             @nErrNo  OUTPUT,      
             @cErrMsg OUTPUT,    
             @cPalletKey--,   
             --@cPickSlipNo, 
             --@nFromCartonNo,
             --@nToCartonNo 
                
      END
                
      
   END
   
   IF @cOption ='3'
   BEGIN
      SET @cTruckID   = @cParam1
      
      IF ISNULL(@cTruckID,'')  = '' 
      BEGIN
         SET @nErrNo = 113703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TruckIDReq  
         GOTO RollBackTran    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
                      WHERE TruckID = @cTruckID
                      AND ShipmentID <> '' ) 
      BEGIN
         SET @nErrNo = 113704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvTruckID  
         GOTO RollBackTran    
      END
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      
      IF EXISTS ( SELECT 1
                  FROM rdt.rdtReport WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = 'TMSLIST'    ) 
      BEGIN 
         
         SELECT @cDataWindow = DataWindow,     
	          					@cTargetDB = TargetDB     
			FROM rdt.rdtReport WITH (NOLOCK)     
			WHERE StorerKey = @cStorerKey    
			AND   ReportType = 'TMSLIST'   
			
			SELECT @cFacility = Facility 
			FROM rdt.rdtMobrec WITH (NOLOCK) 
			WHERE Mobile = @nMobile
			
			SELECT TOP 1 @cShipmentNo = ShipmentID
			FROM dbo.OTMIDTrack WITH (NOLOCK) 
			WHERE TruckID = @cTruckID
			ORDER BY EditDate desc
			
             
         EXEC RDT.rdt_BuiltPrintJob      
   			  @nMobile,      
   			  @cStorerKey,      
   			  'TMSLIST',    -- ReportType      
   			  'TMSLIST',    -- PrintJobName      
   			  @cDataWindow,      
   			  @cPaperPrinter,      
   			  @cTargetDB,      
   			  @cLangCode,      
   			  @nErrNo  OUTPUT,      
   			  @cErrMsg OUTPUT, 
   			  @cShipmentNo,   
   			  @cTruckID,
   			  @cFacility
                
      END
                
      
   END
   
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_593Print12 -- Only rollback change made here      
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

 
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_593Print12    
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 
        

GO