SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ReprintCarrierLabel                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS93812 - Move By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2011-11-17 1.0  Ung      SOS239209 Created. Reprint carrier label    */
/* 2012-03-23 1.1  James    Add extra validation (james01)              */
/* 2012-03-27 1.2  ChewKP   Update TransmitFlag when all label for Order*/
/*                          Printed (ChewKP01)                          */
/* 2012-04-04 1.3  Ung      Fix child ID not check if invalid (ung01)   */
/* 2012-04-05 1.4  ChewKP   New Parameter to Reprint Carrier Label only */
/*                          (ChewKP02)                                  */
/* 2016-09-30 1.5  Ung      Performance tuning                          */ 
/* 2018-11-13 1.6  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ReprintCarrierLabel] (
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
   @nCountPS    INT

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

   @cDropID     NVARCHAR( 20),
   @cChildID    NVARCHAR( 20),
   @nRemain     INT,
   @nTotal      INT,
   @cDecodeLabelNo NVARCHAR( 20),

   @cPickSlipNo   NVARCHAR( 10),      -- (james01)
   @cType         NVARCHAR( 10),      -- (james01)
   @nCartonNo     INT,            -- (james01)
   @cLabelNo      NVARCHAR( 20),      -- (james01)
   @cOrderKey     NVARCHAR( 10),      -- (james01)
   @cMasterChildID NVARCHAR(18),      -- (ChewKP02)



   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

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
   
   @nRemain     = V_Integer1,
   @nTotal      = V_Integer2,

   @cDropID     = V_String1,
   @cChildID    = V_String2,
  -- @nRemain     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
  -- @nTotal      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @cDecodeLabelNo = V_String5,
   @cType       = V_String6,        -- (james01)

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr03 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr05 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr07 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr09 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr11 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr13 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr02 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr04 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr06 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr08 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr10 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr12 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1792
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1792
   IF @nStep = 1 GOTO Step_1   -- Scn = 3060. DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3061. Child ID
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3060
   SET @nStep = 1

   -- Init var

   -- Get StorerConfig
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

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
   SET @cDropID = ''
   SET @cOutField01 = ''  -- DropID

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


/********************************************************************************
Step 1. Screen = 3060
   DROPID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01

      -- Validate blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 75751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

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
            ,@c_LabelNo    = @cDropID
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

         SET @cDropID = @c_oFieled01
      END

      -- (james01)
      -- Get PickSlip by RefNo (master carton)
      SET @cType = ''
      SET @cPickSlipNo = ''
      SELECT TOP 1
         @cPickSlipNo = PickSlipNo,
         @nCartonNo = CartonNo,
         --@cDropID = DropID, -- (ChewKP02)
         @cType = 'MASTER'
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND (RefNo = @cDropID OR RefNo2 = @cDropID) -- RefNo2 is the GS1# for Master

      -- Get PickSlipNo by DropID (child carton)
      IF @cPickSlipNo = ''
      BEGIN
         SELECT TOP 1
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo,
            @cDropID = DropID,
            @cType = 'CHILD'
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cDropID
            AND RefNo <> ''
      END

      -- Get PickSlip by LabelNo (normal carton)
      IF @cPickSlipNo = ''
      BEGIN
         SELECT TOP 1
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo,
            @cDropID = DropID,
            @cType = 'NORMAL'
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND @cDropID IN (DropID, LabelNo)
      END

      -- Check if valid ID
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 75759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID 
         GOTO Step_1_Fail
      END

      -- Check if valid DropID
      IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 75761 -- (ChewKP02)
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
         GOTO Step_1_Fail
      END

      -- Check if login with label printer
      IF @cPrinter = ''
      BEGIN
         SET @nErrNo = 75753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
         GOTO Quit
      END

      -- Get counter
      SET @nRemain = 0
      SET @nTotal = 0
      IF @cType IN ('NORMAL', 'MASTER')
      BEGIN
         SET @nRemain = 1
         SET @nTotal = 1
      END
      BEGIN
         SELECT @nRemain = COUNT( 1) FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND LabelPrinted <> 'Y'
         SELECT @nTotal  = COUNT( 1) FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID
      END

      -- Prep next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = '' -- ChildID
      SET @cOutField03 = CAST( @nRemain AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

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
      SET @cDropID = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 3061
   DROPID     (Field01)
   CHILDID    (Field12, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cChildID = @cInField02

      -- Check ChildID blank
      IF @cChildID = ''
      BEGIN
         SET @nErrNo = 75754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CHILDID
         GOTO Step_2_Fail
      END

      -- Check if DropID = ChildID
      IF @cDropID = @cChildID
      BEGIN
         SET @nErrNo = 75755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Both ID same
         GOTO Step_2_Fail
      END

      IF @cType = 'CHILD'
      BEGIN
         -- Check if validate ChildID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND ChildID = @cChildID)
         BEGIN
            SET @nErrNo = 75756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidChildID
            GOTO Step_2_Fail
         END
     
         -- Check if ChildID printed  
         IF EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND ChildID = @cChildID AND LabelPrinted = 'Y')  
         BEGIN  
            SET @nErrNo = 75757  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Printed  
            GOTO Step_2_Fail  
         END  
      END
      
      SET @cPickSlipNo = ''  
      SET @nCartonNo = 0  
      SET @cLabelNo = ''  
      SET @cOrderKey = ''  
  
      -- Get LabelNo  
      SELECT TOP 1  
         @cPickSlipNo = PickSlipNo,   
         @nCartonNo = CartonNo,   
         @cLabelNo = LabelNo  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND LabelNo = @cChildID  
         
      IF @cLabelNo = '' -- (ung01)
      BEGIN
         SET @nErrNo = 75760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidChildID
         GOTO Step_2_Fail
      END

      -- Get OrderKey
      SELECT @cOrderKey = OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND CaseID = @cChildID

      -- Get GS1 template file
      DECLARE @cGS1TemplatePath NVARCHAR(120)
      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

      -- Print GS1 label
      SET @b_success = 0
      EXEC dbo.isp_PrintGS1Label
         @c_PrinterID = @cPrinter,
         @c_BtwPath   = @cGS1TemplatePath,
         @b_Success   = @b_success OUTPUT,
         @n_Err       = @nErrNo    OUTPUT,
         @c_Errmsg    = @cErrMsg   OUTPUT,
         @c_LabelNo   = @cLabelNo,
         @c_ReprintCarrier = '1' -- Reprint Carrier Label Only (ChewKP02)
         
      IF @nErrNo <> 0 OR @b_success = 0
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Print GS1 Fail'

      IF @cType = 'CHILD'
      BEGIN
         -- Update into ChildID
         UPDATE dbo.DropIDDetail SET
            LabelPrinted = 'Y'
         WHERE DropID = @cDropID
            AND ChildID = @cChildID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 75758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIDFail
            GOTO Step_2_Fail
         END
      END
      
      -- (ChewKP02)
      IF @cType = 'MASTER' 
      BEGIN
         
         SET @cMasterChildID = ''
         SELECT @cMasterChildID = DropID
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE LabelNo = @cChildID
         AND RefNo = @cDropID
         AND PickSlipNo = @cPickSlipNo
         
          -- Update into ChildID
         UPDATE dbo.DropIDDetail SET
            LabelPrinted = 'Y'
         WHERE DropID = @cDropID
            AND ChildID = @cMasterChildID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 75762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIDFail
            GOTO Step_2_Fail
         END
      END

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

      DECLARE @cTransmitLogKey NVARCHAR( 10)
      DECLARE @cTransmitFlag   NVARCHAR( 5)
      SET @cTransmitLogKey = ''
      SET @cTransmitFlag = ''


      -- (ChewKP01)
      -- Update TransmitLog3 when all Label Printed




      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND LabelPrinted <> 'Y' )
      BEGIN

           -- Get transmitlog
         SELECT TOP 1
            @cTransmitLogKey = TransmitLogKey,
            @cTransmitFlag = TransmitFlag
         FROM dbo.TransmitLog3 WITH (NOLOCK)
         WHERE TableName = 'CHANGE_CARRIER_LOG'
            AND Key1 = @cOrderKey
            AND Key3 = @cStorerKey
         ORDER BY TransmitLogKey DESC -- Get latest record

         -- Update transmitlog
         IF @cTransmitLogKey <> '' AND @cTransmitFlag = '0'
            UPDATE TransmitLog3 SET
               TransmitFlag = '9'
            WHERE TransmitLogKey = @cTransmitLogKey


         -- Update TransmitFlag = 9 prior to the Latest TransmitLogKey

         Update TransmitLog3
         SET TransmitFlag = '9'
         WHERE TableName = 'CHANGE_CARRIER_LOG'
         AND Key1 = @cOrderKey
         AND Key3 = @cStorerKey
         AND TransmitLogKey < @cTransmitLogKey
         AND TransmitFlag = '0'


      END


      -- Get counter
      SET @nRemain = 0
      SET @nTotal = 0
      IF @cType IN ('NORMAL', 'MASTER')
      BEGIN
         SET @nRemain = 1
         SET @nTotal = 1
      END
      ELSE
      BEGIN
         SELECT @nRemain = COUNT( 1) FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND LabelPrinted <> 'Y'
         SELECT @nTotal  = COUNT( 1) FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID
      END

      -- Prep next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = '' -- ChildID
      SET @cOutField03 = CAST( @nRemain AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

      -- Prep next screen var
      SET @cOutField01 = '' -- DropID

      -- Remain in current screen
      -- SET @nScn  = @nScn - 1
      -- SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cDropID = ''
      SET @cOutField01 = '' --DropID

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cChildID = ''
      SET @cOutField12 = '' -- To DropID
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
      -- UserName   = @cUserName,
      Printer    = @cPrinter,
      
      V_Integer1 = @nRemain,
      V_Integer2 = @nTotal,

      V_String1  = @cDropID,
      V_String2  = @cChildID,
      --V_String3  = @nRemain,
      --V_String4  = @nTotal,
      V_String5  = @cDecodeLabelNo,
      V_String6  = @cType,       -- (james01)

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr03  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr05  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr07  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr09  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr11  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr13  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr02  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr04  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr06  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr08  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr10  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr12  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO