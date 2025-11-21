SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_St8                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick step8                                          */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick_Adidas                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-Aug-2019 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_St8] (
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
   IF @nStep = 8   GOTO Step_8 -- Scn = 1877, 1883, 1888. SKU, Qty
END

/********************************************************************************
Step 8. Screen = 1877, 1883
   SKU/UPC     (field04, input)
   QTY         (field13, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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
      SET @c_LabelNo = ''

      -- If len of the input is > 20 characters then this is not a SKU
      -- use label decoding
      IF LEN(ISNULL(@cInField04, '')) > 20 AND @nFunc = 1826
      BEGIN
         SET @c_LabelNo = @cInField04
      END

      IF LEN(ISNULL(@cInField03, '')) > 20 AND @nFunc IN (1827, 1828)
      BEGIN
         SET @c_LabelNo = @cInField03
      END

      SET @cScanLOT02 = rdt.RDTGetConfig( @nFunc, 'SCANLOT02', @cStorerKey)

      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
      IF @cDecodeSP = '0'
         SET @cDecodeSP = ''

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         SET @cBarcode = CASE WHEN @nFunc IN (1827, 1828) THEN @cInField03 ELSE @cInField04 END
         SET @cUPC = ''

         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            SET @cActSKU = @cUPC
            SET @cActQty = @nQTY
         END
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutawayZone, @cPickZone, ' +
               ' @cDropID        OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' +                
               ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cWaveKey       NVARCHAR( 10), ' +
               ' @cLoadKey       NVARCHAR( 10), ' +
               ' @cOrderKey      NVARCHAR( 10), ' +
               ' @cPutawayZone   NVARCHAR( 10), ' +
               ' @cPickZone      NVARCHAR( 10), ' +
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY           INT            OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, 
               @cWaveKey, @cLoadKey, @cOrderKey, @cPutawayZone, @cPickZone,
               @cDropID       OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,               
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            SET @cActSKU = @cUPC
            SET @cActQty = @nQTY            
         END
      END   -- End for DecodeSP
      ELSE
      BEGIN
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
         IF @cDecodeLabelNo = '0'
            SET @cDecodeLabelNo = ''

         IF ISNULL(@cDecodeLabelNo, '') <> ''
            SET @c_LabelNo = CASE WHEN @nFunc IN (1827, 1828) THEN @cInField03 ELSE @cInField04 END

         -- If len of the input is > 20 characters then this is not a SKU
         -- use label decoding
         IF ISNULL(@c_LabelNo, '') <> '' AND ISNULL(@cDecodeLabelNo, '') <> ''
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @c_LabelNo
               ,@c_Storerkey  = @cStorerKey
               ,@c_ReceiptKey = @nMobile
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
               SET @cErrMsg = @cErrMsg
               IF @nFunc = 1826
                  SET @cOutField04 = ''
               ELSE
                  SET @cOutField03 = ''

               IF @cClusterPickLockQtyToPick = '1'
               BEGIN
                  SET @cFieldAttr13 = 'O'
                  SET @cInField13 = @cDefaultPickQty
               END

               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Quit
            END

            SET @cActSKU = @c_oFieled01
            SET @cActQty = @c_oFieled05
         END
      END   -- End for DecodeLabelNo

      IF @nFunc = 1826
      BEGIN
         IF LEN(ISNULL(@cInField04, '')) > 20
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = CASE WHEN ISNULL(LTRIM(RTRIM(@cActQty)), '') IN ('', '0') 
                                THEN @cInField13 ELSE @cActQty END   -- (james38)
         END
         ELSE IF ISNULL(@c_LabelNo, '') <> '' AND ISNULL(@cDecodeLabelNo, '') <> ''
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = @cInField13
         END
         ELSE IF ISNULL(@cBarcode, '') <> '' AND ISNULL(@cDecodeSP, '') <> ''
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = CASE WHEN ISNULL(LTRIM(RTRIM(@cActQty)), '') IN ('', '0') 
                                THEN @cInField13 ELSE @cActQty END 
         END
         ELSE
         BEGIN
            SET @cActSKU = @cInField04
            SET @cActQty = @cInField13
         END
      END

      IF @nFunc IN (1827, 1828)
      BEGIN
         IF LEN(ISNULL(LTRIM(RTRIM(@cActSKU)), '')) > 20
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = CASE WHEN ISNULL(LTRIM(RTRIM(@cActQty)), '') IN ('', '0') 
                                THEN @cInField13 ELSE @cActQty END   -- (james38)
         END
         ELSE IF ISNULL(@c_LabelNo, '') <> '' AND ISNULL(@cDecodeLabelNo, '') <> ''
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = @cInField13
         END
         ELSE IF ISNULL(@cBarcode, '') <> '' AND ISNULL(@cDecodeSP, '') <> ''
         BEGIN
            SET @cActSKU = ISNULL(LTRIM(RTRIM(@cActSKU)), '')
            SET @cActQty = CASE WHEN ISNULL(LTRIM(RTRIM(@cActQty)), '') IN ('', '0') 
                                THEN @cInField13 ELSE @cActQty END 
         END
         ELSE
         BEGIN
            SET @cActSKU = @cInField03
            SET @cActQty = @cInField13
         END
      END

      -- If input is blank, goto Confirm Short Pick
      IF ISNULL(@cActSKU, '') = ''
      BEGIN
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

         IF @nFunc = 1826
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
            SET @cOutField03 = @cOrderKey
            SET @cOutField04 = @cExternOrderkey
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cRetailSKU
            SET @cOutField07 = SUBSTRING(@cSKU_Descr,  1, 20)
            SET @cOutField08 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField09 = SUBSTRING(@cSKU_Descr, 41, 20)
            SET @cOutField10 = @cStyle
            SET @cOutField11 = @cColor + @cSize
            SET @cOutField12 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
                               THEN @cTemp_String ELSE @cColor_Descr END

            -- Go to next screen
            SET @nOutScn  = 1878
            SET @nOutStep = 9
         END
         ELSE
         IF @nFunc = 1827
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
            SET @cOutField03 = @cOrderKey
            SET @cOutField04 = @cExternOrderkey
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cRetailSKU
            SET @cOutField07 = SUBSTRING(@cSKU_Descr,  1, 20)
            SET @cOutField08 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField09 = SUBSTRING(@cSKU_Descr, 41, 20)
            SET @cOutField10 = @cLottable02
            SET @cOutField11 = rdt.rdtFormatDate(@dLottable04)

            -- Go to next screen
            SET @nOutScn  = 1884
            SET @nOutStep = 9
         END
         ELSE
         IF @nFunc = 1828  -- (james07)
         BEGIN
            SET @cOutField01 = ''
            SET @cOutField02 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
            SET @cOutField03 = @cLoadKey
            SET @cOutField04 = ''
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cRetailSKU
            SET @cOutField07 = SUBSTRING(@cSKU_Descr,  1, 20)
            SET @cOutField08 = SUBSTRING(@cSKU_Descr, 21, 20)
            SET @cOutField09 = SUBSTRING(@cSKU_Descr, 41, 20)
            SET @cOutField10 = @cLottable02
            SET @cOutField11 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField12 = ''
            SET @cOutField13 = ''

            -- Go to next screen
            SET @nOutScn  = 1889
            SET @nOutStep = 9
         END

         -- SOS197651 If config setup allow to skip SKU (james11)
         -- Show different option when config ClusterPickConfirmSkipSKU is ON (james18)
         SET @cOutField13 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmSkipSKU', @cStorerKey) = 1 THEN
                               ( CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowSkipSKU', @cStorerKey) = 1
                                 THEN '1=YES 2=PKBAL 3=SKIP'
                                 ELSE '1 = YES 2 = NO'
                                 END)
                                 ELSE
                               ( CASE WHEN rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowSkipSKU', @cStorerKey) = 1
                                 THEN '1=YES 2=NO 3=SKIP'
                                 ELSE '1 = YES 2 = NO'
                                 END)
                           END

         GOTO Quit
      END

      IF @nMultiStorer = '1'
         GOTO VALIDATE_QTY

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
            -- SOS 197651 If config setup show error message in new screen (james11)
            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '65934 Invalid SKU'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END

               IF @nFunc = 1826
               BEGIN
                  SET @cOutField04 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 4
               END
               ELSE
               BEGIN
                  SET @cOutField03 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 3
               END

               IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
               BEGIN
                  SET @cFieldAttr13 = 'O'
                  SET @cInField13 = @cDefaultPickQty
               END
               GOTO Quit
            END

            SET @nErrNo = 65934
            SET @cErrMsg = rdt.rdtgetmessage( 65934, @cLangCode, 'DSP') --'Invalid SKU'
            IF @nFunc = 1826
            BEGIN
               SET @cOutField04 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 4
            END
            ELSE
            BEGIN
               SET @cOutField03 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END

            IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
            BEGIN
               SET @cFieldAttr13 = 'O'
               SET @cInField13 = @cDefaultPickQty
            END
            GOTO Quit
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 65935
            SET @cErrMsg = rdt.rdtgetmessage( 65935, @cLangCode, 'DSP') --'SameBarCodeSKU'
            IF @nFunc = 1826
            BEGIN
               SET @cOutField04 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 4
            END
            ELSE
            BEGIN
               SET @cOutField03 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END

            IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
            BEGIN
               SET @cFieldAttr13 = 'O'
               SET @cInField13 = @cDefaultPickQty
            END
            GOTO Quit
         END


         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cActSKU       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         IF @cActSKU <> @cSKU
         BEGIN
            -- SOS 197651 If config setup show error message in new screen (james11)
            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '65936 Different SKU'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END

               IF @nFunc = 1826
               BEGIN
                  SET @cOutField04 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 4
               END
               ELSE
               BEGIN
                  SET @cOutField03 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 3
               END

               IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
               BEGIN
                  SET @cFieldAttr13 = 'O'
                  SET @cInField13 = @cDefaultPickQty
               END
               GOTO Quit
            END

            SET @nErrNo = 65936
            SET @cErrMsg = rdt.rdtgetmessage( 65936, @cLangCode, 'DSP') --'Different SKU'
            IF @nFunc = 1826
            BEGIN
               SET @cOutField04 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 4
            END
            ELSE
            BEGIN
               SET @cOutField03 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END

            IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
            BEGIN
               SET @cFieldAttr13 = 'O'
               SET @cInField13 = @cDefaultPickQty
            END
            GOTO Quit
         END

         IF ISNULL( @cScanLOT02, '') = '1' AND @cFieldAttr06 = '' AND ISNULL( @cInField06, '') = ''   --(james32)
         BEGIN
            IF @nFunc = 1826
               SET @cOutField04 = @cInField04
            ELSE
               SET @cOutField03 = @cInField03
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END
      END

      -- Validate Lot02 (james32)
      IF ISNULL( @cScanLOT02, '') = '' OR @cScanLOT02 <> '1'
         SET @cScanLOT02 = '0'
      ELSE
      BEGIN
         IF ISNULL( @cInField06, '') = ''
         BEGIN
            SET @nErrNo = 69384
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOT02 REQ'
            SET @cOutField06 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6
            IF @nFunc = 1826
               SET @cOutField04 = @cInField04
            ELSE
               SET @cOutField03 = @cInField03

            GOTO Quit
         END

         -- Get the Lottable02
         SELECT
            @cLottable02 = Lottable02
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND SKU = @cSKU
            AND LOT = @cLot

         IF @cInField06 <> @cLottable02
         BEGIN
            SET @nErrNo = 69385
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID LOT02'
            SET @cOutField06 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6
            IF @nFunc = 1826
               SET @cOutField04 = @cInField04
            ELSE
               SET @cOutField03 = @cInField03

            GOTO Quit
         END

         IF @cPrefUOM <> '6' AND @cFieldAttr15 = '' AND ISNULL( @cInField15, '') = ''  -- (james32)
         BEGIN
            -- If carton field is blank then check if qty to pick is it > 1 carton
            -- If yes then quit and force them use case field to enter (james35)
            SELECT @nPrefQty = ISNULL ( CASE @cPrefUOM
                                    WHEN '2' THEN Pack.CaseCNT
                                    WHEN '3' THEN Pack.InnerPack
                                    WHEN '6' THEN Pack.QTY
                                    WHEN '1' THEN Pack.Pallet
                                    WHEN '4' THEN Pack.OtherUnit1
                                    WHEN '5' THEN Pack.OtherUnit2 END, 1)
            FROM SKU SKU (NOLOCK)
            JOIN PACK PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE SKU = @cSKU
            AND (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))

            IF @nPrefQty < CAST( @cActQty AS INT)
            BEGIN
               IF @nFunc = 1826
                  SET @cOutField04 = @cInField04
               ELSE
                  SET @cOutField03 = @cInField03

               SET @cOutField06 = @cInField06

               EXEC rdt.rdtSetFocusField @nMobile, 15
               GOTO Quit
            END
         END
      END

      VALIDATE_QTY:
      SET @nPrefQty = 0
      SET @cPrefQty = ''
      IF @cPrefUOM <> '6' AND @cFieldAttr15 = ''   -- (james32)
      BEGIN
         SET @cPrefQty = @cInField15

         IF RDT.rdtIsValidQTY( @cPrefQty, 1) <> 0
            SELECT @nPrefQty = CAST( @cPrefQty AS INT) * ISNULL ( CASE @cPrefUOM
                                    WHEN '2' THEN Pack.CaseCNT
                                    WHEN '3' THEN Pack.InnerPack
                                    WHEN '6' THEN Pack.QTY
                                    WHEN '1' THEN Pack.Pallet
                                    WHEN '4' THEN Pack.OtherUnit1
                                    WHEN '5' THEN Pack.OtherUnit2 END, 1)
            FROM SKU SKU (NOLOCK)
            JOIN PACK PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE SKU = @cSKU
            AND (( @nMultiStorer = 1 AND SKU.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND SKU.StorerKey = @cStorerKey))

         IF @cFieldAttr13 = '' AND ISNULL( @cInField13, '') = ''  AND @cOutField15 = '' -- (james32)
         BEGIN
            IF @nFunc = 1826
               SET @cOutField04 = @cInField04
            ELSE
               SET @cOutField03 = @cInField03

            SET @cOutField06 = @cInField06
            SET @cOutField15 = @cInField15

            EXEC rdt.rdtSetFocusField @nMobile, 13
            GOTO Quit
         END
      END

      IF @cActQty = '0'
      BEGIN
         IF @cPrefQty = '' OR @cPrefQty = '0'
         BEGIN
            SET @cActQty = ''
            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '65937 QTY needed'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 65937
               SET @cErrMsg = rdt.rdtgetmessage( 65937, @cLangCode, 'DSP') --'QTY needed'
            END
            SET @cOutField13 = @cDefaultPickQty
            EXEC rdt.rdtSetFocusField @nMobile, 13
            GOTO Quit
         END
      END

      IF @cActQty  = ''
         SET @cActQty  = '0' --'Blank taken as zero'

      IF RDT.rdtIsValidQTY( @cActQty, 1) = 0
      BEGIN
         IF @cPrefQty = '' OR @cPrefQty = '0'
         BEGIN
            IF ISNULL(@cActSKU, '') <> ''
            BEGIN
               IF @nFunc = 1826
               BEGIN
                  SET @cOutField04 = @cActSKU
               END
               ELSE
               IF @nFunc in (1827, 1828)
               BEGIN
                  SET @cOutField03 = @cActSKU
               END
            END

            SET @cActQty = ''
            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '65938 Invalid QTY'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 65938
               SET @cErrMsg = rdt.rdtgetmessage( 65938, @cLangCode, 'DSP') --'Invalid QTY'
            END

            SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = 0
                            THEN '' ELSE @cDefaultPickQty END
            EXEC rdt.rdtSetFocusField @nMobile, 13
            GOTO Quit
         END
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
         BEGIN
            IF @nFunc = 1826
            BEGIN
               SET @cOutField04 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 4
            END
            ELSE
            BEGIN
               SET @cOutField03 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END

            IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
            BEGIN
               SET @cFieldAttr13 = 'O'
               SET @cInField13 = @cDefaultPickQty
            END
            GOTO Quit
         END
      END

      -- if the SKU is same then increase ActQTY by 1
      IF @cSKU = @cActSKU
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickNike', @cStorerKey) = '1'
         BEGIN
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            SET @cTemp_PrePackIndicator = ''
            SET @cTemp_PrePackIndicator = 0

            SELECT
               @cTemp_PrePackIndicator = PrePackIndicator,
               @nTemp_PackQtyIndicator = PackQtyIndicator
               FROM dbo.SKU WITH (NOLOCK)
            WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
               AND @cSKU = SKU

            IF CAST(@cTemp_PrePackIndicator AS INT) = 2
            BEGIN
               SET @cActQty = (CAST(@cActQty AS INT) + @nPrefQty) * @nTemp_PackQtyIndicator
            END
          END

         SET @cActQty = CAST( @cActQty AS INT) + @nPrefQty -- (james32)
         SET @nQtyToPick = @nQtyToPick + CAST(@cActQty AS INT)
         SET @nActQty = @nActQty + CAST(@cActQty AS INT)
      END

      SET @nRDTPickLockQTY = 0

      SELECT @nRDTPickLockQTY = SUM(PickQty)
      FROM RDT.RDTPickLock WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND SKU = @cSKU
         AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
         AND LOC = @cLOC
         AND Status = '1'
         AND AddWho = @cUserName

      -- Update PickQty = QtyToPick
      SET @nStartTranCnt = @@TRANCOUNT    --(james10)
      BEGIN TRAN
      SAVE TRAN A

      IF @cLoadDefaultPickMethod = 'C' AND CAST(@cActQty AS INT) > 0
      BEGIN
         -- (james17)   start
         SET @nRDTPickLockQTY = 0

         SELECT @nRDTPickLockQTY = SUM(PickQty)
         FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Status = '1'
            AND AddWho = @cUserName
            AND LoadKey = @cLoadKey
            AND SKU = @cSKU
            AND LOC = @cLOC
            AND (( ISNULL(@cLottable02, '') = '') OR ( Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(Lottable04, '') = @dLottable04))

         SELECT @nTotalPickQty = ISNULL( SUM(PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND PD.Status = '0'
            AND LOC.Facility = @cFacility
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
            AND LPD.LoadKey = @cLoadKey

         IF (@nRDTPickLockQTY + @cActQty) >  @nTotalPickQty
         BEGIN
            -- reverse the qty if error
            SET @nActQty = @nActQty - CAST(@cActQty AS INT)
            SET @nQtyToPick = @nQtyToPick - CAST(@cActQty AS INT)
            SET @cActQty = ''
            ROLLBACK TRAN A

            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '69360 Over Pick'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 69360
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Pick'
            END

            SET @cOutField13 = @cDefaultPickQty
            EXEC rdt.rdtSetFocusField @nMobile, 13
            GOTO Step_8_Fail
         END
         -- (james17)   end

         SET @nQty2Offset = CAST(@cActQty AS INT)

         DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RPL.ORDERKEY, O.Priority, RPL.LOT, SUM(RPL.PickQty)
         FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (RPL.ORDERKEY = O.ORDERKEY)
         WHERE RPL.StorerKey = @cStorerKey
            AND RPL.status = '1'
            AND RPL.AddWho = @cUserName
            AND RPL.LoadKey = @cLoadKey
            AND RPL.SKU = @cSKU
            AND RPL.LOC = @cLOC
         GROUP BY RPL.ORDERKEY, O.Priority, RPL.LOT
         ORDER BY O.PRIORITY     -- Highest priority got the changes to be offset first
         OPEN CUR_LOOK4CONSO_ORDERS
         FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cPriority, @cLOT, @nRPL_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @nPD_Qty = SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND PD.LOT = @cLOT
               AND PD.OrderKey = @cConso_Orders
               AND PD.Status = '0'
               AND LOC.Facility = @cFacility
               AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
               AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))

            IF (@nPD_Qty - @nRPL_Qty) >= @nQty2Offset
            BEGIN
               UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                  PickQty = PickQty + @nQty2Offset
               WHERE OrderKey = @cConso_Orders
                  AND StorerKey = @cStorerKey     --tlting03
                  AND SKU = @cSKU
                  AND LOC = @cLOC
                  AND LOT = @cLOT
                  AND DropID = @cDropID
                  AND Status = '1'
                  AND AddWho = @cUserName

               SET @nQty2Offset = 0
            END
            ELSE
            IF (@nPD_Qty - @nRPL_Qty) < @nQty2Offset
            BEGIN
               UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                  PickQty = PickQty + (@nPD_Qty - @nRPL_Qty)
               WHERE OrderKey = @cConso_Orders
                  AND StorerKey = @cStorerKey     --tlting03
                  AND SKU = @cSKU
                  AND LOC = @cLOC
                  AND LOT = @cLOT
                  AND DropID = @cDropID
                  AND Status = '1'
                  AND AddWho = @cUserName

               SET @nQty2Offset = @nQty2Offset - (@nPD_Qty - @nRPL_Qty)
            END

            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 65979
               SET @cErrMsg = rdt.rdtgetmessage( 65979, @cLangCode, 'DSP') --'UPDPKLockFail'
               ROLLBACK TRAN A
               GOTO Step_8_Fail
            END

            IF @nQty2Offset <= 0
               BREAK

            FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cPriority, @cLOT, @nRPL_Qty
         END
         CLOSE CUR_LOOK4CONSO_ORDERS
         DEALLOCATE CUR_LOOK4CONSO_ORDERS
      END
      ELSE
      BEGIN -- @cLoadDefaultPickMethod <> 'C'
          -- ChewKP01 (Start)
         SET @nRDTPickLockQTY = 0

         SELECT @nRDTPickLockQTY = SUM(PickQty)
         FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND SKU = @cSKU
            AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND LOC = @cLOC
            AND Status = '1'
            AND AddWho = @cUserName

         IF (@nRDTPickLockQTY + CAST(@cActQty AS INT)) >  @nTotalPickQty
         BEGIN
            -- reverse the qty if error
            SET @nActQty = @nActQty - CAST(@cActQty AS INT)
            SET @nQtyToPick = @nQtyToPick - CAST(@cActQty AS INT)
            SET @cActQty = ''
            -- SOS 197651 If config setup show error message in new screen (james11)
            IF rdt.RDTGetConfig( @nFunc, 'ShowWrongSKUInNewScn', @cStorerKey) = 1
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '65939 Over Pick'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 65939
               SET @cErrMsg = rdt.rdtgetmessage( 65939, @cLangCode, 'DSP') --'Over Pick'
               ROLLBACK TRAN A -- ang01
               GOTO Step_8_Fail -- ang01
            END

            SET @cOutField13 = @cDefaultPickQty
            EXEC rdt.rdtSetFocusField @nMobile, 13
            GOTO Step_8_Fail
         END

         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
            PickQty = PickQty + CAST(@cActQty AS INT)
         WHERE OrderKey = @cOrderKey
            AND (( @nMultiStorer = 1) OR ( StorerKey = @cStorerKey))
            AND SKU = @cSKU
            AND LOC = @cLOC
            AND DropID = @cDropID
            AND Status = '1'
            AND AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 65940
            SET @cErrMsg = rdt.rdtgetmessage( 65940, @cLangCode, 'DSP') --'UPDPKLockFail'
            ROLLBACK TRAN A
            GOTO Step_8_Fail
         END
      END   -- @cLoadDefaultPickMethod <> 'C'

      -- If scanned qty = pick qty
      -- Add in LOT as selection criteria because for conso, there might be few orders with
      -- different lot or 1 order with different lot
      IF @nTotalPickQty = @nQtyToPick
      BEGIN
         IF @cLoadDefaultPickMethod = 'C'
         BEGIN
            DECLARE CUR_LOOK4CONSO_ORDERS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT OrderKey, LOT FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND Status = '1'
            AND AddWho = @cUserName
            AND LoadKey = @cLoadKey
            AND SKU = @cSKU
            OPEN CUR_LOOK4CONSO_ORDERS
            FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
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
                  ROLLBACK TRAN A
                  CLOSE CUR_LOOK4CONSO_ORDERS
                  DEALLOCATE CUR_LOOK4CONSO_ORDERS
                  GOTO Step_8_Fail
               END
               FETCH NEXT FROM CUR_LOOK4CONSO_ORDERS INTO @cConso_Orders, @cLOT
            END
            CLOSE CUR_LOOK4CONSO_ORDERS
            DEALLOCATE CUR_LOOK4CONSO_ORDERS
         END
         ELSE
         BEGIN -- @cLoadDefaultPickMethod <> 'C'
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
                  @cOrderKey,
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
         END   -- @cLoadDefaultPickMethod <> 'C'

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN A

            -- reverse the qty if error
            SET @nActQty = @nActQty - CAST(@cActQty AS INT)
            SET @nQtyToPick = @nQtyToPick - CAST(@cActQty AS INT)
            GOTO Step_8_Fail
         END

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
            BEGIN
               ROLLBACK TRAN A

               -- reverse the qty if error
               SET @nActQty = @nActQty - CAST(@cActQty AS INT)
               SET @nQtyToPick = @nQtyToPick - CAST(@cActQty AS INT)
               GOTO Step_8_Fail
            END
         END
         
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
             @cLOC = PD.Loc,
               @cSKU = PD.SKU,
               @cLottable02 = LA.Lottable02,
               @dLottable04 = LA.Lottable04
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.OrderDetail OD WITH (NOLOCK)
               ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    -- (james09)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE O.StorerKey = @cStorerKey        -- tlting03
               AND PD.Status = '0'
               AND O.LoadKey = @cLoadKey
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
               AND LOC.Facility = @cFacility
               AND RTRIM(LOC.LogicalLocation) + RTRIM(PD.SKU) + ISNULL(RTRIM(LA.Lottable02), '') + ISNULL(CONVERT( NVARCHAR( 10), LA.Lottable04, 120), 0) >
                   RTRIM(@cLogicalLoc) + RTRIM(@cSKU) + RTRIM(@cLottable02) + ISNULL(CONVERT( NVARCHAR( 10), @dLottable04, 120), 0)--@dLottable04
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
                  WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')
            GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
            ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

            -- No more task
            IF @@ROWCOUNT = 0
            BEGIN
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
                  AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                  AND LOC.Facility = @cFacility
               GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
               ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT
                     @nOrderPicked = COUNT( DISTINCT OrderKey),
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
                        ROLLBACK TRAN A
                        GOTO Step_8_Fail
                     END

                     FETCH NEXT FROM @curUpdRPL INTO @nRowRef
                  END
                  CLOSE @curUpdRPL
                  DEALLOCATE @curUpdRPL

                  -- Commit the transaction before goto picking screen
                  COMMIT TRAN

                  GOTO Quit
               END
               ELSE
               BEGIN
                  SET @cLOC = @cNewLOC
                  SET @cSKU = @cNewSKU
                  SET @cLottable02 = @cNewLottable02
                  SET @dLottable04 = @dNewLottable04
               END

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
               WHERE OD.StorerKey = @cStorerKey       --tlting03
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
                     ROLLBACK TRAN A
                     GOTO Step_8_Fail
                  END

                  COMMIT TRAN

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
               COMMIT TRAN

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
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
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
                  IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND OrderKey = @cConso_Orders
                                    AND Status = '1'
                                    AND LOT = @cLOT
                                    AND AddWho = @cUserName)
                  BEGIN
                     INSERT INTO RDT.RDTPickLock
                     (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey, LOT, LOC, 
                     Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
                     VALUES
                     (@cWaveKey, @cLoadKey, @cConso_Orders, '', @cStorerKey, @cSKU, @cPutAwayZone, @cPickZone, @cConso_Orders, @cLOT, @cLOC, 
                     @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 65980
                        SET @cErrMsg = rdt.rdtgetmessage( 65980, @cLangCode, 'DSP') --'LockOrdersFail'
                        ROLLBACK TRAN A
                        GOTO Step_8_Fail
                     END
                  END
                  ELSE
                  BEGIN
                     UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                        LOT = @cLot,
                        LOC = @cLoc,
                        SKU = @cSKU,
                        DropID = @cDropID,
                        PackKey = @cCartonType,                                                
                        Lottable02 = @cLottable02,
                        Lottable04 = @dLottable04
                     WHERE OrderKey = @cConso_Orders
                        AND Status = '1'
                        AND AddWho = @cUserName
                        AND StorerKey = @cStorerKey   -- tling03

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 65981
                        SET @cErrMsg = rdt.rdtgetmessage( 65981, @cLangCode, 'DSP') --'UPDPKLockFail'
                        ROLLBACK TRAN A
                        GOTO Step_8_Fail
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
               AND PD.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
               AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
               AND EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK) WHERE RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey
                  AND RPL.Status = '1' AND RPL.AddWho = @cUserName AND RPL.StorerKey = @cStorerKey AND RPL.PickQty = 0)

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
               AND LA.StorerKey = @cStorerKey
               AND LA.SKU = @cSKU
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

            -- (james35)
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
            END

            IF @cPrefUOM <> '6'
               SET @cOutField12 = @cPreferQty2Display
            ELSE
               SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))

            SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = '0'
                               THEN '' ELSE @cDefaultPickQty END-- Qty to pick
            SET @cOutField14 = CASE WHEN ISNULL(@cPackCfg, '') = '' THEN '' ELSE @cPackCfg END  -- (james11)
            SET @cOutField15 = CASE WHEN @cPrefUOM <> '6' THEN
                                    CASE WHEN ISNULL( @cDefaultPrefPickQty, '') = '' OR @cDefaultPrefPickQty = '0' THEN '' ELSE @cDefaultPrefPickQty END
                               ELSE 'QTY: ' END

            -- Commit transaction
            COMMIT TRAN

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
                     SET @nErrNo = 69377
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad SKU Field'
                     ROLLBACK TRAN A
                     GOTO Step_8_Fail
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
                     SET @nErrNo = 69341
                     SET @cErrMsg = rdt.rdtgetmessage( 69341, @cLangCode, 'DSP') --'LockOrdersFail'
                     ROLLBACK TRAN A
                     GOTO Step_8_Fail
                  END

                  SELECT @nSum_PickQty = ISNULL(SUM(PickQty), 0) FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey
                     AND SKU = @cSKU
                     AND LOT = @cLOT
                     AND LOC = @cLOC
                     AND AddWho = @cUserName
                     AND Status = '5'
                     AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                     AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))

                  SELECT @nCount_SerialNo = Count(1) FROM dbo.SerialNo WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey
                     AND SKU = @cSKU

                  -- IF @nOtherUnit2 > 0 AND (@nSum_PickQty % @nOtherUnit2 = 0) (Shong01)
                  IF @nOtherUnit2 > 0 AND (@nSum_PickQty % @nOtherUnit2 = 0 OR @nOtherUnit2=1)
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

                        -- Commit the transaction before goto picking screen
                        COMMIT TRAN

                        GOTO Quit
                     END
                  END   -- @nOtherUnit2 > 0
               END   -- PICKSERIAL
            END   -- ClusterPickInsPackDt

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
                  ROLLBACK TRAN A
                  GOTO Step_8_Fail
               END
            END
         END

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
                        @cCurrentOrderKey,
                        @cDropID       OUTPUT,
                        @cSKU,
                        'U',      -- U = Update
                        @cLangCode,
                        @nErrNo        OUTPUT,
                        @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max

                     IF @nErrNo <> 0
                     BEGIN
                        ROLLBACK TRAN A
                        GOTO Step_8_Fail
                     END
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
                     @cCurrentOrderKey,
                     @cPickSlipNo,
                     @cLOC,
                     @cDropID,
                     @cSKU,
                     @nQty,
                     @nErrNo   OUTPUT,
                     @cErrMsg  OUTPUT
   
                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN A
                     GOTO Step_8_Fail
                  END
               END
               ELSE
               BEGIN
                  SET @cOutField01 = ''

                  -- Go to Close Case screen
                  SET @nOutScn  = 1886
                  SET @nOutStep = 15

                  -- Commit the transaction before goto picking screen
                  COMMIT TRAN

                  GOTO Quit
               END
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
                  SET @nErrNo = 65942
                  SET @cErrMsg = rdt.rdtgetmessage( 65942, @cLangCode, 'DSP') --'UPDPKLockFail'
                  ROLLBACK TRAN A
                  GOTO Step_8_Fail
               END

               FETCH NEXT FROM @curUpdRPL INTO @nRowRef
            END
            CLOSE @curUpdRPL
            DEALLOCATE @curUpdRPL

            -- Commit the transaction before goto picking screen
            COMMIT TRAN

            GOTO Quit
         END

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

         -- Get the Lottables
         SELECT
            @cLottable02 = Lottable02,
            @dLottable04 = Lottable04
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
            AND SKU = @cSKU
            AND LOT = @cLot

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
                        WHERE (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
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
             SKU, PutAwayZone, PickZone, PickDetailKey
            ,LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey)
            VALUES
            (@cWaveKey, @cLoadKey, @cOrderKey, '', CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @cStorerKey END,
             @cSKU, @cPutAwayZone, @cPickZone, ''
            ,@cLOT, @cLOC, @cLottable02, @dLottable04, '1', @cUserName, GETDATE(), @cDropID, @cPickSlipNo, @nMobile, @cCartonType)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 65943
               SET @cErrMsg = rdt.rdtgetmessage( 65943, @cLangCode, 'DSP') --'LockOrdersFail'
               ROLLBACK TRAN A
               GOTO Step_8_Fail
            END
         END
         ELSE
         BEGIN
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
               ROLLBACK TRAN A
               GOTO Step_8_Fail
            END
         END

         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'
         BEGIN
            -- If change of LOC then need to go back to confirm LOC screen
            IF @cPrevLOC <> @cLOC
            BEGIN
               -- Commit until the level we started
               WHILE @@TRANCOUNT > @nStartTranCnt
                  COMMIT TRAN

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
               IF rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirmLOC', @cStorerKey) = '1'
               BEGIN
                  -- If change of LOC then need to go back to confirm LOC screen
                  IF @cPrevLOC <> @cLOC
                  BEGIN
                     SET @nActQty = 0
                     SET @nQtyToPick = 0

                     -- Commit until the level we started
                     WHILE @@TRANCOUNT > @nStartTranCnt
                        COMMIT TRAN

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

               SET @nActQty = 0
               SET @nQtyToPick = 0

               -- Commit transaction before goto DropID screen
               COMMIT TRAN

               GOTO Quit
            END
         END   -- If OrderKey changed

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

         -- If DefaultToAllocatedQty = '1' then we use DefaultToAllocatedQty as DefaultPickQty
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
            AND L.LOC = @cLOC
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
            AND L.Facility = @cFacility
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
            AND EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK) WHERE ADDWHO = RPL.AddWho
                     AND StorerKey = RPL.StorerKey AND OrderKey =  PD.OrderKey )       -- tlting02

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
            AND (( @nMultiStorer = 1 AND LA.StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND LA.StorerKey = @cStorerKey))
            AND LA.SKU = @cSKU      -- tlting03
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
               IF @nMultiStorer = 1
                  SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

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

         --Commit transaction before
         COMMIT TRAN

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

      END   -- If scanned qty = pick qty

      -- (james10)
      WHILE @@TRANCOUNT > @nStartTranCnt
         COMMIT TRAN

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
               
      -- (james36)
      IF @cLoadDefaultPickMethod = 'C'
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
      ELSE
         -- Get the total allocated qty for LOC + SKU + OrderKey
         SELECT @nTotalPickQty = ISNULL( SUM( QTY), 0)
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

      IF @cDefaultToAllocatedQty = '1'
      BEGIN
         SET @cDefaultPickQty = @nTotalPickQty - @nQtyToPick --CAST(@cActQty AS INT)
      END

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
            IF @nMultiStorer = 1
               SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

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

      IF @nFunc = 1826
      BEGIN
         SET @cOutField04 = ''   -- SKU/UPC
         EXEC rdt.rdtSetFocusField @nMobile, 4
      END
      ELSE
      IF @nFunc IN (1827, 1828)
      BEGIN
         SET @cOutField03 = ''   -- SKU/UPC
         EXEC rdt.rdtSetFocusField @nMobile, 3
      END
      SET @cOutField06 = CASE WHEN @cScanLot02 = 1 THEN '' ELSE @cLottable02 END
      SET @cOutField08 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
                              THEN @cOS_Qty
                              WHEN ISNULL( @cExtendedInfoSP, '') <> '' THEN @cExtendedInfo -- (james40)
                         ELSE CAST(@nTTL_Qty AS NVARCHAR( 7)) END
      IF @nFunc = 1826
         SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
      ELSE
      BEGIN
         IF @cPrefUOM <> '6'
            SET @cOutField12 = @cPreferQty2Display
         ELSE
            SET @cOutField12 = RTRIM(CAST(@nQtyToPick AS NVARCHAR( 7))) + '/' + CAST(@nTotalPickQty AS NVARCHAR( 7))
      END
      SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '0') = '0' THEN '' ELSE @cDefaultPickQty END  -- Qty to pick
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

   IF @nInputKey = 0 -- ESC
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
      
      --(james03)
      IF @cPromptCloseCase = '1'
      BEGIN
         SET @cOutField01 = ''

         -- Go to Close Case screen
         SET @nOutScn  = 1886
         SET @nOutStep = 15

         GOTO Quit
      END

      IF @nFunc = 1826
      BEGIN
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

         UPDATE RDT.RDTPickLock WITH (ROWLOCK) -- SOS# 173419
            SET DropID = ''
         WHERE AddWho = @cUserName AND PickQty = 0
         AND Status = '1' AND Mobile = @nMobile
         AND Sku = @cSKU 
         AND (( @nMultiStorer = 1 AND StorerKey = @cORD_StorerKey) OR ( @nMultiStorer <> 1 AND StorerKey = @cStorerKey))
         AND WaveKey = @cWaveKey AND LoadKey = @cLoadKey
         AND OrderKey = @cOrderKey AND LOC = @cLOC
         AND PutawayZone = @cPutAwayZone AND PickZone = @cPickZone
         AND ISNULL(RTRIM(DropID),'') = @cDropID

         -- Prepare Prev Screen
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

         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE Orderkey = @cOrderKey

         -- SOS172041
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
      IF @nFunc = 1828  -- (james07)
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

   GOTO Quit

   Step_8_Fail:
   BEGIN
      IF @nFunc = 1826
         SET @cOutField04 = ''   --ActSKU
      ELSE
         SET @cOutField03 = ''   --ActSKU

      SET @cOutField13 = CASE WHEN ISNULL(@cDefaultPickQty, '') = '' OR @cDefaultPickQty = 0
                      THEN '' ELSE @cDefaultPickQty END
      EXEC rdt.rdtSetFocusField @nMobile, 13

      IF ISNULL(@cClusterPickLockQtyToPick, '') = '1'
      BEGIN
         SET @cFieldAttr13 = 'O'
      END

      -- rollback didn't decrease @@trancount
      -- COMMIT statements for such transaction
      -- decrease @@TRANCOUNT by 1 without making updates permanent
      WHILE @@TRANCOUNT > @nStartTranCnt
         COMMIT TRAN
   END

END
GOTO Quit
        
END
Quit:

GO