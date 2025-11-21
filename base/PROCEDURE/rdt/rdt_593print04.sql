SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_593Print04                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2015-12-30 1.0  AlanTan  SOS#360064 Created                             */
/* 2020-02-24 1.1  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print04] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- CaseID
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
         , @cCaseID     NVARCHAR(20)



   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 95601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   IF @cOption = '1'
   BEGIN
      SET @cCaseID = @cParam1

      -- Check blank
      IF ISNULL(RTRIM(@cCaseID), '') = ''
      BEGIN
         SET @nErrNo = 95602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CartonIDReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                      WHERE CaseID = @cCaseID )
      BEGIN
         SET @nErrNo = 95603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidCartonID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                      WHERE CaseID = @cCaseID
                      AND MUStatus = '10' )
      BEGIN
         SET @nErrNo = 95604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidStatus
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      -- Print Label
      SET @cLabelType = 'CARTONLBLGAP'

      EXEC dbo.isp_BT_GenBartenderCommand
            @cPrinterID     = @cLabelPrinter
          , @c_LabelType    = @cLabelType
          , @c_userid       = ''
          , @c_Parm01       = @cCaseID
          , @c_Parm02       = ''
          , @c_Parm03       = ''
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
          , @c_errmsg       = @cErrMsg OUTPUT
   END
Quit:

GO