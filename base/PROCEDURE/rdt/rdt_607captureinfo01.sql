SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_607CaptureInfo01                                   */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2023-07-26 1.0  James   WMS-23005. Created                              */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_607CaptureInfo01](
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 10),
   @cReceiptKey NVARCHAR( 10),
   @cRefNo      NVARCHAR( 60),
   @cID         NVARCHAR( 18),
   @cLOC        NVARCHAR( 10),
   @cData1      NVARCHAR( 60),
   @cData2      NVARCHAR( 60),
   @cData3      NVARCHAR( 60),
   @cData4      NVARCHAR( 60),
   @cData5      NVARCHAR( 60),
   @cInField01  NVARCHAR(20) OUTPUT,  @cOutField01 NVARCHAR(20) OUTPUT,  @cFieldAttr01 NVARCHAR(1) OUTPUT,
   @cInField02  NVARCHAR(20) OUTPUT,  @cOutField02 NVARCHAR(20) OUTPUT,  @cFieldAttr02 NVARCHAR(1) OUTPUT,
   @cInField03  NVARCHAR(20) OUTPUT,  @cOutField03 NVARCHAR(20) OUTPUT,  @cFieldAttr03 NVARCHAR(1) OUTPUT,
   @cInField04  NVARCHAR(20) OUTPUT,  @cOutField04 NVARCHAR(20) OUTPUT,  @cFieldAttr04 NVARCHAR(1) OUTPUT,
   @cInField05  NVARCHAR(20) OUTPUT,  @cOutField05 NVARCHAR(20) OUTPUT,  @cFieldAttr05 NVARCHAR(1) OUTPUT,
   @cInField06  NVARCHAR(20) OUTPUT,  @cOutField06 NVARCHAR(20) OUTPUT,  @cFieldAttr06 NVARCHAR(1) OUTPUT,
   @cInField07  NVARCHAR(20) OUTPUT,  @cOutField07 NVARCHAR(20) OUTPUT,  @cFieldAttr07 NVARCHAR(1) OUTPUT,
   @cInField08  NVARCHAR(20) OUTPUT,  @cOutField08 NVARCHAR(20) OUTPUT,  @cFieldAttr08 NVARCHAR(1) OUTPUT,
   @cInField09  NVARCHAR(20) OUTPUT,  @cOutField09 NVARCHAR(20) OUTPUT,  @cFieldAttr09 NVARCHAR(1) OUTPUT,
   @cInField10  NVARCHAR(20) OUTPUT,  @cOutField10 NVARCHAR(20) OUTPUT,  @cFieldAttr10 NVARCHAR(1) OUTPUT,
   @cInField11  NVARCHAR(20) OUTPUT,  @cOutField11 NVARCHAR(20) OUTPUT,  @cFieldAttr11 NVARCHAR(1) OUTPUT,
   @cInField12  NVARCHAR(20) OUTPUT,  @cOutField12 NVARCHAR(20) OUTPUT,  @cFieldAttr12 NVARCHAR(1) OUTPUT,
   @cInField13  NVARCHAR(20) OUTPUT,  @cOutField13 NVARCHAR(20) OUTPUT,  @cFieldAttr13 NVARCHAR(1) OUTPUT,
   @cInField14  NVARCHAR(20) OUTPUT,  @cOutField14 NVARCHAR(20) OUTPUT,  @cFieldAttr14 NVARCHAR(1) OUTPUT,
   @cInField15  NVARCHAR(20) OUTPUT,  @cOutField15 NVARCHAR(20) OUTPUT,  @cFieldAttr15 NVARCHAR(1) OUTPUT,
   @tCaptureVar VariableTable READONLY,
   @nErrNo  INT OUTPUT,
   @cErrMsg NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX) = ''
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cCode       NVARCHAR( 10)
   DECLARE @cLabel      NVARCHAR( 20)
   DECLARE @cColumn     NVARCHAR( 20)
   DECLARE @cListName   NVARCHAR( 10)
   DECLARE @cOption     NVARCHAR( 10)
   DECLARE @cData       NVARCHAR( 20)
   DECLARE @nCursorPos  INT
   DECLARE @nNextCursorPos  INT
   DECLARE @curData     CURSOR
   DECLARE @cTempID     NVARCHAR( 18)

   IF @cType = 'DISPLAY'
   BEGIN
      SELECT @cInField01 = '', @cOutField01 = ''
      SELECT @cInField02 = '', @cOutField02 = ''
      SELECT @cInField03 = '', @cOutField03 = ''
      SELECT @cInField04 = '', @cOutField04 = ''
      SELECT @cInField05 = '', @cOutField05 = ''
      SELECT @cInField06 = '', @cOutField06 = ''
      SELECT @cInField07 = '', @cOutField07 = ''
      SELECT @cInField08 = '', @cOutField08 = ''
      SELECT @cInField09 = '', @cOutField09 = ''
      SELECT @cInField10 = '', @cOutField10 = ''

      SET @cFieldAttr02 = 'O'
      SET @cFieldAttr04 = 'O'
      SET @cFieldAttr06 = 'O'
      SET @cFieldAttr08 = 'O'
      SET @cFieldAttr10 = 'O'

      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code, Notes
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTExtUpd'
            AND Storerkey = @cStorerKey
            AND Code2 = @nFunc
         ORDER BY Code
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cLabel
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL( @cLabel, '') <> ''
         BEGIN
            IF @cCode = '1' SELECT @cOutField01 = @cLabel, @cFieldAttr02 = '' ELSE
            IF @cCode = '2' SELECT @cOutField03 = @cLabel, @cFieldAttr04 = '' ELSE
            IF @cCode = '3' SELECT @cOutField05 = @cLabel, @cFieldAttr06 = '' ELSE
            IF @cCode = '4' SELECT @cOutField07 = @cLabel, @cFieldAttr08 = '' ELSE
            IF @cCode = '5' SELECT @cOutField09 = @cLabel, @cFieldAttr10 = ''
         END

         FETCH NEXT FROM @curData INTO @cCode, @cLabel
      END

      -- Position on 1st empty field
      IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
      IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
      IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
      IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
   END

   IF @cType = 'UPDATE'
   BEGIN
      -- Construct update columns TSQL
      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code, Short, Long, UDF01
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTExtUpd'
            AND Storerkey = @cStorerKey
            AND Code2 = @nFunc
         ORDER BY Code
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cOption, @cColumn, @cListName
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Check require field
         IF @cOption <> ''
         BEGIN
            -- Get data
            IF @cCode = '1' SELECT @cData = @cData1, @nCursorPos = 2  ELSE
            IF @cCode = '2' SELECT @cData = @cData2, @nCursorPos = 4  ELSE
            IF @cCode = '3' SELECT @cData = @cData3, @nCursorPos = 6  ELSE
            IF @cCode = '4' SELECT @cData = @cData4, @nCursorPos = 8  ELSE
            IF @cCode = '5' SELECT @cData = @cData5, @nCursorPos = 10

            -- Check blank
            IF CHARINDEX( 'R', @cOption) > 0 AND @cData = ''
            BEGIN
               SET @nErrNo = 165252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data
               EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
               GOTO Quit
            END

            -- Check format
            IF CHARINDEX( 'F', @cOption) > 0
            BEGIN
               IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Data' + @cCode, @cData) = 0
               BEGIN
                  SET @nErrNo = 165253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                  GOTO Quit
               END
            END

            -- Check value in CodeLKUP
            IF CHARINDEX( 'L', @cOption) > 0 AND @cListName <> ''
            BEGIN
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM CodeLKUP WITH (NOLOCK)
                  WHERE ListName = @cListName
                     AND Code = @cData
                     AND StorerKey = @cStorerKey
                     AND Code2 = @nFunc)
               BEGIN
                  SET @nErrNo = 165254
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid value
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                  GOTO Quit
               END
            END
         END

         FETCH NEXT FROM @curData INTO @cCode, @cOption, @cColumn, @cListName
      END
   END
Quit:

END

GO