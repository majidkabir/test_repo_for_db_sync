SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_St5_7                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick step5 - step7                                  */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick_Adidas                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 07-Jul-2017 1.0  James       Created                                 */
/* 13-Aug-2019 1.1  James       Remove step 8 (james01)                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_St5_7] (
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
   IF @nStep = 5   GOTO Step_5 -- Scn = 1874. PickZone
   IF @nStep = 6   GOTO Step_6 -- Scn = 1875. Start Picking
   IF @nStep = 7   GOTO Step_7 -- Scn = 1876, 1882, 1887. Drop ID
END

/********************************************************************************
Step 5. Screen = 1874
   PICK ZONE     (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      SET @cPickZone = @cInField01

      -- If PickZone keyed in
      IF ISNULL(@cPickZone, '') <> ''
      BEGIN
         --  Check whether PickZone exists in orders
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON PD.LOC = L.LOC
            WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
               AND RPL.Status = '1'
               AND RPL.AddWho = @cUserName
               AND PD.Status = '0'
               AND L.Facility = @cFacility
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone)))
         BEGIN
            SET @nErrNo = 65923
            SET @cErrMsg = rdt.rdtgetmessage( 65923, @cLangCode, 'DSP') --'InvalidPKZone'
            GOTO Step_5_Fail
         END
      END

      --if input is blank, system assign a PickZone
      IF ISNULL(@cPickZone, '') = ''
      BEGIN
         SELECT TOP 1
            @cPickZone = L.PickZone
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
            AND RPL.Status = '1'
            AND RPL.AddWho = @cUserName
            AND PD.Status = '0'
            AND L.Facility = @cFacility
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND NOT EXISTS (  SELECT 1 FROM RDT.RDTPickLock RPL2 WITH (NOLOCK)
                              WHERE PD.OrderKey = RPL2.OrderKey
                              AND L.PickZone = RPL2.PickZone
                              AND RPL2.AddWho <> @cUserName
                              AND (( @nMultiStorer = 1) OR ( RPL2.StorerKey = @cStorerKey))
                              AND RPL2.Status = '1' )
         ORDER BY L.PickZone

         IF ISNULL(@cPickZone, '') = ''
         BEGIN
            -- No more pickzone in putawayzone to pick
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
               WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
                  AND Status = '1'
                  AND AddWho = @cUserName
                  AND PutawayZone <> '')
            BEGIN
               SET @nErrNo = 65924
               SET @cErrMsg = rdt.rdtgetmessage( 65924, @cLangCode, 'DSP') --'NoMorePKZone'
               GOTO Step_5_Fail
            END
         END
      END

      -- Check if PickZone locked by other user
      IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND Status = '1'
            AND AddWho <> @cUserName
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
            AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
            AND OrderKey IN (SELECT DISTINCT OrderKey FROM RDT.RDTPickLock WITH (NOLOCK) Where Status < '9' AND AddWho = @cUserName))
      BEGIN
         SET @nErrNo = 65925
         SET @cErrMsg = rdt.rdtgetmessage( 65925, @cLangCode, 'DSP') --'PKZoneLocked'
         GOTO Step_5_Fail
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN

      SAVE TRAN A
      -- (james16)
      SET @nNo_Of_Ord = 0
      SET @nNo_Of_Ord = rdt.RDTGetConfig( @nFunc, 'ClusterPickAutoInsOrd', @cStorerKey)

      IF @nNo_Of_Ord > 0
      BEGIN
         DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE AddWho = @cUserName
         AND   Status ='1'
         OPEN CUR_DEL
         FETCH NEXT FROM CUR_DEL INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE FROM RDT.RDTPICKLOCK WITH (ROWLOCK) WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN A
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

         DECLARE CUR_INS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT PD.OrderKey FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
         JOIN LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
            AND O.SOStatus <> '9'         -- tlting03 - just to make use of index.
            AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
            AND (( ISNULL(@cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
            AND PD.Status = '0'
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
            AND O.Facility = @cFacility      -- tlting03

         OPEN CUR_INS
         FETCH NEXT FROM CUR_INS INTO @cTemp_OrderKey
         WHILE @@FETCH_STATUS <> -1 AND @nNo_Of_Ord > 0
         BEGIN
            SET @cPickSlipNo = ''
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
               AND O.OrderKey = @cTemp_OrderKey
               AND PH.Status = '0'

            -- If not wave plan, look in loadplan
            IF ISNULL(@cPickSlipNo, '') = ''
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON PH.ExternOrderKey = O.LoadKey
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
               WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
                  AND O.OrderKey = @cTemp_OrderKey
                  AND PH.Status = '0'
            END

            -- Not in wave, not in load then check 4 discrete pickslip
            IF ISNULL(@cPickSlipNo, '') = ''
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader PH WITH (NOLOCK)
               WHERE PH.OrderKey = @cTemp_OrderKey
                  AND PH.Status = '0'
            END

            IF ISNULL(@cPickSlipNo, '') = ''
            BEGIN
               SET @nErrNo = 69358
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PKSLIPNOTPRINT'
               ROLLBACK TRAN A
               GOTO Step_5_Fail
            END

            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cTemp_OrderKey

            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
            SELECT UserDefine09,
                   LoadKey,
                   OrderKey,
                   '',
                   StorerKey,
                   @cPutAwayZone AS PutAwayZone,
                   @cPickZone AS PickZone,
                   '' AS PickDetailKey,
                   '' AS LOT,
                   '' AS LOC,
                   '1' AS Status,
                   @cUserName AS AddWho,
                   GETDATE() AS AddWho,
                   @cPickSlipNo AS PickSlipNo,
                   @nMobile as Mobile
            FROM dbo.Orders WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND OrderKey = @cTemp_OrderKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69357
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockOrdersFail'
               ROLLBACK TRAN A
               GOTO Step_5_Fail
            END

            SET @nNo_Of_Ord = @nNo_Of_Ord - 1

            FETCH NEXT FROM CUR_INS INTO @cTemp_OrderKey
         END
         CLOSE CUR_INS
         DEALLOCATE CUR_INS
      END

      -- Update PickZone to respective orders
      UPDATE RPL WITH (ROWLOCK) SET
         PickZone = @cPickZone
      FROM RDT.RDTPickLock RPL
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey) -- (Vicky01)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.Loc = L.Loc) -- (Vicky01)
      WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
         AND RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND L.Facility = @cFacility
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 65926
         SET @cErrMsg = rdt.rdtgetmessage( 65926, @cLangCode, 'DSP') --'UPDPKLockFail'
         ROLLBACK TRAN A
         GOTO Step_5_Fail
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN A

      SELECT @nOrderCnt      = COUNT (DISTINCT PD.OrderKey),
             @nSKUCnt        = COUNT (DISTINCT PD.SKU),
             @nTTL_Alloc_Qty = SUM(PD.Qty)
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.Loc = L.Loc)
      WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
         AND RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
         AND L.Facility = @cFacility

      SET @cDropID = ''

      -- Prep next screen var
      SET @cOutField01 = '' --Option
      SET @cOutField02 = @cWaveKey
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cPutAwayZone
      SET @cOutField05 = @cPickZone
      SET @cOutField06 = @nOrderCnt
      SET @cOutField07 = @nSKUCnt
      SET @cOutField08 = @nTTL_Alloc_Qty

      -- Go to next screen
      SET @nOutScn  = 1875
      SET @nOutStep = 6

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
      SET @cOutField07 = @cPutAwayZone01
      SET @cOutField08 = @cPutAwayZone02
      SET @cOutField09 = @cPutAwayZone03
      SET @cOutField10 = @cPutAwayZone04
      SET @cOutField11 = @cPutAwayZone05

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nOutScn  = 1873
      SET @nOutStep = 4
   END

   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 6. Screen = 1875
   Option    (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 65927
         SET @cErrMsg = rdt.rdtgetmessage( 65927, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = '1'
      BEGIN

         BEGIN TRAN
         -- Scan in pickslip if not yet scan
         IF ISNULL(@cWavekey, '') <> ''
         BEGIN
            INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
            SELECT DISTINCT PH.PickHeaderKey, GETDATE(), @cUserName, NULL, @cUserName
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON RPL.OrderKey = O.OrderKey -- (Vicky03)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)     -- (james09)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON O.Userdefine09 = PH.WaveKey AND O.OrderKey = PH.OrderKey
            WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
               AND RPL.Status = '1'
               AND RPL.AddWho = @cUserName
               AND RPL.StorerKey = @cStorerKey
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
               AND NOT EXISTS (SELECT 1 FROM dbo.PickingInfo PIF WITH (NOLOCK)
                       WHERE PIF.PickSlipNo = PH.PickHeaderKey )
         END
         ELSE
         BEGIN
            -- Check if it is Conso pickslip (james06)
            IF EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
               WHERE ExternOrderKey = @cLoadKey
               AND   ISNULL(RTRIM(Orderkey), '') = '' ) AND ISNULL( @cLoadKey, '') <> ''
            BEGIN
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
               SELECT DISTINCT PH.PickHeaderKey, GETDATE(), @cUserName, NULL, @cUserName
               FROM RDT.RDTPickLock RPL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON RPL.OrderKey = O.OrderKey -- (Vicky03)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)     -- (james09)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON O.LoadKey = PH.ExternOrderKey
               WHERE (( @nMultiStorer = 1) OR ( OD.StorerKey = @cStorerKey))
                  AND RPL.Status = '1'
                  AND RPL.AddWho = @cUserName
                  AND (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
                  AND NOT EXISTS (SELECT 1 FROM dbo.PickingInfo PIF WITH (NOLOCK)
                          WHERE PIF.PickSlipNo = PH.PickHeaderKey )
            END
            ELSE
            BEGIN
               DECLARE @cOrderKey2Scanin NVARCHAR( 10)
               DECLARE CUR_SCANIN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT DISTINCT OrderKey
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               OPEN CUR_SCANIN
               FETCH NEXT FROM CUR_SCANIN INTO @cOrderKey2Scanin
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SELECT @cPickHeaderKey = PickHeaderKey
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey2Scanin

                  IF ISNULL( @cPickHeaderKey, '') <> '' AND NOT EXISTS 
                  ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickHeaderKey)
                  BEGIN
                     INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho) VALUES 
                     (@cPickHeaderKey, GETDATE(), @cUserName, NULL, @cUserName)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 65928
                        SET @cErrMsg = rdt.rdtgetmessage( 65928, @cLangCode, 'DSP') --'Scan In Fail'
                        CLOSE CUR_SCANIN
                        DEALLOCATE CUR_SCANIN
                        ROLLBACK TRAN
                        GOTO Step_6_Fail
                     END
                  END                  
                  FETCH NEXT FROM CUR_SCANIN INTO @cOrderKey2Scanin
               END
               CLOSE CUR_SCANIN
               DEALLOCATE CUR_SCANIN
            END
         END

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65928
            SET @cErrMsg = rdt.rdtgetmessage( 65928, @cLangCode, 'DSP') --'Scan In Fail'
            ROLLBACK TRAN
            GOTO Step_6_Fail
         END

         COMMIT TRAN

         SET @cDropID = ''

         -- If pick by conso then look for all orders
         -- and group by logicalloc, loc, sku, lot2, lot4
         IF @cLoadDefaultPickMethod = 'C'
         BEGIN
            SELECT TOP 1
               @cLOC = PD.Loc,
               @cSKU = PD.SKU,
               @cLottable02 = LA.Lottable02,
               @dLottable04 = LA.Lottable04
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE RPL.StorerKey = @cStorerKey
               AND RPL.Status = '1'
               AND RPL.AddWho = @cUserName
               AND (( ISNULL( @cWaveKey, '') = '') OR ( RPL.WaveKey = @cWaveKey))
               AND (( ISNULL(@cLoadKey, '') = '') OR ( RPL.LoadKey = @cLoadKey))
               AND PD.Status = '0'
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
               AND LOC.Facility = @cFacility
            GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
            ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 65975
               SET @cErrMsg = rdt.rdtgetmessage( 65975, @cLangCode, 'DSP') --'No Record'
               GOTO Step_6_Fail
            END

            DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT RowRef FROM RDT.RDTPICKLOCK WITH (NOLOCK) 
            WHERE  AddWho = @cUserName 
            AND    Status = '1'
            OPEN CUR_DEL
            FETCH NEXT FROM CUR_DEL INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               DELETE FROM RDT.RDTPICKLOCK WITH (ROWLOCK) WHERE RowRef = @nRowRef
               FETCH NEXT FROM CUR_DEL INTO @nRowRef
            END
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL

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
                  GOTO Step_6_Fail
               END

               COMMIT TRAN

               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
            END
            CLOSE CUR_LOOK4CONSO_ORDERS
            DEALLOCATE CUR_LOOK4CONSO_ORDERS
         END
         ELSE
         BEGIN
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
               SET @nErrNo = 0
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
            END

            IF @nErrNo <> 0
               GOTO Quit

            -- Get the Lottables
            SELECT
               @cLottable02 = Lottable02,
               @dLottable04 = Lottable04
            FROM dbo.LotAttribute WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
               AND SKU = @cSKU
               AND LOT = @cLot

            BEGIN TRAN

            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
               LOT = @cLot,
               LOC = @cLoc,
               SKU = @cSKU,
               DropID = @cDropID,
               PackKey = @cCartonType,                
               Lottable02 = @cLottable02,
               Lottable04 = @dLottable04,
               OrderLineNumber = LEFT( OrderLineNumber + '%%', 5)  -- SOS232145
            -- PickSlipNo = @cPickSlipNo
            WHERE OrderKey = @cOrderKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65929
               SET @cErrMsg = rdt.rdtgetmessage( 65929, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN
               GOTO Step_6_Fail
            END

            COMMIT TRAN
         END

         SET @nActQty = 0
         SET @nQtyToPick = '0'

         IF @cClusterPickPrintLabel = '1'
         BEGIN
            SET @cOutField01 = ''

            -- Go to next screen
            SET @nOutScn  = 1885
            SET @nOutStep = 13
         END
         ELSE
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'
            BEGIN
               SET @cOutField01 = @cLOC
               SET @cOutField02 = ''

               -- Go to next screen
               SET @nOutScn  = 1892
               SET @nOutStep = 19

               GOTO Quit
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

               -- (james42)
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickCaptureCtnType', @cStorerKey) NOT IN ('', '0')
               BEGIN
                  SET @cOutField10 = 'CTN TYPE:'   
                  SET @cOutField11 = ''   
               END

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

               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               IF RDT.RDTGetConfig( @nFunc, 'ClusterPickPromptNewDropID', @cStorerKey) = 1
               BEGIN
                  SELECT @cDropID = DropID FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
               SET @cOutField11 = ''
               SET @cOutField12 = ''

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

      IF @cOption = '2'
      BEGIN
         -- Release locked record
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN Step6_Update

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
               ROLLBACK TRAN Step6_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

               CLOSE CUR_DEL
               DEALLOCATE CUR_DEL
               SET @nErrNo = 65930
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
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
               ROLLBACK TRAN Step6_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN 

               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               SET @nErrNo = 65930
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
               GOTO Quit
            END
            FETCH NEXT FROM CUR_UPD INTO @nRowRef
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         COMMIT TRAN Step6_Update
         WHILE @@TRANCOUNT > @nTranCount 
               COMMIT TRAN 

         -- Go back to first screen
         SET @nOutScn  = 1870
         SET @nOutStep = 1

         SET @cDropID = ''
         SET @cOutField01 = ''
      END

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = '' --Option
      SET @cOutField02 = @cWaveKey
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cPutAwayZone
      SET @cOutField05 = @nOrderCnt
      SET @cOutField06 = @nTTL_Alloc_Qty

      SET @nOutScn  = 1874
      SET @nOutStep = 5
   END

   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 7. Screen = 1876, 1882
   Drop ID     (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      IF @nFunc = 1826
      BEGIN
         SET @cDropID = UPPER(@cInField09) -- (Vicky01)
         SET @cCartonType = @cInField11    -- (james42)
      END
      ELSE
      BEGIN
         IF RDT.RDTGetConfig( @nFunc, 'ClusterPickPromptNewDropID', @cStorerKey) = 1
         BEGIN
            IF @cInField10 <> @cDropID
            BEGIN
               SET @cDropID = UPPER(@cInField10)

               SET @cOutField01 = '' --Option

               -- Save current screen no
               SET @nCurScn = @nInScn
               SET @nCurStep = @nInStep

               -- Go to STD short pick screen
               SET @nOutScn = 1890
               SET @nOutStep = 16

               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtBlankDropID', @cStorerKey) = '0'
            OR ISNULL( @cInField09, '') <> ''
               SET @cDropID = UPPER(@cInField10)

            SET @cCartonType = @cInField12    -- (james42)
         END
      END

      -- If config turned on, DropID field is mandatory
      IF @cClusterPickScanDropID = '1' AND ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 65961
         SET @cErrMsg = rdt.rdtgetmessage( 65961, @cLangCode, 'DSP') --DropID needed
         GOTO Step_7_Fail
      END

      --if DropID scanned, check whether the prefix is 'ID'
      IF ISNULL(@cDropID, '') <> ''
      BEGIN
         IF @cNot_Check_ID_Prefix <> '1'
         BEGIN
            IF SUBSTRING(@cDropID, 1, 2) <> 'ID'
            BEGIN
               SET @nErrNo = 65931
               SET @cErrMsg = rdt.rdtgetmessage( 65931, @cLangCode, 'DSP') --Invalid DropID
               GOTO Step_7_Fail
            END
         END

         --(james01)
         -- Stored Proc to validate Drop ID by storerkey
         SET @cCheckDropID_SP = rdt.RDTGetConfig( 0, 'CheckDropID_SP', @cStorerKey)

         IF ISNULL(@cCheckDropID_SP, '') NOT IN ('', '0')
         BEGIN
            SET @cSQLStatement = N'EXEC rdt.' + RTRIM(@cCheckDropID_SP) +
                                  ' @cFacility, @cStorerkey, @cOrderkey, @cDropID, @nValid OUTPUT, @nErrNo OUTPUT,  @cErrMsg OUTPUT'

            SET @cSQLParms = N'@cFacility    NVARCHAR( 5),         ' +
                              '@cStorerkey   NVARCHAR( 15),        ' +
                              '@cOrderkey    NVARCHAR( 10),        ' +
                              '@cDropID      NVARCHAR( 20),        ' +
                              '@nValid       INT      OUTPUT,  ' +
                              '@nErrNo       INT      OUTPUT,  ' +
                              '@cErrMsg      NVARCHAR(20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
                                 @cFacility,
                                 @cStorerKey,
                                 @cOrderKey,
                                 @cDropID,
                                 @nValid  OUTPUT,
                                 @nErrNo  OUTPUT,
                                 @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_7_Fail
            END

            IF @nValid = 0
            BEGIN
               SET @nErrNo = 65962
               SET @cErrMsg = rdt.rdtgetmessage( 65962, @cLangCode, 'DSP') --Invalid DropID
               GOTO Step_7_Fail
            END
         END--(james01)

         -- (james16)
         -- If config AutoPromptDropID turned on then check if this dropid exists in other orders or not
         -- because 1 dropid not allow mix orders
         IF @cAutoPromptDropID = 1
            AND rdt.RDTGetConfig( @nFunc, 'ClusterPickDropIDMixOrd', @cStorerKey) <> '1'
            AND EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  -- (Chee01)
                        JOIN dbo.DropID D WITH (NOLOCK) ON (PD.DropID = D.DropID)            -- (Chee01)
                        WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
                          AND PD.DropID = @cDropID
                          AND PD.OrderKey <> @cOrderKey
                          AND D.Status < '9'                     -- (Chee01)
                          AND PH.PickHeaderKey = D.PickSlipNo)   -- (Chee01)
         BEGIN
            SET @nErrNo = 69359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CANNOT MIX ORD
            GOTO Step_7_Fail
         END

         -- Check from id format (james49)
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
         BEGIN
            SET @nErrNo = 104001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_7_Fail
         END
      END

      -- (james44)
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
            GOTO Step_7_Fail
      END
         
      -- (james42)
      -- Get config for carton type capture
      -- 0 = Off & no need capture carton type
      -- 1 = On & capture cartontype is req
      -- 2 = On but capture carton type is optional
      SET @cCaptureCtnType = RDT.RDTGetConfig( @nFunc, 'ClusterPickCaptureCtnType', @cStorerKey) 

      IF @cCaptureCtnType NOT IN ('', '0')
      BEGIN
         IF @cCaptureCtnType = '1'
         BEGIN
            IF ISNULL( @cCartonType, '') = ''
            BEGIN
               SET @nErrNo = 69389
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn Type Req
               GOTO Step_7_Fail
            END
         END

         IF ISNULL( @cCartonType, '') <> ''
         BEGIN
            IF NOT EXISTS ( SELECT 1 
                  FROM dbo.Cartonization CZ WITH (NOLOCK)
                  JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
                  WHERE StorerKey = @cStorerKey
                  AND   CartonType = @cCartonType)
            BEGIN
               SET @nErrNo = 69390
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Ctn Type
               GOTO Step_7_Fail
            END
         END
      END

      IF @cLoadDefaultPickMethod = 'C'
      BEGIN
         BEGIN TRAN

         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            DropID = @cDropID,
            PackKey = @cCartonType             
         WHERE StorerKey = @cStorerKey
            AND LoadKey = @cLoadKey
            AND Status = '1'
            AND AddWho = @cUserName
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            AND SKU = @cSKU
            AND PickQty = 0

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65977
            SET @cErrMsg = rdt.rdtgetmessage( 65977, @cLangCode, 'DSP') --'UPDPKLockFail'
            ROLLBACK TRAN
            GOTO Step_7_Fail
         END

         DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT OrderKey, SUM(PickQty) FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Status = '1'
            AND AddWho = @cUserName
            AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
            AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            AND SKU = @cSKU
            AND PickQty > 0
         GROUP BY OrderKey
         OPEN CUR_LOOK4CONSO_ORDERS
         FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @nPickQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @nPD_Qty = SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND PD.OrderKey = @cConso_Orders
               AND PD.Status = '0'
               AND LOC.Facility = @cFacility
               AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
               AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

            IF @nPickQty < @nPD_Qty
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE OrderKey = @cConso_Orders
                     AND StorerKey = @cStorerKey      --tlting03
                     AND Status = '1'
                     AND AddWho = @cUserName
                     AND (( ISNULL(@cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
                     AND SKU = @cSKU
                     AND DropID = @cDropID )
               BEGIN
                  INSERT INTO RDT.RDTPickLock
                  (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                  , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
                  SELECT TOP 1 WaveKey, LoadKey, Orderkey, '**' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                       , LOT, LOC, Lottable02, Lottable04, '1', AddWho, AddDate, @cDropID AS DropID, @cPickSlipNo AS PickSlipNo, @nMobile as Mobile
                       , @cCartonType AS PackKey                       
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE OrderKey = @cConso_Orders
                     AND StorerKey = @cStorerKey    -- tlting03
                     AND SKU = @cSKU
                     AND Status = '1'
                     AND Addwho = @cUserName

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 65978
                     SET @cErrMsg = rdt.rdtgetmessage( 65978, @cLangCode, 'DSP') --'UPDPKLockFail'
                     ROLLBACK TRAN
                     GOTO Step_7_Fail
                  END
               END
            END

            FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @nPickQty
         END
         CLOSE CUR_LOOK4CONSO_ORDERS
         DEALLOCATE CUR_LOOK4CONSO_ORDERS

         COMMIT TRAN

         SELECT @nTTL_Qty = SUM(PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
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
                        AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey)
            -- AND PD.OrderKey in (SELECT DISTINCT PickDetailKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName AND Status = '1')
            -- tlitng03 Duplicate check
            --AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = PD.StorerKey
            --               AND OrderKey = PD.OrderKey AND ADDWHO = @cUserName AND Status = '1') -- SOS# 176144

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
               AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey)
      END -- IF @cLoadDefaultPickMethod = 'C'
      ELSE
      BEGIN
         SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         IF EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
               AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               AND SKU = @cSKU
               AND PickQty = '0' ) -- Update by Bryan, update dropid if last carton is not pick yet
         BEGIN
            BEGIN TRAN

            UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
               DropID  = @cDropID,
               PackKey = @cCartonType               
            WHERE OrderKey = @cOrderKey
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND Status = '1'
               AND AddWho = @cUserName
               AND ISNULL(RTRIM(DropID),'') <> @cDropID
               AND PickQty = '0' -- SOS# 208635

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65932
               SET @cErrMsg = rdt.rdtgetmessage( 65932, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN
               GOTO Step_7_Fail
            END

            COMMIT TRAN
         END
         --ELSE --SOS# 173419
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK) --SOS# 173419
         WHERE OrderKey = @cOrderKey
            AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
            AND Status = '1'
            AND AddWho = @cUserName
            AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
            AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            AND SKU = @cSKU
            AND ISNULL(RTRIM(DropID),'') = ISNULL(RTRIM(@cDropID),''))
         BEGIN
            -- If DropID not exists, insert new line
            INSERT INTO RDT.RDTPickLock
            (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
            , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
            SELECT TOP 1 WaveKey, LoadKey, Orderkey, '##' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                 , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, @cDropID AS DropID, @cPickSlipNo AS PickSlipNo, @nMobile as Mobile
                 , @cCartonType AS PackKey                  
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND (( ISNULL( @cWaveKey, '') = '') OR ( WaveKey = @cWaveKey))
               AND (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               AND SKU = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65933
               SET @cErrMsg = rdt.rdtgetmessage( 65933, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN
               GOTO Step_7_Fail
            END
         END

         -- Get the total oustanding qty for orderkey + putawayzone + pickzone
         SELECT @nTTL_Qty = ISNULL( SUM(PD.QTY), 0)
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
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
            AND EXISTS (SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE storerkey = RPL.StorerKey
                           AND OrderKey = PD.OrderKey
                           AND ADDWHO = @cUserName ) -- SOS# 176144
            --AND PD.OrderKey in (SELECT DISTINCT OrderKey FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = @cUserName) -- SOS# 176144


         -- Get the total allocated qty for LOC + SKU + OrderKey
         SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND OrderKey = @cOrderKey
            AND Status = '0'
            AND Lot = @cLOT
      END

      -- ExtendedUpdate (james45)
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
         BEGIN
            ROLLBACK TRAN
            GOTO Step_7_Fail
         END
      END

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
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

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
         IF @nTotalPickQty > 0
            SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
         ELSE
            SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) 

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

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james36)
      SET @cPickNotFinish = ''
      IF rdt.RDTGetConfig( @nFunc, 'DISPLAYPICKNOTFINISH', @cStorerKey) = 1
      BEGIN
         IF EXISTS ( SELECT 1 from dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                     JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                     WHERE (( @nMultiStorer = 1 AND PD.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND PD.StorerKey = @cStorerKey))
                     AND   PD.Status = '0' 
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

      SET @cOutField01 = ''
      SET @cOutField02 = @cWaveKey
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cPutAwayZone
      SET @cOutField05 = @cPickZone
      SET @cOutField06 = @nOrderCnt
      SET @cOutField07 = @nTTL_Alloc_Qty
      SET @cOutField08 = CASE WHEN ISNULL( @cPickNotFinish, '') <> '' THEN @cPickNotFinish ELSE '' END

      -- Goto exit picking screen
      SET @nOutScn  = 1880
      SET @nOutStep = 11
   END

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
            GOTO Step_7_Fail  
      END

      SET @nCurScn = @nInScn
      SET @nCurStep = @nInStep

      SET @cOutField01 = rdt.RDTGetConfig( @nFunc, 'FunctionKey', @cStorerKey)
      --SET @nScn = @nOutScn
      --SET @nStep = @nOutStep
   END

   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOutField10 = ''   --DropID
   END

END
GOTO Quit

END
Quit:

GO