SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PickAndPack                                  */
/* Copyright      : IDS                                                 */
/* FBR:                                                                 */
/* Purpose: RDT Pick And Pack                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 14-Mar-2011  1.0  James      Created                                 */
/* 17-Mar-2011  1.1  James      Add in eventlog                         */
/* 04-Apr-2011  1.2  James      Add Traceinfo (james01)                 */
/* 18-May-2011  1.3  James      Perf tuning (james02)                   */
/* 01-Jun-2011  1.4  James      Fix commit tran issue (james02)         */
/* 02-Jun-2011  1.5  TLTING     Perf tuning (tlting01)                  */
/* 14-Feb-2012  1.6  Ung        SOS235398 Add SKU QTY, ID QTY counter   */
/* 19-Nov-2012  1.7  James      SOS261710 Extend DropID to NVARCHAR(20) */
/* 21-Feb-2013  1.8  James      SOS270278 - Use codelkup to determine   */
/*                              whether need capture serial no (james04)*/
/* 28-Apr-2013  1.9  James      SOS270278 - Use rdt storerconfig to crtl*/
/*                              which field store ADCode (james05)      */
/* 11-Jun-2013  2.0  James      SOS280603 - Add Loadkey (james06)       */
/* 26-Jun-2013  2.1  James      Remove Archivecop and mbol carton count */
/*                              back to packheader trigger (james07)    */
/* 27-Nov-2013  2.2  James      SOS294366 - Add msg queue after picking */
/*                              completed (james08)                     */
/* 10-Jan-2014  2.2  Leong      SOS# 297632 - Insert PackHeader with    */
/*                              Orders.StorerKey instead of @cStorerKey.*/
/* 03-Mar-2014  2.3  James      SOS300405 - Retrieve orderkey if only   */
/*                              loadkey keyed in to process drop id     */
/*                              validation (james09)                    */
/* 26-Mar-2014  2.4  James      SOS305925 - Process by load (james10)   */
/* 06-Aug-2014  2.5  Ung        SOS317600                               */
/*                              Add GenPickSlip                         */
/*                              Add ExtendedValidateSP                  */
/*                              Add ExtendedUpdateSP                    */
/* 22-Sep-2014  2.6  Ung        SOS321147 Add cancel order checking     */
/* 19-Nov-2014  2.7  Ung        SOS325017 Add CANC order checking       */
/* 05-May-2016  2.8  James      SOS369844 Add ExtendedUpdateSP in       */
/*                              step 3 (james11)                        */
/* 18-Aug-2016  2.9  James      SOS375364 Add DecodeSP (james12)        */
/* 05-Oct-2016  3.0  James      Perf tuning                             */
/* 10-Oct-2016  3.1  Ung        Perf tuning. ECOM bypass scan-in trigger*/
/* 07-Nov-2018  3.2  TungGH     Performance                             */
/* 08-Nov-2018  3.3  James      WMS6939-Add rdtIsValidFormat @ DropID   */
/*                              screen (james13)                        */
/* 06-Jun-2020  3.4  James      Add hoc bug fix (james14)               */
/* 25-May-2020  3.5  YeeKung    WMS-13277 Add CartonType Screen         */    
/*                              (yeekung01)                             */  
/* 26-Oct-2020  3.6  James      Remove temp variable used for traceinfo */
/* 02-Feb-2021  3.7  James      WMS-16293 Enhance AutoPackConfirm logic */
/*                              Add ExtendedUpdateSP to step 7 (james15)*/
/* 14-May-2021  3.8  James      WMS-16960 Add ExtendedInfoSP to step 7  */
/*                              esc part (james16)                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PickAndPack](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,
   @nCurScn             INT,  -- Current screen variable
   @nCurStep            INT,  -- Current step variable

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),

   @cWaveKey            NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cOption             NVARCHAR( 1),
   @cSKU                NVARCHAR( 20),
   @cRetailSKU          NVARCHAR( 20),
   @cSKU_Descr          NVARCHAR( 60),
   @cDropID             NVARCHAR( 20),     -- (james03)
   @cScan_SKU           NVARCHAR( 20),
   @cActSKU             NVARCHAR( 20),
   @cConsigneeKey       NVARCHAR( 15),
   @cGenPickSlipSP      NVARCHAR( 20),
   @cExternOrderKey     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),

   @cPickQTY            NVARCHAR( 5),
   @cActQty             NVARCHAR( 5),

   @nQtyToPick          INT,
   @nTotalPickQty       INT,
   @nActQty             INT,
   @nOrdCount           INT,
   @nOrderCnt           INT,
   @nDropIDCnt          INT,
   @nTTL_Alloc_Qty      INT,
   @cCongsineeKey       NVARCHAR( 15),
   @cCartonNo           NVARCHAR( 4),
   @nSKUCnt             INT,
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 255),
   @cPickSlipType       NVARCHAR( 10),
   @cPackUOM3           NVARCHAR( 10),

   @nTotal_Allocated    INT,
   @nTotal_Qty          INT,
   @nTotal_Picked       INT,
   @nTotal_SKU          INT,
   @nTotal_SKU_Picked   INT,
   @nSKU_QTY            INT,
   @nSKU_Picked    INT,
   @nDropID_QTY         INT,

   @cSQL            NVARCHAR(2000),
   @cSQLParam       NVARCHAR(2000),
   @cCheckDropID_SP NVARCHAR(20),
   @nValid          INT,

   @cReasonCode     NVARCHAR( 10),
   @cModuleName     NVARCHAR( 45),
   @cID             NVARCHAR( 18),
   @cPUOM           NVARCHAR( 1),
   @nQTY            INT,

   @cADCode         NVARCHAR( 18),
   @cSerialNoKey    NVARCHAR( 10),
   @cNotes          NVARCHAR( 45),
   @nOtherUnit2     INT,
   @nSum_PickQty    INT,
   @nCount_SerialNo INT,
   @nCartonNo       INT,
   @nSumPackQTY     INT,
   @nSumPickQTY     INT,
   @cPOrderKey      NVARCHAR(10),
   @nStartTranCnt   INT,
   @cErrMsg1        NVARCHAR( 20),
   @cErrMsg2        NVARCHAR( 20),
   @cErrMsg3        NVARCHAR( 20),
   @cErrMsg4        NVARCHAR( 20),
   @cErrMsg5        NVARCHAR( 20),

   @nCount           INT,              -- (james05)
   @cSKUFieldName    NVARCHAR( 30),    -- (james05)
   @cExecStatements  NVARCHAR( 4000),  -- (james05)
   @cExecArguments   NVARCHAR( 4000),  -- (james05)

   @nTranCount       INT,              -- (james06)
   @LP_OrderKey      NVARCHAR( 10),    -- (james06)

   -- (james12)
   @nSKUQTY             INT,
   @cDecodeSP           NVARCHAR( 20), 
   @cBarcode            NVARCHAR( 60), 
   @cUPC                NVARCHAR( 30), 
   @cLottable01         NVARCHAR( 18), 
   @cLottable02         NVARCHAR( 18), 
   @cLottable03         NVARCHAR( 18), 
   @dLottable04         DATETIME,    
   @dLottable05         DATETIME,    
   @cLottable06         NVARCHAR( 30), 
   @cLottable07         NVARCHAR( 30), 
   @cLottable08         NVARCHAR( 30), 
   @cLottable09         NVARCHAR( 30), 
   @cLottable10         NVARCHAR( 30), 
   @cLottable11         NVARCHAR( 30), 
   @cLottable12         NVARCHAR( 30), 
   @dLottable13         DATETIME,      
   @dLottable14         DATETIME,      
   @dLottable15         DATETIME,    
   @cUserDefine01       NVARCHAR( 60),  
   @cUserDefine02       NVARCHAR( 60),  
   @cUserDefine03       NVARCHAR( 60),  
   @cUserDefine04       NVARCHAR( 60),  
   @cUserDefine05       NVARCHAR( 60),
   @cWeight             FLOAT,        --(yeekung01)    
   @cCube               FLOAT,        --(yeekung01)    
   @cRefNo              NVARCHAR(20),  --(yeekung01)    
   @cCapturePackInfoSP  NVARCHAR( 20), --(yeekung01)     
   @cPackInfo           NVARCHAR( 4),  --(yeekung01)    
   @cDefaultWeight      NVARCHAR( 1),  --(yeekung01)    
   @cAllowWeightZero    NVARCHAR( 1),  --(yeekung01)    
   @cAllowCubeZero      NVARCHAR( 1),  --(yeekung01)    
   @cCartonType         NVARCHAR(20),  --(yeekung01)     
   @cAutoPackConfirm    NVARCHAR( 1),  --(james15)     

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

DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20),
   @c_LabelNo            NVARCHAR( 32)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cPickSlipNo      = V_PickSlipNo,
   @cOrderKey        = V_OrderKey,
   @cLoadKey         = V_LoadKey,

   @cConsigneeKey    = V_ConsigneeKey,
   @cSKU             = V_SKU,
   @cSKU_Descr       = V_SKUDescr,

   @cWaveKey            = V_String1,
   @cGenPickSlipSP      = V_String3,
   @cExtendedValidateSP = V_String4,
   @cExtendedUpdateSP   = V_String5,
   @cDecodeSP           = V_String6,  -- (james12)
   @cAutoPackConfirm    = V_String7,  -- (james15)
   @cExternOrderKey     = V_String12,
   @cDropID             = V_String17,
   @cRefNo              = V_String18, --(yeekung01)    
   @cCapturePackInfoSP  = V_String19, --(yeekung01)    
   @cPackInfo           = V_String20, --(yeekung01)    
   @cAllowWeightZero    = V_String21, --(yeekung01)    
   @cAllowCubeZero      = V_String22, --(yeekung01)    
   @cDefaultWeight      = V_String23, --(yeekung01)    
   @cCartonType         = V_String24, --(yeekung01)  
   
   @nActQty             = V_QTY,
      
   @nOrdCount           = V_Integer1,
   @nQtyToPick          = V_Integer2,
   @nTotalPickQty       = V_Integer3,
   @nCurScn             = V_Integer4,
   @nCurStep            = V_Integer5,
   @cWeight             = V_Integer6,  --(yeekung01)    
   @cCube               = V_Integer7, --(yeekung01)   
   
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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 868      -- RDT Pick And Pack
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0 -- Menu. Func = 868
   IF @nStep = 1  GOTO Step_1 -- Scn = 2740. OrderKey
   IF @nStep = 2  GOTO Step_2 -- Scn = 2741. DropID
   IF @nStep = 3  GOTO Step_3 -- Scn = 2742. SKU
   IF @nStep = 4  GOTO Step_4 -- Scn = 2743. ADCode
   IF @nStep = 5  GOTO Step_5 -- Scn = 2011. Reason
   IF @nStep = 6  GOTO Step_6 -- Scn = 2744. Picking Completed
 	IF @nStep = 7  GOTO Step_7  -- Scn = 2745. Carton type, weight, cube, refno    
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 868
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cGenPickSlipSP = rdt.RDTGetConfig( @nFunc, 'GenPickSlipSP', @cStorerKey)
   IF @cGenPickSlipSP = '0'
      SET @cGenPickSlipSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)      
   IF @cCapturePackInfoSP = '0'      
      SET @cCapturePackInfoSP = '' 
      
   -- (james12)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
      
   --(yeekung01)    
   SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)      
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)      
   SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)  
   
   -- (james15)
   SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   
   -- Prepare next screen var
   SET @cOutField01 = '' -- OrderKey
   SET @cOutField02 = '' -- LoadKey

   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Go to WaveKey screen
   SET @nScn = 2740
   SET @nStep = 1
   
   -- Clear the uncompleted task for the same login
   DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
   WHERE StorerKey = @cStorerKey
      AND AddWho = @cUserName

   IF rdt.RDTGetConfig( @nFunc, 'PickSetFocusOnLoadkey', @cStorerKey) = '1'
      EXEC rdt.rdtSetFocusField @nMobile, 1 --LoadKey
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 2 --OrderKey
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 2740
   LoadKey     (field01, input)
   OrderKey    (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cLoadKey = @cInField01
      SET @cOrderKey = @cInField02

      -- If all 2 input is blank (james06)
      IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 72623
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORD/LOAD Req
         GOTO Quit
      END

      -- If all 2 input key in (james06)
      IF ISNULL(@cOrderKey, '') <> '' AND ISNULL(@cLoadKey, '') <> ''
      BEGIN
         SET @nErrNo = 72624
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ONLY ORD/LOAD
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         GOTO Quit
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN STEP_1
         
      IF ISNULL(@cOrderKey, '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 72592
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
            GOTO Step_OrderKey_Fail
         END

         IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND 'CANC' IN (Status, SOStatus))
         BEGIN
            SET @nErrNo = 72634
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            GOTO Step_OrderKey_Fail
         END         

         IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND Status >= '1'
               AND Status < '5')
         BEGIN
            SET @nErrNo = 72593
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ORD Status
            GOTO Step_OrderKey_Fail
         END

         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         WHERE PH.OrderKey = @cOrderKey
            AND PH.Status = '0'

         -- If not discrete orders, look in loadplan
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON PH.ExternOrderKey = O.LoadKey
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE OD.StorerKey = @cStorerKey
               AND O.OrderKey = @cOrderKey
               AND PH.Status = '0'
         END

         -- Not discrete, not conso then check wave
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE OD.StorerKey = @cStorerKey
               AND O.OrderKey = @cOrderKey
               AND PH.Status = '0'
         END

         -- Generate pick slip
         IF @cPickSlipNo = '' AND @cGenPickSlipSP <> ''
         BEGIN
            EXEC rdt.rdt_PickAndPack_GenPickSlip @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, 
               @cGenPickSlipSP, 
               @cOrderKey, 
               @cPickSlipNo OUTPUT, 
               @nErrNo      OUTPUT, 
               @cErrMsg     OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Check if pickslip printed
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 72594
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
            GOTO Step_OrderKey_Fail
         END
         ELSE  -- pickslip printed, check if scanned out
         BEGIN
            -- Check if pickslip scanned out
            IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND ScanOutDate IS NOT NULL)
            BEGIN
               SET @nErrNo = 72595
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scanned Out
               GOTO Step_OrderKey_Fail
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho, TrafficCop)
            VALUES
            (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName, 'U')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72632
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan In Fail'
               GOTO Step_OrderKey_Fail
            END
         END

         -- This part only for discrete pick slip
         IF EXISTS ( SELECT 1
                     FROM dbo.PickHeader PH WITH (NOLOCK)
                     WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND ISNULL(RTRIM(PH.ORderkey), '') = '')
         BEGIN
            SET @cPickSlipType = 'CONSO'
         END
         ELSE
         BEGIN
            SET @cPickSlipType = 'SINGLE'
         END

         -- If configkey turned on, start insert Pack Header (James05)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1'
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'InsDiscretePackHdrInfo', @cStorerKey) <> '1'
            BEGIN
               IF @cPickSlipType = 'SINGLE'
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
                  BEGIN
                     INSERT INTO dbo.PackHeader
                     (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                     SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.StorerKey, @cPickSlipNo -- SOS# 297632
                     FROM  dbo.PickHeader PH WITH (NOLOCK)
                     JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                     WHERE PH.PickHeaderKey = @cPickSlipNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 72596
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                        GOTO Step_OrderKey_Fail
                     END
                  END
               END
               ELSE  -- IF @cPickSlipType = 'CONSO'
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
                  BEGIN
                     INSERT INTO dbo.PackHeader
                     (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                     SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', O.StorerKey, @cPickSlipNo -- SOS# 297632
                     FROM  dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
                     JOIN  dbo.LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
                     JOIN  dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                     JOIN  dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                     WHERE PH.PickHeaderKey = @cPickSlipNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 72597
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                        GOTO Step_OrderKey_Fail
                     END
                  END
               END
            END  -- 'InsDiscretePackHdrInfo'
         END   -- 'ClusterPickInsPackDt'

         -- If LoadKey is blank, retrieve respective loadkey
         IF ISNULL(@cLoadKey, '') = ''
         BEGIN
            SELECT TOP 1 @cLoadKey = ISNULL(RTRIM(LoadKey),'')
            FROM dbo.OrderDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND Status >= '1'
               AND Status < '5'
         END

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND Status = '1')
         BEGIN
            -- Insert OrderKey scanned to picklock
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
            VALUES
            ('', '', @cOrderKey, '*', @cStorerKey, '', '', @cOrderKey
            , '', '', '1', @cUserName, GETDATE(), @cPickSlipNo, @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72598
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockOrdersFail'
               GOTO Step_OrderKey_Fail
            END

            SELECT TOP 1
               @cExternOrderKey = ExternOrderKey,
               @cConsigneeKey = ConsigneeKey
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

            SET @cOutField01 = @cOrderKey
            SET @cOutField02 = @cExternOrderKey
            SET @cOutField03 = @cConsigneeKey
            SET @cOutField04 = ''
            SET @cOutField05 = ''

            SET @cLoadKey = ''

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            -- commit before we go anywhere
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
         END
         ELSE
         BEGIN
            SET @nErrNo = 72599
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Order Locked'
            GOTO Step_OrderKey_Fail
         END
      END
      ELSE  -- Loadkey
      BEGIN
         IF NOT EXISTS ( SELECT 1 from dbo.LoadPlan WITH (NOLOCK)
                        WHERE LoadKey = @cLoadKey )
         BEGIN
            SET @nErrNo = 72625
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LOADKEY
            GOTO Step_LoadKey_Fail
         END

         IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                        JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (LPD.OrderKey = OD.OrderKey)
                        WHERE LPD.LoadKey = @cLoadKey
                        AND   OD.StorerKey = @cStorerKey
                        AND   OD.Status < '1'
                        AND   OD.Status > '5')
         BEGIN
            SET @nErrNo = 72626
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ORD Status
            GOTO Step_LoadKey_Fail
         END

         SET @cPickSlipNo = ''
         SET @LP_OrderKey = ''

         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE ExternOrderKey = @cLoadKey
         AND   ISNULL(OrderKey, '') = ''
         AND   [Status] = '0'

         IF ISNULL(@cPickSlipNo, '') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
               SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', O.StorerKey, @cPickSlipNo -- SOS# 297632
               FROM  dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
               JOIN  dbo.LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
               JOIN  dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
               JOIN  dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               WHERE PH.PickHeaderKey = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 72630
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                  GOTO Step_LoadKey_Fail
               END
            END
         END
         ELSE
         BEGIN
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT OrderKey FROM dbo.LoadPlanDetail WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @LP_OrderKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE OrderKey = @LP_OrderKey
               AND   [Status] = '0'

               -- Check if pickslip printed
               IF ISNULL(@cPickSlipNo, '') = ''
               BEGIN
                  SET @nErrNo = 72627
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
                  CLOSE CUR_LOOP
                  DEALLOCATE CUR_LOOP
                  GOTO Step_LoadKey_Fail
               END

               -- Scan in pickslip, if not yet
               IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  INSERT INTO dbo.PickingInfo
                  (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
                  VALUES
                  (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)
               
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 72629
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan In Fail
                     CLOSE CUR_LOOP
                     DEALLOCATE CUR_LOOP
                     GOTO Step_LoadKey_Fail
                  END
               END
               
              IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                  SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.StorerKey, @cPickSlipNo -- SOS# 297632
                  FROM  dbo.PickHeader PH WITH (NOLOCK)
                  JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 72631
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                     CLOSE CUR_LOOP
                     DEALLOCATE CUR_LOOP
                     GOTO Step_LoadKey_Fail
                  END
               END

               FETCH NEXT FROM CUR_LOOP INTO @LP_OrderKey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                        WHERE LoadKey = @cLoadKey
                        AND Status = '1')
         BEGIN
            -- Insert OrderKey scanned to picklock
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
            VALUES
            ('', @cLoadKey, '', '', @cStorerKey, '', '', ''
            , '', '', '1', @cUserName, GETDATE(), '', @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72633
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKLockFail'
               GOTO Step_LoadKey_Fail
            END
         END

         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN

         SELECT TOP 1
            @cExternOrderKey = ExternOrderKey,
            @cConsigneeKey = ConsigneeKey
         FROM dbo.LoadPlanDetail WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey

         SET @cOutField01 = ''
         SET @cOutField02 = @cExternOrderKey
         SET @cOutField03 = @cConsigneeKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cLoadKey

         SET @cOrderKey = ''

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Release orders scanned from RDTPickLock
      DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
      WHERE AddWho = @cUserName
         AND Status IN ('1', '5', 'X')
         AND StorerKey = @cStorerKey

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
      SET @cOutField02 = ''
      SET @cOrderKey = ''
      SET @cLoadKey = ''
   END

   GOTO Quit

   Step_OrderKey_Fail:
   BEGIN
      ROLLBACK TRAN STEP_1
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN 
      
      SET @cOutField01 = ''
      SET @cOrderKey = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2 --Orderkey
   END
   GOTO Quit

   Step_LoadKey_Fail:
   BEGIN
      ROLLBACK TRAN STEP_1
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN 
         
      SET @cOutField02 = ''
      SET @cLoadKey = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 --Loadkey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 2741
   Drop ID     (field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOrderKey = @cOutField01
      SET @cDropID = UPPER(@cInField04)
      SET @cLoadKey = @cOutField05

      -- If config turned on, DropID field is mandatory
      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickScanDropID', @cStorerKey) = '1' AND ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 72601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID needed
         GOTO Step_2_Fail
      END

      --if DropID scanned, check whether the prefix is 'ID'
      IF ISNULL(@cDropID, '') <> ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'Not_Check_ID_Prefix', @cStorerKey) <> '1'
         BEGIN
            IF SUBSTRING(@cDropID, 1, 2) <> 'ID'
            BEGIN
               SET @nErrNo = 72602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
               GOTO Step_2_Fail
            END
         END

         -- (james09)
         -- because the drop id validation passed in orderkey only. so now need to get 1 orderkey to process
         DECLARE @nOriOrderKey INT  
         SET @nOriOrderKey = 1  
         IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLoadKey, '') <> ''  
         BEGIN  
            SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.Orders WITH (NOLOCK) WHERE LoadKey = @cLoadKey  
            SET @nOriOrderKey = 0  
         END  

         -- Stored Proc to validate Drop ID by storerkey
         SET @cCheckDropID_SP = rdt.RDTGetConfig( 0, 'CheckDropID_SP', @cStorerKey)

         IF ISNULL(@cCheckDropID_SP, '') NOT IN ('', '0')
         BEGIN
            SET @cSQL = N'EXEC rdt.' + RTRIM(@cCheckDropID_SP) +
                                  ' @cFacility, @cStorerkey, @cOrderkey, @cDropID, @nValid OUTPUT, @nErrNo OUTPUT,  @cErrMsg OUTPUT'

            SET @cSQLParam = N'@cFacility    NVARCHAR( 5),         ' +
                              '@cStorerkey   NVARCHAR( 15),        ' +
                              '@cOrderkey    NVARCHAR( 10),        ' +
                              '@cDropID      NVARCHAR( 18),        ' +
                              '@nValid       INT      OUTPUT,  ' +
                              '@nErrNo       INT      OUTPUT,  ' +
                              '@cErrMsg      NVARCHAR(20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                                 @cFacility,
                                 @cStorerKey,
                                 @cOrderKey,
                                 @cDropID,
                                 @nValid  OUTPUT,
                                 @nErrNo  OUTPUT,
                                 @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_2_Fail
            END

            IF @nValid = 0
            BEGIN
               SET @nErrNo = 72603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
               GOTO Step_2_Fail
            END

            -- Reset back the orderkey if originally only loadkey key in (james09)
            IF @nOriOrderKey = 0  
               SET @cOrderKey = ''  
         END
         
         -- Check from id format (james13)
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
         BEGIN
            SET @nErrNo = 72635
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_2_Fail
         END
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cADCode      NVARCHAR( 18), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         -- If OrderKey exists then update else insert new line
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND Status = '1'
            AND AddWho = @cUserName)
         BEGIN
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET
               DropID = @cDropID
            WHERE OrderKey = @cOrderKey
               AND Status = '1'
               AND AddWho = @cUserName
               
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, DropID, Mobile)
            VALUES
            ('', '', @cOrderKey, '**', @cStorerKey, '', '', @cOrderKey
            , '', '', '1', @cUserName, GETDATE(), @cPickSlipNo, @cDropID, @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKLockFail'
               GOTO Step_2_Fail
            END
         END
      END

      IF ISNULL(@cLoadKey, '') <> ''
      BEGIN
         -- If OrderKey exists then update else insert new line
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND Status = '1'
            AND AddWho = @cUserName)
         BEGIN
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET
               DropID = @cDropID
            WHERE OrderKey = @cOrderKey
               AND Status = '1'
               AND AddWho = @cUserName

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, DropID, Mobile)
            VALUES
            ('', @cLoadKey, '', '', @cStorerKey, '', '', ''
            , '', '', '1', @cUserName, GETDATE(), '', @cDropID, @nMobile)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 72605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKLockFail'
               GOTO Step_2_Fail
            END
         END
      END
                  
      SET @cSKU = ''
      EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,
         @nTotal_Qty        OUTPUT,
         @nTotal_Picked     OUTPUT,
         @nTotal_SKU        OUTPUT,
         @nTotal_SKU_Picked OUTPUT,
         @nSKU_QTY          OUTPUT,
         @nSKU_Picked       OUTPUT,
         @nDropID_QTY       OUTPUT

      -- Prep next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = CASE WHEN ISNULL( @cLoadKey, '') = '' THEN @cOrderKey ELSE '' END
      SET @cOutField06 = @cExternOrderKey
      SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))
      SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))
      SET @cOutField11 = @cLoadKey

      -- Go to next screen
      SET @nScn  = 2742
      SET @nStep = 3

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

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Clear the uncompleted task for the same login
      DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
      WHERE StorerKey = @cStorerKey
         AND Status IN ('1', '5', 'X')
         AND AddWho = @cUserName

      SET @cOrderKey = ''
      SET @cLoadKey = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      IF rdt.RDTGetConfig( @nFunc, 'PickSetFocusOnLoadkey', @cStorerKey) = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 1 --LoadKey
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 --OrderKey

   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField04 = ''   --DropID
   END

END
GOTO Quit

/********************************************************************************
Step 3. Screen = 2742
   SKU/UPC     (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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
      SET @c_LabelNo = ''

      IF ISNULL(@cInField02, '') = ''
      BEGIN
         SET @nErrNo = 72606
         SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU req'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         GOTO Step_3_Fail
      END

      -- If len of the input is > 20 characters then this is not a SKU
      -- use label decoding
      IF LEN(ISNULL(@cInField02, '')) > 20
      BEGIN
         SET @c_LabelNo = @cInField02
      END

      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      -- If len of the input is > 20 characters then this is not a SKU
      -- use label decoding
      IF ISNULL(@c_LabelNo, '') <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeLabelNo AND type = 'P')
      BEGIN
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @c_LabelNo
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @cErrMsg1 = @cErrMsg
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_3_Fail
         END

         SET @cActSKU = @c_oFieled01
         SET @cActQty = @c_oFieled05
      END

      IF LEN(ISNULL(@cInField02, '')) > 20
      BEGIN
         SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
         SET @cActQty = ISNULL(LTRIM(RTRIM(@cActQty)), '')
      END
      ELSE
      BEGIN
         SET @cActSKU = @cInField02
      END

      -- (james12)
      IF @cDecodeSP <> '' AND ISNULL( @cDecodeLabelNo, '') = ''
      BEGIN
         SET @cBarcode = @cInField02

         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cLoadKey, @cOrderKey, ' +
               ' @cUPC           OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' + 
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +               
               ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY           INT            OUTPUT, ' +
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04    DATETIME       OUTPUT, ' +
               ' @dLottable05    DATETIME       OUTPUT, ' +
               ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13    DATETIME       OUTPUT, ' +
               ' @dLottable14    DATETIME       OUTPUT, ' +
               ' @dLottable15    DATETIME       OUTPUT, ' +
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cLoadKey, @cOrderKey, 
               @cUPC          OUTPUT, @nQTY           OUTPUT, @cDropID        OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,               
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            SET @cActSKU = @cUPC
            SET @cActQty = @nQTY
         END
      END   -- End for DecodeSP
      
      --if SKU scanned
      IF ISNULL(@cActSKU, '') <> ''
      BEGIN
         -- Get SKU/UPC
         EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cActSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 72607
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_3_Fail
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 72608
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_3_Fail
         END

         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cActSKU       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         IF LEN(ISNULL(@cInField02, '')) > 20 
         BEGIN
            IF @cActQty = '0'
            BEGIN
               SET @cActQty = ''
               SET @nErrNo = 72609
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               GOTO Step_3_Fail
            END
         END
         ELSE
         BEGIN
            SET @cActQty = '1'
         END

         SET @cSKU = @cActSKU

         IF ISNULL(@cLoadKey, '') <> ''
         BEGIN
            SELECT TOP 1 @cOrderKey = PD.OrderKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
            AND   PD.StorerKey = @cStorerKey
            AND   PD.Status = '0'
            AND   PD.SKU = @cSKU
            ORDER BY PD.OrderKey

            SELECT TOP 1
               @cExternOrderKey = ExternOrderKey,
               @cConsigneeKey = ConsigneeKey
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND   [Status] = '0'
         END

         -- Check if SKU exists in orders
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND Status = '0')
         BEGIN
            SET @nErrNo = 72610
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUNotInORD'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_3_Fail
         END

         IF ISNULL(@cLoadKey, '') = ''
         BEGIN
            -- Check if over pick
            SELECT @nTotal_Allocated = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND Status = '0'

            SELECT @nTotal_Picked = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cSKU
            AND Status >= '4'
         END
         ELSE
         BEGIN
            -- Check if over pick
            SELECT @nTotal_Allocated = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.SKU = @cSKU
            AND   PD.Status = '0'
            AND   LPD.LoadKey = @cLoadKey

            SELECT @nTotal_Picked = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.SKU = @cSKU
            AND   PD.Status >= '4'
            AND   LPD.LoadKey = @cLoadKey
         END

         IF CAST(@cActQty AS INT) > @nTotal_Allocated
         BEGIN
            SET @nErrNo = 72611
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Pick'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_3_Fail
         END

         BEGIN TRAN

         IF ISNULL( @cLoadKey, '') = ''   -- (james10)
         BEGIN
            -- Insert SKU + Qty into rdt.rdtPickLock
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND Status = '1'
               AND DropID = @cDropID
               AND AddWho = @cUserName)
            BEGIN
               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
               , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, SKU, PickQty, DropID, Mobile)
               VALUES
               ('', '', @cOrderKey, '**', @cStorerKey, '', '', @cOrderKey
               , '', '', '1', @cUserName, GETDATE(), @cPickSlipNo, @cSKU, CAST(@cActQty AS INT), @cDropID, @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72612
                  SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKLockFail'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  GOTO Step_3_Fail
               END
            END
            ELSE
            BEGIN
               UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                  SKU = @cSKU,
                  PickQty = PickQty + CAST(@cActQty AS INT)
               WHERE OrderKey = @cOrderKey
                  AND DropID = @cDropID
                  AND Status = '1'
                  AND AddWho = @cUserName

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72613
                  SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  GOTO Step_3_Fail
               END
            END
         END
         
         IF ISNULL( @cLoadKey, '') <> ''  -- (james10) 
         BEGIN
            -- Insert SKU + Qty into rdt.rdtPickLock
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
               AND Status = '1'
               AND DropID = @cDropID
               AND AddWho = @cUserName)
            BEGIN
               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
               , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, SKU, PickQty, DropID, Mobile)
               VALUES
               ('', @cLoadKey, '', '', @cStorerKey, '', '', ''
               , '', '', '1', @cUserName, GETDATE(), '', @cSKU, CAST(@cActQty AS INT), @cDropID, @nMobile)

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72612
                  SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKLockFail'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  GOTO Step_3_Fail
               END
            END
            ELSE
            BEGIN
               UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                  SKU = @cSKU,
                  PickQty = PickQty + CAST(@cActQty AS INT)
               WHERE LoadKey = @cLoadKey
                  AND DropID = @cDropID
                  AND Status = '1'
                  AND AddWho = @cUserName

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72613
                  SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  GOTO Step_3_Fail
               END
            END
         END
         
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1'
         BEGIN
            EXECUTE rdt.rdt_PickAndPack_InsPack
               @nMobile,
               @nFunc,
               @cStorerKey,
               @cUserName,
               @cOrderKey,
               @cSKU,
               @cPickSlipNo,
               @cDropID,
               @cLoadKey,
               @cLangCode,
               @nErrNo           OUTPUT,
               @cErrMsg          OUTPUT

            IF @nErrNo <> 0 OR @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @cErrMsg1 = @cErrMsg
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               GOTO Step_3_Fail
            END
            ELSE
            BEGIN
               -- If SKU.SUSR4 setup with L'Oreal Anti-Diversion code
               -- Use codelkup to determine whether we need to capture serial no (james04)
--               IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK)
--                  WHERE StorerKey = @cStorerKey
--                     AND SKU = @cSKU
--                     AND SUSR4 = 'AD')
--               IF EXISTS ( SELECT 1
--                           FROM dbo.CODELKUP CLK WITH (NOLOCK)
--                           JOIN dbo.SKU SKU WITH (NOLOCK) ON (CLK.StorerKey = SKU.StorerKey AND CLK.Code = SKU.SUSR4)
--                           WHERE CLK.StorerKey = @cStorerKey
--                           AND   CLK.ListName = 'PICKSERIAL'
--                           AND   SKU.SKU = @cSKU ) OR
--                  -- cater for existing customer who not setup codelkup yet
--                  EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
--                           WHERE StorerKey = @cStorerKey
--                           AND   SKU = @cSKU
--                           AND   SUSR4 = 'AD' )
               SET @nCount = 0
               SET @cSKUFieldName = rdt.RDTGetConfig( @nFunc, 'FieldName2CaptureSerialNo', @cStorerKey)
               IF ISNULL(@cSKUFieldName, '') NOT IN ('', '0')
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM SYS.COLUMNS
                                WHERE NAME = @cSKUFieldName
                                AND   OBJECT_ID = OBJECT_ID(N'SKU'))
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 72622
                     SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD SKU Field'
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                     GOTO Step_3_Fail
                  END

                  SET @cExecStatements = ''
                  SET @cExecStatements = 'SELECT @nCount = COUNT(1) ' +
                           'FROM dbo.CODELKUP CLK WITH (NOLOCK) ' +
                           'JOIN dbo.SKU SKU WITH (NOLOCK) ON (CLK.StorerKey = SKU.StorerKey AND CLK.Code = SKU.' + RTRIM(@cSKUFieldName) + ') ' +
                           'WHERE CLK.StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' +
                           'AND CLK.ListName = ''PICKSERIAL'' ' +
                           'AND   SKU.SKU = ''' + RTRIM(@cSKU)  + ''' '
                  SET @cExecArguments = N'@nCount            INT     OUTPUT , ' +
                                         '@cSKUFieldName     NVARCHAR( 30)  , ' +
                                         '@cStorerKey        NVARCHAR( 15)  , ' +
                                         '@cSKU              NVARCHAR( 20)   '
                  EXEC sp_ExecuteSql @cExecStatements
                                   , @cExecArguments
                                   , @nCount       OUTPUT
                                   , @cSKUFieldName
                                   , @cStorerKey
                                   , @cSKU
               END

               IF @nCount > 0 OR
               -- cater for existing customer who not setup codelkup yet
               EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   SKU = @cSKU
                        AND   SUSR4 = 'AD' )
               BEGIN
                  SELECT @nOtherUnit2 = OtherUnit2 FROM Pack P WITH (NOLOCK)
                  JOIN SKU S WITH (NOLOCK) ON (P.PackKey = S.PackKey)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU

                  IF @nOtherUnit2 <= 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 72614
                     SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockOrdersFail'
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                     GOTO Step_3_Fail
                  END

                  SELECT @nSum_PickQty = ISNULL(SUM(PickQty), 0) FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey
                   AND SKU = @cSKU
                     AND AddWho = @cUserName

                  SELECT @nCount_SerialNo = Count(1) FROM dbo.SerialNo WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey
                     AND SKU = @cSKU

                  IF @nOtherUnit2 > 0 AND (@nSum_PickQty % @nOtherUnit2 = 0)
                  BEGIN
                     -- Check whether still need to scan Anti-Diversion code
                     IF (@nSum_PickQty / @nOtherUnit2) > @nCount_SerialNo
                     BEGIN
                        SET @cOutField01 = @cSKU
                        SET @cOutField02 = SUBSTRING(@cSKU_Descr,  1, 20)
                        SET @cOutField03 = SUBSTRING(@cSKU_Descr, 21, 20)
                        SET @cOutField04 = SUBSTRING(@cSKU_Descr, 41, 20)
                        SET @cOutField05 = ''
                        SET @cOutField06 = CAST(@nCount_SerialNo AS NVARCHAR( 5)) + '/' + CAST((@nSum_PickQty / @nOtherUnit2) AS NVARCHAR( 5))

                        SET @nCurScn = @nScn  -- remember current screen no
                        SET @nCurStep = @nStep  -- remember current step no

                        -- Go to Anti-Diversion code screen
                        SET @nScn  = 2743
                        SET @nStep = 4

                        COMMIT TRAN -- (James02)

                        GOTO Quit
                     END
                  END
               END

               SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND StorerKey = @cStorerKey

               SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE Orderkey = @cOrderKey
               AND   StorerKey = @cStorerKey

               -- Only when config 'AUTOPACKCONFIRM' is turned on and pick and pack match then scan out
               IF (@nSumPackQTY = @nSumPickQTY) AND @cAutoPackConfirm = '1'
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                             WHERE StorerKey = @cStorerKey
                             AND Orderkey = @cPOrderKey
                             AND Status < '5')
                  BEGIN
                     UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                        STATUS = '9'
                        --ArchiveCop = NULL
                     WHERE PickSlipNo = @cPickSlipNo
                     --   AND StorerKey = @cStorerKey   -- tlting01

                     IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
                     BEGIN
                        UPDATE dbo.PickingInfo WITH (ROWLOCK)
                           SET SCANOUTDATE = GETDATE(),
                               EditWho = @cUserName
                        WHERE PickSlipNo = @cPickSlipNo
                     END

                     IF @@ERROR <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 72615
                        SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ConfPackFail'
                        EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                        GOTO Step_3_Fail
                     END
                  END
               END

               -- Extended update
               IF @cExtendedUpdateSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                     SET @cSQLParam =
                        '@nMobile      INT,           ' +
                        '@nFunc        INT,           ' +
                        '@cLangCode    NVARCHAR( 3),  ' +
                        '@nStep        INT,           ' +
                        '@nInputKey    INT,           ' +
                        '@cStorerKey   NVARCHAR( 15), ' +
                        '@cFacility    NVARCHAR( 5),  ' +
                        '@cOrderKey    NVARCHAR( 10), ' +
                        '@cLoadKey     NVARCHAR( 10), ' +
                        '@cDropID      NVARCHAR( 20), ' +
                        '@cSKU         NVARCHAR( 20), ' +
                        '@cADCode      NVARCHAR( 18), ' +
                        '@nErrNo       INT OUTPUT,    ' +
                        '@cErrMsg      NVARCHAR( 20) OUTPUT'
            
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
                     -- (james14)
                     IF @nErrNo <> 0    
                     BEGIN
                        ROLLBACK TRAN
                        GOTO Quit
                     END    
                  END
               END
      
               SELECT @cSKU_Descr = Descr FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,
                  @nTotal_Qty        OUTPUT,
                  @nTotal_Picked   OUTPUT,
                  @nTotal_SKU        OUTPUT,
                  @nTotal_SKU_Picked OUTPUT,
                  @nSKU_QTY          OUTPUT,
                  @nSKU_Picked       OUTPUT,
                  @nDropID_QTY       OUTPUT

               -- Prep next screen var
               SET @cOutField01 = @cDropID
               SET @cOutField02 = ''
               SET @cOutField03 = SUBSTRING(@cSKU_Descr, 1, 20)
               SET @cOutField04 = SUBSTRING(@cSKU_Descr, 21, 20)
               SET @cOutField05 = CASE WHEN ISNULL( @cLoadKey, '') = '' THEN @cOrderKey ELSE '' END
               SET @cOutField06 = @cExternOrderKey
               SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))
               SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))
               SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))
               SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))
               SET @cOutField11 = @cLoadKey

               IF @nTotal_Picked = @nTotal_Qty
               BEGIN
                  SET @nScn = 2744
                  SET @nStep = 6

                  SET @cOutField01 = @nTotal_Picked
                  SET @cOutField02 = @nTotal_SKU_Picked

                  COMMIT TRAN -- (ChewKP_RDT2) Commit before Exit SP

                  GOTO Quit
               END
            END
         END

         COMMIT TRAN
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cADCode      NVARCHAR( 18), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
		IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE StorerKey = @cStorerKey    
               AND SKU = @cSKU    
               AND dropid =@cDropID)  
      -- Custom PackInfo field setup    
      BEGIN    
         SET @cPackInfo = ''      
         IF @cCapturePackInfoSP <> ''      
         BEGIN      
            -- Custom SP to get PackInfo setup      
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')      
            BEGIN      
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +      
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cDropID,  ' +       
                  ' @nErrNo      OUTPUT, ' +       
                  ' @cErrMsg     OUTPUT, ' +      
                  ' @cPackInfo   OUTPUT, ' +      
                  ' @cWeight     OUTPUT, ' +      
                  ' @cCube       OUTPUT, ' +      
                  ' @cRefNo      OUTPUT, ' +      
                  ' @cCartonType OUTPUT'      
               SET @cSQLParam =      
                  '@nMobile     INT,           ' +      
                  '@nFunc       INT,           ' +      
                  '@cLangCode   NVARCHAR( 3),  ' +      
                  '@nStep       INT,           ' +      
                  '@nInputKey   INT,           ' +      
                  '@cFacility   NVARCHAR( 5),  ' +      
                  '@cStorerKey  NVARCHAR( 15), ' +      
                  '@cPickSlipNo NVARCHAR( 10), ' +      
                  '@cDropID NVARCHAR( 20), ' +       
                  '@nErrNo      INT           OUTPUT, ' +      
                  '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +      
                  '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +      
                  '@cWeight     NVARCHAR( 10) OUTPUT, ' +      
                  '@cCube       NVARCHAR( 10) OUTPUT, ' +      
                  '@cRefNo      NVARCHAR( 20) OUTPUT, ' +      
                  '@cCartonType NVARCHAR( 10) OUTPUT  '      
         
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cDropID,      
                  @nErrNo      OUTPUT,       
                  @cErrMsg     OUTPUT,      
                  @cPackInfo   OUTPUT,      
                  @cWeight     OUTPUT,      
                  @cCube       OUTPUT,      
                  @cRefNo      OUTPUT,      
                  @cCartonType OUTPUT      
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
            SELECT      
               @cCartonType = CartonType,      
               @cWeight = rdt.rdtFormatFloat( Weight),      
               @cCube = rdt.rdtFormatFloat( [Cube]),      
               @cRefNo = RefNo      
            FROM dbo.PackInfo WITH (NOLOCK)      
            WHERE PickSlipNo = @cPickSlipNo      
               AND CartonNo  = @nCartonNo      
            
            -- Prepare LOC screen var      
            SET @cOutField01 = @cCartonType      
            SET @cOutField02 = @cWeight           --WinSern      
            SET @cOutField03 = @cCube             --WinSern      
            SET @cOutField04 = @cRefNo      
            
            -- Enable disable field      
            SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END      
            SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END      
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END      
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END      
            SET @cFieldAttr08 = '' -- QTY      
            
            -- Position cursor      
            IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE      
            IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE      
            IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE      
            IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4      
    
            SET @nCurScn  = @nScn    
            SET @nCurStep = @nStep    
    
            -- Go to next screen      
            SET @nScn =  @nScn + 3   
            SET @nStep = @nStep + 4   
                  
            GOTO Quit      
         END        
      END
            
      SET @cOutField04 = ''
      SET @cDropID = ''

      SELECT TOP 1
         @cExternOrderKey = ExternOrderKey,
         @cConsigneeKey = ConsigneeKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey

      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cExternOrderKey
      SET @cOutField03 = @cConsigneeKey
      SET @cOutField04 = ''
      SET @cOutField05 = @cLoadKey

      -- Goto prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField02 = ''   --ActSKU

      SET @cActSKU = ''
      SET @cActQty = ''
   END

END
GOTO Quit

/********************************************************************************
Step 4. Screen = 2473
   SKU        (field01)
   DESCR      (field01)
   ADCODE     (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cADCode = @cInField05

      IF ISNULL(@cADCode, '') = ''
      BEGIN
         SET @nErrNo = 72616
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ADCode req'
         GOTO Step_4_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SerialNo = @cADCode)
      BEGIN
         SET @nErrNo = 72617
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ADCode exists'
         GOTO Step_4_Fail
      END

      SET @nStartTranCnt = @@TRANCOUNT -- (james02)
      BEGIN TRAN

      -- Start insert ADCode
      EXECUTE dbo.nspg_GetKey
         'SerialNo',
         10 ,
         @cSerialNoKey      OUTPUT,
         @b_success         OUTPUT,
         @n_err             OUTPUT,
         @c_errmsg          OUTPUT

      IF @b_success <> 1
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72618
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Fail'
         GOTO Step_4_Fail
      END

      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      SELECT @nCartonNo = MIN(CartonNo) FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU

      INSERT INTO dbo.SERIALNO (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo)
      VALUES (@cSerialNoKey, @cOrderKey, @nCartonNo, @cStorerKey, @cSKU, @cADCode)

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72619
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Fail'
         GOTO Step_4_Fail
      END

      SELECT @nOtherUnit2 = OtherUnit2 FROM Pack P WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK) ON (P.PackKey = S.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SELECT @nSum_PickQty = ISNULL(SUM(PickQty), 0) FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU
         AND AddWho = @cUserName
         AND Status = '5'

      SELECT @nCount_SerialNo = Count(1) FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      -- No more scanning required
      IF (@nSum_PickQty / @nOtherUnit2) <= @nCount_SerialNo
      BEGIN
         SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey

         SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderKey
         AND   StorerKey = @cStorerKey

         -- Only when config 'AUTOPACKCONFIRM' is turned on and pick and pack match then scan out
         IF @nSumPackQTY = @nSumPickQTY
         BEGIN
            IF @cAutoPackConfirm = '1'
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                          AND Orderkey = @cPOrderKey
                          AND Status < '5')
               BEGIN
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                     STATUS = '9'
                     --ArchiveCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo
                     AND StorerKey = @cStorerKey

                  IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
                  BEGIN
                     UPDATE dbo.PickingInfo WITH (ROWLOCK)
                        SET SCANOUTDATE = GETDATE(),
                            EditWho = @cUserName
                     WHERE PickSlipNo = @cPickSlipNo
                  END

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 72620
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ConfPackFail'
                     ROLLBACK TRAN -- UPD_ADCODE
                     GOTO Step_4_Fail
                  END
               END
            END

            WHILE @@TRANCOUNT > @nStartTranCnt
               COMMIT TRAN --UPD_ADCODE

            EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,
               @nTotal_Qty        OUTPUT,
               @nTotal_Picked     OUTPUT,
               @nTotal_SKU        OUTPUT,
               @nTotal_SKU_Picked OUTPUT,
               @nSKU_QTY          OUTPUT,
               @nSKU_Picked       OUTPUT,
               @nDropID_QTY       OUTPUT

            -- Prep next screen var
            SET @cOutField01 = @cDropID
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = @cOrderKey
            SET @cOutField06 = @cExternOrderKey
            SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))
            SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))
            SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))
            SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))

            IF @nTotal_Picked = @nTotal_Qty
            BEGIN
               SET @nScn = 2744
               SET @nStep = 6

               SET @cOutField01 = @nTotal_Picked
               SET @cOutField02 = @nTotal_SKU_Picked

               GOTO Quit
            END
            ELSE
            BEGIN
               -- Go to next screen
               SET @nScn  = @nCurScn
               SET @nStep = @nCurStep
            END
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @nStartTranCnt
               COMMIT TRAN

            EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,
               @nTotal_Qty        OUTPUT,
               @nTotal_Picked     OUTPUT,
               @nTotal_SKU        OUTPUT,
               @nTotal_SKU_Picked OUTPUT,
               @nSKU_QTY          OUTPUT,
               @nSKU_Picked       OUTPUT,
               @nDropID_QTY       OUTPUT

            -- Prep next screen var
            SET @cOutField01 = @cDropID
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = @cOrderKey
            SET @cOutField06 = @cExternOrderKey
            SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))
            SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))
            SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))
            SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))

            IF @nTotal_Picked = @nTotal_Qty
            BEGIN
               SET @nScn = 2744
               SET @nStep = 6

               SET @cOutField01 = @nTotal_Picked
               SET @cOutField02 = @nTotal_SKU_Picked

               GOTO Quit
            END
            ELSE
            BEGIN
               -- Go to next screen
               SET @nScn  = @nCurScn
               SET @nStep = @nCurStep
            END
         END
      END
      
      WHILE @@TRANCOUNT > @nStartTranCnt
         COMMIT TRAN
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nCount_SerialNo < (@nSum_PickQty / @nOtherUnit2)
      BEGIN
         -- Save current screen no
         SET @nCurScn = @nScn
         SET @nCurStep = @nStep

         SET @cOutField01 = ''

         -- Go to reason code screen
         SET @nScn  = 2011
         SET @nStep = 5

         GOTO Quit
      END


   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. Screen = 2011
   Reason code (field01)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cReasonCode = @cInField01

      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 72621
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_5_Fail
      END

      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc
      SET @cNotes = 'Anti-Diversion code short scan'

      EXEC rdt.rdt_STD_Reason
         @nFunc,
         @nMobile,
         @cLangCode,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT, -- screen limitation, 20 NVARCHAR max
         @cStorerKey,
         @cFacility,
         @cPickSlipNo,
         @cLoadKey,
         @cWaveKey,
         @cOrderKey,
         '',
         @cID,
         @cSKU,
         @cPackUOM3,
         0,       -- In master unit
         '',
         '',
         '',
         NULL,
         NULL,
         @cReasonCode,
         @cUserName,
         @cModuleName,
         @cNotes

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_5_Fail
      END

      EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,
         @nTotal_Qty        OUTPUT,
         @nTotal_Picked     OUTPUT,
         @nTotal_SKU        OUTPUT,
         @nTotal_SKU_Picked OUTPUT,
         @nSKU_QTY          OUTPUT,
         @nSKU_Picked       OUTPUT,
         @nDropID_QTY       OUTPUT

      -- Prep next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @cOrderKey
      SET @cOutField06 = @cExternOrderKey
      SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))
      SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))

      -- Go to next screen
      SET @nScn  = @nCurScn
      SET @nStep = @nCurStep
   END

   Step_5_Fail:
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 2744
Picking completed
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey IN (1, 0) -- ENTER/ESC
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cADCode      NVARCHAR( 18), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cDropID,  ' +       
               ' @nErrNo      OUTPUT, ' +       
               ' @cErrMsg     OUTPUT, ' +      
               ' @cPackInfo   OUTPUT, ' +      
               ' @cWeight     OUTPUT, ' +      
               ' @cCube       OUTPUT, ' +      
               ' @cRefNo      OUTPUT, ' +      
               ' @cCartonType OUTPUT'      
            SET @cSQLParam =      
               '@nMobile     INT,           ' +      
               '@nFunc       INT,           ' +      
               '@cLangCode   NVARCHAR( 3),  ' +      
               '@nStep       INT,           ' +      
               '@nInputKey   INT,           ' +      
               '@cFacility   NVARCHAR( 5),  ' +      
               '@cStorerKey  NVARCHAR( 15), ' +      
               '@cPickSlipNo NVARCHAR( 10), ' +      
               '@cDropID NVARCHAR( 20), ' +       
               '@nErrNo      INT           OUTPUT, ' +      
               '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +      
               '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +      
               '@cWeight     NVARCHAR( 10) OUTPUT, ' +      
               '@cCube       NVARCHAR( 10) OUTPUT, ' +      
               '@cRefNo      NVARCHAR( 20) OUTPUT, ' +      
               '@cCartonType NVARCHAR( 10) OUTPUT  '      
         
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cDropID,      
               @nErrNo      OUTPUT,       
               @cErrMsg     OUTPUT,      
               @cPackInfo   OUTPUT,      
               @cWeight     OUTPUT,      
               @cCube       OUTPUT,      
               @cRefNo      OUTPUT,      
               @cCartonType OUTPUT      
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
         SELECT      
            @cCartonType = CartonType,      
            @cWeight = rdt.rdtFormatFloat( Weight),      
            @cCube = rdt.rdtFormatFloat( [Cube]),      
            @cRefNo = RefNo      
         FROM dbo.PackInfo WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
            AND CartonNo  = @nCartonNo      
            
         -- Prepare LOC screen var      
         SET @cOutField01 = @cCartonType      
         SET @cOutField02 = @cWeight           --WinSern      
         SET @cOutField03 = @cCube             --WinSern      
         SET @cOutField04 = @cRefNo      
            
         -- Enable disable field      
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END      
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END      
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END      
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END      
         SET @cFieldAttr08 = '' -- QTY      
            
         -- Position cursor      
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE      
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE      
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE      
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4      
    
         SET @nCurScn  = @nScn    
         SET @nCurStep = @nStep    
    
         -- Go to next screen      
         SET @nScn =  @nScn + 1    
         SET @nStep = @nStep + 1    
                  
         GOTO Quit      
      END
            
      SET @nScn = 2740
      SET @nStep = 1

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- (james08)
      IF rdt.RDTGetConfig( @nFunc, 'ShowPickCfmInNewScn', @cStorerKey) = 1
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = 'PICKING COMPLETED.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
         END
      END

      IF rdt.RDTGetConfig( @nFunc, 'PickSetFocusOnLoadkey', @cStorerKey) = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 1 --LoadKey
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 --OrderKey

   END
END
GOTO Quit

/********************************************************************************      
Scn = 4653.  Screen = 2745     
   Carton Type (field01, input)      
   Cube        (field02, input)      
   Weight      (field03, input)      
   RefNo       (field04, input)      
********************************************************************************/      
Step_7:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      DECLARE @cChkCartonType NVARCHAR( 10)      
      
      -- (james02)      
      -- Screen mapping      
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END      
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END      
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END      
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END      
      
      -- Carton type      
      IF @cFieldAttr01 = ''      
      BEGIN      
   -- Check blank      
         IF @cChkCartonType = ''      
         BEGIN      
            SET @nErrNo = 100210      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Quit      
         END      
               
         -- Get default cube      
         DECLARE @nDefaultCube FLOAT      
         SELECT @nDefaultCube = [Cube]      
         FROM Cartonization WITH (NOLOCK)      
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)      
         WHERE Storer.StorerKey = @cStorerKey      
            AND Cartonization.CartonType = @cChkCartonType      
      
         -- Check if valid      
         IF @@ROWCOUNT = 0      
         BEGIN      
            SET @nErrNo = 72636      
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
            SET @cOutField02 = @cWeight         --WinSern      
            SET @cOutField03 = @cCube           --WinSern      
         END     
      END      
      
      -- Weight      
      IF @cFieldAttr02 = ''      
      BEGIN      
         -- Check blank      
         IF @cWeight = ''      
         BEGIN      
            SET @nErrNo = 72637      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight      
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
            SET @nErrNo = 72638      
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
            AND PD.dropid = @cdropid      
      
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
            SET @nErrNo = 72639      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube   
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
            SET @nErrNo = 72640      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            SET @cOutField03 = ''      
            GOTO QUIT      
         END      
         SET @nErrNo = 0      
         SET @cOutField03 = @cCube      
      END      
      
      DECLARE @fCube FLOAT      
      DECLARE @fWeight FLOAT      
      SET @fCube = CAST( @cCube AS FLOAT)      
      SET @fWeight = CAST( @cWeight AS FLOAT)      
    
          
      SELECT @nCartonNo = MAX(CartonNo) FROM dbo.PackInfo PD WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      SET @nCartonNo = CASE WHEN ISNULL(@nCartonNo,'')='' THEN '0001' ELSE  @nCartonNo+1 END    
      
      -- PackInfo      
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND cartontype = @cCartonType and refno=@cdropid)      
      BEGIN      
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType, RefNo)      
         VALUES (@cPickSlipNo, @nCartonNo, 1, @fWeight, @fCube, @cCartonType, @cdropid)      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 72641      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail      
            GOTO Quit      
         END      
      END      
      ELSE      
      BEGIN      
         UPDATE dbo.PackInfo WITH (ROWLOCK)    
         SET      
            CartonType = @cCartonType,      
            Weight = @fWeight,      
            [Cube] = @fCube,      
            RefNo = @cRefNo      
         WHERE PickSlipNo = @cPickSlipNo      
             AND Refno = @cDropID    
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 72642      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail      
            GOTO Quit      
         END      
      END    

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cADCode      NVARCHAR( 18), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            -- (james14)
            IF @nErrNo <> 0    
            BEGIN
               ROLLBACK TRAN
               GOTO Quit
            END    
         END
      END

      IF @nCurStep=3  
      BEGIN  
  
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
  
         SET @cOutField04 = ''    
         SET @cDropID = ''    
    
         SELECT TOP 1    
            @cExternOrderKey = ExternOrderKey,    
            @cConsigneeKey = ConsigneeKey    
         FROM dbo.Orders WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
            AND OrderKey = @cOrderKey    
    
         SET @cOutField01 = @cOrderKey    
         SET @cOutField02 = @cExternOrderKey    
         SET @cOutField03 = @cConsigneeKey    
         SET @cOutField04 = ''    
         SET @cOutField05 = @cLoadKey    
    
         -- Goto prev screen    
         SET @nScn  = 2741   
         SET @nStep = 2  
      END      
          
      IF @nCurStep=6  
      BEGIN  
           
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
  
         SET @nScn = 2740    
         SET @nStep = 1    
    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
    
         -- (james08)    
         IF rdt.RDTGetConfig( @nFunc, 'ShowPickCfmInNewScn', @cStorerKey) = 1    
         BEGIN    
            SET @nErrNo = 0    
            SET @cErrMsg1 = 'PICKING COMPLETED.'    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
            END    
         END    
    
         IF rdt.RDTGetConfig( @nFunc, 'PickSetFocusOnLoadkey', @cStorerKey) = '1'    
            EXEC rdt.rdtSetFocusField @nMobile, 1 --LoadKey    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 2 --OrderKey    
      END    
  
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN     
      -- (james16)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cADCode      NVARCHAR( 18), ' +
               '@nErrNo       INT OUTPUT,    ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cOrderKey, @cLoadKey, @cDropID, @cSKU, @cADCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      IF @nCurStep=3  
      BEGIN  
         SET @cSKU = ''    
         EXECUTE rdt.rdtfnc_PickAndPack_GetStat @nMobile, @cOrderKey, @cPickSlipNo, @cStorerKey, @cSKU, @cDropID, @cLoadKey,    
         @nTotal_Qty        OUTPUT,    
         @nTotal_Picked     OUTPUT,    
         @nTotal_SKU        OUTPUT,    
         @nTotal_SKU_Picked OUTPUT,    
         @nSKU_QTY          OUTPUT,    
         @nSKU_Picked       OUTPUT,    
         @nDropID_QTY       OUTPUT    
    
         -- Prep next screen var    
         SET @cOutField01 = @cDropID    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = CASE WHEN ISNULL( @cLoadKey, '') = '' THEN @cOrderKey ELSE '' END    
         SET @cOutField06 = @cExternOrderKey    
         SET @cOutField07 = CAST( @nTotal_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_QTY AS NVARCHAR(5))    
         SET @cOutField08 = CAST( @nSKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nSKU_QTY AS NVARCHAR(5))    
         SET @cOutField09 = CAST( @nTotal_SKU_Picked AS NVARCHAR(5)) + '/' + CAST( @nTotal_SKU AS NVARCHAR(5))    
         SET @cOutField10 = CAST( @nDropID_QTY AS NVARCHAR(5))    
         SET @cOutField11 = @cLoadKey    
    
         -- Go to next screen    
         SET @nScn  = 2742    
         SET @nStep = 3    
    
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
         
      IF @nCurStep=6  
      BEGIN  
         SET @nScn = 2740    
         SET @nStep = 1    
  
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
    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
    
         -- (james08)    
         IF rdt.RDTGetConfig( @nFunc, 'ShowPickCfmInNewScn', @cStorerKey) = 1    
         BEGIN    
            SET @nErrNo = 0    
            SET @cErrMsg1 = 'PICKING COMPLETED.'    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
            END    
         END    
    
         IF rdt.RDTGetConfig( @nFunc, 'PickSetFocusOnLoadkey', @cStorerKey) = '1'    
            EXEC rdt.rdtSetFocusField @nMobile, 1 --LoadKey    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 2 --OrderKey    
      END    
   END      
      
   Step_7_Quit:      
    
END      
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),   
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      Printer      = @cPrinter,

      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,
      V_ConsigneeKey = @cConsigneeKey,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKU_Descr,

      V_String1    = @cWaveKey,
      V_String3    = @cGenPickSlipSP,
      V_String4    = @cExtendedValidateSP,
      V_String5    = @cExtendedUpdateSP,
      V_String6    = @cDecodeSP,  -- (james12)
      V_String7    = @cAutoPackConfirm,  -- (james15)
      V_String12   = @cExternOrderKey,
      V_String17   = @cDropID,
 		V_String18   = @cRefNo,    
      V_String19   = @cCapturePackInfoSP,     
      V_String20   = @cPackInfo,             
      V_String21   = @cAllowWeightZero,      
      V_String22   = @cAllowCubeZero,        
      V_String23   = @cDefaultWeight,        
      V_String24   = @cCartonType, 
      
      V_QTY        = @nActQty,
      
      V_Integer1   = @nOrdCount,
      V_Integer2   = @nQtyToPick,
      V_Integer3   = @nTotalPickQty,
      V_Integer4   = @nCurScn,
      V_Integer5   = @nCurStep,
		V_Integer6   = @cWeight,    
      V_Integer7   = @cCube,      

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