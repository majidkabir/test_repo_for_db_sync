SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593UCCLabel03                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-05-25 1.0  James    WMS1962. Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593UCCLabel03] (
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

   DECLARE @cLabelPrinter  NVARCHAR( 10)
          ,@cPH_StorerKey  NVARCHAR( 15)
          ,@cLabelNo       NVARCHAR( 20)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cDataWindow    NVARCHAR( 50)  
          ,@cTargetDB      NVARCHAR( 20)   
          ,@cReportType    NVARCHAR(10) 
          ,@nCartonNo      INT
          ,@nTTLCnts       INT

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20),
           @cErrMsg03        NVARCHAR( 20),
           @cErrMsg04        NVARCHAR( 20),
           @cErrMsg05        NVARCHAR( 20),
           @cErrMsg06        NVARCHAR( 20),
           @cErrMsg07        NVARCHAR( 20),
           @cErrMsg08        NVARCHAR( 20),
           @cErrMsg09        NVARCHAR( 20),
           @cErrMsg10        NVARCHAR( 20),
           @cErrMsg11        NVARCHAR( 20),
           @cErrMsg12        NVARCHAR( 20),
           @cErrMsg13        NVARCHAR( 20),
           @cErrMsg14        NVARCHAR( 20),
           @cErrMsg15        NVARCHAR( 20)

   -- Parameter mapping
   SET @cLabelNo = @cParam1
   
   -- Check blank
   IF @cLabelNo = ''
   BEGIN
      SET @nErrNo = 110051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Label required
      GOTO Quit
   END

   SELECT @cPH_StorerKey = PH.StorerKey
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE LabelNo = @cLabelNo

   -- Check if label exists
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 110052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No record
      GOTO Quit
   END
   
   -- Check if storerkey same as user login storerkey
   IF ISNULL( @cPH_StorerKey, '') <> @cStorerKey
   BEGIN
      SET @nErrNo = 110053
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer
      GOTO Quit
   END

   SELECT TOP 1 @cPickSlipNo = PH.PickSlipNo,
                @nTTLCnts = PH.TtlCnts,
                @nCartonNo = PD.CartonNo
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
   AND   PD.LabelNo = @cLabelNo

   -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 110054
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Get packing list report info
   SET @cReportType = 'UCCLABEL02'
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReportType = @cReportType
   AND   ( Function_ID = @nFunc OR Function_ID = 0)

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 110055
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END
   
   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 110056
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   -- Insert print job
   SET @nErrNo = 0                    

   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      @cReportType,                    
      'PRINT_UCCLABEL02',                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cPickSlipNo,
      @nCartonNo,
      @nCartonNo

   IF @nErrNo <> 0
      GOTO Quit
   ELSE
   BEGIN
      SET @cErrMsg01 = ''
      SET @cErrMsg02 = ''
      SET @cErrMsg03 = ''
      SET @cErrMsg04 = ''
      SET @cErrMsg05 = '' 
      SET @cErrMsg06 = ''
      SET @cErrMsg07 = ''
      SET @cErrMsg08 = ''
      SET @cErrMsg09 = ''
      SET @cErrMsg10 = ''
      SET @cErrMsg11 = ''
      SET @cErrMsg12 = ''
      SET @cErrMsg13 = ''
      SET @cErrMsg14 = ''
      SET @cErrMsg15 = ''

      SET @nErrNo = 0
      SET @cErrMsg01 = SUBSTRING( rdt.rdtgetmessage( 110057, @cLangCode, 'DSP'), 7, 14)
      SET @cErrMsg02 = @cLabelNo
      SET @cErrMsg04 = SUBSTRING( rdt.rdtgetmessage( 110058, @cLangCode, 'DSP'), 7, 14)
      SET @cErrMsg05 = @cPickSlipNo
      SET @cErrMsg07 = SUBSTRING( rdt.rdtgetmessage( 110059, @cLangCode, 'DSP'), 7, 14)
      SET @cErrMsg08 = RTRIM( CAST( @nCartonNo AS NVARCHAR( 5))) + '/' + CAST( @nTTLCnts AS NVARCHAR( 5))

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05, 
      @cErrMsg06, @cErrMsg07, @cErrMsg08, @cErrMsg09, @cErrMsg10, 
      @cErrMsg11, @cErrMsg12, @cErrMsg13, @cErrMsg14, @cErrMsg15

      -- Reset to 0 because rdtInsertMsgQueue return @nErrNo = 1
      SET @nErrNo = 0
   END

Quit:


GO