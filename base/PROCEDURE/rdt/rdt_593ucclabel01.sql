SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_593UCCLabel01                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-01-27 1.0  Ung      SOS361978 Created base on rdtVFRTSKULabel      */
/* 2016-09-22 1.1  ChewKP   WMS-420 (ChewKP01)                             */
/* 2018-05-07 1.2  James    WMS-3966 Change printing to Qcommander         */
/*                          compatible printing (James01)                  */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593UCCLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN
   @cParam2    NVARCHAR(20),  -- ID
   @cParam3    NVARCHAR(20),  -- SKU/UPC
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cUCCNo        NVARCHAR( 20)
          ,@cLabelNo      NVARCHAR( 20)
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@nCartonNo     INT
          ,@cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)   
          ,@cCartonID     NVARCHAR( 20)
          ,@cOrderKey     NVARCHAR( 10)
          ,@cUpdateSource NVARCHAR( 10) 
          ,@nBilledContainerQty INT
          ,@nContainerQty       INT
          ,@cContainerType NVARCHAR(20)
          ,@cReportType    NVARCHAR(10)
          ,@cFacility      NVARCHAR(5)

   DECLARE @tShipLabel AS VariableTable
   DECLARE @tUPSLabel AS VariableTable
                      
   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @cOption = '1' 
   BEGIN 
      -- Parameter mapping
      SET @cUCCNo = @cParam1
   
      -- Check blank
      IF @cUCCNo = ''
      BEGIN
         SET @nErrNo = 52201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need UCC No
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END
   
      -- Get Receipt info
      DECLARE @cChkStatus NVARCHAR(1)
      SELECT
         @cChkStatus = Status
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
   
      -- Check UCC valid
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 52202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCC not found
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
         GOTO Quit
      END
   
      -- Check UCC picked/replenish
      IF @cChkStatus = '5' OR @cChkStatus = '6'
      BEGIN
         SET @nErrNo = 52203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCCPick/replen
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
         GOTO Quit
      END
   
      -- Get login info
      SELECT 
         @cLabelPrinter = Printer, 
         @cUserName = UserName
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
   
      -- Check label printer blank
      IF @cLabelPrinter = ''
      BEGIN
         SET @nErrNo = 52204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
         GOTO Quit
      END
   
      -- Print label
      EXEC dbo.isp_BT_GenBartenderCommand
          @cLabelPrinter
         ,'UCCLABEL'       -- @cLabelType
         ,@cUserName
         ,@cUCCNo          --Param01
         ,@cStorerKey      --Param02
         ,''               --Param03
         ,''               --Param04
         ,''               --Param05
         ,''               --Param06
         ,''               --Param07
         ,''               --Param08
         ,''               --Param09
         ,''               --Param10
         ,@cStorerKey      
         ,'1'              -- No of copy
         ,'0'              -- Debug
         ,'N'              -- Return result
         ,@nErrNo  OUTPUT
         ,@cERRMSG OUTPUT
         
   END
   
   IF @cOption = '2'
   BEGIN 
      -- Parameter mapping
      SET @cCartonID = @cParam1
      
       -- Check blank
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 52205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CartonIDReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO Quit
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey 
                     AND RefNo = @cCartonID ) 
      BEGIN
         SET @nErrNo = 52206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidCtnID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO Quit
      END

      SELECT 
         @cLabelPrinter = Printer, 
         @cUserName = UserName
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
      
      SELECT @cPickSlipNo = PickSlipNo 
            ,@nCartonNo   = CartonNo
            ,@cLabelNo    = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND RefNo = @cCartonID
      
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND CaseID = @cLabelNo 
      
      
      SELECT @cUpdateSource = UpdateSource
            ,@nBilledContainerQty = BilledContainerQty
            ,@nContainerQty       = ContainerQty
            ,@cContainerType      = ContainerType
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
      
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'UCClbconso'   
      
      IF ISNULL(@nBilledContainerQty, 0 ) <> 0 
      BEGIN
         -- Common params
         DECLARE @tUCClbconso AS VariableTable
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@nCartonNoFrom', @nCartonNo)
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@nCartonNoTo', @nCartonNo)
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@cUpdateSource', @cUpdateSource)
         -- For special handling of calling dw but use btw printing. inside btw sp will use
         -- suser_sname() to get printer but qcommander user do not carry username not printer id
         -- so pass in here
         INSERT INTO @tUCClbconso (Variable, Value) VALUES ( '@cPrinter', @cLabelPrinter)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
            'UCClbconso', -- Report type
            @tUCClbconso, -- Report params
            'rdtfnc_PrintLabelReport', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
      END

      
      IF ISNULL(@cContainerType,'' )  <> '' 
      BEGIN
         SELECT @cReportType = UDF01 
         FROM dbo.CodeLKup WITH (NOLOCK) 
         WHERE ListName IN (  'CZLABEL', 'CAWMINTLBL' ) 
         AND Short = @cContainerType
         
         IF ISNULL(@cReportType,'' )  = '' 
         BEGIN
            SET @nErrNo = 52209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --RptNotSetup
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
            GOTO Quit
         END
               
         SELECT @cDataWindow = DataWindow,     
               @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = @cReportType  
         
   
         
         IF ISNULL(@nContainerQty, 0 ) <> 0 
         BEGIN
            -- Common params
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
               @cReportType, -- Report type
               @tShipLabel, -- Report params
               'rdtfnc_PrintLabelReport', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
        END
     END
     
     IF EXISTS ( SELECT 1
                 FROM dbo.CartonTrack WITH (NOLOCK)
                 WHERE LabelNo = @cLabelNo )
     BEGIN
         SELECT @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'UPSLABEL'  
   
         -- Common params
         INSERT INTO @tUPSLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, '', 
            'UPSLABEL', -- Report type
            @tUPSLabel, -- Report params
            'rdtfnc_PrintLabelReport', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
     END
      
   END
   
   IF @cOption = '3'
   BEGIN 
      
      SET @cLabelNo = @cParam1
      
       -- Check blank
      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 52207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO Quit
      END

  
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey 
                     AND LabelNo = @cLabelNo ) 
      BEGIN
         SET @nErrNo = 52208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO Quit
      END

      SELECT 
         @cLabelPrinter = Printer, 
         @cUserName = UserName
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
      
      SELECT @cPickSlipNo = PickSlipNo 
            ,@nCartonNo   = CartonNo
            ,@cLabelNo    = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo
      
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND CaseID = @cLabelNo 
      
      SELECT @cUpdateSource       = UpdateSource
            ,@nBilledContainerQty = BilledContainerQty
            ,@nContainerQty       = ContainerQty
            ,@cContainerType      = ContainerType
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

      IF ISNULL(@cContainerType,'' )  <> '' 
      BEGIN
         SELECT @cReportType = UDF01 
         FROM dbo.CodeLKup WITH (NOLOCK) 
         WHERE ListName IN (  'CZLABEL', 'CAWMINTLBL' ) 
         AND Short = @cContainerType
         
         IF ISNULL(@cReportType,'' )  = '' 
         BEGIN
            SET @nErrNo = 52210
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --RptNotSetup
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
            GOTO Quit
         END
         
         SELECT @cDataWindow = DataWindow,     
               @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = @cReportType
         
         IF ISNULL(@nContainerQty, 0 ) <> 0 
         BEGIN
            -- Common params
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
               @cReportType, -- Report type
               @tShipLabel, -- Report params
               'rdtfnc_PrintLabelReport', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
        END             
     END
     
     
     IF EXISTS ( SELECT 1
                 FROM dbo.CartonTrack WITH (NOLOCK)
                 WHERE LabelNo = @cLabelNo )
     BEGIN
         SELECT @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'UPSLABEL'  
   
         -- Common params
         INSERT INTO @tUPSLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, '', 
            'UPSLABEL', -- Report type
            @tUPSLabel, -- Report params
            'rdtfnc_PrintLabelReport', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
     END             
      
      
   END

   
Quit:


GO