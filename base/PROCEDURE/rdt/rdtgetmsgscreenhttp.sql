SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Stored Procedure: rdtGetMsgScreen                                         */
/* Creation Date: 07-Nov-2023                                                */
/* Copyright: Maersk                                                         */
/* Written by: JLC042                                                        */
/*                                                                           */
/* Purpose: Build the screen format from Message Queue,                      */
/*          which rdtMsgQueue table.                                         */
/*                                                                           */
/* Input Parameters: Mobile No                                               */
/*                                                                           */
/* Output Parameters: NIL                                                    */
/*                                                                           */
/* Return Status:                                                            */
/*                                                                           */
/* Usage:                                                                    */
/*                                                                           */
/*                                                                           */
/* Called By: rdtHandleHttp                                                  */
/*                                                                           */
/* PVCS Version: 1.0                                                         */
/*                                                                           */
/* Version: 1.0                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Rev    Author    Purposes                                    */
/* 07-Nov-2023  1.0    JLC042    Copy from rdtGetMsgScreen                   */
/* 17-07-2024   1.1    JACKC     UWP-21829 Error msg not visible             */
/*****************************************************************************/

CREATE    PROC [RDT].[rdtGetMsgScreenHttp] (
   @nMobile       INT,
   @nMsgQueueNo   INT,
   @OutMessage    NVARCHAR(4000) OUTPUT,
   @cMediaType    NVARCHAR(15) = ''
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nScreen int,
           @cLangCode NVARCHAR(3)
          --(yeekung01)
   DECLARE @cLine01 NVARCHAR(MaX),    --(yeekung01)
           @cLine02 NVARCHAR(MaX),    --(yeekung01)
           @cLine03 NVARCHAR(MaX),    --(yeekung01)
           @cLine04 NVARCHAR(MaX),    --(yeekung01)
           @cLine05 NVARCHAR(MaX),    --(yeekung01)
           @cLine06 NVARCHAR(MaX),    --(yeekung01)
           @cLine07 NVARCHAR(MaX),    --(yeekung01)
           @cLine08 NVARCHAR(MaX),    --(yeekung01)
           @cLine09 NVARCHAR(MaX),    --(yeekung01)
           @cLine10 NVARCHAR(MaX),    --(yeekung01)
           @cLine11 NVARCHAR(MaX),    --(yeekung01)
           @cLine12 NVARCHAR(MaX),    --(yeekung01)
           @cLine13 NVARCHAR(MaX),    --(yeekung01)
           @cLine14 NVARCHAR(MaX),    --(yeekung01)
           @cLine15 NVARCHAR(MaX),     --(yeekung01)
           @nDisplayMsg INT,
           @cCounter  INT = 0,
           @cStatus   NVARCHAR(2)

   -- (Vicky01) - Start
   DECLARE @cMsgAddDate NVARCHAR(20)
   -- (Vicky01) - End

   DECLARE @cUsername   NVARCHAR(15), -- (Vicky02)
           @cMobileDisp NVARCHAR(1),  -- (Vicky02)
           @cErrMsg     NVARCHAR(20), -- (james01)
           @cLang_Code  NVARCHAR(3),   -- (james01)
           @cXMLHeader  NVARCHAR( MAX),
           @cXMLScreen  NVARCHAR( MAX),
           @nFunc       INT

   SELECT @cLine01 = ISNULL(Line01, ''),
          @cLine02 = ISNULL(Line02, ''),
          @cLine03 = ISNULL(Line03, ''),
          @cLine04 = ISNULL(Line04, ''),
          @cLine05 = ISNULL(Line05, ''),
          @cLine06 = ISNULL(Line06, ''),
          @cLine07 = ISNULL(Line07, ''),
          @cLine08 = ISNULL(Line08, ''),
          @cLine09 = ISNULL(Line09, ''),
          @cLine10 = ISNULL(Line10, ''),
       /* (Vicky01) - Start: Only use 10 lines for Msg display
          @cLine11 = ISNULL(Line11, ''),
          @cLine12 = ISNULL(Line12, ''),   */
          @cLine13 = ISNULL(Line13, ''),     --(yeekung01)
          @cLine14 = ISNULL(Line14, ''),     --(yeekung01)
          @nDisplayMsg = ISNULL(DisplayMsg, 1), 
          /*@cLine15 = ISNULL(Line15, ''),
          (Vicky01) - End  */
          @nMsgQueueNo = MsgQueueNo,
          @cStatus     = STATUS,
          @cMsgAddDate = CONVERT(Char(20), AddDate, 100) -- (Vicky01)
   FROM RDT.rdtMsgQueue WITH (NOLOCK)
   WHERE MsgQueueNo = @nMsgQueueNo
   AND   Status < '9'

   --1.1 JACKC
   IF @cLine01 <> ''
      SET @cLine01 = rdt.rdtReplaceSpecialCharInXMLData(@cLine01)
   IF @cLine02 <> ''
      SET @cLine02 = rdt.rdtReplaceSpecialCharInXMLData(@cLine02)
   IF @cLine03 <> ''
      SET @cLine03 = rdt.rdtReplaceSpecialCharInXMLData(@cLine03)
   IF @cLine04 <> ''
      SET @cLine04 = rdt.rdtReplaceSpecialCharInXMLData(@cLine04)
   IF @cLine05 <> ''
      SET @cLine05 = rdt.rdtReplaceSpecialCharInXMLData(@cLine05)
   IF @cLine06 <> ''
      SET @cLine06 = rdt.rdtReplaceSpecialCharInXMLData(@cLine06)
   IF @cLine07 <> ''
      SET @cLine07 = rdt.rdtReplaceSpecialCharInXMLData(@cLine07)
   IF @cLine08 <> ''
      SET @cLine08 = rdt.rdtReplaceSpecialCharInXMLData(@cLine08)
   IF @cLine09 <> ''
      SET @cLine09 = rdt.rdtReplaceSpecialCharInXMLData(@cLine09)
   IF @cLine10 <> ''
      SET @cLine10 = rdt.rdtReplaceSpecialCharInXMLData(@cLine10)
   --1.1 JACKC END

  -- SELECT @cErrMsg = rdt.rdtgetmessage(54, @cLang_Code, 'DSP')

   -- (Vicky02) - Start
   SELECT @cUsername = RTRIM(UserName),
          @cErrMsg =  CASE WHEN (ISNULL(@cStatus,'')='0') THEN '' ELSE ErrMsg END, --(yeekung01)
          @nFunc = Func
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile

   SELECT @cMobileDisp = ISNULL(MobileNo_Display, 'Y'),
          @cLang_Code  = DefaultLangCode
   FROM RDT.RDTUSER (NOLOCK)
   WHERE Username = @cUsername
   -- (Vicky02) - End


   --Out Message Header
   SET @cXMLHeader = '<?xml version="1.0" encoding="UTF-8"?>' +
        '<tordt number="' + RTRIM( CAST( @nMobile AS NVARCHAR( 10))) + IIF(@nDisplayMsg = 1, '" status = ''error'' >', '" >' )

   --Out Message Screen Title, XML screen <screen title="">
   SET @cXMLScreen = '<screen'
   -- Get screen title
   DECLARE @cScnTitle NVARCHAR( 250) = ''
   IF @nFunc BETWEEN 5 AND 499 -- Menu
      SET @cScnTitle = rdt.rdtGetMessageLong( @nFunc, @cLangCode, 'MNU')
   ELSE -- Function, include login, store and facility, resume session
      SET @cScnTitle = rdt.rdtGetMessageLong( @nFunc, @cLangCode, 'FNC')
   SET @cXMLScreen += ' title="' + @cScnTitle + '"/>'

   -- (Vicky02) - Start
   IF @cMobileDisp = 'N'
   BEGIN
       SET @OutMessage = @cXMLHeader + @cXMLScreen +
                   '<field typ="output" x="01" y="01" value="' + RTRIM( @cLine01 ) + '"/>' +
                   '<field typ="output" x="01" y="02" value="' + RTRIM( @cLine02 ) + '"/>' +
                   '<field typ="output" x="01" y="03" value="' + RTRIM( @cLine03 ) + '"/>' +
                   '<field typ="output" x="01" y="04" value="' + RTRIM( @cMsgAddDate ) + '"/>' +
                  /* Commended for (Vicky01) - Start
                   '<field typ="output" x="01" y="11" value="' + RTRIM( @cLine11 ) + '"/>' +
                   '<field typ="output" x="01" y="12" value="' + RTRIM( @cLine12 ) + '"/>' +
                   (Vicky01) - End */
    --               '<field typ="output" x="01" y="13" value="' + RTRIM( @cLine13 ) + '"/>' +
    --               '<field typ="output" x="01" y="14" value="' + RTRIM( @cLine14 ) + '"/>' +
                --'<field typ="output" x="01" y="05" value="ESC to Continue^"/>' -- (james01)
                     '<field typ="output" x="01" y="05" value="' + RTRIM( @cErrMsg) + '"/>'
   END
   ELSE
   -- (Vicky02) - End
   BEGIN

       IF ISNULL(@cLine14,'')<>'' OR ISNULL(@cLine14,'')<>0
       BEGIN
         IF ISNULL(@cLine14,'')='1'
         BEGIN
            SET @OutMessage=@cXMLHeader + @cXMLScreen +
            '<field typ="output" x="01" y="01" value="' + RTRIM( @cLine01 ) + '"/>' +
            '<field typ="output" x="01" y="02" value="' + RTRIM( @cLine02 ) + '"/>'

            IF @cLine03 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="input" x="01" y="03" length="20" id="I_Field16" default="" match="" />'
               SET @cCounter='1'
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="03" value="' + RTRIM( @cLine03 ) + '"/>'
            END

            IF @cLine04 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="04" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="04" length="20" id="I_Field17" default="" match="" />' END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="04" value="' + RTRIM( @cLine04 ) + '"/>'
            END

            IF @cLine05 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="05" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="05" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="05" length="20" id="I_Field18" default="" match="" />' END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="05" value="' + RTRIM( @cLine05 ) + '"/>'
            END
            IF @cLine06 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="06" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="06" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="06" length="20" id="I_Field18" default="" match="" />'
                                                   WHEN @cCounter='3' THEN'<field typ="input" x="01" y="06" length="20" id="I_Field19" default="" match="" />'  END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="06" value="' + RTRIM( @cLine06 ) + '"/>'
            END
            IF @cLine07 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="07" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="07" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="07" length="20" id="I_Field18" default="" match="" />'
                                                   WHEN @cCounter='3' THEN'<field typ="input" x="01" y="07" length="20" id="I_Field19" default="" match="" />'
                                                   WHEN @cCounter='4' THEN'<field typ="input" x="01" y="07" length="20" id="I_Field20" default="" match="" />'  END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="07" value="' + RTRIM( @cLine07 ) + '"/>'
            END
            IF @cLine08 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="08" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="08" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="08" length="20" id="I_Field18" default="" match="" />'
                                                   WHEN @cCounter='3' THEN'<field typ="input" x="01" y="08" length="20" id="I_Field19" default="" match="" />'
                                                   WHEN @cCounter='4' THEN'<field typ="input" x="01" y="08" length="20" id="I_Field20" default="" match="" />'  END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="08" value="' + RTRIM( @cLine08 ) + '"/>'
            END
            IF @cLine09 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="09" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="09" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="09" length="20" id="I_Field18" default="" match="" />'
                                                   WHEN @cCounter='3' THEN'<field typ="input" x="01" y="09" length="20" id="I_Field19" default="" match="" />'
                                                   WHEN @cCounter='4' THEN'<field typ="input" x="01" y="09" length="20" id="I_Field20" default="" match="" />'  END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="09" value="' + RTRIM( @cLine09 ) + '"/>'
            END
            IF @cLine10 ='%I_Field'
            BEGIN
               SET @OutMessage = @OutMessage +CASE WHEN @cCounter='0' THEN'<field typ="input" x="01" y="10" length="20" id="I_Field16" default="" match="" />'
                                                   WHEN @cCounter='1' THEN'<field typ="input" x="01" y="10" length="20" id="I_Field17" default="" match="" />'
                                                   WHEN @cCounter='2' THEN'<field typ="input" x="01" y="10" length="20" id="I_Field18" default="" match="" />'
                                                   WHEN @cCounter='3' THEN'<field typ="input" x="01" y="10" length="20" id="I_Field19" default="" match="" />'
                                                   WHEN @cCounter='4' THEN'<field typ="input" x="01" y="10" length="20" id="I_Field20" default="" match="" />'  END
               SET @cCounter=@cCounter+1
            END
            ELSE
            BEGIN
               SET @OutMessage = @OutMessage +'<field typ="output" x="01" y="10" value="' + RTRIM( @cLine10 ) + '"/>'
            END

            SET @OutMessage= @OutMessage +
                        '<field typ="output" x="01" y="12" value="' + RTRIM( @cMsgAddDate ) + '"/>'+
                        '<field typ="output" x="01" y="14" value="' + RTRIM( @cErrMsg) + '"/>'
         END
         ELSE
         BEGIN

            SET @OutMessage=@cXMLHeader + @cXMLScreen +
                            '<field typ="output" x="01" y="01" value="' + RTRIM( @cLine01 ) + '"/>' +
                            '<field typ="output" x="01" y="02" value="' + RTRIM( @cLine02 ) + '"/>' +
                            '<field typ="output" x="01" y="03" value="' + RTRIM( @cLine03 ) + '"/>' +
                            '<field typ="output" x="01" y="04" value="' + RTRIM( @cLine04 ) + '"/>' +
                            '<field typ="output" x="01" y="05" value="' + RTRIM( @cLine05 ) + '"/>' +
                            '<field typ="output" x="01" y="06" value="' + RTRIM( @cLine06 ) + '"/>' +
                            '<field typ="output" x="01" y="08" value="Username:"/>' +
                            '<field typ="input" x="01" y="09" length="10" id="I_Field19" default="" match="" />' +
                            '<field typ="output" x="01" y="10" value="Password:"/>' +
                            '<field typ="input" x="01" y="11" length="10" id="I_Field20" default="" match="" />' +
                            '<field typ="output" x="01" y="12" value="' + RTRIM( @cMsgAddDate ) + '"/>' +
                            '<field typ="output" x="01" y="14" value="%e"/>'
         END
       END
       ELSE
       BEGIN
         SET @OutMessage=   @cXMLHeader + @cXMLScreen +
            '<field typ="output" x="01" y="01" value="' + RTRIM( @cLine01 ) + '"/>' +
            '<field typ="output" x="01" y="02" value="' + RTRIM( @cLine02 ) + '"/>' +
            '<field typ="output" x="01" y="03" value="' + RTRIM( @cLine03 ) + '"/>' +
            '<field typ="output" x="01" y="04" value="' + RTRIM( @cLine04 ) + '"/>' +
            '<field typ="output" x="01" y="05" value="' + RTRIM( @cLine05 ) + '"/>' +
            '<field typ="output" x="01" y="06" value="' + RTRIM( @cLine06 ) + '"/>' +
            '<field typ="output" x="01" y="07" value="' + RTRIM( @cLine07 ) + '"/>' +
            '<field typ="output" x="01" y="08" value="' + RTRIM( @cLine08 ) + '"/>' +
            '<field typ="output" x="01" y="09" value="' + RTRIM( @cLine09 ) + '"/>' +
            '<field typ="output" x="01" y="10" value="' + RTRIM( @cLine10 ) + '"/>' +
            '<field typ="output" x="01" y="11" value="' + RTRIM( @cMsgAddDate ) + '"/>'+
               /* Commended for (Vicky01) - Start
               '<field typ="output" x="01" y="11" value="' + RTRIM( @cLine11 ) + '"/>' +
               '<field typ="output" x="01" y="12" value="' + RTRIM( @cLine12 ) + '"/>' +
               (Vicky01) - End */
--               '<field typ="output" x="01" y="13" value="' + RTRIM( @cLine13 ) + '"/>' +
--               '<field typ="output" x="01" y="14" value="' + RTRIM( @cLine14 ) + '"/>' +
               '<field typ="output" x="01" y="13" value="ESC to Continue^"/>' -- (james01)
              -- '<field typ="output" x="01" y="13" value="' + RTRIM( @cErrMsg) + '"/>'
       END
   END

   DECLARE
   --@nFunc int,
           @nStep int,
           @nScn  int

   SELECT @nFunc = [Func],
          @nStep = [Step],
          @nScn  = [Scn]
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile

   -- (Vicky02) - Start
   IF @cMobileDisp = 'N'
   BEGIN
     SET @OutMessage = RTRIM(@OutMessage) +
     '<field typ="output" x="01" y="06" value="Fn'+ RIGHT(RTRIM(CAST(@nFunc as NVARCHAR(6))), 4)
     --+ '-Sn' + RIGHT(RTRIM(CAST(@nScn as NVARCHAR(6))), 3) --(ChewKP01)
     + '-St' + RIGHT(RTRIM(CAST(@nStep as NVARCHAR(6))), 3)
--    + '-' + RIGHT(RTRIM(CAST(@nMobile as NVARCHAR(6))), 3) -- take out M because screen only can display 19 chars
     +  '"/>' + '</tordt>'
   END
   ELSE
   -- (Vicky02) - End
   BEGIN
      SET @OutMessage = RTRIM(@OutMessage) +
      '<field typ="output" x="01" y="15" value="Fn'+ RIGHT(RTRIM(CAST(@nFunc as NVARCHAR(6))), 4)
      --+ '-Sn' + RIGHT(RTRIM(CAST(@nScn as NVARCHAR(6))), 3) --(ChewKP01)
      + '-St' + RIGHT(RTRIM(CAST(@nStep as NVARCHAR(6))), 3)
      + '-M' + RIGHT(RTRIM(CAST(@nMobile as NVARCHAR(6))), 5) -- (ChewKP02)
      +  '"/>' + '</tordt>'
   END

   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      MsgQueueNo = @nMsgQueueNo
   WHERE  Mobile = @nMobile

   UPDATE RDT.rdtMsgQueue WITH (ROWLOCK)
      SET  Status = '1'
   WHERE  Mobile = @nMobile
   AND    MsgQueueNo = @nMsgQueueNo


RETURN_SP:


GO