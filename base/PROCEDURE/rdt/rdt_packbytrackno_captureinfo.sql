SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_PackByTrackNo_CaptureInfo                          */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-11-11 1.0  James   WMS-18225. Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_PackByTrackNo_CaptureInfo](
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10),  -- DISPLAY/UPDATE
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cRefNo       NVARCHAR( 20),                
   @cPickSlipNo  NVARCHAR( 10),
   @cData1       NVARCHAR( 60),
   @cData2       NVARCHAR( 60),
   @cData3       NVARCHAR( 60),
   @cData4       NVARCHAR( 60),
   @cData5       NVARCHAR( 60),
   @cInField01   NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,   
   @cInField02   NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,   
   @cInField03   NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,   
   @cInField04   NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,   
   @cInField05   NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,   
   @cInField06   NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07   NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08   NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09   NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10   NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11   NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT, 
   @cInField12   NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT, 
   @cInField13   NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT, 
   @cInField14   NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT, 
   @cInField15   NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT, 
   @cDataCaptureInfo NVARCHAR( 1)  OUTPUT,
   @tCaptureVar  VariableTable READONLY, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX) = ''
   DECLARE @cSQLParam   NVARCHAR( MAX)

   DECLARE @cCaptureInfoSP NVARCHAR(20)
   SET @cCaptureInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureInfoSP', @cStorerKey)
   IF @cCaptureInfoSP = '0'
      SET @cCaptureInfoSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cCaptureInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCaptureInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCaptureInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,  ' +
            ' @cOrderKey, @cDropID, @cRefNo, @cPickSlipNo, @cData1, @cData2, @cData3, @cData4, @cData5, ' + 
            ' @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, ' +   
            ' @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, ' +   
            ' @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, ' +   
            ' @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, ' +   
            ' @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, ' +   
            ' @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, ' +  
            ' @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, ' +  
            ' @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, ' +  
            ' @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, ' +  
            ' @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, ' +  
            ' @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, ' + 
            ' @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, ' + 
            ' @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, ' + 
            ' @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, ' + 
            ' @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, ' + 
            ' @cDataCaptureInfo OUTPUT, @tCaptureVar, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         SET @cSQLParam =
            ' @nMobile     INT,           ' +
            ' @nFunc       INT,           ' +
            ' @cLangCode   NVARCHAR( 3),  ' +
            ' @nStep       INT,           ' +
            ' @nInputKey   INT,           ' +
            ' @cFacility   NVARCHAR( 5),  ' +
            ' @cStorerKey  NVARCHAR( 15), ' +
            ' @cType       NVARCHAR( 10), ' +
            ' @cOrderKey    NVARCHAR( 10),' + 
            ' @cDropID      NVARCHAR( 20),' + 
            ' @cRefNo       NVARCHAR( 20),' +                
            ' @cPickSlipNo  NVARCHAR( 10),' +
            ' @cData1      NVARCHAR( 60), ' +
            ' @cData2      NVARCHAR( 60), ' +
            ' @cData3      NVARCHAR( 60), ' +
            ' @cData4      NVARCHAR( 60), ' +
            ' @cData5      NVARCHAR( 60), ' +
            ' @cInField01  NVARCHAR(20) OUTPUT,  @cOutField01 NVARCHAR(20) OUTPUT,  @cFieldAttr01 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField02  NVARCHAR(20) OUTPUT,  @cOutField02 NVARCHAR(20) OUTPUT,  @cFieldAttr02 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField03  NVARCHAR(20) OUTPUT,  @cOutField03 NVARCHAR(20) OUTPUT,  @cFieldAttr03 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField04  NVARCHAR(20) OUTPUT,  @cOutField04 NVARCHAR(20) OUTPUT,  @cFieldAttr04 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField05  NVARCHAR(20) OUTPUT,  @cOutField05 NVARCHAR(20) OUTPUT,  @cFieldAttr05 NVARCHAR(1) OUTPUT, ' +   
            ' @cInField06  NVARCHAR(20) OUTPUT,  @cOutField06 NVARCHAR(20) OUTPUT,  @cFieldAttr06 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField07  NVARCHAR(20) OUTPUT,  @cOutField07 NVARCHAR(20) OUTPUT,  @cFieldAttr07 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField08  NVARCHAR(20) OUTPUT,  @cOutField08 NVARCHAR(20) OUTPUT,  @cFieldAttr08 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField09  NVARCHAR(20) OUTPUT,  @cOutField09 NVARCHAR(20) OUTPUT,  @cFieldAttr09 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField10  NVARCHAR(20) OUTPUT,  @cOutField10 NVARCHAR(20) OUTPUT,  @cFieldAttr10 NVARCHAR(1) OUTPUT, ' +  
            ' @cInField11  NVARCHAR(20) OUTPUT,  @cOutField11 NVARCHAR(20) OUTPUT,  @cFieldAttr11 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField12  NVARCHAR(20) OUTPUT,  @cOutField12 NVARCHAR(20) OUTPUT,  @cFieldAttr12 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField13  NVARCHAR(20) OUTPUT,  @cOutField13 NVARCHAR(20) OUTPUT,  @cFieldAttr13 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField14  NVARCHAR(20) OUTPUT,  @cOutField14 NVARCHAR(20) OUTPUT,  @cFieldAttr14 NVARCHAR(1) OUTPUT, ' + 
            ' @cInField15  NVARCHAR(20) OUTPUT,  @cOutField15 NVARCHAR(20) OUTPUT,  @cFieldAttr15 NVARCHAR(1) OUTPUT, ' + 
            ' @cDataCaptureInfo NVARCHAR( 1) OUTPUT,   ' + 
            ' @tCaptureVar VariableTable READONLY, ' +
            ' @nErrNo  INT           OUTPUT, ' +
            ' @cErrMsg NVARCHAR( 20) OUTPUT  ' 
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, 
            @cOrderKey, @cDropID, @cRefNo, @cPickSlipNo, @cData1, @cData2, @cData3, @cData4, @cData5, 
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,   
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,   
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,   
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,   
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,   
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, 
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, 
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
            @cDataCaptureInfo OUTPUT,
            @tCaptureVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cCode       NVARCHAR( 10)
   DECLARE @cLabel      NVARCHAR( 20)
   DECLARE @cColumn     NVARCHAR( 20)
   DECLARE @cListName   NVARCHAR( 10)
   DECLARE @cOption     NVARCHAR( 10)
   DECLARE @cData       NVARCHAR( 20)
   DECLARE @nCursorPos  INT
   DECLARE @curData     CURSOR
   DECLARE @cDataCapture   NVARCHAR( 1)
   
   IF @cType = 'DISPLAY'
   BEGIN
      -- Variable mapping
      SELECT @cDataCapture = Value FROM @tCaptureVar WHERE Variable = '@cDataCapture'

      IF @nStep = 1 AND @cDataCapture <> '1'
      BEGIN
         SET @cDataCaptureInfo = 0
         GOTO Quit      	
      END

      IF @nStep = 3 AND @cDataCapture <> '3'
      BEGIN
         SET @cDataCaptureInfo = 0
         GOTO Quit      	
      END
      
      SET @cDataCaptureInfo = 1
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
         SELECT Code, Notes, UDF01
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTExtUpd'
            AND Storerkey = @cStorerKey
            AND Code2 = @nFunc
         ORDER BY Code
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cLabel, @cListName
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL( @cLabel, '') <> ''
         BEGIN
            IF @cCode = '1' SELECT @cOutField01 = @cLabel, @cFieldAttr02 = '' ELSE
            IF @cCode = '2' SELECT @cOutField03 = @cLabel, @cFieldAttr04 = '' ELSE
            IF @cCode = '3' SELECT @cOutField05 = @cLabel, @cFieldAttr06 = '' ELSE
            IF @cCode = '4' SELECT @cOutField07 = @cLabel, @cFieldAttr08 = '' ELSE
            IF @cCode = '5' SELECT @cOutField09 = @cLabel, @cFieldAttr10 = ''

            -- Get default value from CodeLKUP
            IF CHARINDEX( 'L', @cOption) > 0 AND @cListName <> ''
            BEGIN
               -- Get default value
               SET @cData = ''
               SELECT TOP 1
                  @cData = Code
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = @cListName
                  AND Short LIKE '%D%' -- Default
                  AND StorerKey = @cStorerKey
                  AND Code2 = @nFunc
            
               -- Set default value
               IF @cData <> ''
               BEGIN
                  IF @cCode = '1' SELECT @cOutField02 = @cData ELSE
                  IF @cCode = '2' SELECT @cOutField04 = @cData ELSE
                  IF @cCode = '3' SELECT @cOutField06 = @cData ELSE
                  IF @cCode = '4' SELECT @cOutField08 = @cData ELSE
                  IF @cCode = '5' SELECT @cOutField10 = @cData
               END
            END
         END
         
         FETCH NEXT FROM @curData INTO @cCode, @cLabel, @cListName
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
               SET @nErrNo = 178851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data
               EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
               GOTO Quit
            END

            -- Check format
            IF CHARINDEX( 'F', @cOption) > 0 
            BEGIN
               IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Data' + @cCode, @cData) = 0
               BEGIN
                  SET @nErrNo = 178852
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
                  SET @nErrNo = 178853
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