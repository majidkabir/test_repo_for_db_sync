SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/************************************************************************/
/* Store procedure: rdtfnc_Capture_HandOverDate                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Capture OverDate                                            */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-10-17 1.0  YeeKung    WMS-10852 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Capture_HandOverDate] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cUserName           NVARCHAR(18),
   @cPrinter            NVARCHAR( 10),
   @cOrderkey           NVARCHAR( 20),
   @cCompanyDec         NVARCHAR( 60),
   @cDeliveryDate       DATETIME,
   @cRoute              NVARCHAR( 12),
   @cTtlCarton          INT,
   @cOption             NVARCHAR( 1),
   @cHandOverDate       DATETIME,
   @cOrderStatus        NVARCHAR( 1),
   @cPODStatus          NVARCHAR( 1),
   @cCurrentdate        DATETIME,

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
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cPrinter      = Printer,
   @cUserName     = UserName,

   @cOrderkey     = V_String1,
   @cRoute        = V_String4,
   @cTtlCarton    = V_String5,
   @cOption       = V_String6,

   @cCompanyDec   = V_String41,

   @cDeliveryDate = V_DateTime1,
   @cHandOverDate = V_DateTime2,
   @cCurrentdate  = V_DateTime3,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 932 -- Handover data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- Scn = 5610 Orderkey
   IF @nStep = 2 GOTO Step_2   -- Scn = 5611 Capture HandOver
   IF @nStep = 3 GOTO Step_3   -- Scn = 5612 Overwrite HandOver
   IF @nStep = 4 GOTO Step_4   -- Scn = 5613 Successful overwrite
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 932. Menu
********************************************************************************/
Step_0:
BEGIN

   -- Set the entry point
   SET @nScn = 5610
   SET @nStep = 1

   -- Prepare next screen var
   SET @cOutField01 = '' -- Orderkey

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

END
GOTO Quit

/********************************************************************************
Step 1. Screen = 5610
   Orderkey  (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
    -- Screen mapping
      SET @cOrderkey = @cInField01

      IF ISNULL(@cOrderkey,'')=''
      BEGIN
         SET @nErrNo = 145251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orderkey Needed
         GOTO Step_1_Fail
      END

      SELECT   @cOrderStatus=status,
               @cCompanyDec=C_Company,
               @cDeliveryDate=DeliveryDate,
               @cRoute=Route
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE orderkey=@cOrderkey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 145252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid orders
         GOTO Step_1_Fail
      END

      IF (@cOrderStatus <>9)
      BEGIN
         SET @nErrNo = 145253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipNotConfirm
         GOTO Step_1_Fail
      END

      SELECT @cPODStatus=status
      FROM dbo.POD WITH (NOLOCK)
      WHERE ORDERKEY=@cOrderkey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 145254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid orders
         GOTO Step_1_Fail
      END

      IF (@cPODStatus = '1')
      BEGIN
         SET @nErrNo = 145255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Cancel
         GOTO Step_1_Fail
      END

      IF (@cPODStatus in ('2','3','4','7','8','A'))
      BEGIN
         SET @nErrNo = 145256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order delivered
         GOTO Step_1_Fail
      END

      SELECT @cTtlCarton= TotalCartons
      FROM dbo.MBOLDETAIL WITH (NOLOCK)
      WHERE OrderKey=@cOrderkey

      SET @cOutField01=@cOrderkey
      SET @cOutField02= SUBSTRING( @cCompanyDec,1,20)
      SET @cOutField03= SUBSTRING( @cCompanyDec,21,40)
      SET @cOutField04= rdt.rdtFormatDate( @cDeliveryDate)
      SET @cOutField05= @cRoute
      SET @cOutField06= CAST(@cTtlCarton AS NVARCHAR(5))

      SET @nStep= @nStep +1
      SET @nScn = @nScn + 1

      GOTO QUIT

   END

   IF @nInputkey = 0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      GOTO Quit
   END

   Step_1_Fail:
   BEGIN
      SET @cOrderKey=''
      SET @cOutField01=''
      SET @cCompanyDec=''
      SET @cDeliveryDate=''
      SET @cRoute=''
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 5611
   Orderkey  (Field01)
   Company:
   (Field02)
   (Field03)
   DeliveryDate:
   (Field04)
   Route: (Field05)
   TotalCartons: (Field06)

   1=Capture Handover
   0-Exit
   Option: (Field07)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField07

      SET @cCurrentdate = GETDATE()

      IF ISNULL(@cOption,'')=''
      BEGIN
         SET @nErrNo = 145257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Required
         GOTO Step_2_Fail
      END

      IF (@cOption NOT IN ('1','9'))
      BEGIN
         SET @nErrNo = 145258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         GOTO Step_2_Fail
      END

      IF @cOption = '1'
      BEGIN
         SELECT @cHandOverDate=Trackdate05
         FROM dbo.POD WITH (NOLOCK)
         WHERE ORDERKEY=@cOrderkey

         IF ISNULL(@cHandOverDate,'')=''
         BEGIN

            BEGIN TRAN T1

               UPDATE dbo.POD WITH (ROWLOCk)
               SET Trackdate05 = @cCurrentdate
               WHERE orderkey=@cOrderkey

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 145262
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPODFail
                  GOTO Step_2_Fail
               END

            COMMIT TRAN T1

            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType = '3', -- record members
               @cUserID     = @cUserName,
               @nMobileNo   = @nMobile,
               @nFunctionID = @nFunc,
               @cFacility   = @cFacility,
               @cStorerKey  = @cStorerkey,
               @cOrderkey   = @cOrderkey,
               @cRefno1     = @cUserName,
               @cRefno2     = @cHandOverDate,
               @cRefno3     = @cCurrentdate

            SET @nStep=@nStep+2
            SET @nScn=@nScn+2
         END
         ELSE
         BEGIN
            SET @cOutField08=RDT.RDTFORMATDATE(@cHandOverDate)
            SET @nStep=@nStep+1
            SET @nScn=@nScn+1
         END

      END
      ELSE IF @cOption = '9'
      BEGIN
         SET @nScn  = @nScn-1
         SET @nStep = @nStep-1
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cCompanyDec=''
         SET @cDeliveryDate=''
         SET @cOrderkey=''
         SET @cRoute=''
         SET @cTtlCarton=''
         SET @cOption=''
      END

      GOTO Quit

   END

   IF @nInputkey = 0
   BEGIN

      SET @nScn  = @nScn-1
      SET @nStep = @nStep-1
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cCompanyDec=''
      SET @cDeliveryDate=''
      SET @cOrderkey=''
      SET @cRoute=''
      SET @cTtlCarton=''
      SET @cOption=''

      GOTO Quit
   END

   STEP_2_Fail:
   BEGIN
     SET @cOption=''
     SET @cOutField07=''
   END

END
GOTO Quit

/********************************************************************************
Step 3. Screen = 5612
   Orderkey  (Field01)
   HandOverDate:
   (Field08)
   Overwrite
   Handover Date?

   1=Yes
   0=Exit
   Option: (Field09)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField09

      IF ISNULL(@cOption,'')=''
      BEGIN
         SET @nErrNo = 145259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Require
         GOTO Step_3_Fail
      END

      IF (@cOption NOT IN ('1','9'))
      BEGIN
         SET @nErrNo = 145260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         GOTO Step_3_Fail
      END

      IF @cOption = '1'
      BEGIN

         BEGIN TRAN T1

            UPDATE dbo.POD WITH (ROWLOCk)
            SET Trackdate05 = @cCurrentdate
            WHERE orderkey=@cOrderkey

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 145261
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPODFail
               GOTO Step_3_Fail
            END

         COMMIT TRAN T1

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '3', -- record members
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey,
            @cOrderkey   = @cOrderkey,
            @cRefno1     = @cUserName,
            @cRefno2     = @cHandOverDate,
            @cRefno3     = @cCurrentdate

        SET @nstep=@nstep+1
        SET @nScn=@nScn+1
      END
      ELSE IF @cOption = '9'
      BEGIN
         SET @nScn  = @nScn-2
         SET @nStep = @nStep-2
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cCompanyDec=''
         SET @cDeliveryDate=''
         SET @cOrderkey=''
         SET @cRoute=''
         SET @cTtlCarton=''
         SET @cOption=''
      END

      GOTO Quit
   END

   IF @nInputkey = 0
   BEGIN

      SET @nScn  = @nScn-1
      SET @nStep = @nStep-1
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cHandOverDate=''
      SET @cOption=''

      GOTO Quit
   END

   STEP_3_FAIL:
   BEGIN
     SET @cOption=''
     SET @cOutField08=''
   END
END
GOTO Quit

/********************************************************************************
Step 4. Screen = 5613
   Orderkey  (Field01)
   Capture
   Handover Date
   Successfully!
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey in (0,1)-- ENTER
   BEGIN
      SET @cOutfield01=''
      SET @cOutfield02=''
      SET @cOutfield03=''
      SET @cOutfield04=''
      SET @cOutfield05=''
      SET @cOutfield06=''
      SET @cOutfield07=''
      SET @cOutfield08=''
      SET @cOutfield09=''

      SET @cDeliveryDate =''
      SET @cOrderkey=''

      SET @nScn=@nScn-3
      SET @nStep=@nStep-3
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      Printer        = @cPrinter,
      UserName       = @cUserName,

      V_String1      = @cOrderkey    ,
      V_String4      = @cRoute       ,
      V_String5      = @cTtlCarton   ,
      V_String6      = @cOption      ,


      V_String41     = @cCompanyDec  ,

      V_DateTime1    = @cDeliveryDate,
      V_DateTime2    = @cHandOverDate,
      V_DateTime3    = @cCurrentdate,

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