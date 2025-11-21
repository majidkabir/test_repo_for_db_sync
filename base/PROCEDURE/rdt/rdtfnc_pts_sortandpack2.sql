SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LF                                                              */
/* Purpose: sort and pack -> sort and pack 2                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 26-01-2022 1.0  yeekung     WMS18620. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTS_SortAndPack2] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 20),
   @cUserName  NVARCHAR( 18),

   @nError            INT,
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
   @cPUOM             NVARCHAR( 10),
   @bSuccess          INT,
   @nFromScn          INT, 
   @nFromStep         INT,

   @cPTSZone            NVARCHAR(10),
   @cUserID             NVARCHAR(18),
   @cDropID             NVARCHAR(20),
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000),
   @cExtendedUpdateSP   NVARCHAR(30),
   @nTotalAssignDropID  INT,
   @cOption             NVARCHAR(1),
   @cSuggLoc            NVARCHAR(10),
   @cLightModeColor     NVARCHAR(5),
   @cLightMode          NVARCHAR(10),
   @cPTSLoc             NVARCHAR(10),
   @cWaveKey            NVARCHAR(10),
   @cPTLWaveKey         NVARCHAR(10),
   @nMaxDropID          INT,
   @nAssignDropID       INT,
   @cExtendedValidateSP NVARCHAR(30),
   @cDecodeLabelNo      NVARCHAR(20),
   @cDefaultQTY         NVARCHAR(5),
   @cDisableSKUField    NVARCHAR(1),
   @cDisableQTYField    NVARCHAR(1),
   @cGeneratePackDetail NVARCHAR(1),
   @cGetNextTaskSP      NVARCHAR(30),
   @cLabelNo            NVARCHAR(20),
   @cSuggPTSPosition    NVARCHAR(20),
   @cLoadKey            NVARCHAR(10), -- Check
   @cSuggSKU            NVARCHAR(20),
   @cSKUDescr           NVARCHAR(60),
   @nExpectedQty        INT,
   @nDropIDCount        INT,
   @cPTSPosition        NVARCHAR(20),
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @cMultiSKUBarcode    NVARCHAR( 1),
   --@cScnText            NVARCHAR(20),
   @nPUOM_Div           INT, -- UOM divider
   @nQTY_Avail          INT, -- QTY available in LOTxLOCXID
   @nQTY                INT, -- Pack.QTY
   @nPQTY               INT, -- Preferred UOM QTY
   @nMQTY               INT, -- Master unit QTY
   @nActQTY             INT, -- Actual replenish QTY
   @nActMQTY            INT, -- Actual keyed in master QTY
   @nActPQTY            INT, -- Actual keyed in prefered QTY
   @cScnLabel           NVARCHAR(20),
   @cScnText            NVARCHAR(20),
   @nCountScanTask      INT, -- Check
   @nTotalTaskCount     INT, -- Check
   @cSKU                NVARCHAR(20),
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @cSKULabel           NVARCHAR(20),
   @cSKUValidated       NVARCHAR(2),
   @nUCCQTY             INT,
   @cUCC                NVARCHAR(20),
   @nSKUCnt             INT,
   @cPutawayZone        NVARCHAR(10), -- Check
   @cReplenishmentKey   NVARCHAR(10), -- Check
   @cFromLoc            NVARCHAR(10), -- Check
   @cFromID             NVARCHAR(18), -- Check
   @cSuggToLoc          NVARCHAR(10), -- Check
   @cToLabelNo          NVARCHAR(20),
   @cSuggLabelNo        NVARCHAR(20),
   @cActToLoc           NVARCHAR(10), -- Check
   @cOptions            NVARCHAR(1),
   @cDefaultToLoc       NVARCHAR(10), -- Check
   @cSuggDropID         NVARCHAR(20),
   @cPTSLogKey          NVARCHAR(10),
   @cShort              NVARCHAR(1),
   @cDefaultPosition    NVARCHAR(20),
   @cLottableCode       NVARCHAR(30),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nMorePage           INT,
   @cLot           NVARCHAR(10),
   @cDefaultToLabel NVARCHAR(1),
   @cExtendedInfoSP NVARCHAR(30),
   @cPickStatus     NVARCHAR(1),
	@cExtendedWCSSP  NVARCHAR(20),
   @cAlloWOneDropID NVARCHAR(1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,
   --@cLightMode  = LightMode,
   @cSKU       = V_SKU,
   @cSKUDescr   = V_SKUDescr,

   @cLot        = V_Lot,
   @cPUOM       = V_UOM,
  -- @nExpectedQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_Qty, 5), 0) = 1 THEN LEFT( V_Qty, 5) ELSE 0 END,
  
   @nPUOM_Div  = V_PUOM_Div,
   @nMQTY      = V_MQTY,
   @nPQTY      = V_PQTY,
   
   @nExpectedQTY     = V_Integer1,
   @nActMQTY         = V_Integer2,
   @nActPQTY         = V_Integer3,
   @nActQty          = V_Integer4,
   @nFromScn         = V_Integer5,
   @nFromStep        = V_Integer6,

   @cExtendedUpdateSP        = V_String1,
   @cExtendedValidateSP      = V_String2,
   @cDecodeLabelNo           = V_String3,
   @cDefaultQTY              = V_String4,
   @cDisableSKUField         = V_String5,
   @cGeneratePackDetail      = V_String6,
   @cGetNextTaskSP           = V_String7,
   @cSuggPTSPosition         = V_string8,
   @cSuggSKU                 = V_String9,
   @cSuggDropID              = V_String10,
   @cMUOM_Desc               = V_String11,
   @cPUOM_Desc               = V_String12,
   @cScnText                 = V_String13,
   @cSKUValidated            = V_String15, 
   @cPTSLogKey               = V_String16,
   @cAlloWOneDropID          = V_String17,
   @cPTSPosition             = V_String24,
   @cScnLabel                = V_String25,
   @cShort                   = V_String26,
   @cDropID                  = V_String27,
   @cDefaultToLabel          = V_String29,
   @cExtendedInfoSP          = V_String30,
   @cPickStatus              = V_String31,
   @cDisableQTYField         = V_String32,
	@cExtendedWCSSP           = V_string33,
   @cMultiSKUBarcode         = V_String34,

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT

SET @n_debug = 0


IF @nFunc = 762  -- PTS Sort And Pack
BEGIN

   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTS Sort And Pack
   IF @nStep = 1 GOTO Step_1   -- Scn = 4500. DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4502. SKU , Qty
   IF @nStep = 3 GOTO Step_3   -- Scn = 4503. To LabelNo
   IF @nStep = 4 GOTO Step_4   -- Scn = 4505. Short Pack
   IF @nStep = 5 GOTO Step_5   -- Scn = 4506. Message
   IF @nStep = 6 GOTO Step_6   -- Scn = 3570. Multi SKU Barcode  

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 762. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
   BEGIN
      SET @cExtendedUpdateSP = ''
   END

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)    
    
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
      SET @cExtendedValidateSP = ''
   END

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   SET @cDisableSKUField = rdt.RDTGetConfig( @nFunc, 'DisableSKUField', @cStorerKey)
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cGeneratePackDetail = rdt.RDTGetConfig( @nFunc, 'GeneratePackDetail', @cStorerKey)

   SET @cAlloWOneDropID= rdt.RDTGetConfig( @nFunc, 'AllowOneDropID', @cStorerKey)

   SET @cGetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'GetNextTaskSP', @cStorerKey)
   IF @cGetNextTaskSP = '0'
   BEGIN
      SET @cGetNextTaskSP = ''
   END

	SET @cExtendedWCSSP = rdt.RDTGetConfig( @nFunc, 'ExtendedWCSSP', @cStorerKey)  
   IF @cExtendedWCSSP = '0'  
      SET @cExtendedWCSSP = ''  

   SET @cDefaultToLabel = rdt.RDTGetConfig( @nFunc, 'DefaultToLabel', @cStorerKey)
   IF @cDefaultToLabel = '0'
   BEGIN
      SET @cDefaultToLabel = ''
   END

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
   IF @cPickStatus NOT IN ('3', '5')
      SET @cPickStatus = '5'

   -- Initiate var
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   SET @cSuggPTSPosition      = ''
   SET @cSuggSKU              = ''
   SET @cSuggDropID           = ''
   SET @cMUOM_Desc            = ''
   SET @cPUOM_Desc            = ''
   SET @cScnText              = ''
   SET @nExpectedQTY          = 0
   SET @cSKUValidated         = '0'
   SET @cPTSLogKey            = ''
   SET @nPUOM_Div             = 0
   SET @nMQTY                 = 0
   SET @nPQTY                 = 0
   SET @nActMQTY              = 0
   SET @nActPQTY              = 0
   SET @nActQty               = 0
   SET @nQty                  = 0
   SET @cPTSPosition          = ''
   SET @cScnLabel             = ''
   SET @cShort                = ''
   SET @cDropID               = ''

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''

   -- Clear PTS Log
   DELETE FROM rdt.rdtPTSLog WITH (ROWLOCK)
   WHERE AddWho = @cUserName

   -- Set the entry point
   SET @nScn = 6010
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6010.
	PTS - SORT AND PACK
   DropID:(field01 , input)
   Scanned DropID (field02)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cDropID = ISNULL(RTRIM(@cInField01),'')

      IF @cDropID = ''
      BEGIN

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK)
                         WHERE AddWho = @cUserName
                         AND Status = '0' )
         BEGIN
            SET @nErrNo = 180951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            -- Get Next Task

            SET @cPTSLogKey         = ''
            SET @cSuggPTSPosition   = ''
            SET @cSuggSKU           = ''
            SET @nExpectedQty       = ''
            SET @cScnText           = ''
            SET @cSuggDropID        = ''

            IF @cGetNextTaskSP <> ''
            BEGIN
               SET @cPTSLogKey = ''

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

                  SET @cSQLParam =
                     '@nMobile        INT,            ' +
                     '@nFunc          INT,            ' +
                     '@cLangCode      NVARCHAR(3),    ' +
                     '@nStep          INT,            ' +
                     '@cUserName      NVARCHAR( 18),  ' +
                     '@cFacility      NVARCHAR( 5),   ' +
                     '@cStorerKey     NVARCHAR( 15),  ' +
                     '@cDropID        NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20),  ' +
                     '@nQty           INT,            ' +
                     '@cLabelNo       NVARCHAR( 20),  ' +
                     '@cPTSPosition   NVARCHAR( 20),  ' +
                     '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +
                     '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
                     '@cScnText       NVARCHAR( 20) OUTPUT, ' +
                     '@nErrNo         INT OUTPUT, ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 180952
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
                     GOTO Step_1_Fail
                  END

                  SELECT TOP 1
                        @cSuggSKU         = PTSLOG.SKU
                      , @nExpectedQty     = PTSLOG.ExpectedQty
                      , @cScnText         = PTSLOG.ConsigneeKey
                      , @cSuggDropID      = PTSLog.DropID
                      , @cLot             = PTSLog.Lot
                  FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
                  WHERE PTSLOG.StorerKey = @cStorerKey
                  AND PTSLOG.AddWho = @cUserName
                  AND PTSLogKey = @cPTSLogKey
               END
            END  
            ELSE
            BEGIN

               SELECT 
                     @cSuggSKU         = PTSLOG.SKU
                   , @nExpectedQty     = PTSLOG.ExpectedQty
                   , @cScnText         = PTSLOG.ConsigneeKey
                   , @cSuggDropID      = PTSLog.DropID
                   , @cPTSLogKey       = PTSLog.PTSLogKey
                   , @cLot             = PTSLog.Lot
               FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
               WHERE PTSLOG.StorerKey = @cStorerKey
               AND PTSLOG.AddWho = @cUserName
               AND Status = '0'
               ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY


               IF ISNULL(@cPTSLogKey , '' ) = ''
               BEGIN
                  SET @nErrNo = 180953
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
                  GOTO Step_1_Fail
               END
            END
            -- Get Pack info
            SELECT
               @cLottableCode = SKU.LottableCode,
               @cSKUDescr = SKU.Descr,
               @cMUOM_Desc = Pack.PackUOM3,
               @cPUOM_Desc =
            CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END,
               @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggSKU


            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nExpectedQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit
            END

            -- Prep QTY screen var
            SET @cOutField01 = @cSuggDropID

            SET @cOutField05 = ''
            SET @cOutField06 = ''


            SELECT
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = LA.Lottable04,
               @dLottable05 = LA.Lottable05,
               @cLottable06 = LA.Lottable06,
               @cLottable07 = LA.Lottable07,
               @cLottable08 = LA.Lottable08,
               @cLottable09 = LA.Lottable09,
               @cLottable10 = LA.Lottable10,
               @cLottable11 = LA.Lottable11,
               @cLottable12 = LA.Lottable12,
               @dLottable13 = LA.Lottable13,
               @dLottable14 = LA.Lottable14,
               @dLottable15 = LA.Lottable15
            FROM dbo.LotAttribute LA WITH (NOLOCK)
            WHERE Lot = @cLot

            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 2, 5,
                  @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
                  @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
                  @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
                  @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
                  @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
                  @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
                  @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
                  @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
                  @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
                  @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
                  @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
                  @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
                  @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
                  @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
                  @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
                  @nMorePage   OUTPUT,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT,
                  '',      -- SourceKey
                  @nFunc   -- SourceType

            SET @cOutField04 = @cSuggSKU

            SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
            SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END

            -- Disable QTY field
            SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
            SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField10 = '' -- @nPQTY
               SET @cOutField12 = '' -- @nActPQTY
               -- Disable pref QTY field
               SET @cFieldAttr12 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY
				END

            --SET @cOutField09 = @cMUOM_Desc
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY

            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc

            SET @nCountScanTask = 0
            --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

            SET @cSKU = ''
            SET @cInField12 = ''
            SET @cInField13 = ''
            SET @nActPQTY = 0
            SET @nActMQTY = 0
            SET @cSKUValidated = '0'

            -- GOTO Next Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
				GOTO QUIT
         END
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cDropID
                      AND Status = @cPickStatus )
      BEGIN
         SET @nErrNo = 180954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID
         GOTO Step_1_Fail
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
                  AND Status < '9' )
      BEGIN
         SET @nErrNo = 180968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDExist
         GOTO Step_1_Fail
      END

      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

            SET @cSQLParam =
                  '@nMobile        INT,            ' +
                  '@nFunc          INT,            ' +
                  '@cLangCode      NVARCHAR(3),    ' +
                  '@nStep          INT,            ' +
                  '@cUserName      NVARCHAR( 18),  ' +
                  '@cFacility      NVARCHAR( 5),   ' +
                  '@cStorerKey     NVARCHAR( 15),  ' +
                  '@cDropID        NVARCHAR( 20),  ' +
                  '@cSKU           NVARCHAR( 20),  ' +
                  '@nQty           INT,            ' +
                  '@cToLabelNo     NVARCHAR( 20),  ' +
                  '@cPTSLogKey     NVARCHAR( 20),  ' +
                  '@cShort         NVARCHAR(1),    ' +
                  '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +
                  '@nErrNo         INT OUTPUT,     ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END  -- IF @cExtendedUpdateSP <> ''
      ELSE
      BEGIN

         INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
         SELECT PD.Loc, '0', @cDropID, '' ,PD.StorerKey, '','', PD.SKU, PD.Loc, PD.Lot, PD.UOM
               ,SUM(PD.Qty), 0, '', @nFunc, GetDate(), @cUserName
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status = @cPickStatus
         AND PD.CaseID = ''
			group by  PD.Loc,PD.StorerKey, PD.SKU, PD.Loc, PD.Lot, PD.UOM

        IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail
            GOTO Step_1_Fail
         END
      END

      IF @cAlloWOneDropID='1'
      BEGIN
         -- Get Next Task
         SET @cPTSLogKey         = ''
         SET @cSuggPTSPosition   = ''
         SET @cSuggSKU           = ''
         SET @nExpectedQty       = ''
         SET @cScnText           = ''
         SET @cSuggDropID        = ''

         IF @cGetNextTaskSP <> ''
         BEGIN
            SET @cPTSLogKey = ''

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

               SET @cSQLParam =
                  '@nMobile        INT,            ' +
                  '@nFunc          INT,            ' +
                  '@cLangCode      NVARCHAR(3),    ' +
                  '@nStep          INT,            ' +
                  '@cUserName      NVARCHAR( 18),  ' +
                  '@cFacility      NVARCHAR( 5),   ' +
                  '@cStorerKey     NVARCHAR( 15),  ' +
                  '@cDropID        NVARCHAR( 20),  ' +
                  '@cSKU           NVARCHAR( 20),  ' +
                  '@nQty           INT,            ' +
                  '@cLabelNo       NVARCHAR( 20),  ' +
                  '@cPTSPosition   NVARCHAR( 20),  ' +
                  '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +
                  '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
                  '@cScnText       NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo         INT OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 180952
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
                  GOTO Step_1_Fail
               END

               SELECT TOP 1
                     @cSuggSKU         = PTSLOG.SKU
                     , @nExpectedQty     = PTSLOG.ExpectedQty
                     , @cScnText         = PTSLOG.ConsigneeKey
                     , @cSuggDropID      = PTSLog.DropID
                     , @cLot             = PTSLog.Lot
               FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
               WHERE PTSLOG.StorerKey = @cStorerKey
               AND PTSLOG.AddWho = @cUserName
               AND PTSLogKey = @cPTSLogKey
            END
         END  
         ELSE
         BEGIN

            SELECT 
                  @cSuggSKU         = PTSLOG.SKU
                  , @nExpectedQty     = PTSLOG.ExpectedQty
                  , @cScnText         = PTSLOG.ConsigneeKey
                  , @cSuggDropID      = PTSLog.DropID
                  , @cPTSLogKey       = PTSLog.PTSLogKey
                  , @cLot             = PTSLog.Lot
            FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
            WHERE PTSLOG.StorerKey = @cStorerKey
            AND PTSLOG.AddWho = @cUserName
            AND Status = '0'
            ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY


            IF ISNULL(@cPTSLogKey , '' ) = ''
            BEGIN
               SET @nErrNo = 180953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
               GOTO Step_1_Fail
            END
         END
         -- Get Pack info
         SELECT
            @cLottableCode = SKU.LottableCode,
            @cSKUDescr = SKU.Descr,
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
         CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
            @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSuggSKU


         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nExpectedQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END

         -- Prep QTY screen var
         SET @cOutField01 = @cSuggDropID
         SET @cOutField05 = ''
         SET @cOutField06 = ''


         SELECT
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15
         FROM dbo.LotAttribute LA WITH (NOLOCK)
         WHERE Lot = @cLot

         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 2, 5,
               @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
               @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
               @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
               @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
               @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
               @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
               @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
               @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
               @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
               @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
               @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
               @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
               @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
               @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
               @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
               @nMorePage   OUTPUT,
               @nErrNo      OUTPUT,
               @cErrMsg     OUTPUT,
               '',      -- SourceKey
               @nFunc   -- SourceType

         SET @cOutField04 = @cSuggSKU
         --SET @cOutField05 = SUBSTRInG(@cSKUDescr, 1, 20)
         --SET @cOutField06 = SUBSTRInG(@cSKUDescr, 21, 20)

         SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
         SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END

         -- Disable QTY field
         SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
         SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- @nActPQTY
            -- Disable pref QTY field
            SET @cFieldAttr12 = 'O'

         END
         ELSE
         BEGIN
            SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY
			END

         --SET @cOutField09 = @cMUOM_Desc
         SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
         SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY

         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc

         SET @nCountScanTask = 0
         --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

         SET @cSKU = ''
         SET @cInField12 = ''
         SET @cInField13 = ''
         SET @nActPQTY = 0
         SET @nActMQTY = 0
         SET @cSKUValidated = '0'

         -- GOTO Next Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
			GOTO QUIT
      END

      SELECT @nDropIDCount = Count(Distinct DropID)
      FROM rdt.rdtPTSLog WITH (NOLOCK)
      WHERE AddWho = @cUserName
      AND Status = '0'

       -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = @nDropIDCount
   END 

   IF @nInputKey = 0
   BEGIN

--    -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

   END
   GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SELECT @nDropIDCount = Count(Distinct DropID)
      FROM rdt.rdtPTSLog WITH (NOLOCK)
      WHERE AddWho = @cUserName
      AND Status = '0'

      -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = @nDropIDCount

   END
END
GOTO QUIT

/********************************************************************************
Step 2. Scn = 6011.
   DropID:   (Field01)
   OutField1 (Field02)
   OutField2 (Field03)
   SKU       (Field04)
   SKU Desc1 (Field05)
   SKU Desc2 (Field06)
   SKU       (Field07, input)
   PUOM MUOM (Field09)
   ESP QTY   (Field10, Field11)
   ACT QTY   (Field12, Field13, both input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKULabel = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END
      SET @cActPQTY = CASE WHEN @cFieldAttr12 = '' THEN @cInField12 ELSE @cOutField12 END
      SET @cActMQTY = CASE WHEN @cFieldAttr13 = '' THEN @cInField13 ELSE @cOutField13 END

      -- Retain value
      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END -- PQTY
      SET @cOutField13 = CASE WHEN @cFieldAttr13 = 'O' THEN @cOutField13 ELSE @cInField13 END -- MQTY

      -- Check SKU
      IF @cDisableSKUField = '0' 
      BEGIN
         -- Check SKU blank
         IF @cSKULabel = '' AND @cSKUValidated = '0'
         BEGIN
            SET @nErrNo = 180956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
            GOTO Quit
         END

         IF @cSKULabel <> ''
         BEGIN
            IF @cSKULabel = '99' -- Fully short
            BEGIN
               SET @cSKUValidated = '99'
               SET @cActPQTY = ''
               SET @cActMQTY = '0'
               SET @cOutField12 = ''
               SET @cOutField13 = '0'
               SET @cSKU = @cSuggSKU
            END
            ELSE
            BEGIN
               -- Decode label
               IF @cDecodeLabelNo <> ''
               BEGIN
                  SET @cErrMsg = ''
                  SET @nErrNo = 0

                  EXEC dbo.ispLabelNo_Decoding_Wrapper
                      @c_SPName     = @cDecodeLabelNo
                     ,@c_LabelNo    = @cSKULabel
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
                     GOTO Quit

                  SET @cSKU    = ISNULL( @c_oFieled01, '')
                  SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)
                  SET @cUCC    = ISNULL( @c_oFieled08, '')
               END
               ELSE
               BEGIN
                  SET @cSKU = @cSKULabel
               END

               -- Get SKU barcode count
               -- DECLARE @nSKUCnt INT
               EXEC rdt.rdt_GETSKUCNT
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cSKU
                  ,@nSKUCnt     = @nSKUCnt       OUTPUT
                  ,@bSuccess    = @b_Success     OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT

               -- Check SKU/UPC
               IF @nSKUCnt = 0
               BEGIN
                  SET @nErrNo = 180957
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
                  EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
                  GOTO Quit
               END

               -- Validate barcode return multiple SKU    
               IF @nSKUCnt > 1    
               BEGIN    
                  IF @cMultiSKUBarcode IN ('1', '2')    --(yeekung03)
                  BEGIN      
                     EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,    
                        @cInField01 OUTPUT,  @cOutField01 OUTPUT,    
                        @cInField02 OUTPUT,  @cOutField02 OUTPUT,    
                        @cInField03 OUTPUT,  @cOutField03 OUTPUT,    
                        @cInField04 OUTPUT,  @cOutField04 OUTPUT,    
                        @cInField05 OUTPUT,  @cOutField05 OUTPUT,    
                        @cInField06 OUTPUT,  @cOutField06 OUTPUT,    
                        @cInField07 OUTPUT,  @cOutField07 OUTPUT,    
                        @cInField08 OUTPUT,  @cOutField08 OUTPUT,    
                        @cInField09 OUTPUT,  @cOutField09 OUTPUT,    
                        @cInField10 OUTPUT,  @cOutField10 OUTPUT,    
                        @cInField11 OUTPUT,  @cOutField11 OUTPUT,    
                        @cInField12 OUTPUT,  @cOutField12 OUTPUT,    
                        @cInField13 OUTPUT,  @cOutField13 OUTPUT,    
                        @cInField14 OUTPUT,  @cOutField14 OUTPUT,    
                        @cInField15 OUTPUT,  @cOutField15 OUTPUT,    
                        'POPULATE',    
                        @cMultiSKUBarcode,    
                        @cStorerKey,    
                        @cSKU         OUTPUT,    
                        @nErrNo       OUTPUT,    
                        @cErrMsg      OUTPUT

                     IF @nErrNo = 0 -- Populate multi SKU screen    
                     BEGIN    
                        -- Go to Multi SKU screen    
                        SET @nFromScn = @nScn    
                        SET @nFromStep = @nStep    
                        SET @nScn = 3570    
                        SET @nStep = @nStep + 4
                        GOTO Quit    
                     END    
                     IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
                        SET @nErrNo = 0    
                  END    
                  ELSE    
                  BEGIN    
                     SET @nErrNo = 180978    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'    
                     GOTO quit    
                  END    
               END   

               -- Get SKU code
               EXEC rdt.rdt_GETSKU
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cSKU          OUTPUT
                  ,@bSuccess    = @b_Success     OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT

               -- Check SKU same as suggested
               IF @cSKU <> @cSuggSKU
               BEGIN
                  SET @nErrNo = 180958
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
                  EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
                  GOTO Quit
               END

               -- Mark SKU as validated
               SET @cSKUValidated = '1'
            END
         END
      END
      ELSE
         SET @cSKU = @cSuggSKU

      -- Check PQTY
      IF @cActPQTY <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
         BEGIN
            SET @nErrNo = 180959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
            GOTO Quit
         END
      END

      -- Check MQTY
      IF @cActMQTY  <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
         BEGIN
            SET @nErrNo = 180960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
            GOTO Quit
         END
      END
      
      -- Check full short with QTY
      IF @cSKUValidated = '99' AND 
         ((@cActMQTY <> '0' AND @cActMQTY <> '') OR 
         (@cActPQTY <> '0' AND @cActPQTY <> ''))
      BEGIN
         SET @nErrNo = 180961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FullShortNoQTY
         GOTO Quit
      END
      
      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = @nActMQTY + rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM

      -- Top up QTY, MQTY, PQTY
      IF @cSKUValidated = '99' -- Fully short
         SET @nQTY = 0
      ELSE IF @nUCCQTY > 0
      BEGIN
         SET @nActQTY = @nActQTY + @nUCCQTY

         -- Top up decoded QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @nActMQTY = @nActMQTY + @nUCCQTY
         END
         ELSE
         BEGIN
            SET @nActPQTY = @nActPQTY + (@nUCCQTY / @nPUOM_Div) -- Calc QTY in preferred UOM
            SET @nActMQTY = @nActMQTY + (@nUCCQTY % @nPUOM_Div) -- Calc the remaining in master unit
         END
      END
      ELSE
      BEGIN
         IF @cSKULabel <> '' AND @cDisableQTYField = '1'
         BEGIN
            SET @nActQTY = @nActQTY + 1
            
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @nActMQTY = @nActQTY
            END
            ELSE
            BEGIN
               SET @nActPQTY = @nActQTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nActMQTY = @nActQTY % @nPUOM_Div -- Calc the remaining in master unit
            END
         END
      END
      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN '' ELSE CAST( @nActPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField13 = CAST( @nActMQTY AS NVARCHAR( 5)) -- MQTY

      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

         SET @cSQLParam =
               '@nMobile        INT,            ' +
               '@nFunc          INT,            ' +
               '@cLangCode      NVARCHAR(3),    ' +
               '@nStep          INT,            ' +
               '@cUserName      NVARCHAR( 18),  ' +
               '@cFacility      NVARCHAR( 5),   ' +
               '@cStorerKey     NVARCHAR( 15),  ' +
               '@cDropID        NVARCHAR( 20),  ' +
               '@cSKU           NVARCHAR( 20),  ' +
               '@nQty           INT,            ' +
               '@cToLabelNo     NVARCHAR( 20),  ' +
               '@cPTSLogKey     NVARCHAR( 20),  ' +
               '@cShort         NVARCHAR(1),    ' +
               '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +
               '@nErrNo         INT OUTPUT,     ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT


         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END


      END
      ELSE
      BEGIN
         -- Update rdt.rdtPTSLog
         UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
         SET  Status = '1' -- In Progress
            , Qty  = CASE WHEN Qty + @nActQTY  > ExpectedQty THEN Qty ELSE Qty + @nActQTY END
            , EditDate = GetDate()
         WHERE PTSLogKey = @cPTSLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180962
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
            GOTO Quit
         END
      END

      IF @cSKUValidated = '0'
         SET @cSKUValidated = '1'

      -- QTY fulfill
      IF @nActQTY = @nExpectedQTY
      BEGIN
         SET @cSKUValidated = 0

         -- Prepare next screen var
         SET @cOutField01 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END
         SET @cOutField02 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @c_oFieled01 = ''
            SET @c_oFieled02 = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @coFieled01 OUTPUT, @coFieled02 OUTPUT,' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

            SET @cSQLParam =
                  '@nMobile        INT,            ' +
                  '@nFunc          INT,            ' +
                  '@cLangCode      NVARCHAR(3),    ' +
                  '@nStep          INT,            ' +
                  '@cUserName      NVARCHAR( 18),  ' +
                  '@cFacility      NVARCHAR( 5),   ' +
                  '@cStorerKey     NVARCHAR( 15),  ' +
                  '@cDropID        NVARCHAR( 20),  ' +
                  '@cSKU           NVARCHAR( 20),  ' +
                  '@nQty           INT,            ' +
                  '@cToLabelNo     NVARCHAR( 20),  ' +
                  '@cPTSLogKey     NVARCHAR( 20),  ' +
                  '@cShort         NVARCHAR(1),    ' +
                  '@coFieled01   NVARCHAR(20) OUTPUT,   ' +
                  '@coFieled02   NVARCHAR(20) OUTPUT,   ' +
                  '@nErrNo         INT OUTPUT,     ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort,  @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT


            SET @cOutfield03 = ISNULL(@c_oFieled01,'')
            SET @cOutfield04 = ISNULL(@c_oFieled02,'')

         END
         ELSE
         BEGIN
            SET @cOutField03 = ''
            SET @cOutField04 = ''
         END

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- SKU scanned, remain in current screen
      IF @cSKULabel <> '' AND 
         @cSKUValidated <> '99' AND 
         @cDisableSKUField = '0'
      BEGIN
         SET @cOutField07 = '' -- SKU

         IF @cDisableQTYField = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
         ELSE
            IF @cFieldAttr12 = 'O'
               EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
         GOTO Quit
      END

      -- QTY short
      IF @nActQTY < @nExpectedQTY
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nErrNo = 180963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
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

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      GOTO QUIT
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6012.

   ToLabelNo       (field01)
   ToLabelNo       (field02, input)

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  --OR @nInputKey = 0
   BEGIN
      SET @cToLabelNo = ISNULL(RTRIM(@cInField02),'')

      IF @cToLabelNo = ''
      BEGIN
         SET @nErrNo = 180964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLabelNoReq'
         GOTO Step_3_Fail
      END

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOLABELNO', @cToLabelNo) = 0
      BEGIN
         SET @nErrNo = 180965
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      IF ISNULL(RTRIM(@cExtendedUpdateSP),'')  = ''
      BEGIN

         -- Update rdt.rdtPTSLog
         UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
         SET  Status = '9' -- In Progress
            , LabelNo = @cToLabelNo
            , EditDate = GetDate()
         WHERE PTSLogKey = @cPTSLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180966
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
          BEGIN
              SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

              SET @cSQLParam =
                    '@nMobile        INT,            ' +
                    '@nFunc          INT,            ' +
                    '@cLangCode      NVARCHAR(3),    ' +
                    '@nStep          INT,            ' +
                    '@cUserName      NVARCHAR( 18),  ' +
                    '@cFacility      NVARCHAR( 5),   ' +
                    '@cStorerKey     NVARCHAR( 15),  ' +
                    '@cDropID        NVARCHAR( 20),  ' +
                    '@cSKU           NVARCHAR( 20),  ' +
                    '@nQty           INT,            ' +
                    '@cToLabelNo     NVARCHAR( 20),  ' +
                    '@cPTSLogKey     NVARCHAR( 20),  ' +
                    '@cShort         NVARCHAR(1),    ' +
                    '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +
                    '@nErrNo         INT OUTPUT,     ' +
                    '@cErrMsg        NVARCHAR( 20) OUTPUT'

              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,
                    @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail
          END

      END

      -- Insert WCS ( conveyor info). Due to WSC db could be different server (linked server)  
      -- the wcs stored proc cannot put within transaction block (no rollback allowed)  
      -- Extended wcs  
      IF @cExtendedWCSSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedWCSSP) +  
					' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
					'@nStep				INT,            ' +
               '@cUserName			NVARCHAR( 18),  ' +
					'@cFacility			NVARCHAR( 5),   ' +
               '@cStorerKey		NVARCHAR( 15),  ' +
               '@cDropID			NVARCHAR( 20),  ' +
               '@cSKU				NVARCHAR( 20),  ' +
               '@nQty				INT,            ' +
               '@cToLabelNo		NVARCHAR( 20),  ' +
               '@cPTSLogKey		NVARCHAR( 20),  ' +
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '   
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
              @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey,
				  @nErrNo OUTPUT, @cErrMsg OUTPUT
         END  
      END  

      -- Get Next Task
      -- If Got Task Same Loc Go to Screen 3
      -- If Got Task Diff Loc Go to Screen 2
      IF @cGetNextTaskSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

            SET @cSQLParam =
               '@nMobile        INT,            ' +
               '@nFunc          INT,            ' +
               '@cLangCode      NVARCHAR(3),    ' +
               '@nStep          INT,            ' +
               '@cUserName      NVARCHAR( 18),  ' +
               '@cFacility      NVARCHAR( 5),   ' +
               '@cStorerKey     NVARCHAR( 15),  ' +
               '@cDropID        NVARCHAR( 20),  ' +
               '@cSKU           NVARCHAR( 20),  ' +
               '@nQty           INT,            ' +
               '@cLabelNo       NVARCHAR( 20),  ' +
               '@cPTSPosition   NVARCHAR( 20),  ' +
               '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +
               '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
               '@cScnText       NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo         INT OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 180967
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
               GOTO Step_3_Fail
            END

            SET @cSuggPTSPosition   = ''
            SET @cSuggSKU           = ''
            SET @nExpectedQty       = ''
            SET @cScnText           = ''
            SET @cSuggDropID        = ''


            SELECT TOP 1
                  @cSuggSKU         = PTSLOG.SKU
                , @nExpectedQty     = PTSLOG.ExpectedQty
                , @cScnText         = PTSLOG.ConsigneeKey
                , @cSuggDropID      = PTSLog.DropID
                , @cPTSLogKey       = PTSLog.PTSLogKey
                , @cLot             = PTSLog.Lot
            FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
            WHERE PTSLOG.StorerKey = @cStorerKey
            AND PTSLOG.AddWho = @cUserName
            AND PTSLOG.PTSLogKey = @cPTSLogKey

         END
      END  -- IF @cGetNextTaskSP <> ''
      ELSE
      BEGIN

         SET @cSuggSKU           = ''
         SET @nExpectedQty       = ''
         SET @cScnText           = ''
         SET @cSuggDropID        = ''
         SET @cPTSLogKey = ''

         SELECT TOP 1
              @cSuggSKU         = PTSLOG.SKU
             , @nExpectedQty     = PTSLOG.ExpectedQty
             , @cScnText         = PTSLOG.ConsigneeKey
             , @cSuggDropID      = PTSLog.DropID
             , @cPTSLogKey       = PTSLog.PTSLogKey
             , @cLot             = PTSLog.Lot
         FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
         WHERE PTSLOG.StorerKey = @cStorerKey
         AND PTSLOG.AddWho = @cUserName
         AND Status = '0'
         ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY

      END

      IF ISNULL(@cPTSLogKey,'')  = ''
      BEGIN
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO QUIT
      END

      SET @cSKUDescr = ''
      SET @cMUOM_Desc = ''
      SET @cPUOM_Desc = ''
      SET @nPUOM_Div = ''


      SELECT
			@cLottableCode = SKU.LottableCode,
			@cSKUDescr = SKU.Descr,
			@cMUOM_Desc = Pack.PackUOM3,
			@cPUOM_Desc =
				CASE @cPUOM
					WHEN '2' THEN Pack.PackUOM1 -- Case
					WHEN '3' THEN Pack.PackUOM2 -- Inner pack
					WHEN '6' THEN Pack.PackUOM3 -- Master unit
					WHEN '1' THEN Pack.PackUOM4 -- Pallet
					WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
					WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
				END,
			@nPUOM_Div = CAST( IsNULL(
				CASE @cPUOM
					WHEN '2' THEN Pack.CaseCNT
					WHEN '3' THEN Pack.InnerPack
					WHEN '6' THEN Pack.QTY
					WHEN '1' THEN Pack.Pallet
					WHEN '4' THEN Pack.OtherUnit1
					WHEN '5' THEN Pack.OtherUnit2
				END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSuggSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nExpectedQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prep QTY screen var
      SET @cOutField01 = @cSuggDropID

      SET @cOutField02 = @cScnLabel
      SET @cOutField03 = @cScnText

      SELECT
         @cLottable01 = LA.Lottable01,
         @cLottable02 = LA.Lottable02,
         @cLottable03 = LA.Lottable03,
         @dLottable04 = LA.Lottable04,
         @dLottable05 = LA.Lottable05,
         @cLottable06 = LA.Lottable06,
         @cLottable07 = LA.Lottable07,
         @cLottable08 = LA.Lottable08,
         @cLottable09 = LA.Lottable09,
         @cLottable10 = LA.Lottable10,
         @cLottable11 = LA.Lottable11,
         @cLottable12 = LA.Lottable12,
         @dLottable13 = LA.Lottable13,
         @dLottable14 = LA.Lottable14,
         @dLottable15 = LA.Lottable15
      FROM dbo.LotAttribute LA WITH (NOLOCK)
      WHERE Lot = @cLot

      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 6,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType


      SET @cOutField04 = @cSuggSKU
      SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
      SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END

      -- Disable QTY field
      SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
      SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

      IF @cPUOM_Desc = ''
      BEGIN

         --SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField10 = '' -- @nPQTY
         SET @cOutField12 = '' -- @nActPQTY
         --SET @cOutField14 = '' -- @nPUOM_Div
         -- Disable pref QTY field
         SET @cFieldAttr12 = 'O'

      END
      ELSE
      BEGIN
         --SET @cOutField08 = @cPUOM_Desc
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END
         --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END

      --SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY AS NVARCHAR( 5))   ELSE  '' END

      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc

      --SET @nCountScanTask = 0
      --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

      SET @cSKU = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @nActPQTY = 0
      SET @nActMQTY = 0
      SET @cSKUValidated = '0'

      -- GOTO Next Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU

      GOTO QUIT

   END  -- Inputkey = 1

   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = @cSuggLabelNo
      SET @cOutField02 = ''
   END

END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 6013.

   Short Pack ?
   Option          (field01, input)


********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOptions = ISNULL(RTRIM(@cInField01),'')

      IF @cOptions = ''
      BEGIN
         SET @nErrNo = 180971
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'
         GOTO Step_4_Fail
      END

      IF @cOptions NOT IN ( '1', '9' )
      BEGIN
         SET @nErrNo = 180972
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'
         GOTO Step_4_Fail
      END

      IF @cOptions = '1'
      BEGIN

         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN

               SET @cShort = '1'

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

               SET @cSQLParam =
                     '@nMobile        INT,            ' +
                     '@nFunc          INT,            ' +
                     '@cLangCode      NVARCHAR(3),    ' +
                     '@nStep          INT,            ' +
                     '@cUserName      NVARCHAR( 18),  ' +
                     '@cFacility      NVARCHAR( 5),   ' +
                     '@cStorerKey     NVARCHAR( 15),  ' +
                     '@cDropID        NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20),  ' +
                     '@nQty           INT,            ' +
                     '@cToLabelNo     NVARCHAR( 20),  ' +
                     '@cPTSLogKey     NVARCHAR( 20),  ' +
                     '@cShort         NVARCHAR(1),    ' +
                     '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +
                     '@nErrNo         INT OUTPUT,     ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_4_Fail
            END
         END  -- IF @cExtendedUpdateSP <> ''
         ELSE
         BEGIN
            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
            SET Qty  = @nActQTY
               ,Status = '4'
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 180973
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail
               EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
               GOTO Step_4_Fail
            END
         END

         SET @cOutField01 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END
         SET @cOutField02 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END

         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO QUIT
      END

      IF @cOptions = '9'
      BEGIN
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cShort = '0'

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

               SET @cSQLParam =
                     '@nMobile        INT,            ' +
                     '@nFunc          INT,            ' +
                     '@cLangCode      NVARCHAR(3),    ' +
                     '@nStep          INT,            ' +
                     '@cUserName      NVARCHAR( 18),  ' +
                     '@cFacility      NVARCHAR( 5),   ' +
                     '@cStorerKey     NVARCHAR( 15),  ' +
                     '@cDropID        NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20),  ' +
                     '@nQty           INT,            ' +
                     '@cToLabelNo     NVARCHAR( 20),  ' +
                     '@cPTSLogKey     NVARCHAR( 20),  ' +
                     '@cShort         NVARCHAR(1),    ' +
                     '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +
                     '@nErrNo         INT OUTPUT,     ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_4_Fail
            END
         END  
         ELSE
         BEGIN

            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
            SET Qty  = @nActQTY
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 180974
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail
               EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU
               GOTO Step_4_Fail
            END

            INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
            SELECT PTSPosition, '0', DropID, LabelNo ,StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                  ,@nExpectedQTY - @nActQTY, 0, @cPTSLogKey, @nFunc, GetDate(), @cUserName
            FROM rdt.rdtPTSLog WITH (NOLOCK)
            WHERE PTSLogKey = @cPTSLogKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 180975
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail
               GOTO Step_4_Fail
            END
         END


         IF ISNULL(@nActQTY,0 )  > 0 -- IF QTY not Blank goto To Label Screen
         BEGIN
            SET @cOutField01 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END
            SET @cOutField02 = CASE WHEN @cDefaultToLabel = '1' THEN  @cSuggLabelNo ELSE '' END

            SET @nScn  = @nScn - 1
            SET @nStep = @nStep - 1

            GOTO QUIT
         END
         ELSE IF ISNULL(@nActQTY,0) = 0 -- IF QTY = 0 Go Get Task SP
         BEGIN
            -- Get Next Task

            SET @cPTSLogKey         = ''
            SET @cSuggPTSPosition   = ''
            SET @cSuggSKU           = ''
            SET @nExpectedQty       = ''
            SET @cScnText           = ''
            SET @cSuggDropID        = ''

            IF @cGetNextTaskSP <> ''
            BEGIN
               SET @cPTSLogKey = ''

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'

                  SET @cSQLParam =
                     '@nMobile        INT,            ' +
                     '@nFunc          INT,            ' +
                     '@cLangCode      NVARCHAR(3),    ' +
                     '@nStep          INT,            ' +
                     '@cUserName      NVARCHAR( 18),  ' +
                     '@cFacility      NVARCHAR( 5),   ' +
                     '@cStorerKey     NVARCHAR( 15),  ' +
                     '@cDropID        NVARCHAR( 20),  ' +
                     '@cSKU           NVARCHAR( 20),  ' +
                     '@nQty           INT,            ' +
                     '@cLabelNo       NVARCHAR( 20),  ' +
                     '@cPTSPosition   NVARCHAR( 20),  ' +
                     '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +
                     '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
                     '@cScnText       NVARCHAR( 20) OUTPUT, ' +
                     '@nErrNo         INT OUTPUT, ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 180976
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
                  END

                  SELECT TOP 1
                       @cSuggSKU         = PTSLOG.SKU
                      , @nExpectedQty     = PTSLOG.ExpectedQty
                      , @cScnText         = PTSLOG.ConsigneeKey
                      , @cSuggDropID      = PTSLog.DropID
                      , @cLot             = PTSLog.Lot
                  FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
                  WHERE PTSLOG.StorerKey = @cStorerKey
							AND PTSLOG.AddWho = @cUserName
							AND PTSLogKey = @cPTSLogKey
					END
            END  -- IF @cGetNextTaskSP <> ''
            ELSE
            BEGIN
               SELECT TOP 1
                     @cSuggSKU         = PTSLOG.SKU
                   , @nExpectedQty     = PTSLOG.ExpectedQty
                   , @cScnText         = PTSLOG.ConsigneeKey
                   , @cSuggDropID      = PTSLog.DropID
                   , @cPTSLogKey       = PTSLog.PTSLogKey
                   , @cLot             = PTSLog.Lot
               FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)
               WHERE PTSLOG.StorerKey = @cStorerKey
               AND PTSLOG.AddWho = @cUserName
               AND Status = '0'
               ORDER BY PTSLOG.PTSPosition, PTSLOG.SKU, PTSLOG.PTSLOGKEY

               IF ISNULL(@cPTSLogKey , '' ) = ''
               BEGIN
                  SET @nErrNo = 180977
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
               END
            END

            IF ISNULL( @nErrNo , 0 ) = 0
            BEGIN

               -- GOTO Next Screen
               SET @nScn = @nScn - 2
               SET @nStep = @nStep - 2

               GOTO QUIT
            END
            ELSE
            BEGIN
               SET @cOutField01 = ''
               SET @cOutField02 = ''

               -- GOTO Next Screen
               SET @nScn = @nScn - 3
               SET @nStep = @nStep - 3

               GOTO QUIT
            END

         END

      END
   END  -- Inputkey = 1

   IF @nInputKey = 0 -- ESC
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



      SET @cSKUDescr = ''
      SET @cMUOM_Desc = ''
      SET @cPUOM_Desc = ''
      SET @nPUOM_Div = ''


      SELECT
         @cLottableCode = SKU.LottableCode,
         @cSKUDescr = SKU.Descr,
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =
            CASE @cPUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
         @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSuggSKU


      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nExpectedQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prep QTY screen var

      SET @cOutField01 = @cSuggDropID

      IF @cGetNextTaskSP = ''
      BEGIN
         SET @cOutField02 = 'CONSIGNEEKEY:'
         SET @cOutField03 = @cScnText
      END
      ELSE
      BEGIN
         SET @cOutField02 = @cScnLabel
         SET @cOutField03 = @cScnText
      END

      SELECT
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15
      FROM dbo.LotAttribute LA WITH (NOLOCK)
      WHERE Lot = @cLot

      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 6,
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nMorePage   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT,
            '',      -- SourceKey
            @nFunc   -- SourceType

      SET @cOutField04 = @cSuggSKU
      --SET @cOutField05 = SUBSTRInG(@cSKUDescr, 1, 20)
      --SET @cOutField06 = SUBSTRInG(@cSKUDescr, 21, 20)

      SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
      SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSKU ELSE '' END

      -- Disable QTY field
      SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
      SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

      IF @cPUOM_Desc = ''
      BEGIN

         --SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField10 = '' -- @nPQTY
         SET @cOutField12 = '' -- @nActPQTY
         --SET @cOutField14 = '' -- @nPUOM_Div
         -- Disable pref QTY field
         SET @cFieldAttr12 = 'O'

      END
      ELSE
      BEGIN
         --SET @cOutField08 = @cPUOM_Desc
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END
         --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END

      --SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY AS NVARCHAR( 5))   ELSE  '' END

      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc

      SET @nCountScanTask = 0
      --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

      SET @cSKU = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @nActPQTY = 0
      SET @nActMQTY = 0
      SET @cSKUValidated = '0'

      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      GOTO QUIT
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField02 = '' -- ActPQTY

   END

END
GOTO QUIT


/********************************************************************************
Step 5. Scn = 4505.

   Task Completed
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1  OR @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4

      GOTO QUIT

   END  

END
GOTO QUIT

/********************************************************************************    
Step 10. Screen = 3570. Multi SKU    
   SKU         (Field01)    
   SKUDesc1    (Field02)    
   SKUDesc2    (Field03)    
   SKU         (Field04)    
   SKUDesc1    (Field05)    
   SKUDesc2    (Field06)    
   SKU         (Field07)    
   SKUDesc1    (Field08)    
   SKUDesc2    (Field09)    
   Option      (Field10, input)    
********************************************************************************/    
Step_6:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,  
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  
         'CHECK',  
         @cMultiSKUBarcode,  
         @cStorerKey,  
         @cSKU     OUTPUT,  
         @nErrNo   OUTPUT,  
         @cErrMsg  OUTPUT,
         '',    -- DocType    
         ''    
  
      IF @nErrNo <> 0  
      BEGIN  
         IF @nErrNo = -1  
            SET @nErrNo = 0  
         GOTO Quit  
      END     
         
      -- Prep QTY screen var
      SET @cOutField01 = @cSuggDropID

      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField04 = @cSuggSKU
     -- SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
      SET @cOutField07 =@cSKU-- CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END
      SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
      SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField10 = '' -- @nPQTY
         SET @cOutField12 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr12 = 'O'

      END
      ELSE
      BEGIN
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY
		END

      --SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY

      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc
    
      -- Go to SKU QTY screen    
      SET @nScn = @nFromScn    
      SET @nStep = @nFromStep    
    
      -- To indicate sku has been successfully selected    
      SET @nFromScn = 3570    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prep QTY screen var
      SET @cOutField01 = @cSuggDropID

      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField04 = @cSuggSKU
      SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU
      SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END
      SET @cFieldAttr12 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
      SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField10 = '' -- @nPQTY
         SET @cOutField12 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr12 = 'O'

      END
      ELSE
      BEGIN
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY
		END

      --SET @cOutField09 = @cMUOM_Desc
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY

      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc

      SET @nCountScanTask = 0
      --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))

      SET @cSKU = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @nActPQTY = 0
      SET @nActMQTY = 0
      SET @cSKUValidated = '0'    
    
      -- Go to SKU QTY screen    
      SET @nScn = @nFromScn    
      SET @nStep = @nFromStep    
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      -- UserName  = @cUserName,
      InputKey  = @nInputKey,
      LightMode = @cLightMode,

      V_SKUDescr = @cSKUDescr,
      V_UOM = @cPUOM,
      V_SKU = @cSKU,
      V_Qty = @nExpectedQTY,
      V_Lot = @cLot,
      
      V_PUOM_Div  = @nPUOM_Div,
      V_MQTY      = @nMQTY,
      V_PQTY      = @nPQTY,
      
      V_Integer1  = @nExpectedQTY,
      V_Integer2  = @nActMQTY,
      V_Integer3  = @nActPQTY,
      V_Integer4  = @nActQty,
      V_Integer5  = @nFromScn,
      V_Integer6  = @nFromStep,

      V_String1 = @cExtendedUpdateSP   ,
      V_String2 = @cExtendedValidateSP ,
      V_String3 = @cDecodeLabelNo      ,
      V_String4 = @cDefaultQTY         ,
      V_String5 = @cDisableSKUField    ,
      V_String6 = @cGeneratePackDetail ,
      V_String7 = @cGetNextTaskSP,
      V_String8 = @cSuggPTSPosition,
      V_String9 = @cSuggSKU,
      V_String10 = @cSuggDropID,
      V_String11 = @cMUOM_Desc,
      V_String12 = @cPUOM_Desc,
      V_String13 = @cScnText,
      --V_String14 = @nExpectedQTY,
      V_String15 = @cSKUValidated,
      V_String16 = @cPTSLogKey,
      V_String17 = @cAlloWOneDropID ,
      --V_String18 = @nMQTY     ,
      --V_String19 = @nPQTY     ,
      --V_String20 = @nActMQTY  ,
      --V_String21 = @nActPQTY  ,
      --V_String22 = @nActQty   ,
      --V_String23 = @nQty,
      V_String24 = @cPTSPosition,
      V_String25 = @cScnLabel,
      V_String26 = @cShort,
      V_String27 = @cDropID,
      V_String29 = @cDefaultToLabel,
      V_String30 = @cExtendedInfoSP,
      V_String31 = @cPickStatus,
      V_String32 = @cDisableQTYField,
		V_String33 = @cExtendedWCSSP,
      V_String34 = @cMultiSKUBarcode,

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