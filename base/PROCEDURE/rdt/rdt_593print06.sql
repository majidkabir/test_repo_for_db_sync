SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_593Print06                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-03-18 1.0  ChewKP   SOS#365631 Created                             */
/* 2020-02-24 1.1  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print06] (
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
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cLabelType    NVARCHAR( 20)
         , @cExternOrderKey  NVARCHAR(20)
         , @cOrderKey     NVARCHAR(10)
         , @cPickSlipNo   NVARCHAR(10)
         , @nCartonNo     INT
         , @cOrderDate    NVARCHAR(8)
         , @cDay          NVARCHAR(2)
         , @cMonth        NVARCHAR(2)
         , @cYear         NVARCHAR(4)
         , @nNoInputFlag  INT
         , @cErrMsg1      NVARCHAR( 20)
         , @cErrMsg2      NVARCHAR( 20)
         , @cErrMsg3      NVARCHAR( 20)
         , @cErrMsg4      NVARCHAR( 20)
         , @cErrMsg5      NVARCHAR( 20)

   SET @nNoInputFlag = 0

   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 97851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END


   IF @cOption = '1'
   BEGIN

      SET @cOrderDate = @cParam1
      SET @cExternOrderKey = @cParam3

      IF ISNULL(@cOrderDate,'')  = '' AND ISNULL(@cExternOrderKey,'' )  = ''
      BEGIN
--         SET @nErrNo = 97852
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InputReq
--         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
--         GOTO Quit
           SET @cDay   = Day(GetDate())
           SET @cMonth = Month(GetDate())
           SET @cYear  = Year(GetDate())

           SET @cOrderDate =  @cYear + RIGHT('00' + @cMonth, 2) + RIGHT('00' + @cDay, 2)
           SET @nNoInputFlag = 1
      END


--      IF ISNULL(@cOrderDate,'' ) = ''
--      BEGIN
--         SET @nErrNo = 97853
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --OrderDateReq
--         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
--         GOTO Quit
--      END

      IF ISNULL(@cOrderDate,'' ) <> ''
      BEGIN
         IF LEN(@cOrderDate) <> 8
         BEGIN
            SET @nErrNo = 97857
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --OrderDateReq
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
            GOTO Quit
         END


         IF RDT.rdtIsValidQTY( @cOrderDate, 0) = 0
         BEGIN
            SET @nErrNo = 97854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidDate
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
            GOTO Quit
         END
      END

      IF ISNULL(@cExternOrderKey,'' ) <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND ExternOrderKey = @cExternOrderKey )
         BEGIN
            SET @nErrNo = 97856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidExtOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO Quit
         END
      END

      SET @cLabelType = 'SHIPPLABEL'

      EXEC dbo.isp_BT_GenBartenderCommand
            @cPrinterID     = @cLabelPrinter
          , @c_LabelType    = @cLabelType
          , @c_userid       = @cUserName
          , @c_Parm01       = @cOrderDate
          , @c_Parm02       = @cExternOrderKey
          , @c_Parm03       = @cStorerKey
          , @c_Parm04       = ''
          , @c_Parm05       = ''
          , @c_Parm06       = ''
          , @c_Parm07       = ''
          , @c_Parm08       = ''
          , @c_Parm09       = ''
          , @c_Parm10       = ''
          , @c_StorerKey    = ''
          , @c_NoCopy       = '1'
          , @b_Debug        = '0'
          , @c_Returnresult = 'N'
          , @n_err          = @nErrNo  OUTPUT
          , @c_errmsg       = @cERRMSG OUTPUT

     IF @nErrNo <> 0
     BEGIN
         SET @nErrNo = 97858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidExtOrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
     END
   END
Quit:

GO