SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Store Procedure: rdtGetXMLHttp                                           */
/* Copyright      : Maersk                                                  */
/*                                                                          */
/* Purpose: Generate the rest of XML, beside the screen fields              */
/*                                                                          */
/* Date         Ver.  Author    Purposes                                    */
/* 20-Sep-2023  1.0   JLC042    Created base on rdtGetXML 2.0               */
/****************************************************************************/

CREATE   PROC [RDT].[rdtGetXMLHttp](
   @nMobile INT,
   @cXML NVARCHAR(MAX) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cXMLHeader       NVARCHAR( MAX),
      @cXMLSession      NVARCHAR( MAX),
      @cXMLScreen       NVARCHAR( MAX),
      @cXMLFooter       NVARCHAR( MAX),

      @nFunc            INT,
      @nStep            INT,
      @nScn             INT,
      @cUsername        NVARCHAR( 15),
      @cErrMsg          NVARCHAR( 125),
      @cLangCode        NVARCHAR( 3),
      @nRemotePrint     INT,
      @cV_MAX           NVARCHAR( MAX),
      @cStorerKey       NVARCHAR( 15),

      @cFocus           NVARCHAR( 20),
      @cMobileDisp      NVARCHAR( 1),
      @cSoundLevel      NVARCHAR( 10),
      @cVibrationLevel  NVARCHAR( 10),
      @cPrintData       NVARCHAR( MAX)

   -- Get sesion info
   SELECT
      @nFunc = Func,
      @nStep = Step,
      @nScn  = Scn,
      @cUsername = RTRIM(UserName),
      @cErrMsg = RTRIM(ErrMSG),
      @cLangCode = Lang_Code,
      @nRemotePrint = RemotePrint,
      @cV_MAX = V_MAX,
      @cStorerKey = StorerKey
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cFocus = Focus FROM rdt.rdtXML_Root WITH (NOLOCK) WHERE Mobile = @nMobile
   IF @cFocus IS NULL
      SET @cFocus = ''

   -- Get user info
   SELECT
      @cMobileDisp = ISNULL(MobileNo_Display, 'Y'),
      @cSoundLevel = SoundLevel,
      @cVibrationLevel = VibrationLevel
   FROM rdt.rdtUser WITH (NOLOCK)
   WHERE Username = @cUsername

   -- XML header
   SET @cXMLHeader = '<?xml version="1.0" encoding="UTF-8"?>'

   -- XML session <tordt number="" focus="" status="" soundlevel="" vibrationlevel="">
   SET @cXMLSession += ' <tordt number="' + CAST( @nMobile AS NVARCHAR(10)) + '" '
   IF @cFocus <> ''
      IF CHARINDEX( ' id="' + @cFocus + '"', @cXML) > 0
         SET @cXMLSession += ' focus="' + @cFocus + '"'

   DECLARE @iStart INT
   DECLARE @iLength INT
   IF CHARINDEX( ' focus="', @cXMLSession) = 0
   BEGIN
      SET @iStart = CHARINDEX( ' id="', @cXML)
      IF @iStart > 0
      BEGIN
         SET @iStart = @iStart + LEN( ' id="')
         SET @iLength = CHARINDEX( '"', SUBSTRING( @cXML, @iStart, LEN( @cXML)))
         SET @cXMLSession += ' focus="' + SUBSTRING( @cXML, @iStart, ABS( @iLength - 1)) + '"'
      END
   END

   IF @cErrMsg <> ''
      SET @cXMLSession += ' status="error"'
   -- Sound and vibration only send once after login in screen
   IF @cSoundLevel <> '' AND @nFunc < 5
      SET @cXMLSession += ' soundlevel="' + @cSoundLevel + '"'
   IF @cVibrationLevel <> ''  AND @nFunc < 5
      SET @cXMLSession += ' vibrationlevel="' + @cVibrationLevel + '"'
   SET @cXMLSession += '>'

   -- XML screen <screen title="" autodisappear="">
   SET @cXMLScreen = '<screen'

   -- Get screen title
   DECLARE @cScnTitle NVARCHAR( 250) = ''
   IF @nFunc BETWEEN 5 AND 499 -- Menu
      SET @cScnTitle = rdt.rdtGetMessageLong( @nFunc, @cLangCode, 'MNU')
   ELSE -- Function, include login, store and facility, resume session
      SET @cScnTitle = rdt.rdtGetMessageLong( @nFunc, @cLangCode, 'FNC')
   SET @cXMLScreen += ' title="' + @cScnTitle + '"'

   -- Get auto disappear screen
   DECLARE @cAutoDisappear NVARCHAR( 10) = ''
   IF @nFunc > 499 -- Function
   BEGIN
      -- Get screen info
      SELECT @cAutoDisappear = AutoDisappear FROM rdt.rdtScn WITH (NOLOCK) WHERE Scn = @nScn

      -- Screen is auto disappear type
      IF @cAutoDisappear <> ''
         -- The storer and facility activate it
         IF rdt.RDTGetConfig( @nFunc, 'AutoDisappearScreen', @cStorerKey) = '1'
            SET @cXMLScreen += ' autodisappear="' + @cAutoDisappear + '"'
   END
   SET @cXMLScreen += "/>"

   -- XML footer
   IF @cMobileDisp = 'N'
      SET @cXMLFooter = '<field typ="output" x="01" y="6" value="' +
         'Fn'+ CAST( @nFunc AS NVARCHAR(4)) +
         '-St' + CAST( @nStep AS NVARCHAR(3)) +
         --'-M' + CAST( @nMobile AS NVARCHAR(3))  -- take out because screen only can display 19 chars
         + '"/>'
   ELSE
      SET @cXMLFooter = '<field typ="output" x="01" y="15" value="' +
         'Fn'+ CAST( @nFunc AS NVARCHAR(4)) +
         '-St' + CAST( @nStep AS NVARCHAR(3)) +
         '-M' + CAST( @nMobile AS NVARCHAR(5)) +
         '"/>'
   SET @cXMLFooter += '</tordt>'

   -- Construct entire XML
   SET @cXML =
      @cXMLHeader +
      @cXMLSession +
      @cXMLScreen +
      @cXML +
      @cXMLFooter

GO