SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_CartonToMBOL                                    */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Scan carton to populate orders into MBOL, MBOLDetail           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-03-30   1.0  Ung      WMS-22181 Created                            */
/* 2023-06-07   1.1  Ung      WMS-22678 Add capture PackInfo               */
/*                            Add StorerGroup                              */
/*                            Add key-in MBOL                              */
/*                            Add rdtCartonToMBOLLog                       */
/*                            Add CloseMBOL                                */
/*                            Add RefNo                                    */
/*                            Add TrackCartonType                          */
/* 2024-10-25   1.2  PXL009   FCR-759 ID and UCC Length Issue              */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_CartonToMBOL] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)  
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @cSQL           NVARCHAR(MAX),
   @cSQLParam      NVARCHAR(MAX),
   @tCaptureVar    VariableTable,
   @tExtValVar     VariableTable,
   @tExtUpdVar     VariableTable,
   @tConfirmVar    VariableTable,
   @tExtInfoVar    VariableTable, 
   @cOption        NVARCHAR( 2),
   @nTranCount     INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerGroup   NVARCHAR( 20),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),

   @cPickSlipNo         NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),

   @cMBOLKey            NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cCartonID           NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cPackInfoRefNo      NVARCHAR( 20),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cLength             NVARCHAR( 10),
   @cWidth              NVARCHAR( 10),
   @cHeight             NVARCHAR( 10),
   
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cCaptureInfoSP      NVARCHAR( 20),
   @cCartonIDSP         NVARCHAR( 20),
   @cAutoGenMBOL        NVARCHAR( 1),
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 10),
   @cDefaultCartonType  NVARCHAR( 10),
   @cDefaultWeight      NVARCHAR( 1),
   @cAllowWeightZero    NVARCHAR( 1),
   @cAllowCubeZero      NVARCHAR( 1),
   @cAllowLengthZero    NVARCHAR( 1),
   @cAllowWidthZero     NVARCHAR( 1),
   @cAllowHeightZero    NVARCHAR( 1),
   @cCloseMBOL          NVARCHAR( 1),
   @cTrackCartonType    NVARCHAR( 1),
   @cBarcode            NVARCHAR( 60),
   @cDecodeSP           NVARCHAR( 20),

   @cData1              NVARCHAR( 60),
   @cData2              NVARCHAR( 60),
   @cData3              NVARCHAR( 60),
   @cData4              NVARCHAR( 60),
   @cData5              NVARCHAR( 60),

   @nCartonNo           INT,
   @nTotalCarton        INT,
   @nUseSequence        INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup,
   -- @cStorerKey       = StorerKey,
   @cFacility        = Facility,

   @cStorerKey          = V_StorerKey,
   @cOrderKey           = V_OrderKey,
   @cSKU                = V_SKU, 
   @cPickSlipNo         = V_PickSlipNo, 
   @nCartonNo           = V_CartonNo, 
      
   @cMBOLKey            = V_String1,
   @cRefNo              = V_String2,
   @cCartonID           = V_String3,
   @cCartonType         = V_String4,
   @cCube               = V_String6,
   @cWeight             = V_String7,
   @cPackInfoRefNo      = V_String8,
   @cLength             = V_String9, 
   @cWidth              = V_String10, 
   @cHeight             = V_String11, 

   @cExtendedUpdateSP   = V_String21,
   @cExtendedValidateSP = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cCaptureInfoSP      = V_String25,
   @cCartonIDSP         = V_String26,
   @cAutoGenMBOL        = V_String27,
   @cCapturePackInfoSP  = V_String28,
   @cPackInfo           = V_String29,
   @cDefaultCartonType  = V_String30,
   @cDefaultWeight      = V_String31,
   @cAllowWeightZero    = V_String32,
   @cAllowCubeZero      = V_String33,
   @cAllowLengthZero    = V_String34,
   @cAllowWidthZero     = V_String35,
   @cAllowHeightZero    = V_String36,
   @cCloseMBOL          = V_String37,
   @cTrackCartonType    = V_String38,
   @cDecodeSP           = V_String39,

   @cData1              = V_String41,
   @cData2              = V_String42,
   @cData3              = V_String43,
   @cData4              = V_String44,
   @cData5              = V_String45,

   @nCartonNo           = V_CartonNo,
   @nTotalCarton        = V_Integer1,
   @nUseSequence        = V_Integer2, 

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_MBOL          INT,  @nScn_MBOL           INT,
   @nStep_Carton        INT,  @nScn_Carton         INT,
   @nStep_CloseMBOL     INT,  @nScn_CloseMBOL      INT,
   @nStep_CaptureData   INT,  @nScn_CaptureData    INT,
   @nStep_PackInfo      INT,  @nScn_PackInfo       INT

SELECT
   @nStep_MBOL          = 1,  @nScn_MBOL          = 6240,
   @nStep_CaptureData   = 2,  @nScn_CaptureData   = 6241, 
   @nStep_Carton        = 3,  @nScn_Carton        = 6242,
   @nStep_CloseMBOL     = 4,  @nScn_CloseMBOL     = 6243, 
   @nStep_PackInfo      = 5,  @nScn_PackInfo      = 6244

IF @nFunc = 1863
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 1863
   IF @nStep = 1  GOTO Step_MBOL          -- Scn = 6240. MBOL
   IF @nStep = 2  GOTO Step_CaptureData   -- Scn = 6241. Capture data
   IF @nStep = 3  GOTO Step_Carton        -- Scn = 6242. Carton ID
   IF @nStep = 4  GOTO Step_CloseMBOL     -- Scn = 6243. Close MBOL?
   IF @nStep = 5  GOTO Step_PackInfo      -- Scn = 6244. CartonType, Weight, Cube, PackInfoRefNo, Length, Weight, Height
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 1863
********************************************************************************/
Step_Start:
BEGIN
   -- NOTE: this module support StorerGroup
   IF @cStorerGroup <> '' AND @cStorerKey = ''
      SELECT @cStorerKey = StorerKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   
   -- Get storer config (all store config is retrieved after getting carton ID, except the below one which need to use immediately)
   SET @cAutoGenMBOL =  rdt.rdtGetConfig( @nFunc, 'AutoGenMBOL', @cStorerKey)

   SET @cCaptureInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureInfoSP', @cStorerKey)
   IF @cCaptureInfoSP = '0'
      SET @cCaptureInfoSP = ''
   SET @cCartonIDSP = rdt.RDTGetConfig( @nFunc, 'CartonIDSP', @cStorerKey)
   IF @cCartonIDSP = '0'
      SET @cCartonIDSP = ''
   IF @cCartonIDSP = ''
      SET @cCartonIDSP = 'L' -- L=LabenNo
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- MBOL

   -- Go to next screen
   SET @nScn = @nScn_MBOL
   SET @nStep = @nStep_MBOL
END
GOTO Quit


/************************************************************************************
Step 1. Scn = 6240. Scan MBOL
   MBOL  (field01, input)
************************************************************************************/
Step_MBOL:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = @cInField01
      SET @cRefNo  = @cInField02
      
      -- RefNo lookup
      IF @cRefNo <> '' AND @cMBOLKey = ''
      BEGIN
         EXEC rdt.rdt_CartonToMBOL_RefNoLookup
             @nMobile      = @nMobile
            ,@nFunc        = @nFunc
            ,@cLangCode    = @cLangCode
            ,@nStep        = @nStep
            ,@nInputKey    = @nInputKey
            ,@cFacility    = @cFacility
            ,@cStorerKey   = @cStorerKey
            ,@cStorerGroup = @cStorerGroup
            ,@cRefNo       = @cRefNo   OUTPUT
            ,@cMBOLKey     = @cMBOLKey OUTPUT
            ,@nErrNo       = @nErrNo   OUTPUT
            ,@cErrMsg      = @cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- Check blank
      IF @cMBOLKey = ''
      BEGIN
         IF @cAutoGenMBOL = '1'
         BEGIN
            DECLARE @nSuccess INT = 1
            EXECUTE dbo.nspg_getkey
               'MBOL'
               , 10
               , @cMBOLKey    OUTPUT
               , @nSuccess    OUTPUT
               , @nErrNo      OUTPUT
               , @cErrMsg     OUTPUT
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 198851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            END
            
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdtfnc_CartonToMBOL -- For rollback or commit only our own transaction
            
            -- MBOL
            INSERT INTO dbo.MBOL (MBOLKey, ExternMBOLKey, Facility, Status) 
            VALUES (@cMBOLKey, @cMBOLKey, @cFacility, '0')
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_CartonToMBOL -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 
                  
               SET @nErrNo = 198853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail
               GOTO Step_MBOL_Fail
            END
          
            COMMIT TRAN rdtfnc_CartonToMBOL
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN 
         END
         ELSE
         BEGIN
            SET @nErrNo = 198855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need MBOL
            GOTO Step_MBOL_Fail
         END
      END

      -- Scanned MBOL
      ELSE
      BEGIN
         -- Get MBOL info
         DECLARE @cChkFacility NVARCHAR( 5)
         DECLARE @cChkStatus NVARCHAR( 10)
         SELECT 
            @cChkFacility = Facility, 
            @cChkStatus = Status
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey
      
         -- Check MBOL valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 198856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MBOL
            GOTO Step_MBOL_Fail
         END
         
         -- Check facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 198857
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
            GOTO Step_MBOL_Fail
         END

         -- Check facility
         IF @cChkStatus >= '5'
         BEGIN
            SET @nErrNo = 198858
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL closed
            GOTO Step_MBOL_Fail
         END
      END

      -- Capture info
      IF @cCaptureInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_CartonToMBOL_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',
            @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cData1, @cData2, @cData3, @cData4, @cData5, 
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
            @tCaptureVar,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to next screen
         SET @nScn = @nScn_CaptureData
         SET @nStep = @nStep_CaptureData

         GOTO Quit
      END
      
      -- Get stat
      SELECT @nTotalCarton = COUNT(1)
      FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey

      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ''
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn_Carton
      SET @nStep = @nStep_Carton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_MBOL_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

   GOTO Quit
END
GOTO Quit


/***********************************************************************************
Step 2. Scn = 6241. Capture data screen
   Data1    (field01)
   Input1   (field02, input)
   .
   .
   .
   Data5    (field09)
   Input5   (field10, input)
***********************************************************************************/
Step_CaptureData:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cData4 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cData5 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      EXEC rdt.rdt_CartonToMBOL_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',
         @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cData1, @cData2, @cData3, @cData4, @cData5, 
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
         @tCaptureVar,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Get stat
      SELECT @nTotalCarton = COUNT(1)
      FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
      
      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ''
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn_Carton
      SET @nStep = @nStep_Carton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- @cMBOLKey

      -- Go to next screen
      SET @nScn = @nScn_MBOL
      SET @nStep = @nStep_MBOL
   END
END
GOTO Quit


/***********************************************************************************
Step 3. Scn = 6242. Carton ID screen
   MBOLKey     (field01)
   CARTON ID   (field02, input)
   SCANNED     (field03)
***********************************************************************************/
Step_Carton:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonID = @cInField02
      SET @cBarcode = @cInField02

      -- Check blank
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 198859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton ID
         GOTO Step_Carton_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo  = @cCartonID      OUTPUT,
               @nErrNo  = @nErrNo         OUTPUT,
               @cErrMsg = @cErrMsg        OUTPUT,
               @cType   = 'UCCNo'

               IF @nErrNo <> 0
                  GOTO Step_Carton_Fail
         END
      END

      -- Check format
      IF @cStorerGroup = ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0  
         BEGIN  
            SET @nErrNo = 198860  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonID  
            GOTO Quit  
         END
      END

      -- Check carton ID scanned
      IF EXISTS( SELECT 1 FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CartonID = @cCartonID)
      BEGIN
         SET @nErrNo = 198861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton Scanned
         GOTO Step_Carton_Fail
      END

      SET @cOrderKey = ''
      SET @cSKU = ''
      SET @cPickSlipNo = ''
      SET @nCartonNo = 0

      -- Custom carton retrive
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCartonIDSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCartonIDSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey OUTPUT, @cStorerGroup, ' +
            ' @cMBOLKey, @cRefNo, @cCartonID, @cData1, @cData2, @cData3, @cData4, @cData5, ' +
            ' @cPickSlipNo OUTPUT, @cOrderKey OUTPUT, @nCartonNo OUTPUT, @cSKU OUTPUT, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15) OUTPUT, ' +
            ' @cStorerGroup   NVARCHAR( 20), ' +
            ' @cMBOLKey       NVARCHAR( 10), ' +
            ' @cRefNo         NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cData1         NVARCHAR( 20), ' +
            ' @cData2         NVARCHAR( 20), ' +
            ' @cData3         NVARCHAR( 20), ' +
            ' @cData4         NVARCHAR( 20), ' +
            ' @cData5         NVARCHAR( 20), ' +
            ' @cPickSlipNo    NVARCHAR( 20) OUTPUT, ' + 
            ' @cOrderKey      NVARCHAR( 10) OUTPUT, ' +
            ' @nCartonNo      INT           OUTPUT, ' + 
            ' @cSKU           NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey OUTPUT, @cStorerGroup, 
            @cMBOLKey, @cRefNo, @cCartonID, @cData1, @cData2, @cData3, @cData4, @cData5, 
            @cPickSlipNo OUTPUT, @cOrderKey OUTPUT, @nCartonNo OUTPUT, @cSKU OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_Carton_Fail
      END
      
      -- Standard carton retrive
      ELSE
      BEGIN
         -- Check carton ID (PackDetail.LabelNo)
         IF @cOrderKey = '' AND CHARINDEX( 'L', @cCartonIDSP) > 0 -- L=LabelNo
         BEGIN
            IF @cStorerGroup = ''
               SELECT TOP 1 
                  @cPickSlipNo = PH.PickSlipNo,
                  @cOrderKey = PH.OrderKey, 
                  @nCartonNo = CartonNo, 
                  @cSKU = SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cCartonID
           ELSE
               SELECT TOP 1 
                  @cStorerKey = PH.StorerKey, 
                  @cPickSlipNo = PH.PickSlipNo,
                  @cOrderKey = PH.OrderKey, 
                  @nCartonNo = CartonNo, 
                  @cSKU = SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = PH.StorerKey AND SG.StorerGroup = @cStorerGroup)
               WHERE PD.LabelNo = @cCartonID
         END

         -- Check carton ID (PackDetail.DropID)
         IF @cOrderKey = '' AND CHARINDEX( 'D2', @cCartonIDSP) > 0 -- D2=PackDetail.DropID
         BEGIN
            IF @cStorerGroup = ''
               SELECT TOP 1 
                  @cPickSlipNo = PH.PickSlipNo,
                  @cOrderKey = PH.OrderKey, 
                  @nCartonNo = CartonNo, 
                  @cSKU = SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cCartonID
            ELSE
               SELECT TOP 1 
                  @cStorerKey = PH.StorerKey, 
                  @cPickSlipNo = PH.PickSlipNo,
                  @cOrderKey = PH.OrderKey, 
                  @nCartonNo = CartonNo, 
                  @cSKU = SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = PH.StorerKey AND SG.StorerGroup = @cStorerGroup)
               WHERE PD.DropID = @cCartonID
         END

         -- Check carton ID (PickDetail.CaseID)
         IF @cOrderKey = '' AND CHARINDEX( 'C', @cCartonIDSP) > 0 -- C=CaseID
         BEGIN
            IF @cStorerGroup = ''
               SELECT TOP 1 
                  @cOrderKey = OrderKey, 
                  @cSKU = SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cCartonID
            ELSE
               SELECT TOP 1 
                  @cStorerKey = PD.StorerKey, 
                  @cOrderKey = PD.OrderKey, 
                  @cSKU = PD.SKU
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = PD.StorerKey AND SG.StorerGroup = @cStorerGroup)
               WHERE PD.CaseID = @cCartonID
         END

         -- Check carton ID (PickDetail.DropID)
         IF @cOrderKey = '' AND CHARINDEX( 'D1', @cCartonIDSP) > 0 -- D1=PickDetail.DropID
         BEGIN
            IF @cStorerGroup = ''
               SELECT TOP 1 
                  @cOrderKey = OrderKey, 
                  @cSKU = SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cCartonID
            ELSE
               SELECT TOP 1 
                  @cStorerKey = PD.StorerKey, 
                  @cOrderKey = PD.OrderKey, 
                  @cSKU = PD.SKU
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = PD.StorerKey AND SG.StorerGroup = @cStorerGroup)
               WHERE PD.DropID = @cCartonID
         END
      END
      
      -- Check order found
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 198862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Order
         GOTO Step_Carton_Fail
      END

      -- Check MBOL same storer
      IF @cStorerGroup <> ''
      BEGIN
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.MBOLDetail MD WITH (NOLOCK) 
               JOIN dbo.Orders O WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey)
            WHERE MD.MBOLKey = @cMBOLKey 
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 198863
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Step_Carton_Fail
         END
      END

      -- Check order populated to other MBOL
      IF EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey <> @cMBOLKey AND OrderKey = @cOrderKey)
      BEGIN
         SET @nErrNo = 198864
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInOthMBOL
         GOTO Step_Carton_Fail
      END

      -- Get storer config
      SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)
      SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
      SET @cAllowLengthZero = rdt.rdtGetConfig( @nFunc, 'AllowLengthZero', @cStorerKey)
      SET @cAllowWidthZero = rdt.rdtGetConfig( @nFunc, 'AllowWidthZero', @cStorerKey)
      SET @cAllowHeightZero = rdt.rdtGetConfig( @nFunc, 'AllowHeightZero', @cStorerKey)
      SET @cCloseMBOL = rdt.RDTGetConfig( @nFunc, 'CloseMBOL', @cStorerKey)
      SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)
      SET @cTrackCartonType = rdt.rdtGetConfig( @nFunc, 'TrackCartonType', @cStorerKey)

      SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
      IF @cCapturePackInfoSP = '0'
         SET @cCapturePackInfoSP = ''
      SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
      IF @cDefaultCartonType = '0'
         SET @cDefaultCartonType = ''
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, ' + 
               ' @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, ' +
               ' @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cMBOLKey       NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' + 
               ' @cPickSlipNo    NVARCHAR( 20), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cData1         NVARCHAR( 20), ' +
               ' @cData2         NVARCHAR( 20), ' +
               ' @cData3         NVARCHAR( 20), ' +
               ' @cData4         NVARCHAR( 20), ' +
               ' @cData5         NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 2),  ' +
               ' @cCartonType    NVARCHAR( 10), ' +
               ' @nUseSequence   INT,           ' + 
               ' @cCube          NVARCHAR( 10), ' +
               ' @cWeight        NVARCHAR( 10), ' +
               ' @cPackInfoRefNo NVARCHAR( 20), ' + 
               ' @cLength        NVARCHAR( 10), ' + 
               ' @cWidth         NVARCHAR( 10), ' + 
               ' @cHeight        NVARCHAR( 10), ' + 
               ' @tExtValVar     VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, 
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, 
               @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, 
               @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_Carton_Fail
         END
      END

      -- Custom PackInfo field setup
      SET @cPackInfo = ''
      IF @cCapturePackInfoSP <> ''
      BEGIN
         -- Custom SP to get PackInfo setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, ' + 
               ' @cCartonType OUTPUT, @cCube OUTPUT, @cWeight OUTPUT, @cPackInfoRefNo OUTPUT, @cLength OUTPUT, @cWidth OUTPUT, @cHeight OUTPUT ' 

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cMBOLKey       NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' + 
               ' @cPickSlipNo    NVARCHAR( 20), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cData1         NVARCHAR( 20), ' +
               ' @cData2         NVARCHAR( 20), ' +
               ' @cData3         NVARCHAR( 20), ' +
               ' @cData4         NVARCHAR( 20), ' +
               ' @cData5         NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 2),  ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT, ' +
               ' @cCartonType    NVARCHAR( 10) OUTPUT, ' +
               ' @cCube          NVARCHAR( 10) OUTPUT, ' +
               ' @cWeight        NVARCHAR( 10) OUTPUT, ' +
               ' @cPackInfoRefNo NVARCHAR( 20) OUTPUT, ' + 
               ' @cLength        NVARCHAR( 10) OUTPUT, ' + 
               ' @cWidth         NVARCHAR( 10) OUTPUT, ' + 
               ' @cHeight        NVARCHAR( 10) OUTPUT  ' 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, 
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, 
               @nErrNo         OUTPUT,
               @cErrMsg        OUTPUT,
               @cPackInfo      OUTPUT,
               @cCartonType    OUTPUT, 
               @cWeight        OUTPUT,
               @cCube          OUTPUT,
               @cPackInfoRefNo OUTPUT,
               @cLength        OUTPUT,
               @cWidth         OUTPUT,
               @cHeight        OUTPUT
         END
         ELSE
            -- Setup is non SP
            SET @cPackInfo = @cCapturePackInfoSP
      END

      -- Capture pack info
      IF @cPackInfo <> ''
      BEGIN
         -- Get PackInfo
         SET @cCartonType = ''
         SET @cWeight = ''
         SET @cCube = ''
         SET @cRefNo = ''
         SET @cLength = ''
         SET @cWidth = ''
         SET @cHeight = ''
            
         SELECT
            @cCartonType = CartonType,
            @cWeight = rdt.rdtFormatFloat( Weight),
            @cCube = rdt.rdtFormatFloat( [Cube]),
            @cRefNo = RefNo,
            @cLength = rdt.rdtFormatFloat( [Length]),
            @cWidth = rdt.rdtFormatFloat( [Width]),
            @cHeight = rdt.rdtFormatFloat( [Height])
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo  = @nCartonNo

         -- Prepare LOC screen var
         SET @cOutField01 = CASE WHEN ISNULL( @cCartonType, '') = '' AND ISNULL( @cDefaultCartonType, '') <> '' THEN @cDefaultCartonType ELSE @cCartonType END
         SET @cOutField02 = @cWeight
         SET @cOutField03 = @cCube
         SET @cOutField04 = @cRefNo
         SET @cOutField05 = @cLength
         SET @cOutField06 = @cWidth
         SET @cOutField07 = @cHeight

         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr05 = CASE WHEN CHARINDEX( 'L', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'D', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'H', @cPackInfo) = 0 THEN 'O' ELSE '' END

         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
         IF @cFieldAttr05 = '' AND @cOutField05 = '0' EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE
         IF @cFieldAttr06 = '' AND @cOutField06 = '0' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
         IF @cFieldAttr07 = '' AND @cOutField07 = '0' EXEC rdt.rdtSetFocusField @nMobile, 7 

         -- Go to next screen
         SET @nScn = @nScn_PackInfo
         SET @nStep = @nStep_PackInfo

         GOTO Quit
      END

      -- Capture carton type (backend auto take from PackInfo.CartonType)
      SET @cCartonType = ''
      SET @nUseSequence = 0
      IF @cTrackCartonType = '5'
      BEGIN
         IF @cPickSlipNo <> '' AND @nCartonNo > 0
         BEGIN
            -- Get carton info
            SELECT @cCartonType = CartonType FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
            SELECT @nUseSequence = UseSequence
            FROM dbo.Cartonization WITH (NOLOCK)
               JOIN dbo.Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
            WHERE Storer.StorerKey = @cStorerKey
               AND Cartonization.CartonType = @cCartonType
         END
      END 

      -- Confirm
      EXEC rdt.rdt_CartonToMBOL_Confirm
          @nMobile      = @nMobile
         ,@nFunc        = @nFunc
         ,@cLangCode    = @cLangCode
         ,@nStep        = @nStep
         ,@nInputKey    = @nInputKey
         ,@cFacility    = @cFacility
         ,@cStorerKey   = @cStorerKey
         ,@cMBOLKey     = @cMBOLKey
         ,@cRefNo       = @cRefNo
         ,@cOrderKey    = @cOrderKey
         ,@cCartonID    = @cCartonID
         ,@cSKU         = @cSKU
         ,@cPickSlipNo  = @cPickSlipNo
         ,@nCartonNo    = @nCartonNo
         ,@cData1       = @cData1
         ,@cData2       = @cData2
         ,@cData3       = @cData3
         ,@cData4       = @cData4
         ,@cData5       = @cData5
         ,@tConfirmVar  = @tConfirmVar
         ,@nTotalCarton = @nTotalCarton OUTPUT
         ,@nErrNo       = @nErrNo       OUTPUT
         ,@cErrMsg      = @cErrMsg      OUTPUT
         ,@cCartonType  = @cCartonType  
         ,@nUseSequence = @nUseSequence
      IF @nErrNo <> 0
         GOTO Step_Carton_Fail

      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = '' -- @cCartonID
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, ' + 
               ' @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, ' +
               ' @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cMBOLKey       NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' + 
               ' @cPickSlipNo    NVARCHAR( 20), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cData1         NVARCHAR( 20), ' +
               ' @cData2         NVARCHAR( 20), ' +
               ' @cData3         NVARCHAR( 20), ' +
               ' @cData4         NVARCHAR( 20), ' +
               ' @cData5         NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 2),  ' +
               ' @cCartonType    NVARCHAR( 10), ' +
               ' @nUseSequence   INT,           ' + 
               ' @cCube          NVARCHAR( 10), ' +
               ' @cWeight        NVARCHAR( 10), ' +
               ' @cPackInfoRefNo NVARCHAR( 20), ' + 
               ' @cLength        NVARCHAR( 10), ' + 
               ' @cWidth         NVARCHAR( 10), ' + 
               ' @cHeight        NVARCHAR( 10), ' + 
               ' @tExtValVar     VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, 
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, 
               @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, 
               @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      IF @nTotalCarton > 0 AND @cCloseMBOL = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = ''   -- Option

         -- Go to next screen
         SET @nScn = @nScn_CloseMBOL
         SET @nStep = @nStep_CloseMBOL
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- MBOL

         -- Go to next screen
         SET @nScn = @nScn_MBOL
         SET @nStep = @nStep_MBOL
      END
   END
   GOTO Quit

   Step_Carton_Fail:
   BEGIN
      EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
      SET @cOutField02 = '' -- Carton ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 6243. Close MBOL?
   MBOLKey  (field01)
   OPTION   (field02, input)
********************************************************************************/
Step_CloseMBOL:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 198865
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_CloseMBOL_Fail
      END

      -- Check option
      IF @cOption NOT IN ( '1', '2')
      BEGIN
         SET @nErrNo = 198866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_CloseMBOL_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Send MBOL for validation
         UPDATE dbo.MBOL SET
            Status = '5', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE MbolKey = @cMBOLKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 198867
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail
            GOTO Step_CloseMBOL_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- MBOL

      -- Go to next screen
      SET @nScn = @nScn_MBOL
      SET @nStep = @nStep_MBOL
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = '' -- Carton ID
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn_Carton
      SET @nStep = @nStep_Carton
   END
   GOTO Quit

   Step_CloseMBOL_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit


/********************************************************************************
Scn = 6244. Capture pack info
   Carton Type (field01, input)
   Weight      (field02, input)
   Cube        (field03, input)
   RefNo       (field04, input)
********************************************************************************/
Step_PackInfo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)

      -- Screen mapping
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cLength         = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END
      SET @cWidth          = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cHeight         = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END

      -- Carton type
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cChkCartonType = ''
         BEGIN
            SET @nErrNo = 198868
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Get default cube
         DECLARE @nDefaultCube FLOAT
         SELECT 
            @nDefaultCube = [Cube], 
            @nUseSequence = UseSequence
         FROM Cartonization WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
         WHERE Storer.StorerKey = @cStorerKey
            AND Cartonization.CartonType = @cChkCartonType

         -- Check if valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 198869
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Different carton type scanned
         IF @cChkCartonType <> @cCartonType
         BEGIN
            SET @cCartonType = @cChkCartonType
            SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)
            SET @cWeight = ''

            SET @cOutField01 = @cCartonType
            SET @cOutField02 = @cWeight
            SET @cOutField03 = @cCube
         END
      END

      -- Weight
      IF @cFieldAttr02 = ''
      BEGIN
         -- Check blank
         IF @cWeight = ''
         BEGIN
            SET @nErrNo = 198870
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0
         BEGIN
            SET @nErrNo = 198871
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check weight valid
         IF @cAllowWeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 198872
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField02 = @cWeight
      END

      -- Default weight
      ELSE IF @cDefaultWeight IN ('2', '3')
      BEGIN
         -- Weight (SKU only)
         DECLARE @nWeight FLOAT
         SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.CartonNo = @nCartonNo

         -- Weight (SKU + carton)
         IF @cDefaultWeight = '3'
         BEGIN
            -- Get carton type info
            DECLARE @nCartonWeight FLOAT
            SELECT @nCartonWeight = CartonWeight
            FROM Cartonization C WITH (NOLOCK)
               JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
            WHERE S.StorerKey = @cStorerKey
               AND C.CartonType = @cCartonType

            SET @nWeight = @nWeight + @nCartonWeight
         END
         SET @cWeight = rdt.rdtFormatFloat( @nWeight)
      END

      -- Cube
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
         IF @cCube = ''
         BEGIN
            SET @nErrNo = 198873
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Cube', @cCube) = 0
         BEGIN
            SET @nErrNo = 198874
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowCubeZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 198875
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = ''
        GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField03 = @cCube
      END

      -- Length
      IF @cFieldAttr05 = ''
      BEGIN
         -- Check blank
         IF @cLength = ''
         BEGIN
            SET @nErrNo = 198876
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Length
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Length', @cLength) = 0
         BEGIN
            SET @nErrNo = 198877
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowLengthZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 198878
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length
            EXEC rdt.rdtSetFocusField @nMobile, 5
            SET @cOutField04 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField04 = @cLength
      END

      -- Width
      IF @cFieldAttr06 = ''
      BEGIN
         -- Check blank
         IF @cWidth = ''
         BEGIN
            SET @nErrNo = 198879
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Width
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Width', @cWidth) = 0
         BEGIN
            SET @nErrNo = 198880
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowWidthZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 198881
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Width
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField05 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField05 = @cWidth
      END

      -- Height
      IF @cFieldAttr07 = ''
      BEGIN
         -- Check blank
         IF @cHeight = ''
         BEGIN
            SET @nErrNo = 198882
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Height', @cHeight) = 0
         BEGIN
            SET @nErrNo = 198883
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowHeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 198884
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Height
            EXEC rdt.rdtSetFocusField @nMobile, 7
            SET @cOutField06 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField06 = @cHeight
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, ' + 
               ' @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, ' +
               ' @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cMBOLKey       NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' + 
               ' @cPickSlipNo    NVARCHAR( 20), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cData1         NVARCHAR( 20), ' +
               ' @cData2         NVARCHAR( 20), ' +
               ' @cData3         NVARCHAR( 20), ' +
               ' @cData4         NVARCHAR( 20), ' +
               ' @cData5         NVARCHAR( 20), ' +
               ' @cOption        NVARCHAR( 2),  ' +
               ' @cCartonType    NVARCHAR( 10), ' +
               ' @nUseSequence   INT,           ' + 
               ' @cCube          NVARCHAR( 10), ' +
               ' @cWeight        NVARCHAR( 10), ' +
               ' @cPackInfoRefNo NVARCHAR( 20), ' + 
               ' @cLength        NVARCHAR( 10), ' + 
               ' @cWidth         NVARCHAR( 10), ' + 
               ' @cHeight        NVARCHAR( 10), ' + 
               ' @tExtValVar     VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, 
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, 
               @cCartonType, @nUseSequence, @cCube, @cWeight, @cPackInfoRefNo, @cLength, @cWidth, @cHeight, 
               @tExtValVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Capture carton type (backend auto take from PackInfo.CartonType)
      IF @cTrackCartonType = '5' AND @cCartonType = ''
      BEGIN
         IF @cPickSlipNo <> '' AND @nCartonNo > 0
         BEGIN
            -- Get carton info
            SELECT @cCartonType = CartonType FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
            SELECT @nUseSequence = UseSequence
            FROM dbo.Cartonization WITH (NOLOCK)
               JOIN dbo.Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
            WHERE Storer.StorerKey = @cStorerKey
               AND Cartonization.CartonType = @cCartonType
         END
      END 

      -- Confirm
      EXEC rdt.rdt_CartonToMBOL_Confirm
          @nMobile         = @nMobile
         ,@nFunc           = @nFunc
         ,@cLangCode       = @cLangCode
         ,@nStep           = @nStep
         ,@nInputKey       = @nInputKey
         ,@cFacility       = @cFacility
         ,@cStorerKey      = @cStorerKey
         ,@cMBOLKey        = @cMBOLKey
         ,@cRefNo          = @cRefNo
         ,@cOrderKey       = @cOrderKey
         ,@cCartonID       = @cCartonID
         ,@cSKU            = @cSKU
         ,@cPickSlipNo     = @cPickSlipNo
         ,@nCartonNo       = @nCartonNo
         ,@cData1          = @cData1
         ,@cData2          = @cData2
         ,@cData3          = @cData3
         ,@cData4          = @cData4
         ,@cData5          = @cData5
         ,@tConfirmVar     = @tConfirmVar
         ,@nTotalCarton    = @nTotalCarton OUTPUT
         ,@nErrNo          = @nErrNo       OUTPUT
         ,@cErrMsg         = @cErrMsg      OUTPUT
         ,@cCartonType     = @cCartonType  
         ,@nUseSequence    = @nUseSequence
         ,@cWeight         = @cWeight
         ,@cCube           = @cCube
         ,@cPackInfoRefNo  = @cPackInfoRefNo
         ,@cLength         = @cLength
         ,@cWidth          = @cWidth
         ,@cHeight         = @cHeight
      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo
      SET @cFieldAttr05 = '' -- Length
      SET @cFieldAttr06 = '' -- Width
      SET @cFieldAttr07 = '' -- Height

      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = '' -- @cCartonID
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))
      
      -- Go to next screen
      SET @nScn = @nScn_Carton
      SET @nStep = @nStep_Carton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo
      SET @cFieldAttr05 = '' -- Length
      SET @cFieldAttr06 = '' -- Width
      SET @cFieldAttr07 = '' -- Height

      -- Prepare next screen var
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = '' -- @cCartonID
      SET @cOutField03 = CAST( @nTotalCarton AS NVARCHAR( 5))
      
      -- Go to next screen
      SET @nScn = @nScn_Carton
      SET @nStep = @nStep_Carton
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_StorerKey  = @cStorerKey,
      V_OrderKey   = @cOrderKey, 
      V_SKU        = @cSKU, 
      V_PickSlipNo = @cPickSlipNo, 

      V_String1  = @cMBOLKey,
      V_String2  = @cRefNo,
      V_String3  = @cCartonID,
      V_String4  = @cCartonType,
      V_String6  = @cCube,
      V_String7  = @cWeight,
      V_String8  = @cPackInfoRefNo,
      V_String9  = @cLength, 
      V_String10 = @cWidth, 
      V_String11 = @cHeight, 
      
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @cExtendedValidateSP,
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cExtendedInfo,
      V_String25 = @cCaptureInfoSP,
      V_String26 = @cCartonIDSP,
      V_String27 = @cAutoGenMBOL, 
      V_String28 = @cCapturePackInfoSP,
      V_String29 = @cPackInfo,
      V_String30 = @cDefaultCartonType,
      V_String31 = @cDefaultWeight,
      V_String32 = @cAllowWeightZero,
      V_String33 = @cAllowCubeZero,
      V_String34 = @cAllowLengthZero,
      V_String35 = @cAllowWidthZero,
      V_String36 = @cAllowHeightZero,
      V_String37 = @cCloseMBOL,
      V_String38 = @cTrackCartonType,
      V_String39 = @cDecodeSP,

      V_String41 = @cData1,
      V_String42 = @cData2,
      V_String43 = @cData3,
      V_String44 = @cData4,
      V_String45 = @cData5,

      V_CartonNo = @nCartonNo,
      V_Integer1 = @nTotalCarton,
      V_Integer2 = @nUseSequence, 

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15
      
   WHERE Mobile = @nMobile
END

GO