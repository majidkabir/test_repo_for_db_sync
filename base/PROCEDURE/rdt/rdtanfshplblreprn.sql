SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtANFSHPLBLReprn                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-02-11 1.0  James    SOS300969 Created                              */
/* 2014-05-13 1.1  Chee     If LoadKey is empty, find loadkey from system  */
/*                          base on LabelNo given (Chee01)                 */
/* 2016-07-21 1.2  ChewKP   SOS#373756 - Additional Option (ChewKP01)      */
/* 2020-02-24 1.3  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdtANFSHPLBLReprn] (
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
   DECLARE @cLabelNo      NVARCHAR( 20)
   DECLARE @cLabelType    NVARCHAR( 1)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cPrintTemplateSP  NVARCHAR( 40)
          ,@cUCCNo        NVARCHAR(20)

   IF @cOption IN ( 1,2,6 ) -- (ChewKP01)
   BEGIN
      -- Parameter mapping
      SET @cLoadKey = @cParam1
      SET @cLabelNo = @cParam3

     -- (Chee01)
   --   -- Check blank
   --   IF ISNULL( @cLoadKey, '') = ''
   --   BEGIN
   --      SET @nErrNo = 85101
   --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOADKEY REQ
   --      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
   --      GOTO Quit
   --   END
   --

      -- Check blank
      IF ISNULL( @cLabelNo, '') = ''
      BEGIN
         SET @nErrNo = 85103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LABELNO REQ
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3
         GOTO Quit
      END

      -- If user did not provide loadkey, get from system base on labelno (Chee01)
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SELECT DISTINCT @cLoadKey = PH.LoadKey
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickslipNo = PH.PickSlipNo)
         WHERE PH.StorerKey = @cStorerKey
         AND   PD.LabelNo = @cLabelNo

         IF @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 85101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOADKEY REQ
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END

      -- Check if it is valid loadkey
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE LoadKey = @cLoadKey
                      AND   StorerKey = @cStorerKey)
       BEGIN
         SET @nErrNo = 85102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV LOADKEY
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check if it is valid labelno
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickslipNo = PH.PickSlipNo)
                      WHERE PH.LoadKey = @cLoadKey
                      AND   PH.StorerKey = @cStorerKey
                      AND   PD.LabelNo = @cLabelNo)
       BEGIN
         SET @nErrNo = 85104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV LABELNO
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Get printer info
      SELECT
         @cUserName = UserName,
         @cLabelPrinter = Printer,
         @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      /*-------------------------------------------------------------------------------

                                       Print Label

      -------------------------------------------------------------------------------*/

      -- Check label printer blank
      IF @cLabelPrinter = ''
      BEGIN
         SET @nErrNo = 85105
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
         GOTO Quit
      END

      /*
      opt = 1 (DC2STORE)
      opt = 2 (DC2DC)

      IF  @Parm07 = '0'
         'DC2DC'
      ELSE
         'DC2STORE'
      */

      IF @cOption = '1'
         SET @cLabelType = '1'
      ELSE IF  @cOption = '2'
         SET @cLabelType = '0'
      ELSE IF @cOption = '6'
         SET @cLabelType = '2'

      -- Call Bartender standard SP
      EXECUTE dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cLabelPrinter,     -- printer id
         @c_LabelType    = 'SHIPPLABELANF',    -- label type
         @c_userid       = @cUserName,    -- user id
         @c_Parm01       = @cLoadKey,     -- parm01
         @c_Parm02       = '',            -- parm02
         @c_Parm03       = @cLabelNo,     -- parm03
         @c_Parm04       = '',            -- parm04
         @c_Parm05       = '',            -- parm05
         @c_Parm06       = '',            -- parm06
         @c_Parm07       = @cLabelType,   -- parm07
         @c_Parm08       = '',            -- parm08
         @c_Parm09       = '',            -- parm09
         @c_Parm10       = '',            -- parm10
         @c_StorerKey    = @cStorerKey,   -- StorerKey
         @c_NoCopy       = '1',           -- no of copy
         @b_Debug        = 0,             -- debug
         @c_Returnresult = 'N',            -- return result
         @n_err          = @nErrNo        OUTPUT,
         @c_errmsg       = @cErrMsg       OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

   -- (ChewKP01)
   IF @cOption = '5'
   BEGIN
      SET @cUCCNo = @cParam1

      IF ISNULL(@cUCCNo, '' )  = ''
      BEGIN
         SET @nErrNo = 85106
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCCReq
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param3
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND UCCNo = @cUCCNo )
      BEGIN
         SET @nErrNo = 85107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidUCC
         --EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param3
         GOTO Quit
      END

      -- Call Bartender standard SP
      EXECUTE dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cLabelPrinter,     -- printer id
         @c_LabelType    = 'UCCLBLANF',    -- label type
         @c_userid       = @cUserName,    -- user id
         @c_Parm01       = @cUCCNo,     -- parm01
         @c_Parm02       = '',            -- parm02
         @c_Parm03       = '',     -- parm03
         @c_Parm04       = '',            -- parm04
         @c_Parm05       = '',            -- parm05
         @c_Parm06       = '',            -- parm06
         @c_Parm07       = '',   -- parm07
         @c_Parm08       = '',            -- parm08
         @c_Parm09       = '',            -- parm09
         @c_Parm10       = '',            -- parm10
         @c_StorerKey    = @cStorerKey,   -- StorerKey
         @c_NoCopy       = '1',           -- no of copy
         @b_Debug        = 0,             -- debug
         @c_Returnresult = 'N',            -- return result
         @n_err          = @nErrNo        OUTPUT,
         @c_errmsg       = @cErrMsg       OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

   END
Quit:

GO