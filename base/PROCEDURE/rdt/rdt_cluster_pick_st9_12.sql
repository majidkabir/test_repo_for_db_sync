SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_St9_12                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick step9 - step12                                 */
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

CREATE PROC [RDT].[rdt_Cluster_Pick_St9_12] (
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
   @cNewOrderKey   NVARCHAR( 10),
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
   IF @nStep = 9   GOTO Step_9 -- Scn = 1878, 1884, 1889. Confirm Short Pick
   IF @nStep = 10  GOTO Step_10 -- Scn = 1879. Picking completed
   IF @nStep = 11  GOTO Step_11 -- Scn = 1880. Exit Picking
   IF @nStep = 12  GOTO Step_12 -- Scn = 1881. Confirm Short Pick/Cancel Pick
END

/********************************************************************************
Step 9. Screen = 1878, 1884
   Option     (field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField01

      --if input is not either '1' or '2' OR '3'
      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 65944
         SET @cErrMsg = rdt.rdtgetmessage( 65944, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_9_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- (james36)
         IF rdt.RDTGetConfig( @nFunc, 'NOTALLOWSHORTPICK', @cStorerKey) = 1
         BEGIN
            SET @nErrNo = 69387
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SHPICK X ALLOW
            GOTO Step_9_Fail
         END

         -- (james18)
         Confirm_Skip_SKU:

         SET @cSHOWSHTPICKRSN = rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey)

         IF @cSHOWSHTPICKRSN = '1'
         BEGIN
            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

            SELECT @nShortPickedQty = PickQty
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cLOC
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))

            SELECT
               @cPackUOM3 = P.PACKUOM3
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
               AND SKU.SKU = @cSKU

            SET @cOutField01 = @nShortPickedQty -- cluster picking, this is short picked qty
            SET @cOutField02 = @cPackUOM3 -- cluster picking
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''

            -- Save current screen no
            SET @nCurScn = @nInScn
            SET @nCurStep = @nInStep

            -- Go to STD short pick screen
            SET @nOutScn = 2010
            SET @nOutStep = @nStep + 5

            GOTO Quit
         END
         ELSE
         BEGIN
            IF  @cLoadDefaultPickMethod <> 'C' -- SOS# 176144
            BEGIN
               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

               -- Insert the short picked qty   SOS131967
               IF NOT EXISTS (SELECT 1
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
                  AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND Status = '1'
                  AND AddWho = @cUserName
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                  AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                  AND SKU = @cSKU
                  AND PickQty = 0)
               BEGIN

                  BEGIN TRAN
                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, 
                  Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, PickQty, Mobile)
                  SELECT TOP 1 WaveKey, LoadKey, Orderkey, '****' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, 
                  Lottable02, Lottable04, Status, AddWho, AddDate, '' AS DropID, @cPickSlipNo AS PickSlipNo, 0, @nMobile
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                     AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                     AND Status = '1'
                     AND AddWho = @cUserName
                     AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                     AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                     AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                     AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                     AND SKU = @cSKU

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65964
                     SET @cErrMsg = rdt.rdtgetmessage( 65964, @cLangCode, 'DSP') --'INSTPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE -- SOS# 176144
                  BEGIN
                     COMMIT TRAN
                  END
               END
            END

            IF @cLoadDefaultPickMethod = 'C'
            BEGIN --SOS# 176144 (Start)
               -- Insert the short picked qty   SOS131967
               IF NOT EXISTS (SELECT 1
                              FROM RDT.RDTPickLock WITH (NOLOCK)
                              WHERE Status = '1'
                              AND StorerKey = @cStorerKey   --tlting03
                              AND AddWho = @cUserName
                              AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                              AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                              AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                              AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                              AND SKU = @cSKU
                              AND PickQty = 0)
               BEGIN
                  BEGIN TRAN
                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, 
                  Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, PickQty, Mobile)
                  SELECT TOP 1 WaveKey, LoadKey, Orderkey, '****' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, 
                  Lottable02, Lottable04, Status, AddWho, AddDate, '' AS DropID, @cPickSlipNo AS PickSlipNo, 0, @nMobile
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE Status = '1'
                     AND StorerKey = @cStorerKey   --tlting03
                     AND AddWho = @cUserName
                     AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                     AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                     AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                     AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                     AND SKU = @cSKU

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65964
                     SET @cErrMsg = rdt.rdtgetmessage( 65964, @cLangCode, 'DSP') --'INSTPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END --SOS# 176144 (End)

               -- 1.0 Confirm pick first
               DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT OrderKey FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND LoadKey = @cLoadKey
               AND SKU = @cSKU
               AND PickQty > 0
               OPEN CUR_LOOK4CONSO_ORDERS
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  BEGIN TRAN --SOS# 176144
                  SET @nErrNo = 0
                  SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                  IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                  BEGIN
                     SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                        ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                        ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                     SET @cSQLParms =    
                        '@nMobile                   INT,           ' +
                        '@nFunc                     INT,           ' +
                        '@cLangCode                 NVARCHAR( 3),  ' +
                        '@nStep                     INT,           ' +
                        '@nInputKey                 INT,           ' +
                        '@cFacility                 NVARCHAR( 5),  ' +
                        '@cStorerkey                NVARCHAR( 15), ' +
                        '@cWaveKey                  NVARCHAR( 10), ' +
                        '@cLoadKey                  NVARCHAR( 10), ' +
                        '@cOrderKey                 NVARCHAR( 10), ' +
                        '@cPutAwayZone              NVARCHAR( 10), ' +
                        '@cPickZone                 NVARCHAR( 10), ' +
                        '@cSKU                      NVARCHAR( 20), ' +
                        '@cPickSlipNo               NVARCHAR( 10), ' +
                        '@cLOT                      NVARCHAR( 10), ' +
                        '@cLOC                      NVARCHAR( 10), ' +
                        '@cDropID                   NVARCHAR( 20), ' +
                        '@cStatus                   NVARCHAR( 1),  ' +
                        '@cCartonType               NVARCHAR( 10), ' +
                        '@nErrNo                    INT           OUTPUT,  ' +
                        '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                     EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                        @cWaveKey, @cLoadKey, @cConso_Orders, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                        @cLOT, @cLOC, @cDropID, '5', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  END
                  ELSE
                  BEGIN
                     EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                        @cStorerKey,
                        @cUserName,
                        @cFacility,
                        @cPutAwayZone,
                        @cPickZone,
                        @cConso_Orders,   -- Set orderkey = '' as conso pick
                        @cSKU,
                        @cPickSlipNo,
                        @cLOT,
                        @cLOC,
                        @cDropID,
                        '5',
                        @cLangCode,
                        @nErrNo        OUTPUT,
                        @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                        @nMobile, -- (Vicky06)
                        @nFunc    -- (Vicky06)
                  END

                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN
                     CLOSE CUR_LOOK4CONSO_ORDERS
                     DEALLOCATE CUR_LOOK4CONSO_ORDERS
                     GOTO Step_9_Fail
                  END
                  ELSE -- SOS# 176144
                  BEGIN
                     COMMIT TRAN
                  END
                  FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
               END
               CLOSE CUR_LOOK4CONSO_ORDERS
               DEALLOCATE CUR_LOOK4CONSO_ORDERS

               -- 2.0 Short pick the rest
               DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT OrderKey FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND LoadKey = @cLoadKey
               AND SKU = @cSKU
               AND PickQty = 0
               OPEN CUR_LOOK4CONSO_ORDERS
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  BEGIN TRAN --SOS# 176144

                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmSkipSKU', @cStorerKey) = '1'
                  BEGIN
                     SET @nErrNo = 0
                     SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                     IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                     BEGIN
                        SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                           ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                           ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParms =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cLOT                      NVARCHAR( 10), ' +
                           '@cLOC                      NVARCHAR( 10), ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cStatus                   NVARCHAR( 1),  ' +
                           '@cCartonType               NVARCHAR( 10), ' +
                           '@nErrNo                    INT           OUTPUT,  ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                        EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cConso_Orders, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                           @cLOT, @cLOC, @cDropID, '0', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                     END
                     ELSE
                     BEGIN
                        EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                           @cStorerKey,
                           @cUserName,
                           @cFacility,
                           @cPutAwayZone,
                           @cPickZone,
                           @cConso_Orders,   -- Set orderkey = '' as conso pick
                           @cSKU,
                           @cPickSlipNo,
                           @cLOT,
                           @cLOC,
                           @cDropID,
                           '0',
                           @cLangCode,
                           @nErrNo        OUTPUT,
                           @cErrMsg     OUTPUT,  -- screen limitation, 20 NVARCHAR max
                           @nMobile, -- (Vicky06)
                           @nFunc    -- (Vicky06)
                     END
                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 0
                     SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                     IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                     BEGIN
                        SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                           ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                           ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParms =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cLOT                      NVARCHAR( 10), ' +
                           '@cLOC                      NVARCHAR( 10), ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cStatus                   NVARCHAR( 1),  ' +
                           '@cCartonType               NVARCHAR( 10), ' +
                           '@nErrNo                    INT           OUTPUT,  ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                        EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cConso_Orders, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                           @cLOT, @cLOC, @cDropID, '4', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                     END
                     ELSE
                     BEGIN
                        EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                           @cStorerKey,
                           @cUserName,
                           @cFacility,
                           @cPutAwayZone,
                           @cPickZone,
                           @cConso_Orders,   -- Set orderkey = '' as conso pick
                           @cSKU,
                           @cPickSlipNo,
                           @cLOT,
                           @cLOC,
                           @cDropID,
                           '4',
                           @cLangCode,
                           @nErrNo        OUTPUT,
                           @cErrMsg     OUTPUT,  -- screen limitation, 20 NVARCHAR max
                           @nMobile, -- (Vicky06)
                           @nFunc    -- (Vicky06)
                     END

                     IF @nErrNo <> 0
                     BEGIN
                        ROLLBACK TRAN
                        CLOSE CUR_LOOK4CONSO_ORDERS
                        DEALLOCATE CUR_LOOK4CONSO_ORDERS
                        GOTO Step_9_Fail
                     END
                     ELSE -- SOS# 176144
                     BEGIN
                        COMMIT TRAN
                     END
                     FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
                     END
                     CLOSE CUR_LOOK4CONSO_ORDERS
                     DEALLOCATE CUR_LOOK4CONSO_ORDERS
                  END
               END
               ELSE
               BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmSkipSKU', @cStorerKey) = '1'
               BEGIN
                  IF @cOption = '1' -- (james28)
                  BEGIN
                     SET @nErrNo = 0
                     SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                     IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                     BEGIN
                        SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                           ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                           ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParms =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cLOT                      NVARCHAR( 10), ' +
                           '@cLOC                      NVARCHAR( 10), ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cStatus                   NVARCHAR( 1),  ' +
                           '@cCartonType               NVARCHAR( 10), ' +
                           '@nErrNo                    INT           OUTPUT,  ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                        EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                           @cLOT, @cLOC, @cDropID, '4', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                     END
                     ELSE
                     BEGIN
                        EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                           @cStorerKey,
                           @cUserName,
                           @cFacility,
                           @cPutAwayZone,
                           @cPickZone,
                           @cOrderKey,
                           @cSKU,
                           @cPickSlipNo,
                           @cLOT,
                           @cLOC,
                           @cDropID,
                           '4',  -- Pick in progress
                           @cLangCode,
                           @nErrNo        OUTPUT,
                           @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                           @nMobile, -- (Vicky06)
                           @nFunc    -- (Vicky06)
                     END
                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 0
                     SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                     IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                     BEGIN
                        SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                           ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                           ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParms =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cLOT                      NVARCHAR( 10), ' +
                           '@cLOC                      NVARCHAR( 10), ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cStatus                   NVARCHAR( 1),  ' +
                           '@cCartonType               NVARCHAR( 10), ' +
                           '@nErrNo                    INT           OUTPUT,  ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                        EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                           @cLOT, @cLOC, @cDropID, '0', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                     END
                     ELSE
                     BEGIN
                        EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                           @cStorerKey,
                           @cUserName,
                           @cFacility,
                           @cPutAwayZone,
                           @cPickZone,
                           @cOrderKey,
                           @cSKU,
                           @cPickSlipNo,
                           @cLOT,
                           @cLOC,
                           @cDropID,
                           '0',  -- Pick in progress
                           @cLangCode,
                           @nErrNo        OUTPUT,
                           @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                           @nMobile, -- (Vicky06)
                           @nFunc    -- (Vicky06)
                  END
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 0

               SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
               IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
               BEGIN
                  SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                     ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                     ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                  SET @cSQLParms =    
                     '@nMobile                   INT,           ' +
                     '@nFunc                     INT,           ' +
                     '@cLangCode                 NVARCHAR( 3),  ' +
                     '@nStep                     INT,           ' +
                     '@nInputKey                 INT,           ' +
                     '@cFacility                 NVARCHAR( 5),  ' +
                     '@cStorerkey                NVARCHAR( 15), ' +
                     '@cWaveKey                  NVARCHAR( 10), ' +
                     '@cLoadKey                  NVARCHAR( 10), ' +
                     '@cOrderKey                 NVARCHAR( 10), ' +
                     '@cPutAwayZone              NVARCHAR( 10), ' +
                     '@cPickZone                 NVARCHAR( 10), ' +
                     '@cSKU                      NVARCHAR( 20), ' +
                     '@cPickSlipNo               NVARCHAR( 10), ' +
                     '@cLOT                      NVARCHAR( 10), ' +
                     '@cLOC                      NVARCHAR( 10), ' +
                     '@cDropID                   NVARCHAR( 20), ' +
                     '@cStatus                   NVARCHAR( 1),  ' +
                     '@cCartonType               NVARCHAR( 10), ' +
                     '@nErrNo                    INT           OUTPUT,  ' +
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                  EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                     @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                     @cLOT, @cLOC, @cDropID, '4', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
               END
               ELSE
               BEGIN
                  EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                     @cStorerKey,
                     @cUserName,
                     @cFacility,
                     @cPutAwayZone,
                     @cPickZone,
                     @cOrderKey,
                     @cSKU,
                     @cPickSlipNo,
                     @cLOT,
                     @cLOC,
                     @cDropID,
                     '4',  -- Pick in progress
                     @cLangCode,
                     @nErrNo        OUTPUT,
                     @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                     @nMobile, -- (Vicky06)
                     @nFunc    -- (Vicky06)
               END
            END

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_9_Fail
            END
            ELSE
            BEGIN
               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                  -- SOS172041
                  -- If SKU.SUSR4 setup with L'Oreal Anti-Diversion code
                  -- Use codelkup to determine whether we need to capture serial no (james20)
                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1'
                  BEGIN
                     SET @nCount = 0   -- (james27)
                     SET @cSKUFieldName = rdt.RDTGetConfig( @nFunc, 'FieldName2CaptureSerialNo', @cStorerKey)
                     IF ISNULL(@cSKUFieldName, '') NOT IN ('', '0')
                     BEGIN
                        IF NOT EXISTS(SELECT 1 FROM SYS.COLUMNS
                                      WHERE NAME = @cSKUFieldName
                                      AND   OBJECT_ID = OBJECT_ID(N'SKU'))
                        BEGIN
                           SET @nErrNo = 69378
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad SKU Field'
                           ROLLBACK TRAN A
                           GOTO Step_9_Fail
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
                              WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                              AND   SKU = @cSKU
                              AND   SUSR4 = 'AD' )
                     BEGIN
                        SELECT @nOtherUnit2 = OtherUnit2 FROM Pack P WITH (NOLOCK)
                        JOIN SKU S WITH (NOLOCK) ON (P.PackKey = S.PackKey)
                        WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                           AND SKU = @cSKU

                        IF @nOtherUnit2 <= 0
                        BEGIN
                           SET @nErrNo = 69349
                           SET @cErrMsg = rdt.rdtgetmessage( 69349, @cLangCode, 'DSP') --'LockOrdersFail'
                           --  ROLLBACK TRAN  -- ang02
                           GOTO Step_9_Fail
                        END

                        SELECT @nSum_PickQty = ISNULL(SUM(PickQty), 0) FROM RDT.RDTPickLock WITH (NOLOCK)
                        WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                           AND OrderKey = @cOrderKey
                           AND SKU = @cSKU
                           AND LOT = @cLOT
                           AND LOC = @cLOC
                           AND AddWho = @cUserName
                           AND Status = '5'
                           AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                           AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))

                        SELECT @nCount_SerialNo = Count(1) FROM dbo.SerialNo WITH (NOLOCK)
                        WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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

                              SET @nCurScn = @nInScn  -- remember current screen no
                              SET @nCurStep = @nInStep  -- remember current step no

                              -- Go to Anti-Diversion code screen
                              SET @nOutScn  = 1891
                              SET @nOutStep = 17

                              GOTO Quit
                           END
                        END   -- @nOtherUnit2 > 0
                     END   -- PICKSERIAL
                  END
               END
            END

            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               SELECT TOP 1
                  @cLOC = PD.Loc,
                  @cSKU = PD.SKU,
                  @cLottable02 = LA.Lottable02,
                  @dLottable04 = LA.Lottable04
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK)
                  ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  -- (james09)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE O.StorerKey = @cStorerKey -- tlting03
                  AND PD.Status = '0'
                  AND O.LoadKey = @cLoadKey
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                  AND LOC.Facility = @cFacility
                  AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                     WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')
               GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
               ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

               -- No more task
               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT
                     @nOrderPicked   = COUNT(DISTINCT OrderKey),
                     @nTTL_PickedQty = SUM(PickQty)
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE AddWho = @cUserName
                     AND Status = '5'  -- Picked
                     AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                     AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                     AND StorerKey = @cStorerKey

                  -- (james36)
                  SET @cPickNotFinish = ''
                  IF rdt.RDTGetConfig( @nFunc, 'DISPLAYPICKNOTFINISH', @cStorerKey) = 1
                  BEGIN
                     IF EXISTS ( SELECT 1 from dbo.PickDetail PD WITH (NOLOCK)
                                 JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                                 JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
                                 JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                                 WHERE PD.StorerKey = @cStorerKey
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
                     BEGIN TRAN --SOS# 176144
                     UPDATE RDT.RDTPickLock with (ROWLOCK) SET
                        Status = '9'   -- Confirm Picked
                     WHERE RowRef = @nRowRef

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 65942
                        SET @cErrMsg = rdt.rdtgetmessage( 65942, @cLangCode, 'DSP') --'UPDPKLockFail'
                        ROLLBACK TRAN
                        GOTO Step_9_Fail
                     END
                     ELSE -- SOS# 176144
                     BEGIN
                        COMMIT TRAN
                     END

                     FETCH NEXT FROM @curUpdRPL INTO @nRowRef
                  END
                  CLOSE @curUpdRPL
                  DEALLOCATE @curUpdRPL

                  -- Commit the transaction before goto picking screen
                  --COMMIT TRAN --SOS# 176144

                  GOTO Quit
               END   -- IF @@ROWCOUNT = 0
               ELSE
               BEGIN
                  SELECT
                     @cSKU_Descr = SKU.DESCR,
                     @cStyle = SKU.Style,
                     @cColor = SKU.Color,
                     @cSize = SKU.Size,
                     @cColor_Descr = SKU.BUSR7
                  FROM dbo.SKU SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

                  IF rdt.RDTGetConfig( @nFunc, 'ReplaceDescrWithColorSize', @cStorerKey) = 1
                  BEGIN
                     SET @cColor_Descr = SUBSTRING( @cSKU_Descr, 1, 20)
                     SET @cColor = @cColor + ' '
                     SET @cSKU_Descr = ''
                  END

                  DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PD.ORDERKEY, PD.LOT
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) --SOS# 176144
                  JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
                  WHERE LA.StorerKey = @cStorerKey    -- tlting03
                     AND PD.STATUS = '0'
                     AND PD.LOC = @cLOC
                     AND LA.SKU = @cSKU
                     AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                     AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                     AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                     AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  OPEN CUR_LOOK4CONSO_ORDERS
                  FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                                    AND OrderKey = @cConso_Orders
                                    AND Status = '1'
                                    AND LOT = @cLOT
                                    AND AddWho = @cUserName)
                     BEGIN
                        BEGIN TRAN --SOS# 176144
                        INSERT INTO RDT.RDTPickLock
                        (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                        , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
                        VALUES
                        (@cWaveKey, @cLoadKey, @cConso_Orders, 'C', @cStorerKey, @cSKU, @cPutAwayZone, @cPickZone, @cConso_Orders
                        , @cLOT, @cLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 65980
                           SET @cErrMsg = rdt.rdtgetmessage( 65980, @cLangCode, 'DSP') --'LockOrdersFail'
                           ROLLBACK TRAN
                           GOTO Step_9_Fail
                        END
                        ELSE -- SOS# 176144
                        BEGIN
                           COMMIT TRAN
                        END
                     END
                     ELSE
                     BEGIN
                        BEGIN TRAN --SOS# 176144
                        UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                           LOT = @cLot,
                           LOC = @cLoc,
                           SKU = @cSKU,
                           DropID = @cDropID,
                           PackKey = @cCartonType,                           
                           Lottable02 = @cLottable02,
                           Lottable04 = @dLottable04
                         , OrderLineNumber = OrderLineNumber + 'CC'
                        WHERE OrderKey = @cConso_Orders
                           AND StorerKey = @cStorerKey    -- tlting03
                           AND Status = '1'
                           AND AddWho = @cUserName

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 65981
                           SET @cErrMsg = rdt.rdtgetmessage( 65981, @cLangCode, 'DSP') --'UPDPKLockFail'
                           ROLLBACK TRAN
                           GOTO Step_9_Fail
                        END
                        ELSE -- SOS# 176144
                        BEGIN
                           COMMIT TRAN
                        END
                     END

                     FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
                  END
                  CLOSE CUR_LOOK4CONSO_ORDERS
                  DEALLOCATE CUR_LOOK4CONSO_ORDERS
               END

               SELECT @nTTL_Qty = SUM(PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) --ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey)
               JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.Status = '0'
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
                  AND L.Facility = @cFacility
                  AND LA.Storerkey = @cStorerKey      -- tlting03
                  AND LA.SKU = @cSKU
                  AND L.LOC = @cLOC
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)
                  -- TLTING03 Duplicate check
                  --AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = PD.StorerKey
                  --               AND OrderKey = PD.OrderKey AND ADDWHO = @cUserName ) -- SOS# 176144
                  --AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) -- SOS# 176144

               -- Get the total allocated qty for LOC + SKU + OrderKey
               SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.Status = '0'
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)

               SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
               IF CAST(@cDefaultPickQty AS INT) <= 0 SET @cDefaultPickQty = ''

               IF @cDefaultToAllocatedQty = '1'
               BEGIN
                  SET @cDefaultPickQty = @nTotalPickQty
               END

               SET @nQtyToPick = 0
               SET @nActQty = 0

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
                                          THEN @cTemp_String
                                          ELSE @cColor_Descr END
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
               IF @nFunc = 1828 -- (james07)
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

               -- Commit transaction
               -- COMMIT TRAN   ang02

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

               GOTO Quit
            END   -- IF @cLoadDefaultPickMethod = 'C'
            ELSE
            BEGIN
               -- Get next available task
               SET @nErrNo = 0

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
                  SET @cNewOrderKey    = @c_oFieled02
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
                     @cNewOrderKey     OUTPUT,
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
                     SET @nErrNo = 65945
                     SET @cErrMsg = rdt.rdtgetmessage( 65945, @cLangCode, 'DSP') --'GetNextTaskFail'
                     GOTO Step_9_Fail
                  END
               END
            END

            -- If no more task, goto confirm picking screen
            IF ISNULL(@cNewOrderKey, '') = ''
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'AutoCloseCaseIfLastCarton', @cStorerKey) = '1'
               BEGIN
                  -- Insert into DropID table   (james30)
                  IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
                  BEGIN
                     SET @nErrNo = 0
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
                        'U',      -- U = Update
                        @cLangCode,
                        @nErrNo        OUTPUT,
                        @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

                     IF @nErrNo <> 0
                        GOTO Step_9_Fail
                  END

                  SET @nErrNo = 0
                  EXECUTE RDT.rdt_Cluster_Pick_PrintLabel
                     @nMobile, 
                     @nFunc, 
                     @nStep, 
                     @nInputKey, 
                     @cLangCode,
                     @cStorerKey,
                     @cWaveKey,
                     @cLoadKey,
                     @cOrderKey,
                     @cPickSlipNo,
                     @cLOC,
                     @cDropID,
                     @cSKU,
                     @nQty,
                     @nErrNo   OUTPUT,
                     @cErrMsg  OUTPUT
   
                  IF @nErrNo <> 0
                     GOTO Step_9_Fail
               END

               -- (jamesxx)
               SELECT
                  @nOrderPicked = COUNT( DISTINCT OrderKey),
                  @nTTL_PickedQty = SUM(PickQty)
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE AddWho = @cUserName
                  AND Status = '5'  -- Picked
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                  AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))

               -- Confirm picking in RDT.RDTPickLock
               SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                  AND AddWho = @cUserName
                  AND Status = '5'
               OPEN @curUpdRPL
               FETCH NEXT FROM @curUpdRPL INTO @nRowRef
               WHILE @@FETCH_STATUS <> -1
               BEGIN

                  BEGIN TRAN --SOS# 176144
                  UPDATE RDT.RDTPickLock with (ROWLOCK) SET
                  Status = '9'   -- Confirm Picked
                  WHERE RowRef = @nRowRef

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65946
                     SET @cErrMsg = rdt.rdtgetmessage( 65946, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE -- SOS# 176144
                  BEGIN
                     COMMIT TRAN
                  END

                  FETCH NEXT FROM @curUpdRPL INTO @nRowRef
               END
               CLOSE @curUpdRPL
               DEALLOCATE @curUpdRPL

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

               GOTO Quit
            END

            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cNewOrderKey

            -- Get the Lottables
            SELECT
               @cLottable02 = Lottable02,
               @dLottable04 = Lottable04
            FROM dbo.LotAttribute WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND SKU = @cSKU
               AND LOT = @cLot

            BEGIN TRAN --SOS# 176144
            -- Insert next task to picklock
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey,
            SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
            VALUES
            (@cWaveKey, @cLoadKey, @cNewOrderKey, 'SHPK', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
            @cSKU, @cPutAwayZone, @cPickZone, '', @cLOT, @cLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65947
               SET @cErrMsg = rdt.rdtgetmessage( 65947, @cLangCode, 'DSP') --'LockOrdersFail'
               ROLLBACK TRAN
               GOTO Step_9_Fail
            END
            ELSE -- SOS# 176144
            BEGIN
               COMMIT TRAN
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

            -- If still have remaining task
            -- If OrderKey changed
            IF @cOrderKey <> @cNewOrderKey
            BEGIN
               SET @cOrderKey = @cNewOrderKey

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

                     IF @nMultiStorer = 1
                        SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

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
                        @cErrMsg       OUTPUT   -- screen limitation, 20 NVARCHAR max

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

                  GOTO Quit
              END
            END   -- If OrderKey changed

            SET @cOrderKey = @cNewOrderKey

            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

            -- Get the total allocated qty for LOC + SKU + OrderKey
            SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE (( @nMultiStorer = 1 AND PD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND PD.StorerKey = @cStorerKey))
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
            WHERE (( @nMultiStorer = 1 AND RPL.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND RPL.StorerKey = @cStorerKey))
               AND RPL.Status < '5'
               AND RPL.AddWho = @cUserName
               AND RPL.PickQty <= 0
               AND PD.Status = '0'
               AND (( @nMultiStorer = 1 AND LA.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND LA.StorerKey = @cStorerKey))
               AND LA.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
               AND L.Facility = @cFacility
               AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
               AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
               AND EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = RPL.AddWho
                                    AND StorerKey = RPL.StorerKey AND OrderKey =  PD.OrderKey )       -- tlting02
               --AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) -- SOS# 176144

            -- Get Total Orders left on the current sku that need to pick
            SELECT @nTTL_Ord = COUNT( DISTINCT PD.ORDERKEY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE (( @nMultiStorer = 1 AND RPL.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND RPL.StorerKey = @cStorerKey))
               AND RPL.Status < '5'
               AND RPL.AddWho = @cUserName
               AND RPL.PickQty <= 0
               AND PD.Status = '0'
               AND PD.SKU = @cSKU
               AND PD.LOC = @cLOC
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
                  WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                     AND OrderKey = @cOrderKey

                  -- Get the total qty unpick per orders
                  SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
               WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
               WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
         END   -- @cSHOWSHTPICKRSN = 1

         -- If config turned on, not allow to change Qty To Pick
         IF @cClusterPickLockQtyToPick = '1'
         BEGIN
            SET @cFieldAttr13 = 'O'
            SET @cInField13 = @cDefaultPickQty
         END

         GOTO Quit
      END   -- Option = 1

      IF @cOption = '2'
      BEGIN
         -- If storerconfig turned on, confirm the skipped SKU    (james18)
         -- This is the same functionality as user choosing Option 1
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmSkipSKU', @cStorerKey) = '1'
         BEGIN
            GOTO Confirm_Skip_SKU
         END

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

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
               WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND OrderKey = @cOrderKey

               -- Get the total qty unpick per orders
               SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
            WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
            WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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

            -- Go to prev screen
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
      END
      ELSE
      -- SOS197651 If config setup allow to skip SKU (james11)
      IF @cOption = '3'
      BEGIN
         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

         SELECT @cLogicalLoc = '', @cStyle = '', @cColor = '', @cBUSR6 = ''
         SELECT @cLogicalLoc = LogicalLocation
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND Facility = @cFacility

         SELECT @cStyle = Style, @cColor = Color, @cBUSR6 = BUSR6 FROM dbo.SKU WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
            AND SKU = @cSKU

         --BEGIN TRAN ang02(remove)

         IF NOT EXISTS (
            SELECT 1
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE (( @nMultiStorer = 1 AND RPL.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND RPL.StorerKey = @cStorerKey))
               AND RPL.Status < '9'
               AND RPL.AddWho = @cUserName
               AND PD.Status = '0'
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
               AND L.Facility = @cFacility
               AND RTRIM(L.LogicalLocation) + RTRIM(PD.LOC) + RTRIM(SKU.Style) + RTRIM(SKU.Color) + RTRIM(SKU.BUSR6) +
                   CASE WHEN @cLoadDefaultPickMethod = 'C' THEN '' ELSE RTRIM(PD.OrderKey) END >
                   RTRIM(@cLogicalLoc) + RTRIM(@cLOC) + RTRIM(@cStyle) + RTRIM(@cColor) + RTRIM(@cBUSR6) +
                   CASE WHEN @cLoadDefaultPickMethod = 'C' THEN '' ELSE RTRIM(@cOrderKey) END)
         BEGIN

            -- Cancel the current task
            BEGIN TRAN --ang02 (add)
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET
               Status = 'X', Descr = 'User Skipped Task !!!'
            WHERE LoadKey = CASE WHEN @cLoadDefaultPickMethod = 'C' THEN @cLoadKey ELSE LoadKey END
               AND OrderKey = CASE WHEN @cLoadDefaultPickMethod = 'C' THEN OrderKey ELSE @cOrderKey END
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND SKU = @cSKU
               AND AddWho = @cUserName
               AND LOC = @cLOC   -- (james13)
               AND Status = '1'


            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69350
               SET @cErrMsg = rdt.rdtgetmessage( 69350, @cLangCode, 'DSP') --'Skip Task Fail'
               ROLLBACK TRAN
               GOTO Step_9_Fail
            END
            ELSE --(ang02) start
            BEGIN
               COMMIT TRAN
            END    --(ang02) end

            -- If pick by conso then look for all orders
            -- and group by logicalloc, loc, sku, lot2, lot4
            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               SET @cLogicalLoc = ''
               SELECT @cLogicalLoc = LogicalLocation
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cLOC
                  AND Facility = @cFacility

               SELECT TOP 1
                  @cNewLOC = PD.Loc,
                  @cNewSKU = PD.SKU,
                  @cNewLottable02 = LA.Lottable02,
                  @dNewLottable04 = LA.Lottable04
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE O.StorerKey = @cStorerKey
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                  AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                  AND PD.Status = '0'
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
                  -- (james31) to allow get next task in diff pickzone if skip task
                  --AND LOC.PickZone = CASE WHEN ISNULL(@cPickZone, '') = '' THEN LOC.PickZone ELSE @cPickZone END
                  AND O.Facility = @cFacility      -- tlting03
                  AND RTRIM(LOC.LogicalLocation) + RTRIM(PD.Loc) + RTRIM(PD.SKU) + ISNULL(RTRIM(LA.Lottable02), '') + ISNULL(CONVERT( NVARCHAR( 10), LA.Lottable04, 120), 0) >
                      RTRIM(@cLogicalLoc) + RTRIM(@cLoc) + RTRIM(@cSKU) + RTRIM(@cLottable02) + ISNULL(CONVERT( NVARCHAR( 10), @dLottable04, 120), 0)
                  AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                     WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')  -- (james31)
               GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
               ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 65975
                  SET @cErrMsg = rdt.rdtgetmessage( 65975, @cLangCode, 'DSP') --'No Record'
                  GOTO Step_9_Fail
               END

               SET @cLOC = @cNewLOC
               SET @cSKU = @cNewSKU
               SET @cLottable02 = @cNewLottable02
               SET @dLottable04 = @dNewLottable04

               SELECT
                  @cSKU_Descr   = SKU.DESCR,
                  @cStyle       = SKU.Style,
                  @cColor       = SKU.Color,
                  @cSize        = SKU.Size,
                  @cColor_Descr = SKU.BUSR7
               FROM dbo.SKU SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               IF rdt.RDTGetConfig( @nFunc, 'ReplaceDescrWithColorSize', @cStorerKey) = 1
               BEGIN
                  SET @cColor_Descr = SUBSTRING( @cSKU_Descr, 1, 20)
                  SET @cColor = @cColor + ' '
                  SET @cSKU_Descr = ''
               END

               DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PD.ORDERKEY, PD.LOT
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey and PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.STATUS = '0'
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                  AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
               OPEN CUR_LOOK4CONSO_ORDERS
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  BEGIN TRAN

                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
                  , LOT, LOC, SKU, DropID, Lottable02, Lottable04, Status, AddWho, AddDate, PickSlipNo, Mobile, PackKey)
                  VALUES
                  (ISNULL(@cWaveKey, ''), ISNULL(@cLoadKey, ''), @cConso_Orders, '', @cStorerKey, ISNULL(@cPutAwayZone, ''), ISNULL(@cPickZone, ''), @cConso_Orders,
                  @cLot, @cLoc, @cSKU, @cDropID, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cPickSlipNo, @nMobile, @cCartonType)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65976
                     SET @cErrMsg = rdt.rdtgetmessage( 65976, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE --ang02 start
                  BEGIN
                  COMMIT TRAN
                  END--ang02 end

                  FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
               END
               CLOSE CUR_LOOK4CONSO_ORDERS
               DEALLOCATE CUR_LOOK4CONSO_ORDERS

               SELECT @nTTL_Qty = SUM(PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) --ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey)
               JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.Status = '0'
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
                  AND L.Facility = @cFacility
                  AND LA.Storerkey = @cStorerKey   -- tlting03
                  AND LA.SKU = @cSKU
                  AND L.LOC = @cLOC
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)
                  -- TLTING03  Duplicate check
                  --AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = PD.StorerKey
                  --               AND OrderKey = PD.OrderKey AND ADDWHO = @cUserName ) -- SOS# 176144
--                  AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName and Status = '1') -- SOS# 176144

               -- Get the total allocated qty for LOC + SKU + OrderKey
               SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.Status = '0'
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)

               SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
               IF CAST(@cDefaultPickQty AS INT) <= 0 SET @cDefaultPickQty = ''

               IF @cDefaultToAllocatedQty = '1'
               BEGIN
                  SET @cDefaultPickQty = @nTotalPickQty
               END

               SET @nQtyToPick = 0
               SET @nActQty = 0

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

                  EXEC rdt.rdtSetFocusField @nMobile, 4

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

               -- Commit transaction
               --COMMIT TRAN    ang02 remove

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

               GOTO Quit
            END
            ELSE
            BEGIN
               SELECT
                  @nOrderPicked = COUNT( DISTINCT OrderKey),
                  @nTTL_PickedQty = SUM(PickQty)
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE AddWho = @cUserName
                  AND Status = '5'
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                  AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                  AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))

               -- Confirm picking in RDT.RDTPickLock
               SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
               AND AddWho = @cUserName
               AND Status = '5'
               OPEN @curUpdRPL
               FETCH NEXT FROM @curUpdRPL INTO @nRowRef
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  BEGIN TRAN --ang02 add
                  UPDATE RDT.RDTPickLock with (ROWLOCK) SET
                  Status = '9'   -- Confirm Picked
                  WHERE RowRef = @nRowRef

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65946
                     SET @cErrMsg = rdt.rdtgetmessage( 65946, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE --(ang02) start
                  BEGIN
                        COMMIT TRAN
                  END--(ang02) end

                  FETCH NEXT FROM @curUpdRPL INTO @nRowRef
               END
               CLOSE @curUpdRPL
               DEALLOCATE @curUpdRPL

               --COMMIT TRAN ang02 remove

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

               GOTO Quit
            END
         END   -- not exists
         ELSE
         BEGIN
            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

            SELECT @cLogicalLoc = '', @cStyle = '', @cColor = '', @cBUSR6 = ''
            SELECT @cLogicalLoc = LogicalLocation
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cLOC
               AND Facility = @cFacility

            SELECT @cStyle = Style, @cColor = Color, @cBUSR6 = BUSR6 FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU


            -- If pick by conso then look for all orders
            -- and group by logicalloc, loc, sku, lot2, lot4
            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               SELECT TOP 1
                  @cNewLOC = PD.Loc,
                  @cNewSKU = PD.SKU,
                  @cNewLottable02 = LA.Lottable02,
                  @dNewLottable04 = LA.Lottable04
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK)
                  ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    -- (james09)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.Status = '0'
                  AND O.LoadKey = @cLoadKey
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                  AND O.Facility = @cFacility   -- tlting03
                  AND RTRIM(LOC.LogicalLocation) + RTRIM(PD.SKU) + ISNULL(RTRIM(LA.Lottable02), '') + ISNULL(CONVERT( NVARCHAR( 10), LA.Lottable04, 120), 0) >
                      RTRIM(@cLogicalLoc) + RTRIM(@cSKU) + RTRIM(@cLottable02) + ISNULL(CONVERT( NVARCHAR( 10), @dLottable04, 120), 0)--@dLottable04
                  AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                     WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')
               GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
               ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 65975
                  SET @cErrMsg = rdt.rdtgetmessage( 65975, @cLangCode, 'DSP') --'No Record'
                  GOTO Step_9_Fail
               END
               BEGIN TRAN   --ang02 add
               -- Cancel the current task
               UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET
                  Status = 'X', Descr = 'User Skipped Task !!!'
               WHERE LoadKey = @cLoadKey
                  AND StorerKey = @cStorerKey    -- tlting03
                  AND SKU = @cSKU
                  AND AddWho = @cUserName
                  AND LOC = @cLOC   -- (james13)
                  AND Status = '1'
                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
                  ELSE --(ang02) start
                  BEGIN
                        COMMIT TRAN
                  END--(ang02) end

               SET @cLOC = @cNewLOC
               SET @cSKU = @cNewSKU
               SET @cLottable02 = @cNewLottable02
               SET @dLottable04 = @dNewLottable04

               SELECT
                  @cSKU_Descr   = SKU.DESCR,
                  @cStyle       = SKU.Style,
                  @cColor       = SKU.Color,
                  @cSize        = SKU.Size,
                  @cColor_Descr = SKU.BUSR7
               FROM dbo.SKU SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               IF rdt.RDTGetConfig( @nFunc, 'ReplaceDescrWithColorSize', @cStorerKey) = 1
               BEGIN
                  SET @cColor_Descr = SUBSTRING( @cSKU_Descr, 1, 20)
                  SET @cColor = @cColor + ' '
                  SET @cSKU_Descr = ''
               END

               DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PD.ORDERKEY, PD.LOT
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey and PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.STATUS = '0'
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
                  AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
               OPEN CUR_LOOK4CONSO_ORDERS
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  BEGIN TRAN

                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
                  , LOT, LOC, SKU, DropID, Lottable02, Lottable04, Status, AddWho, AddDate, PickSlipNo, Mobile, PackKey)
                  VALUES
                  (ISNULL(@cWaveKey, ''), ISNULL(@cLoadKey, ''), @cConso_Orders, 'SKIP', @cStorerKey, ISNULL(@cPutAwayZone, ''), ISNULL(@cPickZone, ''), @cConso_Orders,
                  @cLot, @cLoc, @cSKU, @cDropID, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cPickSlipNo, @nMobile, @cCartonType)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65976
                     SET @cErrMsg = rdt.rdtgetmessage( 65976, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                GOTO Step_9_Fail
                  END
                  ELSE --ang02 start
                  BEGIN
                     COMMIT TRAN
                  END --ang02 end

                  FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
               END
               CLOSE CUR_LOOK4CONSO_ORDERS
               DEALLOCATE CUR_LOOK4CONSO_ORDERS

               SELECT @nTTL_Qty = SUM(PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) --ON (RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey)
               JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.Status = '0'
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
                  AND L.Facility = @cFacility
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)
                  -- TLTING03 Duplicate check
                  --AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = PD.StorerKey
                  --               AND OrderKey = PD.OrderKey
                  --               AND ADDWHO = @cUserName ) -- SOS# 176144
                  --AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName and Status = '1') -- SOS# 176144

               -- Get the total allocated qty for LOC + SKU + OrderKey
               SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.LOC = @cLOC
                  AND PD.StorerKey = @cStorerKey   -- tlting03
                  AND PD.SKU = @cSKU
                  AND PD.Status = '0'
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.SKU = PD.SKU AND RPL.OrderKey = PD.OrderKey
                     AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)

               SET @cDefaultPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultPickQty', @cStorerKey)
               IF CAST(@cDefaultPickQty AS INT) <= 0 SET @cDefaultPickQty = ''

               IF @cDefaultToAllocatedQty = '1'
               BEGIN
                  SET @cDefaultPickQty = @nTotalPickQty
               END

               SET @nQtyToPick = 0
               SET @nActQty = 0

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
                  AND LA.StorerKey = @cStorerKey      -- tlting03
                  AND LA.SKU = @cSKU
                  AND L.LOC = @cLOC
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

                  EXEC rdt.rdtSetFocusField @nMobile, 4

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

               -- Commit transaction
               --  COMMIT TRAN   -- ang02

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

               GOTO Quit
            END
            ELSE
            BEGIN
               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               SELECT @cLogicalLoc = '', @cStyle = '', @cColor = '', @cBUSR6 = ''
               SELECT @cLogicalLoc = LogicalLocation
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cLOC
                  AND Facility = @cFacility

               SELECT @cStyle = Style, @cColor = Color, @cBUSR6 = BUSR6 FROM dbo.SKU WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND SKU = @cSKU

               -- (james19)
               SET @cPrevLOC = ''
               SET @cPrevLOC = @cLOC
               -- Skip current SKU
               SET @c_ExecStatements = N'SELECT TOP 1 ' +
                                        '@cNewLOC = PD.Loc, ' +
                                        '@cNewOrderKey = PD.OrderKey,  ' +
                                        '@cNewSKU = PD.SKU,  ' +
                                        '@cLot = PD.LOT,  ' +
                                        '@cPickSlipNo = PD.PickSlipNo  ' +
                                        'FROM RDT.RDTPickLock RPL WITH (NOLOCK)  ' +
                                        'JOIN dbo.PickDetail PD WITH (NOLOCK) ' +
                                        'ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  ' +
                                        'JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  ' +
                                        'JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  ' +
                                        'WHERE (( @nMultiStorer = 1 AND RPL.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND RPL.StorerKey = @cStorerKey))' + 
                                        'AND RPL.Status < ''9''  ' +
                                        'AND RPL.AddWho = @cUserName  ' +
                                        'AND PD.Status = ''0''  ' +
                                        'AND (( ISNULL( @cPutAwayZone, '''') = ''ALL'') OR ( L.PutAwayZone = @cPutAwayZone)) ' +
                                        'AND (( ISNULL( @cPickZone, '''') = '''') OR ( L.PickZone = @cPickZone)) ' + 
                                        'AND L.Facility = @cFacility  '

               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
               BEGIN
                  SET @c_ExecStatements = RTRIM(@c_ExecStatements) +
                                          ' AND RTRIM(L.LogicalLocation) + RTRIM(PD.LOC) + RTRIM(SKU.Style) + RTRIM(SKU.Color) + RTRIM(SKU.BUSR6) + RTRIM(PD.OrderKey) > ' +
                                          ' RTRIM(@cLogicalLoc) + RTRIM(@cLOC) + RTRIM(@cStyle) + RTRIM(@cColor) + RTRIM(@cBUSR6) + RTRIM(@cOrderKey) '
                  SET @c_ExecStatements = RTRIM(@c_ExecStatements) + ' ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, PD.OrderKey '
               END
               ELSE
               BEGIN
                  SET @c_ExecStatements = RTRIM(@c_ExecStatements) + ' AND RTRIM(L.LogicalLocation) + RTRIM(PD.SKU) > RTRIM(@cLogicalLoc) + RTRIM(@cSKU) '
                  SET @c_ExecStatements = RTRIM(@c_ExecStatements) + ' ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, PD.OrderKey '
               END

               SET @c_ExecArguments = N'@cStorerKey            NVARCHAR(15), ' +
                                       '@cUserName             NVARCHAR(15), ' +
                                       '@cPutAwayZone          NVARCHAR(10), ' +
                                       '@cPickZone             NVARCHAR(10), ' +
                                       '@cFacility             NVARCHAR(5),  ' +
                                       '@cLogicalLoc           NVARCHAR(18), ' +
                                       '@cSKU                  NVARCHAR(20), ' +
                                       '@cStyle                NVARCHAR(20), ' +
                                       '@cColor                NVARCHAR(10), ' +
                                       '@cBUSR6                NVARCHAR(30), ' +
                                       '@cOrderKey             NVARCHAR(10), ' +
                                       '@cLOC                  NVARCHAR(10), ' +
                                       '@cORD_StorerKey        NVARCHAR(15), ' +
                                       '@nMultiStorer          INT,          ' +
                                       '@cNewLOC               NVARCHAR(10) OUTPUT, ' +
                                       '@cNewOrderKey          NVARCHAR(10) OUTPUT, ' +
                                       '@cNewSKU               NVARCHAR(20) OUTPUT, ' +
                                       '@cLot                  NVARCHAR(10) OUTPUT, ' +
                                       '@cPickSlipNo           NVARCHAR(10) OUTPUT '

               EXEC sp_ExecuteSql @c_ExecStatements
                                 ,@c_ExecArguments
                                 ,@cStorerKey
                                 ,@cUserName
                                 ,@cPutAwayZone
                                 ,@cPickZone
                                 ,@cFacility
                                 ,@cLogicalLoc
                                 ,@cSKU
                                 ,@cStyle
                                 ,@cColor
                                 ,@cBUSR6
                                 ,@cOrderKey
                                 ,@cLOC
                                 ,@cORD_StorerKey
                                 ,@nMultiStorer
                                 ,@cNewLOC      OUTPUT
                                 ,@cNewOrderKey OUTPUT
                                 ,@cNewSKU      OUTPUT
                                 ,@cLot         OUTPUT
                                 ,@cPickSlipNo  OUTPUT

               -- (james31)
               IF ISNULL(@cNewOrderKey, '') = ''
               BEGIN
                  SET @nErrNo = 69383
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO MORE TASK'
                  GOTO Step_9_Fail
               END

               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cNewOrderKey

               SELECT
                  @cLottable02 = Lottable02,
                  @dLottable04 = Lottable04
               FROM dbo.LotAttribute WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND SKU = @cNewSKU
                  AND LOT = @cLot

               SELECT @cSKU_Descr = SKU.DESCR,
                  @cStyle = SKU.Style,
                  @cColor = SKU.Color,
                  @cSize = SKU.Size,
                  @cColor_Descr = SKU.BUSR7
               FROM dbo.SKU SKU WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
                  AND SKU.SKU = @cNewSKU

               IF rdt.RDTGetConfig( @nFunc, 'ReplaceDescrWithColorSize', @cStorerKey) = 1
               BEGIN
                  SET @cColor_Descr = SUBSTRING( @cSKU_Descr, 1, 20)
                  SET @cColor = @cColor + ' '
                  SET @cSKU_Descr = ''
               END

               SELECT
                  @cExternOrderKey = ExternOrderKey,
                  @cConsigneeKey = ConsigneeKey
               FROM dbo.Orders WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND OrderKey = @cNewOrderKey

               BEGIN TRAN

               -- Insert next task to picklock
               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
               , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
               VALUES
               (@cWaveKey, @cLoadKey, @cNewOrderKey, 'SKIP', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
               @cNewSKU, @cPutAwayZone, @cPickZone, ''
               , @cLOT, @cNewLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 69352
                  SET @cErrMsg = rdt.rdtgetmessage( 69352, @cLangCode, 'DSP') --'LockOrdersFail'
                  ROLLBACK TRAN
                  GOTO Step_9_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END

               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               -- Cancel the current task
               BEGIN TRAN --ang02
               UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET
                  Status = 'X', Descr = 'User Skipped Task !!!'
               WHERE OrderKey = @cOrderKey
                  AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                  AND SKU = @cSKU
                  AND AddWho = @cUserName
                  AND LOC = @cLOC   -- (james13)
                  AND Status = '1'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 69353
                  SET @cErrMsg = rdt.rdtgetmessage( 69353, @cLangCode, 'DSP') --'Skip Task Fail'
                  ROLLBACK TRAN
                  GOTO Step_9_Fail
               END
               ELSE --ang02 start
               BEGIN
                     COMMIT TRAN
               END -- ang02 end

               -- (james26)
               SET @cLOC = @cNewLOC
               SET @cSKU = @cNewSKU
               SET @cOrderKey = @cNewOrderKey

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

               -- If still have remaining task
               -- If OrderKey changed
               IF @cOrderKey <> @cNewOrderKey
               BEGIN
                  SET @cOrderKey = @cNewOrderKey
                  SET @cSKU = @cNewSKU

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

                        IF @nMultiStorer = 1
                           SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

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

                     GOTO Quit
                 END
               END   -- If OrderKey changed

               SET @cOrderKey = @cNewOrderKey
               SET @cSKU = @cNewSKU

               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               -- Get the total allocated qty for LOC + SKU + OrderKey
               SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
               WHERE (( @nMultiStorer = 1 AND PD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND PD.StorerKey = @cStorerKey))
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
               WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
                  AND RPL.Status < '5'
                  AND RPL.AddWho = @cUserName
                  AND RPL.PickQty <= 0
                  AND PD.Status = '0'
                  AND (( @nMultiStorer = 1 AND LA.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND LA.StorerKey = @cStorerKey))
                  AND LA.SKU = @cSKU
                  AND L.LOC = @cLOC
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
                  AND L.Facility = @cFacility
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                  AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) -- SOS# 176144

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
                  AND PD.Status = '0'
                  AND (( @nMultiStorer = 1) OR ( LA.StorerKey = @cStorerKey))
                  AND LA.SKU = @cSKU
                  AND L.LOC = @cLOC
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
                  AND L.Facility = @cFacility
                  AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                  AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

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
                     WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
                        AND OrderKey = @cOrderKey

                     -- Get the total qty unpick per orders
                     SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
                  WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
                  WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
            END
         END
      END      -- IF @cOption = '3'

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

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james14)
      IF rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
      BEGIN
         SET @cOS_Qty = ''

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

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
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND OrderKey = @cOrderKey

            -- Get the total qty unpick per orders
            SELECT @nTTL_UnPick_ORD = ISNULL( SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
         WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
         WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
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
         SET @cOutField06 = CASE WHEN @cScanLOT02 = '1' THEN '' ELSE @cLottable02 END  -- (james32)
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
   END
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

   GOTO Quit

   Step_9_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 10. Screen = 1879
   Picking Completed
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey IN (0, 1)-- ESC/ENTER
   BEGIN
      BEGIN TRAN

      -- Scan Out pickslip
      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         DECLARE curPickingInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PH.PickHeaderKey, 'W' -- Wave PS (Vicky07)
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON (RPL.OrderKey = O.OrderKey) -- (Vicky03)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) -- SOS# 176144
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.UserDefine09 = PH.WaveKey AND O.OrderKey = PH.OrderKey)
         WHERE O.UserDefine09 = @cWaveKey
            AND RPL.Status = '9'
            AND RPL.StorerKey = @cStorerKey    -- tlting03
            AND RPL.AddWho = @cUserName
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
            AND RPL.Mobile = @nMobile -- (Vicky07)
         --ORDER BY PH.PickHeaderKey
      END
      ELSE
      BEGIN
         -- Check if it is Conso pickslip (james06)
         IF EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
                     WHERE ExternOrderKey = @cLoadKey
                     AND ISNULL(RTRIM(Orderkey), '') = '') -- SOS# 176144
         BEGIN
            DECLARE curPickingInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PH.PickHeaderKey, 'C' -- Conso PS (Vicky07)
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON (RPL.OrderKey = O.OrderKey) -- (Vicky03)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) -- SOS# 176144
            JOIN dbo.LoadPlanDetail lpd WITH (NOLOCK) ON (lpd.OrderKey = O.OrderKey)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (lpd.LoadKey = PH.ExternOrderKey)
            WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
               AND lpd.LoadKey = @cLoadKey         --tlting03
               AND RPL.Status = '9'
               AND RPL.StorerKey = @cStorerKey     -- tlting03
               AND RPL.AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
               AND RPL.Mobile = @nMobile -- (Vicky07)
            --ORDER BY PH.PickHeaderKey
         END
         ELSE
         BEGIN
            DECLARE curPickingInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PH.PickHeaderKey, 'D' -- Discrete PS (Vicky07)
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON (RPL.OrderKey = O.OrderKey) -- (Vicky03)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) -- SOS# 176144
            JOIN dbo.LoadPlanDetail lpd WITH (NOLOCK) ON (lpd.OrderKey = O.OrderKey)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (lpd.LoadKey = PH.ExternOrderKey AND lpd.OrderKey = PH.OrderKey)
            WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
               AND (( ISNULL(@cLoadKey, '') = '') OR ( lpd.LoadKey = @cLoadKey))
               AND RPL.Status = '9'
               AND RPL.StorerKey = @cStorerKey   -- tlting03
               AND RPL.AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
               AND RPL.Mobile = @nMobile -- (Vicky07)
            --ORDER BY PH.PickHeaderKey
         END
      END

      OPEN curPickingInfo
      FETCH NEXT FROM curPickingInfo INTO @cPickSlipNo, @cPSFlag -- (Vicky07)
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- (Vicky07) - Start
         IF @cPSFlag = 'W'
         BEGIN
            IF NOT EXISTS (SELECT 1 From dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.ORDERDETAIL ORDDET WITH (NOLOCK) ON (PD.Orderkey = ORDDET.Orderkey AND PD.OrderLineNumber = ORDDET.OrderLineNumber)
            JOIN dbo.ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = ORDDET.Orderkey)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (ORD.UserDefine09 = PH.WaveKey AND ORD.OrderKey = PH.OrderKey)
            WHERE PH.PickHeaderkey = @cPickSlipNo
            AND   PD.Status < '5')
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
               BEGIN
                  UPDATE dbo.PickingInfo WITH (ROWLOCK)
                     SET SCANOUTDATE = GETDATE(),
                         EditWho = @cUserName--,
                         --TrafficCop = 'X'
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   SCANOUTDATE IS NULL
               END
            END
         END
         ELSE IF @cPSFlag = 'C'
         BEGIN
            IF NOT EXISTS (SELECT 1 From dbo.PickDetail PD WITH (NOLOCK)
                            JOIN dbo.ORDERDETAIL ORDDET WITH (NOLOCK) ON (PD.Orderkey = ORDDET.Orderkey AND PD.OrderLineNumber = ORDDET.OrderLineNumber)
                            JOIN dbo.ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = ORDDET.Orderkey)
                            JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = ORD.Orderkey)
                            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (LPD.Loadkey = PH.ExternOrderKey)
                           WHERE PH.PickHeaderkey = @cPickSlipNo
                           AND   PD.Status < '5')
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
               BEGIN
                  UPDATE dbo.PickingInfo WITH (ROWLOCK)
                     SET SCANOUTDATE = GETDATE(),
                         EditWho = @cUserName--,
                         --TrafficCop = 'X'
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   SCANOUTDATE IS NULL
               END
            END
         END
         ELSE IF @cPSFlag = 'D'
         BEGIN
            IF NOT EXISTS (SELECT 1 From dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.ORDERDETAIL ORDDET WITH (NOLOCK) ON (PD.Orderkey = ORDDET.Orderkey AND PD.OrderLineNumber = ORDDET.OrderLineNumber)
               JOIN dbo.ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = ORDDET.Orderkey)
               JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = ORD.Orderkey)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON (LPD.Loadkey = PH.ExternOrderKey AND LPD.Orderkey = PH.Orderkey)
               WHERE PH.PickHeaderkey = @cPickSlipNo
               AND   PD.Status < '5')
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
               BEGIN
                  UPDATE dbo.PickingInfo WITH (ROWLOCK)
                     SET SCANOUTDATE = GETDATE(),
                         EditWho = @cUserName--,
                         --TrafficCop = 'X'
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   SCANOUTDATE IS NULL
               END
            END
         END
         -- (Vicky07) - End

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65948
            SET @cErrMsg = rdt.rdtgetmessage( 65948, @cLangCode, 'DSP') --'Scan Out Fail'
            ROLLBACK TRAN
            GOTO Step_10_Fail
         END

         -- (james10)
         -- Check picked qty = packed qty then can confirm
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1'
         BEGIN
            SELECT @cPOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            -- Start (james37)
            IF @cPSFlag = 'D'
            BEGIN
               SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE Orderkey = @cPOrderKey
               AND   [Status] = '5'
            END

            IF @cPSFlag = 'C'
            BEGIN
               SELECT @nSumPickQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON (LPD.LoadKey = PH.ExternOrderKey)
               WHERE PH.PickHeaderKey = @cPickSlipNo
               AND   PD.Status = '5'
            END

            IF @cPSFlag = 'W'
            BEGIN
               SELECT @nSumPickQTY = ISNULL( SUM( QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.Orderkey = O.Orderkey)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.UserDefine09 = PH.WaveKey AND O.OrderKey = PH.OrderKey)
               WHERE PH.PickHeaderKey = @cPickSlipNo
               AND   PD.Status = '5'
            END
            -- End(james37)

            -- Only when config 'AUTOPACKCONFIRM' is turned on and pick and pack match then scan out
            IF (@nSumPackQTY = @nSumPickQTY) AND rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey) = '1'
            BEGIN
               -- Start (james37)
               IF @cPSFlag = 'D'
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                             WHERE Orderkey = @cPOrderKey
                             AND   [Status] < '5')
                  BEGIN
                     UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                        STATUS = '9'
                     WHERE PickSlipNo = @cPickSlipNo
                        AND STATUS = '0'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 69348
                        SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'ConfPackFail'
                        ROLLBACK TRAN
                        GOTO Step_10_Fail
                     END
                  END
               END

               IF @cPSFlag = 'C'
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (LPD.LoadKey = PH.ExternOrderKey)
                                  WHERE PH.PickHeaderKey = @cPickSlipNo
                                  AND PD.Status < '5')
                  BEGIN
                     UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                        STATUS = '9'
                     WHERE PickSlipNo = @cPickSlipNo
                        AND STATUS = '0'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 69348
                        SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'ConfPackFail'
                        ROLLBACK TRAN
                        GOTO Step_10_Fail
                     END
                  END
               END

               IF @cPSFlag = 'W'
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                                  JOIN dbo.Orders O WITH (NOLOCK) ON (OD.Orderkey = O.Orderkey)
                                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.UserDefine09 = PH.WaveKey AND O.OrderKey = PH.OrderKey)
                                  WHERE PH.PickHeaderKey = @cPickSlipNo
                                  AND   PD.Status < '5')
                  BEGIN
                     UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                        STATUS = '9'
                     WHERE PickSlipNo = @cPickSlipNo
                        AND STATUS = '0'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 69348
                        SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'ConfPackFail'
                        ROLLBACK TRAN
                        GOTO Step_10_Fail
                     END
                  END
               END                -- Start (james37)
            END

            -- Close the dropid if picked = packed (james30)
            IF (@nSumPackQTY = @nSumPickQTY) AND rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
            BEGIN
               SET @cTDropID = ''
               SELECT TOP 1 @cTDropID = D.DropID 
               FROM dbo.DROPID D (NOLOCK)
               JOIN dbo.DROPIDDETAIL DD (NOLOCK) ON D.DROPID = DD.DROPID
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON DD.ChildID = PD.OrderKey
               WHERE PD.OrderKey = @cPOrderKey
               AND   D.Status = '0'

               EXECUTE rdt.rdt_Cluster_Pick_DropID
                  @nMobile,
                  @nFunc,
                  @cStorerKey,
                  @cUserName,
                  @cFacility,
                  @cLoadKey,
                  @cPickSlipNo,
                  @cOrderKey,
                  @cTDropID      OUTPUT,
                  @cSKU,
                  'U',      -- U = Update
                  @cLangCode,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT   -- screen limitation, 20 NVARCHAR max
            END
            set @nErrNo = 0
            set @cErrMsg = ''
         END
         ELSE  -- Not auto packing
         BEGIN
            -- Close the dropid if picked = packed (james30)
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1'
            BEGIN
               SET @cTDropID = ''
               SELECT TOP 1 @cTDropID = DropID 
               FROM DROPID WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   Status = '0'

               EXECUTE rdt.rdt_Cluster_Pick_DropID
                  @nMobile,
                  @nFunc,
                  @cStorerKey,
                  @cUserName,
                  @cFacility,
                  @cLoadKey,
                  @cPickSlipNo,
                  @cOrderKey,
                  @cTDropID      OUTPUT,
                  @cSKU,
                  'U',      -- U = Update
                  @cLangCode,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT   -- screen limitation, 20 NVARCHAR max
            END
         END
         FETCH NEXT FROM curPickingInfo INTO @cPickSlipNo, @cPSFlag -- (Vicky07)
      END
      CLOSE curPickingInfo
      DEALLOCATE curPickingInfo

      COMMIT TRAN

      IF @nMultiStorer = 1 AND ISNULL(@cPOrderKey, '') <> ''
         SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      -- Decide where to go
      --1. Check if exists other pickzone within the same orders
      IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         WHERE  PD.Status = '0'
            AND PD.OrderKey = @cOrderKey
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND L.Facility = @cFacility
            AND RPL.AddWho = @cUserName)
      BEGIN
         -- check discrete first    (james23)
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         WHERE PH.OrderKey = @cOrderKey
            AND PH.Status = '0'

         -- not discrete pick, look in wave
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            IF ISNULL(@cWaveKey, '') <> ''
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    -- (james09)
               WHERE  O.OrderKey = @cOrderKey
                  AND PH.Status = '0'
                  AND O.UserDefine09 = @cWaveKey 
            ELSE
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    -- (james09)
               WHERE  O.OrderKey = @cOrderKey
                  AND PH.Status = '0'
         END

         -- If not wave plan, look in loadplan
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            IF ISNULL(@cLoadKey, '') <> ''
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey  AND PH.ExternOrderKey <> '')
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey     -- (james09)
               WHERE  O.OrderKey = @cOrderKey
                  AND PH.Status = '0'
                  AND O.LoadKey = @cLoadKey 
            ELSE
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey  AND PH.ExternOrderKey <> '')
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey     -- (james09)
               WHERE  O.OrderKey = @cOrderKey
                  AND PH.Status = '0'
         END

         INSERT INTO RDT.RDTPickLock
         (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey,
         PutAwayZone, PickZone, PickDetailKey
         , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, PickQty, Mobile)
         VALUES
         (@cWaveKey, @cLoadKey, @cOrderKey, '***', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
         @cPutawayzone, '', ''
         , '', '', '1', @cUserName, GETDATE(), @cPickSlipNo, 0, @nMobile)

         -- Go to PickZone screen, if there still have other pickzone to pick
         SET @nOutScn  = 1874
         SET @nOutStep = 5

         SET @cOutField01 = '' --PickZone

--         GOTO Quit
      END
      ELSE
      BEGIN
         --2. Check if others orders got the task to do or not within same putawayzone
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE RPL.Status = '1'
               AND RPL.AddWho = @cUserName
               AND PD.Status = '0'
               AND PD.StorerKey = @cStorerKey
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
               AND L.Facility = @cFacility)
         BEGIN
            -- Go to PickZone screen, if there still have other pickzone to pick
            SET @nOutScn  = 1874
            SET @nOutStep = 5

            SET @cOutField01 = '' --PickZone

            --GOTO Quit
         END
         ELSE
         BEGIN
            -- tlting  deadlock tune
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET 
               PickDetailKey = ''
            WHERE ADDWHO = @cUserName 
            AND   ISNULL( PickDetailKey, '') <> '' 
            AND   Status < '9'

            -- (james34)
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

            -- Go to WaveKey screen, if no other pickzone to pick
            SET @nOutScn  = 1870
            SET @nOutStep = 1

            SET @cOutField01 = '' --WaveKey

            --GOTO Quit
         END
      END
   END

   DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT ROWREF 
   FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ADDWho = @cUserName
      AND Status = 'X'
   OPEN CUR_DEL
   FETCH NEXT FROM CUR_DEL INTO @nRowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM RDT.RDTPickLock WITH (ROWLOCK) WHERE ROWREF = @nRowRef
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
   END
   CLOSE CUR_DEL
   DEALLOCATE CUR_DEL

   GOTO Quit

   Step_10_Fail:
   BEGIN
      GOTO Quit
   END

END
GOTO Quit

/********************************************************************************
Step 11. Screen = 1880
   Exit Picking     (display)
********************************************************************************/
Step_11:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 65949
         SET @cErrMsg = rdt.rdtgetmessage( 65949, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_11_Fail
      END

      IF @cOption = '1'
      BEGIN
      -- If there is scanned but not yet confirmed qty, goto screen 12
      IF EXISTS ( SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
                  AND AddWho = @cUserName
                  AND Status = '1'
                  AND PickQty > 0
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone)))
      BEGIN
         -- (jame18)
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmSkipSKU', @cStorerKey) = 1
         BEGIN
            SET @cOutField02 = '3 - KEEP SCANNED SKU'
         END

         SET @nOutScn  = 1881
         SET @nOutStep = 12

         SET @cOutField01 = '' -- Option
         GOTO Quit
      END
      ELSE
      BEGIN
         -- No scanned qty
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN Step11_Update

         -- Update Picked to Confirm Picked
         SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
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
               ROLLBACK TRAN Step11_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

               SET @nErrNo = 65950
               SET @cErrMsg = rdt.rdtgetmessage( 65950, @cLangCode, 'DSP') --'UPDPKLockFail'
               GOTO Step_11_Fail
            END

            FETCH NEXT FROM @curUpdRPL INTO @nRowRef
         END
         CLOSE @curUpdRPL
         DEALLOCATE @curUpdRPL

         -- Release lock
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
               ROLLBACK TRAN Step11_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

               CLOSE CUR_DEL
               DEALLOCATE CUR_DEL
               SET @nErrNo = 65951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
               GOTO Step_11_Fail
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
               ROLLBACK TRAN Step11_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

          CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               SET @nErrNo = 65951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
               GOTO Step_11_Fail
            END
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         COMMIT TRAN Step11_Update
         WHILE @@TRANCOUNT > @nTranCount 
               COMMIT TRAN 

         SET @cOutField01 = '' -- WaveKey

         -- Prev next screen variable
         SET @nOutScn  = 1870
         SET @nOutStep = 1

         GOTO Quit
      END
   END

   IF @cOption = '2'
   BEGIN
      IF @nFunc = 1826
      BEGIN
         -- Go to scan DropID screen
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
            @cErrMsg       OUTPUT   -- screen limitation, 20 NVARCHAR max

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

      GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nFunc = 1826
      BEGIN
         -- Go to scan DropID screen
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
   END

   GOTO Quit

   Step_11_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 12. Screen = 1881
   Please Input     (field01, input)
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 65952
         SET @cErrMsg = rdt.rdtgetmessage( 65952, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_12_Fail
      END

      IF @nMultiStorer = 1
         SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

      IF @cOption IN ('1', '3')
      BEGIN
         -- (james36)
         IF rdt.RDTGetConfig( @nFunc, 'NOTALLOWSHORTPICK', @cStorerKey) = 1
         BEGIN
            SET @nErrNo = 69388
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SHPICK X ALLOW
            GOTO Step_12_Fail
         END

         SET @cSHOWSHTPICKRSN = rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey)

         IF @cSHOWSHTPICKRSN = '1'
         BEGIN
            SELECT @nShortPickedQty = PickQty
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cLOC
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))

            SELECT
                 @cPackUOM3 = P.PACKUOM3
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
            WHERE (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))
               AND SKU.SKU = @cSKU

            SET @cOutField01 = @nShortPickedQty -- cluster picking, this is short picked qty
            SET @cOutField02 = @cPackUOM3 -- cluster picking
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''

            -- Save current screen no
            SET @nCurScn = @nInScn
            SET @nCurStep = @nInStep

            -- Go to STD short pick screen
            SET @nOutScn = 2010
            SET @nOutStep = @nStep + 2
            GOTO Quit
         END
         ELSE
         BEGIN
            -- Insert the short picked qty   SOS131967
            IF NOT EXISTS (SELECT 1
                           FROM RDT.RDTPickLock WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey
                           AND Status = '1'
                           AND AddWho = @cUserName
                           AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                           AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                           AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                           AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                           AND SKU = @cSKU
                           AND PickQty = 0)
            BEGIN
               BEGIN TRAN

               INSERT INTO RDT.RDTPickLock
               (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
               , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, PickQty, Mobile)
               SELECT TOP 1 WaveKey, LoadKey, Orderkey, '*****' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
               , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, '' AS DropID, @cPickSlipNo AS PickSlipNo, 0, @nMobile
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
                  AND Status = '1'
                  AND AddWho = @cUserName
                  AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
                  AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
                  AND SKU = @cSKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 65963
                  SET @cErrMsg = rdt.rdtgetmessage( 65963, @cLangCode, 'DSP') --'INSTPKLockFail'
                  ROLLBACK TRAN
                  GOTO Step_12_Fail
               END
            END

            IF @cLoadDefaultPickMethod = 'C'
            BEGIN
               DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT OrderKey FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND LoadKey = @cLoadKey
               AND SKU = @cSKU
               OPEN CUR_LOOK4CONSO_ORDERS
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @nErrNo = 0

                  SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
                  IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
                  BEGIN
                     SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                        ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                        ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                     SET @cSQLParms =    
                        '@nMobile                   INT,           ' +
                        '@nFunc                     INT,           ' +
                        '@cLangCode                 NVARCHAR( 3),  ' +
                        '@nStep                     INT,           ' +
                        '@nInputKey                 INT,           ' +
                        '@cFacility                 NVARCHAR( 5),  ' +
                        '@cStorerkey                NVARCHAR( 15), ' +
                        '@cWaveKey                  NVARCHAR( 10), ' +
                        '@cLoadKey                  NVARCHAR( 10), ' +
                        '@cOrderKey                 NVARCHAR( 10), ' +
                        '@cPutAwayZone              NVARCHAR( 10), ' +
                        '@cPickZone                 NVARCHAR( 10), ' +
                        '@cSKU                      NVARCHAR( 20), ' +
                        '@cPickSlipNo               NVARCHAR( 10), ' +
                        '@cLOT                      NVARCHAR( 10), ' +
                        '@cLOC                      NVARCHAR( 10), ' +
                        '@cDropID                   NVARCHAR( 20), ' +
                        '@cStatus                   NVARCHAR( 1),  ' +
                        '@cCartonType               NVARCHAR( 10), ' +
                        '@nErrNo                    INT           OUTPUT,  ' +
                        '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                     EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                        @cWaveKey, @cLoadKey, @cConso_Orders, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                        @cLOT, @cLOC, @cDropID, '5', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  END
                  ELSE
                  BEGIN
                     EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                        @cStorerKey,
                        @cUserName,
                        @cFacility,
                        @cPutAwayZone,
                        @cPickZone,
                        @cConso_Orders,   -- Set orderkey = '' as conso pick
                        @cSKU,
                        @cPickSlipNo,
                        @cLOT,
                        @cLOC,
                        @cDropID,
                        '5',
                        @cLangCode,
                        @nErrNo        OUTPUT,
                        @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                        @nMobile, -- (Vicky06)
                        @nFunc    -- (Vicky06)
                  END

                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN
                     CLOSE CUR_LOOK4CONSO_ORDERS
                     DEALLOCATE CUR_LOOK4CONSO_ORDERS
                     GOTO Step_12_Fail
                  END
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders
               END
               CLOSE CUR_LOOK4CONSO_ORDERS
               DEALLOCATE CUR_LOOK4CONSO_ORDERS
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
               IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')
               BEGIN
                  SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                     ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                     ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                  SET @cSQLParms =    
                     '@nMobile                   INT,           ' +
                     '@nFunc                     INT,           ' +
                     '@cLangCode                 NVARCHAR( 3),  ' +
                     '@nStep                     INT,           ' +
                     '@nInputKey                 INT,           ' +
                     '@cFacility                 NVARCHAR( 5),  ' +
                     '@cStorerkey                NVARCHAR( 15), ' +
                     '@cWaveKey                  NVARCHAR( 10), ' +
                     '@cLoadKey                  NVARCHAR( 10), ' +
                     '@cOrderKey                 NVARCHAR( 10), ' +
                     '@cPutAwayZone              NVARCHAR( 10), ' +
                     '@cPickZone                 NVARCHAR( 10), ' +
                     '@cSKU                      NVARCHAR( 20), ' +
                     '@cPickSlipNo               NVARCHAR( 10), ' +
                     '@cLOT                      NVARCHAR( 10), ' +
                     '@cLOC                      NVARCHAR( 10), ' +
                     '@cDropID                   NVARCHAR( 20), ' +
                     '@cStatus                   NVARCHAR( 1),  ' +
                     '@cCartonType               NVARCHAR( 10), ' +
                     '@nErrNo                    INT           OUTPUT,  ' +
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                  EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                     @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                     @cLOT, @cLOC, @cDropID, '4', @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT 
               END
               ELSE
               BEGIN
                  EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                     @cStorerKey,
                     @cUserName,
                     @cFacility,
                     @cPutAwayZone,
                     @cPickZone,
                     @cOrderKey,
                     @cSKU,
                     @cPickSlipNo,
                     @cLOT,
                     @cLOC,
                     @cDropID,
                     '4',  -- Pick in progress
                     @cLangCode,
                     @nErrNo        OUTPUT,
                     @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                     @nMobile, -- (Vicky06)
                     @nFunc    -- (Vicky06)
               END

               IF @nErrNo <> 0
               BEGIN
                  GOTO Step_12_Fail
               END
            END

            -- BEGIN TRAN

            -- Update Picked to Confirm Picked
            SET @curUpdRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
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
                  SET @nErrNo = 65953
                  SET @cErrMsg = rdt.rdtgetmessage( 65953, @cLangCode, 'DSP') --'UPDPKLockFail'
                  ROLLBACK TRAN
                  GOTO Step_12_Fail
               END

               FETCH NEXT FROM @curUpdRPL INTO @nRowRef
            END
            CLOSE @curUpdRPL
            DEALLOCATE @curUpdRPL

            -- Release lock
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
                  CLOSE CUR_DEL
                  DEALLOCATE CUR_DEL
                  SET @nErrNo = 65954
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
                  ROLLBACK TRAN
                  GOTO Step_12_Fail
               END
               FETCH NEXT FROM CUR_DEL INTO @nRowRef
            END
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL

            COMMIT TRAN
         END   -- @cSHOWSHTPICKRSN = '1'
      END   -- IF @cOption = '1'

      IF @cOption = '2'
      BEGIN
         --cancel pick, rollback any partial scanned qty and return to screen 1
         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND AddWho = @cUserName
            AND Status = '1'
            AND PickQty > 0
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone)))
            BEGIN
               BEGIN TRAN

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
                     CLOSE CUR_DEL
                     DEALLOCATE CUR_DEL
                     SET @nErrNo = 65955
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_12_Fail
                  END
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef
               END
               CLOSE CUR_DEL
               DEALLOCATE CUR_DEL

               COMMIT TRAN
         END

         --         -- (ChewKP01)
         SET @nQtyToPick = 0
         SET @nTotalPickQty = 0
      END   -- IF @cOption = '2'

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN Step12_Update

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
            ROLLBACK TRAN Step12_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN 

            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO Quit
         END
         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      COMMIT TRAN Step12_Update
      WHILE @@TRANCOUNT > @nTranCount 
            COMMIT TRAN 

      SET @cOutField01 = '' -- WaveKey

      -- Prev next screen variable
      SET @nOutScn  = 1870
      SET @nOutStep = 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nOutScn  = @nMenu
      SET @nOutStep = 0
      SET @cOutField01 = '' -- WaveKey
   END

   GOTO Quit

   Step_12_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit
        
END
Quit:

GO