SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_St17_20                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick step13 - step12                                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick_Adidas                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 07-Jul-2017 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_St17_20] (
   @nMobile                   INT,
   @nFunc                     INT            OUTPUT, 
	@cLangCode	               NVARCHAR( 3),
   @nInputKey                 INT            OUTPUT,
   @nMenu                     INT            OUTPUT,
   @nInScn                    INT,
   @nInStep                   INT,
   @nOutScn                   INT             OUTPUT,
   @nOutStep                  INT             OUTPUT,   
   @cStorerKey                NVARCHAR( 15)   ,
   @cFacility                 NVARCHAR( 5)   ,
   @cUserName                 NVARCHAR( 18)   ,
   @cPrinter                  NVARCHAR( 10)  OUTPUT,
   @cPickSlipNo               NVARCHAR( 10)  OUTPUT,
   @cOrderKey                 NVARCHAR( 10)  OUTPUT,
   @cLoadKey                  NVARCHAR( 10)  OUTPUT,
   @cLOC                      NVARCHAR( 10)  OUTPUT,
   @cLOT                      NVARCHAR( 10)  OUTPUT,
   @cID                       NVARCHAR( 18)  OUTPUT,
   @cConsigneeKey             NVARCHAR( 15)  OUTPUT,
   @cSKU                      NVARCHAR( 20)  OUTPUT,
   @cSKU_Descr                NVARCHAR( 60)  OUTPUT,
   @nActQty                   INT            OUTPUT,
   @cLottable02               NVARCHAR( 18)  OUTPUT,
   @dLottable04               DATETIME       OUTPUT,
   @cWaveKey                  NVARCHAR( 10)  OUTPUT,
   @cPutAwayZone01            NVARCHAR( 10)  OUTPUT,
   @cPutAwayZone02            NVARCHAR( 10)  OUTPUT,
   @cPutAwayZone03            NVARCHAR( 10)  OUTPUT,
   @cPutAwayZone04            NVARCHAR( 10)  OUTPUT,
   @cPutAwayZone05            NVARCHAR( 10)  OUTPUT,
   @cLastOrderKey             NVARCHAR( 10)  OUTPUT,
   @nOrdCount                 INT            OUTPUT,
   @cPutAwayZone              NVARCHAR( 10)  OUTPUT,
   @cPickZone                 NVARCHAR( 10)  OUTPUT,
   @cExternOrderKey           NVARCHAR( 20)  OUTPUT,
   @cStyle                    NVARCHAR( 20)  OUTPUT,
   @cColor                    NVARCHAR( 10)  OUTPUT,
   @cSize                     NVARCHAR( 5)   OUTPUT,
   @cColor_Descr              NVARCHAR( 20)  OUTPUT,
   @cDropID                   NVARCHAR( 20)  OUTPUT,
   @nOrderCnt                 INT            OUTPUT,
   @nTTL_Alloc_Qty            INT            OUTPUT,
   @cDefaultPickQty           NVARCHAR( 5)   OUTPUT,
   @nQtyToPick                INT            OUTPUT,
   @nTotalPickQty             INT            OUTPUT,
   @nTTL_Qty                  INT            OUTPUT,
   @cDefaultToAllocatedQty    NVARCHAR( 5)   OUTPUT,
   @cCurrentOrderKey          NVARCHAR( 10)  OUTPUT,
   @nTTL_Ord                  INT            OUTPUT,
   @cClusterPickScanDropID    NVARCHAR( 1)   OUTPUT,
   @cClusterPickLockQtyToPick NVARCHAR( 1)   OUTPUT,
   @cAutoPromptDropID         NVARCHAR( 1)   OUTPUT,
   @cClusterPickPrintLabel    NVARCHAR( 1)   OUTPUT,
   @cAllowableIdleTime        NVARCHAR( 1)   OUTPUT,
   @cNot_Check_ID_Prefix      NVARCHAR( 1)   OUTPUT,
   @nCurScn                   INT            OUTPUT,
   @nCurStep                  INT            OUTPUT,
   @cLoadDefaultPickMethod    NVARCHAR( 1)   OUTPUT,
   @nMultiStorer              INT            OUTPUT,
   @cPrefUOM                  NVARCHAR( 1)   OUTPUT,
   @cCartonType               NVARCHAR( 10)  OUTPUT,
   @nFunctionKey              INT            OUTPUT,
   @cInField01                NVARCHAR( 60),
   @cInField02                NVARCHAR( 60),
   @cInField03                NVARCHAR( 60),
   @cInField04                NVARCHAR( 60),
   @cInField05                NVARCHAR( 60),
   @cInField06                NVARCHAR( 60),
   @cInField07                NVARCHAR( 60),
   @cInField08                NVARCHAR( 60),
   @cInField09                NVARCHAR( 60),
   @cInField10                NVARCHAR( 60),
   @cInField11                NVARCHAR( 60),
   @cInField12                NVARCHAR( 60),
   @cInField13                NVARCHAR( 60),
   @cInField14                NVARCHAR( 60),
   @cInField15                NVARCHAR( 60),
   @cOutField01               NVARCHAR( 60)  OUTPUT,
   @cOutField02               NVARCHAR( 60)  OUTPUT,
   @cOutField03               NVARCHAR( 60)  OUTPUT,
   @cOutField04               NVARCHAR( 60)  OUTPUT,
   @cOutField05               NVARCHAR( 60)  OUTPUT,
   @cOutField06               NVARCHAR( 60)  OUTPUT,
   @cOutField07               NVARCHAR( 60)  OUTPUT,
   @cOutField08               NVARCHAR( 60)  OUTPUT,
   @cOutField09               NVARCHAR( 60)  OUTPUT,
   @cOutField10               NVARCHAR( 60)  OUTPUT,
   @cOutField11               NVARCHAR( 60)  OUTPUT,
   @cOutField12               NVARCHAR( 60)  OUTPUT,
   @cOutField13               NVARCHAR( 60)  OUTPUT,
   @cOutField14               NVARCHAR( 60)  OUTPUT,
   @cOutField15               NVARCHAR( 60)  OUTPUT,
   @cFieldAttr01              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr02              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr03              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr04              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr05              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr06              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr07              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr08              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr09              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr10              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr11              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr12              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr13              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr14              NVARCHAR( 1)   OUTPUT,
   @cFieldAttr15              NVARCHAR( 1)   OUTPUT,
   @nErrNo                    INT            OUTPUT,
   @cErrMsg                   NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variables
DECLARE
   @cOption        NVARCHAR( 1),
   @cNewLOC        NVARCHAR( 10),
   @cRetailSKU     NVARCHAR( 20),
   @cColorNSize    NVARCHAR( 20),
   @cBUSR6         NVARCHAR( 30),
   @cScan_SKU      NVARCHAR( 20),
   @cActSKU        NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable05    DATETIME,
   @cNewLottable02 NVARCHAR( 18),
   @dNewLottable04 DATETIME,

   @cPickQTY               NVARCHAR( 5),
   @cActQty                NVARCHAR( 7),

   @nDropIDCnt       INT,
   @nLoop            INT,
   @cUCCNo           NVARCHAR( 20),
   @cCongsineeKey    NVARCHAR( 15),
   @cCartonNo        NVARCHAR( 4),
   @cDataWindow      NVARCHAR( 50),
   @cTargetDB        NVARCHAR( 10),
   @nFocusField      INT,
   @nRDTMobile       INT,
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
   @cPUOM           NVARCHAR( 1),
   @nQTY            INT,
   @nUpdatePickQty  INT, -- SOS# 208635

   -- SOS170848
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

   @cORD_StorerKey   NVARCHAR( 15),    -- (james25)
   @cOrder_Status    NVARCHAR( 1),     -- (james25)
   @cPrint_OrderKey  NVARCHAR( 15),    -- (james25)
   @cTDropID         NVARCHAR( 20),    -- (james30)
   @cScanLOT02       NVARCHAR( 1),     -- (james32)
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
   @cFunctionKey        NVARCHAR( 3),  -- (james50)
   @cExtendedFuncKeySP  NVARCHAR( 20)  -- (james50)

   

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

DECLARE @nStep INT,
        @nScn  INT

   SET @nScn = @nInScn
   SET @nStep = @nInStep
   SET @nOutScn = @nInScn
   SET @nOutStep = @nInStep

IF @nFunc IN (1826, 1827, 1828)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 17  GOTO Step_17 -- Scn = 1891. Anti-Diversion code
   IF @nStep = 18  GOTO Step_18 -- Scn = Anti-Diversion code (Short Pick)
   IF @nStep = 19  GOTO Step_19 -- Scn = 1892. Get Carton Size
   IF @nStep = 20  GOTO Step_20 -- Scn = 4790. Picking on hold
END

/********************************************************************************
Step 17. Screen = 1891
   SKU        (field01)
   DESCR      (field01)
   ADCODE     (field01, input)
********************************************************************************/
Step_17:
BEGIN
   IF @nInputKey = 1 -- ENTER
  BEGIN
      SET @cADCode = @cInField05

      IF ISNULL(@cADCode, '') = ''
      BEGIN
         SET @nErrNo = 69342
         SET @cErrMsg = rdt.rdtgetmessage( 69342, @cLangCode, 'DSP') --'ADCode req'
         GOTO Step_17_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SerialNo = @cADCode)
      BEGIN
         SET @nErrNo = 69343
         SET @cErrMsg = rdt.rdtgetmessage( 69343, @cLangCode, 'DSP') --'ADCode exists'
         GOTO Step_17_Fail
      END

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
         SET @nErrNo = 69344
         SET @cErrMsg = rdt.rdtgetmessage( 69344, @cLangCode, 'DSP') --'Upd Fail'
         GOTO Step_17_Fail
      END

      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      SELECT @nCartonNo = MIN(CartonNo) FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU

      BEGIN TRAN   --(ang01)

      INSERT INTO dbo.SERIALNO (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo)
      VALUES (@cSerialNoKey, @cOrderKey, @nCartonNo, @cStorerKey, @cSKU, @cADCode)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 69345
         SET @cErrMsg = rdt.rdtgetmessage( 69345, @cLangCode, 'DSP') --'Upd Fail'
         ROLLBACK TRAN --(ang01)
         GOTO Step_17_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN --(ang01)
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
         -- Get next available task
         SET @nErrNo = 0
         SET @cCurrentOrderKey = @cOrderKey -- to Store the current Orderkey
         SET @cOrderKey = ''

         -- Remember current LOC (james19)
         SET @cPrevLOC = ''
         SET @cPrevLOC = @cLOC

         SET @cClusterPickGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickGetNextTask_SP', @cStorerKey)
         IF ISNULL(@cClusterPickGetNextTask_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_ClusterPickGetNextTask_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_SPName        = @cClusterPickGetNextTask_SP
               ,@c_Storerkey     = @cStorerKey
               ,@c_UserName      = @cUserName
               ,@c_Facility      = @cFacility
               ,@c_PutawayZone   = @cPutawayZone
               ,@c_PickZone      = @cPickZone
               ,@c_LangCode      = @cLangCode
               ,@c_oFieled01     = @c_oFieled01 OUTPUT
               ,@c_oFieled02     = @c_oFieled02 OUTPUT
               ,@c_oFieled03     = @c_oFieled03 OUTPUT
               ,@c_oFieled04     = @c_oFieled04 OUTPUT
               ,@c_oFieled05     = @c_oFieled05 OUTPUT
               ,@c_oFieled06     = @c_oFieled06 OUTPUT
               ,@c_oFieled07     = @c_oFieled07 OUTPUT
               ,@c_oFieled08     = @c_oFieled08 OUTPUT
               ,@c_oFieled09     = @c_oFieled09 OUTPUT
               ,@c_oFieled10     = @c_oFieled10 OUTPUT
               ,@c_oFieled11     = @c_oFieled11 OUTPUT
               ,@c_oFieled12     = @c_oFieled12 OUTPUT
               ,@c_oFieled13     = @c_oFieled13 OUTPUT
               ,@c_oFieled14     = @c_oFieled14 OUTPUT
               ,@c_oFieled15     = @c_oFieled15 OUTPUT
               ,@b_Success       = @b_Success   OUTPUT
               ,@n_ErrNo         = @nErrNo      OUTPUT
               ,@c_ErrMsg        = @cErrMsg     OUTPUT

            SET @cLOC            = @c_oFieled01
            SET @cOrderKey       = @c_oFieled02
            SET @cSKU            = @c_oFieled03
            SET @cSKU_Descr      = @c_oFieled04
            SET @cStyle          = @c_oFieled05
            SET @cColor          = @c_oFieled06
            SET @cSize           = @c_oFieled07
            SET @cColor_Descr    = @c_oFieled08
            SET @cLot            = @c_oFieled09
            SET @cPickSlipNo     = @c_oFieled10
            SET @cExternOrderKey = @c_oFieled11
            SET @cConsigneeKey   = @c_oFieled12
         END
         ELSE
         BEGIN
            EXECUTE rdt.rdt_Cluster_Pick_GetNextTask
               @cStorerKey,
               @cUserName,
               @cFacility,
               @cPutAwayZone,
               @cPickZone,
               @cLangCode,
               @nErrNo           OUTPUT,
               @cErrMsg          OUTPUT,  -- screen limitation, 20 NVARCHAR max
               @cLOC             OUTPUT,
               @cOrderKey        OUTPUT,
               @cExternOrderKey  OUTPUT,
               @cConsigneeKey    OUTPUT,
               @cSKU             OUTPUT,
               @cSKU_Descr       OUTPUT,
               @cStyle           OUTPUT,
               @cColor           OUTPUT,
               @cSize            OUTPUT,
               @cColor_Descr     OUTPUT,
               @cLot             OUTPUT,
               @cPickSlipNo      OUTPUT,
               @nMobile,
              @nFunc

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 65941
               SET @cErrMsg = rdt.rdtgetmessage( 65941, @cLangCode, 'DSP') --'GetNextTaskFail'
--               ROLLBACK TRAN
               GOTO Step_17_Fail
            END
         END

         -- Get the Lottables
         SELECT
            @cLottable02 = Lottable02,
            @dLottable04 = Lottable04
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND SKU = @cSKU
            AND LOT = @cLot

         -- If no more task, goto confirm picking screen
         IF ISNULL(@cOrderKey, '') = ''
         BEGIN
            SET @cPromptCloseCase = ''
            SET @cPromptCloseCase = rdt.RDTGetConfig( @nFunc, 'PromptCloseCase', @cStorerKey)

            IF LEN( RTRIM( @cPromptCloseCase)) > 1
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPromptCloseCase AND type = 'P')
               BEGIN
                  SET @nErrNo = 0
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cPromptCloseCase) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, ' +
                     ' @cLoc, @cDropID, @cSKU, @nQty, @cPromptCloseCase OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile          INT,                   ' +
                     '@nFunc            INT,                   ' +
                     '@cLangCode        NVARCHAR( 3),          ' +
                     '@nStep            INT,                   ' +
                     '@nInputKey        INT,                   ' +
                     '@cStorerkey       NVARCHAR( 15),         ' +
                     '@cWaveKey         NVARCHAR( 10),         ' +
                     '@cLoadKey         NVARCHAR( 10),         ' +
                     '@cOrderKey        NVARCHAR( 10),         ' +
                     '@cLoc             NVARCHAR( 10),         ' +
                     '@cDropID          NVARCHAR( 20),         ' +
                     '@cSKU             NVARCHAR( 20),         ' +
                     '@nQty             INT,                   ' +
                     '@cPromptCloseCase NVARCHAR( 1)  OUTPUT,  ' +
                     '@nErrNo           INT           OUTPUT,  ' +
                     '@cErrMsg          NVARCHAR( 20) OUTPUT   ' 

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey,  
                     @cLoc, @cDropID, @cSKU, @nQty, @cPromptCloseCase OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
               END      
            END     

            --If no more task then prompt Close Case screen (If turned on) (james03)
            IF @cPromptCloseCase = '1'
            BEGIN
               SET @cOutField01 = ''

               -- Go to Close Case screen
               SET @nOutScn  = 1886
               SET @nOutStep = 15

               GOTO Quit
            END

            SET @cOrderKey = @cCurrentOrderKey -- Assign back the OrderKey
            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

            SELECT
               @nOrderPicked = COUNT( DISTINCT OrderKey),
               @nTTL_PickedQty = SUM(PickQty)
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE AddWho = @cUserName
               AND Status = '5'  -- Picked
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))

            -- (james36)
            SET @cPickNotFinish = ''
            IF rdt.RDTGetConfig( @nFunc, 'DISPLAYPICKNOTFINISH', @cStorerKey) = 1
            BEGIN
               IF EXISTS ( SELECT 1 from dbo.PickDetail PD WITH (NOLOCK)
                           JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                           JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                           WHERE (( @nMultiStorer = 1 AND PD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND PD.StorerKey = @cStorerKey))
                           AND   ( PD.Status = '0' OR PD.Status = '4')
                           AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                           AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                           AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
                           AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                           AND   LOC.Facility = @cFacility
                           AND   PD.OrderKey IN (SELECT DISTINCT RPL.OrderKey FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK)
                                                 WHERE PD.OrderKey = RPL.OrderKey
                                                 AND   PD.StorerKey = RPL.StorerKey
                                                 AND   RPL.AddWho = @cUserName
                                                 AND   RPL.Status < '9'))
               BEGIN
                  SET @cPickNotFinish = 'PICKING NOT FINISH'
               END
            END

            -- Prep next screen var
            SET @cOutField01 = @cWaveKey
            SET @cOutField02 = @cLoadKey
            SET @cOutField03 = @cPutawayZone
            SET @cOutField04 = @cPickZone
            SET @cOutField05 = @nOrderPicked
            SET @cOutField06 = @nTTL_PickedQty
            SET @cOutField07 = CASE WHEN ISNULL( @cPickNotFinish, '') <> '' THEN @cPickNotFinish ELSE '' END

            SET @nOutScn  = 1879
            SET @nOutStep = 10

            SET @nActQty = 0
            SET @nQtyToPick = 0

            SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND AddWho = @cUserName
               AND Status = '5'
            OPEN @curUpdRPL
            FETCH NEXT FROM @curUpdRPL INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               BEGIN TRAN --(ang01)
               UPDATE RDT.RDTPickLock with (ROWLOCK) SET
                  Status = '9'   -- Confirm Picked
               WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 65942
                  SET @cErrMsg = rdt.rdtgetmessage( 65942, @cLangCode, 'DSP') --'UPDPKLockFail'
                  ROLLBACK TRAN   --(ang01)
                  GOTO Step_17_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN --(ang01)
               END

               FETCH NEXT FROM @curUpdRPL INTO @nRowRef
            END
            CLOSE @curUpdRPL
            DEALLOCATE @curUpdRPL

            GOTO Quit
         END

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                        AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                        AND OrderKey = @cOrderKey
                        AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                        AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                        AND Status = '1'
                        AND SKU IS NULL
                        AND AddWho = @cUserName)
         BEGIN              -- Insert next task to picklock
            BEGIN TRAN --(ang01)
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey,
            SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
            VALUES
            (@cWaveKey, @cLoadKey, @cOrderKey, '', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
            @cSKU, @cPutAwayZone, @cPickZone, '', @cLOT, @cLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65943
               SET @cErrMsg = rdt.rdtgetmessage( 65943, @cLangCode, 'DSP') --'LockOrdersFail'
               ROLLBACK TRAN
               GOTO Step_17_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN --(ang01)
            END
         END
         ELSE
         BEGIN
            -- Get the lottables
            SELECT
               @cLottable02 = Lottable02,
               @dLottable04 = Lottable04
            FROM dbo.LotAttribute WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
            AND SKU = @cSKU
               AND LOT = @cLot

            BEGIN TRAN --(ang01)
            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
               LOT = @cLot,
               LOC = @cLoc,
               SKU = @cSKU,
               DropID = @cDropID,
               PackKey = @cCartonType,                               
               Lottable02 = @cLottable02,
               Lottable04 = @dLottable04
            WHERE OrderKey = @cOrderKey
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND Status = '1'
               AND AddWho = @cUserName

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65929
               SET @cErrMsg = rdt.rdtgetmessage( 65929, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN  --(ang01)
               GOTO Step_17_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN --(ang01)
            END
         END

         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'
         BEGIN
            -- If change of LOC then need to go back to confirm LOC screen
            IF @cPrevLOC <> @cLOC
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cLOC
               SET @cOutField02 = ''

               -- Go to next screen
               SET @nOutScn  = 1892
               SET @nOutStep = 19

               GOTO Quit
            END
         END

         -- If OrderKey changed
         IF @cOrderKey <> @cOutField09
         BEGIN
            -- If configkey 'AutoPromptDropID' turned on, auto go back to DropID screen
            IF @cAutoPromptDropID = '1'
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'   -- (james18)
               BEGIN
                  -- If change of LOC then need to go back to confirm LOC screen
                  IF @cPrevLOC <> @cLOC
                  BEGIN
                     SET @nActQty = 0
                     SET @nQtyToPick = 0

                     -- Prep next screen var
                     SET @cOutField01 = @cLOC
                     SET @cOutField02 = ''

                     -- Go to next screen
                     SET @nOutScn  = 1892
                     SET @nOutStep = 19

                     -- Commit transaction before goto DropID screen
                     COMMIT TRAN

                     GOTO Quit
                  END
               END

               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               IF @nFunc = 1826
               BEGIN
                  -- Prep next screen var
                  SET @cOutField01 = @cLOC
                  SET @cOutField02 = @cOrderKey
                  SET @cOutField03 = @cExternOrderKey
                  SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
                  SET @cOutField05 = @cSKU
                  SET @cOutField06 = @cStyle
                  SET @cOutField07 = @cColor + @cSize

                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
                  BEGIN
                     SET @cTemp_String = ''
                     SET @cTemp_UOM = ''
                     SET @nTemp_PackQtyIndicator = ''

                     SELECT
                        @cTemp_UOM = SUBSTRING(PACK.PackUOM3, 1, 2),
                        @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
                     FROM dbo.SKU SKU WITH (NOLOCK)
                     JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
                     WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
                        AND SKU.SKU = @cSKU

                     SET @cOutField08 = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                                        '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
                  END
                  ELSE
                  BEGIN
                     SET @cOutField08 = @cColor_Descr
                  END

                  SET @cOutField09 = ''   -- DropID
                  SET @cOutField10 = ''   
                  SET @cOutField11 = ''   

                  SET @nOutScn  = 1876
                  SET @nOutStep = 7
               END
               ELSE
               IF @nFunc = 1827
               BEGIN
                  -- Prep next screen var
                  SET @cOutField01 = @cLOC
                  SET @cOutField02 = @cOrderKey
                  SET @cOutField03 = @cExternOrderKey
                  SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
                  SET @cOutField05 = @cSKU
                  SET @cOutField06 = SUBSTRING(@cSKU_Descr, 1, 20)
                  SET @cOutField07 = SUBSTRING(@cSKU_Descr, 21, 20)
                  SET @cOutField08 = @cLottable02
                  SET @cOutField09 = rdt.rdtFormatDate(@dLottable04)
                  SET @cOutField10 = ''   -- DropID

                  -- Go to next screen
                  SET @nOutScn  = 1882
                  SET @nOutStep = 7
               END
               ELSE
               IF @nFunc = 1828
               BEGIN
                  -- Prep next screen var
                  SET @cOutField01 = @cLOC
                  SET @cOutField02 = @cLoadKey
                  SET @cOutField05 = @cSKU
                  SET @cOutField06 = SUBSTRING(@cSKU_Descr, 1, 20)
                  SET @cOutField07 = SUBSTRING(@cSKU_Descr, 21, 20)
                  SET @cOutField08 = @cLottable02
                  SET @cOutField09 = rdt.rdtFormatDate(@dLottable04)
                  SET @cOutField10 = ''   -- DropID

                  -- Go to next screen
                  SET @nOutScn  = 1887
                  SET @nOutStep = 7
               END

               -- (james30)
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
               BEGIN
                  EXECUTE rdt.rdt_Cluster_Pick_DropID
                     @nMobile,
                     @nFunc,
                     @cStorerKey,
                     @cUserName,
                     @cFacility,
                     @cLoadKey,
                     @cPickSlipNo,
                     @cOrderKey,
                     @cDropID       OUTPUT,
                     @cSKU,
                     'R',      -- R = Retrieve
                     @cLangCode,
                     @nErrNo        OUTPUT,
                     @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

                  IF @nFunc = 1826
                  BEGIN
                     IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                        SET @cOutField09 = ''         -- DropID
                     ELSE
                        SET @cOutField09 = @cDropID   -- DropID
                  END
                  ELSE
                  BEGIN
                     IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                        SET @cOutField10 = ''         -- DropID
                     ELSE
                        SET @cOutField10 = @cDropID   -- DropID
                  END
               END

               SET @nActQty = 0
               SET @nQtyToPick = 0

               -- Commit transaction before goto DropID screen
               --COMMIT TRAN

               GOTO Quit
            END
         END   -- If OrderKey changed

         -- Get the total allocated qty for LOC + SKU + OrderKey
         SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.LOC = @cLOC
            AND PD.SKU = @cSKU
            AND PD.OrderKey = @cOrderKey
            AND PD.Status = '0'
            AND PD.LOT = @cLOT
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility

         SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
         IF CAST(@cDefaultPickQty AS INT) <= 0 SET @cDefaultPickQty = ''

         IF @cDefaultToAllocatedQty = '1'
         BEGIN
            SET @cDefaultPickQty = @nTotalPickQty
         END

         SET @nQtyToPick = 0
         SET @nActQty = 0

         -- Get the total oustanding qty for orderkey + putawayzone + pickzone
         SELECT @nTTL_Qty = SUM(QTY)
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE RPL.StorerKey = @cStorerKey
            AND RPL.Status < '5'
            AND RPL.AddWho = @cUserName
            AND RPL.PickQty <= 0
            AND PD.Status = '0'
            AND LA.StorerKey = @cStorerKey    -- tlting03
            AND LA.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
            AND EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = RPL.AddWho
                        AND StorerKey = RPL.StorerKey AND OrderKey =  PD.OrderKey )       --tlting02
            --AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) --SOS# 176144

         -- Get Total Orders left on the current sku that need to pick
         SELECT @nTTL_Ord = COUNT( DISTINCT PD.ORDERKEY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE RPL.StorerKey = @cStorerKey
            AND RPL.Status < '5'
            AND RPL.AddWho = @cUserName
            AND RPL.PickQty <= 0
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND PD.Status = '0'
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

         -- (james14)
         IF rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
         BEGIN
            SET @cOS_Qty = ''

            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               -- Get the total qty picked per orders
               SELECT @nTTL_Pick_ORD = ISNULL( SUM(PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                  AND LPD.LoadKey = @cLoadKey

               -- Get the total qty unpick per orders
               SELECT @nTTL_UnPick_ORD = ISNULL( SUM(PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.Status >= '3'
                  AND LPD.LoadKey = @cLoadKey

               SET @cOS_Qty = 'LOAD QTY: ' + LTRIM(RTRIM(CAST((@nTTL_UnPick_ORD + @nQtyToPick) AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
            END
            ELSE
            BEGIN
               -- Get the total qty picked per orders
               SELECT @nTTL_Pick_ORD = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey

               -- Get the total qty unpick per orders
               SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND Status >= '3'

               SET @cOS_Qty = 'OS QTY: ' + LTRIM(RTRIM(CAST((@nTTL_UnPick_ORD + @nQtyToPick) AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
            END
         END

         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
         BEGIN
            SET @cTemp_String = ''
            SET @cTemp_UOM = ''
            SET @nTemp_PackQtyIndicator = ''

            SELECT
               @cTemp_UOM = SUBSTRING( PACK.PackUOM3, 1, 2),
               @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            SET @cTemp_String = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                               '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
         END

         -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'    (james11)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickShowPackCfg', @cStorerKey) = '1'
         BEGIN
            SET @cPackCfg = ''

            SELECT @fPack_Qty = PACK.QTY,
                   @fPack_InnerPack = PACK.InnerPack,
                   @fPack_CaseCnt = PACK.CaseCnt
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            SET @cPackCfg = SUBSTRING( CAST(@fPack_Qty AS NVARCHAR(1)) + ':' +
                            RTRIM( CAST( @fPack_InnerPack AS NVARCHAR( 3))) + ':' +
                            RTRIM( CAST( @fPack_CaseCnt AS NVARCHAR( 4))), 1, 9)
         END

         SET @cScanLOT02 = rdt.RDTGetConfig( @nFunc, 'SCANLOT02', @cStorerKey)
         IF ISNULL( @cScanLOT02, '') = '' OR @cScanLOT02 <> '1'
            SET @cScanLOT02 = '0'

         IF @cPrefUOM <> '6'
         BEGIN
            SELECT TOP 1
               @nPrefUOM_Div = CAST( IsNULL(
                  CASE @cPrefUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU (NOLOCK)
               INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU

            -- Convert to prefer UOM QTY to be picked
            SET @nPrefQTY2Pick = @nQtyToPick / @nPrefUOM_Div -- Calc QTY in Pref UOM
            SET @nMstQTY2Pick = @nQtyToPick % @nPrefUOM_Div  -- Calc remaining QTY in master unit

            -- Convert to prefer UOM QTY picked
            SET @nPrefQTYPicked = @nTotalPickQty / @nPrefUOM_Div -- Calc QTY in Pref UOM
            SET @nMstQTYPicked = @nTotalPickQty % @nPrefUOM_Div  -- Calc remaining QTY in master unit

				--SOS334125 Start
            SET @cPreferQty2Display = RTRIM( CAST( @nPrefQTY2Pick AS NVARCHAR( 4))) + '-' +
                                      RTRIM( CAST( @nMstQTY2Pick AS NVARCHAR( 4))) +
                                      '/' +
                                      RTRIM( CAST( @nPrefQTYPicked AS NVARCHAR( 4))) + '-' +
                                      RTRIM( CAST( @nMstQTYPicked AS NVARCHAR( 4)))
				--SOS334125 End

            SET @cDefaultPrefPickQty = CAST( @cDefaultPickQty AS INT) / @nPrefUOM_Div
            SET @cDefaultPickQty = CAST( @cDefaultPickQty AS INT) % @nPrefUOM_Div
         END

         -- Get stored proc name for extended info (james40)
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT '
               
               SET @cSQLParam =
                  '@nMobile       INT, ' +
                  '@nFunc         INT, ' +
                  '@cLangCode     NVARCHAR( 3), ' +
                  '@nStep         INT, ' +
                  '@nInputKey     INT, ' +
                  '@cWaveKey      NVARCHAR( 10), ' +
                  '@cLoadKey      NVARCHAR( 10), ' +
                  '@cOrderKey     NVARCHAR( 10), ' +
                  '@cDropID       NVARCHAR( 15), ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT
            END
         END

         IF @nFunc = 1826
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cDropID
            SET @cOutField03 = @cSKU
            SET @cOutField04 = ''
            SET @cOutField05 = @cStyle
            SET @cOutField06 = @cColor + @cSize
            SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
                               THEN @cTemp_String ELSE @cColor_Descr END
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cOrderKey
            SET @cOutField10 = @cExternOrderKey
            SET @cOutField11 = SUBSTRING(@cConsigneeKey, 1, 14)

            -- Go to next screen
            SET @nOutScn  = 1877
            SET @nOutStep = 8
         END
         ELSE
         IF @nFunc = 1827
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cSKU
            SET @cOutField03 = ''
            SET @cOutField04 = SUBSTRING(@cSKU_Descr, 1, 20)
            SET @cOutField05 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE @cLottable02 END
            SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cOrderKey
            SET @cOutField10 = @cExternOrderKey
            SET @cOutField11 = @nTTL_Ord

            -- Go to next screen
            SET @nOutScn  = 1883
            SET @nOutStep = 8
         END
         ELSE
         IF @nFunc = 1828  -- (james07)
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cSKU
            SET @cOutField03 = ''
            SET @cOutField04 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cStyle ELSE SUBSTRING(@cSKU_Descr, 1, 20) END
            SET @cOutField05 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cColor + @cSize ELSE SUBSTRING(@cSKU_Descr, 21, 20) END
            SET @cOutField06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE @cLottable02 END
            SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cLoadKey
            SET @cOutField10 = @cColor_Descr
            SET @cOutField11 = @nTTL_Ord

            -- Go to next screen
            SET @nOutScn  = 1888
            SET @nOutStep = 8
         END

         IF @cPrefUOM <> '6'
            SET @cOutField12 = @cPreferQty2Display
         ELSE
            SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))

         SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = '0'
                            THEN '' ELSE @cDefaultPickQty END -- Qty to pick
         SET @cOutField14 = CASE WHEN ISNULL(@cPackCfg, '') = '' THEN '' ELSE @cPackCfg END  -- (james11)
         SET @cOutField15 = CASE WHEN @cPrefUOM <> '6' THEN
                                 CASE WHEN ISNULL( @cDefaultPrefPickQty, '') = '' OR @cDefaultPrefPickQty = '0' THEN '' ELSE @cDefaultPrefPickQty END
                            ELSE 'QTY: ' END

         SET @cFieldAttr01 = ''
         SET @cFieldAttr02 = ''
         SET @cFieldAttr03 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''
         SET @cFieldAttr06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE 'O' END
         SET @cFieldAttr07 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr09 = ''
         SET @cFieldAttr10 = ''
         SET @cFieldAttr11 = ''
         SET @cFieldAttr12 = ''
         SET @cFieldAttr13 = ''
         SET @cFieldAttr14 = ''
         SET @cFieldAttr15 = CASE WHEN @cPrefUOM <> '6' THEN '' ELSE 'O' END

         -- If config turned on, not allow to change Qty To Pick
         IF @cClusterPickLockQtyToPick = '1'
         BEGIN
            SET @cFieldAttr13 = 'O'
            SET @cInField13 = @cDefaultPickQty
         END
      END
      ELSE
      BEGIN
         SET @cOutField05 = ''
         SET @cOutField06 =  RTRIM(CAST(@nCount_SerialNo AS NVARCHAR( 5))) + '/' + CAST((@nSum_PickQty / @nOtherUnit2) AS NVARCHAR( 5))
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nCount_SerialNo < (@nSum_PickQty / @nOtherUnit2)
      BEGIN
         -- Save current screen no
         SET @nCurScn = @nInScn
         SET @nCurStep = @nInStep

         SET @cOutField01 = ''

         -- Go to Close Case screen
         SET @nOutScn  = 2011
         SET @nOutStep = 18

         GOTO Quit
      END


   END
   GOTO Quit

   Step_17_Fail:
   BEGIN
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 18. Screen = 2011
   SKU        (field01)
   DESCR      (field01)
   ADCODE     (field01, input)
********************************************************************************/
Step_18:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
         --screen mapping
      SET @cReasonCode = @cInField01

      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 69346
         SET @cErrMsg = rdt.rdtgetmessage( 69346, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_18_Fail
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
         @cLOC,
         @cID,
         @cSKU,
         @cPackUOM3,
         @nShortPickedQTY,       -- In master unit
         @cLottable01,
         @cLottable02,
         @cLottable03,
         @dLottable04,
         @dLottable05,
         @cReasonCode,
         @cUserName,
         @cModuleName,
         @cNotes

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_18_Fail
      END

      -- Get next available task
      SET @nErrNo = 0
      SET @cCurrentOrderKey = @cOrderKey -- to Store the current Orderkey
      SET @cOrderKey = ''

      -- Remember current LOC (james19)
      SET @cPrevLOC = ''
      SET @cPrevLOC = @cLOC

      SET @cClusterPickGetNextTask_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickGetNextTask_SP', @cStorerKey)
      IF ISNULL(@cClusterPickGetNextTask_SP, '') NOT IN ('', '0')
      BEGIN
         EXEC RDT.RDT_ClusterPickGetNextTask_Wrapper
             @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_SPName        = @cClusterPickGetNextTask_SP
            ,@c_Storerkey     = @cStorerKey
            ,@c_UserName      = @cUserName
            ,@c_Facility      = @cFacility
            ,@c_PutawayZone   = @cPutawayZone
            ,@c_PickZone      = @cPickZone
            ,@c_LangCode      = @cLangCode
            ,@c_oFieled01     = @c_oFieled01 OUTPUT
            ,@c_oFieled02     = @c_oFieled02 OUTPUT
            ,@c_oFieled03     = @c_oFieled03 OUTPUT
            ,@c_oFieled04     = @c_oFieled04 OUTPUT
            ,@c_oFieled05     = @c_oFieled05 OUTPUT
            ,@c_oFieled06     = @c_oFieled06 OUTPUT
            ,@c_oFieled07     = @c_oFieled07 OUTPUT
            ,@c_oFieled08     = @c_oFieled08 OUTPUT
            ,@c_oFieled09     = @c_oFieled09 OUTPUT
            ,@c_oFieled10     = @c_oFieled10 OUTPUT
            ,@c_oFieled11     = @c_oFieled11 OUTPUT
            ,@c_oFieled12     = @c_oFieled12 OUTPUT
            ,@c_oFieled13     = @c_oFieled13 OUTPUT
            ,@c_oFieled14     = @c_oFieled14 OUTPUT
            ,@c_oFieled15     = @c_oFieled15 OUTPUT
            ,@b_Success       = @b_Success   OUTPUT
            ,@n_ErrNo         = @nErrNo      OUTPUT
            ,@c_ErrMsg        = @cErrMsg     OUTPUT

         SET @cLOC            = @c_oFieled01
         SET @cOrderKey       = @c_oFieled02
         SET @cSKU            = @c_oFieled03
         SET @cSKU_Descr      = @c_oFieled04
         SET @cStyle          = @c_oFieled05
         SET @cColor          = @c_oFieled06
         SET @cSize           = @c_oFieled07
         SET @cColor_Descr    = @c_oFieled08
         SET @cLot            = @c_oFieled09
         SET @cPickSlipNo     = @c_oFieled10
         SET @cExternOrderKey = @c_oFieled11
         SET @cConsigneeKey   = @c_oFieled12
      END
      ELSE
      BEGIN
         EXECUTE rdt.rdt_Cluster_Pick_GetNextTask
            @cStorerKey,
            @cUserName,
            @cFacility,
            @cPutAwayZone,
            @cPickZone,
            @cLangCode,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT,  -- screen limitation, 20 NVARCHAR max
            @cLOC             OUTPUT,
            @cOrderKey        OUTPUT,
            @cExternOrderKey  OUTPUT,
            @cConsigneeKey    OUTPUT,
            @cSKU             OUTPUT,
            @cSKU_Descr       OUTPUT,
            @cStyle           OUTPUT,
            @cColor           OUTPUT,
            @cSize            OUTPUT,
            @cColor_Descr     OUTPUT,
            @cLot             OUTPUT,
            @cPickSlipNo      OUTPUT,
            @nMobile,
            @nFunc

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 65941
            SET @cErrMsg = rdt.rdtgetmessage( 65941, @cLangCode, 'DSP') --'GetNextTaskFail'
            ROLLBACK TRAN
            GOTO Step_18_Fail
         END
      END

      -- Get the Lottables
      SELECT
         @cLottable02 = Lottable02,
         @dLottable04 = Lottable04
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
         AND SKU = @cSKU
         AND LOT = @cLot

      -- If no more task, goto confirm picking screen
      IF ISNULL(@cOrderKey, '') = ''
      BEGIN
         SET @cPromptCloseCase = ''
         SET @cPromptCloseCase = rdt.RDTGetConfig( @nFunc, 'PromptCloseCase', @cStorerKey)

         IF LEN( RTRIM( @cPromptCloseCase)) > 1
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPromptCloseCase AND type = 'P')
            BEGIN
               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cPromptCloseCase) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, ' +
                  ' @cLoc, @cDropID, @cSKU, @nQty, @cPromptCloseCase OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile          INT,                   ' +
                  '@nFunc            INT,                   ' +
                  '@cLangCode        NVARCHAR( 3),          ' +
                  '@nStep            INT,                   ' +
                  '@nInputKey        INT,                   ' +
                  '@cStorerkey       NVARCHAR( 15),         ' +
                  '@cWaveKey         NVARCHAR( 10),         ' +
                  '@cLoadKey         NVARCHAR( 10),         ' +
                  '@cOrderKey        NVARCHAR( 10),         ' +
                  '@cLoc             NVARCHAR( 10),         ' +
                  '@cDropID          NVARCHAR( 20),         ' +
                  '@cSKU             NVARCHAR( 20),         ' +
                  '@nQty             INT,                   ' +
                  '@cPromptCloseCase NVARCHAR( 1)  OUTPUT,  ' +
                  '@nErrNo           INT           OUTPUT,  ' +
                  '@cErrMsg          NVARCHAR( 20) OUTPUT   ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey,  
                  @cLoc, @cDropID, @cSKU, @nQty, @cPromptCloseCase OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END      
         END     

         --If no more task then prompt Close Case screen (If turned on) (james03)
         IF @cPromptCloseCase = '1'
         BEGIN
            SET @cOutField01 = ''

            -- Go to Close Case screen
            SET @nOutScn  = 1886
            SET @nOutStep = 15

            GOTO Quit
         END

         SET @cOrderKey = @cCurrentOrderKey -- Assign back the OrderKey
         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         SELECT
            @nOrderPicked = COUNT( DISTINCT OrderKey),
            @nTTL_PickedQty = SUM(PickQty)
         FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE AddWho = @cUserName
            AND Status = '5'  -- Picked
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))

         -- (james36)
         SET @cPickNotFinish = ''
         IF rdt.RDTGetConfig( @nFunc, 'DISPLAYPICKNOTFINISH', @cStorerKey) = 1
         BEGIN
            IF EXISTS ( SELECT 1 from dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                        WHERE (( @nMultiStorer = 1 AND PD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND PD.StorerKey = @cStorerKey))
                        AND   ( PD.Status = '0' OR PD.Status = '4')
                        AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                        AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                        AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
                        AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                        AND   LOC.Facility = @cFacility
                        AND   PD.OrderKey IN (SELECT DISTINCT RPL.OrderKey FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK)
                                              WHERE PD.OrderKey = RPL.OrderKey
                                              AND   PD.StorerKey = RPL.StorerKey
                                              AND   RPL.AddWho = @cUserName
                                              AND   RPL.Status < '9'))
            BEGIN
               SET @cPickNotFinish = 'PICKING NOT FINISH'
            END
         END

         -- Prep next screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = @cPutawayZone
         SET @cOutField04 = @cPickZone
         SET @cOutField05 = @nOrderPicked
         SET @cOutField06 = @nTTL_PickedQty
         SET @cOutField07 = CASE WHEN ISNULL( @cPickNotFinish, '') <> '' THEN @cPickNotFinish ELSE '' END

         SET @nOutScn  = 1879
         SET @nOutStep = 10

         SET @nActQty = 0
         SET @nQtyToPick = 0

         SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND AddWho = @cUserName
            AND Status = '5'
         OPEN @curUpdRPL
         FETCH NEXT FROM @curUpdRPL INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE RDT.RDTPickLock with (ROWLOCK) SET
               Status = '9'   -- Confirm Picked
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65942
               SET @cErrMsg = rdt.rdtgetmessage( 65942, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN
               GOTO Step_18_Fail
            END

            FETCH NEXT FROM @curUpdRPL INTO @nRowRef
         END
         CLOSE @curUpdRPL
         DEALLOCATE @curUpdRPL

         GOTO Quit
      END

      IF @nMultiStorer = 1
         SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

      IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                        AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                        AND OrderKey = @cOrderKey
                        AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                        AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                        AND Status = '1'
                        AND SKU IS NULL
                        AND AddWho = @cUserName)
      BEGIN
         -- Insert next task to picklock
         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey,
         SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
         VALUES
         (@cWaveKey, @cLoadKey, @cOrderKey, '', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
         @cSKU, @cPutAwayZone, @cPickZone, '', @cLOT, @cLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65943
            SET @cErrMsg = rdt.rdtgetmessage( 65943, @cLangCode, 'DSP') --'LockOrdersFail'
            ROLLBACK TRAN
            GOTO Step_18_Fail
         END
      END
      ELSE
      BEGIN
         -- Get the lottables
         SELECT
            @cLottable02 = Lottable02,
            @dLottable04 = Lottable04
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND SKU = @cSKU
            AND LOT = @cLot

         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            LOT = @cLot,
            LOC = @cLoc,
            SKU = @cSKU,
            DropID = @cDropID,
            PackKey = @cCartonType,                                     
            Lottable02 = @cLottable02,
            Lottable04 = @dLottable04
         WHERE OrderKey = @cOrderKey
            AND Status = '1'
            AND AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65929
            SET @cErrMsg = rdt.rdtgetmessage( 65929, @cLangCode, 'DSP') --'UPDPKLockFail'
            ROLLBACK TRAN
            GOTO Step_18_Fail
         END
      END

      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'   -- (james18)
      BEGIN
         -- If change of LOC then need to go back to confirm LOC screen
         IF @cPrevLOC <> @cLOC
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = ''

            -- Go to next screen
            SET @nOutScn  = 1892
            SET @nOutStep = 19

            GOTO Quit
         END
      END

      -- If OrderKey changed
      IF @cOrderKey <> @cOutField09
      BEGIN
         -- If configkey 'AutoPromptDropID' turned on, auto go back to DropID screen
         IF @cAutoPromptDropID = '1'
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'   -- (james18)
            BEGIN
               -- If change of LOC then need to go back to confirm LOC screen
               IF @cPrevLOC <> @cLOC
               BEGIN
                  SET @nActQty = 0
                  SET @nQtyToPick = 0

                  -- Commit transaction before goto DropID screen
                  COMMIT TRAN

                  -- Prep next screen var
                  SET @cOutField01 = @cLOC
                  SET @cOutField02 = ''

                  -- Go to next screen
                  SET @nOutScn  = 1892
                  SET @nOutStep = 19

                  GOTO Quit
               END
            END

            IF @nFunc = 1826
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cLOC
               SET @cOutField02 = @cOrderKey
               SET @cOutField03 = @cExternOrderKey
               SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
               SET @cOutField05 = @cSKU
               SET @cOutField06 = @cStyle
               SET @cOutField07 = @cColor + @cSize

               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
               BEGIN
                  SET @cTemp_String = ''
                  SET @cTemp_UOM = ''
                  SET @nTemp_PackQtyIndicator = ''

                  SELECT
                     @cTemp_UOM = SUBSTRING(PACK.PackUOM3, 1, 2),
                     @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
                  FROM dbo.SKU SKU WITH (NOLOCK)
                  JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
                  WHERE SKU.StorerKey = @cStorerKey
                     AND SKU.SKU = @cSKU

                  SET @cOutField08 = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                                  '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
               END
               ELSE
               BEGIN
                  SET @cOutField08 = @cColor_Descr
               END

               SET @cOutField09 = ''   -- DropID
               SET @cOutField10 = ''   
               SET @cOutField11 = ''   

               SET @nOutScn  = 1876
               SET @nOutStep = 7
            END
            ELSE
            IF @nFunc = 1827
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cLOC
               SET @cOutField02 = @cOrderKey
               SET @cOutField03 = @cExternOrderKey
               SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
               SET @cOutField05 = @cSKU
               SET @cOutField06 = SUBSTRING(@cSKU_Descr, 1, 20)
               SET @cOutField07 = SUBSTRING(@cSKU_Descr, 21, 20)
               SET @cOutField08 = @cLottable02
               SET @cOutField09 = rdt.rdtFormatDate(@dLottable04)
               SET @cOutField10 = ''   -- DropID

               -- Go to next screen
               SET @nOutScn  = 1882
               SET @nOutStep = 7
            END
            ELSE
            IF @nFunc = 1828
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cLOC
               SET @cOutField02 = @cLoadKey
               SET @cOutField05 = @cSKU
               SET @cOutField06 = SUBSTRING(@cSKU_Descr, 1, 20)
               SET @cOutField07 = SUBSTRING(@cSKU_Descr, 21, 20)
               SET @cOutField08 = @cLottable02
               SET @cOutField09 = rdt.rdtFormatDate(@dLottable04)
               SET @cOutField10 = ''   -- DropID

               -- Go to next screen
               SET @nOutScn  = 1887
               SET @nOutStep = 7
            END

            -- (james30)
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
            BEGIN
               EXECUTE rdt.rdt_Cluster_Pick_DropID
                  @nMobile,
                  @nFunc,
                  @cStorerKey,
                  @cUserName,
                  @cFacility,
                  @cLoadKey,
                  @cPickSlipNo,
                  @cOrderKey,
                  @cDropID       OUTPUT,
                  @cSKU,
                  'R',      -- R = Retrieve
                  @cLangCode,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

               IF @nFunc = 1826
               BEGIN
                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                     SET @cOutField09 = ''         -- DropID
                  ELSE
                     SET @cOutField09 = @cDropID   -- DropID
               END
               ELSE
               BEGIN
                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                     SET @cOutField10 = ''         -- DropID
                  ELSE
                     SET @cOutField10 = @cDropID   -- DropID
               END
            END

            SET @nActQty = 0
            SET @nQtyToPick = 0

            -- Commit transaction before goto DropID screen
            COMMIT TRAN

            GOTO Quit
         END
      END   -- If OrderKey changed

      -- Get the total allocated qty for LOC + SKU + OrderKey
      SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.LOC = @cLOC
         AND PD.SKU = @cSKU
         AND PD.OrderKey = @cOrderKey
         AND PD.Status = '0'
         AND PD.LOT = @cLOT
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
         AND L.Facility = @cFacility
      SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
      IF CAST(@cDefaultPickQty AS INT) <= 0 SET @cDefaultPickQty = ''

      IF @cDefaultToAllocatedQty = '1'
      BEGIN
         SET @cDefaultPickQty = @nTotalPickQty
      END

      SET @nQtyToPick = 0
      SET @nActQty = 0

      -- Get the total oustanding qty for orderkey + putawayzone + pickzone
      SELECT @nTTL_Qty = SUM(QTY)
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE RPL.StorerKey = @cStorerKey
         AND RPL.Status < '5'
         AND RPL.AddWho = @cUserName
         AND RPL.PickQty <= 0
         AND PD.Status = '0'
         AND LA.StorerKey = @cStorerKey    -- tlting03
         AND LA.SKU = @cSKU
         AND PD.LOC = @cLOC
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
         AND L.Facility = @cFacility
         AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
         AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
         AND EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = RPL.AddWho
                  AND StorerKey = RPL.StorerKey AND OrderKey =  PD.OrderKey )       -- tlting02
--         AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) -- SOS# 176144

         -- Get Total Orders left on the current sku that need to pick
      SELECT @nTTL_Ord = COUNT( DISTINCT PD.ORDERKEY)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE RPL.StorerKey = @cStorerKey
         AND RPL.Status < '5'
         AND RPL.AddWho = @cUserName
         AND RPL.PickQty <= 0
         AND PD.SKU = @cSKU
         AND PD.LOC = @cLOC
         AND PD.Status = '0'
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
         AND L.Facility = @cFacility
         AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
         AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

      -- (james14)
      IF rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
      BEGIN
         SET @cOS_Qty = ''

         IF @cLoadDefaultPickMethod = 'C'
         BEGIN
            -- Get the total qty picked per orders
            SELECT @nTTL_Pick_ORD = ISNULL( SUM(PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE PD.StorerKey = @cStorerKey
               AND LPD.LoadKey = @cLoadKey

            -- Get the total qty unpick per orders
            SELECT @nTTL_UnPick_ORD = ISNULL( SUM(PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE PD.StorerKey = @cStorerKey
               AND PD.Status >= '3'
               AND LPD.LoadKey = @cLoadKey

            SET @cOS_Qty = 'LOAD QTY: ' + LTRIM(RTRIM(CAST((@nTTL_UnPick_ORD + @nQtyToPick) AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
         END
         ELSE
         BEGIN
            -- Get the total qty picked per orders
            SELECT @nTTL_Pick_ORD = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

            -- Get the total qty unpick per orders
            SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND Status >= '3'

            SET @cOS_Qty = 'OS QTY: ' + LTRIM(RTRIM(CAST(@nTTL_UnPick_ORD AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
         END
      END

      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
      BEGIN
         SET @cTemp_String = ''
         SET @cTemp_UOM = ''
         SET @nTemp_PackQtyIndicator = ''

         SELECT
            @cTemp_UOM = SUBSTRING( PACK.PackUOM3, 1, 2),
            @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @cTemp_String = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                            '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
      END

      -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'    (james11)
      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickShowPackCfg', @cStorerKey) = '1'
      BEGIN
         SET @cPackCfg = ''

         SELECT @fPack_Qty = PACK.QTY,
             @fPack_InnerPack = PACK.InnerPack,
             @fPack_CaseCnt = PACK.CaseCnt
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @cPackCfg = SUBSTRING( CAST(@fPack_Qty AS NVARCHAR(1)) + ':' +
                         RTRIM( CAST( @fPack_InnerPack AS NVARCHAR( 3))) + ':' +
                         RTRIM( CAST( @fPack_CaseCnt AS NVARCHAR( 4))), 1, 9)
      END

      IF @cPrefUOM <> '6'
      BEGIN
         SELECT TOP 1
            @nPrefUOM_Div = CAST( IsNULL(
               CASE @cPrefUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- Convert to prefer UOM QTY to be picked
         SET @nPrefQTY2Pick = @nQtyToPick / @nPrefUOM_Div -- Calc QTY in Pref UOM
         SET @nMstQTY2Pick = @nQtyToPick % @nPrefUOM_Div  -- Calc remaining QTY in master unit

         -- Convert to prefer UOM QTY picked
         SET @nPrefQTYPicked = @nTotalPickQty / @nPrefUOM_Div -- Calc QTY in Pref UOM
         SET @nMstQTYPicked = @nTotalPickQty % @nPrefUOM_Div  -- Calc remaining QTY in master unit

			--SOS334125 Start
         SET @cPreferQty2Display = RTRIM( CAST( @nPrefQTY2Pick AS NVARCHAR( 4))) + '-' +
                                   RTRIM( CAST( @nMstQTY2Pick AS NVARCHAR( 4))) +
                                   '/' +
                                   RTRIM( CAST( @nPrefQTYPicked AS NVARCHAR( 4))) + '-' +
                                   RTRIM( CAST( @nMstQTYPicked AS NVARCHAR( 4)))
			--SOS334125 End

         SET @cDefaultPrefPickQty = CAST( @cDefaultPickQty AS INT) / @nPrefUOM_Div
         SET @cDefaultPickQty = CAST( @cDefaultPickQty AS INT) % @nPrefUOM_Div
      END

      -- Get stored proc name for extended info (james40)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT '
            
            SET @cSQLParam =
               '@nMobile       INT, ' +
               '@nFunc         INT, ' +
               '@cLangCode     NVARCHAR( 3), ' +
               '@nStep         INT, ' +
               '@nInputKey     INT, ' +
               '@cWaveKey      NVARCHAR( 10), ' +
               '@cLoadKey      NVARCHAR( 10), ' +
               '@cOrderKey     NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 15), ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT
         END
      END
      
      IF @nFunc = 1826
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = ''
         SET @cOutField05 = @cStyle
         SET @cOutField06 = @cColor + @cSize
         SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
                            THEN @cTemp_String ELSE @cColor_Descr END
         SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                 THEN @cOS_Qty
                                 WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                            ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
         SET @cOutField09 = @cOrderKey
         SET @cOutField10 = @cExternOrderKey
         SET @cOutField11 = SUBSTRING(@cConsigneeKey, 1, 14)
      END
      ELSE
      IF @nFunc = 1827
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = ''
         SET @cOutField04 = SUBSTRING(@cSKU_Descr, 1, 20)
         SET @cOutField05 = SUBSTRING(@cSKU_Descr, 21, 20)
         SET @cOutField06 = @cLottable02
         SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
         SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                 THEN @cOS_Qty
                                 WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                            ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
         SET @cOutField09 = @cOrderKey
         SET @cOutField10 = @cExternOrderKey
         SET @cOutField11 = @nTTL_Ord
      END
      ELSE
      IF @nFunc = 1828  -- (james07)
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = ''
         SET @cOutField04 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cStyle ELSE SUBSTRING(@cSKU_Descr, 1, 20) END
         SET @cOutField05 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cColor + @cSize ELSE SUBSTRING(@cSKU_Descr, 21, 20) END
         SET @cOutField06 = @cLottable02
         SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
         SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                 THEN @cOS_Qty
                                 WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                            ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
         SET @cOutField09 = @cLoadKey
         SET @cOutField10 = @cColor_Descr
         SET @cOutField11 = @nTTL_Ord
      END
      IF @cPrefUOM <> '6'
         SET @cOutField12 = @cPreferQty2Display
      ELSE
         SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))

      SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = '0'
                         THEN '' ELSE @cDefaultPickQty END -- Qty to pick
      SET @cOutField14 = CASE WHEN ISNULL(@cPackCfg, '') = '' THEN '' ELSE @cPackCfg END  -- (james11)
      SET @cOutField15 = CASE WHEN @cPrefUOM <> '6' THEN
                              CASE WHEN ISNULL( @cDefaultPrefPickQty, '') = '' OR @cDefaultPrefPickQty = '0' THEN '' ELSE @cDefaultPrefPickQty END
                         ELSE 'QTY: ' END

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE 'O' END
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = CASE WHEN @cPrefUOM <> '6' THEN '' ELSE 'O' END

      -- If config turned on, not allow to change Qty To Pick
      IF @cClusterPickLockQtyToPick = '1'
      BEGIN
         SET @cFieldAttr13 = 'O'
         SET @cInField13 = @cDefaultPickQty
      END
   END

   Step_18_Fail:
END
GOTO Quit

/********************************************************************************
Step 19. Screen = 1892
   LOC      (field03, input)
********************************************************************************/
Step_19:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Check if blank
      IF ISNULL(@cInField02, '') = ''
      BEGIN
         SET @nErrNo = 69362
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD LOC'
         GOTO Step_19_Fail
      END

      -- Check the LOC scanned match with suggested LOC
      IF @cLOC <> @cInField02
      BEGIN
         SET @nErrNo = 69363
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC NOT MATCH'
         GOTO Step_19_Fail
      END

      SET @nActQty = 0
      SET @nQtyToPick = '0'

      -- Skip Drop ID screen if it is exists (james21)
      IF rdt.RDTGetConfig( @nFunc, 'SKIPDROPIDSCNIFEXISTS', @cStorerKey) = '1' AND EXISTS
      ( SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK)
        WHERE AddWho = @cUserName
        AND   Status < '5'    -- (james22)
        AND   ISNULL(DropID, '') <> '' )
      BEGIN
         -- Get the total oustanding qty for orderkey + putawayzone + pickzone
         SELECT @nTTL_Qty = SUM(PD.QTY)
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
            AND RPL.Status < '5'
            AND RPL.AddWho = @cUserName
            AND PD.Status = '0'
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility
            AND RPL.PickQty <= 0
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND (( ISNULL( @cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
            AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = RPL.StorerKey
                           AND OrderKey = PD.OrderKey
                           AND ADDWHO = @cUserName ) -- SOS# 176144

         -- Get the total allocated qty for LOC + SKU + OrderKey
         SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND OrderKey = @cOrderKey
            AND Status = '0'
            AND Lot = @cLOT

         SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
         IF CAST(@cDefaultPickQty AS INT) <= 0
         BEGIN
            SET @cDefaultPickQty = ''

            IF @cDefaultToAllocatedQty = '1'
            BEGIN
               SET @cDefaultPickQty = @nTotalPickQty
            END

            IF @nQtyToPick > 0
            BEGIN
               IF ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = '0'
                  SET @cDefaultPickQty = ''
               ELSE
                  SET @cDefaultPickQty = CAST(@cDefaultPickQty AS INT) - @nQtyToPick
            END
         END

         -- Get Total Orders left on the current sku that need to pick
         SELECT @nTTL_Ord = COUNT( DISTINCT PD.ORDERKEY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
            AND RPL.Status < '5'
            AND RPL.AddWho = @cUserName
            AND RPL.PickQty <= 0
            AND PD.SKU = @cSKU
            AND PD.Status = '0'
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND (( ISNULL( @cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

         -- (james14)
         IF rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
         BEGIN
            SET @cOS_Qty = ''

            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               -- Get the total qty picked per orders
               SELECT @nTTL_Pick_ORD = ISNULL( SUM(PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
                  AND LPD.LoadKey = @cLoadKey

               -- Get the total qty unpick per orders
               SELECT @nTTL_UnPick_ORD = ISNULL( SUM(PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))               
                  AND PD.Status >= '3'
                  AND LPD.LoadKey = @cLoadKey

               SET @cOS_Qty = 'LOAD QTY: ' + LTRIM(RTRIM(CAST((@nTTL_UnPick_ORD + @nQtyToPick) AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
            END
            ELSE
            BEGIN
               -- Get the total qty picked per orders
               SELECT @nTTL_Pick_ORD = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
                  AND OrderKey = @cOrderKey

               -- Get the total qty unpick per orders
               SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
                  AND OrderKey = @cOrderKey
                  AND Status >= '3'

               SET @cOS_Qty = 'OS QTY: ' + LTRIM(RTRIM(CAST((@nTTL_UnPick_ORD + @nQtyToPick) AS NVARCHAR(5)))) + '/' + LTRIM(RTRIM(CAST(@nTTL_Pick_ORD AS NVARCHAR(5))))
            END
         END

         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
         BEGIN
            SET @cTemp_String = ''
            SET @cTemp_UOM = ''
            SET @nTemp_PackQtyIndicator = ''

            SELECT
               @cTemp_UOM = SUBSTRING( PACK.PackUOM3, 1, 2),
               @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE (( @nMultiStorer = 1) OR ( SKU.StorerKey = @cStorerKey))
               AND SKU.SKU = @cSKU

            SET @cTemp_String = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                           '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
         END

         -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'    (james11)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickShowPackCfg', @cStorerKey) = '1'
         BEGIN
            SET @cPackCfg = ''

            SELECT @fPack_Qty = PACK.QTY,
                   @fPack_InnerPack = PACK.InnerPack,
                   @fPack_CaseCnt = PACK.CaseCnt
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE (( @nMultiStorer = 1) OR ( SKU.StorerKey = @cStorerKey))
               AND SKU.SKU = @cSKU

            SET @cPackCfg = SUBSTRING( CAST(@fPack_Qty AS NVARCHAR(1)) + ':' +
                            RTRIM( CAST( @fPack_InnerPack AS NVARCHAR( 3))) + ':' +
                            RTRIM( CAST( @fPack_CaseCnt AS NVARCHAR( 4))), 1, 9)
         END

         SET @cScanLOT02 = rdt.RDTGetConfig( @nFunc, 'SCANLOT02', @cStorerKey)
         IF ISNULL( @cScanLOT02, '') = '' OR @cScanLOT02 <> '1'
            SET @cScanLOT02 = '0'

         IF @cPrefUOM <> '6'
         BEGIN
            SELECT TOP 1
               @nPrefUOM_Div = CAST( IsNULL(
                  CASE @cPrefUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU (NOLOCK)
               INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU

            -- Convert to prefer UOM QTY to be picked
            SET @nPrefQTY2Pick = @nQtyToPick / @nPrefUOM_Div -- Calc QTY in Pref UOM
            SET @nMstQTY2Pick = @nQtyToPick % @nPrefUOM_Div  -- Calc remaining QTY in master unit

            -- Convert to prefer UOM QTY picked
            SET @nPrefQTYPicked = @nTotalPickQty / @nPrefUOM_Div -- Calc QTY in Pref UOM
            SET @nMstQTYPicked = @nTotalPickQty % @nPrefUOM_Div  -- Calc remaining QTY in master unit

				--SOS334125 Start
            SET @cPreferQty2Display = RTRIM( CAST( @nPrefQTY2Pick AS NVARCHAR( 4))) + '-' +
                                      RTRIM( CAST( @nMstQTY2Pick AS NVARCHAR( 4))) +
                                      '/' +
                                      RTRIM( CAST( @nPrefQTYPicked AS NVARCHAR( 4))) + '-' +
                                      RTRIM( CAST( @nMstQTYPicked AS NVARCHAR( 4)))
				--SOS334125 End

            SET @cDefaultPrefPickQty = CAST( @cDefaultPickQty AS INT) / @nPrefUOM_Div
            SET @cDefaultPickQty = CAST( @cDefaultPickQty AS INT) % @nPrefUOM_Div
         END

         -- Get stored proc name for extended info (james40)
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT '
               
               SET @cSQLParam =
                  '@nMobile       INT, ' +
                  '@nFunc         INT, ' +
                  '@cLangCode     NVARCHAR( 3), ' +
                  '@nStep         INT, ' +
                  '@nInputKey     INT, ' +
                  '@cWaveKey      NVARCHAR( 10), ' +
                  '@cLoadKey      NVARCHAR( 10), ' +
                  '@cOrderKey     NVARCHAR( 10), ' +
                  '@cDropID       NVARCHAR( 15), ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cWaveKey, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cLOC, @cExtendedInfo OUTPUT
            END
         END
      
         IF @nFunc = 1826
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cDropID
            SET @cOutField03 = @cSKU
            SET @cOutField04 = ''
            SET @cOutField05 = @cStyle
            SET @cOutField06 = @cColor + @cSize
            SET @cOutField07 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
                               THEN @cTemp_String ELSE @cColor_Descr END
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cOrderKey
            SET @cOutField10 = @cExternOrderKey
            SET @cOutField11 = SUBSTRING(@cConsigneeKey, 1, 14)

            EXEC rdt.rdtSetFocusField @nMobile, 4

            -- Go to next screen
            SET @nOutScn  = 1877
            SET @nOutStep = 8
         END
         ELSE
         IF @nFunc = 1827
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cSKU
            SET @cOutField03 = ''
            SET @cOutField04 = SUBSTRING(@cSKU_Descr, 1, 20)
            SET @cOutField05 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE @cLottable02 END
            SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cOrderKey
            SET @cOutField10 = @cExternOrderKey
            SET @cOutField11 = @nTTL_Ord

            EXEC rdt.rdtSetFocusField @nMobile, 3

            -- Go to next screen
            SET @nOutScn  = 1883
            SET @nOutStep = 8
         END
         ELSE
         IF @nFunc = 1828  -- (james07)
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cSKU
            SET @cOutField03 = ''
            SET @cOutField04 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cStyle ELSE SUBSTRING(@cSKU_Descr, 1, 20) END
            SET @cOutField05 = CASE WHEN ISNULL( @cSKU_Descr, '') = '' THEN @cColor + @cSize ELSE SUBSTRING(@cSKU_Descr, 21, 20) END
            SET @cOutField06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE @cLottable02 END
            SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                                    THEN @cOS_Qty
                                    WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                               ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
            SET @cOutField09 = @cLoadKey
            SET @cOutField10 = @cColor_Descr
            SET @cOutField11 = @nTTL_Ord

            EXEC rdt.rdtSetFocusField @nMobile, 3

            -- Go to next screen
            SET @nOutScn  = 1888
            SET @nOutStep = 8
         END

         IF @cPrefUOM <> '6'
            SET @cOutField12 = @cPreferQty2Display
         ELSE
            SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))

         SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = '0'
                            THEN '' ELSE @cDefaultPickQty END -- Qty to pick
         SET @cOutField14 = CASE WHEN ISNULL(@cPackCfg, '') = '' THEN '' ELSE @cPackCfg END  -- (james11)
         SET @cOutField15 = CASE WHEN @cPrefUOM <> '6' THEN
                                 CASE WHEN ISNULL( @cDefaultPrefPickQty, '') = '' OR @cDefaultPrefPickQty = '0' THEN '' ELSE @cDefaultPrefPickQty END
                            ELSE 'QTY: ' END

         SET @cFieldAttr01 = ''
         SET @cFieldAttr02 = ''
         SET @cFieldAttr03 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''
         SET @cFieldAttr06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE 'O' END
         SET @cFieldAttr07 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr09 = ''
         SET @cFieldAttr10 = ''
         SET @cFieldAttr11 = ''
         SET @cFieldAttr12 = ''
         SET @cFieldAttr13 = ''
         SET @cFieldAttr14 = ''
         SET @cFieldAttr15 = CASE WHEN @cPrefUOM <> '6' THEN '' ELSE 'O' END
      END   -- end of (james21)
      ELSE
      BEGIN
     -- Goto Drop ID screen
         IF @nFunc = 1826
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cOrderKey
            SET @cOutField03 = @cExternOrderKey
            SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cStyle
            SET @cOutField07 = @cColor + @cSize

            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
            BEGIN
               SET @cTemp_String = ''
               SET @cTemp_UOM = ''
               SET @nTemp_PackQtyIndicator = ''

               SELECT
                  @cTemp_UOM = SUBSTRING(PACK.PackUOM3, 1, 2),
                  @nTemp_PackQtyIndicator = SUBSTRING( CAST( SKU.PackQtyIndicator AS NVARCHAR( 3)), 1, 3)
               FROM dbo.SKU SKU WITH (NOLOCK)
               JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
               WHERE (( @nMultiStorer = 1) OR ( SKU.StorerKey = @cStorerKey))
                  AND SKU.SKU = @cSKU

               SET @cOutField08 = SUBSTRING(@cColor_Descr, 1, 2) + '  ' + SUBSTRING(ISNULL(@cLottable02, '     '), 1, 5) +
                                  '  ' + SUBSTRING(@cTemp_UOM, 1, 2) + '  ' + SUBSTRING((CAST(@nTemp_PackQtyIndicator AS NVARCHAR( 3))), 1, 3)
            END
            ELSE
            BEGIN
               SET @cOutField08 = @cColor_Descr
            END

            SET @cOutField09 = ''   -- DropID
            SET @cOutField10 = ''   
            SET @cOutField11 = ''   
         
            -- Go to next screen
            SET @nOutScn  = 1876
            SET @nOutStep = 7
         END
         ELSE
         IF @nFunc = 1827
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cOrderKey
            SET @cOutField03 = @cExternOrderKey
            SET @cOutField04 = SUBSTRING(@cConsigneeKey, 1, 14)
            SET @cOutField05 = @cSKU
            SET @cOutField06 = SUBSTRING(@cSKU_Descr, 1, 20)
            SET @cOutField07 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField08 = @cLottable02
            SET @cOutField09 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField10 = ''   -- DropID
            -- SOS172041
            IF RDT.RDTGetConfig( @nFunc, 'ClusterPickPromptNewDropID', @cStorerKey) = 1
            BEGIN
               SELECT @cDropID = DropID FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LOC = @cLOC
                  AND OrderKey = @cOrderKey
                  AND AddWho = @cUserName

               IF ISNULL(@cDropID, '') = ''
               BEGIN
                  SET @cOutField11 = 'NEW DROP ID'
                  SET @cOutField12 = ''
               END
               ELSE
               BEGIN
                  SET @cOutField11 = @cDropID
                  SET @cOutField12 = ''
               END
            END
            ELSE
            BEGIN
               SET @cOutField11 = 'SCAN CARTON ID'
               SET @cOutField12 = 'DROP ID:'
            END

            -- Go to next screen
            SET @nOutScn  = 1882
            SET @nOutStep = 7
         END

         -- (james30)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
         BEGIN
            EXECUTE rdt.rdt_Cluster_Pick_DropID
               @nMobile,
               @nFunc,
               @cStorerKey,
               @cUserName,
               @cFacility,
               @cLoadKey,
               @cPickSlipNo,
               @cOrderKey,
               @cDropID       OUTPUT,
               @cSKU,
               'R',      -- R = Retrieve
               @cLangCode,
               @nErrNo        OUTPUT,
               @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

            IF @nFunc = 1826
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                  SET @cOutField09 = ''         -- DropID
               ELSE
                  SET @cOutField09 = @cDropID   -- DropID
            END
            ELSE
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '1'
                  SET @cOutField10 = ''         -- DropID
               ELSE
                  SET @cOutField10 = @cDropID   -- DropID
            END
         END

         -- (james42)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickCaptureCtnType', @cStorerKey) NOT IN ('', '0')
         BEGIN
            IF @nFunc = 1826
            BEGIN
               SET @cOutField10 = 'CTN TYPE:'   
               SET @cFieldAttr11 = ''   
               SET @cOutField11 = ''   
            END
            ELSE
            BEGIN
               SET @cOutField11 = 'CTN TYPE:' 
               SET @cFieldAttr12 = ''     
               SET @cOutField12 = ''   
            END
         END
         ELSE
         BEGIN
            IF @nFunc = 1826
               SET @cFieldAttr11 = 'O'   
            ELSE
               SET @cFieldAttr12 = 'O'   
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen variable
      SET @cOutField01 = ''

      -- Go back prev screen
      SET @nOutScn = 1874
      SET @nOutStep = 5
 END

   Step_19_Fail:
END
GOTO Quit

/********************************************************************************
Step 20. Screen = 4790
   PICKING ON HOLD      (Press F4 to unhold)
********************************************************************************/
Step_20:
BEGIN
   -- (james50)
   IF @nInputKey = @nFunctionKey -- Special event, call extended stored proc
   BEGIN
      SET @cExtendedFuncKeySP = rdt.RDTGetConfig( @nFunc, 'ExtendedFuncKeySP', @cStorerkey)
      IF @cExtendedFuncKeySP NOT IN ('0', '')
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
            GOTO Step_20_Fail  
      END

      SET @nOutScn = @nCurScn
      SET @nOutStep = @nCurStep

      IF @nStep = 7
      BEGIN
         SET @cOutField01 = @cLOC
      END

      IF @nInScn = 1870 AND @nInStep = 1
      BEGIN
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '1', -- Sign in function
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey

         SET @cOutField01 = ''
      END
   END

   Step_20_Fail:
END
        
END
Quit:

GO