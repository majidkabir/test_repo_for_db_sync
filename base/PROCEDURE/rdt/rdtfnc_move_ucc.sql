SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Move_UCC                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-12 1.0  UngDH    Created                                     */
/* 2009-07-06 1.1  Vicky    Add in EventLog (Vicky06)                   */
/* 2011-11-11 1.2  ChewKP   LCI Project Changes Update UCC Table        */
/*                          (ChewKP01)                                  */
/* 2011-12-21 1.3  James    Revamp rdt_move (james01)                   */
/* 2012-02-14 1.4  James    Include from loc to scan (james02)          */
/* 2012-07-17 1.5  James    Storerconfig to control whether need to scan*/
/*                          from loc (james03)                          */
/* 2012-07-19 1.6  ChewKP   SOS#250946 - Move UCC Update to SP rdt_Move */
/*                          (ChewKP02)                                  */
/* 2013-06-14 1.7  James    SOS#281065 - Bug fix (james04)              */
/* 2013-09-20 1.8  Ung      Fix FromID not pass-in to rdt_move          */
/*                          Add MoveByUCCDefaultCursorToID              */
/* 2015-01-07 1.9  ChewKP   SOS#330113 - Add ExtendedValidate Config    */
/*                          (ChewKP03)                                  */
/* 2015-04-24 2.0  Ung      SOS340172 Add ExtendedUpdateSP              */
/*                          Revise ExtendedValidateSP                   */
/* 2016-09-30 2.1  Ung      Performance tuning                          */
/* 2018-11-01 2.2  James    Reinitialse variable before exit (james05)  */
/* 2018-02-20 2.3  YeeKung  WMS-8020 Add RDTSTDEVENTLOG                 */
/* 2019-03-26 2.4  James    WMS-8352 Add From ID (james06)              */
/*                          Add Loc lookup                              */
/* 2020-05-04 2.5  Ung      WMS-12637 Add ConfirmSP                     */
/* 2023-01-20 2.6  Ung      WMS-21577 Add unlimited UCC to move         */
/* 2023-05-09 2.7  Ung      WMS-22401 Fix UCC DoubleScan                */
/* 2023-06-12 2.8  Ung      WMS-22742 Add 2D barcode                    */
/* 2024-10-25 2.9  ShaoAn   FCR-759-1001 ID and UCC Length Issue        */
/* 2024-08-05 3.0  Ung      WMS-25998 Add UCC.Status = 3                */
/* 2024-11-07 3.1  PXL009   Merged 2.9 from v0 branch                   */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Move_UCC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cSQL         NVARCHAR( MAX), 
   @cSQLParam    NVARCHAR( MAX), 
   @cUCC         NVARCHAR( 20),
   @cChkFacility NVARCHAR( 5),
   @nRowRef      INT,
   @i            INT,
   @curUCC       CURSOR

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),

   @cSKU         NVARCHAR( 20),
   @cSKUDescr    NVARCHAR( 60),
   @cBarcode     NVARCHAR( MAX),
   @cBarcodeUCC  NVARCHAR( 60),
   @cUCCNo       NVARCHAR( 20),
   @cUDF01       NVARCHAR( 30),

   @cUCC1      NVARCHAR( 20),
   @cUCC2      NVARCHAR( 20),
   @cUCC3      NVARCHAR( 20),
   @cUCC4      NVARCHAR( 20),
   @cUCC5      NVARCHAR( 20),
   @cUCC6      NVARCHAR( 20),
   @cUCC7      NVARCHAR( 20),
   @cUCC8      NVARCHAR( 20),
   @cUCC9      NVARCHAR( 20),

   @cToLOC       NVARCHAR( 10),
   @cToID        NVARCHAR( 18),
   @cFromLOC     NVARCHAR( 10),
   @cFromID      NVARCHAR( 18),
   @cUCCStatus NVARCHAR( 10),

   @cExtendedValidateSP NVARCHAR( 20), 
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cLOCLookUP          NVARCHAR( 20),
   @c2DBarcode          NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 20),

   @nTotalUCC  INT,
   @nPage      INT,
   @nUCCOnPage INT, 

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @cBarcode   = V_Barcode,

   @cUCC1      = V_String1,
   @cUCC2      = V_String2,
   @cUCC3      = V_String3,
   @cUCC4      = V_String4,
   @cUCC5      = V_String5,
   @cUCC6      = V_String6,
   @cUCC7      = V_String7,
   @cUCC8      = V_String8,
   @cUCC9      = V_String9,

   @cToLOC     = V_String10,
   @cToID      = V_String11,
   @cFromLOC   = V_String12,
   @cFromID    = V_String15,
   @cUCCStatus = V_String16,
   @cUDF01     = V_String17,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @c2DBarcode          = V_String22,
   @cLOCLookUP          = V_String23,
   @cDecodeSP           = V_String24,

   @nTotalUCC  = V_Integer1,
   @nPage      = V_Integer2,
   @nUCCOnPage = V_Integer3,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Start            INT, 
   @nStep_UCC              INT,  @nScn_UCC              INT,
   @nStep_ToLOC            INT,  @nScn_ToLOC            INT,
   @nStep_Message          INT,  @nScn_Message          INT,
   @nStep_FromLOC          INT,  @nScn_FromLOC          INT,
   @nStep_2DUCC            INT,  @nScn_2DUCC            INT

SELECT
   @nStep_Start            = 0, 
   @nStep_UCC              = 1,  @nScn_UCC            = 808,
   @nStep_ToLOC            = 2,  @nScn_ToLOC          = 809,
   @nStep_Message          = 3,  @nScn_Message        = 810,
   @nStep_FromLOC          = 4,  @nScn_FromLOC        = 811,
   @nStep_2DUCC            = 5,  @nScn_2DUCC          = 812

IF @nFunc = 514 -- Move (UCC)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start     -- Func = 514
   IF @nStep = 1 GOTO Step_UCC       -- Scn = 808. UCC1..9
   IF @nStep = 2 GOTO Step_ToLOC     -- Scn = 809. ToLOC, ToID
   IF @nStep = 3 GOTO Step_Message   -- Scn = 810. Message
   IF @nStep = 4 GOTO Step_FromLOC   -- Scn = 811. FromLOC, FromID
   IF @nStep = 5 GOTO Step_2DUCC     -- Scn = 812. 2D UCC
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 514. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Storer configure
   SET @c2DBarcode = rdt.RDTGetConfig( @nFunc, '2DBarcode', @cStorerKey)
   
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cLOCLookUP = rdt.rdtGetConfig( @nFunc, 'LOCLookUPSP', @cStorerKey)
   IF @cLOCLookUP = '0'
      SET @cLOCLookUP = ''

   -- UCC status allowed
	SET @cUCCStatus = '1' -- Received
	IF rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey) = '1'
      SET @cUCCStatus += '3' -- Alloc

   -- Initiate var
   SET @cUCC1 = ''
   SET @cUCC2 = ''
   SET @cUCC3 = ''
   SET @cUCC4 = ''
   SET @cUCC5 = ''
   SET @cUCC6 = ''
   SET @cUCC7 = ''
   SET @cUCC8 = ''
   SET @cUCC9 = ''
   SET @nTotalUCC = 0
   SET @nPage = 1

   SET @cFromLOC = ''
   SET @cToLOC = ''
   SET @cToID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''

   -- Clear temp table
   IF EXISTS( SELECT TOP 1 1
      FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND AddWho = SUSER_SNAME())
   BEGIN
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtMoveUCCLog WHERE RowRef = @nRowRef
         FETCH NEXT FROM @curUCC INTO @nRowRef
      END
   END
   
   -- Set the entry point
   IF rdt.RDTGetConfig( @nFunc, 'MoveByUCCScanFromLOC', @cStorerKey) = '1'
   BEGIN
      SET @cOutField01 = '' -- From LOC
      SET @cOutField02 = '' -- From ID
      
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromLOC
      
      SET @nScn = @nScn_FromLOC
      SET @nStep = @nStep_FromLOC
   END
   ELSE
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- UCC1
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' -- UCC9
      SET @cOutField10 = '' -- SKU
      SET @cOutField11 = '' -- Desc1
      SET @cOutField12 = '' -- Desc2
      SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR( 3))
      
      IF @c2DBarcode = '1'
      BEGIN
         SET @nUCCOnPage = 8

         SET @cBarcode = '' 
         SET @nScn = @nScn_2DUCC
         SET @nStep = @nStep_2DUCC
      END
      ELSE
      BEGIN
         SET @nUCCOnPage = 9

         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
   END
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 806. Move From screen
   UCC1  (field01, input)
   UCC2  (field02, input)
   UCC3  (field03, input)
   UCC4  (field04, input)
   UCC5  (field05, input)
   UCC6  (field06, input)
   UCC7  (field07, input)
   UCC8  (field08, input)
   UCC9  (field09, input)
   SKU   (field10)
   Desc1 (field11)
   Desc2 (field12)
********************************************************************************/
Step_UCC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Retain key-in value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
      SET @cOutField08 = @cInField08
      SET @cOutField09 = @cInField09

      -- Validate blank
      IF @cInField01 = '' AND
         @cInField02 = '' AND
         @cInField03 = '' AND
         @cInField04 = '' AND
         @cInField05 = '' AND
         @cInField06 = '' AND
         @cInField07 = '' AND
         @cInField08 = '' AND
         @cInField09 = ''
      BEGIN
         -- Nothing in log
         IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtMoveUCCLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AddWho = SUSER_SNAME())
         BEGIN
            SET @nErrNo = 60601
            SET @cErrMsg = rdt.rdtgetmessage( 60601, @cLangCode, 'DSP') --'UCC needed'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_UCC_Fail
         END
      END
      
         -- Decode
         -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         SET @i = 1
         WHILE @i < 10
         BEGIN
            IF @i = 1 SELECT @cBarcodeUCC = @cInField01,@cUCC = @cUCC1
            IF @i = 2 SELECT @cBarcodeUCC = @cInField02,@cUCC = @cUCC2
            IF @i = 3 SELECT @cBarcodeUCC = @cInField03,@cUCC = @cUCC3
            IF @i = 4 SELECT @cBarcodeUCC = @cInField04,@cUCC = @cUCC4
            IF @i = 5 SELECT @cBarcodeUCC = @cInField05,@cUCC = @cUCC5
            IF @i = 6 SELECT @cBarcodeUCC = @cInField06,@cUCC = @cUCC6
            IF @i = 7 SELECT @cBarcodeUCC = @cInField07,@cUCC = @cUCC7
            IF @i = 8 SELECT @cBarcodeUCC = @cInField08,@cUCC = @cUCC8
            IF @i = 9 SELECT @cBarcodeUCC = @cInField09,@cUCC = @cUCC9

            IF @cBarcodeUCC <> '' AND @cBarcodeUCC <> @cUCC
            BEGIN
               SET @cUCCNo = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcodeUCC,
                        @cUCCNo  = @cUCCNo  OUTPUT,
                        @nErrNo  = @nErrNo   OUTPUT,
                        @cErrMsg = @cErrMsg  OUTPUT,
                        @cType   = 'UCCno'
               IF @nErrNo <> 0
                  GOTO Step_UCC_Fail

               IF @i = 1 SELECT  @cInField01 = @cUCCNo ,@cOutField01 = @cUCCNo
               IF @i = 2 SELECT  @cInField02 = @cUCCNo ,@cOutField02 = @cUCCNo
               IF @i = 3 SELECT  @cInField03 = @cUCCNo ,@cOutField03 = @cUCCNo
               IF @i = 4 SELECT  @cInField04 = @cUCCNo ,@cOutField04 = @cUCCNo
               IF @i = 5 SELECT  @cInField05 = @cUCCNo ,@cOutField05 = @cUCCNo
               IF @i = 6 SELECT  @cInField06 = @cUCCNo ,@cOutField06 = @cUCCNo
               IF @i = 7 SELECT  @cInField07 = @cUCCNo ,@cOutField07 = @cUCCNo
               IF @i = 8 SELECT  @cInField08 = @cUCCNo ,@cOutField08 = @cUCCNo
               IF @i = 9 SELECT  @cInField09 = @cUCCNo ,@cOutField09 = @cUCCNo
            END
            SET @i = @i + 1
         END
      END

      -- Validate if anything changed
      IF @cUCC1 <> @cInField01 OR
         @cUCC2 <> @cInField02 OR
         @cUCC3 <> @cInField03 OR
         @cUCC4 <> @cInField04 OR
         @cUCC5 <> @cInField05 OR
         @cUCC6 <> @cInField06 OR
         @cUCC7 <> @cInField07 OR
         @cUCC8 <> @cInField08 OR
         @cUCC9 <> @cInField09
      -- There are changes, remain in current screen
      BEGIN
         DECLARE @cInField NVARCHAR( 20)
         DECLARE @nLastValidatedUCC NVARCHAR( 20)
         SET @nLastValidatedUCC = ''
         
         -- Check newly scanned UCC. Validated UCC will be saved to respective @cUCC variable
         SET @i = 1
         WHILE @i < 10
         BEGIN
            IF @i = 1 SELECT @cInField = @cInField01, @cUCC = @cUCC1
            IF @i = 2 SELECT @cInField = @cInField02, @cUCC = @cUCC2
            IF @i = 3 SELECT @cInField = @cInField03, @cUCC = @cUCC3
            IF @i = 4 SELECT @cInField = @cInField04, @cUCC = @cUCC4
            IF @i = 5 SELECT @cInField = @cInField05, @cUCC = @cUCC5
            IF @i = 6 SELECT @cInField = @cInField06, @cUCC = @cUCC6
            IF @i = 7 SELECT @cInField = @cInField07, @cUCC = @cUCC7
            IF @i = 8 SELECT @cInField = @cInField08, @cUCC = @cUCC8
            IF @i = 9 SELECT @cInField = @cInField09, @cUCC = @cUCC9

            -- Value changed
            IF @cInField <> @cUCC
            BEGIN
               -- Consist a new value
               IF @cInField <> ''
               BEGIN
                  IF @cFromLOC = ''
                     SET @cFromLOC = NULL

                  -- Validate UCC
                  EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                     @cInField, -- UCC
                     @cStorerKey, 
                     @cUCCStatus, -- 1=Received, 3=Alloc
                     @cChkLOC = @cFromLOC

                  IF @nErrNo = 0
                  BEGIN
                     -- Check UCC scanned
                     IF EXISTS( SELECT 1
                        FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND UCCNo = @cInField
                           AND AddWho = SUSER_SNAME())
                     BEGIN
                        SET @nErrNo = 60602
                        SET @cErrMsg = rdt.rdtgetmessage( 60602, @cLangCode, 'DSP') --'UCC DoubleScan'
                     END
                  END
                  
                  IF @nErrNo = 0
                  BEGIN
                     -- Extended validate
                     IF @cExtendedValidateSP <> ''
                     BEGIN
                        IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
                        BEGIN
                           SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                              ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cUCC, ' + 
                              ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' + 
                              ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                           SET @cSQLParam =
                              '@nMobile        INT, ' +
                              '@nFunc          INT, ' +
                              '@cLangCode      NVARCHAR( 3),  ' +
                              '@nStep          INT, ' +
                              '@nInputKey      INT, ' + 
                              '@cStorerKey     NVARCHAR( 15), ' +
                              '@cToID          NVARCHAR( 18), ' +
                              '@cToLoc         NVARCHAR( 10), ' +
                              '@cFromLoc       NVARCHAR( 10), ' +
                              '@cFromID        NVARCHAR( 18), ' +
                              '@cUCC           NVARCHAR( 20), ' +
                              '@cUCC1          NVARCHAR( 20), ' +
                              '@cUCC2          NVARCHAR( 20), ' +
                              '@cUCC3          NVARCHAR( 20), ' +
                              '@cUCC4          NVARCHAR( 20), ' +
                              '@cUCC5          NVARCHAR( 20), ' +
                              '@cUCC6          NVARCHAR( 20), ' +
                              '@cUCC7          NVARCHAR( 20), ' +
                              '@cUCC8          NVARCHAR( 20), ' +
                              '@cUCC9          NVARCHAR( 20), ' +
                              '@nErrNo         INT           OUTPUT, ' + 
                              '@cErrMsg        NVARCHAR( 20) OUTPUT'
                          
                           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cInField, 
                              '', '', '', '', '', '', '', '', '', 
                              @nErrNo OUTPUT, @cErrMsg OUTPUT 
                        END
                     END
                  END
                  
                  IF @nErrNo = 0
                     SET @nLastValidatedUCC = @cInField -- UCC
                  ELSE 
                  BEGIN
                     -- Error, clear the UCC field
                     IF @i = 1 SELECT @cUCC1 = '', @cInField01 = '', @cOutField01 = ''
                     IF @i = 2 SELECT @cUCC2 = '', @cInField02 = '', @cOutField02 = ''
                     IF @i = 3 SELECT @cUCC3 = '', @cInField03 = '', @cOutField03 = ''
                     IF @i = 4 SELECT @cUCC4 = '', @cInField04 = '', @cOutField04 = ''
                     IF @i = 5 SELECT @cUCC5 = '', @cInField05 = '', @cOutField05 = ''
                     IF @i = 6 SELECT @cUCC6 = '', @cInField06 = '', @cOutField06 = ''
                     IF @i = 7 SELECT @cUCC7 = '', @cInField07 = '', @cOutField07 = ''
                     IF @i = 8 SELECT @cUCC8 = '', @cInField08 = '', @cOutField08 = ''
                     IF @i = 9 SELECT @cUCC9 = '', @cInField09 = '', @cOutField09 = ''
                     EXEC rdt.rdtSetFocusField @nMobile, @i
                     
                     -- Remove old value
                     IF @cUCC <> '' 
                     BEGIN
                        DELETE rdt.rdtMoveUCCLog 
                        WHERE StorerKey = @cStorerKey
                           AND UCCNo = @cUCC
                           AND AddWho = SUSER_SNAME()
                     
                        SELECT @nTotalUCC = COUNT(1) 
                        FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND AddWho = SUSER_SNAME()
                           
                        -- Refresh counter
                        SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR( 3))
                     END
                     
                     GOTO Step_UCC_Fail
                  END
               END
               
               -- Save to UCC variable
               IF @i = 1 SET @cUCC1 = @cInField01
               IF @i = 2 SET @cUCC2 = @cInField02
               IF @i = 3 SET @cUCC3 = @cInField03
               IF @i = 4 SET @cUCC4 = @cInField04
               IF @i = 5 SET @cUCC5 = @cInField05
               IF @i = 6 SET @cUCC6 = @cInField06
               IF @i = 7 SET @cUCC7 = @cInField07
               IF @i = 8 SET @cUCC8 = @cInField08
               IF @i = 9 SET @cUCC9 = @cInField09
               
               -- Save to log
               -- Remove old value
               IF @cUCC <> '' 
                  DELETE rdt.rdtMoveUCCLog 
                  WHERE StorerKey = @cStorerKey
                     AND UCCNo = @cUCC
                     AND AddWho = SUSER_SNAME()
               
               -- Add new value
               IF @cInField <> '' 
                  INSERT INTO rdt.rdtMoveUCCLog (StorerKey, UCCNo, RecNo) 
                  SELECT @cStorerKey, @cInField, (@nPage-1) * @nUCCOnPage + @i
            END
            SET @i = @i + 1
         END
         
         -- Get SKU and desc of last validated UCC
         IF @nLastValidatedUCC <> ''
            SELECT 
               @cSKU = SKU.SKU, 
               @cSKUDescr = SKU.Descr
            FROM dbo.UCC UCC (NOLOCK)
               INNER JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = UCC.StorerKey AND SKU.SKU = UCC.SKU)
            WHERE SKU.StorerKey = @cStorerKey
               AND UCC.UCCNo = @nLastValidatedUCC
               AND UCC.Status = '1' -- Received

         SELECT @nTotalUCC = COUNT(1) 
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()

         -- Prepare current screen var
         SET @cOutField10 = @cSKU
         SET @cOutField11 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR( 3))

         -- Turn to next page
         IF @cUCC1 <> '' AND 
            @cUCC2 <> '' AND 
            @cUCC3 <> '' AND 
            @cUCC4 <> '' AND 
            @cUCC5 <> '' AND 
            @cUCC6 <> '' AND 
            @cUCC7 <> '' AND 
            @cUCC8 <> '' AND 
            @cUCC9 <> '' 
         BEGIN
            -- Prepare next page
            SELECT
               @cUCC1 = '', @cOutField01 = '', 
               @cUCC2 = '', @cOutField02 = '', 
               @cUCC3 = '', @cOutField03 = '', 
               @cUCC4 = '', @cOutField04 = '', 
               @cUCC5 = '', @cOutField05 = '', 
               @cUCC6 = '', @cOutField06 = '', 
               @cUCC7 = '', @cOutField07 = '', 
               @cUCC8 = '', @cOutField08 = '', 
               @cUCC9 = '', @cOutField09 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC1
            SET @nPage += 1
         END
         ELSE
         BEGIN
            -- Set next field focus
            SET @i = 1 -- start from 1st field
            IF @cInField01 <> '' SET @i = @i + 1
            IF @cInField02 <> '' SET @i = @i + 1
            IF @cInField03 <> '' SET @i = @i + 1
            IF @cInField04 <> '' SET @i = @i + 1
            IF @cInField05 <> '' SET @i = @i + 1
            IF @cInField06 <> '' SET @i = @i + 1
            IF @cInField07 <> '' SET @i = @i + 1
            IF @cInField08 <> '' SET @i = @i + 1
            IF @cInField09 <> '' SET @i = @i + 1
            IF @i > 9 SET @i = 1
            EXEC rdt.rdtSetFocusField @nMobile, @i
         END
      END
      ELSE
      BEGIN
         -- Turn to next page
         IF @cUCC1 <> '' AND 
            @cUCC2 <> '' AND 
            @cUCC3 <> '' AND 
            @cUCC4 <> '' AND 
            @cUCC5 <> '' AND 
            @cUCC6 <> '' AND 
            @cUCC7 <> '' AND 
            @cUCC8 <> '' AND 
            @cUCC9 <> '' 
         BEGIN
            SET @nPage += 1
            
            -- Load page
            SELECT 
               @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '', 
               @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = ''
               
            SELECT
               @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END, 
               @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END, 
               @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END, 
               @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END, 
               @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END, 
               @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END, 
               @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END, 
               @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 8 THEN UCCNo ELSE @cUCC8 END, 
               @cUCC9 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC9 END
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey 
               AND AddWho = SUSER_SNAME()
               AND RecNo BETWEEN @nPage * @nUCCOnPage - (9-1) AND @nPage * @nUCCOnPage
            
            SET @cOutField01 = @cUCC1
            SET @cOutField02 = @cUCC2
            SET @cOutField03 = @cUCC3
            SET @cOutField04 = @cUCC4
            SET @cOutField05 = @cUCC5
            SET @cOutField06 = @cUCC6
            SET @cOutField07 = @cUCC7
            SET @cOutField08 = @cUCC8
            SET @cOutField09 = @cUCC9
            SET @cOutField10 = '' -- @cSKU
            SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
            SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))
            
            EXEC rdt.rdtSetFocusField @nMobile, 1 --UCC1
            GOTO Quit
         END
         
         -- Extended validate
         IF @cExtendedValidateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID,  @cUCC, ' + 
                  ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' + 
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@nInputKey      INT, ' + 
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cToID          NVARCHAR( 18), ' +
                  '@cToLoc         NVARCHAR( 10), ' +
                  '@cFromLoc       NVARCHAR( 10), ' +
                  '@cFromID        NVARCHAR( 18), ' +
                  '@cUCC           NVARCHAR( 20), ' +
                  '@cUCC1          NVARCHAR( 20), ' +
                  '@cUCC2          NVARCHAR( 20), ' +
                  '@cUCC3          NVARCHAR( 20), ' +
                  '@cUCC4          NVARCHAR( 20), ' +
                  '@cUCC5          NVARCHAR( 20), ' +
                  '@cUCC6          NVARCHAR( 20), ' +
                  '@cUCC7          NVARCHAR( 20), ' +
                  '@cUCC8          NVARCHAR( 20), ' +
                  '@cUCC9          NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, '', 
                  @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT 
   
               IF @nErrNo <> 0 
                  GOTO Step_ToLOC_Fail
            END
         END

         -- Prep next screen var
         -- Not reset so that user do not need to rescan the ToID, ToLOC again and again if multiple UCC encounter error
         -- (system will return back to this screen to indicate which UCC encounter the error)
         -- SET @cToID = '' 
         -- SET @cToLOC = ''
         SET @cOutField01 = @cToID
         SET @cOutField02 = @cToLOC

         IF rdt.rdtGetConfig( @nFunc, 'MoveByUCCDefaultCursorToID', @cStorerKey) = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 1 --ToID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 --ToLOC

         -- Go to next screen
         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nPage > 1
      BEGIN
         SET @nPage -= 1
         
         -- Load page
         SELECT 
            @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '', 
            @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = ''
         SELECT
            @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END, 
            @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END, 
            @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END, 
            @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END, 
            @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END, 
            @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END, 
            @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END, 
            @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 8 THEN UCCNo ELSE @cUCC8 END, 
            @cUCC9 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC9 END
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND AddWho = SUSER_SNAME()
            AND RecNo BETWEEN @nPage * @nUCCOnPage - (9-1) AND @nPage * @nUCCOnPage

         SET @cOutField01 = @cUCC1
         SET @cOutField02 = @cUCC2
         SET @cOutField03 = @cUCC3
         SET @cOutField04 = @cUCC4
         SET @cOutField05 = @cUCC5
         SET @cOutField06 = @cUCC6
         SET @cOutField07 = @cUCC7
         SET @cOutField08 = @cUCC8
         SET @cOutField09 = @cUCC9
         SET @cOutField10 = '' -- @cSKU
         SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 --UCC1
      END
      ELSE
      BEGIN
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND AddWho = SUSER_SNAME()
         OPEN @curUCC 
         FETCH NEXT FROM @curUCC INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtMoveUCCLog WHERE RowRef = @nRowRef
            FETCH NEXT FROM @curUCC INTO @nRowRef
         END
         
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign Out
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey

         -- Initiate var before exit to prevent  
         -- next module using isvalidqty having  
         -- overflowed int error coz UCC 20 digits  
         -- (james05)  
         SET @cUCC1 = ''  
         SET @cUCC2 = ''  
         SET @cUCC3 = ''  
         SET @cUCC4 = ''  
         SET @cUCC5 = ''  
         SET @cUCC6 = ''  
         SET @cUCC7 = ''  
         SET @cUCC8 = ''  
         SET @cUCC9 = '' 
         
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
      END
   END

   Step_UCC_Fail:

END
GOTO Quit


/********************************************************************************
Step 2. scn = 809. Move to screen
   ToID  (field01)
   ToLOC (field02)
********************************************************************************/
Step_ToLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField01
      SET @cToLOC = @cInField02

      -- Retain ToID value
      SET @cOutField01 = @cInField01

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 60603
         SET @cErrMsg = rdt.rdtgetmessage( 60603, @cLangCode, 'DSP') --'ToLOC needed'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_ToLOC_Fail
      END

      -- Decode
      -- Standard decode
      SET @cUDF01 = ''
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOutField01,
               @cID           = @cToID   OUTPUT,
               @cUserDefine01 = @cUDF01  OUTPUT,
               @nErrNo        = @nErrNo  OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cType         = 'ID'
            IF @nErrNo <> 0
               GOTO Step_ToLOC_Fail
      END

      IF @cLOCLookUP <> ''
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cToLOC     OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
            GOTO Step_ToLOC_Fail
      END

      -- Get LOC
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60604
         SET @cErrMsg = rdt.rdtgetmessage( 60604, @cLangCode, 'DSP') --'Invalid ToLOC'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_ToLOC_Fail
      END

      -- Validate ToLOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 60605
            SET @cErrMsg = rdt.rdtgetmessage( 60605, @cLangCode, 'DSP') --'Diff facility'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_ToLOC_Fail
         END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLOC, @cFromID, @cUCC, ' +
               ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cToID          NVARCHAR( 18), ' +
               '@cToLoc         NVARCHAR( 10), ' +
               '@cFromLOC       NVARCHAR( 10), ' +
               '@cFromID        NVARCHAR( 18), ' +
               '@cUCC           NVARCHAR( 20), ' +
               '@cUCC1          NVARCHAR( 20), ' +
               '@cUCC2          NVARCHAR( 20), ' +
               '@cUCC3          NVARCHAR( 20), ' +
               '@cUCC4          NVARCHAR( 20), ' +
               '@cUCC5          NVARCHAR( 20), ' +
               '@cUCC6          NVARCHAR( 20), ' +
               '@cUCC7          NVARCHAR( 20), ' +
               '@cUCC8          NVARCHAR( 20), ' +
               '@cUCC9          NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLOC, @cFromID, '',
               @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_ToLOC_Fail
         END
      END

      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_Move_UCC

      -- Confirm
      EXEC rdt.rdt_Move_UCC_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
         @cToID, @cToLoc, @cFromLOC, @cFromID,
         @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9,
         @i OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_Move_UCC
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Recalc page
         SET @nPage = CEILING( @i / (@nUCCOnPage * 1.0))

         SELECT
            @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '',
            @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = ''

         -- Load page
         IF @c2DBarcode = '1'
            SELECT
               @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END,
               @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END,
               @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END,
               @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END,
               @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END,
               @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END,
               @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END,
               @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC8 END
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND AddWho = SUSER_SNAME()
               AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage
         ELSE
            SELECT
               @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END,
               @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END,
               @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END,
               @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END,
               @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END,
               @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END,
               @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END,
               @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 8 THEN UCCNo ELSE @cUCC8 END, 
               @cUCC9 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC9 END
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND AddWho = SUSER_SNAME()
               AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage

         SET @cOutField01 = @cUCC1
         SET @cOutField02 = @cUCC2
         SET @cOutField03 = @cUCC3
         SET @cOutField04 = @cUCC4
         SET @cOutField05 = @cUCC5
         SET @cOutField06 = @cUCC6
         SET @cOutField07 = @cUCC7
         SET @cOutField08 = @cUCC8
         SET @cOutField09 = @cUCC9
         SET @cBarcode    = ''
         SET @cOutField10 = '' -- @cSKU
         SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))

         -- Go back to UCC screen indicate which UCC encountered error
         -- Not reset so that user do not need to rescan the ToID, ToLOC again and again if multiple UCC encounter error
         EXEC rdt.rdtSetFocusField @nMobile, @i

         -- Go to prev screen
         IF @c2DBarcode = '1'
         BEGIN
            SET @nScn = @nScn_2DUCC
            SET @nStep = @nStep_2DUCC
         END
         ELSE
         BEGIN
            SET @nScn = @nScn_UCC
            SET @nStep = @nStep_UCC
         END
         
         GOTO Step_ToLOC_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLOC, @cFromID, ' +
               ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, @cUDF01, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cToID          NVARCHAR( 18), ' +
               '@cToLoc         NVARCHAR( 10), ' +
               '@cFromLOC       NVARCHAR( 10), ' +
               '@cFromID        NVARCHAR( 18), ' +
               '@cUCC1          NVARCHAR( 20), ' +
               '@cUCC2          NVARCHAR( 20), ' +
               '@cUCC3          NVARCHAR( 20), ' +
               '@cUCC4          NVARCHAR( 20), ' +
               '@cUCC5          NVARCHAR( 20), ' +
               '@cUCC6          NVARCHAR( 20), ' +
               '@cUCC7          NVARCHAR( 20), ' +
               '@cUCC8          NVARCHAR( 20), ' +
               '@cUCC9          NVARCHAR( 20), ' +
               '@cUDF01         NVARCHAR( 30), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLOC, @cFromID,
               @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, @cUDF01,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Move_UCC
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_ToLOC_Fail
            END
         END
      END

      -- Clear temp table
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtMoveUCCLog WHERE RowRef = @nRowRef
         FETCH NEXT FROM @curUCC INTO @nRowRef
      END

      COMMIT TRAN rdtfnc_Move_UCC
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Go to next screen
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT
         @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '',
         @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = '', 
         @cToID = '', @cToLOC = ''

      -- Load page     
      IF @c2DBarcode = '1'
      BEGIN
         SELECT
            @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END,
            @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END,
            @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END,
            @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END,
            @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END,
            @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END,
            @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END,
            @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC8 END
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()
            AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage

         -- Prepare prev screen var
         SET @cOutField01 = @cUCC1
         SET @cOutField02 = @cUCC2
         SET @cOutField03 = @cUCC3
         SET @cOutField04 = @cUCC4
         SET @cOutField05 = @cUCC5
         SET @cOutField06 = @cUCC6
         SET @cOutField07 = @cUCC7
         SET @cOutField08 = @cUCC8
         SET @cBarcode    = ''
         SET @cOutField10 = '' -- @cSKU
         SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))

         SET @nScn = @nScn_2DUCC
         SET @nStep = @nStep_2DUCC
      END
      ELSE
      BEGIN
         SELECT
            @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END,
            @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END,
            @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END,
            @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END,
            @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END,
            @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END,
            @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END,
            @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 8 THEN UCCNo ELSE @cUCC8 END, 
            @cUCC9 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC9 END
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()
            AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage
      
         -- Set next field focus
         SET @i = 1 -- start from 1st field
         IF @cInField01 <> '' SET @i = @i + 1
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1
         IF @cInField06 <> '' SET @i = @i + 1
         IF @cInField07 <> '' SET @i = @i + 1
         IF @cInField08 <> '' SET @i = @i + 1
         IF @cInField09 <> '' SET @i = @i + 1
         IF @i > 9 SET @i = 1
            EXEC rdt.rdtSetFocusField @nMobile, @i

         -- Prepare prev screen var
         SET @cOutField01 = @cUCC1
         SET @cOutField02 = @cUCC2
         SET @cOutField03 = @cUCC3
         SET @cOutField04 = @cUCC4
         SET @cOutField05 = @cUCC5
         SET @cOutField06 = @cUCC6
         SET @cOutField07 = @cUCC7
         SET @cOutField08 = @cUCC8
         SET @cOutField09 = @cUCC9
         SET @cOutField10 = '' -- @cSKU
         SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))

         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
   END

   Step_ToLOC_Fail:

END
GOTO Quit


/********************************************************************************
Step 3. scn = 810. Message screen
   Msg
********************************************************************************/
Step_Message:
BEGIN
   -- Go back to SKU screen
   IF rdt.RDTGetConfig( @nFunc, 'MoveByUCCScanFromLOC', @cStorerKey) = '1'
   BEGIN
      SET @nScn  = @nScn_FromLOC
      SET @nStep = @nStep_FromLOC
   END
   ELSE
   BEGIN
      -- Init next screen var
      SET @cUCC1 = ''
      SET @cUCC2 = ''
      SET @cUCC3 = ''
      SET @cUCC4 = ''
      SET @cUCC5 = ''
      SET @cUCC6 = ''
      SET @cUCC7 = ''
      SET @cUCC8 = ''
      SET @cUCC9 = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cToID = ''
      SET @cToLOC = ''
      SET @cFromLOC = ''

      SET @cOutField01 = '' -- UCC1
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' -- UCC9
      SET @cOutField10 = '' -- SKU
      SET @cOutField11 = '' -- Desc1
      SET @cOutField12 = '' -- Desc2
      EXEC rdt.rdtSetFocusField @nMobile, 1

      IF @c2DBarcode = '1'
      BEGIN
         SET @cBarcode = '' 
         SET @nScn = @nScn_2DUCC
         SET @nStep = @nStep_2DUCC
      END
      ELSE
      BEGIN
         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 811. FROM LOC screen
   FROM LOC  (field01)
********************************************************************************/
Step_FromLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01
      SET @cFromID = @cInField02

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 60607
         SET @cErrMsg = rdt.rdtgetmessage( 60607, @cLangCode, 'DSP') --'FROMLOC needed'
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_FromLOC_Fail
      END

      IF @cLOCLookUP <> ''
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cFromLOC   OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
            GOTO Step_FromLOC_Fail
      END

      -- Get LOC
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60608
         SET @cErrMsg = rdt.rdtgetmessage( 60608, @cLangCode, 'DSP') --'Invalid FROMLOC'
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_FromLOC_Fail
      END

      -- Validate ToLOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
      BEGIN
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 60609
            SET @cErrMsg = rdt.rdtgetmessage( 60609, @cLangCode, 'DSP') --'Diff facility'
            SET @cOutField01 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_FromLOC_Fail
         END
      END

      -- (james06)
      IF ISNULL( @cFromID, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                         WHERE Loc = @cFromLOC
                         AND   ID = @cFromID
                         AND   StorerKey = @cStorerKey
                         AND   Qty  > 0) -- can move allocated or picked
         BEGIN
            SET @nErrNo = 60610
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid FromID'
            SET @cOutField01 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_FromLOC_Fail
         END
      END

      -- Initiate var
      SET @cUCC1 = ''
      SET @cUCC2 = ''
      SET @cUCC3 = ''
      SET @cUCC4 = ''
      SET @cUCC5 = ''
      SET @cUCC6 = ''
      SET @cUCC7 = ''
      SET @cUCC8 = ''
      SET @cUCC9 = ''

      SET @cToLOC = ''
      SET @cToID = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- UCC1
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' -- UCC9
      SET @cOutField10 = '' -- SKU
      SET @cOutField11 = '' -- Desc1
      SET @cOutField12 = '' -- Desc2

      IF @c2DBarcode = '1'
      BEGIN
         SET @cBarcode = '' 
         SET @nScn = @nScn_2DUCC
         SET @nStep = @nStep_2DUCC
      END
      ELSE
      BEGIN
         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = SUSER_SNAME()
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtMoveUCCLog WHERE RowRef = @nRowRef
         FETCH NEXT FROM @curUCC INTO @nRowRef
      END

      -- EventLog
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
      SET @cOutField01 = ''
   END

   Step_FromLOC_Fail:
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 812. 2D UCC screen
   UCC1  (field01)
   UCC2  (field02)
   UCC3  (field03)
   UCC4  (field04)
   UCC5  (field05)
   UCC6  (field06)
   UCC7  (field07)
   UCC8  (field08)
   UCC   (V_Barcode)
   SKU   (field10)
   Desc1 (field11)
   Desc2 (field12)
********************************************************************************/
Step_2DUCC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = LEFT( @cBarcode, 20)
      
      -- Validate blank
      IF @cBarcode = ''
      BEGIN
         -- Nothing in log
         IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtMoveUCCLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AddWho = SUSER_SNAME())
         BEGIN
            SET @nErrNo = 60611
            SET @cErrMsg = rdt.rdtgetmessage( 60601, @cLangCode, 'DSP') --'UCC needed'
            GOTO Step_2DUCC_Fail
         END
         
         -- Turn to next page
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey 
               AND AddWho = SUSER_SNAME()
               AND RecNo > @nPage * @nUCCOnPage)
         BEGIN
            SET @nPage += 1
            
            -- Load page
            SELECT 
               @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '', 
               @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = ''
               
            SELECT
               @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END, 
               @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END, 
               @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END, 
               @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END, 
               @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END, 
               @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END, 
               @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END, 
               @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC8 END
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey 
               AND AddWho = SUSER_SNAME()
               AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage
            
            SET @cOutField01 = @cUCC1
            SET @cOutField02 = @cUCC2
            SET @cOutField03 = @cUCC3
            SET @cOutField04 = @cUCC4
            SET @cOutField05 = @cUCC5
            SET @cOutField06 = @cUCC6
            SET @cOutField07 = @cUCC7
            SET @cOutField08 = @cUCC8
            SET @cBarcode    = ''
            SET @cOutField10 = '' -- @cSKU
            SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
            SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))
            
            GOTO Quit
         END
         
         -- Prep next screen var
         SET @cOutField01 = @cToID
         SET @cOutField02 = @cToLOC

         IF rdt.rdtGetConfig( @nFunc, 'MoveByUCCDefaultCursorToID', @cStorerKey) = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 1 --ToID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 --ToLOC

         -- Go to next screen
         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC
         
         GOTO Quit
      END
      
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCC = @cUCC OUTPUT
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cBarcode, ' + 
                  ' @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@nInputKey      INT, ' + 
                  '@cFacility      NVARCHAR( 5),  ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cToID          NVARCHAR( 18), ' +
                  '@cToLoc         NVARCHAR( 10), ' +
                  '@cFromLoc       NVARCHAR( 10), ' +
                  '@cFromID        NVARCHAR( 18), ' +
                  '@cBarcode       NVARCHAR( MAX), ' +
                  '@cUCC           NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT  '
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cBarcode, 
                  @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
               IF @nErrNo <> 0
                  GOTO Step_2DUCC_Fail
            END
         END
      END
      
      IF @cFromLOC = ''
         SET @cFromLOC = NULL
      
      -- Validate UCC
      EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cUCC, -- UCC
         @cStorerKey, 
         @cUCCStatus, -- 1=Received, 3=Alloc
         @cChkLOC = @cFromLOC
      IF @nErrNo <> 0
         GOTO Step_2DUCC_Fail
      
      -- Check UCC scanned
      IF EXISTS( SELECT 1
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND AddWho = SUSER_SNAME())
      BEGIN
         SET @nErrNo = 60612
         SET @cErrMsg = rdt.rdtgetmessage( 60602, @cLangCode, 'DSP') --'UCC DoubleScan'
         GOTO Step_2DUCC_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cUCC, ' + 
               ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' + 
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cToID          NVARCHAR( 18), ' +
               '@cToLoc         NVARCHAR( 10), ' +
               '@cFromLoc       NVARCHAR( 10), ' +
               '@cFromID        NVARCHAR( 18), ' +
               '@cUCC           NVARCHAR( 20), ' +
               '@cUCC1          NVARCHAR( 20), ' +
               '@cUCC2          NVARCHAR( 20), ' +
               '@cUCC3          NVARCHAR( 20), ' +
               '@cUCC4          NVARCHAR( 20), ' +
               '@cUCC5          NVARCHAR( 20), ' +
               '@cUCC6          NVARCHAR( 20), ' +
               '@cUCC7          NVARCHAR( 20), ' +
               '@cUCC8          NVARCHAR( 20), ' +
               '@cUCC9          NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToID, @cToLoc, @cFromLoc, @cFromID, @cUCC, 
               '', '', '', '', '', '', '', '', '', 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Step_2DUCC_Fail
         END
      END

      -- Save to variable
      SET @i = 0
      IF @cOutField01 = '' SELECT @cOutField01 = @cUCC, @cUCC1 = @cUCC, @i = 1 ELSE
      IF @cOutField02 = '' SELECT @cOutField02 = @cUCC, @cUCC2 = @cUCC, @i = 2 ELSE
      IF @cOutField03 = '' SELECT @cOutField03 = @cUCC, @cUCC3 = @cUCC, @i = 3 ELSE
      IF @cOutField04 = '' SELECT @cOutField04 = @cUCC, @cUCC4 = @cUCC, @i = 4 ELSE
      IF @cOutField05 = '' SELECT @cOutField05 = @cUCC, @cUCC5 = @cUCC, @i = 5 ELSE
      IF @cOutField06 = '' SELECT @cOutField06 = @cUCC, @cUCC6 = @cUCC, @i = 6 ELSE
      IF @cOutField07 = '' SELECT @cOutField07 = @cUCC, @cUCC7 = @cUCC, @i = 7 ELSE
      IF @cOutField08 = '' SELECT @cOutField08 = @cUCC, @cUCC8 = @cUCC, @i = 8

      IF @i = 0
      BEGIN
         SET @nPage += 1
         SET @i = 1
                    
         SELECT 
            @cOutField01 = @cUCC, @cUCC1 = @cUCC, 
            @cOutField02 = '',    @cUCC2 = '',
            @cOutField03 = '',    @cUCC3 = '',
            @cOutField04 = '',    @cUCC4 = '',
            @cOutField05 = '',    @cUCC5 = '',
            @cOutField06 = '',    @cUCC6 = '',
            @cOutField07 = '',    @cUCC7 = '',
            @cOutField08 = '',    @cUCC8 = ''
      END
      
      -- Save to log
      INSERT INTO rdt.rdtMoveUCCLog (StorerKey, UCCNo, RecNo) 
      SELECT @cStorerKey, @cUCC, (@nPage-1) * @nUCCOnPage + @i      

      -- Get SKU info
      IF @cUCC <> ''
         SELECT 
            @cSKU = SKU.SKU, 
            @cSKUDescr = SKU.Descr
         FROM dbo.UCC UCC (NOLOCK)
            JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = UCC.StorerKey AND SKU.SKU = UCC.SKU)
         WHERE SKU.StorerKey = @cStorerKey
            AND UCC.UCCNo = @cUCC
            AND UCC.Status = '1' -- Received

      SELECT @nTotalUCC = COUNT(1) 
      FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND AddWho = SUSER_SNAME()

      -- Prepare current screen var
      SET @cBarcode = ''
      SET @cOutField10 = @cSKU
      SET @cOutField11 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField12 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR( 3))

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nPage > 1
      BEGIN
         SET @nPage -= 1
         
         -- Load page
         SELECT 
            @cUCC1 = '', @cUCC2 = '', @cUCC3 = '', @cUCC4 = '', @cUCC5 = '', 
            @cUCC6 = '', @cUCC7 = '', @cUCC8 = '', @cUCC9 = ''
         SELECT
            @cUCC1 = CASE WHEN RecNo % @nUCCOnPage = 1 THEN UCCNo ELSE @cUCC1 END, 
            @cUCC2 = CASE WHEN RecNo % @nUCCOnPage = 2 THEN UCCNo ELSE @cUCC2 END, 
            @cUCC3 = CASE WHEN RecNo % @nUCCOnPage = 3 THEN UCCNo ELSE @cUCC3 END, 
            @cUCC4 = CASE WHEN RecNo % @nUCCOnPage = 4 THEN UCCNo ELSE @cUCC4 END, 
            @cUCC5 = CASE WHEN RecNo % @nUCCOnPage = 5 THEN UCCNo ELSE @cUCC5 END, 
            @cUCC6 = CASE WHEN RecNo % @nUCCOnPage = 6 THEN UCCNo ELSE @cUCC6 END, 
            @cUCC7 = CASE WHEN RecNo % @nUCCOnPage = 7 THEN UCCNo ELSE @cUCC7 END, 
            @cUCC8 = CASE WHEN RecNo % @nUCCOnPage = 0 THEN UCCNo ELSE @cUCC8 END
         FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND AddWho = SUSER_SNAME()
            AND RecNo BETWEEN @nPage * @nUCCOnPage - (@nUCCOnPage-1) AND @nPage * @nUCCOnPage

         SET @cOutField01 = @cUCC1
         SET @cOutField02 = @cUCC2
         SET @cOutField03 = @cUCC3
         SET @cOutField04 = @cUCC4
         SET @cOutField05 = @cUCC5
         SET @cOutField06 = @cUCC6
         SET @cOutField07 = @cUCC7
         SET @cOutField08 = @cUCC8
         SET @cBarcode    = ''
         SET @cOutField10 = '' -- @cSKU
         SET @cOutField11 = '' -- SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField12 = '' -- SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField13 = CAST( @nTotalUCC AS NVARCHAR(3))
      END
      ELSE
      BEGIN
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef
            FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND AddWho = SUSER_SNAME()
         OPEN @curUCC 
         FETCH NEXT FROM @curUCC INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtMoveUCCLog WHERE RowRef = @nRowRef
            FETCH NEXT FROM @curUCC INTO @nRowRef
         END
         
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign Out
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey

         -- Initiate var before exit to prevent  
         -- next module using isvalidqty having  
         -- overflowed int error coz UCC 20 digits  
         -- (james05)  
         SET @cUCC1 = ''  
         SET @cUCC2 = ''  
         SET @cUCC3 = ''  
         SET @cUCC4 = ''  
         SET @cUCC5 = ''  
         SET @cUCC6 = ''  
         SET @cUCC7 = ''  
         SET @cUCC8 = ''  
         SET @cUCC9 = '' 
         
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
      END
   END

   Step_2DUCC_Fail:
      SET @cBarcode = ''
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,

      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,

      V_String1  = @cUCC1,
      V_String2  = @cUCC2,
      V_String3  = @cUCC3,
      V_String4  = @cUCC4,
      V_String5  = @cUCC5,
      V_String6  = @cUCC6,
      V_String7  = @cUCC7,
      V_String8  = @cUCC8,
      V_String9  = @cUCC9,
      V_Barcode  = @cBarcode,

      V_String10 = @cToLOC,
      V_String11 = @cToID,
      V_String12 = @cFromLOC,
      V_String15 = @cFromID,
      V_String16 = @cUCCStatus,
      V_String17 = @cUDF01,

      V_String20 = @cExtendedValidateSP,
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @c2DBarcode,
      V_String23 = @cLOCLookUP,
      V_String24 = @cDecodeSP,

      V_Integer1 = @nTotalUCC,
      V_Integer2 = @nPage,
      V_Integer3 = @nUCCOnPage,

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