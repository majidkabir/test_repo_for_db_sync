SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtANFDTCLBLReprn                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-07-17 1.0  ChewKP   SOS#315552 Created                             */
/* 2015-06-11 1.1  ChewKP   Remove Traceinfo  (ChewKP01)                   */
/* 2020-02-24 1.2  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdtANFDTCLBLReprn] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LoadKey
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),  -- LabelNo
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
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cLoadKey      NVARCHAR( 10)
   DECLARE @cTrackNo      NVARCHAR( 20)
   DECLARE @cLabelType    NVARCHAR( 20)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cPrintTemplateSP  NVARCHAR( 40)
   DECLARE @cLabelNo      NVARCHAR(20)
         , @cExternOrderKey NVARCHAR(30)
         , @cPickSlipNo     NVARCHAR(10)
         , @cOrderKey       NVARCHAR(10)
         , @cShipperKey     NVARCHAR(10)

   -- cTrackNo mapping
   SET @cTrackNo = @cParam1
   SET @cLoadKey = ''

   --(ChewKP01)
   --INSERT INTO TraceInfo ( TraceName , TimEIN , col1 , Col2 ,Col3 , col4 , col5  )
   --VALUES ( 'PRINT' , Getdate() , @cParam1 ,@cParam2, @cParam3, @cParam4 , @cParam5 )

   -- Check blank
   IF ISNULL( @cTrackNo, '') = ''
   BEGIN
      SET @nErrNo = 91051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TrackNo Req
      --EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param1
      GOTO Quit
   END

--   -- If user did not provide loadkey, get from system base on labelno (Chee01)
--   IF ISNULL(@cLoadKey, '') = ''
--   BEGIN
--      SELECT DISTINCT @cLoadKey = PH.LoadKey
--      FROM dbo.PackDetail PD WITH (NOLOCK)
--      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickslipNo = PH.PickSlipNo)
--      WHERE PH.StorerKey = @cStorerKey
--      AND   PD.LabelNo = @cLabelNo
--
--      IF @@ROWCOUNT <> 1
--      BEGIN
--         SET @nErrNo = 85101
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOADKEY REQ
--         EXEC rdt.rdtSetFocusField @nMobile, 2
--         GOTO Quit
--      END
--   END


   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                   WHERE UserDefine04 = @cTrackNo
                   AND   StorerKey = @cStorerKey)
    BEGIN
      SET @nErrNo = 91052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTrackNo
      --EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE UPC = @cTrackNo
                   AND   StorerKey = @cStorerKey)
    BEGIN
      SET @nErrNo = 91053
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTrackNo
      --EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK)
                   WHERE TrackingNumber = @cTrackNo
                   AND   StorerKey = @cStorerKey)
   BEGIN
      SET @nErrNo = 91054
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidTrackNo
      --EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END

   -- Get printer info
   SELECT
      @cUserName = UserName,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

--   SELECT @cLoadKey        = O.LoadKey
--         ,@cExternOrderKey = O.ExternOrderKey
--         ,@cOrderKey       = O.OrderKey
--         ,@cShipperKey     = O.ShipperKey
--   FROM dbo.PackHeader PH WITH (NOLOCK)
--   INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
--   INNER JOIN dbo.PickDetail PICKDET WITH (NOLOCK) ON PICKDET.PickSlipNo = PH.PickSlipNo AND PD.LabeLNo = PICKDET.CaseID
--   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PICKDET.OrderKey
--   AND PD.UPC = @cTrackNo
--   AND PICKDET.StorerKey = @cStorerKey

   /*-------------------------------------------------------------------------------

                                    Print Label

   -------------------------------------------------------------------------------*/
   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 91055
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   --SET @cLabelType = 'SHIPPLABELDTC'
   SELECT @cOrderKey = OrderKey
   FROM dbo.CartonShipmentDetail WITH (NOLOCK)
   WHERE TrackingNumber = @cTrackNo

   SELECT @cPickSlipNo = PickHeaderKey
   FROM dbo.Pickheader WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT Top 1 @cExternOrderKey = O.ExternOrderKey
               ,@cLabelNo       = PD.CaseID
               ,@cShipperKey     = O.ShipperKey
               ,@cLoadKey        = O.LoadKey
   FROM dbo.Orders O WITH (NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
   INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
   WHERE PH.PickHeaderKey = @cPickSlipNo
   AND PD.OrderKey = @cOrderKey

   IF @cShipperKey IN ( 'LFL', 'DHL' )
   BEGIN
      SET @cLabelType = 'SHIPPLABELDTC'
      EXEC dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cLabelPrinter
       , @c_LabelType    = @cLabelType
       , @c_userid       = @cUserName
       , @c_Parm01       = @cLoadKey
       , @c_Parm02       = @cOrderKey -- OrderKey
       , @c_Parm03       = @cExternOrderKey
       , @c_Parm04       = @cLabelNo
       , @c_Parm05       = @cShipperKey
       , @c_Parm06       = ''
       , @c_Parm07       = ''
       , @c_Parm08       = ''
       , @c_Parm09       = ''
       , @c_Parm10       = ''
       , @c_StorerKey    = @cStorerKey
       , @c_NoCopy       = '1'
       , @b_Debug        = '0'
       , @c_Returnresult = 'N'
       , @n_err          = @nErrNo  OUTPUT
--     , @c_errmsg       = @cERRMSG OUTPUT
--
--   -- Call Bartender standard SP
--   EXECUTE dbo.isp_BT_GenBartenderCommand
--      @cLabelPrinter,     -- printer id
--      'SHIPPLABELANF',    -- label type
--      @cUserName,    -- user id
--      @cLoadKey,     -- parm01
--      '',            -- parm02
--      @cLabelNo,     -- parm03
--      '',            -- parm04
--      '',            -- parm05
--      '',            -- parm06
--      @cLabelType,   -- parm07
--      '',            -- parm08
--      '',            -- parm09
--      '',            -- parm10
--      @cStorerKey,   -- StorerKey
--      '1',           -- no of copy
--      0,             -- debug
--      'N',            -- return result
--      @nErrNo        OUTPUT,
--      @cErrMsg       OUTPUT
   END
   ELSE
   BEGIN
      SET @cLabelType = 'SHIPPLABEL'
      EXEC dbo.isp_BT_GenBartenderCommand
            @cPrinterID     = @cLabelPrinter
          , @c_LabelType    = @cLabelType
          , @c_userid       = @cUserName
          , @c_Parm01       = @cLoadKey
          , @c_Parm02       = @cOrderKey -- OrderKey
          , @c_Parm03       = @cShipperKey
          , @c_Parm04       = 0
          , @c_Parm05       = ''
          , @c_Parm06       = ''
          , @c_Parm07       = ''
          , @c_Parm08       = ''
          , @c_Parm09       = ''
          , @c_Parm10       = ''
          , @c_StorerKey    = @cStorerKey
          , @c_NoCopy       = '1'
          , @b_Debug        = '0'
          , @c_Returnresult = 'N'
          , @n_err          = @nErrNo  OUTPUT
          , @c_errmsg       = @cERRMSG OUTPUT
   END

   IF @nErrNo <> 0
      GOTO Quit

Quit:

GO