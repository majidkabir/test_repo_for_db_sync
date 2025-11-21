SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593Print36                                         */
/*                                                                         */
/* Purpose: Reprint HM courier label by scanning BuyerPO.                  */
/*          Need trim leading zero.                                        */
/*          rdt_593Print20->rdt_593Print36                                 */
/*                                                                         */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2022-09-12 1.0  yeekung    WMS20776. Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_593Print36] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- OrderKey
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),  -- Reprint from web service
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

   DECLARE @cLabelPrinter  NVARCHAR( 10)
          ,@cPrinter_Paper NVARCHAR( 10)
          ,@cOrderKey      NVARCHAR( 10)
          ,@cBuyerPO       NVARCHAR( 20)
          ,@cStatus        NVARCHAR( 10)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@nCartonNo      INT
          ,@cLabelNo       NVARCHAR( 20)
          ,@cTrackingNo    NVARCHAR( 20)
          ,@nMyntra        INT
          ,@cInvoiceNo     NVARCHAR( 10)
          ,@cFileType      NVARCHAR( 10)
          ,@cPrintServer   NVARCHAR( 50)
          ,@cStringEncoding   NVARCHAR( 30)
          ,@nFileExists       INT
          ,@bSuccess          INT
          ,@cCMD              NVARCHAR( 1000)
          ,@cPrinterName      NVARCHAR( 100)
          ,@cWinPrinter       NVARCHAR( 128)
          ,@cWorkingFilePath  NVARCHAR( 250)
          ,@cPrintFilePath    NVARCHAR( 250)
          ,@cFilePath         NVARCHAR( 250)
          ,@cFileName         NVARCHAR( 100)
          ,@cErrMsg01         NVARCHAR( 20)
          ,@cErrMsg02         NVARCHAR( 20)
          ,@cWinPrinterName   NVARCHAR( 100)
          ,@cExternOrderKey   NVARCHAR( 50)
          ,@cUsername         NVARCHAR( 20)



   SET @cExternOrderKey = @cParam1

   SET @nMyntra = 0

   -- Both value must not blank
   IF ISNULL(@cParam1, '') = ''
   BEGIN
      SET @nErrNo = 191201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit
   END

   /*--INC1247941(START)
   SELECT @cBuyerPO = SUBSTRING( @cParam1, PATINDEX( '%[^0]%', @cParam1+'.'), LEN( @cParam1)-1)
   SELECT @cBuyerPO = SUBSTRING( @cExternOrderKey, 1, LEN( @cExternOrderKey)-1) --(JH01)
   */--INC1247941(END)

   SELECT @cPrinter_Paper = Printer_Paper,
          @cLabelPrinter = Printer,
          @cUsername = username
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check if it is valid OrderKey
   SELECT @cStatus = [Status],
          @cOrderKey = OrderKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ExternOrderKey = @cExternOrderKey   

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SET @nErrNo = 191202 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS
      GOTO Quit
   END

   IF ISNULL( @cStatus, '') < '5'
    BEGIN
      SET @nErrNo = 191203
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit
   END

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cPickSlipNo, '') = ''
   BEGIN
      SET @nErrNo = 191204
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO PKSLIP NO
      GOTO Quit
   END

   
   IF EXISTS (SELECT 1 From rdt.rdtuser (nolock) WHERE username=@cusername AND OPSPosition='SUser')
   BEGIN
      SET @nErrNo = 191205
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidUser
      GOTO Quit
   END

   IF EXISTS (SELECT 1 From packinfo (nolock) WHERE pickslipno=@cPickSlipNo and cartonstatus='CLOSED')
   BEGIN
      SET @nErrNo = 191206
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PackInfoClosed
      GOTO Quit
   END

   UPDATE packinfo WITH (ROWLOCK)
   SET cartonstatus='Closed'
   WHERE pickslipno=@cPickSlipNo

   IF @@ERROR <> ''
   BEGIN
      SET @nErrNo = 191207
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdPIFail
      GOTO Quit
   END

   -- Check if myntra orders
   IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               AND   StorerKey = @cStorerkey
               AND   M_STATE like 'MYN%')
   BEGIN
      SET @nMyntra = '1'
   END

   IF @nMyntra = '0'
   BEGIN
      -- HM india only 1 carton no for customer orders
      SET @nCartonNo = 1

      SELECT @cTrackingNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo
      AND   CartonNo = @nCartonNo

      /*-------------------------------------------------------------------------------

                                       Print Ship Label

      -------------------------------------------------------------------------------*/

      -- Check label printer blank
      IF @cLabelPrinter = ''
      BEGIN
         SET @nErrNo = 191208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
         GOTO Quit
      END

      EXECUTE dbo.isp_PrintZplLabel
          @cStorerKey        = @cStorerKey
         ,@cLabelNo          = @cOrderKey  --(JH02)
         ,@cTrackingNo       = @cTrackingNo
         ,@cPrinter          = @cLabelPrinter
         ,@nErrNo            = @nErrNo    OUTPUT
         ,@cErrMsg           = @cErrMsg   OUTPUT
   END
   ELSE
   BEGIN
      SELECT @cTrackingNo = TrackingNo
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF ISNULL( @cTrackingNo, '') = ''
      BEGIN
         SET @nErrNo = 191209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Track No'
         GOTO Quit
      END

      -- The Order and Invoice will be 1:1 relationship
      SELECT TOP 1 @cInvoiceNo = InvoiceNo
      FROM dbo.GUIDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cExternOrderKey
      ORDER BY 1

      -- Get the related printing info, path, file type, etc
      SELECT @cWorkingFilePath = UDF01,
             @cFileType = UDF02,
             @cPrintServer = UDF03,
             @cStringEncoding = UDF04,
             @cPrintFilePath = Notes   -- foxit program
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PrintLabel'
      AND   Code = 'QSFilePath'
      AND   Storerkey = @cStorerKey
      AND   (( ISNULL( code2, '') = '') OR ( code2 = 'MyntraSHPLBL'))

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 191210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'
         GOTO Quit
      END

      -- Construct print file
      --SET @cFileName = RTRIM(@cExternOrderKey) + '-' + RTRIM( @cInvoiceNo) + '.' + @cFileType
      SET @cFileName = 'SHPLBL_' + RTRIM( @cTrackingNo) + '.' + @cFileType
      SET @cFilePath = RTRIM( @cWorkingFilePath) + '\' + @cFileName

      EXEC isp_FileExists @cFilePath, @nFileExists OUTPUT, @bSuccess OUTPUT

      --If @Exists=0, then the file exists. This saves having to declare and query a temp table,
      --but requires that you know the file name and extension.
      IF @nFileExists = 0
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg01 = rdt.rdtgetmessage( 191211, @cLangCode, 'DSP') -- No invoice
         SET @cErrMsg02 = rdt.rdtgetmessage( 191212, @cLangCode, 'DSP') -- Proceed to hospital

         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         @cErrMsg01, @cErrMsg02

         SET @nErrNo = 0
         GOTO Quit
      END

      -- Check if valid printer
      IF ISNULL( @cLabelPrinter, '') = ''
      BEGIN
         SET @nErrNo = 191213
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Printer'
         GOTO Quit
      END

      SELECT @cWinPrinter = WinPrinter
      FROM rdt.rdtPrinter WITH (NOLOCK)
      WHERE PrinterID = @cLabelPrinter

      IF CHARINDEX(',' , @cWinPrinter) > 0
      BEGIN
         SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
         SET @cPrinterName = @cLabelPrinter
      END
      ELSE
      BEGIN
         SET @cPrinterName =  @cLabelPrinter
         SET @cWinPrinterName = @cWinPrinter
      END

      SET @cCMD = '"' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cWinPrinterName + '"'

      DECLARE @tRDTPrintJob AS VariableTable

      SET @nErrNo = 0
      -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
         'PDFINVOICE',     -- Report type
         @tRDTPrintJob,    -- Report params
         'rdt_593Print36',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         1,
         @cCMD
      END

Quit:

GO