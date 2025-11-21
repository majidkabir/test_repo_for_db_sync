SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PalletInquiry                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pallet Inquiry                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2022-09-20   1.0  James    WMS-20742. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PalletInquiry] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nAfterStep  INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,
   @nMorePage   INT,
   @bSuccess    INT,
   @nTranCount  INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cSKU        NVARCHAR( 20),
   @cUserName           NVARCHAR( 18),
   @cOrderKey           NVARCHAR( 10),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @tExtValidVar        VariableTable,
   @tExtUpdateVar       VariableTable,
   @tExtInfoVar         VariableTable,
   @tPalletInq          VariableTable,
   @tGetNextCarton      VariableTable,
   
   @cPalletKey          NVARCHAR( 20),
   @cMBOLKey            NVARCHAR( 10),
   @cOption             NVARCHAR( 1),
   @cStatus             NVARCHAR( 10),
   @cCaseId             NVARCHAR( 20),
   @cCartonId           NVARCHAR( 20),
   @cCartonId01         NVARCHAR( 20),
   @cCartonId02         NVARCHAR( 20),
   @cCartonId03         NVARCHAR( 20),
   @cCartonId04         NVARCHAR( 20),
   @cCartonId05         NVARCHAR( 20),
   @cCartonId06         NVARCHAR( 20),
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),
   @cUserWhoLockedOrd   NVARCHAR( 15),
   @nIsScanPalletKey    INT = 0,
   @nIsScanOrderKey     INT = 0,
   @nIsCartonId         INT = 0,
   @nIsTrackingNo       INT = 0,
   @nFromStep           INT,
   @nFromScn            INT,
   @cOPSPosition        NVARCHAR( 60),
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cOrderKey   = V_OrderKey,
   @cCartonId   = V_CaseID, 
   
   @nFromStep   = V_FromStep,
   @nFromScn    = V_FromScn,
   
   @nIsScanPalletKey = V_Integer1,
   @nIsScanOrderKey  = V_Integer2,
   
   @cMBOLKey               = V_String1,
   @cPalletKey             = V_String2,
   @cExtendedInfoSP        = V_String3,
   @cExtendedValidateSP    = V_String4,
   @cExtendedUpdateSP      = V_String5,
   @cCartonId01 =  V_String6,
   @cCartonId02 =  V_String7,
   @cCartonId03 =  V_String8,
   @cCartonId04 =  V_String9,
   @cCartonId05 =  V_String10,
   @cCartonId06 =  V_String11,
   
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_PalletOrder         INT,  @nScn_PalletOrder          INT,
   @nStep_AllCartonId         INT,  @nScn_AllCartonId          INT,
   @nStep_OptionRemoveAll     INT,  @nScn_OptionRemoveAll      INT,
   @nStep_CartonId            INT,  @nScn_CartonId             INT,
   @nStep_Option              INT,  @nScn_Option               INT,
   @nStep_Message             INT,  @nScn_Message              INT

SELECT
   @nStep_PalletOrder         = 1,   @nScn_PalletOrder         = 6150,
   @nStep_AllCartonId         = 2,   @nScn_AllCartonId         = 6151,
   @nStep_OptionRemoveAll     = 3,   @nScn_OptionRemoveAll     = 6152,
   @nStep_CartonId            = 4,   @nScn_CartonId            = 6153,
   @nStep_Option              = 5,   @nScn_Option              = 6154,
   @nStep_Message             = 6,   @nScn_Message             = 6155


IF @nFunc = 1667 -- TrackNo Sort To Pallet Close Lane
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0
   IF @nStep = 1 GOTO Step_PalletOrder       -- Scn = 6150. PALLET/ORDER
   IF @nStep = 2 GOTO Step_AllCartonId       -- Scn = 6151. CARTON ID
   IF @nStep = 3 GOTO Step_OptionRemoveAll   -- Scn = 6152. OPTION
   IF @nStep = 4 GOTO Step_CartonId          -- Scn = 6153. CARTON ID
   IF @nStep = 5 GOTO Step_Option            -- Scn = 6154. OPTION
   IF @nStep = 6 GOTO Step_Message           -- Scn = 6155. MESSAGE
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1667. Menu
********************************************************************************/
Step_0:
BEGIN
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''

   -- Initialize value
   SET @cPalletKey = ''
   SET @cOrderKey = ''
   SET @cOption = ''
   
   -- Prep next screen var
   SET @cOutField01 = '' -- PalletKey
   SET @cOutField02 = '' -- OrderKey

   SET @nScn = @nScn_PalletOrder
   SET @nStep = @nStep_PalletOrder

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6150
   PALLETKEY    (field01, input)
   ORDERKEY     (field02, input)
********************************************************************************/
Step_PalletOrder:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cPalletKey = @cInField01
      SET @cOrderKey = @cInField02

      IF ISNULL( @cPalletKey, '') = '' AND ISNULL( @cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 191701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value
         GOTO Step_Pallet_Fail
      END

      IF ISNULL( @cPalletKey, '') <> '' AND ISNULL( @cOrderKey, '') <> ''
      BEGIN
         SET @nErrNo = 191702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ether 1 Value
         GOTO Step_Pallet_Fail
      END

      SET @nIsScanPalletKey = 0
      IF ISNULL( @cPalletKey, '') <> ''
      BEGIN
      	IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail (NOLOCK)
      	                WHERE StorerKey = @cStorerKey
      	                AND   PalletKey = @cPalletKey)
         BEGIN 
            SET @nErrNo = 191703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv PalletKey
            GOTO Step_Pallet_Fail
         END 
         
         IF EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                     WHERE ExternMbolKey = @cPalletKey
                     AND   STATUS = '9') 
         BEGIN 
            SET @nErrNo = 191704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
            GOTO Step_Pallet_Fail
         END
         
         SET @nIsScanPalletKey = 1
      END
      
      IF ISNULL( @cOrderKey, '') <> ''
      BEGIN
         SET @cUserWhoLockedOrd = ''

         -- Check orderkey in use                  
         SELECT @cUserWhoLockedOrd = UserName 
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile <> @nMobile
         AND   Func = @nFunc 
         AND   @cOrderKey = V_OrderKey

         IF ISNULL( @cUserWhoLockedOrd, '') <> ''
         BEGIN
            SET @nErrNo = 191705
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdersInUse
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''

            IF rdt.RDTGetConfig( @nFunc, 'ShowOrdersInUseWithUserName', @cStorerKey) = '1'
            BEGIN
               SET @cErrMsg1 = SUBSTRING( @cErrMsg, 7, 14)
               SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 191706, @cLangCode, 'DSP'), 7, 14) --Locked By
               SET @cErrMsg3 = @cUserWhoLockedOrd
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
               END   
            END

            GOTO Quit
         END
      
         SELECT @cStatus = STATUS
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF @cStatus = '9'
         BEGIN 
            SET @nErrNo = 191707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Shipped
            GOTO Step_Order_Fail
         END

         SELECT TOP 1 @cPalletKey = PalletKey
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cOrderKey
         ORDER BY 1
         
         IF ISNULL( @cPalletKey, '') = ''
         BEGIN 
            SET @nErrNo = 191708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ord Found
            GOTO Step_Order_Fail
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                     WHERE ExternMbolKey = @cPalletKey
                     AND   STATUS = '9') 
          BEGIN 
            SET @nErrNo = 191709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
            GOTO Step_Order_Fail
          END
          
          SET @nIsScanOrderKey = 1
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @nIsScanPalletKey = 1 -- PalletKey
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = ''   -- CartonId
         
         -- Goto carton Id screen
         SET @nScn  = @nScn_AllCartonId
         SET @nStep = @nStep_AllCartonId
      END
      ELSE  -- OrderKey
      BEGIN
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PalletInquiry_GetNextCarton]
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cOrderKey     = @cOrderKey,
            @cCartonId     = @cCartonId,
            @cOption       = @cOption,
            @cPalletKey    = @cPalletKey  OUTPUT,
            @cCartonId01   = @cCartonId01 OUTPUT,
            @cCartonId02   = @cCartonId02 OUTPUT,
            @cCartonId03   = @cCartonId03 OUTPUT,
            @cCartonId04   = @cCartonId04 OUTPUT,
            @cCartonId05   = @cCartonId05 OUTPUT,
            @cCartonId06   = @cCartonId06 OUTPUT,
            @tGetNextCarton= @tGetNextCarton,
            @nErrNo        = @nErrNo      OUTPUT,
            @cErrMsg       = @cErrMsg     OUTPUT

         -- Prep next screen var
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = @cPalletKey
         SET @cOutField03 = @cCartonId01
         SET @cOutField04 = @cCartonId02
         SET @cOutField05 = @cCartonId03
         SET @cOutField06 = @cCartonId04
         SET @cOutField07 = @cCartonId05
         SET @cOutField08 = @cCartonId06
         SET @cOutField09 = ''   -- Carton Id/Tracking No
          
         -- Goto scan pallet screen
         SET @nScn  = @nScn_CartonId
         SET @nStep = @nStep_CartonId
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_Pallet_Fail:
   BEGIN
      SET @cPalletKey = ''
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1        
   END
   GOTO Quit
   
   Step_Order_Fail:
   BEGIN
      SET @cOrderKey = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2        
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 6151.
   PALLETKEY           (field01)
   CARTON ID           (field02, input)
********************************************************************************/
Step_AllCartonId:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cCartonId = @cInField02

      IF ISNULL( @cCartonId, '') = ''
      BEGIN
         SELECT @cOPSPosition = OPSPosition
         FROM rdt.RDTUser WITH (NOLOCK)
         WHERE UserName = @cUserName
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                         WHERE LISTNAME = 'SUPRUSR'
                         AND   Code = @cOPSPosition
                         AND   Storerkey = @cStorerKey)
         BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 191710, @cLangCode, 'DSP') --This user not allow
               SET @cErrMsg2 = rdt.rdtgetmessage( 191711, @cLangCode, 'DSP') --To remove all carton
               SET @cErrMsg3 = rdt.rdtgetmessage( 191712, @cLangCode, 'DSP') --From pallet
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
               END   

            SET @nErrNo = 191710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --This user not allow
            GOTO Step_AllCartonId_Fail
         END
         
         -- Prep next screen var
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn_OptionRemoveAll
         SET @nStep = @nStep_OptionRemoveAll

         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   PalletKey = @cPalletKey
                      AND   CaseId = @cCartonId)
      BEGIN
         SET @nErrNo = 191713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Carton Id
         GOTO Step_AllCartonId_Fail
      END

      SELECT @cOrderKey = UserDefine01
      FROM dbo.PALLETDETAIL WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PalletKey = @cPalletKey
      AND   CaseId = @cCartonId
      
      -- Check if order is shipped
      IF EXISTS ( SELECT 1 
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
                  JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PH.OrderKey AND O.StorerKey = PH.StorerKey) 
                  WHERE PD.LabelNo = @cCartonId
                  AND   PH.StorerKey = @cStorerKey
                  AND   O.OrderKey = @cOrderKey
                  AND   O.Status = '9')
      BEGIN 
         SET @nErrNo = 191714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn is Shipped
         GOTO Step_AllCartonId_Fail
      END


      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nFromStep = @nStep_AllCartonId
      SET @nFromScn = @nScn_AllCartonId

      SET @cOutField01 = @cCartonId
      SET @cOutField02 = @cPalletKey
      SET @cOutField03 = ''            -- Option

      SET @nScn = @nScn_Option
      SET @nStep = @nStep_Option
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cPalletKey = ''
      SET @cOrderKey = ''
      SET @cOption = ''
   
      -- Prep next screen var
      SET @cOutField01 = '' -- PalletKey
      SET @cOutField02 = '' -- OrderKey

      EXEC rdt.rdtSetFocusField @nMobile, 1  
      
      SET @nScn = @nScn_PalletOrder
      SET @nStep = @nStep_PalletOrder
   END

   GOTO Quit

   Step_AllCartonId_Fail:
   BEGIN
      SET @cCartonId = ''
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6152.
   OPTION         field01, input)
********************************************************************************/
Step_OptionRemoveAll:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cOption = @cInField01

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 191715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_OptionAll_Fail
      END

      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 191716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_OptionAll_Fail
      END

      IF @cOption = '2'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = ''   -- CartonId
         
         -- Goto carton Id screen
         SET @nScn  = @nScn_AllCartonId
         SET @nStep = @nStep_AllCartonId
         
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_RemoveAllCarton -- For rollback or commit only our own transaction
      
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PalletInquiry_RemoveCarton]
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cPalletKey    = @cPalletKey,
         @cOrderKey     = @cOrderKey,
         @cCartonId     = @cCartonId,
         @cOption       = @cOption,
         @cType         = 'ALL',
         @tPalletInq    = @tPalletInq,
         @nErrNo        = @nErrNo      OUTPUT,
         @cErrMsg       = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran_AllCarton

      -- Extended Update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtUpdateVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdateVar  VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtUpdateVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_AllCarton
         END
      END

      COMMIT TRAN rdt_RemoveAllCarton

      GOTO Quit_RemoveAllCarton

      RollBackTran_AllCarton:
         ROLLBACK TRAN rdt_RemoveAllCarton    -- Only rollback change made here
      Quit_RemoveAllCarton:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit
                  
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = ''   -- CartonId
         
      -- Goto carton Id screen
      SET @nScn  = @nScn_AllCartonId
      SET @nStep = @nStep_AllCartonId
   END

   GOTO Quit

   Step_OptionAll_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 6153.
   PALLETKEY               (field01)
   CARTON ID/TRACKING NO   (field02, input)
********************************************************************************/
Step_CartonId:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cCartonId = @cInField09

      IF ISNULL( @cCartonId, '') = ''
      BEGIN
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PalletInquiry_GetNextCarton]
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cOrderKey     = @cOrderKey,
            @cCartonId     = @cCartonId,
            @cOption       = @cOption,
            @cPalletKey    = @cPalletKey  OUTPUT,
            @cCartonId01   = @cCartonId01 OUTPUT,
            @cCartonId02   = @cCartonId02 OUTPUT,
            @cCartonId03   = @cCartonId03 OUTPUT,
            @cCartonId04   = @cCartonId04 OUTPUT,
            @cCartonId05   = @cCartonId05 OUTPUT,
            @cCartonId06   = @cCartonId06 OUTPUT,
            @tGetNextCarton= @tGetNextCarton,
            @nErrNo        = @nErrNo      OUTPUT,
            @cErrMsg       = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
            
         -- Prep next screen var
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = @cPalletKey
         SET @cOutField03 = @cCartonId01
         SET @cOutField04 = @cCartonId02
         SET @cOutField05 = @cCartonId03
         SET @cOutField06 = @cCartonId04
         SET @cOutField07 = @cCartonId05
         SET @cOutField08 = @cCartonId06
         SET @cOutField09 = ''   -- Carton Id/Tracking No
          
         -- Remain current screen
         SET @nScn  = @nScn_CartonId
         SET @nStep = @nStep_CartonId
         
         GOTO Quit
      END

      -- Check if the carton/tracking no is valid
      IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   PalletKey = @cPalletKey
                      AND   CaseId = @cInField09)   -- user scan carton id
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cPalletKey
                         AND   UserDefine02 = @cInField09)   -- User scan tracking no
         BEGIN
            SET @nErrNo = 191717
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Carton Id
            GOTO Step_CartonId_Fail
         END
         ELSE
         	SET @nIsTrackingNo = 1
      END
      ELSE
      	SET @nIsCartonId = 1
      
      -- Check if this carton/tracking no belong to the orderkey scanned
      IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   PalletKey = @cPalletKey
                      AND   UserDefine01 = @cOrderKey
                      AND   ((@nIsCartonId = 1 AND CaseId = @cCartonId) OR 
                             (@nIsTrackingNo = 1 AND UserDefine02 = @cCartonId)))
      BEGIN
         SET @nErrNo = 191718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn Not In Ord
         GOTO Step_CartonId_Fail
      END
      
      -- Get real carton id from tracking no scan
      IF @nIsTrackingNo = 1
      BEGIN
         SELECT @cCartonId = CaseId
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cPalletKey
         AND   UserDefine01 = @cOrderKey
         AND   UserDefine02 = @cInField09
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nFromStep = @nStep_CartonId
      SET @nFromScn = @nScn_CartonId
      
      -- Prep next screen var
      SET @cOutField01 = @cCartonId
      SET @cOutField02 = @cPalletKey
      SET @cOutField03 = ''

      SET @nScn = @nScn_Option
      SET @nStep = @nStep_Option
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cPalletKey = ''
      SET @cOrderKey = ''
      SET @cOption = ''
   
      -- Prep next screen var
      SET @cOutField01 = '' -- PalletKey
      SET @cOutField02 = '' -- OrderKey

      EXEC rdt.rdtSetFocusField @nMobile, 2  
      
      SET @nScn = @nScn_PalletOrder
      SET @nStep = @nStep_PalletOrder
   END

   GOTO Quit

   Step_CartonId_Fail:
   BEGIN
      SET @cCartonId = ''
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cPalletKey
      SET @cOutField03 = @cCartonId01
      SET @cOutField04 = @cCartonId02
      SET @cOutField05 = @cCartonId03
      SET @cOutField06 = @cCartonId04
      SET @cOutField07 = @cCartonId05
      SET @cOutField08 = @cCartonId06
      SET @cOutField09 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6152.
   OPTION         field01, input)
********************************************************************************/
Step_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cOption = @cInField03

      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 191719
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_Option_Fail
      END

      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 191720
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_Option_Fail
      END

      IF @cOption = '2'
      BEGIN
      	IF @nFromScn = @nScn_AllCartonId
      	BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cPalletKey
            SET @cOutField02 = ''   -- CartonId
         
            -- Goto carton Id screen
            SET @nScn  = @nScn_AllCartonId
            SET @nStep = @nStep_AllCartonId
      	END
      	ELSE
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cOrderKey
            SET @cOutField02 = @cPalletKey
            SET @cOutField03 = @cCartonId01
            SET @cOutField04 = @cCartonId02
            SET @cOutField05 = @cCartonId03
            SET @cOutField06 = @cCartonId04
            SET @cOutField07 = @cCartonId05
            SET @cOutField08 = @cCartonId06
            SET @cOutField09 = ''   -- Carton Id/Tracking No
          
            -- Goto scan pallet screen
            SET @nScn  = @nScn_CartonId
            SET @nStep = @nStep_CartonId
         END         

         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_RemoveCarton -- For rollback or commit only our own transaction
      
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PalletInquiry_RemoveCarton]
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cPalletKey    = @cPalletKey,
         @cOrderKey     = @cOrderKey,
         @cCartonId     = @cCartonId,
         @cOption       = @cOption,
         @cType         = '',
         @tPalletInq    = @tPalletInq,
         @nErrNo        = @nErrNo      OUTPUT,
         @cErrMsg       = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran_Carton

      -- Extended Update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtUpdateVar, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletKey     NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdateVar     VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cOrderKey, @cCartonId, @cOption, @tExtUpdateVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_Carton
         END
      END

      COMMIT TRAN rdt_RemoveCarton

      GOTO Quit_RemoveCarton

      RollBackTran_Carton:
         ROLLBACK TRAN rdt_RemoveCarton    -- Only rollback change made here
      Quit_RemoveCarton:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Quit
                  
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     	IF @nFromScn = @nScn_AllCartonId
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = ''   -- CartonId
         
         -- Goto carton Id screen
         SET @nScn  = @nScn_AllCartonId
         SET @nStep = @nStep_AllCartonId
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = @cPalletKey
         SET @cOutField03 = @cCartonId01
         SET @cOutField04 = @cCartonId02
         SET @cOutField05 = @cCartonId03
         SET @cOutField06 = @cCartonId04
         SET @cOutField07 = @cCartonId05
         SET @cOutField08 = @cCartonId06
         SET @cOutField09 = ''   -- Carton Id/Tracking No
          
         -- Goto scan pallet screen
         SET @nScn  = @nScn_CartonId
         SET @nStep = @nStep_CartonId
      END         
   END

   GOTO Quit

   Step_Option_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = @cCartonId
      SET @cOutField02 = @cPalletKey
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 6155
   MESSAGE
********************************************************************************/
Step_Message:
BEGIN
   IF @nInputKey IN (0, 1) -- ENTER or ESC
   BEGIN
   	IF @nFromStep = @nStep_CartonId
   	BEGIN
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PalletInquiry_GetNextCarton]
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cOrderKey     = @cOrderKey,
            @cCartonId     = @cCartonId,
            @cOption       = @cOption,
            @cPalletKey    = @cPalletKey  OUTPUT,
            @cCartonId01   = @cCartonId01 OUTPUT,
            @cCartonId02   = @cCartonId02 OUTPUT,
            @cCartonId03   = @cCartonId03 OUTPUT,
            @cCartonId04   = @cCartonId04 OUTPUT,
            @cCartonId05   = @cCartonId05 OUTPUT,
            @cCartonId06   = @cCartonId06 OUTPUT,
            @tGetNextCarton= @tGetNextCarton,
            @nErrNo        = @nErrNo      OUTPUT,
            @cErrMsg       = @cErrMsg     OUTPUT

         -- Prep next screen var
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = @cPalletKey
         SET @cOutField03 = @cCartonId01
         SET @cOutField04 = @cCartonId02
         SET @cOutField05 = @cCartonId03
         SET @cOutField06 = @cCartonId04
         SET @cOutField07 = @cCartonId05
         SET @cOutField08 = @cCartonId06
         SET @cOutField09 = ''   -- Carton Id/Tracking No
          
         -- Goto scan pallet screen
         SET @nScn  = @nScn_CartonId
         SET @nStep = @nStep_CartonId
   	END
   	ELSE
      BEGIN
   	   IF @nIsScanPalletKey = 1
            EXEC rdt.rdtSetFocusField @nMobile, 1
         ELSE
      	   EXEC rdt.rdtSetFocusField @nMobile, 2

         -- Initialize value
         SET @cPalletKey = ''
         SET @cOrderKey = ''
         SET @cOption = ''
   
         -- Prep next screen var
         SET @cOutField01 = '' -- PalletKey
         SET @cOutField02 = '' -- OrderKey

         SET @nScn = @nScn_PalletOrder
         SET @nStep = @nStep_PalletOrder
      END
      
      GOTO Quit
   END
END

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      UserName  = @cUserName,
      V_OrderKey= @cOrderKey,
      V_CaseID  = @cCartonId,

      V_FromStep  = @nFromStep,
      V_FromScn   = @nFromScn, 

      V_Integer1  = @nIsScanPalletKey,
      V_Integer2  = @nIsScanOrderKey,
   
      V_String1   = @cMBOLKey,
      V_String2   = @cPalletKey,
      
      V_String3 = @cExtendedInfoSP,
      V_String4 = @cExtendedValidateSP,
      V_String5 = @cExtendedUpdateSP,
      V_String6 = @cCartonId01,
      V_String7 = @cCartonId02,
      V_String8 = @cCartonId03,
      V_String9 = @cCartonId04,
      V_String10 = @cCartonId05,
      V_String11 = @cCartonId06,
       
      I_Field01 = @cInField01,  O_Field01 = @cOutField01, FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02, FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03, FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04, FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05, FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06, FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07, FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08, FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09, FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10, FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11, FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12, FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13, FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14, FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15, FieldAttr15  = @cFieldAttr15
   WHERE Mobile = @nMobile
END

GO