SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Ecomm_Dispatch                                    */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175743 - EComm Order Despatch                                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-14 1.0  AQSKC    Created                                          */
/* 2010-06-24 1.0  AQSKC    Check if tote completed scanning at screen 1     */
/*                          and change rdtEcommLog retrieval logic (KC01)    */
/* 2010-07-19 1.0  AQSKC    Do not include picks wih status '4' (shortpick)  */
/*                          and change to WCSRouting update (Kc02)           */
/* 2010-07-22 1.1  Vicky    To cater Paper Printer since printing both Label */
/*                          and Paper Report (Vicky01)                       */
/* 2010-07-27 1.2  AQSKC    Bug Fix (Kc03)                                   */
/* 2010-07-27 1.3  AQSKC    Update DropID status to '9' and standardize      */
/*                          message std (Kc04)                               */
/* 2010-07-29 1.4  AQSKC    Remove update dropid status to '9' - will be     */
/*                          handled by MBOL ship (Kc05)                      */
/* 2010-07-29 1.5  AQSKC    Add parameter username when call sp              */
/*                          rdt_EcommDispatch_Confirm (Kc06)                 */
/* 2010-07-29 1.6  Vicky    rdt_EcommDispatch_Confirm has lesser Parameter & */
/*                          do not display SKU on sKU field (Vicky02)        */
/* 2010-09-01 1.7  Shong    Clean Routing Record By Sending DELETE action    */
/*                          (Shong01)                                        */
/* 2010-09-02 1.8  James    If not all allocated sku being packed then not   */
/*                          allow to close tote (james01)                    */
/* 2010-09-06 1.9  ChewKP   When ShortPick with 0 Qty Pick, should allow to  */
/*                          process (ChewKP01)                               */
/* 2010-09-07 2.0  ChewKP   Enhance Supervisor Alert (ChewKP02)              */
/* 2010-09-13 2.1  ChewKP   Enhancement for Orders which 2nd Tote with       */
/*                          no ToteNo and not yet scan and pick  (ChewKP03)  */
/* 2010-09-15 2.2  James    Prevent Store tote to be scanned (james02)       */
/* 2010-09-15 2.3  James    Check if tote completed (james03)                */
/* 2010-10-05 2.4  James    Check if overpacked & clear ecommlog (james04)   */
/* 2010-10-14 2.5  James    Do not allow short pick qty to pack (james05)    */
/*                          PickDetail.Status = '4' and PickDetail.Qty > 0   */
/* 2010-10-20 2.6  Shong    Only Reverse PackDetail.Qty = 0 only for Order   */
/*                          Where Qty Expected <> Scanned Qty                */
/* 2011-01-11 2.7  James    SOS202130 - Add extra SKU check (james06)        */
/* 2011-05-12 2.8  ChewKP   Begin Tran and Commit Tran issues (ChewKP04)     */
/* 2012-07-05 2.0  TLTING   Avoid Deadlock (tling01) - Select NOLOCK         */
/* 2014-07-17 2.1  James    SOS311987 - Allow DropIDType SINGLES% and        */
/*                          MULTIS% (james07)                                */
/* 2014-08-19 2.2  James    SOS317664 - Add print Metapack (james08)         */
/* 2014-12-16 2.3  James    SOS327809 - Add rdt config to bypass checking for*/
/*                          Park Tote (james09)                              */
/* 2015-03-03 2.4  James    SOS334537 - Bug fix on pickmethod filter(james10)*/
/* 2015-04-15 2.5  James    SOS338716-Reverse pack qty for MULTIS  (james11) */
/* 2015-11-03 2.6  James    Extend @cOption to NVARCHAR( 2) (james12)        */
/* 2015-11-27 2.7  James    Deadlock tuning (james13)                        */
/* 2015-12-10 2.8  James    SOS358577 - Enhance park tote feature (james14)  */
/* 2016-09-22 2.9  James    SOS370883 - Cater tote from Cart Picking         */
/*                          Add RDTFormat (james15)                          */
/* 2016-10-05 3.0  James    Perf tuning                                      */
/* 2018-11-01 3.1  TungGH   Performance                                      */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Ecomm_Dispatch](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
-- Misc variable
DECLARE
   @b_success           INT

DECLARE @c_NewLineChar NVARCHAR(2) -- (ChewKP02)
SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) -- (ChewKP02)

DECLARE @tCMDError TABLE( ErrMsg NVARCHAR(250))  -- james08

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10), -- (Vicky01)
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cOrderkey           NVARCHAR(10),
   @cSingles            NVARCHAR(10),
   @cDoubles            NVARCHAR(10),
   @cMultis             NVARCHAR(10),
   @cToteNo             NVARCHAR(18),
   @cDropIDType         NVARCHAR(10),
   @cSku                NVARCHAR(20),
   @cReasonCode         NVARCHAR(10),
   @cRSN_Descr          NVARCHAR(60),
   @cModuleName         NVARCHAR(45),
   @cAlertMessage       NVARCHAR(255),
   @cWCSKey             NVARCHAR(10),
   @cOption             NVARCHAR(2),         -- (james12)
   @nToteCnt            int,
   @cOtherTote          NVARCHAR(18),
   @cUnPickOrderkey     NVARCHAR(10),
   @nOrderCount         INT,
   @nSUM_PackQTY        INT,
   @nSUM_PickQTY        INT,
   @nSKU_Picked_TTL     INT,       -- (james04)
   @nSKU_Packed_TTL     INT,       -- (james04)
   @cPickSlipNo         NVARCHAR(10),  -- (james04)
   @nPrevScn            INT,       -- (james04)
   @nPrevStep           INT,       -- (james04)
   @cErrMsg1            NVARCHAR( 20),       -- (james08)
   @cErrMsg2            NVARCHAR( 20),       -- (james08)
   @cErrMsg3            NVARCHAR( 20),       -- (james08)
   @cErrMsg4            NVARCHAR( 20),       -- (james08)
   @cErrMsg5            NVARCHAR( 20),       -- (james08)
   @cFileName           NVARCHAR( 100),      -- (james08)
   @cPrintFileName      NVARCHAR( 500),      -- (james08)
   @cFilePath           NVARCHAR( 1000),     -- (james08)
   @nFileExists         INT,                 -- (james08)
   @cPrintFilePath      NVARCHAR( 1000),     -- (james08)
   @cLabelNo            NVARCHAR( 20),
   @bSuccess            INT,
   @nReturnCode         INT,
   @cCMD                NVARCHAR(1000),
   @nTTL_SKU_Picked     INT,
   @nTTL_SKU_Packed     INT,
   @cSkipParkTote       NVARCHAR( 20),    -- (james13)
   @nRowRef             INT,              -- (james13)
   @nParkTote           INT,              -- (james14)
   @cPrev_ToteNo        NVARCHAR( 18),    -- (james14)
   @cParkTote_OrderKey  NVARCHAR( 10),    -- (james14)
   @cTote2Park1         NVARCHAR( 18),    -- (james14)
   @cTote2Park2         NVARCHAR( 18),    -- (james14)
   @cTote2Park3         NVARCHAR( 18),    -- (james14)
   @cTote2Park4         NVARCHAR( 18),    -- (james14)
   @cTote2Park5         NVARCHAR( 18),    -- (james14)
   @cTote2Park6         NVARCHAR( 18),    -- (james14)
   @cOrders4Tote        NVARCHAR( 10),    -- (james15)
   @cCartPick           NVARCHAR( 1),     -- (james15)

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

   SET @cSingles     = 'SINGLES'
   SET @cDoubles     = 'DOUBLES'
   SET @cMultis      = 'MULTIS'
   SET @cToteNo      = ''
   SET @cDropIDType  = ''

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper, -- (Vicky01)
   @cUserName        = UserName,

   @cToteno          = V_String1,
   @cDropIDType      = V_String2,
   @cOrderkey        = V_String3,
   @cSku             = V_String4,
   @cSkipParkTote    = V_String7,
   @cPrev_ToteNo     = V_String8,
   @cCartPick        = V_String9,   -- (james15)
   
   @nPrevScn         = V_FromScn,
   @nPrevStep        = V_FromStep,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1712
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1712
   IF @nStep = 1 GOTO Step_1   -- Scn = 2400  ToteNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 2401  Singles/Doubles Order Sku
   IF @nStep = 3 GOTO Step_3   -- Scn = 2402  Multis Order SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 2403  ReasonCode
   IF @nStep = 5 GOTO Step_5   -- Scn = 2404  Multi ToteNo
   IF @nStep = 6 GOTO Step_6   -- Scn = 2405  Park Tote
   IF @nStep = 7 GOTO Step_7   -- Scn = 2406  Print Metapack doc
   IF @nStep = 8 GOTO Step_8   -- Scn = 2407  Scan parked tote
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1712)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2400
   SET @nStep = 1

    -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   --initialise all variables
   SET @cToteNo      = ''
   SET @cDropIDType  = ''
   SET @cOrderkey    = ''
   SET @cSku         = ''
   SET @cReasonCode  = ''
   SET @cRSN_Descr   = ''
   SET @cModuleName  = ''
   SET @cAlertMessage = ''
   SET @cWCSKey      = ''
   SET @cOption      = ''
   SET @nToteCnt     = 0
   SET @cOtherTote   = ''
   SET @cPrev_ToteNo = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''

   -- (james13)
   SET @cSkipParkTote = rdt.RDTGetConfig( @nFunc, 'SkipParkTote', @cStorerKey)
   IF ISNULL( @cSkipParkTote, '') IN ('', '0')
      SET @cSkipParkTote = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2400
   TOTE NO:
   DROPID  (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
 BEGIN
      -- Screen mapping
      SET @cToteno = @cInField01

      /****************************
       VALIDATION
      ****************************/
      -- Check Printer ID
      IF ISNULL(@cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 69879
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Printer ID req
         GOTO Step_1_Fail
      END

      -- (Vicky01) - Start
      IF ISNULL(@cPrinter_Paper, '') = ''
      BEGIN
         SET @nErrNo = 69900
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
         GOTO Step_1_Fail
      END
      -- (Vicky01) - End

      --When ToteNo is blank
      IF @cToteno = ''
      BEGIN
         SET @nErrNo = 69866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (james15)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteno) = 0
      BEGIN
         SET @nErrNo = 104401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT @cDropIDType  = ISNULL(RTRIM(DropIDType),'')
      FROM dbo.DROPID WITH (NOLOCK)
      WHERE DropId = @cToteno

      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                      WHERE ListName = 'DROPIDTYPE'
                      AND   CODE = @cDropIDType)--(james01)
      BEGIN
         SET @nErrNo = 69868
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote
         GOTO Step_1_Fail
      END

      -- Determine what type of picking tote (james15)
      -- For cart picking, no taskdetail will be updated
      -- So every checking must exclude the taskdetail table
      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                  WHERE DropID = @cToteno
                  AND   UDF02 = 'CARTPICK'
                  AND   Status < '9')
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                     JOIN dbo.DropID D WITH (NOLOCK) ON ( PD.DROPID = D.DROPID AND D.LoadKey = O.LoadKey)
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.DropID = @cToteno
                     AND   O.USERDEFINE01 = ''
                     AND   O.Status NOT IN ('9', 'CANC'))
         BEGIN
            SET @nErrNo = 104402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Store Tote
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- when tote does not exist in dropid
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cToteno
                        AND   Status < '9')
         BEGIN
            SET @nErrNo = 104403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not exists
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Check any short pick found
         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                    JOIN dbo.DropID D WITH (NOLOCK) ON ( PD.DropID = D.DropID AND D.LoadKey = O.LoadKey)
                    WHERE PD.Storerkey = @cStorerkey
                    AND   PD.DropID = @cToteno
                    AND   PD.Status IN ('3', '4')
                    AND   PD.QTY > 0)
         BEGIN
            SET @nErrNo = 104404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShortPickFound
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- check any item on tote not picked or any picks exists for this tote
         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                    JOIN dbo.DropID D WITH (NOLOCK) ON ( PD.DropID = D.DropID AND D.LoadKey = O.LoadKey)
                    WHERE PD.Storerkey = @cStorerkey 
                    AND   PD.DropID = @cToteno 
                    AND   PD.Status < '5'
                    AND   PD.Qty > 0 
                    AND  (O.UserDefine01 LIKE 'DOUBLES%' OR O.UserDefine01 LIKE 'MULTIS%'))
         OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                        WHERE Storerkey = @cStorerkey 
                        AND   DropID = @cToteNo)
         BEGIN
            SET @nErrNo = 104405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- 1 tote for 1 orders for cart picking
         SELECT TOP 1 @cOrders4Tote = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   DropID = @cToteno
         AND   Status < '9'
         AND   Qty > 0 
         
         -- Check if this orders has something not picked
         IF EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   OrderKey = @cOrders4Tote
                     AND   Status < '9'
                     AND   Qty > 0
                     AND   ISNULL( DropID, '') = '')
         BEGIN
            SET @nErrNo = 104412
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0
         SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.DropID = @cToteNo
            AND PH.Status <> '9'

         SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
           AND O.Status NOT IN ('9', 'CANC')
           AND PD.DropID = @cToteNo
           AND PD.Status = '5'

         IF ( @nSUM_PackQTY = @nSUM_PickQTY) OR 
            EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                    WHERE DropID = @cToteNo 
                    AND   Status = '9')
         BEGIN
            SET @nErrNo = 104406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cToteNo
         AND   [Status] = '9'
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Delete what ever for this tote which is not complete by orders
            DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               BREAK
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         BEGIN TRAN 

         UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK) SET 
            Status = '9'
         WHERE TOTENO = @cToteNo
         AND   STATUS < '9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 104407
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRoutingDetail Fail
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         BEGIN TRAN 

         UPDATE dbo.WCSRouting WITH (ROWLOCK) SET 
            Status = '9'
         WHERE TOTENO = @cToteNo
         AND STATUS < '9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 104408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRouting Fail
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         -- Check for Unpick Order with No ToteNo
         IF @cDropIDType LIKE 'DOUBLES%'  OR @cDropIDType LIKE 'MULTIS%'
         BEGIN
            SET @nOrderCount = 1

            DECLARE CUR_UNPORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT P.Orderkey
            FROM dbo.PickDetail P WITH (NOLOCK)
            JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
            JOIN dbo.DropID D WITH (NOLOCK) ON P.DROPID = D.DROPID AND D.LOADKEY = O.LOADKEY
            WHERE P.DropID = @cToteNo
            AND   O.UserDefine01 LIKE @cDropIDType
            AND   O.Status < '9'
            OPEN CUR_UNPORDER
            FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey

               IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                          WHERE Orderkey = @cUnPickOrderkey
                          AND Status = '0'
                          AND DropID = '' )
               BEGIN
                  -- If orders with multiple totes and not all item picked then check whether
                  -- this tote still have other outstanding task. If not then can proceed else prompt error
                  IF @cSkipParkTote <> '1'
                  BEGIN
                     SET @nErrNo = 104409
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_1_Fail
                  END
               END

               SET @nOrderCount = @nOrderCount + 1

               FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey
            CLOSE CUR_UNPORDER
            DEALLOCATE CUR_UNPORDER
         END

         -- If skip pack tote feature turn on then skip below 
         IF @cSkipParkTote <> '1'
         BEGIN

            /****************************
             Calculate # of Totes
            ****************************/
            SET @nToteCnt = 1
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''

            -- retrieve other totes
            DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT ISNULL(RTRIM(PK1.DROPID),'')
            FROM  dbo.PICKDETAIL PK1 WITH (NOLOCK)
            JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey = PK1.OrderKey
            JOIN DROPID DI WITH (NOLOCK) ON PK1.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
            WHERE EXISTS ( SELECT 1 from PICKDETAIL PK2 WITH (NOLOCK)
                           JOIN ORDERS O2 WITH (NOLOCK) ON O2.OrderKey = PK2.OrderKey
                           JOIN DROPID D2 WITH (NOLOCK) ON PK2.DROPID = D2.DROPID AND D2.LOADKEY = O2.LOADKEY
                           WHERE PK2.DROPID = ISNULL(RTRIM(@cToteNo),'')
                           AND   PK2.Orderkey = PK1.Orderkey )
            AND   NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog WITH (NOLOCK) WHERE TOTENO = PK1.DROPID and Status = '9' AND Orderkey = PK1.Orderkey)
            AND   PK1.DROPID <> ISNULL(RTRIM(@cToteNo),'')
            AND   PK1.STATUS = '5'                    
            ORDER BY ISNULL(RTRIM(PK1.DROPID),'')

            OPEN CUR_TOTE
            FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nToteCnt = 1 SET @cOutField01 = @cOtherTote
               IF @nToteCnt = 2 SET @cOutField02 = @cOtherTote
               IF @nToteCnt = 3 SET @cOutField03 = @cOtherTote
               IF @nToteCnt = 4 SET @cOutField04 = @cOtherTote
               IF @nToteCnt = 5 SET @cOutField05 = @cOtherTote
               IF @nToteCnt = 6 SET @cOutField06 = @cOtherTote

               SET @nToteCnt = @nToteCnt + 1
               FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
            END
            CLOSE CUR_TOTE
            DEALLOCATE CUR_TOTE

            IF ISNULL(RTRIM(@cOutField01),'') <> '' OR ISNULL(RTRIM(@cOutField02),'') <> ''
            OR ISNULL(RTRIM(@cOutField03),'') <> '' OR ISNULL(RTRIM(@cOutField04),'') <> ''
            OR ISNULL(RTRIM(@cOutField05),'') <> '' OR ISNULL(RTRIM(@cOutField06),'') <> ''
            BEGIN
               SET @cPrev_ToteNo = @cToteNo
               GOTO PARK_TOTE
            END
         END

         /****************************
          INSERT INTO rdtECOMMLog
         ****************************/

         BEGIN TRAN -- (ChewKP04)

         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)
         SELECT @nMobile, @cToteNo, PD.Orderkey, PD.SKU, @cDropIDType, SUM(PD.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         JOIN dbo.DropID D WITH (NOLOCK) ON ( PD.DropID = D.DropID AND D.LoadKey = O.LoadKey)
         WHERE PD.DropID = @cToteNo
         AND   PD.Status = '5'
         AND   PD.Qty > 0
         AND   O.Status < '9'
         AND   O.UserDefine01 LIKE @cDropIDType
         -- Assume 1 orders 1 pickslipno and no half packed orders
         AND NOT EXISTS (SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK)
                         WHERE PH.Orderkey = PD.Orderkey
                         AND   PH.Status = '9')
         GROUP BY PD.Orderkey, PD.SKU

         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 104410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO Step_1_Fail
         END

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 104411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         /****************************
          prepare next screen variable
         ****************************/
         SET @cOutField01 = @cToteno

         IF @cDropIDType LIKE 'MULTIS%'
         BEGIN
            SELECT @cOrderkey = MIN(Orderkey)
            FROM  rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cToteNo
            AND   Status < '5'
            AND   Mobile = @nMobile

            SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2
         END
         ELSE
         BEGIN
            -- singles and doubles order type
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END

         GOTO Quit
      END

      -- (james02)
      IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                 JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE TD.StorerKey = @cStorerKey
                    AND TD.DropID = @cToteno
                    AND O.USERDEFINE01 = ''
                    AND O.Status NOT IN ('9', 'CANC'))
      BEGIN
         SET @nErrNo = 69910
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Store Tote
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- when tote does not exist in dropid
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID DROPID WITH (NOLOCK) WHERE DROPID.DropID = @cToteno
      AND Status < '9')  --(Kc04)
      BEGIN
         SET @nErrNo = 69867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not exists
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (james05)
      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                 JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE PD.Storerkey = @cStorerkey
                    AND TD.DropID = @cToteno
                    AND PD.Status IN ('3', '4')
                    AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 71443
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShortPickFound
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      --(KC01)
      -- check any item on tote not picked or any picks exists for this tote
      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                 JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE PD.Storerkey = @cStorerkey AND TD.DropID = @cToteno AND PD.Status < '5'
                 AND PD.Qty > 0  --(ChewKP01)
                 AND (TD.PickMethod LIKE 'DOUBLES%' OR TD.PickMethod LIKE 'MULTIS%'))   -- (james10)
      OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey AND DropID = @cToteNo)
      BEGIN
         SET @nErrNo = 69892
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (KC01)
      -- check if tote completely scanned , then do not allow to proceed
--      IF NOT EXISTS (SELECT 1
--      FROM  dbo.PICKDETAIL PK WITH (nolock)
--      LEFT OUTER JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PK.Orderkey = PH.Orderkey)
--      LEFT OUTER JOIN  dbo.PACKDETAIL PD WITH (NOLOCK) ON (PD.Pickslipno = PH.Pickslipno AND PD.Sku = PK.Sku)
--      WHERE PK.DropId = @cToteNo
--      AND PK.Storerkey = @cStorerkey
--      AND   PK.Status = '5'   --(Kc02)
--     GROUP BY PK.SKU
--      HAVING SUM(PK.QTY) <> SUM(ISNULL(PD.QTY,0)))
      -- (james03)
--      IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
--                 JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
--                 JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
--                 WHERE O.StorerKey = @cStorerKey
--                    AND O.Status NOT IN ('9', 'CANC')
--                    AND PD.DropID = @cToteNo)
      -- (james03)
      SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0
      SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.DropID = @cToteNo
         AND PH.Status <> '9'

      SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
        AND O.Status NOT IN ('9', 'CANC')
        AND PD.DropID = @cToteNo
        AND PD.Status = '5'

      IF @nSUM_PackQTY = @nSUM_PickQTY
      OR EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToteNo AND Status = '9')
      BEGIN
         SET @nErrNo = 69891
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted
       EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (james13)
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo = @cToteNo
      AND   [Status] = '9'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Delete what ever for this tote which is not complete by orders
         DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            BREAK
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      /****************************
       UPDATE WCSROUTING
      ****************************/
       --(Kc02) - start
--      SET @cWCSKey = ''
--      SELECT @cWCSKey = ISNULL(RTRIM(WCSKey),'')
--      FROM WCSRouting WITH (NOLOCK)
--      WHERE TOTENO = @cToteNo
--      AND Facility = @cFacility                 --(KC01)
--      AND STATUS < '9'

--      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
--      SET Status = '9'
--      WHERE WCSKey = @cWCSKey
--      AND TOTENO = @cToteNo
--      AND STATUS < '9'

      BEGIN TRAN -- (ChewKP04)

      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
      SET Status = '9'
      WHERE TOTENO = @cToteNo
      AND STATUS < '9'
      --(Kc02) - end

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 69876
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRoutingDetail Fail
         GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      --(Kc02) - start
--      UPDATE dbo.WCSRouting WITH (ROWLOCK)
--      SET Status = '9'
--      WHERE WCSKey = @cWCSKey
--      AND STATUS < '9'
      BEGIN TRAN -- (ChewKP04)

      UPDATE dbo.WCSRouting WITH (ROWLOCK)
      SET Status = '9'
      WHERE TOTENO = @cToteNo
      AND STATUS < '9'
      --(Kc02) - end

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 69877
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRouting Fail
         GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END


      -- (ChewKP03) Start
      -- Check for Unpick Order with No ToteNo
      IF @cDropIDType LIKE 'DOUBLES%'  OR @cDropIDType LIKE 'MULTIS%'
      BEGIN
         SET @nOrderCount = 1

         DECLARE CUR_UNPORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT P.Orderkey
         FROM dbo.PickDetail P WITH (NOLOCK)
         JOIN TaskDetail td WITH (NOLOCK) ON td.TaskDetailKey = P.TaskDetailKey
         JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON P.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE P.DropID = @cToteNo
         AND   TD.PickMethod = @cDropIDType
         AND   O.Status < '9'
         OPEN CUR_UNPORDER
         FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey

            IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                       WHERE Orderkey = @cUnPickOrderkey
                       AND Status = '0'
                    AND DropID = '' )
            BEGIN
               -- If orders with multiple totes and not all item picked then check whether
               -- this tote still have other outstanding task. If not then can proceed else prompt error
               IF @cSkipParkTote = '1'
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                              WHERE StorerKey = @cStorerKey
                              AND   TaskType = 'PK'
                              AND   Status < '9'
                              AND   DropID = @cToteNo)
                  BEGIN
                     SET @nErrNo = 71450
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_1_Fail
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 69909
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_1_Fail
               END
            END

            SET @nOrderCount = @nOrderCount + 1

            FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey
         CLOSE CUR_UNPORDER
         DEALLOCATE CUR_UNPORDER
      END

      -- (ChewKP03) End
      -- (james09)
      -- If skip pack tote feature turn on then skip below (james13)
      IF @cSkipParkTote <> '1'
      BEGIN

         /****************************
          Calculate # of Totes
         ****************************/
         SET @nToteCnt = 1
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         -- retrieve other totes
         DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT ISNULL(RTRIM(PK1.DROPID),'')
         FROM  dbo.PICKDETAIL PK1 WITH (NOLOCK)
         JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey = PK1.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PK1.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE EXISTS ( SELECT 1 from PICKDETAIL PK2 WITH (NOLOCK)
                        JOIN ORDERS O2 WITH (NOLOCK) ON O2.OrderKey = PK2.OrderKey
                        JOIN DROPID D2 WITH (NOLOCK) ON PK2.DROPID = D2.DROPID AND D2.LOADKEY = O2.LOADKEY
                        WHERE PK2.DROPID = ISNULL(RTRIM(@cToteNo),'')
                        AND   PK2.Orderkey = PK1.Orderkey )
         AND   NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog WITH (NOLOCK) WHERE TOTENO = PK1.DROPID and Status = '9' AND Orderkey = PK1.Orderkey)
         AND   PK1.DROPID <> ISNULL(RTRIM(@cToteNo),'')
         AND   PK1.STATUS = '5'                    --(Kc02)
         ORDER BY ISNULL(RTRIM(PK1.DROPID),'')

         OPEN CUR_TOTE
         FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @nToteCnt = 1 SET @cOutField01 = @cOtherTote
            IF @nToteCnt = 2 SET @cOutField02 = @cOtherTote
            IF @nToteCnt = 3 SET @cOutField03 = @cOtherTote
            IF @nToteCnt = 4 SET @cOutField04 = @cOtherTote
            IF @nToteCnt = 5 SET @cOutField05 = @cOtherTote
            IF @nToteCnt = 6 SET @cOutField06 = @cOtherTote

            SET @nToteCnt = @nToteCnt + 1
            FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
         END
         CLOSE CUR_TOTE
         DEALLOCATE CUR_TOTE

         IF ISNULL(RTRIM(@cOutField01),'') <> '' OR ISNULL(RTRIM(@cOutField02),'') <> ''
         OR ISNULL(RTRIM(@cOutField03),'') <> '' OR ISNULL(RTRIM(@cOutField04),'') <> ''
         OR ISNULL(RTRIM(@cOutField05),'') <> '' OR ISNULL(RTRIM(@cOutField06),'') <> ''
         BEGIN
            SET @cPrev_ToteNo = @cToteNo
            GOTO PARK_TOTE
         END
      END

      /****************************
       INSERT INTO rdtECOMMLog
      ****************************/

      BEGIN TRAN -- (ChewKP04)

      INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)
      SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()
      FROM dbo.PICKDETAIL PK WITH (NOLOCK)
      JOIN TaskDetail td WITH (NOLOCK) ON td.TaskDetailKey = PK.TaskDetailKey
      JOIN ORDERS o WITH (NOLOCK) ON O.OrderKey = PK.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE PK.DROPID = @cToteNo
      AND PK.Status = '5'
      AND O.Status < '9'
      AND PK.Qty > 0
      AND TD.PickMethod = @cDropIDType
      -- Assume 1 orders 1 pickslipno and no half packed orders
      AND NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER PH WITH (NOLOCK)
                      WHERE PH.Orderkey = PK.Orderkey
                      AND   PH.Status = '9')
      GROUP BY PK.Orderkey, PK.SKU

      IF @@ROWCOUNT = 0 -- No data inserted
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 69882
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
         GOTO Step_1_Fail
      END

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 69875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'
         GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      /****************************
       prepare next screen variable
      ****************************/
      SET @cOutField01 = @cToteno

      IF @cDropIDType LIKE 'MULTIS%'
      BEGIN
         SELECT @cOrderkey = MIN(Orderkey)
         FROM  rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cToteNo
         AND   Status < '5'
         AND   Mobile = @nMobile

         SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         -- singles and doubles order type
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      GOTO QUIT

      PARK_TOTE:
      BEGIN
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james13)
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE [Status] = '0'
      AND   AddWho = @cUserName
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Delete what ever for this tote which is not complete by orders
         DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            BREAK
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      -- EventLog - Sign Out Function
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

      SET @cOutField01 = ''
      SET @cToteNo      = ''
      SET @cDropIDType  = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cDropIDType  = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2401
   ToteNo:
   TOTENo   (Field01, display)
   SKU/UPC:
   SKU/UPC  (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSku    = @cInField02

      -- Check If SKU exists in TOTE (james06)
      IF NOT EXISTS (SELECT 1
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON pd.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo
            AND PD.SKU = @cSku)
      BEGIN
         SET @nErrNo = 71444
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID SKU'
         GOTO Step_2_Fail
      END

      -- (james04)
      -- Check total picked & unshipped qty for this SKU
      SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Pickdetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON pd.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.Status = '5'
         AND PD.DropID = @cToteNo
         AND PD.SKU = @cSku

      -- Check total packed & unshipped qty for this SKU
      SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Packdetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.DropID = @cToteNo
         AND PD.SKU = @cSku

      IF @nSKU_Picked_TTL > @nSKU_Packed_TTL
      BEGIN
         EXEC rdt.rdt_EcommDispatch_Confirm
            @nMobile       = @nMobile,
            @cPrinter      = @cPrinter,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cOrderkey     = @cOrderkey OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cSku          = @cSku,
            @cToteno       = @cToteNo,
            @cDropIDType   = @cDropIDType,
            @cPrinter_Paper = @cPrinter_Paper,  -- (Vicky01)
            @cPrevOrderkey = @cOrderkey,        --(Kc03)
            @nFunc         = @nFunc,            --(Kc06)
            @cFacility     = @cFacility,        --(Kc06)
            @cUserName     = @cUserName         --(Kc06)

         IF @nErrno <> 0
         BEGIN
           SET @nErrNo = @nErrNo
           SET @cErrMsg = @cErrMsg
           GOTO Step_2_Fail
         END

         -- Check if it is Metapack printing
         SELECT @cFilePath = Long, @cPrintFilePath = Notes
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'Metapack'
         AND   Code = 'PDFPrint'
         AND   StorerKey = @cStorerKey

         IF ISNULL( @cFilePath, '') <> ''
         BEGIN
            SET @nFileExists = 0
            -- Print C23 (james08)
            DECLARE CUR_PRINTC23 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT PD.LabelNo
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
            WHERE PH.StorerKey = @cStorerKey
            AND   PH.OrderKey = @cOrderkey
            ORDER BY 1
            OPEN CUR_PRINTC23
            FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @cFileName = 'C23_' + @cLabelNo + '.pdf'
               SET @cPrintFileName = RTRIM( @cFilePath) + '\' + 'C23_' + RTRIM( @cLabelNo) + '.pdf'
               EXEC isp_FileExists @cPrintFileName, @nFileExists OUTPUT, @bSuccess OUTPUT

               IF @nFileExists = 1
               BEGIN
                  -- Prepare next screen variable
                  SET @nScn = @nScn + 5
                  SET @nStep = @nStep + 5
                  CLOSE CUR_PRINTC23
                  DEALLOCATE CUR_PRINTC23
                  GOTO Quit
               END

               FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
            END
            CLOSE CUR_PRINTC23
            DEALLOCATE CUR_PRINTC23
         END   -- @cFilePath
      END
      ELSE
      BEGIN
         SET @nErrNo = 69911
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Exceeded'
         GOTO Step_2_Fail
      END

      /****************************
       Prepare Next Screen
      ****************************/
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
         AND Mobile = @nMobile AND Status < '5')
      BEGIN
         -- tote completed, so need to return to 1st screen

         -- Check if all SKU in this tote picked and packed (james01)
         -- Check total picked & unshipped qty
         SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo

         -- Check total packed & unshipped qty
         SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Packdetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.DropID = @cToteNo

         -- Close DropID when pick & pack qty matches
         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL
         BEGIN
            SET @cSKU = ''
            SET @cOutField01 = @cToteNo
            SET @cOutField02 = ''
         END
         ELSE
         BEGIN
            --(Kc05)
            --(KC04) - start
            UPDATE dbo.DROPID WITH (Rowlock)
            SET   Status = '9'
            WHERE DropID = @cToteNo
            AND   Status < '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'
               GOTO Step_2_Fail
            END
            --(Kc04) - end

            -- (Shong01)
            EXEC [dbo].[nspInsertWCSRouting]
             @cStorerKey
            ,@cFacility
            ,@cToteNo
            ,'ECOMM_DSPT'
            ,'D'
            ,''
            ,@cUserName
            ,0
            ,@b_Success          OUTPUT
            ,@nErrNo             OUTPUT
            ,@cErrMsg   OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = @nErrNo
               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
               GOTO Step_2_Fail
            END

            -- (james13)
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cToteNo
            AND   AddWho = @cUserName
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Delete what ever for this tote which is not complete by orders
               DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  CLOSE CUR_UPD
                  DEALLOCATE CUR_UPD
                  SET @nErrNo = 69913
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcomLogFail'
                  GOTO Step_2_Fail
               END

               FETCH NEXT FROM CUR_UPD INTO @nRowRef
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD

            SET @cOutField01 = ''
            SET @cToteNo      = ''
            SET @cDropIDType  = ''
            SET @cOrderkey    = ''
            SET @cSku         = ''
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
      END
      ELSE
      BEGIN
         -- loop same screen
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
            AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5'
            AND Orderkey = @cOrderkey)                   --(Kc03)
         BEGIN
            -- sku fully scanned for the order
            SET @cSKU = ''
         END
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = '' --@cSku  -- (Vicky02)
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cInField01  = ''

      -- Remember the current scn & step
      SET @nPrevScn = @nScn
      SET @nPrevStep = @nStep

      SET @nScn = @nScn + 2   --ESC screen
      SET @nStep = @nStep + 2
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
   SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2402
   ToteNo:
   TOTENo   (Field01, display)
   Orderkey:
   Orderkey (Field02, display)
   SKU/UPC:
   SKU/UPC  (Field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSku    = @cInField03

      -- Check If SKU exists in TOTE (james06)
      IF NOT EXISTS (SELECT 1
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON pd.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo
            AND PD.SKU = @cSku)
      BEGIN
         SET @nErrNo = 71445
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID SKU'
         GOTO Step_3_Fail
      END

      -- (james04)
      -- Check total picked & unshipped qty for this SKU
      SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Pickdetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.Status = '5'
         AND PD.DropID = @cToteNo
         AND PD.SKU = @cSku

      -- Check total packed & unshipped qty for this SKU
      SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Packdetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.DropID = @cToteNo
         AND PD.SKU = @cSku

      IF @nSKU_Picked_TTL > @nSKU_Packed_TTL
      BEGIN
         EXEC rdt.rdt_EcommDispatch_Confirm
            @nMobile       = @nMobile,
            @cPrinter      = @cPrinter,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cOrderkey     = @cOrderkey OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cSku          = @cSku,
            @cToteno       = @cToteNo,
            @cDropIDType   = @cDropIDType,
            @cPrinter_Paper = @cPrinter_Paper,  -- (Vicky01)
            @cPrevOrderkey = @cOrderkey,         --(Kc03)
            @nFunc         = @nFunc,            --(Kc06)
            @cFacility     = @cFacility,        --(Kc06)
            @cUserName     = @cUserName         --(Kc06)

         IF @nErrno <> 0
         BEGIN
           SET @nErrNo = @nErrNo
           SET @cErrMsg = @cErrMsg
           GOTO Step_3_Fail
         END

         SET @nTTL_SKU_Picked = 0
         SET @nTTL_SKU_Packed = 0

         -- Check total picked & unshipped qty for this SKU
         SELECT @nTTL_SKU_Picked = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo

         -- Check total packed & unshipped qty for this SKU
         SELECT @nTTL_SKU_Packed = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Packdetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.DropID = @cToteNo

         -- Fully pick and pack only print c23
         IF @nTTL_SKU_Picked = @nTTL_SKU_Packed
         BEGIN
            -- Check if there is other parked tote need to scan
            IF EXISTS ( SELECT 1 FROM rdt.rdtEcommLog WITH (NOLOCK) 
                        WHERE AddWho = @cUserName 
                        AND [Status] = '0')
            BEGIN
               SELECT TOP 1 @cToteNo = ToteNo, 
                            @cOrderkey = OrderKey
               FROM rdt.rdtEcommLog WITH (NOLOCK) 
               WHERE AddWho = @cUserName 
               AND [Status] = '0'
               ORDER BY RowRef
      
               SET @cOutField01 = @cToteNo
               SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
               SET @cOutField03 = ''
               GOTO Quit
            END
            ELSE
            BEGIN            
               SELECT @cFilePath = Long, @cPrintFilePath = Notes
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'Metapack'
               AND   Code = 'PDFPrint'
               AND   StorerKey = @cStorerKey

               IF ISNULL( @cFilePath, '') <> ''
               BEGIN
                  -- Print C23 (james08)
                  DECLARE CUR_PRINTC23 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT DISTINCT PD.LabelNo
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                  WHERE PH.StorerKey = @cStorerKey
                  AND   PH.OrderKey = @cOrderkey
                  ORDER BY 1
                  OPEN CUR_PRINTC23
                  FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SET @cFileName = 'C23_' + RTRIM( @cLabelNo) + '.pdf'
                     SET @cPrintFileName = RTRIM( @cFilePath) + '\' + 'C23_' + RTRIM( @cLabelNo) + '.pdf'
                     EXEC isp_FileExists @cPrintFileName, @nFileExists OUTPUT, @bSuccess OUTPUT

                     IF @nFileExists = 1
                     BEGIN
                        -- Prepare next screen variable
                        SET @nScn = @nScn + 4
                        SET @nStep = @nStep + 4
                        CLOSE CUR_PRINTC23
                        DEALLOCATE CUR_PRINTC23
                        GOTO Quit
                     END
                     FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
                  END
                  CLOSE CUR_PRINTC23
                  DEALLOCATE CUR_PRINTC23
               END   -- @cFilePath
            END
         END   -- If exists ()
      END
      ELSE
      BEGIN
         SET @nErrNo = 69912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Exceeded'
         GOTO Step_3_Fail
      END

      /****************************
       Prepare Next Screen
      ****************************/
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
         AND Mobile = @nMobile AND Status < '5')
      BEGIN
         -- tote completed, so need to return to 1st screen

         -- Check if all SKU in this tote picked and packed (james01)
         -- Check total picked & unshipped qty
         SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo

         -- Check total packed & unshipped qty
         SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Packdetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.DropID = @cToteNo

         -- Close DropID when pick & pack qty matches
         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL
         BEGIN
            SET @cSKU = ''

            SET @cOutField01 = @cToteNo
            SET @cOutField02 = @cOrderkey
            SET @cOutField03 = ''--@cSku  -- (Vicky02)
         END
         ELSE
         BEGIN
            --(KC04) - start
            UPDATE dbo.DROPID WITH (Rowlock)
            SET   Status = '9'
            WHERE DropID = @cToteNo
            AND   Status < '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'
               GOTO Step_2_Fail
            END
            --(Kc04) - end

            -- (Shong01)
          EXEC [dbo].[nspInsertWCSRouting]
             @cStorerKey
            ,@cFacility
            ,@cToteNo
            ,'ECOMM_DSPT'
            ,'D'
            ,''
            ,@cUserName
            ,0
            ,@b_Success          OUTPUT
            ,@nErrNo             OUTPUT
            ,@cErrMsg   OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = @nErrNo
               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
               GOTO Step_3_Fail
            END

            -- (james13)
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cToteNo
            AND   AddWho = @cUserName
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Delete what ever for this tote which is not complete by orders
               DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  CLOSE CUR_UPD
                  DEALLOCATE CUR_UPD
                  SET @nErrNo = 71442
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcomLogFail'
                  GOTO Step_2_Fail
               END

               FETCH NEXT FROM CUR_UPD INTO @nRowRef
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD

            SET @cOutField01 = ''
            SET @cToteNo      = ''
            SET @cDropIDType  = ''
            SET @cOrderkey    = ''
            SET @cSku         = ''
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
      END
      ELSE
      BEGIN
         -- loop same screen
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
            AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5')
         BEGIN
            -- sku fully scanned for the tote
            SET @cSKU = ''
         END

         SET @cOutField01 = @cToteNo
         SET @cOutField02 = @cOrderkey
         SET @cOutField03 = ''--@cSku  -- (Vicky02)
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cInField01  = ''

      -- Remember the current scn & step
      SET @nPrevScn = @nScn
      SET @nPrevStep = @nStep

      SET @nScn = @nScn + 1   --ESC screen
      SET @nStep = @nStep + 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2403
   RSN: REASONCODE (Field01, display)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER/ESC
   BEGIN
      -- Screen mapping
      SET @cReasonCode    = @cInField01

      --When Reason is blank
      IF @cReasonCode = ''
      BEGIN
         SET @nErrNo = 69873
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req
         GOTO Step_4_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK) WHERE TaskManagerReasonKey = @cReasonCode)
      BEGIN
         SET @nErrNo = 69874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Reason'
         GOTO Step_4_Fail
      END

      SELECT @cRSN_Descr = Descr FROM dbo.TaskManagerReason WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode

      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc

      SET @cAlertMessage = 'Discontinue from EComm Dispatch Task for Tote: ' + @cToteNo

      IF @cOrderkey <> ''
         SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' Orderkey: ' + ISNULL(@cOrderkey,'')  + ISNULL(@c_NewLineChar,'')  -- (ChewKP02)
      IF @cSku <> ''
         SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' SKU: ' + ISNULL(@cSku,'')  + ISNULL(@c_NewLineChar,'')     -- (ChewKP02)

      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' UID: ' + ISNULL(@cUserName,'')  + ISNULL(@c_NewLineChar,'')   -- (ChewKP02)
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' MOB: ' + CAST(@nMobile AS NVARCHAR( 5)) + ISNULL(@c_NewLineChar,'')    -- (ChewKP02)
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' DateTime: ' + CONVERT(NVARCHAR( 10),GETDATE(), 103) + ISNULL(@c_NewLineChar,'')  -- (ChewKP02)
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' RSN: ' + ISNULL(@cReasonCode,'') + ISNULL(@c_NewLineChar,'')   -- (ChewKP02)
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' RSN Desc: ' + ISNULL(@cRSN_Descr,'')  + ISNULL(@c_NewLineChar,'') -- (ChewKP02)

--         SET @cErrMsg = '123'--@cAlertMessage
--         GOTO Step_4_Fail
      -- Insert LOG Alert
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'')

      SELECT @b_Success = 1
      EXECUTE dbo.nspLogAlert
       @c_ModuleName   = @cModuleName,
       @c_AlertMessage = @cAlertMessage,
       @n_Severity     = 0,
       @b_success      = @b_Success OUTPUT,
       @n_err          = @nErrNo OUTPUT,
       @c_errmsg       = @cErrmsg OUTPUT

      IF NOT @b_Success = 1
      BEGIN
        GOTO Step_4_Fail
      END

      BEGIN TRAN

      -- set status to indicate error during processing
      UPDATE rdt.rdtECOMMLog WITH (ROWLOCK)
      SET   Status = '5',
            ErrMsg = SUBSTRING( @cAlertMessage, 1, 250)
      WHERE ToteNo = @cToteNo
      AND   Status IN ('0','1')
      AND   AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 69914
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDECOMLOGFail'
         GOTO Step_4_Fail
      END

      -- (james04)
      -- Update packdetail.qty = 0 with those orders which start packing halfway
      -- so that later they can pack again after the tote comes back from QC
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT ECOM1.OrderKey, ECOM1.SKU
      FROM rdt.rdtECOMMLog ECOM1 WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON ECOM1.OrderKey = O.OrderKey
      WHERE ECOM1.ToteNo = @cToteNo
      --AND   Status = '5'
      AND   ECOM1.AddWho = @cUserName
      -- (james11) exclude singles as every scan will produce label and consider fully packed.
      -- Cannot reverse.
      AND   (O.UserDefine01 LIKE 'DOUBLES%' OR O.UserDefine01 LIKE 'MULTIS%')
      AND   EXISTS(SELECT 1 FROM rdt.rdtECOMMLog ECOM2  WITH (NOLOCK)
             WHERE ECOM2.SCANNEDQTY <> ECOM2.ExpectedQty
             AND   ECOM2.Orderkey = ECOM1.Orderkey
             AND   ECOM2.ToteNo = @cToteNo
             --AND   ECOM2.[Status] = '5'
             AND   ECOM2.AddWho = @cUserName)

      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cSKU
      WHILE @@FETCH_STATUS <> - 1
      BEGIN
         -- Get pickslipno
         SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey

         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                    WHERE PickSlipNo = @cPickSlipNo
                    AND SKU = @cSKU
                    AND StorerKey = @cStorerKey
                    AND QTY > 0)
         BEGIN
            -- put ArchiveCop here to avoid delete packdetail line when qty = 0 by trigger
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = 0, ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND StorerKey = @cStorerKey
            AND QTY > 0

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               SET @nErrNo = 69915
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReversePACFail'
               GOTO Step_4_Fail
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cSKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      -- (james13)
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo = @cToteNo
      AND   [Status] = '5'
      AND   AddWho = @cUserName
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Delete what ever for this tote which is not complete by orders
         DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            SET @nErrNo = 69914
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDECOMLOGFail'
            GOTO Step_4_Fail
         END
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      COMMIT TRAN

      /****************************
       Prepare Next Screen
      ****************************/
      SET @cOutField01 = ''
      SET @cToteNo = ''
      SET @cDropIDType = ''
      SET @cSKU = ''
      SET @cOrderkey = ''
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cDropIDType LIKE 'MULTIS%'
      BEGIN
         SELECT @cOrderkey = MIN(Orderkey)
         FROM  rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cToteNo
         AND   Status < '5'
         AND   Mobile = @nMobile

         SET @cOutField01 = @cToteNo
         SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = ''
      END
      SET @nScn = @nPrevScn
      SET @nStep = @nPrevStep
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2404
   More Tote To be Scanned, Continue?
   TOTENo   (Field01, display)
   TOTENo   (Field02, display)
   TOTENo   (Field03, display)
   TOTENo   (Field04, display)
   TOTENo   (Field05, display)
   TOTENo   (Field06, display)
   Option   (Field07, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption    = @cInField07
      SET @cTote2Park1 = @cOutField01
      SET @cTote2Park2 = @cOutField02
      SET @cTote2Park3 = @cOutField03
      SET @cTote2Park4 = @cOutField04
      SET @cTote2Park5 = @cOutField05
      SET @cTote2Park6 = @cOutField06                              

      --When Option is blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 69888
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Step_5_Fail
      END

      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 69889
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      IF @cOption = '1' -- continue
      BEGIN
         IF ISNULL( @cToteNo, '') <> ''
         BEGIN
            BEGIN TRAN -- (ChewKP04)

            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)
            --(KC01) - start
            SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)
            JOIN dbo.ORDERS O WITH (NOLOCK) ON PK.OrderKey = O.OrderKey
            JOIN DROPID DI WITH (NOLOCK) ON PK.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
            WHERE PK.DROPID = @cToteNo
            AND PK.Status = '5'
            AND PK.Qty > 0
            AND NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER PH WITH (NOLOCK) where PH.Orderkey = PK.Orderkey and PH.Status = '9')
            GROUP BY PK.Orderkey, PK.SKU
            --(KC01) - end
            IF @@ROWCOUNT = 0 -- No data inserted
            BEGIN
               SET @nErrNo = 69904        --(Kc04)
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
               GOTO Step_5_Fail
            END

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69902        --(Kc04)
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'
               GOTO Step_5_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      END -- option = '1'

      IF @cOption = '9' -- park tote
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO Quit
      END
         
      --initialise all variables
      SET @cToteNo      = ''
      SET @cDropIDType  = ''

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = @cTote2Park1
      SET @cOutField03 = @cTote2Park2
      SET @cOutField04 = @cTote2Park3
      SET @cOutField05 = @cTote2Park4
      SET @cOutField06 = @cTote2Park5
      SET @cOutField07 = @cTote2Park6                          

      SET @nScn = @nScn + 3
      SET @nStep = @nStep + 3      
/*
      /****************************
       prepare next screen variable
      ****************************/
      IF @cOption = '1'
      BEGIN
         SET @cOutField01 = @cToteno
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         IF @cDropIDType LIKE 'MULTIS%'
         BEGIN
            SELECT @cOrderkey = MIN(Orderkey)
            FROM  rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cToteNo
            AND   Status < '5'
            AND   Mobile = @nMobile

            SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- singles and doubles order type
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
      END -- @cOption = '1'
      ELSE IF @cOption = '9' -- park tote
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
*/
   END -- inputkey = 1

--   IF @nInputKey = 0 -- ESC
--   BEGIN
--      SET @cOutField01 = ''
--      SET @cOutField02 = ''
--      SET @cOutField03 = ''
--      SET @cOutField04 = ''
--      SET @cOutField05 = ''
--      SET @cOutField06 = ''
--      SET @cOutField07 = ''
--      SET @cOutField08 = ''
--      SET @cOutField09 = ''
--      SET @cOutField10 = ''
--      SET @cOutField11 = ''
--      SET @cInField01  = ''
--
--      SET @nScn = @nScn - 4   --ESC screen
--      SET @nStep = @nStep - 4
--   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField07 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2405
   PARK TOTE (display)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      /****************************
       Prepare Next Screen
     ****************************/
      SET @cOutField01 = ''
      SET @cToteNo = ''
      SET @cDropIDType = ''
      SET @cSKU = ''
      SET @cOrderkey = ''
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2400
   TOTE NO:
   DROPID  (Field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey IN (0, 1) -- ENTER/ESC
   BEGIN
      SELECT @cFilePath = Long, @cPrintFilePath = Notes
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'Metapack'
      AND   Code = 'PDFPrint'
      AND   StorerKey = @cStorerKey

      IF ISNULL( @cFilePath, '') <> ''
      BEGIN
         -- Print C23 (james08)
         DECLARE CUR_PRINTC23 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT PD.LabelNo
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         WHERE PH.StorerKey = @cStorerKey
         AND   PH.OrderKey = @cOrderkey
         ORDER BY 1
         OPEN CUR_PRINTC23
         FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cFileName = 'C23_' + RTRIM( @cLabelNo) + '.pdf'
            SET @cPrintFileName = RTRIM( @cFilePath) + '\' + 'C23_' + RTRIM( @cLabelNo) + '.pdf'
            EXEC isp_FileExists @cPrintFileName, @nFileExists OUTPUT, @bSuccess OUTPUT

            IF @nFileExists = 1
            BEGIN
               SET @nReturnCode = 0
               SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinter_Paper + '"'

               INSERT INTO @tCMDError
               EXEC @nReturnCode = xp_cmdshell @cCMD
               IF @nReturnCode <> 0
               BEGIN
                  SET @nErrNo = 71447
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PRINT C23 FAIL'
                  BREAK
               END
            END
            FETCH NEXT FROM CUR_PRINTC23 INTO @cLabelNo
         END
         CLOSE CUR_PRINTC23
         DEALLOCATE CUR_PRINTC23
      END   -- @cFilePath

      /****************************
       Prepare Next Screen
      ****************************/
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
         AND Mobile = @nMobile AND Status < '5')
      BEGIN
         -- tote completed, so need to return to 1st screen

         -- Check if all SKU in this tote picked and packed (james01)
         -- Check total picked & unshipped qty
         SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.Status = '5'
            AND PD.DropID = @cToteNo

         -- Check total packed & unshipped qty
         SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)
         FROM dbo.Packdetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE O.StorerKey = @cStorerKey
            AND O.Status NOT IN ('9', 'CANC')
            AND PD.DropID = @cToteNo

         -- Close DropID when pick & pack qty matches
         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL
         BEGIN
            SET @cSKU = ''
            SET @cOutField01 = @cToteNo
            SET @cOutField02 = ''
         END
         ELSE
         BEGIN
            --(Kc05)
            --(KC04) - start
            UPDATE dbo.DROPID WITH (Rowlock)
            SET   Status = '9'
            WHERE DropID = @cToteNo
            AND   Status < '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'
               GOTO Step_7_Fail
            END
            --(Kc04) - end

            -- (Shong01)
            EXEC [dbo].[nspInsertWCSRouting]
             @cStorerKey
            ,@cFacility
            ,@cToteNo
            ,'ECOMM_DSPT'
            ,'D'
            ,''
            ,@cUserName
            ,0
            ,@b_Success          OUTPUT
            ,@nErrNo             OUTPUT
            ,@cErrMsg   OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = @nErrNo
               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
               GOTO Step_7_Fail
            END

            -- (james13)
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cToteNo
            AND   AddWho = @cUserName
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Delete what ever for this tote which is not complete by orders
               DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  CLOSE CUR_UPD
                  DEALLOCATE CUR_UPD
                  SET @nErrNo = 69913
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcomLogFail'
                  GOTO Step_7_Fail
               END

               FETCH NEXT FROM CUR_UPD INTO @nRowRef
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD

            SET @cOutField01 = ''
            SET @cToteNo      = ''
            SET @cDropIDType  = ''
            SET @cOrderkey    = ''
            SET @cSku         = ''
            SET @nScn = @nScn - 6
            SET @nStep = @nStep - 6
         END
      END
      ELSE
      BEGIN
         IF @cDropIDType LIKE 'MULTIS%'
         BEGIN
            -- loop same screen
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
               AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5')
            BEGIN
               -- sku fully scanned for the tote
               SET @cSKU = ''
            END

            SET @cOutField01 = @cToteNo
            SET @cOutField02 = @cOrderkey
            SET @cOutField03 = ''--@cSku  -- (Vicky02)

            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4
         END
         ELSE
         BEGIN
            -- loop same screen
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno
               AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5'
               AND Orderkey = @cOrderkey)                   --(Kc03)
            BEGIN
               -- sku fully scanned for the order
               SET @cSKU = ''
            END
            SET @cOutField01 = @cToteNo
            SET @cOutField02 = '' --@cSku  -- (Vicky02)

            SET @nScn = @nScn - 5
            SET @nStep = @nStep - 5
         END
         GOTO Quit
      END
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOutField01 = @cToteNo
      SET @cOutField02 = ''

      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 2407
   TOTE NO:
   DROPID  (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
 BEGIN
      -- Screen mapping
      SET @cToteno = @cInField01

      --When ToteNo is blank
      IF ISNULL( @cToteno, '') = ''
      BEGIN
         SET @nErrNo = 71451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote req
         GOTO Step_8_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                 JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE TD.StorerKey = @cStorerKey
                    AND TD.DropID = @cToteno
                    AND O.USERDEFINE01 = ''
                    AND O.Status NOT IN ('9', 'CANC'))
      BEGIN
         SET @nErrNo = 71452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Store Tote
         GOTO Step_1_Fail
      END

      -- when tote does not exist in dropid
      IF NOT EXISTS ( SELECT 1 FROM dbo.DROPID DROPID WITH (NOLOCK)
                      WHERE DROPID.DropID = @cToteno
                      AND Status < '9')
      BEGIN
         SET @nErrNo = 71453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not exists
         GOTO Step_8_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                 JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE PD.Storerkey = @cStorerkey
                    AND TD.DropID = @cToteno
                    AND PD.Status IN ('3', '4')
                    AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 71454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShortPickFound
         GOTO Step_8_Fail
      END

      -- check any item on tote not picked or any picks exists for this tote
      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                 JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                 JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                 JOIN DBO.DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
                 WHERE PD.Storerkey = @cStorerkey AND TD.DropID = @cToteno AND PD.Status < '5'
                 AND PD.Qty > 0
                 AND (TD.PickMethod LIKE 'DOUBLES%' OR TD.PickMethod LIKE 'MULTIS%'))
      OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey AND DropID = @cToteNo)
      BEGIN
         SET @nErrNo = 71455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
         GOTO Step_8_Fail
      END

      SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0
      SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
         AND O.Status NOT IN ('9', 'CANC')
         AND PD.DropID = @cToteNo
         AND PH.Status <> '9'

      SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN DBO.DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE O.StorerKey = @cStorerKey
        AND O.Status NOT IN ('9', 'CANC')
        AND PD.DropID = @cToteNo
        AND PD.Status = '5'

      IF @nSUM_PackQTY = @nSUM_PickQTY
      OR EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToteNo AND Status = '9')
      BEGIN
         SET @nErrNo = 71456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted
         GOTO Step_8_Fail
      END

      SELECT @cDropIDType  = ISNULL(RTRIM(DropIDType),'')
      FROM dbo.DROPID WITH (NOLOCK)
      WHERE DropId = @cToteno

      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                      WHERE ListName = 'DROPIDTYPE'
                      AND   CODE = @cDropIDType)
      BEGIN
         SET @nErrNo = 71457
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote
         GOTO Step_8_Fail
      END

      -- Check if this tote scanned before
      IF EXISTS ( SELECT 1 FROM RDT.rdtECOMMLog WITH (NOLOCK) 
                  WHERE ToteNo = @cToteNo
                  AND   [Status] < '9')
      BEGIN
         SET @nErrNo = 71464
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote scan b4
         GOTO Step_8_Fail
      END

      SELECT @cParkTote_OrderKey = OrderKey
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   DropID = ISNULL(RTRIM(@cToteNo),'')
      AND   [Status] = '5'

      SELECT @cOrderKey= OrderKey
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   DropID = ISNULL(RTRIM(@cPrev_ToteNo),'')
      AND   [Status] = '5'

      IF ISNULL( @cParkTote_OrderKey, '') <> ISNULL( @cOrderKey, '')
      BEGIN
         SET @nErrNo = 71465
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff park tote
         GOTO Step_8_Fail
      END

      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo = @cToteNo
      AND   [Status] = '9'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Delete what ever for this tote which is not complete by orders
         DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            BREAK
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      /****************************
       UPDATE WCSROUTING
      ****************************/

      BEGIN TRAN

      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
      SET Status = '9'
      WHERE TOTENO = @cToteNo
      AND STATUS < '9'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 71458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRoutingDetail Fail
         GOTO Step_8_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRAN

      UPDATE dbo.WCSRouting WITH (ROWLOCK)
      SET Status = '9'
      WHERE TOTENO = @cToteNo
      AND STATUS < '9'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 71459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update WCSRouting Fail
         GOTO Step_8_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      -- Check for Unpick Order with No ToteNo
      IF @cDropIDType LIKE 'DOUBLES%'  OR @cDropIDType LIKE 'MULTIS%'
      BEGIN
         SET @nOrderCount = 1

         DECLARE CUR_UNPORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT P.Orderkey
         FROM dbo.PickDetail P WITH (NOLOCK)
         JOIN TaskDetail td WITH (NOLOCK) ON td.TaskDetailKey = P.TaskDetailKey
         JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON P.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE P.DropID = @cToteNo
         AND   TD.PickMethod = @cDropIDType
         AND   O.Status < '9'
         OPEN CUR_UNPORDER
         FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey

            IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                       WHERE Orderkey = @cUnPickOrderkey
                       AND Status = '0'
                    AND DropID = '' )
            BEGIN
               -- If orders with multiple totes and not all item picked then check whether
               -- this tote still have other outstanding task. If not then can proceed else prompt error
               IF @cSkipParkTote = '1'
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                              WHERE StorerKey = @cStorerKey
                              AND   TaskType = 'PK'
                              AND   Status < '9'
                              AND   DropID = @cToteNo)
                  BEGIN
                     SET @nErrNo = 71460
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_8_Fail
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 71461
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_8_Fail
               END
            END

            SET @nOrderCount = @nOrderCount + 1

            FETCH NEXT FROM CUR_UNPORDER INTO @cUnPickOrderkey
         CLOSE CUR_UNPORDER
         DEALLOCATE CUR_UNPORDER
      END

      SET @nParkTote = 0

      -- If skip pack tote feature turn on then skip below
      IF @cSkipParkTote <> '1'
      BEGIN

         /****************************
          Calculate # of Totes
         ****************************/
         SET @nToteCnt = 1
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         -- retrieve other totes
         DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT ISNULL(RTRIM(PK1.DROPID),'')
         FROM  dbo.PICKDETAIL PK1 WITH (NOLOCK)
         JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey = PK1.OrderKey
         JOIN DROPID DI WITH (NOLOCK) ON PK1.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
         WHERE EXISTS ( SELECT 1 from PICKDETAIL PK2 WITH (NOLOCK)
                        JOIN ORDERS O2 WITH (NOLOCK) ON O2.OrderKey = PK2.OrderKey
                        JOIN DROPID D2 WITH (NOLOCK) ON PK2.DROPID = D2.DROPID AND D2.LOADKEY = O2.LOADKEY
                        WHERE PK2.DROPID = ISNULL(RTRIM(@cToteNo),'')
                        AND   PK2.Orderkey = PK1.Orderkey )
         AND   NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog WITH (NOLOCK) WHERE TOTENO = PK1.DROPID and Status = '0' AND Orderkey = PK1.Orderkey)
         AND   PK1.DROPID <> ISNULL(RTRIM(@cToteNo),'')
         AND   PK1.STATUS = '5'
         ORDER BY ISNULL(RTRIM(PK1.DROPID),'')

         OPEN CUR_TOTE
         FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @nToteCnt = 1 SET @cOutField01 = @cOtherTote
            IF @nToteCnt = 2 SET @cOutField02 = @cOtherTote
            IF @nToteCnt = 3 SET @cOutField03 = @cOtherTote
            IF @nToteCnt = 4 SET @cOutField04 = @cOtherTote
            IF @nToteCnt = 5 SET @cOutField05 = @cOtherTote
            IF @nToteCnt = 6 SET @cOutField06 = @cOtherTote

            SET @nToteCnt = @nToteCnt + 1
            FETCH NEXT FROM CUR_TOTE INTO @cOtherTote
         END
         CLOSE CUR_TOTE
         DEALLOCATE CUR_TOTE

         IF ISNULL(RTRIM(@cOutField01),'') <> '' OR ISNULL(RTRIM(@cOutField02),'') <> ''
         OR ISNULL(RTRIM(@cOutField03),'') <> '' OR ISNULL(RTRIM(@cOutField04),'') <> ''
         OR ISNULL(RTRIM(@cOutField05),'') <> '' OR ISNULL(RTRIM(@cOutField06),'') <> ''
         BEGIN
            SET @nParkTote = 1
         END
      END

      /****************************
       INSERT INTO rdtECOMMLog
      ****************************/

      INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)
      SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()
      FROM dbo.PICKDETAIL PK WITH (NOLOCK)
      JOIN TaskDetail td WITH (NOLOCK) ON td.TaskDetailKey = PK.TaskDetailKey
      JOIN ORDERS o WITH (NOLOCK) ON O.OrderKey = PK.OrderKey
      JOIN DROPID DI WITH (NOLOCK) ON TD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY
      WHERE PK.DROPID = @cToteNo
      AND PK.Status = '5'
      AND O.Status < '9'
      AND PK.Qty > 0
      AND TD.PickMethod = @cDropIDType
      -- Assume 1 orders 1 pickslipno and no half packed orders
      AND NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER PH WITH (NOLOCK)
                      WHERE PH.Orderkey = PK.Orderkey
                      AND   PH.Status = '9')
      GROUP BY PK.Orderkey, PK.SKU

      IF @@ROWCOUNT = 0 -- No data inserted
      BEGIN
         SET @nErrNo = 71462
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
         GOTO Step_8_Fail
      END

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 71463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'
         GOTO Step_8_Fail
      END

      IF @nParkTote = 1
      BEGIN
         SET @cToteNo = ''
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
         
         GOTO Quit
      END

      /****************************
       prepare next screen variable
      ****************************/
      SET @cOutField01 = @cToteno

      IF @cDropIDType LIKE 'MULTIS%'
      BEGIN
         SELECT @cOrderkey = MIN(Orderkey)
         FROM  rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cToteNo
         AND   Status < '5'
         AND   Mobile = @nMobile

         SET @cOutField02 = @cOrderkey   --multis order will have only 1 order in the tote
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
      END
      ELSE
      BEGIN
         -- singles and doubles order type
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6
      END
      GOTO QUIT
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --initialise all variables
      SET @cToteNo      = ''
      SET @cDropIDType  = ''
      
      -- Prep next screen var
      SET @cOutField01 = ''

      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cDropIDType  = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(),
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       Printer_Paper = @cPrinter_Paper, -- (Vicky01)

       V_String1      = @cToteNo,
       V_String2      = @cDropIDType,
       V_String3      = @cOrderkey,
       V_String4      = @cSku,
       V_String5      = @nPrevScn,
       V_String6      = @nPrevStep,
       V_String7      = @cSkipParkTote,
       V_String8      = @cPrev_ToteNo,
       V_String9      = @cCartPick,
   
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