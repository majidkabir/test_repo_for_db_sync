SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_MoveByDropID_Pack                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS93812 - Move By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2011-11-17 1.0  Ung      Created                                     */
/* 2011-12-28 1.1  Shong01  Print Packing List when move to 1st Carton  */
/* 2011-12-29 1.2  James    Bug fix on print packlist (james01)         */
/* 2012-01-03 1.3  Ung      Standarize print GS1 to use Exceed logic    */
/* 2012-02-01 1.4  Shong02  Include UPS ODBC Interface                  */
/* 2012-02-06 1.5  Shong    Fixing Bug                                  */
/* 2012-02-22 1.6  ChewKP   Get Error Message from Source (ChewKP01)    */
/* 2012-02-22 1.7  James    Bug fix (james01)                           */
/* 2012-03-06 1.8  Ung      Add event log                               */
/* 2012-03-13 1.9  Ung      SOS236905 Add weight field                  */
/* 2012-04-02 2.0  ChewKP   SOS#239881 -- Check Pick before Pack        */
/*                          (ChewKP02)                                  */
/* 2012-04-30 2.1  Ung      SOS243194 Stamp DropID.DropIDType           */
/* 2012-05-10 2.2  TLTING   Trace Info                                  */
/* 2014-02-11 2.3  ChewKP   SOS#302191 Enhancement for ANF (ChewKP03)   */
/* 2015-05-29 2.4  ChewKP   SOS#343121 V7 Fixes (ChewKP04)              */
/* 2016-02-10 2.5  ChewKP   SOS#359841 Add StorerConfig                 */
/*                          CheckByPickDetailDropID (ChewKP05)          */
/* 2016-09-30 2.6  Ung      Performance tuning                          */
/* 2017-06-06 2.7  ChewKP   WMS-2116 Add ExtendedUpdate @Step4(ChewKP06)*/ 
/* 2018-05-17 2.8  LZG      INC0231664 - Fix lower case issue (ZG01)    */  
/* 2018-10-08 2.9  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_MoveByDropID_Pack] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success   INT,
   @n_err       INT,
   @c_errmsg    NVARCHAR( 255),
   @nCountPS    INT,
   @cToPickSlipNo   NVARCHAR( 10),
   @cFromPickSlipNo NVARCHAR( 10)

DECLARE @cUPS_ODBC_Interface NVARCHAR(1)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName   NVARCHAR(18),
   @cPrinter    NVARCHAR(10),

   @cFromDropID NVARCHAR( 20),
   @cToDropID   NVARCHAR( 20),
   @cMergePLT   NVARCHAR( 1),
   @cSKU        NVARCHAR( 20),
   @cDescr      NVARCHAR( 40),
   @nQTY_Move   INT,
   @nQTY_Bal    INT,
   @nTotal      INT,
   @cPickSlipNo    NVARCHAR( 10),
   @cPrevSKU       NVARCHAR( 20),
   @cPrintGS1Label NVARCHAR( 1),
   @cDecodeLabelNo NVARCHAR( 20),
   @cCheckPickB4Pack NVARCHAR(1), -- (ChewKP02)
   @cOrderKey        NVARCHAR(10),-- (ChewKP02)
   @cExtendedUpdateSP  NVARCHAR(30), -- (ChewKP03)
   @cSQL               NVARCHAR(1000), -- (ChewKP03)
   @cSQLParam          NVARCHAR(1000), -- (ChewKP03)
   @cExtendedValidateSP NVARCHAR(30),  -- (ChewKP03)
   @cCheckByPickDetailDropID NVARCHAR(1), -- (ChewKP05)

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- SHONG02
DECLARE @cLabelNo NVARCHAR( 20)
DECLARE @cGS1TemplatePath NVARCHAR(120)

DECLARE @nSum_Picked    INT,
        @nSum_Packed    INT

-- TraceInfo (Vicky02) - Start
DECLARE    @d_starttime    datetime,
           @d_endtime      datetime,
           @d_step1        datetime,
           @d_step2        datetime,
           @d_step3        datetime,
           @d_step4        datetime,
           @d_step5        datetime,
           @c_col1         NVARCHAR(20),
           @c_col2         NVARCHAR(20),
           @c_col3         NVARCHAR(20),
           @c_col4         NVARCHAR(20),
           @c_col5         NVARCHAR(20),
           @c_TraceName    NVARCHAR(80)

SET @d_starttime = getdate()

SET @c_TraceName = 'rdtfnc_MoveByDropID_Pack'
-- TraceInfo (Vicky02) - End

-- Load RDT.RDTMobRec
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
   @cPrinter    = Printer,

   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   
   @nQTY_Move   = V_Integer1,
   @nQTY_Bal    = V_Integer2,
   @nTotal      = V_Integer3,

   @cFromDropID = V_String1,
   @cToDropID   = V_String2,
   @cMergePLT   = V_String3,
  -- @nQTY_Move   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
  -- @nQTY_Bal    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
  -- @nTotal      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @cPickSlipNo = V_String7,
   @cPrevSKU    = V_String8,
   @cPrintGS1Label = V_String9,
   @cDecodeLabelNo = V_String10,
   @cLabelNo       = V_String11,
   @cExtendedUpdateSP = V_String12,
   @cExtendedValidateSP = V_String13, 
   @cCheckByPickDetailDropID = V_String14, -- (ChewKP05) 

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc IN ( 519, 529 ) -- (ChewKP03)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 519
   IF @nStep = 1 GOTO Step_1   -- Scn = 2960. From DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2961. To Drop ID, merge carton
   IF @nStep = 3 GOTO Step_3   -- Scn = 2962. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 2963. Option (Close carton?)
   IF @nStep = 5 GOTO Step_5   -- Scn = 2964. Weight
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 2960
   SET @nStep = 1

   -- Init var

   -- Get StorerConfig
   SET @cPrintGS1Label = rdt.RDTGetConfig( @nFunc, 'PrintGS1Label', @cStorerKey) -- (ChewKP03)
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   
   -- (ChewKP03)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
   -- (ChewKP05) 
   SET @cCheckByPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckByPickDetailDropID', @cStorerKey)
   IF @cCheckByPickDetailDropID = '0'  
   BEGIN
      SET @cCheckByPickDetailDropID = ''
   END
   
   
            
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cFromDropID = ''
   SET @cMergePLT = 1
   SET @cOutField01 = ''  -- From DropID
   SET @cOutField02 = '1' -- Merge Pallet

   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 2960
   FROM DROPID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromDropID = UPPER(@cInField01)                 -- ZG01
      SET @cMergePLT = @cInField02

      -- Validate blank
      IF @cFromDropID = ''
      BEGIN
         SET @nErrNo = 74601
         SET @cErrMsg = rdt.rdtgetmessage( 74601, @cLangCode, 'DSP') --DropID needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Validate if To DropID closed
      -- (ChewKP03) 
--      IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cFromDropID AND Status = '9')
--      BEGIN
--         SET @nErrNo = 74617
--         SET @cErrMsg = rdt.rdtgetmessage( 74617, @cLangCode, 'DSP') --DropID closed
--         GOTO Step_1_Fail
--      END

      -- Decode label
      IF @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

         SET @cErrMsg = ''
         SET @nErrNo = 0
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cFromDropID
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Step_1_Fail

         SET @cFromDropID = @c_oFieled01
      END

      -- Get PickSlip
      SET @cPickSlipNo = ''
      SET @nCountPS = 0
      
      IF @cCheckByPickDetailDropID = '1'
      BEGIN
         SELECT
            @nCountPS = COUNT( DISTINCT PH.PickHeaderKey),
            @cPickSlipNo = MAX( PH.PickHeaderKey) -- Just to bypass SQL aggregate checking
         FROM dbo.PickDetail PD WITH (NOLOCK)
            INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey )
         WHERE PD.StorerKey = @cStorerKey
            AND PD.DropID = @cFromDropID
            
          -- Check if valid DropID
--         IF @nCountPS = 0
--         BEGIN
--            SET @nErrNo = 74626
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
--            EXEC rdt.rdtSetFocusField @nMobile, 1
--            GOTO Step_1_Fail
--         END   
--         
--         -- Check if DropID in multi PickSlip
--         IF @nCountPS > 1
--         BEGIN
--            SET @nErrNo = 74627
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDMultiPS
--            EXEC rdt.rdtSetFocusField @nMobile, 1
--            GOTO Step_1_Fail
--         END
         
         DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Distinct PD.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey )
         WHERE PD.PickHeaderKey  = @cPickSlipNo
            AND PD.StorerKey  = @cStorerKey
            AND PD.DropID     = @cFromDropID
         ORDER BY PD.OrderKey
   
         OPEN curPD
         FETCH NEXT FROM curPD INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
   
            IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                       WHERE OrderKey = @cOrderKey
                       AND Status < '5')
            BEGIN
                  SET @nErrNo = 74625
                  SET @cErrMsg = rdt.rdtgetmessage( 74625, @cLangCode, 'DSP') --ORDNotPicked
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_1_Fail
   
            END
   
            FETCH NEXT FROM curPD INTO @cOrderKey
         END
         CLOSE curPD
         DEALLOCATE curPD
            
      END
      ELSE
      BEGIN
         SELECT
            @nCountPS = COUNT( DISTINCT PH.PickSlipNo),
            @cPickSlipNo = MAX( PH.PickSlipNo) -- Just to bypass SQL aggregate checking
         FROM dbo.PackHeader PH WITH (NOLOCK)
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.StorerKey = @cStorerKey
            AND PD.DropID = @cFromDropID
   
         -- Check if valid DropID
         IF @nCountPS = 0
         BEGIN
            SET @nErrNo = 74602
            SET @cErrMsg = rdt.rdtgetmessage( 74602, @cLangCode, 'DSP') --Invalid DropID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
   
         -- Check if DropID in multi PickSlip
         IF @nCountPS > 1
         BEGIN
            SET @nErrNo = 74603
            SET @cErrMsg = rdt.rdtgetmessage( 74603, @cLangCode, 'DSP') --DropIDMultiPS
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
   
         --SET @cCheckPickB4Pack = rdt.RDTGetConfig( @nFunc, 'CheckPickB4Pack', @cStorerKey) -- (ChewKP02) -- (ChewKP03)
         
         DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Distinct PD.OrderKey
         FROM dbo.PackDetail PackD WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickslipNo = PackD.PickSlipNo AND
                        PD.StorerKey = PackD.StorerKey)
         WHERE PackD.PickSlipNo  = @cPickSlipNo
            AND PackD.StorerKey  = @cStorerKey
            AND PackD.DropID     = @cFromDropID
         ORDER BY PD.OrderKey
   
         OPEN curPD
         FETCH NEXT FROM curPD INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
   
            IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                       WHERE OrderKey = @cOrderKey
                       AND Status < '5')
            BEGIN
                  SET @nErrNo = 74625
                  SET @cErrMsg = rdt.rdtgetmessage( 74625, @cLangCode, 'DSP') --ORDNotPicked
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_1_Fail
   
            END
   
            FETCH NEXT FROM curPD INTO @cOrderKey
         END
         CLOSE curPD
         DEALLOCATE curPD
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = '' -- ToDropID
      -- Turn off by SHONG on 1-Feb-2012
      SET @cOutField03 = ''
      --SET @cOutField03 = '1' -- Merge carton

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- Logging
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromDropID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = '1'
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 2961
   FROM DROPID     (Field01)
   TO DROPID       (Field12, input)
   MERGE PALLET:   (Field03, input)
   1 = Yes 2 = No
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping 
      SET @cToDropID = UPPER(@cInField02)                   -- ZG01
      SET @cMergePLT = @cInField03

      -- Validate blank
      IF @cToDropID = ''
      BEGIN
         SET @nErrNo = 74604
         SET @cErrMsg = rdt.rdtgetmessage( 74604, @cLangCode, 'DSP') --Need TO DROPID
         GOTO Step_2_Fail
      END

      -- Validate if From DropID = To DropID
      IF @cFromDropID = @cToDropID
      BEGIN
         SET @nErrNo = 74605
         SET @cErrMsg = rdt.rdtgetmessage( 74605, @cLangCode, 'DSP') --BothDropIDSame
         GOTO Step_2_Fail
      END

      -- Validate if To DropID closed
      -- (ChewKP03) 
--      IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID AND Status = '9')
--      BEGIN
--         SET @nErrNo = 74617
--         SET @cErrMsg = rdt.rdtgetmessage( 74617, @cLangCode, 'DSP') --DropID closed
--         GOTO Step_2_Fail
--      END

      -- Get PickSlip
      SET @cToPickSlipNo = ''
      SET @cFromPickSlipNo = ''
      
      IF @cCheckByPickDetailDropID = '1'
      BEGIN
         SELECT TOP 1
                @cToPickSlipNo = PH.PickHeaderKey 
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE  PD.StorerKey = @cStorerKey
            AND PD.DropID = @cToDropID
   
         SELECT TOP 1
                @cFromPickSlipNo = PH.PickHeaderKey
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE  PD.StorerKey = @cStorerKey
            AND PD.DropID = @cFromDropID
         
         SET @nCountPS = 0
         SELECT
            @nCountPS = COUNT( DISTINCT PH.PickHeaderKey),
            @cToPickSlipNo = MAX( PH.PickHeaderKey) -- Just to bypass SQL aggregate checking
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE PH.StorerKey = @cStorerKey
            AND PD.DropID = @cToDropID
      
         -- Check if TO DropID in multi PickSlip
         IF @nCountPS > 1
         BEGIN
            SET @nErrNo = 74628
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDMultiPS
            GOTO Step_2_Fail
         END
            
      END
      ELSE
      BEGIN
         SELECT TOP 1
                @cToPickSlipNo = PickSlipNo
         FROM   dbo.PackDetail PD WITH (NOLOCK)
         WHERE  PD.StorerKey = @cStorerKey
            AND PD.DropID = @cToDropID
   
         SELECT TOP 1
                @cFromPickSlipNo = PickSlipNo
         FROM   dbo.PackDetail PD WITH (NOLOCK)
         WHERE  PD.StorerKey = @cStorerKey
            AND PD.DropID = @cFromDropID
      
         SET @nCountPS = 0
         SELECT
            @nCountPS = COUNT( DISTINCT PH.PickSlipNo),
            @cToPickSlipNo = MAX( PH.PickSlipNo) -- Just to bypass SQL aggregate checking
         FROM dbo.PackHeader PH WITH (NOLOCK)
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.StorerKey = @cStorerKey
            AND PD.DropID = @cToDropID
      
         -- Check if TO DropID in multi PickSlip
         IF @nCountPS > 1
         BEGIN
            SET @nErrNo = 74606
            SET @cErrMsg = rdt.rdtgetmessage( 74606, @cLangCode, 'DSP') --DropIDMultiPS
            GOTO Step_2_Fail
         END
     END
     
     IF ISNULL(RTRIM(@cFromPickSlipNo),'') <> ISNULL(RTRIM(@cToPickSlipNo),'') AND ISNULL(RTRIM(@cToPickSlipNo),'') <> ''
     BEGIN
        SET @nErrNo = 74619
        SET @cErrMsg = rdt.rdtgetmessage( 74619, @cLangCode, 'DSP') --Diff PickSlip
        GOTO Step_2_Fail
     END
      
        
      
      
      -- Retain ToDropID
      SET @cOutField02 = @cToDropID

      -- Validate Option is blank
      IF @cMergePLT = ''
      BEGIN
         SET @nErrNo = 74607
         SET @cErrMsg = rdt.rdtgetmessage( 74607, @cLangCode, 'DSP') --Option needed
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Validate Option
      IF @cMergePLT NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 74608
         SET @cErrMsg = rdt.rdtgetmessage( 74608, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      
      -- Extended Validate SP -- (ChewKP03)
      IF @cExtendedValidateSP <> ''
      BEGIN
         
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
              
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromTote, @cToTote, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3), ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cFromTote      NVARCHAR( 20), ' +
               '@cToTote        NVARCHAR( 20),  ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromDropID, @cToDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0 
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_2_Fail
            END
         END
      END     
      
      -- Merge by carton
      IF @cMergePLT = '1' -- Go to close carton screen
      BEGIN
         
         -- (ChewKP03)
         IF @nFunc = 529 
         BEGIN
              
            IF @cExtendedUpdateSP <> ''
            BEGIN
               
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  
                  SET @cSKU = ''
                    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3), ' +
                     '@cUserName      NVARCHAR( 18), ' +
                     '@cFacility      NVARCHAR( 5), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cPickSlipNo    NVARCHAR( 10), ' +
                     '@cFromDropID    NVARCHAR( 20), ' +
                     '@cToDropID      NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20), ' +
                     '@nQty_Move      INT, ' +
                     '@nErrNo         INT           OUTPUT, ' + 
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'
                     
      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
                  IF @nErrNo <> 0 
                     GOTO QUIT
                     
               END
            END               
         END
         ELSE IF @nFunc = 519 
         BEGIN
            EXECUTE rdt.rdt_MoveByDropID_Pack @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
               @cPickSlipNo,
               @cFromDropID,
               @cToDropID,
               '', -- SKU
               0, -- QTY
               @nErrNo OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max
   
            IF @nErrNo <> 0
               GOTO Quit
            
         END
         
         IF @cCheckByPickDetailDropID <> '1' 
         BEGIN 
            IF EXISTS(SELECT 1 FROM PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '9' )
            BEGIN
               -- Get total picked qty
               SELECT @nSum_Picked = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   [Status] NOT IN ('4','9')
   
               -- Get total packed qty
               SELECT @nSum_Packed = ISNULL( SUM(QTY), 0),
                      @cStorerKey  = ISNULL(MAX(StorerKey),'')
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
   
               IF @nSum_Picked = @nSum_Packed  -- (james01)
               BEGIN
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                     Status = '9'
                  WHERE PickSlipNo = @cPickSlipNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 74620
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'
                     GOTO Step_2_Fail
                  END
               END
            END
         END
         
         IF @nFunc = 519 
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' -- Option

            -- Go to weight screen
            SET @nScn  = @nScn + 3
            SET @nStep = @nStep + 3
            GOTO QUIT 
         END
         ELSE IF @nFunc = 529
         BEGIN
            -- Prep next screen var
            SET @cOutField02 = '' --Option

            -- Go to close carton screen
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2
            GOTO Quit
         END

      END

      -- Merge by SKU
      IF @cMergePLT = '2'
      BEGIN
         -- Prep next screen var
         SET @cSKU = ''
         SET @cPrevSKU = ''
         SET @nQTY_Move = 0

         SET @cOutField01 = @cToDropID
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = '' -- SKU desc
         SET @cOutField04 = '' -- SKU desc
         SET @cOutField05 = '0'
         SET @cOutField06 = '0/0'

         -- Go to SKU/UPC screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cFromDropID = ''
      SET @cOutField01 = '' --FromDropID

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToDropID = ''
      SET @cOutField12 = '' -- To DropID
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen 2962
   FROM DROPID: (Field01)
   SKU/UPC:     (Field02, input)
   SKU DESC1    (Field03)
   SKU DESC2    (Field04)
   QTY MV       (Field05)
   QTY BAL      (Field06)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- Validate blank
      IF @cSKU = ''
      BEGIN
         
         IF @cCheckByPickDetailDropID = '1'
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM PickDetail P (NOLOCK)
                      WHERE DROPID = @cToDropID
                      AND   Qty > 0 ) OR @nQTY_Move = 0
            BEGIN
               IF @cPrevSKU <> '' AND @nQTY_Move > 0
                  GOTO ExecuteMove
   
               -- Prep next screen var
               SET @cOutField01 = '' --Option
   
               -- Go to close carton screen
               SET @nScn  = @nScn + 1
               SET @nStep = @nStep + 1
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM PACKDETAIL P (NOLOCK)
                      WHERE DROPID = @cToDropID
                      AND   Qty > 0 ) OR @nQTY_Move = 0
            BEGIN
               IF @cPrevSKU <> '' AND @nQTY_Move > 0
                  GOTO ExecuteMove
   
               -- Prep next screen var
               SET @cOutField01 = '' --Option
   
               -- Go to close carton screen
               SET @nScn  = @nScn + 1
               SET @nStep = @nStep + 1
               GOTO Quit
            END
         END
         
         IF @nQTY_Move = 0
         BEGIN
            SET @nErrNo = 74609
            SET @cErrMsg = rdt.rdtgetmessage( 74609, @cLangCode, 'DSP') --SKU/UPC needed
            GOTO Step_3_Fail
         END
         ELSE
         BEGIN
            GOTO ExecuteMove
         END
      END

      -- Get SKU count
      DECLARE @nSKUCnt INT
      EXEC [RDT].[rdt_GetSKUCnt]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 74610
         SET @cErrMsg = rdt.rdtgetmessage( 74610, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 74611
         SET @cErrMsg = rdt.rdtgetmessage( 74611, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_3_Fail
      END

      -- Get SKU code thru barcode
      EXEC [RDT].[rdt_GetSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      IF @cCheckByPickDetailDropID = '1'
      BEGIN
         -- Check if SKU exists in DropID
         IF NOT EXISTS (SELECT 1
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromDropID
               AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 74629
            SET @cErrMsg = rdt.rdtgetmessage( 74612, @cLangCode, 'DSP') --SKUNotInFromID
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- Check if SKU exists in DropID
         IF NOT EXISTS (SELECT 1
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromDropID
               AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 74612
            SET @cErrMsg = rdt.rdtgetmessage( 74612, @cLangCode, 'DSP') --SKUNotInFromID
            GOTO Step_3_Fail
         END
      END
      -- Get SKU info
      SELECT @cDescr = S.Descr
      FROM dbo.SKU S (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND SKU = @cSKU

      IF ISNULL(RTRIM(@cPrevSKU),'') = ''
         SET @cPrevSKU = @cSKU

ExecuteMove:

      IF (@cSKU <> @cPrevSKU OR ISNULL(RTRIM(@cSKU),'') = '') AND  @nQTY_Move > 0
      BEGIN
         -- Move QTY
         IF @nFunc = 529 
         BEGIN
      
            
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
               
                  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cPrevSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3), ' +
                     '@cUserName      NVARCHAR( 18), ' +
                     '@cFacility      NVARCHAR( 5), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cPickSlipNo    NVARCHAR( 10), ' +
                     '@cFromDropID    NVARCHAR( 20), ' +
                     '@cToDropID      NVARCHAR( 20),  ' +
                     '@cPrevSKU       NVARCHAR( 20), ' +
                     '@nQty_Move      INT, ' +
                     '@nErrNo         INT           OUTPUT, ' + 
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'
                     
      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cPrevSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                        
                  IF @nErrNo <> 0 
                     GOTO QUIT
               END
            END               
         END
         ELSE IF @nFunc = 519
         BEGIN
            EXECUTE rdt.rdt_MoveByDropID_Pack @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
               @cPickSlipNo,
               @cFromDropID,
               @cToDropID,
               @cPrevSKU,
               @nQTY_Move,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max
   
            IF @nErrNo <> 0
               GOTO Quit
            
         END
         
         SET @cPrevSKU = @cSKU
         SET @nQTY_Move = 0
         SET @nQTY_Bal = 0
         SET @nTotal = 0


         IF ISNULL(RTRIM(@cSKU),'') = ''
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' --Option

            -- Go to close carton screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END

      IF @cCheckByPickDetailDropID = '1' 
      BEGIN
         SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.DropID = @cFromDropID
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
      END
      ELSE
      BEGIN
         SELECT @nTotal = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.DropID = @cFromDropID
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
      END
      SET @nQTY_Bal = @nTotal

      SET @nQTY_Move = @nQTY_Move + 1

      SET @nQTY_Bal = @nQTY_Bal - @nQTY_Move


       -- Get QTY statistic
      IF @cSKU = @cPrevSKU AND (@nQTY_Bal <= 0)
      BEGIN
         -- Move QTY
         IF @nFunc = 529 
         BEGIN
            
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3), ' +
                     '@cUserName      NVARCHAR( 18), ' +
                     '@cFacility      NVARCHAR( 5), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cPickSlipNo    NVARCHAR( 10), ' +
                     '@cFromDropID    NVARCHAR( 20), ' +
                     '@cToDropID      NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20), ' +
                     '@nQty_Move      INT, ' +
                     '@nErrNo         INT           OUTPUT, ' + 
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'
                     
      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
                  IF @nErrNo <> 0 
                     GOTO QUIT
                     
               END
            END               
         END
         ELSE IF @nFunc = 519
         BEGIN
            EXECUTE rdt.rdt_MoveByDropID_Pack @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
               @cPickSlipNo,
               @cFromDropID,
               @cToDropID,
               @cSKU,
               @nQTY_Move,
               @nErrNo OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max
   
            IF @nErrNo <> 0
               GOTO Quit
            
         END
         SET @cPrevSKU = ''
         SET @nQTY_Move = 0
         SET @cDescr = ''
         SET @nQTY_Bal = 0
         SET @nTotal = 0


      END
      
      IF @cCheckByPickDetailDropID = '1'
      BEGIN
         IF NOT EXISTS(SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.DropID = @cFromDropID
                  AND PD.StorerKey = @cStorerKey)
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' --Option
   
            -- Go to close carton screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS(SELECT 1
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  WHERE PD.DropID = @cFromDropID
                  AND PD.StorerKey = @cStorerKey)
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' --Option
   
            -- Go to close carton screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END


      -- Remain in current screen
      SET @cSKU = ''
      SET @cOutField01 = @cToDropID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
      SET @cOutField05 = CAST( @nQTY_Move AS NVARCHAR( 5))
      SET @cOutField06 = CAST( @nQTY_Bal AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

      -- Remain in current screen
      -- SET @nScn  = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromDropID
      SET @cOutField02 = ''
      SET @cOutField03 = @cMergePLT

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromDropID
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 2963
   Close carton?
   1 = YES
   2 = NO
   OPTION (Field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      SET @nSum_Picked = 0
      SET @nSum_Packed = 0

      -- Screen mapping
      SET @cOption = @cInField02

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 74613
         SET @cErrMsg = rdt.rdtgetmessage( 74613, @cLangCode, 'DSP') --Option needed
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 74614
         SET @cErrMsg = rdt.rdtgetmessage( 74614, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         -- Check if login with label printer
         IF @cPrinter = ''
         BEGIN
            SET @nErrNo = 74615
            SET @cErrMsg = rdt.rdtgetmessage( 74615, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO Quit
         END

         -- Get LabelNo
         -- DECLARE @cLabelNo NVARCHAR( 20)
         SELECT TOP 1
            @cLabelNo = LabelNo,
            @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cToDropID

         SET @nErrNo    = 0
         SET @b_success = 0
         
         

         IF EXISTS(SELECT 1 FROM PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '9' )
         BEGIN
            -- Get total picked qty
            SELECT @nSum_Picked = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   [Status] NOT IN ('4','9')

            -- Get total packed qty
            SELECT @nSum_Packed = ISNULL( SUM(QTY), 0),
                   @cStorerKey  = ISNULL(MAX(StorerKey),'')
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            IF @nSum_Picked = @nSum_Packed  -- (james01)
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  Status = '9'
               WHERE PickSlipNo = @cPickSlipNo
               IF @@ERROR <> 0
             BEGIN
                  SET @nErrNo = 74621
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'
                  GOTO Quit
               END
            END
         END
         
         -- (ChewKP06) 
         IF @cExtendedUpdateSP <> ''
         BEGIN
            
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               
               SET @cSKU = ''
                 
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cPickSlipNo    NVARCHAR( 10), ' +
                  '@cFromDropID    NVARCHAR( 20), ' +
                  '@cToDropID      NVARCHAR( 20),  ' +
                  '@cSKU           NVARCHAR( 20), ' +
                  '@nQty_Move      INT, ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                  
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cToDropID, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
               IF @nErrNo <> 0 
                  GOTO QUIT
                  
            END
         END  


         -- Prepare next screen var
         -- (ChewKP03)
         IF @nFunc = 529 
         BEGIN
            SET @cOutField01 = '' 

            -- Go to weight screen
            SET @nScn  = @nScn - 3
            SET @nStep = @nStep - 3
   
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cOutField01 = '' --Weight

            -- Go to weight screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
   
            GOTO Quit
         END
      END
   END

   -- Back to FROM DropID screen
   SET @cOutField01 = '' --FromDropID
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 2964
   Weight (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cWeight NVARCHAR(10)

      -- Screen mapping
      SET @cWeight = @cInField01

      -- Check if weight is valid
      IF RDT.rdtIsValidQTY( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 74622
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
         GOTO Quit
      END

      -- Get ToDropID carton no
      DECLARE @nCartonNo INT
      SET @nCartonNo = 0
      SELECT @nCartonNo = ISNULL(CartonNo,0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
            AND DropID = @cToDropID
--
--      IF @nCartonNo = 0
--      BEGIN
--         SET @nCartonNo = 0
--         SELECT @nCartonNo = ISNULL(CartonNo,0)
--         FROM dbo.PackDetail WITH (NOLOCK)
--         WHERE PickSlipNo = @cPickSlipNo
--               AND DropID = @cFromDropID
--      END

      IF @nCartonNo = 0
      BEGIN
         SET @nErrNo = 74622
         SET @cErrMsg = 'Carton# = 0' --Invalid weight
         GOTO Quit
      END

      -- Insert PackInfo
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo)
      BEGIN
         SET @d_step1 = GETDATE()   -- (tlting)
         SET @c_Col5 = 'Y -PackInfo'
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)
         VALUES ( @cPickSlipNo, @nCartonNo, CAST( @cWeight AS FLOAT))
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74623
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
            GOTO Quit
         END
         SET @d_step1 = GETDATE() - @d_step1 -- (tlting)
      END
      ELSE
      BEGIN
         SET @d_step1 = GETDATE()   -- (tlting)
         SET @c_Col5 = 'N -PackInfo'
         UPDATE dbo.PackInfo SET
            Weight = CAST( @cWeight AS FLOAT)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74624
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail
            GOTO Quit
         END
         SET @d_step1 = GETDATE() - @d_step1 -- (tlting)
      END

   ------------------------------------------------------
   ---  Print Label And Packing Start                ----
   ------------------------------------------------------
         -- Check if login with label printer
         IF @cPrinter = ''
         BEGIN
            SET @nErrNo = 74615
            SET @cErrMsg = rdt.rdtgetmessage( 74615, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO Quit
         END

         -- Get LabelNo
         SET @cLabelNo = ''
         SELECT TOP 1
            @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cToDropID

         -- Print GS1 label
         IF @cPrintGS1Label = '1'   -- GS1 label turn on
         BEGIN
            -- Get GS1 template file
            SET @cGS1TemplatePath = ''
            SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK)
            WHERE ConfigKey = 'GS1TemplatePath'
            SET @d_step2 = GETDATE() -- (tlting)
            -- Print GS1 label
            SET @b_success = 0
            EXEC dbo.isp_PrintGS1Label
               @c_PrinterID = @cPrinter,
               @c_BtwPath   = @cGS1TemplatePath,
               @b_Success   = @b_success OUTPUT,
               @n_Err       = @nErrNo    OUTPUT,
               @c_Errmsg    = @cErrMsg   OUTPUT,
               @c_LabelNo   = @cLabelNo
            IF @nErrNo <> 0 OR @b_success = 0
            BEGIN
               --SET @nErrNo = 74618  (ChewKP01)
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Print GS1 Fail'  -- (ChewKP01)
               --GOTO Step_2_Fail
            END
            SET @d_step2 = GETDATE() - @d_step2 -- (tlting)
            -- Insert into DropID
            IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToDropID)
            BEGIN
               INSERT INTO dbo.DropID (DropID, LabelPrinted, [Status], PickSlipNo, DropIDType)
               VALUES (@cToDropID, '1', '9', @cPickSlipNo, 'NON-WCS')
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 74616
                  SET @cErrMsg = rdt.rdtgetmessage( 74616, @cLangCode, 'DSP') --InsDropIDFail
                  GOTO Quit
               END
            END
         END -- Print GS1 Label = 'Y'
         SET @d_step3 = GETDATE() -- (tlting)
         -- Shong01
         EXEC rdt.rdt_MoveByDropID_PrintPackList
              @nMobile,
              @cToDropID,
              @cStorerKey,
              @cLangCode,
              @nErrNo    OUTPUT,
              @cErrMsg   OUTPUT

   ------------------------------------------------------
   ---  Print Label And Packing End                  ----
   ------------------------------------------------------
      SET @d_step3 = GETDATE() - @d_step3 -- (tlting)
      SET @d_step4 = GETDATE()  -- (tlting)
      -- Send rate from Agile (carrier consolidation system)
      EXEC dbo.isp1156P_Agile_Rate
          @cPickSlipNo
         ,@nCartonNo
         ,@cLabelNo
         ,@b_Success OUTPUT
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0 OR @b_Success <> 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END
      SET @d_step4 = GETDATE() - @d_step4 -- (tlting)
      -- Shong02 UPS ODBC Interface
      SET @cUPS_ODBC_Interface = '0'
      SET @cUPS_ODBC_Interface = rdt.RDTGetConfig( 519, 'UPS_ODBC_Interface', @cStorerKey)
      IF @cUPS_ODBC_Interface = '1'
      BEGIN
         SET @d_step5 = GETDATE() -- (tlting)
         EXEC isp_GenUPSInfor
           @cDropID = @cToDropID,
           @cLabelNo = '',
           @cStorerKey = @cStorerKey,
           @nErrNo = @nErrNo OUTPUT,
           @cErrMsg = @cErrMsg OUTPUT
         SET @d_step5 = GETDATE() - @d_step5 -- (tlting)
      END

      SET @c_Col1 = @cPickSlipNo
      SET @c_Col2 = @cToDropID
      SET @c_Col3 = @nCartonNo
      SET @c_Col4 = @cLabelNo


      SET @d_endtime = GETDATE()
      INSERT INTO TraceInfo VALUES
            (RTRIM(@c_TraceName), @d_starttime, @d_endtime
            ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
            ,CONVERT(CHAR(12),@d_step1,114)
            ,CONVERT(CHAR(12),@d_step2,114)
            ,CONVERT(CHAR(12),@d_step3,114)
            ,CONVERT(CHAR(12),@d_step4,114)
            ,CONVERT(CHAR(12),@d_step5,114)
                ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL
      SET @c_Col1  = ''
      SET @c_Col2  = ''
      SET @c_Col3  = ''
      SET @c_Col4  = ''
      SET @c_Col5  = ''

      -- Prepare next screen var
      SET @cOutField01 = '' --FromDropID

      -- Back to FROM DropID screen
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,-- (Vicky06)
      Printer    = @cPrinter,

      V_SKU      = @cSKU,
      V_SKUDescr = @cDescr,
      
      V_Integer1 = @nQTY_Move,
      V_Integer2 = @nQTY_Bal,
      V_Integer3 = @nTotal,

      V_String1  = @cFromDropID,
      V_String2  = @cToDropID,
      V_String3  = @cMergePLT,
      --V_String4  = @nQTY_Move,
      --V_String5  = @nQTY_Bal,
      --V_String6  = @nTotal,
      V_String7  = @cPickSlipNo,
      V_String8  = @cPrevSKU,
      V_String9  = @cPrintGS1Label,
      V_String10 = @cDecodeLabelNo,
      V_String11 = @cLabelNo,
      V_String12 = @cExtendedUpdateSP,
      V_String13 = @cExtendedValidateSP,
      V_String14 = @cCheckByPickDetailDropID, -- (ChewKP05) 

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END

GO