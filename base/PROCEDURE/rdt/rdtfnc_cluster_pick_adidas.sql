SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Cluster_Pick_Adidas                          */
/* Copyright      : IDS                                                 */
/* FBR: 116248                                                          */
/* Purpose: Modified from Cluster Pick.                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 07-Jul-2017  1.0  James      Created                                 */
/* 13-Aug-2019  1.1  James      Split step 8 (james01)                  */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Cluster_Pick_Adidas](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep  INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,
   @nCurScn        INT,  -- Current screen variable
   @nCurStep       INT,  -- Current step variable

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),

   @cWaveKey       NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cNewOrderKey   NVARCHAR( 10),
   @cLastOrderKey  NVARCHAR( 10),
   @cCurrentOrderKey NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @cPutAwayZone   NVARCHAR( 10),
   @cPutAwayZone01 NVARCHAR( 10),
   @cPutAwayZone02 NVARCHAR( 10),
   @cPutAwayZone03 NVARCHAR( 10),
   @cPutAwayZone04 NVARCHAR( 10),
   @cPutAwayZone05 NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cOption        NVARCHAR( 1),
   @cLOC           NVARCHAR( 10),
   @cNewLOC        NVARCHAR( 10),
   @cLot           NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cRetailSKU     NVARCHAR( 20),
   @cSKU_Descr     NVARCHAR( 60),
   @cStyle         NVARCHAR( 20),
   @cColorNSize    NVARCHAR( 20),
   @cColor         NVARCHAR( 10),
   @cSize          NVARCHAR( 5),
   @cColor_Descr   NVARCHAR( 20),
   @cBUSR6         NVARCHAR( 30),
   @cDropID        NVARCHAR( 20),
   @cScan_SKU      NVARCHAR( 20),
   @cActSKU        NVARCHAR( 20),
   @cConsigneeKey  NVARCHAR( 15),
   @cExternOrderKey NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cNewLottable02 NVARCHAR( 18),
   @dNewLottable04 DATETIME,

   @cPickQTY               NVARCHAR( 5),
   @cDefaultPickQty        NVARCHAR( 5),
   @cDefaultToAllocatedQty NVARCHAR( 5),
   @cActQty                NVARCHAR( 7),

   @nQtyToPick       INT,
   @nTotalPickQty    INT,
   @nActQty          INT,
   @nOrdCount        INT,
   @nOrderCnt        INT,
   @nDropIDCnt       INT,
   @nTTL_Alloc_Qty   INT,
   @nLoop            INT,
   @cUCCNo           NVARCHAR( 20),
   @cCongsineeKey    NVARCHAR( 15),
   @cCartonNo        NVARCHAR( 4),
   @cDataWindow      NVARCHAR( 50),
   @cTargetDB        NVARCHAR( 10),
   @nFocusField      INT,
   @nRDTMobile       INT,
   @nTTL_Qty         INT,
   @nTTL_Ord         INT,
   @nSKUCnt          INT,
   @nZoneCount       INT,
   @nOrderPicked     INT,
   @nTTL_PickedQty   INT,
   @nRowRef          INT,
   @b_success        INT,
   @n_err            INT,
   @c_errmsg         NVARCHAR( 255),
   @cPickSlipType    NVARCHAR( 10),
   @nShortPickedQty  INT,
   @cPackUOM3        NVARCHAR( 10),
   @cReportType      NVARCHAR( 10),
   @cPrintJobName    NVARCHAR( 50),
   @cOS_Qty          NVARCHAR( 20),
   @nTTL_Pick_ORD    INT,
   @nTTL_UnPick_ORD  INT,

   @cAllowableIdleTime        NVARCHAR( 3),
   @cClusterPickLockQtyToPick NVARCHAR( 1),
   @cClusterPickScanDropID    NVARCHAR( 1),
   @cAutoPromptDropID         NVARCHAR( 1),
   @cClusterPickPrintLabel    NVARCHAR( 1),
   @cNot_Check_ID_Prefix      NVARCHAR( 1),
   @cAutoPackConfirm          NVARCHAR( 1),
   @cSHOWSHTPICKRSN           NVARCHAR( 1),

   @cDisPlay        NVARCHAR( 20),   -- (james11)
   @cPackCfg        NVARCHAR( 20),   -- (james11)
   @cNewSKU         NVARCHAR( 20),   -- (james11)
   @fPack_Qty       FLOAT,
   @fPack_InnerPack FLOAT,
   @fPack_CaseCnt   FLOAT,

   --(james01)
   @cSQLStatement   NVARCHAR(2000),
   @cSQLParms       NVARCHAR(2000),
   @cCheckDropID_SP NVARCHAR(20),
   @nValid          INT,

   @cReasonCode     NVARCHAR( 10),
   @cModuleName     NVARCHAR( 45),
   @cID             NVARCHAR( 18),
   @cPUOM           NVARCHAR( 1),
   @nQTY            INT,
   @nUpdatePickQty  INT, -- SOS# 208635

   -- SOS170848
   @cLoadDefaultPickMethod NVARCHAR( 1),   -- (james07)
   @cConso_Orders   NVARCHAR( 10),         -- (james07)
   @cPriority       NVARCHAR( 10),         -- (james07)
   @nQty2Offset     INT,               -- (james07)
   @nPD_Qty         INT,               -- (james07)
   @nRPL_Qty        INT,               -- (james07)
   @nPickQty        INT,               -- (james07)

   -- SOS172041
   @cADCode         NVARCHAR( 18),         -- (james08)
   @cSerialNoKey    NVARCHAR( 10),         -- (james08)
   @cNotes          NVARCHAR( 45),         -- (james08)
   @nOtherUnit2     INT,               -- (james08)
   @nSum_PickQty    INT,               -- (james08)
   @nCount_SerialNo INT,               -- (james08)
   @nCartonNo       INT,               -- (james08)
   @nSumPackQTY     INT,               -- (james10)
   @nSumPickQTY     INT,               -- (james10)
   @cPOrderKey      NVARCHAR(10),      -- (james10)
   @nStartTranCnt   INT,               -- (james10)
   @nDeletedCnt     INT,               -- (james_tune)

   @cPSFlag         NVARCHAR( 1),  -- (Vicky07)
   @cPSOrderkey     NVARCHAR( 10), -- (Vicky07)
   @cPSLoadkey      NVARCHAR( 10), -- (Vicky07)
   @cPSWavekey      NVARCHAR( 10), -- (Vicky07)
   @nRDTPickLockQTY INT, -- (ChewKP01)
   @cLogicalLoc     NVARCHAR( 18),

   @cClusterPickGetNextTask_SP   NVARCHAR( 30),     -- (james15)
   @cTemp_String                 NVARCHAR( 20),     -- (james15)
   @cTemp_UOM                    NVARCHAR( 20),     -- (james15)
   @cTemp_PrePackIndicator       NVARCHAR( 30),     -- (james15)
   @nTemp_PackQtyIndicator       INT,           -- (james15)
   @nNew_TTLPickQty              INT,           -- (james15)

   @cErrMsg1        NVARCHAR( 20),         -- (james11)
   @cErrMsg2        NVARCHAR( 20),         -- (james11)
   @cErrMsg3        NVARCHAR( 20),         -- (james11)
   @cErrMsg4        NVARCHAR( 20),         -- (james11)
   @cErrMsg5        NVARCHAR( 20),         -- (james11)
   @cLastPAZone     NVARCHAR( 10),         -- SOS# 237003
   @nNo_Of_Ord      INT,               -- (james16)
   @nTranCount      INT,               -- (james16)
   @cTemp_OrderKey  NVARCHAR(10),          -- (james16)
   @cPickDetailKey  NVARCHAR(10),          -- (james17)
   @cPrevLOC        NVARCHAR(10),          -- (james19)

   @nCount           INT,              -- (james05)
   @cSKUFieldName    NVARCHAR( 30),    -- (james05)
   @cExecStatements  NVARCHAR( 4000),  -- (james05)
   @cExecArguments   NVARCHAR( 4000),  -- (james05)

   @nMultiStorer     INT,              -- (james25)
   @cORD_StorerKey   NVARCHAR( 15),    -- (james25)
   @cOrder_Status    NVARCHAR( 1),     -- (james25)
   @cPrint_OrderKey  NVARCHAR( 15),    -- (james25)
   @cTDropID         NVARCHAR( 20),    -- (james30)
   @cScanLOT02       NVARCHAR( 1),     -- (james32)
   @cPrefUOM         NVARCHAR( 1),     -- (james32)
   @cPrefQty         NVARCHAR( 5),     -- (james32)

   @nPrefQty         INT,              -- (james32)
   @nPrefUOM_Div     INT,              -- (james32)
   @nPrefQTY2Pick    INT,              -- (james32)
   @nMstQTY2Pick     INT,              -- (james32)
   @nPrefQTYPicked   INT,              -- (james32)
   @nMstQTYPicked    INT,              -- (james32)

   @cPreferQty2Display  NVARCHAR( 20), -- (james32), SOS334125
   @cDefaultPrefPickQty NVARCHAR( 5),  -- (james32)
   @cSP                 NVARCHAR( 20), -- (james35)  
   @cParam1             NVARCHAR( 20), -- (james35)  
   @cParam2             NVARCHAR( 20), -- (james35)  
   @cParam3             NVARCHAR( 20), -- (james35)  
   @cParam4             NVARCHAR( 20), -- (james35)  
   @cParam5             NVARCHAR( 20), -- (james35)  
   @cPickNotFinish      NVARCHAR( 20), -- (james36)
   @cExtendedUpdateSP   NVARCHAR( 20), -- (james39)  
   @cExtendedInfoSP     NVARCHAR( 20), -- (james40)  
   @cExtendedInfo       NVARCHAR( 20), -- (james40)  
   @cSQL                NVARCHAR( MAX),-- (james40)  
   @cSQLParam           NVARCHAR( MAX),-- (james40)  

   @cExtendedValidateSP NVARCHAR( 20), -- (james41)  
   @cPickConfirm_SP     NVARCHAR( 20), -- (james41)  
   @cStatus             NVARCHAR( 1),  -- (james41)  
   @cCartonType         NVARCHAR( 10), -- (james42)  
   @cCaptureCtnType     NVARCHAR( 1),  -- (james42)  
   @cPickHeaderKey      NVARCHAR( 10), -- (james43)  
   @cPromptCloseCase    NVARCHAR( 20), -- (james44)  
   @cDecodeSP           NVARCHAR( 20), -- (james47)  
   @cBarcode            NVARCHAR( 60), -- (james47)  
   @cUPC                NVARCHAR( 30), -- (james47)  
   @cFromID             NVARCHAR( 18), -- (james47)  
   @cReceiptKey         NVARCHAR( 10), -- (james47)  
   @cPOKey              NVARCHAR( 10), -- (james47)  
   @cToLOC              NVARCHAR( 10), -- (james47)  
   @cLottable06         NVARCHAR( 30), -- (james47)  
   @cLottable07         NVARCHAR( 30), -- (james47)  
   @cLottable08         NVARCHAR( 30), -- (james47)  
   @cLottable09         NVARCHAR( 30), -- (james47)  
   @cLottable10         NVARCHAR( 30), -- (james47)  
   @cLottable11         NVARCHAR( 30), -- (james47)  
   @cLottable12         NVARCHAR( 30), -- (james47)  
   @dLottable13         DATETIME,      -- (james47)  
   @dLottable14         DATETIME,      -- (james47)  
   @dLottable15         DATETIME,      -- (james47)  
   @cUserDefine01       NVARCHAR( 60),  
   @cUserDefine02       NVARCHAR( 60),  
   @cUserDefine03       NVARCHAR( 60),  
   @cUserDefine04       NVARCHAR( 60),  
   @cUserDefine05       NVARCHAR( 60),  
   @nOutScn             INT,           -- (james50)
   @nOutStep            INT,           -- (james50)
   @nFunctionKey        INT,           -- (james50)
   @cFunctionKey        NVARCHAR( 3),  -- (james50)
   @cExtendedFuncKeySP  NVARCHAR( 20), -- (james50)

   
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

DECLARE @curReleaseLock  CURSOR
DECLARE @curPickingInfo  CURSOR
DECLARE @curUpdRPL       CURSOR

DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20),
   @c_LabelNo            NVARCHAR( 32)

DECLARE @c_ExecStatements     nvarchar(4000)
      , @c_ExecArguments      nvarchar(4000)

DECLARE  @nInScn     INT,
         @nInStep    INT

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
   @cLOC             = V_LOC,
   @cLOT             = V_LOT,
   @cID              = V_ID,
   @cConsigneeKey    = V_ConsigneeKey,
   @cSKU             = V_SKU,
   @cSKU_Descr       = V_SKUDescr,
   @nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_Qty, 7), 0) = 1 THEN LEFT( V_Qty, 7) ELSE 0 END,
   @cLottable02      = V_Lottable02,
   @dLottable04      = V_Lottable04,

   @cWaveKey         = V_String1,
   @nOrdCount        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,
   @cPutAwayZone01   = V_String3,
   @cPutAwayZone02   = V_String4,
   @cPutAwayZone03   = V_String5,
   @cPutAwayZone04   = V_String6,
   @cPutAwayZone05   = V_String7,
   @cLastOrderKey    = V_String8,
   @nOrdCount        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cPutAwayZone     = V_String10,
   @cPickZone        = V_String11,
   @cExternOrderKey  = V_String12,
   @cStyle           = V_String13,
   @cColor           = V_String14,
   @cSize            = V_String15,
   @cColor_Descr     = V_String16,
   @cDropID          = V_String17,
   @nOrderCnt        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18, 7), 0) = 1 THEN LEFT( V_String18, 7) ELSE 0 END,
   @nTTL_Alloc_Qty   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 7), 0) = 1 THEN LEFT( V_String19, 7) ELSE 0 END,
   @cDefaultPickQty  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 7), 0) = 1 THEN LEFT( V_String20, 7) ELSE 0 END,
   @nQtyToPick       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 7), 0) = 1 THEN LEFT( V_String21, 7) ELSE 0 END,
   @nTotalPickQty    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 7), 0) = 1 THEN LEFT( V_String22, 7) ELSE 0 END,
   @nTTL_Qty         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 7), 0) = 1 THEN LEFT( V_String23, 7) ELSE 0 END,
   @cDefaultToAllocatedQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24, 7), 0) = 1 THEN LEFT( V_String24, 7) ELSE 0 END,
   @cCurrentOrderKey = V_String25,
   @nTTL_Ord         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String26, 5), 0) = 1 THEN LEFT( V_String26, 5) ELSE 0 END,
   @cClusterPickScanDropID    = V_String27,
   @cClusterPickLockQtyToPick = V_String28,
   @cAutoPromptDropID         = V_String29,
   @cDefaultToAllocatedQty    = V_String30,
   @cClusterPickPrintLabel    = V_String31,
   @cAllowableIdleTime        = V_String32,
   @cNot_Check_ID_Prefix    = V_String33,
   @nCurScn                   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String34, 5), 0) = 1 THEN LEFT( V_String34, 5) ELSE 0 END,
   @nCurStep                  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String35, 5), 0) = 1 THEN LEFT( V_String35, 5) ELSE 0 END,
   @cLoadDefaultPickMethod    = V_String36,  -- (james07)
   @nMultiStorer              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String37, 5), 0) = 1 THEN LEFT( V_String37, 5) ELSE 0 END,  -- (james25)/(james50)
   @cPrefUOM                  = V_String38,  -- (james32)
   @cCartonType               = V_String39,  -- (james42)
   @nFunctionKey              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String40, 5), 0) = 1 THEN LEFT( V_String40, 5) ELSE 0 END, -- (james50)

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

IF @nFunc IN (1826, 1827, 1828)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0                 GOTO Step_0 
   IF @nStep IN (1,  2,  3,  4)  GOTO Step1_4
   IF @nStep IN (5,  6,  7)      GOTO Step5_7
   IF @nStep = 8                 GOTO Step8
   IF @nStep IN (9,  10, 11, 12) GOTO Step9_12
   IF @nStep IN (13, 14, 15, 16) GOTO Step13_16
   IF @nStep IN (17, 18, 19, 20) GOTO Step17_20
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1620
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- (james25)
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   -- Clear the uncompleted task for the same login
   DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT ROWREF FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE [Status] IN ('1', 'X')
   AND   AddWho = @cUserName
   OPEN CUR_DEL
   FETCH NEXT FROM CUR_DEL INTO @nRowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM RDT.RDTPickLock WITH (ROWLOCK) WHERE RowRef = @nRowRef
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
   END
   CLOSE CUR_DEL
   DEALLOCATE CUR_DEL

   -- If config turned on, not allow to change Qty To Pick
   SET @cClusterPickLockQtyToPick  = rdt.RDTGetConfig( @nFunc, 'ClusterPickLockQtyToPick', @cStorerKey)

   -- If config turned on, DropID field is mandatory
   SET @cClusterPickScanDropID = rdt.RDTGetConfig( @nFunc, 'ClusterPickScanDropID', @cStorerKey)

   -- If config turned on, auto go back to DropID field
   SET @cAutoPromptDropID = rdt.RDTGetConfig( @nFunc, 'AutoPromptDropID', @cStorerKey)

   -- If config turned on, auto go back the qty to pick is defaulted to QtyAllocated field
   SET @cDefaultToAllocatedQty = rdt.RDTGetConfig( @nFunc, 'DefaultToAllocatedQty', @cStorerKey)

   -- If config turned on, auto go to Print label screen
   SET @cClusterPickPrintLabel = rdt.RDTGetConfig( @nFunc, 'ClusterPickPrintLabel', @cStorerKey)

   -- If config turned on, auto go to Print label screen
   SET @cAllowableIdleTime = rdt.RDTGetConfig( @nFunc, 'AllowableIdleTime', @cStorerKey)

   -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'
   SET @cNot_Check_ID_Prefix = rdt.RDTGetConfig( @nFunc, 'Not_Check_ID_Prefix', @cStorerKey)

   -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'
   SET @cLoadDefaultPickMethod = rdt.RDTGetConfig( @nFunc, 'LoadDefaultPickMethod', @cStorerKey)

   SET @cFunctionKey = rdt.RDTGetConfig( @nFunc, 'FunctionKey', @cStorerKey)
   IF @cFunctionKey NOT IN ('', '0')
      SELECT @nFunctionKey = RDT.rdtGetFuncKey(@cFunctionKey)
   ELSE
      SET @nFunctionKey = 99  -- Set to some other value than 1 = ENTER; 0 = ESC

   IF @nFunctionKey IN (11, 12, 13, 14) 
   BEGIN
      SET @cExtendedFuncKeySP = rdt.RDTGetConfig( @nFunc, 'ExtendedFuncKeySP', @cStorerkey)
      IF @cExtendedFuncKeySP NOT IN ('0', '') AND 
         EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @cExtendedFuncKeySP AND TYPE = 'P')
      BEGIN
         SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cExtendedFuncKeySP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @nFunctionKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, ' + 
            ' @cPutAwayZone, @cPickZone, @cDropID, @cCartonType, @cLOC, @cSKU, @nQty,' + 
            ' @nOutScn OUTPUT, @nOutStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParms =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@nFunctionKey    INT,           ' + 
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cWaveKey        NVARCHAR( 10), ' +
            '@cLoadKey        NVARCHAR( 10), ' +
            '@cOrderKey       NVARCHAR( 10), ' +
            '@cPutAwayZone    NVARCHAR( 10), ' +
            '@cPickZone       NVARCHAR( 10), ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@cCartonType     NVARCHAR( 10), ' +
            '@cLOC            NVARCHAR( 10), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQty            INT,           ' +
            '@nOutScn         INT           OUTPUT,  ' +
            '@nOutStep        INT           OUTPUT,  ' +
            '@nErrNo          INT           OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT   ' 

         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @nFunctionKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, 
               @cPutAwayZone,  @cPickZone, @cDropID, @cCartonType, @cLOC, @cSKU, @nQty, 
               @nOutScn OUTPUT, @nOutStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
                 
         IF @nErrNo <> 0
            GOTO Quit  
      END

      SET @nCurScn = 1870
      SET @nCurStep = 1

      IF @nOutScn > @nCurScn AND @nOutStep > @nCurStep
      BEGIN
         -- Goto function key screen
         SET @cOutField01 = @cFunctionKey
         SET @nScn = @nOutScn
         SET @nStep = @nOutStep
         GOTO Quit
      END
   END

   -- (Vicky06) EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- WaveKey

   -- Go to WaveKey screen
   SET @nScn = 1870
   SET @nStep = 1
END
GOTO Quit

Step1_4:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St1_4] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END

Step5_7:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St5_7] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END

Step8:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St8] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END

Step9_12:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St9_12] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END

Step13_16:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St13_16] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END

Step17_20:
BEGIN
   EXEC [RDT].[rdt_Cluster_Pick_St17_20] 
      @nMobile,
      @nFunc            OUTPUT, 
	   @cLangCode,
      @nInputKey        OUTPUT,
      @nMenu            OUTPUT,
      @nScn,
      @nStep,
      @nOutScn          OUTPUT,
      @nOutStep         OUTPUT,   
      @cStorerKey   ,
      @cFacility    ,
      @cUserName    ,
      @cPrinter         OUTPUT,
      @cPickSlipNo      OUTPUT,
      @cOrderKey        OUTPUT,
      @cLoadKey         OUTPUT,
      @cLOC             OUTPUT,
      @cLOT             OUTPUT,
      @cID              OUTPUT,
      @cConsigneeKey    OUTPUT,
      @cSKU             OUTPUT,
      @cSKU_Descr       OUTPUT,
      @nActQty          OUTPUT,
      @cLottable02      OUTPUT,
      @dLottable04      OUTPUT,
      @cWaveKey         OUTPUT,
      @cPutAwayZone01   OUTPUT,
      @cPutAwayZone02   OUTPUT,
      @cPutAwayZone03   OUTPUT,
      @cPutAwayZone04   OUTPUT,
      @cPutAwayZone05   OUTPUT,
      @cLastOrderKey    OUTPUT,
      @nOrdCount        OUTPUT,
      @cPutAwayZone     OUTPUT,
      @cPickZone        OUTPUT,
      @cExternOrderKey  OUTPUT,
      @cStyle           OUTPUT,
      @cColor           OUTPUT,
      @cSize            OUTPUT,
      @cColor_Descr     OUTPUT,
      @cDropID          OUTPUT,
      @nOrderCnt        OUTPUT,
      @nTTL_Alloc_Qty   OUTPUT,
      @cDefaultPickQty  OUTPUT,
      @nQtyToPick       OUTPUT,
      @nTotalPickQty    OUTPUT,
      @nTTL_Qty         OUTPUT,
      @cDefaultToAllocatedQty OUTPUT,
      @cCurrentOrderKey       OUTPUT,
      @nTTL_Ord               OUTPUT,
      @cClusterPickScanDropID OUTPUT,
      @cClusterPickLockQtyToPick OUTPUT,
      @cAutoPromptDropID         OUTPUT,
      @cClusterPickPrintLabel    OUTPUT,
      @cAllowableIdleTime        OUTPUT,
      @cNot_Check_ID_Prefix      OUTPUT,
      @nCurScn          OUTPUT,
      @nCurStep         OUTPUT,
      @cLoadDefaultPickMethod    OUTPUT,
      @nMultiStorer     OUTPUT,
      @cPrefUOM         OUTPUT,
      @cCartonType      OUTPUT,
      @nFunctionKey     OUTPUT,
      @cInField01,    
      @cInField02,    
      @cInField03,    
      @cInField04,    
      @cInField05,    
      @cInField06,    
      @cInField07,    
      @cInField08,    
      @cInField09,    
      @cInField10,    
      @cInField11,    
      @cInField12,    
      @cInField13,    
      @cInField14,    
      @cInField15,    
      @cOutField01   OUTPUT,
      @cOutField02   OUTPUT,
      @cOutField03   OUTPUT,
      @cOutField04   OUTPUT,
      @cOutField05   OUTPUT,
      @cOutField06   OUTPUT,
      @cOutField07   OUTPUT,
      @cOutField08   OUTPUT,
      @cOutField09   OUTPUT,
      @cOutField10   OUTPUT,
      @cOutField11   OUTPUT,
      @cOutField12   OUTPUT,
      @cOutField13   OUTPUT,
      @cOutField14   OUTPUT,
      @cOutField15   OUTPUT,
      @cFieldAttr01  OUTPUT,
      @cFieldAttr02  OUTPUT,
      @cFieldAttr03  OUTPUT,
      @cFieldAttr04  OUTPUT,
      @cFieldAttr05  OUTPUT,
      @cFieldAttr06  OUTPUT,
      @cFieldAttr07  OUTPUT,
      @cFieldAttr08  OUTPUT,
      @cFieldAttr09  OUTPUT,
      @cFieldAttr10  OUTPUT,
      @cFieldAttr11  OUTPUT,
      @cFieldAttr12  OUTPUT,
      @cFieldAttr13  OUTPUT,
      @cFieldAttr14  OUTPUT,
      @cFieldAttr15  OUTPUT,
      @nErrNo        OUTPUT,
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

      SET @nScn = @nOutScn
      SET @nStep = @nOutStep

      GOTO Quit
END


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
      -- UserName     = @cUserName,
      Printer      = @cPrinter,

      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,
      V_LOC        = @cLOC,
      V_LOT        = @cLOT,
      V_ID         = @cID,
      V_ConsigneeKey = @cConsigneeKey,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKU_Descr,
      V_QTY        = @nActQty,

      V_Lottable02 = @cLottable02,
      V_Lottable04 = @dLottable04,

      V_String1    = @cWaveKey,
      V_String2    = @nOrdCount,
      V_String3    = @cPutAwayZone01,
      V_String4    = @cPutAwayZone02,
      V_String5    = @cPutAwayZone03,
      V_String6    = @cPutAwayZone04,
      V_String7    = @cPutAwayZone05,
      V_String8    = @cLastOrderKey,
      V_String9    = @nOrdCount,
      V_String10   = @cPutAwayZone,
      V_String11   = @cPickZone,
      V_String12   = @cExternOrderKey,
      V_String13   = @cStyle,
      V_String14   = @cColor,
      V_String15   = @cSize,
      V_String16   = @cColor_Descr,
      V_String17   = @cDropID,
      V_String18   = @nOrderCnt,
      V_String19   = @nTTL_Alloc_Qty,
      V_String20   = @cDefaultPickQty,
      V_String21   = @nQtyToPick,
      V_String22   = @nTotalPickQty,
      V_String23   = @nTTL_Qty,
      V_String24   = @cDefaultToAllocatedQty,
      V_String25   = @cCurrentOrderKey,
      V_String26   = @nTTL_Ord,
      V_String27   = @cClusterPickScanDropID,
      V_String28   = @cClusterPickLockQtyToPick,
      V_String29   = @cAutoPromptDropID,
      V_String30   = @cDefaultToAllocatedQty,
      V_String31   = @cClusterPickPrintLabel,
      V_String32   = @cAllowableIdleTime,
      V_String33   = @cNot_Check_ID_Prefix,
      V_String34   = @nCurScn,
      V_String35   = @nCurStep,
      V_String36   = @cLoadDefaultPickMethod,  -- (james07)
      V_String37   = @nMultiStorer,            -- (james25)
      V_String38   = @cPrefUOM,                -- (james32)
      V_String39   = @cCartonType,             -- (james42)
      V_String40   = @nFunctionKey,            -- (james50)

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