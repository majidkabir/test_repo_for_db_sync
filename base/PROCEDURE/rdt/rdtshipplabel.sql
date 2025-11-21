SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtShipPLabel                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2014-02-14 1.0  Ung        SOS303065 Created                            */
/* 2016-04-15 1.1  ChewKP     SOS#367342 - Add Option 2 (ChewKP01)         */
/* 2016-09-14 1.2  ChewKP     SOS#295 - Add Option 3 (ChewKP02)            */
/* 2017-11-12 1.3  James      Add additional param value (james01)         */
/* 2020-02-24 1.4  Leong      INC1049672 - Revise BT Cmd parameters.       */
/***************************************************************************/

CREATE PROC [RDT].[rdtShipPLabel] (
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

   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cOrderKey    NVARCHAR(10)
   DECLARE @cChkOrderKey NVARCHAR(10)
   DECLARE @cChkStatus   NVARCHAR(10)
   DECLARE @cChkSOStatus NVARCHAR(10)
   DECLARE @cLoadKey     NVARCHAR(10)
          ,@cTrackingNo  NVARCHAR(20)
          ,@cSKU         NVARCHAR(20)
          ,@nSKUCnt      INT
          ,@b_Success    INT
          ,@cUDF01       NVARCHAR( 30)
          ,@cLabelNo     NVARCHAR( 20)

   SET @cChkOrderKey = ''
   SET @cChkStatus   = ''
   SET @cChkSOStatus = ''
   SET @cLoadKey = ''
   SET @cTrackingNo = ''


   IF @cOption = '1'
   BEGIN

      -- Screen mapping
      SET @cOrderKey = @cParam1
      SET @cUDF01 = @cParam2

      -- james01
      IF ISNULL( @cUDF01 , '') <> ''
      BEGIN
         SELECT TOP 1 @cLabelNo = LabelNo
         FROM dbo.CartonTrack WITH (NOLOCK, INDEX =IX_CARTONTRACK_03)
         WHERE CarrierName='HTKY'
         AND   UDF01 = @cUDF01

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 85266
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UDF
            EXEC rdt.rdtSetFocusField @nMobile, 4 --Param1
            GOTO Quit
         END

         SET @cOrderKey = @cLabelNo
      END

      -- Check blank
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 85251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need OrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      -- Get Order info
      SELECT
         @cChkOrderKey = OrderKey,
         @cChkStatus   = Status,
         @cChkSOStatus = SOStatus
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check OrderKey valid
      IF @cChkOrderKey = ''
      BEGIN
         SET @nErrNo = 85252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
         GOTO Quit
      END

      -- Check order shipped
      IF @cChkStatus = '9' AND @cUDF01 = ''
      BEGIN
         SET @nErrNo = 85253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
         GOTO Quit
      END

      -- Check order cancel
      IF @cChkStatus = 'CANC'
      BEGIN
         SET @nErrNo = 85254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order cancel
         GOTO Quit
      END

      -- Check order status
      IF @cChkSOStatus IN ('HOLD','PENDCANC','PENDGET','PENDPACK')
      BEGIN
         SET @nErrNo = 85255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOrderStatus
         GOTO Quit
      END
   /*
      -- Check order status
      IF @cChkSOStatus <> 'PENDPRINT'
      BEGIN
         DECLARE @cErrMsg1 NVARCHAR(20)
         SET @cErrMsg1 = @cChkSOStatus

         SET @nErrNo = 85256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, @cErrMsg1
         GOTO Quit
      END
   */
      -- Get LoadKey
      SELECT
         @cLoadKey = LoadKey
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check LoadKey
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 85257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') + @cChkSOStatus --OrdNotLoadPlan
         GOTO Quit
      END

      -- Get printer info
      SELECT
         @cLabelPrinter = Printer,
         @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      -- Check label printer blank
      IF @cLabelPrinter = ''
      BEGIN
         SET @nErrNo = 85258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
         GOTO Quit
      END

      DECLARE @cUserName NVARCHAR(18)
      SELECT @cUserName = UserName FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      -- Print BarTender label
      EXECUTE dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cLabelPrinter,
         @c_LabelType    = 'SHIPPLABEL',  -- label type
         @c_userid       = @cUserName,    -- user id
         @c_Parm01       = @cLoadKey,     -- parm01
         @c_Parm02       = @cOrderKey,    -- parm02
         @c_Parm03       = '',            -- parm03
         @c_Parm04       = '',            -- parm04
         @c_Parm05       = '',            -- parm05
         @c_Parm06       = '',            -- parm06
         @c_Parm07       = '',            -- parm07
         @c_Parm08       = '',            -- parm08
         @c_Parm09       = '',            -- parm09
         @c_Parm10       = '',            -- parm10
         @c_StorerKey    = @cStorerKey,   -- StorerKey
         @c_NoCopy       = '1',           -- no of copy
         @b_Debug        = 0,             -- debug
         @c_Returnresult = '',            -- return result
         @n_err          = @nErrNo        OUTPUT,
         @c_errmsg       = @cErrMsg       OUTPUT
   END

   -- (ChewKP01)
   IF @cOption = '2'
   BEGIN
       -- Screen mapping
      SET @cOrderKey = @cParam1
      SET @cTrackingNo = @cParam3

      IF ISNULL(@cOrderKey,'') = '' AND ISNULL(@cTrackingNo,'') = ''
      BEGIN
         SET @nErrNo = 85259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InputReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      IF ISNULL(@cOrderKey,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND OrderKey = @cOrderKey )
         BEGIN
            SET @nErrNo = 85260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidOrder
            EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
            GOTO Quit
         END
      END

      IF ISNULL(@cTrackingNo,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND UserDefine04 = @cTrackingNo )
         BEGIN
            SET @nErrNo = 85261
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidTrackNo
            EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
            GOTO Quit
         END

         SELECT @cOrderKey = OrderKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND UserDefine04 = @cTrackingNo
      END



      SELECT @cDataWindow = DataWindow,
            @cTargetDB = TargetDB
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = 'BAGMANFEST'

      -- Get printer info
      SELECT
         @cLabelPrinter = Printer,
         @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      EXEC RDT.rdt_BuiltPrintJob
       @nMobile,
       @cStorerKey,
       'BAGMANFEST',              -- ReportType
       'ANF_CUSTOMERMANIFEST',    -- PrintJobName
       @cDataWindow,
       @cPaperPrinter,
       @cTargetDB,
       @cLangCode,
       @nErrNo  OUTPUT,
       @cErrMsg OUTPUT,
       @cOrderkey,
       ''


   END

   -- (CheWKP02)
   IF @cOption = '3'
   BEGIN
        -- Screen mapping
      SET @cSKU = @cParam1

      IF ISNULL(@cSKU,'')  = ''
      BEGIN
          SET @nErrNo = 85262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKUReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      -- Get SKU barcode count
      --DECLARE @nSKUCnt INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 85263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 85264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      IF EXISTS ( SELECT 1 FROM dbo.SKUConfig WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU )
      BEGIN
         SELECT @cDataWindow = DataWindow,
            @cTargetDB = TargetDB
         FROM rdt.rdtReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'BOXLABEL'

         -- Get printer info
         SELECT
            @cLabelPrinter = Printer,
            @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         EXEC RDT.rdt_BuiltPrintJob
          @nMobile,
          @cStorerKey,
          'BOXLABEL',    -- ReportType
          'BOXLABEL',    -- PrintJobName
          @cDataWindow,
          @cPaperPrinter,
          @cTargetDB,
          @cLangCode,
          @nErrNo  OUTPUT,
          @cErrMsg OUTPUT,
          @cStorerKey,
          @cSKU
      END
      ELSE
      BEGIN
         SET @nErrNo = 85265
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

   END
Quit:


GO