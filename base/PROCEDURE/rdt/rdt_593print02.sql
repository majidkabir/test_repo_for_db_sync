SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_593Print02                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2015-11-25 1.0  ChewKP   SOS#357567 Created                             */
/* 2016-02-24 1.1  ChewKP   SOS#364275 - (ChewKP01)                        */
/* 24-02-2020 1.2  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print02] (
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
         , @cExternOrderKey     NVARCHAR(20)
         , @cOrderKey     NVARCHAR(10)
         , @cPickSlipNo   NVARCHAR(10)
         , @nCartonNo     INT
         , @cNoOfCopy     NVARCHAR(5)
         , @nCount        INT
         , @nNoOfCopy     INT


   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 95251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END


   IF @cOption = '2'
   BEGIN

      SET @cExternOrderKey = @cParam1
      SET @cNoOfCopy       = @cParam3

      SELECT @cOrderKey = OrderKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ExternOrderKey = @cExternOrderKey

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                      WHERE OrderKey = @cOrderKey
                      AND Status = '9' )
      BEGIN
         SET @nErrNo = 95254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PackNotComplete
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END


      -- Check blank
      IF ISNULL(RTRIM(@cExternOrderKey), '') = ''
      BEGIN
         SET @nErrNo = 95252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ExtOrderKeyReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE ExternOrderKey = @cExternOrderKey
                      AND StorerKey = @cStorerKey  )
      BEGIN
         SET @nErrNo = 95253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidExtOrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey


      IF ISNULL(@cNoOfCopy,'' )  <> ''
      BEGIN

         IF RDT.rdtIsValidQTY( @cNoOfCopy, 0) = 0
         BEGIN
            SET @nErrNo = 95255
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidInput
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1
            GOTO Quit
         END

         SET @nNoOfCopy = @cNoOfCopy

         SET @nCount = 0

         WHILE @nCount < @nNoOfCopy
         BEGIN

            SET @cLabelType = 'SHIPPLABELMO'

            EXEC dbo.isp_BT_GenBartenderCommand
                  @cPrinterID     = @cLabelPrinter
                , @c_LabelType    = @cLabelType
                , @c_userid       = @cUserName
                , @c_Parm01       = @cStorerKey
                , @c_Parm02       = @cExternOrderKey
                , @c_Parm03       = ''
                , @c_Parm04       = ''
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

            IF @cERRMSG <> ''
            BEGIN
               SET @nErrNo = 95256
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PrintError
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
               BREAK
            END

            SET @nCount = @nCount +  1

            CONTINUE
         END


      END
      ELSE
      BEGIN

         DECLARE C_NIKELBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT DISTINCT CartonNo
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.StorerKey = @cStorerKey
         AND PD.PickSlipNo = @cPickSlipNo
         ORDER BY PD.CartonNo


         OPEN C_NIKELBL
         FETCH NEXT FROM C_NIKELBL INTO  @nCartonNo
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            SET @cLabelType = 'SHIPPLABELMO'

            EXEC dbo.isp_BT_GenBartenderCommand
                  @cPrinterID     = @cLabelPrinter
                , @c_LabelType    = @cLabelType
                , @c_userid       = @cUserName
                , @c_Parm01       = @cStorerKey
                , @c_Parm02       = @cExternOrderKey
                , @c_Parm03       = ''
                , @c_Parm04       = ''
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


                IF @cERRMSG <> ''
                BEGIN
                   SET @nErrNo = 95257
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PrintError
                   EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
                   BREAK
                END

                FETCH NEXT FROM C_NIKELBL INTO  @nCartonNo

         END
         CLOSE C_NIKELBL
         DEALLOCATE C_NIKELBL
      END
   END


Quit:

GO