SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************************/
/* Store procedure: rdtfnc_Outbound_PalletTempCapture                                           */
/* Copyright      : Maersk                                                                      */
/*                                                                                              */
/* Date        Rev   Author         Purposes                                                    */
/* 2024-12-05  1.0.0 PXL009         FCR-1398 Temp Capture                                       */
/************************************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Outbound_PalletTempCapture] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @bSuccess            INT,
   @nAction             INT,

   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @nTranCount          INT,
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),

   @cPalletChoice       NVARCHAR( 20),
   @cMBOLKey            NVARCHAR( 10),
   @cPalletID           NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cItemClass          NVARCHAR( 10),
   @cTemperature        NVARCHAR( 20),
   @nTemperature        DECIMAL(5 ,2),
   @cTemperatureUnit    NVARCHAR( 20),
   @cTemperatureMin     NVARCHAR( 20),
   @nTemperatureMin     DECIMAL(5 ,2),
   @cTemperatureMax     NVARCHAR( 20),
   @nTemperatureMax     DECIMAL(5 ,2),
   @cTempCheckPoint     NVARCHAR( 20),
   @cOption             NVARCHAR( 1),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),   @cFieldAttr01 NVARCHAR( 1), @cLottable01  NVARCHAR( 18),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),   @cFieldAttr02 NVARCHAR( 1), @cLottable02  NVARCHAR( 18),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),   @cFieldAttr03 NVARCHAR( 1), @cLottable03  NVARCHAR( 18),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),   @cFieldAttr04 NVARCHAR( 1), @dLottable04  DATETIME,
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),   @cFieldAttr05 NVARCHAR( 1), @dLottable05  DATETIME,
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),   @cFieldAttr06 NVARCHAR( 1), @cLottable06  NVARCHAR( 30),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),   @cFieldAttr07 NVARCHAR( 1), @cLottable07  NVARCHAR( 30),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),   @cFieldAttr08 NVARCHAR( 1), @cLottable08  NVARCHAR( 30),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),   @cFieldAttr09 NVARCHAR( 1), @cLottable09  NVARCHAR( 30),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),   @cFieldAttr10 NVARCHAR( 1), @cLottable10  NVARCHAR( 30),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),   @cFieldAttr11 NVARCHAR( 1), @cLottable11  NVARCHAR( 30),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),   @cFieldAttr12 NVARCHAR( 1), @cLottable12  NVARCHAR( 30),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),   @cFieldAttr13 NVARCHAR( 1), @dLottable13  DATETIME,
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),   @cFieldAttr14 NVARCHAR( 1), @dLottable14  DATETIME,
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),   @cFieldAttr15 NVARCHAR( 1), @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

-- Getting Mobile information
SELECT
   @nFunc            = [Func],
   @nScn             = [Scn],
   @nStep            = [Step],
   @nInputKey        = [InputKey],
   @nMenu            = [Menu],
   @cLangCode        = [Lang_code],

   @cFacility        = [Facility],
   @cStorerKey       = [StorerKey],
   @cUserName        = [UserName],

   @cMBOLKey         = [V_String1],
   @cPalletChoice    = [V_String2],
   @cPalletID        = [V_String3],
   @cSKU             = [V_String4],
   @cItemClass       = [V_String5],
   @cTemperature     = [V_String6],
   @cTemperatureMin  = [V_String7],
   @cTemperatureMax  = [V_String8],
   @cTemperatureUnit = [V_String9],
   @cTempCheckPoint  = [V_String10],

   @cInField01 = [I_Field01],   @cOutField01 = [O_Field01],  @cFieldAttr01 = [FieldAttr01],
   @cInField02 = [I_Field02],   @cOutField02 = [O_Field02],  @cFieldAttr02 = [FieldAttr02],
   @cInField03 = [I_Field03],   @cOutField03 = [O_Field03],  @cFieldAttr03 = [FieldAttr03],
   @cInField04 = [I_Field04],   @cOutField04 = [O_Field04],  @cFieldAttr04 = [FieldAttr04],
   @cInField05 = [I_Field05],   @cOutField05 = [O_Field05],  @cFieldAttr05 = [FieldAttr05],
   @cInField06 = [I_Field06],   @cOutField06 = [O_Field06],  @cFieldAttr06 = [FieldAttr06],
   @cInField07 = [I_Field07],   @cOutField07 = [O_Field07],  @cFieldAttr07 = [FieldAttr07],
   @cInField08 = [I_Field08],   @cOutField08 = [O_Field08],  @cFieldAttr08 = [FieldAttr08],
   @cInField09 = [I_Field09],   @cOutField09 = [O_Field09],  @cFieldAttr09 = [FieldAttr09],
   @cInField10 = [I_Field10],   @cOutField10 = [O_Field10],  @cFieldAttr10 = [FieldAttr10],
   @cInField11 = [I_Field11],   @cOutField11 = [O_Field11],  @cFieldAttr11 = [FieldAttr11],
   @cInField12 = [I_Field12],   @cOutField12 = [O_Field12],  @cFieldAttr12 = [FieldAttr12],
   @cInField13 = [I_Field13],   @cOutField13 = [O_Field13],  @cFieldAttr13 = [FieldAttr13],
   @cInField14 = [I_Field14],   @cOutField14 = [O_Field14],  @cFieldAttr14 = [FieldAttr14],
   @cInField15 = [I_Field15],   @cOutField15 = [O_Field15],  @cFieldAttr15 = [FieldAttr15]

FROM [RDT].[RDTMOBREC] WITH (NOLOCK)
WHERE [Mobile] = @nMobile

IF @nFunc = 1870 -- Outbound Pallet Temp Capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 1870
   IF @nStep = 1  GOTO Step_1  -- Scn = 6540. MBOL
   IF @nStep = 2  GOTO Step_2  -- Scn = 6541. Scan DropID/ID
   IF @nStep = 3  GOTO Step_3  -- Scn = 6542. Temperature Capture
   IF @nStep = 4  GOTO Step_4  -- Scn = 6543. Confirm Prompt
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1870. Menu
********************************************************************************/
Step_0:
BEGIN
     -- EventLog
   EXEC [RDT].[rdt_STD_EventLog]
      @cActionType = N'1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   SET @cPalletChoice = [RDT].[rdtGetConfig]( @nFunc, N'PalletChoice', @cStorerKey)
   IF @cPalletChoice NOT IN(N'DROPID' ,N'ID' ,N'BOTH') 
      SET @cPalletChoice = N'BOTH'

   -- Go to MBOL screen
   SET @cOutField01 = N''
   SET @nScn = 6540
   SET @nStep = 1
END
GOTO QUIT

/********************************************************************************
Step 1. Scn = 6540. MBOL
   MBOL    (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1
   BEGIN

      IF @cInField01 = N''
      BEGIN
         SET @nErrNo = 230151
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230151 - MBOL is needed
         GOTO Step_1_QUIT
      END

      SET @cMBOLKey = @cInField01

      IF NOT EXISTS( SELECT 1 FROM [dbo].[MBOL] WITH(NOLOCK) WHERE [MbolKey] = @cMBOLKey)
      BEGIN
         SET @nErrNo = 230152
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230152 - MBOL does not exist
         GOTO Step_1_QUIT
      END

      IF EXISTS( SELECT 1 FROM [dbo].[MBOL] WITH(NOLOCK) WHERE [MbolKey] = @cMBOLKey AND [Status] = N'9')
      BEGIN
         SET @nErrNo = 230153
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230153 - MBOL Shipped
         GOTO Step_1_QUIT
      END

      IF EXISTS( SELECT 1 FROM [dbo].[MBOL] WITH(NOLOCK) WHERE [MbolKey] = @cMBOLKey AND [Facility] <> @cFacility)
      BEGIN
         SET @nErrNo = 230154
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230154 - MBOL belongs to a different facility
         GOTO Step_1_QUIT
      END

      -- Prepare next screen var
      SET @cOutField01  = @cMBOLKey
      SET @cOutField02  = N''

      -- Go to next screen
      SET @nScn   = @nScn + 1
      SET @nStep  = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- EventLog
      EXEC [RDT].[rdt_STD_EventLog]
         @cActionType = N'9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
   END
   GOTO QUIT

   Step_1_QUIT:
   BEGIN
      SET @cOutField01 = ''
      EXEC [RDT].[rdtSetFocusField] @nMobile, 1
      GOTO QUIT
   END
END


/********************************************************************************
Scn = 6541. Scan DropID/ID
   MBOL        (field01)
   ID/DROPID   (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1
   BEGIN

      IF @cInField02 = N''
      BEGIN
         SET @nErrNo = 230155
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230155 - ID/DROPID is needed
         GOTO Step_2_QUIT
      END

      SET @cPalletID = @cInField02

      IF NOT EXISTS(
         SELECT 1
         FROM [dbo].[PickDetail] [PD] WITH(NOLOCK)
         WHERE [PD].[StorerKey] = @cStorerKey
            AND [PD].[Status] IN (N'3', N'5')
            AND ((@cPalletChoice IN (N'BOTH', N'ID') AND [PD].[ID] = @cPalletID) OR (@cPalletChoice IN (N'BOTH', N'DROPID') AND [PD].[DropID] = @cPalletID))
      )
      BEGIN
         SET @nErrNo = 230156
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230156 - Invalid ID
         GOTO Step_2_QUIT
      END

      IF NOT EXISTS(
         SELECT 1
         FROM [dbo].[PickDetail] [PD] WITH(NOLOCK)
            INNER JOIN [dbo].[ORDERS] [O] WITH(NOLOCK) ON [PD].[StorerKey] = [O].[StorerKey] AND [PD].[OrderKey] = [O].[OrderKey]
         WHERE [PD].[StorerKey] = @cStorerKey
            AND [PD].[Status] IN (N'3', N'5')
            AND ((@cPalletChoice IN (N'BOTH', N'ID') AND [PD].[ID] = @cPalletID) OR (@cPalletChoice IN (N'BOTH', N'DROPID') AND [PD].[DropID] = @cPalletID))
            AND [O].[MBOLKey] = @cMBOLKey
      )
      BEGIN
         SET @nErrNo = 230157
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230157 - ID does not belong to MBOL
         GOTO Step_2_QUIT
      END

      -- get sku
      SELECT TOP 1 @cSKU = [SKU]
      FROM [dbo].[PickDetail] [PD] WITH(NOLOCK)
      WHERE [PD].[StorerKey] = @cStorerKey
         AND [PD].[Status] IN (N'3', N'5')
         AND ((@cPalletChoice IN (N'BOTH', N'ID') AND [PD].[ID] = @cPalletID) OR (@cPalletChoice IN (N'BOTH', N'DROPID') AND [PD].[DropID] = @cPalletID))

      -- get Itemclass
      SELECT TOP 1 @cItemClass = [itemclass]
      FROM [dbo].[SKU] WITH(NOLOCK)
      WHERE [StorerKey] = @cStorerKey
         AND [Sku] = @cSKU

      -- validate code lookup config exists
      IF NOT EXISTS(SELECT 1 FROM [dbo].[CodeLKUP] WITH(NOLOCK) WHERE [StorerKey] = @cStorerKey AND [LISTNAME] = N'ITEMCLASS' AND [Code] = @cItemClass AND [UDF04] IN (N'BOTH', N'LDG'))
      BEGIN
         SET @nErrNo = 230158
         SET @cErrMsg = [RDT].[rdtGetMessageLong]( @nErrNo, @cLangCode, N'DSP')  -- Code List entry is missing for
         GOTO Step_2_QUIT
      END

      -- get code lookup config
      -- BOTH have higher priority
      SELECT TOP 1 
          @cTemperatureMin  = [UDF01]
         ,@cTemperatureMax  = [UDF02]
         ,@cTemperatureUnit = [UDF03]
         ,@cTempCheckPoint  = [UDF04]
      FROM [dbo].[CodeLKUP] WITH(NOLOCK) 
      WHERE [StorerKey] = @cStorerKey
         AND [LISTNAME] = N'ITEMCLASS'
         AND [Code]     = @cItemClass
         AND [UDF04]    = N'BOTH'
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1 
             @cTemperatureMin  = [UDF01]
            ,@cTemperatureMax  = [UDF02]
            ,@cTemperatureUnit = [UDF03]
            ,@cTempCheckPoint  = [UDF04]
         FROM [dbo].[CodeLKUP] WITH(NOLOCK) 
         WHERE [StorerKey] = @cStorerKey
            AND [LISTNAME] = N'ITEMCLASS'
            AND [Code]     = @cItemClass
            AND [UDF04]    = N'LDG'
      END

      IF ISNULL(@cTemperatureMin, N'') = N'' OR ISNULL(@cTemperatureMax, N'') = N'' OR ISNULL(@cTemperatureUnit, N'') = N''
      BEGIN
         SET @nErrNo = 230159
         SET @cErrMsg = [RDT].[rdtGetMessageLong]( @nErrNo, @cLangCode, N'DSP')  -- Item class code needs to be maintained properly
         GOTO Step_2_QUIT
      END

      IF TRY_CONVERT(DECIMAL(5,2), @cTemperatureMin) IS NULL
      BEGIN
         SET @nErrNo = 230160
         SET @cErrMsg = [RDT].[rdtGetMessageLong]( @nErrNo, @cLangCode, N'DSP')  -- Item class code needs to be maintained properly: UDF01
         GOTO Step_2_QUIT
      END

      IF TRY_CONVERT(DECIMAL(5,2), @cTemperatureMax) IS NULL
      BEGIN
         SET @nErrNo = 230161
         SET @cErrMsg = [RDT].[rdtGetMessageLong]( @nErrNo, @cLangCode, N'DSP')  -- Item class code needs to be maintained properly: UDF02
         GOTO Step_2_QUIT
      END

      -- Prepare next screen var
      SET @cOutField01  = @cMBOLKey
      SET @cOutField02  = @cPalletID
      SET @cOutField03  = N''
      SET @cOutField04  = CASE @cTemperatureUnit WHEN N'Celcius' THEN N'°C' WHEN N'Fahrenheit' THEN '°F' ELSE @cTemperatureUnit END

      -- Go to next screen
      SET @nScn   = @nScn + 1
      SET @nStep  = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = N''
      SET @cOutField02 = N''
      -- Go to prev screen
      SET @nScn   = @nScn - 1
      SET @nStep  = @nStep - 1
   END

   GOTO QUIT

   Step_2_QUIT:
   BEGIN
      SET @cOutField01  = @cMBOLKey
      SET @cOutField02  = N''
      SET @cOutField03  = N''
      EXEC [RDT].[rdtSetFocusField] @nMobile, 3
      GOTO QUIT
   END
END



/********************************************************************************
Scn = 6542. Temperature Capture
   MBOL        (field01)
   ID/DROPID   (field02)
   Temp        (field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN

      IF @cInField03 = N''
      BEGIN
         SET @nErrNo = 230163
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230163 - Temperature is needed
         GOTO Step_3_QUIT
      END

      SET @cTemperature = @cInField03
      SET @nTemperature = TRY_CONVERT(DECIMAL(5,2), @cTemperature)
      IF @nTemperature IS NULL
      BEGIN
         SET @nErrNo = 230164
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230164 - Invalid temperature
         GOTO Step_3_QUIT
      END

      SET @nTemperatureMin = TRY_CONVERT(DECIMAL(5,2), @cTemperatureMin)
      SET @nTemperatureMax = TRY_CONVERT(DECIMAL(5,2), @cTemperatureMax)
      IF @nTemperature < @nTemperatureMin OR @nTemperature > @nTemperatureMax
      BEGIN
         -- Prepare next screen var
         SET @cOutField03   = @cTemperature
         SET @cOutField04   = N''

         -- Go to next screen
         SET @nScn   = @nScn + 1
         SET @nStep  = @nStep + 1

         GOTO QUIT
      END

      -- Confirm
      EXEC [RDT].[rdt_Outbound_PalletTempCapture_Confirm] @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
            @cMBOLKey, @cPalletID, @cSKU, @cItemClass, @nTemperature,
            @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_QUIT

      -- Prepare prev screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = N''
      -- Go to prev screen
      SET @nScn   = @nScn - 1
      SET @nStep  = @nStep - 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = N''
      -- Go to prev screen
      SET @nScn   = @nScn - 1
      SET @nStep  = @nStep - 1
   END

   GOTO QUIT

   Step_3_QUIT:
   BEGIN
      SET @cOutField01  = @cMBOLKey
      SET @cOutField02  = @cPalletID
      SET @cOutField03  = N''
      SET @cOutField04  = CASE @cTemperatureUnit WHEN N'Celcius' THEN N'℃' WHEN N'Fahrenheit' THEN '℉' ELSE @cTemperatureUnit END
      GOTO QUIT
   END
END


/********************************************************************************
Scn = 6543. Confirm Prompt
   OPTION    (field04, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = @cInField04
      IF @cOption NOT IN (N'1', N'9')
      BEGIN
         SET @nErrNo = 230165
         SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230165 - Invalid Option
         GOTO Step_4_QUIT
      END

      IF @cOption = N'1'
      BEGIN

         SET @nTemperature = TRY_CONVERT(DECIMAL(5,2), @cTemperature)
         -- Confirm
         EXEC [RDT].[rdt_Outbound_PalletTempCapture_Confirm] @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cMBOLKey, @cPalletID, @cSKU, @cItemClass, @nTemperature,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Step_4_QUIT

         -- Prepare prev screen var
         SET @cOutField01  = @cMBOLKey
         SET @cOutField02  = N''
         SET @cOutField03  = N''
         SET @cOutField04  = N''

         -- Go to screen 2
         SET @nScn   = @nScn - 2
         SET @nStep  = @nStep - 2
      END

      IF @cOption = N'9'
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01  = @cMBOLKey
         SET @cOutField02  = @cPalletID
         SET @cOutField03  = N''
         SET @cOutField04  = CASE @cTemperatureUnit WHEN N'Celcius' THEN N'℃' WHEN N'Fahrenheit' THEN '℉' ELSE @cTemperatureUnit END

         -- Go to prev screen
         SET @nScn   = @nScn - 1
         SET @nStep  = @nStep - 1
      END
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01  = @cMBOLKey
      SET @cOutField02  = @cPalletID
      SET @cOutField03  = N''
      SET @cOutField04  = CASE @cTemperatureUnit WHEN N'Celcius' THEN N'℃' WHEN N'Fahrenheit' THEN '℉' ELSE @cTemperatureUnit END

      -- Go to prev screen
      SET @nScn   = @nScn - 1
      SET @nStep  = @nStep - 1
   END

   GOTO QUIT

   Step_4_QUIT:
   BEGIN
      SET @cOutField03  = @cTemperature
      SET @cOutFIeld04  = N''
      GOTO QUIT
   END
END

Quit:
BEGIN
   UPDATE [rdt].[RDTMOBREC] WITH (ROWLOCK) SET
      [EditDate]        = GETDATE(),
      [ErrMsg]          = @cErrMsg,
      [Func]            = @nFunc,
      [Step]            = @nStep,
      [Scn]             = @nScn,

      [V_String1]       = @cMBOLKey,
      [V_String2]       = @cPalletChoice,
      [V_String3]       = @cPalletID,
      [V_String4]       = @cSKU,
      [V_String5]       = @cItemClass,
      [V_String6]       = @cTemperature,
      [V_String7]       = @cTemperatureMin,
      [V_String8]       = @cTemperatureMax,
      [V_String9]       = @cTemperatureUnit,
      [V_String10]      = @cTempCheckPoint,

      [I_Field01] = @cInField01,  [O_Field01] = @cOutField01,   [FieldAttr01]  = @cFieldAttr01,
      [I_Field02] = @cInField02,  [O_Field02] = @cOutField02,   [FieldAttr02]  = @cFieldAttr02,
      [I_Field03] = @cInField03,  [O_Field03] = @cOutField03,   [FieldAttr03]  = @cFieldAttr03,
      [I_Field04] = @cInField04,  [O_Field04] = @cOutField04,   [FieldAttr04]  = @cFieldAttr04,
      [I_Field05] = @cInField05,  [O_Field05] = @cOutField05,   [FieldAttr05]  = @cFieldAttr05,
      [I_Field06] = @cInField06,  [O_Field06] = @cOutField06,   [FieldAttr06]  = @cFieldAttr06,
      [I_Field07] = @cInField07,  [O_Field07] = @cOutField07,   [FieldAttr07]  = @cFieldAttr07,
      [I_Field08] = @cInField08,  [O_Field08] = @cOutField08,   [FieldAttr08]  = @cFieldAttr08,
      [I_Field09] = @cInField09,  [O_Field09] = @cOutField09,   [FieldAttr09]  = @cFieldAttr09,
      [I_Field10] = @cInField10,  [O_Field10] = @cOutField10,   [FieldAttr10]  = @cFieldAttr10,
      [I_Field11] = @cInField11,  [O_Field11] = @cOutField11,   [FieldAttr11]  = @cFieldAttr11,
      [I_Field12] = @cInField12,  [O_Field12] = @cOutField12,   [FieldAttr12]  = @cFieldAttr12,
      [I_Field13] = @cInField13,  [O_Field13] = @cOutField13,   [FieldAttr13]  = @cFieldAttr13,
      [I_Field14] = @cInField14,  [O_Field14] = @cOutField14,   [FieldAttr14]  = @cFieldAttr14,
      [I_Field15] = @cInField15,  [O_Field15] = @cOutField15,   [FieldAttr15]  = @cFieldAttr15
   WHERE [Mobile] = @nMobile
END

GO