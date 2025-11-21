SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_BatchPickSortation                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Batch picking Sortation (SOS283551)                         */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 17-Jul-2013 1.0  James    Created                                    */
/* 19-Aug-2013 1.1  James    Bug fix (james01)                          */
/* 21-Oct-2015 1.2  James    SOS354881 - Add config to skip             */ 
/*                           "SKU ALL SORTED" screen (james02)          */
/* 30-Sep-2016 1.3  Ung      Performance tuning                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_BatchPickSortation] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success       INT,
   @n_err           INT,
   @c_errmsg        NVARCHAR(250),
   @nSKUCnt         INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),
   @cLOC                NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),

   @cWaveKey            NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cOrderLineNo        NVARCHAR( 5),
   @cBatchNo            NVARCHAR( 10),
   @cTempBatchNo        NVARCHAR( 10),
   @cPrinter            NVARCHAR( 10) ,
   @cLoadKey            NVARCHAR( 10),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cSQL                NVARCHAR( 1000), 
   @cSQLParam           NVARCHAR( 1000), 
   @cOtherParm01        NVARCHAR( 20), 
   @cOtherParm02        NVARCHAR( 20), 
   @cOtherParm03        NVARCHAR( 20), 
   @cOtherParm04        NVARCHAR( 20), 
   @cOtherParm05        NVARCHAR( 20), 
   @cOtherParm06        NVARCHAR( 20), 
   @cOtherParm07        NVARCHAR( 20), 
   @cOtherParm08        NVARCHAR( 20), 
   @cOtherParm09        NVARCHAR( 20), 
   @cOtherParm10        NVARCHAR( 20), 
   @cSeqNo              NVARCHAR( 5), 
   @cTempSKU            NVARCHAR( 20), 
   @cQty                NVARCHAR( 5), 
   @cErrMsg1            NVARCHAR( 20),         
   @cErrMsg2            NVARCHAR( 20),         
   @cErrMsg3            NVARCHAR( 20),         
   @cErrMsg4            NVARCHAR( 20),         
   @cErrMsg5            NVARCHAR( 20),  
   @nQty                INT,
   @nTQty               INT,
   @nUpdQty             INT,
   @nBalQty             INT,
   @nScanQTY            INT,
   @nPageNo             INT,  
   @nTotalPage          INT,  
   @nQtyToProcess       INT,  
   @nQtyToScan          INT,
   @nQtyScanned         INT,
   @nExpQTY             INT, 
   @nSKUExpQTY          INT, 
   @nTtlScanQty         INT, 
   @nTtlExpQty          INT, 
   @nTtlSKUInLoad       INT, 
   @nSortQty            INT, 
   @nTranCount          INT, 
      
   @cFlowThruSortationPieceScaning     NVARCHAR( 1),
   @cFlowThruSortationLockQty          NVARCHAR( 1), 
   @cFlowThruSortationSkipSortedScn    NVARCHAR( 1),  -- (james02)
   
   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1)
   -- (Vicky02) - End

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @cPrinter         = Printer,


   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cSKU             = V_SKU,
   @nQty             = V_QTY, 

   @cLoadKey         = V_LoadKey, 
   @cWaveKey         = V_String1,
   @cBatchNo         = V_String2,
   @cFlowThruSortationPieceScaning = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @cFlowThruSortationLockQty      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @cFlowThruSortationSkipSortedScn= CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
   @nPageNo          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @nTotalPage       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,

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

   -- (Vicky02) - Start
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1709
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0    -- Menu. Func = 1709
   IF @nStep = 1  GOTO Step_1    -- Scn = 3590. LOADKEY
   IF @nStep = 2  GOTO Step_2    -- Scn = 3591. LOADKEY, SKU/UPC, SKUDesc, QTY, SKU QTY, Total QTY
   IF @nStep = 3  GOTO Step_3    -- Scn = 3592. LOADKEY, SKU/UPC, LOC, QTY
   IF @nStep = 4  GOTO Step_4    -- Scn = 3593. Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1709. Screen 0.
********************************************************************************/
Step_0:
BEGIN

   SET @cFlowThruSortationPieceScaning = ''
   SET @cFlowThruSortationPieceScaning = rdt.RDTGetConfig( @nFunc, 'FlowThruSortationPieceScaning', @cStorerKey)

   SET @cFlowThruSortationLockQty = ''
   SET @cFlowThruSortationLockQty = rdt.RDTGetConfig( @nFunc, 'FlowThruSortationLockQty', @cStorerKey)

   SET @cFlowThruSortationSkipSortedScn = ''
   SET @cFlowThruSortationSkipSortedScn = rdt.RDTGetConfig( @nFunc, 'FlowThruSortationSkipSortedScn', @cStorerKey)

   SELECT
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''

   -- (Vicky02) - Start
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
   -- (Vicky02) - End

   -- Clear any left over data
   IF EXISTS ( SELECT 1 FROM rdt.rdtFlowThruSort WITH (NOLOCK)
               WHERE UserName = @cUserName
               AND LoadKey    = @cLoadKey
               AND Status     <> '9')
   BEGIN
      DELETE FROM rdt.rdtFlowThruSort 
      WHERE UserName = @cUserName
      AND   LoadKey    = @cLoadKey
      AND   Status     <> '9'
   END
      
   -- Prep next screen var
   SET @cLoadKey = ''      
   SET @cOutField01 = ''

   SET @nScn = 3590
   SET @nStep = 1
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 3590. Screen 1.
   LOADKEY (field01)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01   


      -- Validate blank
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 81751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOADKEY needed
         GOTO Step_1_Fail
      END


      IF not EXISTS ( SELECT 1 from dbo.LoadPlan WITH (NOLOCK)
                      WHERE LoadKey = @cLoadKey )
      BEGIN
         SET @nErrNo = 81752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LOADKEY
         GOTO Step_1_Fail
      END

      IF not EXISTS ( SELECT 1 FROM dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
                      INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (LPD.LoadKey = OD.LoadKey )
                     WHERE LPD.LoadKey = @cLoadKey
                     AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                     AND OD.QtyAllocated + OD.QtyPicked > 0 )
      BEGIN
         SET @nErrNo = 81753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadFullyDistr
         GOTO Step_1_Fail
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
            ' @nMobile, @nFunc, @cLangCode, @cStorerkey, @cWaveKey, @cLoadKey, @cOtherParm01, @cOtherParm02, ' + 
            ' @cOtherParm03, @cOtherParm04, @cOtherParm05, @cOtherParm06, @cOtherParm07, @cOtherParm08, ' + 
            ' @cOtherParm09, @cOtherParm10, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile                   INT,             ' +
            '@nFunc                     INT,             ' +
            '@cLangCode                 NVARCHAR( 3),    ' +
            '@cStorerkey                NVARCHAR( 15),   ' +
            '@cWaveKey                  NVARCHAR( 10),   ' +
            '@cLoadKey                  NVARCHAR( 10),   ' +
            '@cOtherParm01              NVARCHAR( 20),   ' +
            '@cOtherParm02              NVARCHAR( 20),   ' +
            '@cOtherParm03              NVARCHAR( 20),   ' +
            '@cOtherParm04              NVARCHAR( 20),   ' +
            '@cOtherParm05              NVARCHAR( 20),   ' +
            '@cOtherParm06              NVARCHAR( 20),   ' +
            '@cOtherParm07              NVARCHAR( 20),   ' +
            '@cOtherParm08              NVARCHAR( 20),   ' +
            '@cOtherParm09              NVARCHAR( 20),   ' +
            '@cOtherParm10              NVARCHAR( 20),   ' +
            '@bSuccess                  INT           OUTPUT,  ' +
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
              @nMobile, @nFunc, @cLangCode, @cStorerKey, @cWaveKey, @cLoadKey, @cOtherParm01, @cOtherParm02,  
              @cOtherParm03, @cOtherParm04, @cOtherParm05, @cOtherParm06, @cOtherParm07, @cOtherParm08,  
              @cOtherParm09, @cOtherParm10, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
              
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cLoadKey = ''
            SET @cOutField01 = '' -- Loadkey
            GOTO Quit
         END
      END

      SET @cSeqNo = ''
      EXEC rdt.rdt_BatchPickSortation_GetStat 
         @nMobile,
         @nFunc, 
         @cLoadKey,
         @cStorerKey,
         @cSKU,
         0, 
         @cSeqNo           OUTPUT,
         @nExpQTY          OUTPUT, 
         @nSKUExpQTY       OUTPUT, 
         @nTtlScanQty      OUTPUT, 
         @nTtlExpQty       OUTPUT, 
         @nTtlSKUInLoad    OUTPUT 
            
      -- Prep next screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''   -- SKU/UPC
      SET @cOutField03 = ''   -- SKU descr 1
      SET @cOutField04 = ''   -- SKU descr 2
      SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
      SET @cOutField06 = CAST( @nTtlScanQty AS NVARCHAR( 5)) + '/' + CAST( @nTtlExpQty AS NVARCHAR( 5))  --SKU QTY

      -- Disable the Qty field
      IF @cFlowThruSortationLockQty = '1'
         SET @cFieldAttr05 = 'O' 

      -- Clear any left over data
      IF EXISTS ( SELECT 1 FROM rdt.rdtFlowThruSort WITH (NOLOCK)
                  WHERE UserName = @cUserName
                  AND LoadKey    = @cLoadKey
                  AND Status     <> '9')
      BEGIN
         DELETE FROM rdt.rdtFlowThruSort 
         WHERE UserName = @cUserName
         AND   LoadKey    = @cLoadKey
         AND   Status     <> '9'
      END
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cLoadKey = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Loadkey
      SET @cLoadKey = ''
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 3591. Screen 2.
   LOADKEY        (field01)
   SKU/UPC        (field02)   - Input field
   SKUDesc (1-20) (field03)
   SKUDesc (21-40)(field04)
   QTY            (field05)   - Input field - default 1   StorerConfig - FlowThruSortationPieceScaning - to protect
   Total QTY      (field06)
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      IF ISNULL(@cOutField03, '') = ''
         GOTO GET_SKU
      ELSE
         GOTO GET_QTY
         
      GET_SKU:
      BEGIN
         -- Screen mapping
         SET @cTempSKU = @cInField02

         -- Validate SKU
         IF ISNULL(@cTempSKU, '') = ''
         BEGIN
            SET @nErrNo = 81754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU required'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cTempSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 81755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid SKU'
            SET @cOutField02 = ''
            SET @cTempSKU = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 81756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') -- 'MultiSKUBarcod'
            SET @cOutField02 = ''
            SET @cTempSKU = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Get SKU    (james03)
         EXEC [RDT].[rdt_GETSKU]    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cTempSKU      OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
            
         SET @cSKU = @cTempSKU

         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
                         WHERE Loadkey = @cLoadKey
                         AND SKU = @cSKU  )
         BEGIN
            SET @nErrNo = 81757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') -- 'SKU NotOnLoad'
            SET @cOutField02 = ''
            SET @cTempSKU = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
         
         SELECT @cSKUDescr = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU       = @cSKU

         EXEC rdt.rdt_BatchPickSortation_GetStat 
            @nMobile,
            @nFunc, 
            @cLoadKey,
            @cStorerKey,
            @cSKU,
            0, 
            @cSeqNo           OUTPUT,
            @nExpQTY          OUTPUT,
            @nSKUExpQTY       OUTPUT, 
            @nTtlScanQty      OUTPUT, 
            @nTtlExpQty       OUTPUT, 
            @nTtlSKUInLoad    OUTPUT 

         SET @cOutField02 = @cSKU   -- SKU/UPC
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)    -- SKU descr 1
         SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)   -- SKU descr 2

         -- In the case where user key in sku and qty simultaneously
         -- If sku is valid then go check qty validity
         IF ISNULL( @cInField05, '') <> ''
            GOTO GET_QTY

         -- If qty field is disabled then no need wait for user input qty (james02)
         IF @cFlowThruSortationLockQty = '1'
         BEGIN
            IF ISNULL( @cOutField05, '') <> ''
               GOTO GET_QTY         
         END

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Qty 
         
         SET @cOutField05 = @nExpQTY
         SET @cOutField06 = CAST( @nTtlScanQty AS NVARCHAR( 5)) + '/' + CAST( @nTtlExpQty AS NVARCHAR( 5))
         
         GOTO Quit
      END
      
      GET_QTY:
      BEGIN
         IF ISNULL(@cOutField02, '') = ''
         BEGIN
            SET @nErrNo = 81758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU required'
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- If qty field is disabled then take the outfield as qty (james02)
         IF @cFlowThruSortationLockQty = '1'
            SET @cQty = @cOutField05
         ELSE
            SET @cQty = @cInField05

         IF @cQty  = ''  
            SET @cQty  = '0' --'Blank taken as zero'  
  
         IF RDT.rdtIsValidQTY( @cQty, 1) = 0  
         BEGIN  
            SET @nErrNo = 81759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid QTY'
            SET @cQty = ''
            SET @cInField05 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Quit
         END

         SET @nQty = CAST( @cQty AS INT)
         
         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0), 
                @nQtyToProcess = ISNULL( SUM( QtyToProcess), 0)
         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
         AND   SKU = @cSKU
      
         SELECT @nQtyScanned = ISNULL( SUM( Qty), 0) 
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey 
         AND   SKU = @cSKU
         AND   Status = '0'
            
         IF (@nQtyToProcess + @nQtyScanned + @nQty) > @nQtyToScan
         BEGIN
            SET @nErrNo = 81760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') -- 'Over Scanned'
            SET @cQty = ''
            SET @cInField05 = ''
            SET @cOutField02 = ''   -- SKU/UPC           -- (james01)
            SET @cOutField03 = ''   -- SKU descr 1
            SET @cOutField04 = ''   -- SKU descr 2
            SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         SET @cSeqNo = ''
         EXEC rdt.rdt_BatchPickSortation_GetStat 
            @nMobile,
            @nFunc, 
            @cLoadKey,
            @cStorerKey,
            @cSKU,
            @nQty, 
            @cSeqNo           OUTPUT,
            @nExpQTY          OUTPUT, 
            @nSKUExpQTY       OUTPUT, 
            @nTtlScanQty      OUTPUT, 
            @nTtlExpQty       OUTPUT, 
            @nTtlSKUInLoad    OUTPUT 

         SET @nPageNo = 1
         SET @nTotalPage = @nTtlSKUInLoad
         
         -- Prepare next screen var
         SET @cOutField01 = CAST( @nPageNo AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)    -- SKU descr 1
         SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)   -- SKU descr 2
         SET @cOutField05 = @cSeqNo
         SET @cOutField06 = @nSKUExpQTY

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''
      SET @cLoadKey = ''
      
      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/************************************************************************************
Step_3. Scn = 3592. Screen 3.
   SEQ      (field01)
   SKU      (field01)
   LOC      (field01)
   QTY      (field01)
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cSeqNo = @cOutField05
      SET @nSortQty = CAST( @cOutField06 AS INT)
      
      SET @cBatchNo = ''
      SELECT @cBatchNo = MAX(BatchNo)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE UserName = @cUserName
      AND LoadKey    = @cLoadKey 
      AND Status     <> '9'
      
      IF ISNULL(@cBatchNo, '') = ''
      BEGIN
         SET @cTempBatchNo = ''
         SELECT @cTempBatchNo = Max(BatchNo)
         FROM rdtFlowThruSort WITH (NOLOCK)

         IF ISNULL(@cTempBatchNo, '') = ''
         BEGIN
            SET @cBatchNo = RIGHT('0000000000' + RTRIM(Cast(1 as NVARCHAR(10))) , 10)
         END
         ELSE
         BEGIN
            SET @cBatchNo = RIGHT('0000000000' + RTRIM(Cast( Cast(@cTempBatchNo as bigint) + 1 as NVARCHAR(10))) , 10)
         END
      END

      BEGIN TRAN
      
      IF EXISTS ( SELECT TOP 1 SKU FROM rdt.rdtFlowThruSort WITH (NOLOCK)
                        WHERE  BatchNo = @cBatchNo
                        AND UserName   = @cUserName
                        AND LoadKey    = @cLoadKey 
                        AND SKU        = @cSKU
                        AND Status     = '0' )
      BEGIN
         UPDATE rdt.rdtFlowThruSort WITH (ROWLOCK)
         SET Qty = Qty + @nSortQty
         WHERE BatchNo = @cBatchNo
         AND UserName  = @cUserName
         AND LoadKey   = @cLoadKey 
         AND SKU       = @cSKU
         AND Status    = '0'
         
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 81761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD WSort Fail'
            GOTO Quit
         END
         
         SET @nQty = @nQty - @nSortQty
      END
      ELSE
      BEGIN
         INSERT INTO rdt.rdtFlowThruSort ( BatchNo, UserName, Storerkey, SKU,  Qty, Status, LoadKey, WaveKey)
         VALUES (@cBatchNo, @cUserName, @cStorerKey, @cSKU, @nSortQty, '0', ISNULL(@cLoadKey, ''), '' )
            
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 81762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Add WSort Fail'
            GOTO Quit
         END
         
         SET @nQty = @nQty - @nSortQty
      END
      COMMIT TRAN

      EXEC rdt.rdt_BatchPickSortation_GetStat 
         @nMobile,
         @nFunc, 
         @cLoadKey,
         @cStorerKey,
         @cSKU,
         @nQty,
         @cSeqNo           OUTPUT,
         @nExpQTY          OUTPUT, 
         @nSKUExpQTY       OUTPUT, 
         @nTtlScanQty      OUTPUT, 
         @nTtlExpQty       OUTPUT, 
         @nTtlSKUInLoad    OUTPUT 

      SELECT @nTQty = ISNULL( SUM( QTY), 0)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo  = @cBatchNo
      AND UserName   = @cUserName
      AND LoadKey    = @cLoadKey 
      AND SKU        = @cSKU
      AND Status     = '0'
            
--      IF @nExpQTY = @nTQty
--      IF @nSortQty = @nTQty
--      BEGIN
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  
      SAVE TRAN UPD_QtyToProcess

      WHILE @nTQty > 0
      BEGIN
         SET @nUpdQty = 0
         SET @nBalQty = 0
         SET @nScanQty = 0
         SET @cOrderKey = ''
         SET @cOrderLineNo =''

         SELECT @cOrderKey = Orderkey 
         FROM dbo.LoadPlanDetail WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
         AND   UserDefine02 = @cOutField05
         
         SELECT TOP 1 @nBalQty  = QtyAllocated + QtyPicked - QtyToProcess,
                      @nScanQty = QtyToProcess,
                      @cOrderLineNo  = OrderLineNumber 
         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
         AND   OrderKey = @cOrderKey
         AND   SKU = @cSKU
         AND   QtyAllocated + QtyPicked > QtyToProcess
         AND   QtyAllocated + QtyPicked > 0
         ORDER BY OrderLineNumber   -- If sku exists in multiple order line within same orderkey

         IF @nBalQty > @nTQty
         BEGIN
            SET @nUpdQty = @nTQty
            SET @nTQty   = 0
         END
         ELSE
         BEGIN
            SET @nUpdQty = @nBalQty
            SET @nTQty   = @nTQty - @nBalQty
         END

         IF @nUpdQty <= 0
            BREAK
         
         IF @nUpdQty > 0
         BEGIN
            UPDATE dbo.ORDERDETAIL WITH (ROWLOCK)
            SET   QtyToProcess = QtyToProcess + @nUpdQty, TrafficCop = NULL
            WHERE OrderKey = @cOrderKey
            AND OrderLineNumber = @cOrderLineNo
            AND SKU = @cSKU
            AND QtyToProcess = @nScanQTY -- If UPDATE by other user, fail and refresh qty
            AND QtyAllocated + QtyPicked - QtyToProcess >= @nUpdQty

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN UPD_QtyToProcess
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  

               SET @nErrNo = 81764
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD ODtl Fail'
               GOTO Quit
            END

            --SET @nTQty = @nTQty - @nUpdQty
            
            IF @nTQty <= 0
            BEGIN
               UPDATE rdt.rdtFlowThruSort WITH (ROWLOCK) SET 
                  Status = '9'
               WHERE BatchNo  = @cBatchNo
               AND UserName   = @cUserName
               AND LoadKey    = @cLoadKey 
               AND Status     = '0'

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN UPD_QtyToProcess
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  

                  SET @nErrNo = 81765
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD ODtl Fail'
                  GOTO Quit
               END

               BREAK
            END
         END
      END   -- WHILE @nTQty > 0

      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
      --END   --    IF @nExpQTY = @nTQty
         
      IF ISNULL(@cSeqNo, '') = '' OR @nQty <= 0
      BEGIN
         EXEC rdt.rdt_BatchPickSortation_GetStat 
            @nMobile,
            @nFunc, 
            @cLoadKey,
            @cStorerKey,
            @cSKU,
            0,
            @cSeqNo           OUTPUT,
            @nExpQTY          OUTPUT, 
            @nSKUExpQTY       OUTPUT, 
            @nTtlScanQty      OUTPUT, 
            @nTtlExpQty       OUTPUT, 
            @nTtlSKUInLoad    OUTPUT 
            
         -- Everything scanned, goto screen 4   
         IF @nTtlScanQty = @nTtlExpQty
         BEGIN
            -- Goto next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
         ELSE
         BEGIN
            IF @cFlowThruSortationSkipSortedScn <> '1'
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = 'SKU All Sorted'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
                  SET @cErrMsg1 =''
            END

            -- Prep next screen var
            SET @cOutField01 = @cLoadKey
            SET @cOutField02 = ''   -- SKU/UPC
            SET @cOutField03 = ''   -- SKU descr 1
            SET @cOutField04 = ''   -- SKU descr 2
            SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
            SET @cOutField06 = CAST( @nTtlScanQty AS NVARCHAR( 5)) + '/' + CAST( @nTtlExpQty AS NVARCHAR( 5))  --SKU QTY

            EXEC rdt.rdtSetFocusField @nMobile, 2
         
            -- Disable the Qty field
            IF @cFlowThruSortationLockQty = '1'
               SET @cFieldAttr05 = 'O' 

            -- Back to previous screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1

         END
      END
      ELSE
      BEGIN
         SELECT @cSKUDescr = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU       = @cSKU
         
         SET @nPageNo = @nPageNo + 1

         -- Prepare next screen var
         SET @cOutField01 = CAST( @nPageNo AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)    -- SKU descr 1
         SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)   -- SKU descr 2
         SET @cOutField05 = @cSeqNo
         SET @cOutField06 = @nSKUExpQTY
      END
      
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cSeqNo = ''
      EXEC rdt.rdt_BatchPickSortation_GetStat 
         @nMobile,
         @nFunc, 
         @cLoadKey,
         @cStorerKey,
         @cSKU,
         0,
         @cSeqNo           OUTPUT,
         @nExpQTY          OUTPUT, 
         @nSKUExpQTY       OUTPUT, 
         @nTtlScanQty      OUTPUT, 
         @nTtlExpQty       OUTPUT, 
         @nTtlSKUInLoad    OUTPUT 
         
      -- Everything scanned, goto screen 4   
      IF @nTtlScanQty = @nTtlExpQty
      BEGIN
         -- Goto next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''   -- SKU/UPC
         SET @cOutField03 = ''   -- SKU descr 1
         SET @cOutField04 = ''   -- SKU descr 2
         SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
         SET @cOutField06 = CAST( @nTtlScanQty AS NVARCHAR( 5)) + '/' + CAST( @nTtlExpQty AS NVARCHAR( 5))  --SKU QTY

         EXEC rdt.rdtSetFocusField @nMobile, 2
      
         -- Disable the Qty field
         IF @cFlowThruSortationLockQty = '1'
            SET @cFieldAttr05 = 'O' 

         -- Back to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit
END
GOTO Quit

/************************************************************************************
Step_4. Scn = 3593. Screen 4.
   MESSAGE
************************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cOutField01 = ''
      SET @cLoadKey = ''
      
      -- Go back first screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''
      SET @cLoadKey = ''
      
      -- Go back first screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit

/********************************************************************************
Quit. UPDATE back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      Printer        = @cPrinter,

      V_SKU          = @cSKU,
      V_QTY          = @nQty, 
      V_LoadKey      = @cLoadKey, 
      V_String1      = @cWaveKey,
      V_String2      = @cBatchNo,

      V_String3      = @cFlowThruSortationPieceScaning,
      V_String4      = @cFlowThruSortationLockQty,
      V_String5      = @cFlowThruSortationSkipSortedScn,
      V_String6      = @nPageNo, 
      V_String7      = @nTotalPage, 
      
      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15,

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
END

GO