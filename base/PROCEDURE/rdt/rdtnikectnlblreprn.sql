SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtNIKECTNLBLReprn                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2015-11-18 1.0  James    SOS356971 Created                              */  
/* 2016-05-09 1.1  James    SOS364904 - Bug fix (james01)                  */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtNIKECTNLBLReprn] (  
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
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cOrderKey     NVARCHAR( 10)  
          ,@cLabelNo      NVARCHAR( 20)     
          ,@cUserName     NVARCHAR( 18) 
          ,@cLoc          NVARCHAR( 10) 
          ,@cPutawayZone  NVARCHAR( 10) 
          ,@cFacility     NVARCHAR( 5)  
   

   SET @cOrderKey = @cParam1

   SELECT @cUserName = UserName, @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nFunc <> 593
   BEGIN
      SELECT TOP 1 @cLoc = Loc
      FROM RDT.RDTPICKLOCK WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey
      AND   AddWho = @cUserName
      ORDER BY EditDate DESC

      SELECT @cPutawayZone = PutAwayZone
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Facility = @cFacility
      AND   LOC = @cLoc
   
      SELECT TOP 1 @cLabelNo = D.DropID 
      FROM dbo.DropIDDetail DD WITH (NOLOCK) 
      JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
      WHERE DD.ChildID = @cOrderKey
      AND   UDF05 = @cPutawayZone
      ORDER BY D.EditDate DESC   -- the latest set of dropid

      IF ISNULL(@cLabelNo, '') = '' 
         SELECT TOP 1 @cLabelNo = D.DropID 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
         WHERE DD.ChildID = @cOrderKey
         ORDER BY D.EditDate DESC   
            
      IF ISNULL(@cLabelNo, '') = '' 
      BEGIN
         SET @nErrNo = 95101  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LABELNO REQ
         GOTO Quit  
      END
   END
   ELSE
   BEGIN
      SET @cLabelNo = @cParam2

      -- Both value must not blank
      IF ISNULL(@cOrderKey, '') = '' 
      BEGIN
         SET @nErrNo = 95102  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORDERKEY REQ
         GOTO Quit  
      END

      IF ISNULL(@cLabelNo, '') = '' 
      BEGIN
         SET @nErrNo = 95103  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LABELNO REQ
         GOTO Quit  
      END

      -- Check if it is valid OrderKey
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                      WHERE OrderKey = @cOrderKey 
                      AND   StorerKey = @cStorerKey)
       BEGIN  
         SET @nErrNo = 95104  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
         GOTO Quit  
      END  

      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.PackDetail PD WITH (NOLOCK)
                      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
                      WHERE PH.OrderKey = @cOrderKey
                      AND   PD.LabelNo = @cLabelNo)
       BEGIN  
         SET @nErrNo = 95105  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV LABELNO
         GOTO Quit  
      END  
   END
   
   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Carton Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 95106  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

   -- Get report info  
   SET @cDataWindow = ''  
   SET @cTargetDB = ''  
   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = 'CARTONLBL'  
        
   -- Insert print job  
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'CARTONLBL',                    
      'PRINT_CARTONLABEL',                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cStorerKey,                    
      @cOrderKey, 
      @cLabelNo

   IF @nErrNo <> 0
      GOTO Quit  

   UPDATE dbo.DropID WITH (ROWLOCK) SET 
      LabelPrinted = 'Y'
   WHERE DropID = @cLabelNo
   AND   [Status] = '9'
   AND   LabelPrinted <> 'Y'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 95107
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CLOSE FAIL'
   END
Quit:  

GO