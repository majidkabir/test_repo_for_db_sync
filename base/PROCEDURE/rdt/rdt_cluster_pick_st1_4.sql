SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_St1_4                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick step1 - step4                                  */
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

CREATE PROC [RDT].[rdt_Cluster_Pick_St1_4] (
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
   IF @nStep = 1   GOTO Step_1 -- Scn = 1870. WaveKey
   IF @nStep = 2   GOTO Step_2 -- Scn = 1871. LoadKey
   IF @nStep = 3   GOTO Step_3 -- Scn = 1872. OrderKey
   IF @nStep = 4   GOTO Step_4 -- Scn = 1873. PutAwayZone
END

/********************************************************************************
Step 1. Screen = 1870
   WaveKey     (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cWaveKey = @cInField01

      --if input is blank, goto next screen
      IF ISNULL(@cWaveKey, '') = ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickWaveKeyReq', @cStorerKey) = 1  -- (james15)
         BEGIN
            SET @nErrNo = 69355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WAVEKEY Is Req
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' --WaveKey
            SET @cOutField02 = '' --LoadKey

            -- Go to next screen
            SET @nOutScn  = 1871
            SET @nOutStep = 2

            DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT RowRef FROM RDT.RDTPICKLOCK WITH (NOLOCK) 
            WHERE ADDWHO = @cUserName 
            AND   Status < '9'
            OPEN CUR_DEL
            FETCH NEXT FROM CUR_DEL INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               DELETE FROM RDT.RDTPICKLOCK WITH (ROWLOCK) WHERE RowRef = @nRowRef
               FETCH NEXT FROM CUR_DEL INTO @nRowRef
            END
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL

            GOTO Quit
         END
      END

      IF @cWaveKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 65901
            SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Bad WAVEKEY
            GOTO Step_1_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cWaveKey --WaveKey
      SET @cOutField02 = '' --LoadKey

      -- Go to next screen
      SET @nOutScn  = 1871
      SET @nOutStep = 2

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (Vicky06) EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nOutScn  = @nMenu
      SET @nOutStep = 0
      SET @cOutField01 = '' -- WaveKey
   END

   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. Screen = 1871
   WaveKey  (field01)
   LoadKey     (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cLoadKey = @cInField02

      --if input is blank, goto next screen
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         -- If using conso pick then scanning loadkey is mandatory   (james07)
         IF @nFunc = 1828
         BEGIN
            SET @nErrNo = 65902
            SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad LOADKEY
            GOTO Step_2_Fail
         END
         ELSE
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickLoadKeyReq', @cStorerKey) = 1  -- (james16)
         BEGIN
            SET @nErrNo = 69356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOADKEY Is Req
            GOTO Step_2_Fail
         END

         -- Prep next screen var
         SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END--WaveKey
         SET @cOutField02 = '' --LoadKey
         SET @cOutField03 = '' --OrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = '0'
         SET @nOrdCount = 0

         SET @cOrderKey = ''
         SET @cLastOrderKey = ''

         -- Go to next screen
         SET @nOutScn  = 1872
         SET @nOutStep = 3

         GOTO Quit
      END

      IF @cLoadKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 65902
            SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad LOADKEY
            GOTO Step_2_Fail
         END

         -- (james07)
         SELECT @cLoadDefaultPickMethod = LoadPickMethod FROM dbo.LoadPlan WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey

         -- If using conso pick but loadplan pick method <> 'C' then prompt error
         IF @nFunc = 1828 AND @cLoadDefaultPickMethod <> 'C'
         BEGIN
            SET @nErrNo = 65902
            SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad LOADKEY
            GOTO Step_2_Fail
         END
      END

      IF @cWaveKey <> '' AND @cLoadKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
         WHERE UserDefine09 = @cWaveKey
            AND LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 65903
            SET @cErrMsg = rdt.rdtgetmessage( 65903, @cLangCode, 'DSP') --Load not in Wave
            GOTO Step_2_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END --WaveKey
      SET @cOutField02 = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN '' ELSE @cLoadKey END --LoadKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = '0'
      SET @nOrdCount = 0

      -- Go to next screen
      SET @nOutScn  = 1872
      SET @nOutStep = 3

      SET @cOrderKey = ''
      SET @cLastOrderKey = ''

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to prev screen
      SET @nOutScn  = 1870
      SET @nOutStep = 1

      SET @cWaveKey = ''
      SET @cLoadKey = ''

      SET @cOutField01 = ''
   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END --WaveKey
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. Screen = 1872
   WaveKey     (field01)
   LoadKey     (field02)
   OrderKey    (field03, input)
   Last OrderKey (field04)
   OrderKey Count (field05)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOrderKey = @cInField03

      -- If all 3 input is blank
      IF ISNULL(@cWaveKey, '') = '' AND ISNULL(@cLoadKey, '') = '' AND ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLastOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 65904
         SET @cErrMsg = rdt.rdtgetmessage( 65904, @cLangCode, 'DSP') --NeedWav/Load/Ord
         GOTO Step_3_Fail
      END

      -- If either WaveKey/LoadKey entered, check OrderKey exists in Wave/LoadPlan
      IF ISNULL(@cOrderKey, '') <> ''
      BEGIN
         IF ISNULL(@cWaveKey, '') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.WaveDetail WITH (NOLOCK)
                           WHERE WaveKey = @cWaveKey
                          AND OrderKey = @cOrderKey)
            BEGIN
               SET @nErrNo = 65905
               SET @cErrMsg = rdt.rdtgetmessage( 65905, @cLangCode, 'DSP') --Bad OrderKey
               GOTO Step_3_Fail
            END
         END

         IF ISNULL(@cWaveKey, '') = '' AND ISNULL(@cLoadKey, '') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
               AND OrderKey = @cOrderKey)
            BEGIN
               SET @nErrNo = 65906
               SET @cErrMsg = rdt.rdtgetmessage( 65906, @cLangCode, 'DSP') --Bad OrderKey
               GOTO Step_3_Fail
            END
         END
      END

      IF ISNULL(@cOrderKey, '') <> ''
      BEGIN
         IF @nMultiStorer = 1
         BEGIN
            SET @cOrder_Status = ''
            SELECT @cOrder_Status = MIN(OD.Status)
            FROM dbo.OrderDetail OD WITH (NOLOCK)
            JOIN StorerGroup SG WITH (NOLOCK) ON (OD.StorerKey = SG.StorerKey)
            WHERE SG.StorerGroup = @cStorerKey
            AND   OrderKey = @cOrderKey

            IF ISNULL(@cOrder_Status, '') = ''
            BEGIN
               SET @nErrNo = 69375
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID ORDERS
               GOTO Step_3_Fail
            END

            IF ISNULL(@cOrder_Status, '') = '0' OR ISNULL(@cOrder_Status, '') >= '5'
            BEGIN
               SET @nErrNo = 69376
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Order Status
               GOTO Step_3_Fail
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  -- (james09)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND Status >= '1'
                  AND Status < '5')
            BEGIN
               
               SET @nErrNo = 65907
               SET @cErrMsg = rdt.rdtgetmessage( 65907, @cLangCode, 'DSP') --Bad Order Status
               GOTO Step_3_Fail
            END
         END

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey =  @cOrderKey

         -- (james39)
         SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
         IF @cExtendedUpdateSP NOT IN ('0', '')
         BEGIN
            SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, ' + 
               ' @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

            SET @cSQLParms =    
               '@nMobile                   INT,           ' +
               '@nFunc                     INT,           ' +
               '@cLangCode                 NVARCHAR( 3),  ' +
               '@nStep                     INT,           ' +
               '@nInputKey                 INT,           ' +
               '@cStorerkey                NVARCHAR( 15), ' +
               '@cWaveKey                  NVARCHAR( 10), ' +
               '@cLoadKey                  NVARCHAR( 10), ' +
               '@cOrderKey                 NVARCHAR( 10), ' +
               '@bSuccess                  INT           OUTPUT,  ' +
               '@nErrNo                    INT           OUTPUT,  ' +
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey,  
                 @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
                 
            IF @b_Success <> 1
               GOTO Step_3_Fail  
         END

         SET @cPickSlipNo = ''

         -- check discrete first    (james23)
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         WHERE PH.OrderKey = @cOrderKey
            AND PH.Status = '0'

         -- not discrete pick, look in wave
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    -- (james09)
            WHERE (( @nMultiStorer = 1 AND OD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND OD.StorerKey = @cStorerKey))
               AND O.OrderKey = @cOrderKey
               AND PH.Status = '0'
               AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
         END

         -- If not wave plan, look in loadplan
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey  AND PH.ExternOrderKey <> '')
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey     -- (james09)
            WHERE (( @nMultiStorer = 1 AND OD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND OD.StorerKey = @cStorerKey))
               AND O.OrderKey = @cOrderKey
               AND PH.Status = '0'
               AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
         END

         -- Check if pickslip printed
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 65908
            SET @cErrMsg = rdt.rdtgetmessage( 65908, @cLangCode, 'DSP') --PKSLIPNotPrinted
            GOTO Step_3_Fail
         END

         -- Check if pickslip scanned out
         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                    WHERE PickSlipNo = @cPickSlipNo
                     AND ScanOutDate IS NOT NULL)
         BEGIN
            SET @nErrNo = 65909
            SET @cErrMsg = rdt.rdtgetmessage( 65909, @cLangCode, 'DSP') --PS Scanned Out
            GOTO Step_3_Fail
         END

      END   -- IF ISNULL(@cOrderKey, '') <> ''

      -- If no orderkey is keyed in then pickslipno will be blank
      -- Make sure pickslipno is selected properly    (jamesxx)
      --IF ISNULL(@cPickSlipNo, '') = ''           -- (james37)
      --BEGIN
      IF ISNULL(@cOrderKey, '') <> ''  -- By OrderKey
      BEGIN
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
         WHERE (( @nMultiStorer = 1 AND OD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND OD.StorerKey = @cStorerKey))
            AND O.OrderKey = @cOrderKey
            AND PH.Status = '0'

         -- If not wave plan, look in loadplan
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON PH.ExternOrderKey = O.LoadKey
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE (( @nMultiStorer = 1 AND OD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND OD.StorerKey = @cStorerKey))
               AND O.OrderKey = @cOrderKey
               AND PH.Status = '0'
         END

         -- Not in wave, not in load then check 4 discrete pickslip
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            WHERE PH.OrderKey = @cOrderKey
               AND PH.Status = '0'
         END
      END
      ELSE
      IF ISNULL(@cLoadKey, '') <> ''   -- By LoadKey
      BEGIN
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE ExternOrderKey = @cLoadKey
         AND   Status = '0'
      END
      ELSE
      IF ISNULL(@cWaveKey, '') <> ''   -- SOS# 307304
      BEGIN                            -- By WaveKey
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
         AND   Status = '0'
      END
      --END

      -- Auto scan in pickslip if config turned on (james30)
      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickAutoScanIn', @cStorerKey) = '1' AND 
         ISNULL( @cPickSlipNo, '') <> ''
      BEGIN
         -- if key in orderkey then do scanning
         IF ISNULL(@cOrderKey, '') <> '' OR 
            -- if no orderkey key in, no prev orderkey key in and 1 of the wave or load key in
            ( ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLastOrderKey, '') = '' AND 
            ( ISNULL(@cWaveKey, '') <> '' OR ISNULL(@cLoadKey, '') <> ''))
         BEGIN
            IF ISNULL(@cOrderKey, '') <> ''
            BEGIN
               --Check if PickSlipNo exists in pickinginfo
               IF NOT EXISTS ( SELECT 1
                               FROM dbo.PickingInfo WITH (NOLOCK)
                               WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  INSERT INTO dbo.PickingInfo
                  (PickSlipNo, ScanInDate, PickerID )
                  Values(@cPickSlipNo, GETDATE(), sUser_sName())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69379
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
                     GOTO Step_3_Fail
                  END
               END   -- Insert pickinginfo
               ELSE
               BEGIN
                  UPDATE dbo.PickingInfo WITH (ROWLOCK) SET
                     ScanInDate = GETDATE(),
                     PickerID = sUser_sName()
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   ScanInDate IS NULL

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69380
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
                     GOTO Step_3_Fail
                  END
               END   -- Update pickinginfo
            END
            ELSE
            BEGIN
               -- Rules. If key in wavekey as filter then pickslip must have wavekey stamp and loadkey is optional
               --        If key in loadkey as filter then pickslip must have externorderkey stamp and 1 loadkey will not have 2 wavekey
               IF ISNULL( @cWaveKey, '') <> '' AND ISNULL( @cLoadKey, '') <> ''
                  DECLARE CUR_PICKINGINFO CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE WaveKey = @cWaveKey
                  AND   ExternOrderKey = @cLoadKey
                  AND   [Status] = '0'

               IF ISNULL( @cWaveKey, '') <> '' AND ISNULL( @cLoadKey, '') = ''
                  DECLARE CUR_PICKINGINFO CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE WaveKey = @cWaveKey
                  AND   [Status] = '0'

               IF ISNULL( @cWaveKey, '') = '' AND ISNULL( @cLoadKey, '') <> ''               
               -- Rules. If key in loadkey as filter then pickslip must have externorderkey stamp and 1 loadkey will not have 2 wavekey
                  DECLARE CUR_PICKINGINFO CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE ExternOrderKey = @cLoadKey
                  AND   [Status] = '0'

               OPEN CUR_PICKINGINFO
               FETCH NEXT FROM CUR_PICKINGINFO INTO @cPickHeaderKey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  --Check if PickSlipNo exists in pickinginfo
                  IF NOT EXISTS ( SELECT 1
                                  FROM dbo.PickingInfo WITH (NOLOCK)
                                  WHERE PickSlipNo = @cPickHeaderKey)
                  BEGIN
                     INSERT INTO dbo.PickingInfo
                     (PickSlipNo, ScanInDate, PickerID )
                     Values(@cPickHeaderKey, GETDATE(), sUser_sName())

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 69379
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
                        GOTO Step_3_Fail
                     END
                  END   -- Insert pickinginfo
                  ELSE
                  BEGIN
                     UPDATE dbo.PickingInfo WITH (ROWLOCK) SET
                        ScanInDate = GETDATE(),
                        PickerID = sUser_sName()
                     WHERE PickSlipNo = @cPickHeaderKey
                     AND   ScanInDate IS NULL

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 69380
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
                        GOTO Step_3_Fail
                     END   -- Update pickinginfo
                  END

                  FETCH NEXT FROM CUR_PICKINGINFO INTO @cPickHeaderKey
               END
               CLOSE CUR_PICKINGINFO
               DEALLOCATE CUR_PICKINGINFO
            END
         END
      END

      -- This part only for discrete pick slip
      IF EXISTS ( SELECT 1
                  FROM dbo.PickHeader PH WITH (NOLOCK)
                  WHERE PH.PickHeaderKey = @cPickSlipNo    -- SOS# 176144
                  AND ISNULL(RTRIM(PH.ORderkey), '') = '') -- SOS# 176144
      BEGIN
         SET @cPickSlipType = 'CONSO'
      END
      ELSE
      BEGIN
         SET @cPickSlipType = 'SINGLE'
      END

      IF EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK)
                 WHERE LoadKey = @cLoadKey
                 AND LoadPickMethod = 'C')
      BEGIN
         SET @cPickSlipType = 'CONSO'
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
                  BEGIN TRAN

                  INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                  SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo -- SOS# 176144
                  FROM  dbo.PickHeader PH WITH (NOLOCK)
                  JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo
                    AND (( @nMultiStorer = 1 AND O.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND O.StorerKey = @cStorerKey))

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65962
                     SET @cErrMsg = rdt.rdtgetmessage( 65962, @cLangCode, 'DSP') --'InsPHdrFail'
                     ROLLBACK TRAN
                     GOTO Step_3_Fail
                  END

                  COMMIT TRAN
               END
            END
            ELSE  -- IF @cPickSlipType = 'CONSO'
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
               BEGIN
                  BEGIN TRAN

                  INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                  SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', O.StorerKey, @cPickSlipNo
                  FROM  dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
                  JOIN  dbo.LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
                  JOIN  dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                  JOIN  dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo
                    AND (( @nMultiStorer = 1 AND O.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND O.StorerKey = @cStorerKey))

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65974
                     SET @cErrMsg = rdt.rdtgetmessage( 65974, @cLangCode, 'DSP') --'InsPHdrFail'
                     ROLLBACK TRAN
                     GOTO Step_3_Fail
                  END

                  COMMIT TRAN
               END
            END
         END  -- 'InsDiscretePackHdrInfo'
      END   -- 'ClusterPickInsPackDt'

      -- If LoadKey is blank, retrieve respective loadkey (james04)
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      END

      -- (james41)
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @nErrNo = 0
         SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey, ' + 
            ' @cLoc, @cDropID, @cSKU, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParms =    
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' +
            '@nInputKey                 INT,           ' +
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cWaveKey                  NVARCHAR( 10), ' +
            '@cLoadKey                  NVARCHAR( 10), ' +
            '@cOrderKey                 NVARCHAR( 10), ' +
            '@cLoc                      NVARCHAR( 10), ' +
            '@cDropID                   NVARCHAR( 20), ' +
            '@cSKU                      NVARCHAR( 20), ' +
            '@nQty                      INT, '           +
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWaveKey, @cLoadKey, @cOrderKey,  
               @cLoc, @cDropID, @cSKU, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT     

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END
      
      -- If blank OrderKey and at least scanned one OrderKey
      IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLastOrderKey, '') <> ''
      BEGIN
         GOTO Get_PutAwayZone
      END

      -- If blank OrderKey and no scanned OrderKey
      IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLastOrderKey, '') = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
                        JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
                        WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
                           AND (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
                           AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                           AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                           AND PD.Status = '0')
         -- If no task
         BEGIN
            SET @nErrNo = 65913
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No more task'
            GOTO Step_3_Fail
         END

         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
         , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
         SELECT O.UserDefine09, ISNULL(RTRIM(O.LoadKey),''), O.OrderKey, '', O.StorerKey, '', '', O.OrderKey
         , '', '', '1', @cUserName AS UserName, GETDATE(), @cPickSlipNo AS PickSlipNo, @nMobile as Mobile
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) -- (james07) & (james09)
         WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
            AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
            AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
            AND OD.Status >= '1'
            AND OD.Status < '5'
         GROUP BY O.UserDefine09, O.LoadKey, O.OrderKey, O.Storerkey
         GOTO Get_PutAwayZone
      END

      IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                     WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
                     AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                     AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                     AND OrderKey = @cOrderKey
                     AND AddWho = @cUserName
                     AND Status = '1')
      BEGIN
         BEGIN TRAN

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Insert OrderKey scanned to picklock
         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey,
         PutAwayZone, PickZone, PickDetailKey
         , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
         VALUES
         (@cWaveKey, @cLoadKey, @cOrderKey, '*', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
         '', '', @cOrderKey
         , '', '', '1', @cUserName, GETDATE(), @cPickSlipNo, @nMobile)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65910
            SET @cErrMsg = rdt.rdtgetmessage( 65910, @cLangCode, 'DSP') --'LockOrdersFail'
            ROLLBACK TRAN
            GOTO Step_3_Fail
         END

         COMMIT TRAN

         SET @nOrdCount = @nOrdCount + 1
         SET @cLastOrderKey = @cOrderKey

         SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END --WaveKey
         SET @cOutField02 = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN '' ELSE @cLoadKey END --LoadKey
         SET @cOutField03 = ''
         SET @cOutField04 = @cLastOrderKey
         SET @cOutField05 = @nOrdCount
         GOTO Quit
   END
   ELSE
   BEGIN
      SET @nErrNo = 65911
      SET @cErrMsg = rdt.rdtgetmessage( 65911, @cLangCode, 'DSP') --'OrdersAlrdLocked'
      GOTO Step_3_Fail
   END

   GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN Step3_Update

      -- Release orders scanned from RDTPickLock
      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE AddWho = @cUserName
      AND   Status IN ('1', 'X')
      AND   (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
      OPEN CUR_DEL
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK) WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN Step3_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN 

            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL
            SET @nErrNo = 65912
            SET @cErrMsg = rdt.rdtgetmessage( 65912, @cLangCode, 'DSP') --'ReleaseMobFail'
            GOTO Quit
         END
         FETCH NEXT FROM CUR_DEL INTO @nRowRef
      END
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL

      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE ADDWHO = @cUserName 
      AND   PickDetailKey <> ''
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET 
            PickDetailKey = '' 
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN Step3_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN 

            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            SET @nErrNo = 65912
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
            GOTO Quit
         END
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      COMMIT TRAN Step3_Update
      WHILE @@TRANCOUNT > @nTranCount 
            COMMIT TRAN 

      -- Go to prev screen
      SET @nOutScn  = 1871
      SET @nOutStep = 2

      SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END
      SET @cOutField02 = ''

      SET @cLoadKey = ''
   END

   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END --WaveKey
      SET @cOutField02 = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN '' ELSE @cLoadKey END --LoadKey
      SET @cOutField03 = ''
      SET @cOrderKey = ''
   END
   GOTO Quit

   Get_PutAwayZone:
   BEGIN TRAN
   -- If configkey turned on then insert packheader with discrete order information (james10)
   IF rdt.RDTGetConfig( @nFunc, 'InsDiscretePackHdrInfo', @cStorerKey) = '1'
   BEGIN
      DECLARE CUR_INSPACKHDR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT OrderKey FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
         AND AddWho = @cUserName
         AND Status = '1'
      OPEN CUR_INSPACKHDR
      FETCH NEXT FROM CUR_INSPACKHDR INTO @cOrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
         BEGIN
            INSERT INTO dbo.PackHeader
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
            SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, PH.PickHeaderKey
            FROM  dbo.PickHeader PH WITH (NOLOCK)
            JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
            WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
               AND O.OrderKey = @cOrderKey
               AND NOT EXISTS (SELECT 1 FROM dbo.PackHeader PAH WITH (NOLOCK)
                  WHERE PAH.StorerKey = O.StorerKey AND O.OrderKey = PAH.OrderKey)
         END

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69347
            SET @cErrMsg = rdt.rdtgetmessage( 69347, @cLangCode, 'DSP') --'InsPHdrFail'
            ROLLBACK TRAN
            GOTO Step_3_Fail
         END

         FETCH NEXT FROM CUR_INSPACKHDR INTO @cOrderKey
      END
      CLOSE CUR_INSPACKHDR
      DEALLOCATE CUR_INSPACKHDR
   END

   COMMIT TRAN

   -- Clear the output first
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''


   -- Clear the variable first
   SET @nLoop = 0
   SET @cPutAwayZone = ''
   SET @cPutAwayZone01 = ''
   SET @cPutAwayZone02 = ''
   SET @cPutAwayZone03 = ''
   SET @cPutAwayZone04 = ''
   SET @cPutAwayZone05 = ''
   SET @cLastPAZone = '' -- SOS# 237003

   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
      DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT L.PutawayZone
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( L.LocationType = CLK.Code AND PD.StorerKey = CLK.Storerkey AND ListName = 'CLPLOCTYPE')
      WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
         AND (( ISNULL( @cWaveKey, '') = '') OR ( RPL.WaveKey = @cWaveKey))
         AND (( ISNULL(@cLoadKey, '') = '') OR ( RPL.LoadKey = @cLoadKey))
         AND RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND L.Facility = @cFacility
      ORDER BY L.PutawayZone
   ELSE
      DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT L.PutawayZone
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
         AND (( ISNULL( @cWaveKey, '') = '') OR ( RPL.WaveKey = @cWaveKey))
         AND (( ISNULL(@cLoadKey, '') = '') OR ( RPL.LoadKey = @cLoadKey))
         AND RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND L.Facility = @cFacility
      ORDER BY L.PutawayZone

   OPEN curPutAwayZone
   FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nLoop = 0
      BEGIN
         SET @cOutField07 = @cPutAwayZone
         SET @cPutAwayZone01 = @cPutAwayZone
         SET @cOutField15 = @cPutAwayZone -- SOS# 237003
      END
      IF @nLoop = 1
      BEGIN
         SET @cOutField08 = @cPutAwayZone
         SET @cPutAwayZone02 = @cPutAwayZone
         SET @cOutField15 = @cPutAwayZone -- SOS# 237003
      END
      IF @nLoop = 2
      BEGIN
         SET @cOutField09 = @cPutAwayZone
         SET @cPutAwayZone03 = @cPutAwayZone
         SET @cOutField15 = @cPutAwayZone -- SOS# 237003
      END
      IF @nLoop = 3
      BEGIN
         SET @cOutField10 = @cPutAwayZone
         SET @cPutAwayZone04 = @cPutAwayZone
         SET @cOutField15 = @cPutAwayZone -- SOS# 237003
      END
      IF @nLoop = 4
      BEGIN
         SET @cOutField11 = @cPutAwayZone
         SET @cPutAwayZone05 = @cPutAwayZone
         SET @cOutField15 = @cPutAwayZone -- SOS# 237003
      END

      SET @nLoop = @nLoop + 1
      IF @nLoop = 5 BREAK

      FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
   END
   CLOSE curPutAwayZone
   DEALLOCATE curPutAwayZone

   -- If no task
   IF ISNULL(@cOutField07, '') = ''
   BEGIN
      SET @nErrNo = 65913
      SET @cErrMsg = rdt.rdtgetmessage( 65913, @cLangCode, 'DSP') --'No more task'
      GOTO Step_3_Fail
   END

   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField12 = ''
      SET @cFieldAttr01 = 'O'
      SET @cFieldAttr12 = 'O'
   END
   ELSE
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField12 = 'ALL'
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''

   SET @cInField01 = ''
   SET @cInField02 = ''
   SET @cInField03 = ''
   SET @cInField04 = ''
   SET @cInField05 = ''
   SET @cInField06 = ''
   
   -- Go to next screen
   SET @nOutScn  = 1873
   SET @nOutStep = 4

   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 4. Screen = 1873
   ALL     (field01, input)
   PutAwayZone01   (field02, input)
   PutAwayZone03   (field03, input)
   PutAwayZone04   (field04, input)
   PutAwayZone05   (field05, input)
   PutAwayZone06   (field06, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- If blank option selected, retrieve next 5 putawayzone
      IF ISNULL(@cInField01, '') = ''   -- All
      AND ISNULL(@cInField02, '') = ''   -- PutAwayZone01
      AND ISNULL(@cInField03, '') = ''   -- PutAwayZone02
      AND ISNULL(@cInField04, '') = ''   -- PutAwayZone03
      AND ISNULL(@cInField05, '') = ''   -- PutAwayZone04
      AND ISNULL(@cInField06, '') = ''   -- PutAwayZone05
      BEGIN
         GOTO Get_Next5PutAwayZone
      END

      -- If not '1' or blank
     IF (ISNULL(@cInField01, '') <> '' AND @cInField01 <> '1' )   -- All
      OR (ISNULL(@cInField02, '') <> '' AND @cInField02 <> '1' )   -- PutAwayZone01
      OR (ISNULL(@cInField03, '') <> '' AND @cInField03 <> '1' )   -- PutAwayZone02
      OR (ISNULL(@cInField04, '') <> '' AND @cInField04 <> '1' )   -- PutAwayZone03
      OR (ISNULL(@cInField05, '') <> '' AND @cInField05 <> '1' )   -- PutAwayZone04
      OR (ISNULL(@cInField06, '') <> '' AND @cInField06 <> '1' )   -- PutAwayZone05
      BEGIN
         SET @nErrNo = 65914
         SET @cErrMsg = rdt.rdtgetmessage( 65914, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_4_Fail
      END

      -- If non of the option selected
      IF @cInField01 <> '1'   -- All
      AND @cInField02 <> '1'   -- PutAwayZone01
      AND @cInField03 <> '1'   -- PutAwayZone02
      AND @cInField04 <> '1'   -- PutAwayZone03
      AND @cInField05 <> '1'   -- PutAwayZone04
      AND @cInField06 <> '1'   -- PutAwayZone05
      BEGIN
         SET @nErrNo = 65915
         SET @cErrMsg = rdt.rdtgetmessage( 65915, @cLangCode, 'DSP') --No Selection
         GOTO Step_4_Fail
      END

      -- If more than one option selected
      IF (@cInField01 = '1' AND (@cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField02 = '1' AND (@cInField01 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField03 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField04 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField04 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField05 = '1' OR @cInField06 = '1'))
         OR (@cInField05 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField06 = '1'))
         OR (@cInField06 = '1' AND (@cInField01 = '1' OR @cInField02 = '1' OR @cInField03 = '1' OR @cInField04 = '1' OR @cInField05 = '1'))
      BEGIN
         SET @nErrNo = 65916
         SET @cErrMsg = rdt.rdtgetmessage( 65916, @cLangCode, 'DSP') --Only1ZoneAllow
         GOTO Step_4_Fail
      END

      IF @cInField01 = '1'
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN Step4_Update

         SET @cPutAwayZone = 'ALL'

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE Status = '1'
         AND   AddWho = @cUserName
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET 
               PutAwayZone = @cPutAwayZone
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN Step4_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               SET @nErrNo = 65917
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPWZoneFail'
               GOTO Step_4_Fail
            END
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         COMMIT TRAN Step4_Update
         WHILE @@TRANCOUNT > @nTranCount 
               COMMIT TRAN 
      END
      ELSE
      BEGIN
         IF ISNULL(@cInField02, '') = '1'
            SET @cPutAwayZone = @cOutField07

         IF ISNULL(@cInField03, '') = '1'
            SET @cPutAwayZone = @cOutField08

         IF ISNULL(@cInField04, '') = '1'
            SET @cPutAwayZone = @cOutField09

         IF ISNULL(@cInField05, '') = '1'
            SET @cPutAwayZone = @cOutField10

         IF ISNULL(@cInField06, '') = '1'
            SET @cPutAwayZone = @cOutField11

         BEGIN TRAN

         -- Update only respective orders with putawayzone
         UPDATE RPL WITH (ROWLOCK) SET
            RPL.PutAwayZone = @cPutAwayZone
         FROM RDT.RDTPickLock RPL
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey) -- (Vicky01)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC) -- (Vicky01)
         WHERE RPL.Status = '1'
            AND RPL.AddWho = @cUserName
            AND (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
            AND PD.Status = '0'
            AND L.Facility = @cFacility
            AND L.PutAwayZone = @cPutAwayZone

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65918
            SET @cErrMsg = rdt.rdtgetmessage( 65918, @cLangCode, 'DSP') --'UPDPWZoneFail'
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END

         COMMIT TRAN
      END

      -- If there exists any handheld has been idle more than allowable time, release locking
      IF CAST(@cAllowableIdleTime AS INT) > 0
      BEGIN
         SET @curReleaseLock = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT MOBILE FROM RDT.RDTMobRec WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND DATEDIFF(HH, EditDate, GETDATE()) >= CAST(@cAllowableIdleTime AS INT)
            AND Step > 0
         OPEN @curReleaseLock
         FETCH NEXT FROM @curReleaseLock INTO @nRDTMobile
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN

            UPDATE RDT.RDTMobRec WITH (ROWLOCK) SET
            Scn = 0, Step = 0, Menu = 0, Func = 0
            WHERE Mobile = @nRDTMobile

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65919
               SET @cErrMsg = rdt.rdtgetmessage( 65919, @cLangCode, 'DSP') --'ReleaseMobFail'
               ROLLBACK TRAN
               CLOSE @curReleaseLock
               DEALLOCATE @curReleaseLock
               GOTO Step_4_Fail
            END

            DELETE RPL
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN RDT.RDTMobRec RMB WITH (NOLOCK) ON (RPL.StorerKey = RMB.StorerKey AND RPL.AddWho = RMB.UserName)
            WHERE RMB.Mobile = @nRDTMobile
               AND (( @nMultiStorer = 1) OR ( RMB.StorerKey = @cStorerKey))
               AND RPL.Status < '9'

            IF @@ERROR <> 0
               BEGIN
               SET @nErrNo = 65920
               SET @cErrMsg = rdt.rdtgetmessage( 65920, @cLangCode, 'DSP') --'ReleaseMobFail'
               ROLLBACK TRAN
               CLOSE @curReleaseLock
               DEALLOCATE @curReleaseLock
               GOTO Step_4_Fail
            END

            COMMIT TRAN

            FETCH NEXT FROM @curReleaseLock INTO @nRDTMobile
         END
         CLOSE @curReleaseLock
         DEALLOCATE @curReleaseLock
      END

      -- Prep next screen var
      SET @cOutField01 = '' --Pick Zone

      -- Go to next screen
      SET @nOutScn  = 1874
      SET @nOutStep = 5

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

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Release lock
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN Step4_Update

      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
      AND   AddWho = @cUserName
      AND   Status IN ('1', 'X')
      OPEN CUR_DEL
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK) WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN Step4_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN 

            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL
            SET @nErrNo = 65921
            SET @cErrMsg = rdt.rdtgetmessage( 65921, @cLangCode, 'DSP') --'ReleaseMobFail'
            GOTO Quit
         END

         FETCH NEXT FROM CUR_DEL INTO @nRowRef
      END
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL

      COMMIT TRAN Step4_Update
      WHILE @@TRANCOUNT > @nTranCount 
            COMMIT TRAN 

      SET @cLastOrderKey = ''
      SET @nOrdCount = ''
      SET @cOrderKey = '' -- SOS# 307304

      SET @cOutField01 = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN '' ELSE @cWaveKey END --WaveKey
      SET @cOutField02 = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN '' ELSE @cLoadKey END --LoadKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      -- Go to Prev screen
      SET @nOutScn  = 1872
      SET @nOutStep = 3

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

   Step_4_Fail:
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr01 = 'O'
         SET @cFieldAttr12 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField12 = 'ALL'
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END

      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      GOTO Quit
   END

   Get_Next5PutAwayZone:
   BEGIN
      SET @nZoneCount = 0
      SET @cLastPAZone = @cOutField15 -- SOS# 237003

      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
         SELECT @nZoneCount = COUNT(LOC.PutawayZone)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK)
            ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (james09)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( LOC.LocationType = CLK.Code AND PD.StorerKey = CLK.Storerkey AND ListName = 'CLPLOCTYPE')
         WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
            AND PD.Status = '0'
            AND EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK)
                                 WHERE Status = '1'
                                 AND OrderKey = PD.OrderKey
                                 AND Storerkey = PD.StorerKey
                                 AND AddWho = @cUserName)
            AND LOC.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)
            AND LOC.PutawayZone > @cLastPAZone -- SOS# 237003
      ELSE
         SELECT @nZoneCount = COUNT(LOC.PutawayZone)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK)
            ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (james09)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
            AND PD.Status = '0'
            AND EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK)
                                 WHERE Status = '1'
                                 AND OrderKey = PD.OrderKey
                                 AND Storerkey = PD.StorerKey
                                 AND AddWho = @cUserName)
            AND LOC.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)
            AND LOC.PutawayZone > @cLastPAZone -- SOS# 237003

      -- If no task
      IF @nZoneCount = 0
      BEGIN
         SET @nErrNo = 65922
         SET @cErrMsg = rdt.rdtgetmessage( 65922, @cLangCode, 'DSP') --'No more PWZone'
         GOTO Step_4_Fail
      END

      -- Clear the variable first
      SET @nLoop = 0
      SET @cPutAwayZone = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LOC.PutawayZone 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK)
            ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    -- (james09)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( LOC.LocationType = CLK.Code AND PD.StorerKey = CLK.Storerkey AND ListName = 'CLPLOCTYPE')
         WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
            AND PD.Status = '0'
            AND EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK)
                                 WHERE Status = '1'
                                 AND OrderKey = PD.OrderKey
                                 AND Storerkey = PD.StorerKey--@cStorerKey
                                 AND AddWho = @cUserName)      -- tlting03
            AND LOC.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)
            AND LOC.PutawayZone > @cLastPAZone -- SOS# 237003
         ORDER BY LOC.PutawayZone
      ELSE
         DECLARE curPutAwayZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LOC.PutawayZone 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK)
            ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    -- (james09)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
            AND PD.Status = '0'
            AND EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK)
                                 WHERE Status = '1'
                                 AND OrderKey = PD.OrderKey
                                 AND Storerkey = PD.StorerKey--@cStorerKey
                                 AND AddWho = @cUserName)      -- tlting03
            AND LOC.PutawayZone NOT IN (@cPutAwayZone01, @cPutAwayZone02, @cPutAwayZone03, @cPutAwayZone04, @cPutAwayZone05)
            AND LOC.PutawayZone > @cLastPAZone -- SOS# 237003
         ORDER BY LOC.PutawayZone
      OPEN curPutAwayZone
      FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 0
         BEGIN
            SET @cOutField07 = @cPutAwayZone
            SET @cPutAwayZone01 = @cPutAwayZone
            SET @cOutField15 = @cPutAwayZone -- SOS# 237003
         END
         IF @nLoop = 1
         BEGIN
            SET @cOutField08 = @cPutAwayZone
            SET @cPutAwayZone02 = @cPutAwayZone
            SET @cOutField15 = @cPutAwayZone -- SOS# 237003
         END
         IF @nLoop = 2
         BEGIN
            SET @cOutField09 = @cPutAwayZone
            SET @cPutAwayZone03 = @cPutAwayZone
            SET @cOutField15 = @cPutAwayZone -- SOS# 237003
         END
         IF @nLoop = 3
         BEGIN
            SET @cOutField10 = @cPutAwayZone
            SET @cPutAwayZone04 = @cPutAwayZone
            SET @cOutField15 = @cPutAwayZone -- SOS# 237003
         END
         IF @nLoop = 4
         BEGIN
            SET @cOutField11 = @cPutAwayZone
            SET @cPutAwayZone05 = @cPutAwayZone
            SET @cOutField15 = @cPutAwayZone -- SOS# 237003
         END

         SET @nLoop = @nLoop + 1
         IF @nLoop = 5 BREAK

         FETCH NEXT FROM curPutAwayZone INTO @cPutAwayZone
      END
      CLOSE curPutAwayZone
      DEALLOCATE curPutAwayZone

      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @cStorerKey)
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr01 = 'O'
         SET @cFieldAttr12 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField12 = 'ALL'
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END

      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      SET @cPutAwayZone01 = CASE WHEN ISNULL(@cOutField07, '') = '' THEN '' ELSE @cPutAwayZone01 END
      SET @cPutAwayZone02 = CASE WHEN ISNULL(@cOutField08, '') = '' THEN '' ELSE @cPutAwayZone02 END
      SET @cPutAwayZone03 = CASE WHEN ISNULL(@cOutField09, '') = '' THEN '' ELSE @cPutAwayZone03 END
      SET @cPutAwayZone04 = CASE WHEN ISNULL(@cOutField10, '') = '' THEN '' ELSE @cPutAwayZone04 END
      SET @cPutAwayZone05 = CASE WHEN ISNULL(@cOutField11, '') = '' THEN '' ELSE @cPutAwayZone05 END

      -- SOS# 237003 (Start)
      IF ISNULL(RTRIM(@cPutAwayZone01),'') = ''
      BEGIN
         SET @cOutField15 = ''
      END

      IF ISNULL(RTRIM(@cPutAwayZone02),'') = ''
      BEGIN
         SET @cOutField15 = ''
      END

      IF ISNULL(RTRIM(@cPutAwayZone03),'') = ''
      BEGIN
         SET @cOutField15 = ''
      END

      IF ISNULL(RTRIM(@cPutAwayZone04),'') = ''
      BEGIN
         SET @cOutField15 = ''
      END

      IF ISNULL(RTRIM(@cPutAwayZone05),'') = ''
      BEGIN
         SET @cOutField15 = ''
      END
      -- SOS# 237003 (End)

      GOTO Quit
   END
END
GOTO Quit
        
END
Quit:

GO