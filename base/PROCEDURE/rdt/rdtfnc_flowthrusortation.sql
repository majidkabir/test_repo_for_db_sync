SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_FlowThruSortation                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Flow Thru Sortation (SOS101115)                             */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 13-Sep-2007 1.0  MaryVong Created                                    */
/* 25-Oct-2007 1.1  Shong    Using TrafficCop with updateing Order Det  */
/* 22-Nov-2007 1.2  Shong    SOS90411 Display error in another screen   */
/* 02-Sep-2008 1.3  Vicky    Modify to cater for SQL2005 (Vicky01)      */
/* 03-Nov-2008 1.4  Vicky    Remove XML part of code that is used to    */
/*                           make field invisible and replace with new  */
/*                           code (Vicky02)                             */
/* 25-Mar-2009 1.5  James    SOS131513 - Add in configkey               */
/*                           'FlowThruSortationPrintSortLabel'          */
/* 17-Jun-2010 1.6  James    Bug Fix (james01)                          */
/* 21-Jun-2010 1.7  Leong    Bug Fix (Leong01)                          */
/* 29-May-2013 1.8  James    SOS279025 - Zara e-comm changes (james02)  */
/* 13-Jun-2013 1.9  James    Several enhancement (james03)              */
/* 30-Sep-2016 2.0  Ung      Performance tuning                         */
/* 16-Jan-2018 2.1  ChewKP   WMS-3767-Call rdt.rdtPrintJob (ChewKP01)   */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_FlowThruSortation] (
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
   @nFunc           INT,
   @nScn            INT,
   @nStep           INT,
   @cLangCode       NVARCHAR(3),
   @nInputKey       INT,
   @nMenu           INT,

   @cStorer         NVARCHAR(15),
   @cUserName       NVARCHAR(18),
   @cFacility       NVARCHAR(5),
   @cLOC            NVARCHAR(10),
   @cSKU            NVARCHAR(20),
   @cSKUDescr       NVARCHAR(60),

   @cWaveKey        NVARCHAR(10),
   @cOrderKey       NVARCHAR(10),
   @cOrderLineNo    NVARCHAR(5),
   @cConsigneekey   NVARCHAR(15),
   @cC_Company      NVARCHAR(20),
   @nAllocPickQTY   INT,
   @nTotScanQTY     INT,
   @nScanQTY        INT,

   @nTotalQty       INT,
   @nSKUQty         INT,
   @nQty            INT,
   @cOption         NVARCHAR(1),
   @cCallSource     NVARCHAR(1),
   @cCallSource2    NVARCHAR(1),
   @cCallSource3    NVARCHAR(1),
   @cBatchNo        NVARCHAR(10),
   @cTempBatchNo    NVARCHAR(10),
   @cTOrderKey      NVARCHAR(10),
   @cTSKU           NVARCHAR(20),
   @nTQty           INT,
   @nUpdQty         INT,
   @nBalQty         INT,
   @cPickSlipNo     NVARCHAR(10),
   @cV_OrderKey     NVARCHAR(10),
   @cV_Sku          NVARCHAR(20),
   @n_TotalOrder    INT,
   @cSku1           NVARCHAR(20),
   @cQty1           NVARCHAR(5),
   @n_NoOrder       INT,
   @n_TotalSKu      INT,
   @cSku2           NVARCHAR(20),
   @cSku3           NVARCHAR(20),
   @cQty2           NVARCHAR(5),
   @cQty3           NVARCHAR(5),
   @n_SKuPage       INT,
   @cFlowThruSortationPieceScaning   NVARCHAR(1),
   @cXML            NVARCHAR(4000), -- To allow double byte data for e.g. SKU desc
   @cPrinter        NVARCHAR(10) ,
   @cFlowThruSortationPrintSortList NVARCHAR(1),
   @cFlowThruSortationPrintLabel    NVARCHAR(1),
   @cDataWindow     NVARCHAR( 50),
   @cTargetDB       NVARCHAR( 20),
   
   -- (james02)
   @cLoadKey            NVARCHAR( 10),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
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
   @nSeqNo              INT,  
   @nQtyToProcess       INT,  
   @nQtyToScan          INT,
   @nQtyScanned         INT,
   @nTtlSKUQty          INT,
   @nTtlQty             INT,
   @nTtlQtyToProcess    INT,
   @cSeqNo              NVARCHAR( 5), 
   @cTempSKU            NVARCHAR( 20), 
   @cLastSKU           NVARCHAR( 20), 
   @cFlowThruSortationLockQty    NVARCHAR( 1), 


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


   @cStorer          = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cV_SKU           = V_SKU,
   @cV_OrderKey      = V_OrderKey,
   @cLoadKey         = V_LoadKey, 
   @cWaveKey         = V_String1,
   @cBatchNo         = V_String2,
   @cFlowThruSortationPieceScaning = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @cFlowThruSortationLockQty      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @cLastSKU         = V_String5,

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

IF @nFunc = 1710
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0 -- Menu. Func = 1710
   IF @nStep = 1  GOTO Step_1   -- Scn = 1710. WAVEKEY
   IF @nStep = 2  GOTO Step_2 -- Scn = 1711. WAVEKEY, SKU/UPC, SKUDesc, QTY, SKU QTY, Total QTY
   IF @nStep = 3  GOTO Step_3 -- Scn = 1712. Start distribute? 1=YES  2=NO  OPTION:
   IF @nStep = 4  GOTO Step_4 -- Scn = 1713. DISTRIBUTE:   ORDERKEY, PKSLIPNO, CONSIGNEE/COMPANY, SKU, QTY
   IF @nStep = 5  GOTO Step_5 -- Scn = 1714. Finish distribute? 1=YES  2=NO  OPTION:
   IF @nStep = 6  GOTO Step_6 -- Scn = 1715. Everything will be deleted? 1=YES  2=NO  OPTION:
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1710. Screen 0.
********************************************************************************/
Step_0:
BEGIN

   SET @cFlowThruSortationPieceScaning = ''
   SET @cFlowThruSortationPieceScaning = rdt.RDTGetConfig( @nFunc, 'FlowThruSortationPieceScaning', @cStorer)

   SET @cFlowThruSortationLockQty = ''
   SET @cFlowThruSortationLockQty = rdt.RDTGetConfig( @nFunc, 'FlowThruSortationLockQty', @cStorer)

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

   -- Prep next screen var
      SET @cWaveKey = ''
      SET @cLoadKey = ''      -- (james02)
      SET @cBatchNo = ''
      SET @cOutField01 = ''

      SET @nScn = 1710
      SET @nStep = 1
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 1710. Screen 1.
   WAVEKEY (field01)   - Input field
   LOADKEY (field02)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cWaveKey = @cInField01
      SET @cLoadKey = @cInField02   -- (james02)

/*
      -- Validate blank
      IF @cWaveKey = '' OR @cWaveKey IS NULL
      BEGIN
         SET @nErrNo = 63951
         SET @cErrMsg = rdt.rdtgetmessage( 63951, @cLangCode, 'DSP') --WAVEKEY needed
         GOTO Step_WaveKey_Fail
      END
*/
      IF ISNULL(@cWaveKey, '') = '' AND ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 63987
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WAVE/LOAD req
         GOTO Quit
      END

      SET @cBatchNo = ''
               
      -- Wavekey entered
      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         IF not EXISTS ( SELECT 1 from dbo.WAVE WAVE WITH (NOLOCK)
                        WHERE WAVE.Wavekey = @cWaveKey )
         BEGIN
            SET @nErrNo = 63952
            SET @cErrMsg = rdt.rdtgetmessage( 63952, @cLangCode, 'DSP') --Bad WAVEKEY
            GOTO Step_WaveKey_Fail
         END

         IF not EXISTS ( SELECT 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
                                 INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
                                 INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
                        WHERE WD.Wavekey = @cWaveKey
                        AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                        AND OD.QtyAllocated + OD.QtyPicked > 0 )
         BEGIN
            SET @nErrNo = 63953
            SET @cErrMsg = rdt.rdtgetmessage( 63953, @cLangCode, 'DSP') --WaveFullyDistr
            GOTO Step_WaveKey_Fail
         END

         SELECT @cBatchNo = MAX(BatchNo)
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE UserName = @cUserName
         AND WaveKey    = @cWaveKey
         AND Status     <> '9'
      END
      ELSE  -- LoadKey entered   (james02)
      BEGIN
         IF not EXISTS ( SELECT 1 from dbo.LoadPlan WITH (NOLOCK)
                        WHERE LoadKey = @cLoadKey )
         BEGIN
            SET @nErrNo = 63988
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LOADKEY
            GOTO Step_LoadKey_Fail
         END

         IF not EXISTS ( SELECT 1 FROM dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
                                 INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (LPD.LoadKey = OD.LoadKey )
                        WHERE LPD.LoadKey = @cLoadKey
                        AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                        AND OD.QtyAllocated + OD.QtyPicked > 0 )
         BEGIN
            SET @nErrNo = 63989
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadFullyDistr
            GOTO Step_LoadKey_Fail
         END

         SELECT @cBatchNo = MAX(BatchNo)
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE UserName = @cUserName
         AND LoadKey    = @cLoadKey
         AND Status     <> '9'
      END

      -- (james04)
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
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
              @nMobile, @nFunc, @cLangCode, @cStorer, @cWaveKey, @cLoadKey, @cOtherParm01, @cOtherParm02,  
              @cOtherParm03, @cOtherParm04, @cOtherParm05, @cOtherParm06, @cOtherParm07, @cOtherParm08,  
              @cOtherParm09, @cOtherParm10, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
              
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cWaveKey = ''
            SET @cLoadKey = ''
            SET @cOutField01 = '' -- Wavekey
            SET @cOutField02 = '' -- Loadkey
            GOTO Quit
         END
      END

      IF @cBatchNo is NULL
         SET @cBatchNo = ''
      
      SET @cCallSource = '1'
      GOTO Refresh_TotalQty
      Refresh_TotalQty1:

      IF @nTotalQty IS NULL
         SELECT @nTotalQty = 0

      SET @nQtyToProcess = 0
      SET @nQtyToScan = 0
      
      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0),  
                @nQtyToProcess = ISNULL( SUM( OD.QtyToProcess), 0)
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
      END
      ELSE
      BEGIN
         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0),  
                @nQtyToProcess = ISNULL( SUM( QtyToProcess), 0)
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
      END
      
      -- Prep next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = ''   -- SKU/UPC
      SET @cOutField03 = ''   -- SKU descr 1
      SET @cOutField04 = ''   -- SKU descr 2
      SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
      SET @cOutField06 = '0/0'  --SKU QTY
      SET @cOutField07 = CAST( @nQtyToProcess AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5))      -- Total QTY
      SET @cOutField08 = @cLoadKey
      -- Prepare next screen var

      IF @cFlowThruSortationLockQty = '1'
         SET @cFieldAttr05 = 'O' 

      SET @cCallSource3 = '1'
      GOTO CheckPeiceScan
      CheckPeiceScan1:

      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         -- Clear any left over data
         IF EXISTS ( SELECT 1 FROM rdt.rdtFlowThruSort WITH (NOLOCK)
                     WHERE UserName = @cUserName
                     AND WaveKey    = @cWaveKey
                     AND Status     <> '9')
         BEGIN
            DELETE FROM rdt.rdtFlowThruSort 
            WHERE UserName = @cUserName
            AND   WaveKey    = @cWaveKey
            AND   Status     <> '9'
         END
      END
      ELSE
      BEGIN
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
      END
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cWaveKey = ''
      SET @cBatchNo = ''

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

   Step_WaveKey_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Wavekey
      SET @cOutField02 = '' -- Loadkey
      SET @cWaveKey = ''
      SET @cLoadKey = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 --WaveKey 
   END
   GOTO Quit
   
   Step_LoadKey_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Wavekey
      SET @cOutField02 = '' -- Loadkey
      SET @cWaveKey = ''
      SET @cLoadKey = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2 --LoadKey    
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 1711. Screen 2.
   WAVEKEY (field01)
   LOADKEY (field08)
   SKU/UPC (field02)   - Input field
   SKUDesc (1-20) (field03)
   SKUDesc (21-40) (field04)

   QTY     (field05)   - Input field - default 1   StorerConfig - FlowThruSortationPieceScaning - to protect

   SKU QTY (field06)
   Total QTY   (field07)
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cCallSource3 = '2'
      GOTO CheckPeiceScan
      CheckPeiceScan2:

      -- Screen mapping
      SET @cTempSKU = @cInField02
      SET @cSKU = @cLastSKU      -- remember last scanned sku

      IF rdt.rdtIsValidQTY( @cOutField07, 0) = 1
      BEGIN
         SET @nTotalQty     = Cast (@cOutField07  as int)
      END
      ELSE
      BEGIN
         SET @nTotalQty     = 0
      END

      IF ISNULL(@cTempSKU, '') = ''
      BEGIN
         SELECT @nTotalQty = ISNULL( SUM( Qty), 0)
         FROM rdt.rdtFlowThruSort WITH (ROWLOCK)
         WHERE WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND   LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND   Status    <> '9'
         AND   UserName = @cUserName
      
         IF @nTotalQty > 0 -- something scanned
         BEGIN
           SET @cOutField01 = '' -- Option 1

           -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END
      
      IF ISNULL(@cFlowThruSortationPieceScaning, '') = '1'
      BEGIN
         SET @cInField05 = '1'  -- Default as 1
         SET @nQty = 1
      END
      ELSE
      BEGIN
         IF rdt.rdtIsInteger( @cInField05) = 1
         BEGIN
            IF @cFlowThruSortationLockQty = '1'
               SET @nQty = Cast (@cOutField05  as int)
            ELSE
               SET @nQty = Cast (@cInField05  as int)
         END
         ELSE
         BEGIN
            IF ISNULL(@cInField02, '') <> '' -- (james03)
            BEGIN
               SET @cOutField02 = @cTempSKU
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Quit
            END
            
            SET @nQty     = 0
            SET @nErrNo = 63955
            SET @cErrMsg = rdt.rdtgetmessage( 63955, @cLangCode, 'DSP') -- 'Invalid QTY'
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_2_Fail
         END

         IF @nQty = 0
         BEGIN
            SET @nQty     = 0
            SET @nErrNo = 63956
            SET @cErrMsg = rdt.rdtgetmessage( 63956, @cLangCode, 'DSP') -- 'QTY needed'
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_2_Fail
         END

      END

--      SET @nSKUQty     = @cOutField06

       -- Retain the key-in value
       SET @cOutField02 = @cTempSKU

      -- Validate SKU
      IF @cTempSKU = '' OR @cTempSKU IS NULL
      BEGIN
         SET @nErrNo = 63957
         SET @cErrMsg = rdt.rdtgetmessage( 63957, @cLangCode, 'DSP') -- 'SKU required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_SKU_Fail
      END

      EXEC [RDT].[rdt_GETSKUCNT]
       @cStorerKey  = @cStorer
      ,@cSKU        = @cTempSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63958
         SET @cErrMsg = rdt.rdtgetmessage( 63958, @cLangCode, 'DSP') -- 'Invalid SKU'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_SKU_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63959
         SET @cErrMsg = rdt.rdtgetmessage( 63959 , @cLangCode, 'DSP') -- 'MultiSKUBarcod'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      -- Get SKU    (james03)
      EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cStorer    
         ,@cSKU        = @cTempSKU      OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
         
      SET @cSKU = @cTempSKU
      SET @cLastSKU = @cTempSKU

      SELECT @cSKUDescr = DESCR
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   SKU       = @cSKU
      
      IF ISNULL(@cWaveKey, '') <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
                                 INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
                                 INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
                        WHERE WD.Wavekey = @cWaveKey
                        AND OD.SKU = @cSKU  )
         BEGIN
            SET @nErrNo = 63960
            SET @cErrMsg = rdt.rdtgetmessage( 63960 , @cLangCode, 'DSP') -- 'SKU NotOnWave'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
                         WHERE Loadkey = @cLoadKey
                         AND SKU = @cSKU  )
         BEGIN
            SET @nErrNo = 63990
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') -- 'SKU NotOnLoad'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_2_Fail
         END
      END

      -- check over scanned (james02)
      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         SELECT @nQtyToScan = SUM(OD.QtyAllocated + OD.QtyPicked), 
                @nQtyToProcess = ISNULL( SUM( OD.QtyToProcess), 0)
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
         AND   OD.SKU = @cSKU
      END
      ELSE
      BEGIN
         SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0), 
                @nQtyToProcess = ISNULL( SUM( QtyToProcess), 0)
         FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.StorerKey = O.StorerKey AND OD.OrderKey = O.OrderKey)
         WHERE OD.LoadKey = @cLoadKey
         AND OD.SKU       = @cSKU
      END
      
      SELECT @nQtyScanned = ISNULL( SUM( Qty), 0) 
      FROM rdt.rdtFlowThruSort WITH (ROWLOCK)
      WHERE WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND   LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND   SKU       = @cSKU
      AND   Status    = '0'
         
      IF @nQtyToProcess + @nQtyScanned + @nQty > @nQtyToScan
      BEGIN
         SET @nErrNo = 63991
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') -- 'Over Scanned'
         GOTO Refresh_TotalQty2
      END
         
      SET @cBatchNo = ''
      SELECT @cBatchNo = MAX(BatchNo)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE UserName = @cUserName
      AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
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

      IF EXISTS ( SELECT TOP 1 SKU FROM rdt.rdtFlowThruSort WITH (NOLOCK)
                        WHERE  BatchNo = @cBatchNo
                        AND UserName   = @cUserName
                        AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                        AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                        AND SKU        = @cSKU
                        AND Status     = '0' )
      BEGIN
         BEGIN TRAN

         UPDATE rdt.rdtFlowThruSort WITH (ROWLOCK)
         SET Qty = Qty + @nQty
         WHERE BatchNo = @cBatchNo
         AND UserName  = @cUserName
         AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND SKU       = @cSKU
         AND Status    = '0'
         
         IF @@ROWCOUNT = 1
            COMMIT TRAN
         ELSE
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 63962
            SET @cErrMsg = rdt.rdtgetmessage( 63962, @cLangCode, 'DSP') -- 'UPD WSortFail Fail'
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         BEGIN TRAN
         INSERT INTO rdt.rdtFlowThruSort ( BatchNo,
            UserName,   WaveKey, Storerkey,
            SKU,  Qty,   Status, LoadKey)
         VALUES (@cBatchNo,
            @cUserName, ISNULL(@cWaveKey, ''), @cStorer,
            @cSKU, @nQty, '0', ISNULL(@cLoadKey, '') )
            
         IF @@ROWCOUNT = 1
            COMMIT TRAN
         ELSE
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 63961
            SET @cErrMsg = rdt.rdtgetmessage( 63961, @cLangCode, 'DSP') -- 'Add WSortFail Fail'
            GOTO Step_2_Fail
         END
      END

      SET @cCallSource = '2'
      GOTO Refresh_TotalQty

      Refresh_TotalQty2:
      SELECT @nSKUQty = SUM(Qty)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
      AND UserName  = @cUserName
      AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND SKU       = @cSKU
      AND Status <> '9'

      SELECT @nTtlQty = ISNULL( SUM( Qty), 0)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
      AND UserName  = @cUserName
      AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND Status <> '9'

      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         SELECT @nTtlSKUQty = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0), 
                @nQtyToProcess = ISNULL( SUM( OD.QtyToProcess), 0)  
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
         AND SKU       = @cSKU

         SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0), 
                @nTtlQtyToProcess = ISNULL( SUM( OD.QtyToProcess), 0)
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
      END
      ELSE
      BEGIN
         SELECT @nTtlSKUQty = ISNULL( SUM( QtyAllocated + QtyPicked), 0), 
                @nQtyToProcess = ISNULL( SUM( QtyToProcess), 0)  
         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
         AND SKU       = @cSKU

         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0), 
                @nTtlQtyToProcess = ISNULL( SUM( QtyToProcess), 0)
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
      END
      
      IF @nSKUQty is NULL
         SELECT @nSKUQty = 0

      -- Retain the key-in value
      SET @cOutField01 = @cWaveKey
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
      SET @cOutField06 = CAST( @nSKUQty + @nQtyToProcess AS NVARCHAR( 5)) + '/' + CAST( @nTtlSKUQty AS NVARCHAR( 5))   --SKU QTY
      SET @cOutField07 = CAST( @nTtlQty + @nTtlQtyToProcess AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5)) -- Total QTY
      SET @cOutField08 = @cLoadKey

      IF @cFlowThruSortationLockQty = '1'
         SET @cFieldAttr05 = 'O' 
         
      -- Prepare next screen var
      SET @cOutField02 = ''   -- SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Loop at current screen
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Check if something scanned
      SELECT @nTotalQty = ISNULL( SUM( Qty), 0)
      FROM rdt.rdtFlowThruSort WITH (ROWLOCK)
      WHERE WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND   LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND   Status    <> '9'
      AND   UserName = @cUserName
   
      IF @nTotalQty > 0 -- something scanned
      BEGIN
        SET @cOutField01 = '' -- Option 1

        -- Go to next screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
         
         GOTO Quit
      END

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      
      -- Go to precious screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_SKU_Fail:
   BEGIN
      SET @cOutField02 = '' -- SKU/UPC
      SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = '' -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      GOTO Quit
   END
   
   Step_2_Fail:
   BEGIN
      SET @cCallSource = '3'
      GOTO Refresh_TotalQty
      Refresh_TotalQty3:

      IF ISNULL(@cBatchNo, '') = ''
         SELECT @cBatchNo = MAX(BatchNo)
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE UserName = @cUserName
         AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status     <> '9'
      
      SELECT @nSKUQty = ISNULL( SUM( Qty), 0)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
      AND UserName  = @cUserName
      AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND SKU       = @cSKU
      AND Status <> '9'

      SELECT @nTtlQty = ISNULL( SUM( Qty), 0)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
      AND UserName  = @cUserName
      AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND Status <> '9'

      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         SELECT @nTtlSKUQty = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0)  
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
         AND SKU       = @cSKU

         SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0) 
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
      END
      ELSE
      BEGIN
         SELECT @nTtlSKUQty = ISNULL( SUM( QtyAllocated + QtyPicked), 0)
         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
         AND SKU       = @cSKU

         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0)   
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
      END
      
      -- Reset this screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = '' -- SKU/UPC
      SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = ''  -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
      SET @cOutField06 = CAST( @nSKUQty AS NVARCHAR( 5)) + '/' + CAST( @nTtlSKUQty AS NVARCHAR( 5))   --SKU QTY
      SET @cOutField07 = CAST( @nTtlQty AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5)) -- Total QTY
      SET @cOutField08 = @cLoadKey

      IF @cFlowThruSortationLockQty = '1'
         SET @cFieldAttr05 = 'O' 
   END
END
GOTO Quit

CheckPeiceScan:
BEGIN
   IF ISNULL(@cFlowThruSortationPieceScaning, '') = '1'
   BEGIN
      SET @cFieldAttr05 = '' -- (Vicky02)
      --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value)
      --   VALUES ('Field05', 'NULL', 'output', 'NULL', 'NULL', '1')
   END

   IF @cCallSource3 = '1'
   BEGIN
      SET @cCallSource3 = ''
      GOTO CheckPeiceScan1
   END
   IF @cCallSource3 = '2'
   BEGIN
      SET @cCallSource3 = ''
      GOTO CheckPeiceScan2
   END
   IF @cCallSource3 = '3'
   BEGIN
      SET @cCallSource3 = ''
      GOTO CheckPeiceScan3
   END
   IF @cCallSource3 = '4'
   BEGIN
      SET @cCallSource3 = ''
      GOTO CheckPeiceScan4
   END
   IF @cCallSource3 = '5'
   BEGIN
      SET @cCallSource3 = ''
      GOTO CheckPeiceScan5
   END
END
/************************************************************************************
Step_3. Scn = 1712. Screen 3.
   Start distribute?

   1=Yes
   2=No

   Option   (field01)
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

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

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63965
         SET @cErrMsg = rdt.rdtgetmessage( 63965, @cLangCode, 'DSP') --Option needed
         GOTO Step_3_Fail
      END

      IF NOT ( @cOption = '1' OR @cOption = '2' )
      BEGIN
         SET @nErrNo = 63966
         SET @cErrMsg = rdt.rdtgetmessage( 63966, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_3_Fail
      END

      SET @cCallSource = '4'
      GOTO Refresh_TotalQty

      Refresh_TotalQty4:
      IF @nTotalQty = 0
      BEGIN
         SET @cOption = '2'
      END

      IF @cOption = '1'
      BEGIN
         WHILE 1=1
         BEGIN
            SET @cTSKU = ''
            SET @nTQty = 0

            SELECT TOP 1 @cTSKU = SKU, @nTQty = QTY
            FROM rdt.rdtFlowThruSort WITH (NOLOCK)
            WHERE BatchNo  = @cBatchNo
            AND UserName   = @cUserName
            AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
            AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
            AND Status     = '0'
            AND QTY        > 0
            Order by SKU

            IF ISNULL(@cTSKU, '') = ''
            BEGIN
               BREAK
            END

            SET @nQty = @nTQty
--            BEGIN TRAN       -- commit by rdtFlowThruSort line  -- (james01)

            WHILE @nTQty > 0
            BEGIN
             --BEGIN TRAN  -- (james01) / Leong01

               SET @nUpdQty = 0
               SET @nBalQty = 0
               SET @nScanQty = 0
               SET @cOrderKey = ''
               SET @cOrderLineNo =''
               SET @cConsigneeKey = ''
               SET @cC_Company = ''
               SET @cPickSlipNo = ''

               -- Get order infor and qty able to distribute
               IF ISNULL(@cWaveKey, '') <> ''
               BEGIN
                  SELECT TOP 1 @nBalQty  = OD.QtyAllocated + OD.QtyPicked - OD.QtyToProcess,
                               @nScanQty = OD.QtyToProcess,
                               @cOrderKey     = OD.Orderkey,
                               @cOrderLineNo  = OD.OrderLineNumber,
                               @cConsigneeKey = ORDERS.ConsigneeKey,
                               @cC_Company    = ORDERS.C_Company,
                               @cPickSlipNo   = ( SELECT MAX(WH.PickHeaderKey) FROM  dbo.PickHeader WH WITH (NOLOCK)
                                                  Where WH.WaveKey = WD.WaveKey
                                    AND WH.ORDERKey = WD.OrderKey )
                             --@cPickSlipNo   = ( SELECT MAX(PickSlipNo)
                             --                    FROM dbo.PickDetail PD WITH (NOLOCK)
                             --                    WHERE  (PD.WaveKey = WD.WaveKey
                             --                    AND PD.OrderKey = WD.OrderKey
                             --                    AND PD.OrderLineNumber = OD.OrderLineNumber) )
                  FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
                           INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey)
                           INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey)
                  WHERE WD.Wavekey = @cWaveKey
                  AND OD.SKU       = @cTSKU
                  AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                  AND OD.QtyAllocated + OD.QtyPicked > 0
                  ORDER BY Orders.Priority, OD.Orderkey, OD.OrderLineNumber
               END
               ELSE
               BEGIN
                  SELECT TOP 1 @nBalQty  = OD.QtyAllocated + OD.QtyPicked - OD.QtyToProcess,
                               @nScanQty = OD.QtyToProcess,
                               @cOrderKey     = OD.Orderkey,
                               @cOrderLineNo  = OD.OrderLineNumber,
                               @cConsigneeKey = O.ConsigneeKey,
                               @cC_Company    = O.C_Company,
                               @cPickSlipNo   = ( SELECT MAX(PH.PickHeaderKey) FROM dbo.PickHeader PH WITH (NOLOCK)
                                                  Where PH.OrderKey = O.OrderKey )
                  FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.StorerKey = O.StorerKey AND OD.OrderKey = O.OrderKey)
                  WHERE OD.LoadKey = @cLoadKey
                  AND OD.SKU       = @cTSKU
                  AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                  AND OD.QtyAllocated + OD.QtyPicked > 0
                  ORDER BY O.Priority, OD.Orderkey, OD.OrderLineNumber
               END
               
               IF @@ROWCOUNT = 0
               BEGIN
                --ROLLBACK TRAN -- Leong01
                  SET @nErrNo = 63967
                  SET @cErrMsg = rdt.rdtgetmessage( 63967 , @cLangCode, 'DSP') -- 'Over scanned'
                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                  IF @nErrNo = 1
                     SET @cErrMsg =''
                  GOTO Step_3_Fail
               END

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

               IF @nUpdQty > 0
               BEGIN
                  BEGIN TRAN  -- (james01) / Leong01
                  --Using TrafficCop with updating Order Det
                  UPDATE dbo.ORDERDETAIL WITH (ROWLOCK)
                  SET   QtyToProcess = QtyToProcess + @nUpdQty, TrafficCop = NULL
                  WHERE OrderKey = @cOrderKey
                  AND OrderLineNumber = @cOrderLineNo
                  AND SKU = @cTSKU
                  AND QtyToProcess = @nScanQTY -- If UPDATE by other user, fail and refresh qty
                  AND QtyAllocated + QtyPicked - QtyToProcess >= @nUpdQty

                  --Leong01 (Start)
                  IF @@ROWCOUNT = 1
                     COMMIT TRAN
                  ELSE
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 63969
                     SET @cErrMsg = rdt.rdtgetmessage( 63969, @cLangCode, 'DSP') -- 'UPD ODtl Fail'
                     SET @nErrNo = 0
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                     IF @nErrNo = 1
                        SET @cErrMsg =''
                     GOTO Step_3_Fail
                  END

                  --IF @@ROWCOUNT <> 1
                  --BEGIN
                  --   ROLLBACK TRAN
                  --   SET @nErrNo = 63969
                  --   SET @cErrMsg = rdt.rdtgetmessage( 63969, @cLangCode, 'DSP') -- 'UPD ODtl Fail'
                  --   SET @nErrNo = 0
                  --   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                  --   IF @nErrNo = 1
                  --      SET @cErrMsg =''
                  --   GOTO Step_3_Fail
                  --END
                  --Leong01 (End)

                  IF EXISTS ( SELECT TOP 1 1
                                 FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
                                 WHERE BatchNo  = @cBatchNo
                                 AND UserName   = @cUserName
                                 AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                                 AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                                 AND OrderKey   = @cOrderKey
                                 AND SKU        = @cTSKU
                                 AND Status     = '1'  )
                  BEGIN
                     BEGIN TRAN  -- Leong01
                     -- distribute item EXISTS, then add qty
                     UPDATE rdt.rdtFlowThruSortDistr WITH (ROWLOCK)
                            SET QTY = QTY + @nUpdQty
                     WHERE BatchNo  = @cBatchNo
                     AND UserName   = @cUserName
                     AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                     AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                     AND OrderKey   = @cOrderKey
                     AND SKU        = @cTSKU
                     AND Status     = '1'

                     --Leong01 (Start)
                     IF @@ROWCOUNT = 1
                        COMMIT TRAN
                     ELSE
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 63971
                        SET @cErrMsg = rdt.rdtgetmessage( 63971, @cLangCode, 'DSP') -- 'UPD WaveDistr Fail'
                        SET @nErrNo = 0
                        EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                        IF @nErrNo = 1
                           SET @cErrMsg =''
                        GOTO Step_3_Fail
                     END

                     --IF @@ROWCOUNT <> 1
                     --BEGIN
                     --   ROLLBACK TRAN
                     --   SET @nErrNo = 63971
                     --   SET @cErrMsg = rdt.rdtgetmessage( 63971, @cLangCode, 'DSP') -- 'UPD WaveDistr Fail'
                     --   SET @nErrNo = 0
                     --   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                     --   IF @nErrNo = 1
                     --      SET @cErrMsg =''
                     --   GOTO Step_3_Fail
                     --END
                     --Leong01 (End)
                  END -- EXISTS rdtFlowThruSortDistr
                  ELSE
                  BEGIN
                     BEGIN TRAN  -- Leong01
                     INSERT INTO rdt.rdtFlowThruSortDistr ( BatchNo, UserName, WaveKey, Storerkey,
                                                            OrderKey,  PickSlipNo, ConsigneeKey,
                                                            C_Company, SKU, Qty, Status, LoadKey )
                     VALUES ( @cBatchNo, @cUserName, @cWaveKey, @cStorer,
                              @cOrderKey, @cPickSlipNo, @cConsigneeKey,
                              @cC_Company, @cTSKU, @nUpdQty, '1', @cLoadKey )

                     --Leong01 (Start)
                     IF @@ROWCOUNT = 1
                        COMMIT TRAN
                     ELSE
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 63970
                        SET @cErrMsg = rdt.rdtgetmessage( 63970, @cLangCode, 'DSP') -- 'Add WaveDistr Fail'
                        SET @nErrNo = 0
                        EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                        IF @nErrNo = 1
                           SET @cErrMsg =''
                        GOTO Step_3_Fail
                     END

                     --IF @@ROWCOUNT <> 1
                     --BEGIN
                     --   ROLLBACK TRAN
                     --   SET @nErrNo = 63970
                     --   SET @cErrMsg = rdt.rdtgetmessage( 63970, @cLangCode, 'DSP') -- 'Add WaveDistr Fail'
                     --   SET @nErrNo = 0
                     --   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                     --   IF @nErrNo = 1
                     --      SET @cErrMsg =''
                     --   GOTO Step_3_Fail
                     --END
                     --Leong01 (End)
                  END  -- Not EXISTS rdtFlowThruSortDistr
               END -- @nUpdQty > 0
            END  -- @cTQty > 0

            BEGIN TRAN -- Leong01
            -- SKu EXISTS in status '1', then add qty to the line
            UPDATE rdt.rdtFlowThruSort WITH (ROWLOCK)
              SET QTY = QTY + @nQty
            WHERE BatchNo  = @cBatchNo
            AND UserName   = @cUserName
            AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
            AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
            AND SKU        = @cTSKU
            AND Status     = '1'

            IF @@ROWCOUNT = 0
            BEGIN
               -- SKu not EXISTS in status '1', then change status for EXISTS line only
               UPDATE rdt.rdtFlowThruSort  WITH (ROWLOCK)
                 SET Status = '1'
               WHERE BatchNo  = @cBatchNo
               AND UserName   = @cUserName
               AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
               AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
               AND SKU        = @cTSKU
               AND Status     = '0'

               IF @@ROWCOUNT <> 1
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 63974
                  SET @cErrMsg = rdt.rdtgetmessage( 63974, @cLangCode, 'DSP') -- 'UPD WSortFail'
                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                  IF @nErrNo = 1
                     SET @cErrMsg =''
                  GOTO Step_3_Fail
               END

            END
            ELSE IF @@ROWCOUNT = 1
            BEGIN
               -- SKu EXISTS in status '1', then add qty to the line, then DELETE existing line
               DELETE rdt.rdtFlowThruSort
               WHERE BatchNo  = @cBatchNo
               AND UserName   = @cUserName
               AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
               AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
               AND SKU        = @cTSKU
               AND Status     = '0'

               IF @@ROWCOUNT <> 1
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 63973
                  SET @cErrMsg = rdt.rdtgetmessage( 63973, @cLangCode, 'DSP') -- 'DEL WSortFail'
                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                  IF @nErrNo = 1
                     SET @cErrMsg =''
                  GOTO Step_3_Fail
               END
            END
            ELSE IF @@ROWCOUNT > 1
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 63972
               SET @cErrMsg = rdt.rdtgetmessage( 63972, @cLangCode, 'DSP') -- 'UPD WSortFail'
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
               IF @nErrNo = 1
                  SET @cErrMsg =''
               GOTO Step_3_Fail
            END

            COMMIT TRAN -- per sku qty in rdtFlowThruSort item

         END --  WHILE 1=1 (IF @cOption = '1')

         SET @cFlowThruSortationPrintSortList = ''
         SET @cFlowThruSortationPrintSortList = rdt.RDTGetConfig( 0, 'FlowThruSortationPrintSortList', @cStorer)

         SET @cFlowThruSortationPrintLabel = ''
         SET @cFlowThruSortationPrintLabel = rdt.RDTGetConfig( 0, 'FlowThruSortationPrintLabel', @cStorer)

         IF @cFlowThruSortationPrintSortList = '1'
         BEGIN
            IF  EXISTS (SELECT TOP 1 1
                        FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
                        WHERE BatchNo  = @cBatchNo
                        AND UserName   = @cUserName
                        AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                        AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                        AND Status     = '1' )
                        AND ISNULL(@cPrinter, '') <> ''
            BEGIN
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND ReportType = 'SORTLIST'

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 63981
                  SET @cErrMsg = rdt.rdtgetmessage( 63981, @cLangCode, 'DSP') --DWNOTSetup
                  GOTO Step_3_Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 63982
                  SET @cErrMsg = rdt.rdtgetmessage( 63982, @cLangCode, 'DSP') --TgetDB Not SET
                  GOTO Step_3_Fail
               END

               IF ISNULL(@cWaveKey, '') <> ''
               BEGIN
                  --(ChewKP01) 
                  --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                  --VALUES('FlowThruSortationPrintSortList', 'SORTLIST', '0', @cDataWindow, 2, @cWaveKey, @cUserName, '', @cPrinter, 1, @nMobile, @cTargetDB)
                  EXEC RDT.rdt_BuiltPrintJob                     
                        @nMobile,                    
                        @cStorer,                    
                        'SORTLIST',                    
                        'FlowThruSortationPrintSortList',                    
                        @cDataWindow,                    
                        @cPrinter,                    
                        @cTargetDB,                    
                        @cLangCode,                    
                        @nErrNo  OUTPUT,                     
                        @cErrMsg OUTPUT,                    
                        @cWaveKey,
                        @cUserName
                                              
               END
               ELSE
               BEGIN
                  --(ChewKP01) 
                  --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                  --VALUES('FlowThruSortationPrintSortList', 'SORTLIST', '0', @cDataWindow, 2, @cLoadKey, @cUserName, '', @cPrinter, 1, @nMobile, @cTargetDB)
                  EXEC RDT.rdt_BuiltPrintJob                     
                        @nMobile,                    
                        @cStorer,                    
                        'SORTLIST',                    
                        'FlowThruSortationPrintSortList',                    
                        @cDataWindow,                    
                        @cPrinter,                    
                        @cTargetDB,                    
                        @cLangCode,                    
                        @nErrNo  OUTPUT,                     
                        @cErrMsg OUTPUT,                    
                        @cLoadKey,
                        @cUserName
               END

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63983
                  SET @cErrMsg = rdt.rdtgetmessage( 63983, @cLangCode, 'DSP') --''InsertPRTFail''
                  GOTO Step_3_Fail
               END
            END
         END

         -- SOS131513 Add in new configkey
         IF @cFlowThruSortationPrintLabel = '1'
         BEGIN
            IF  EXISTS ( SELECT TOP 1 1
                                    FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
                                    WHERE BatchNo  = @cBatchNo
                                    AND UserName   = @cUserName
                                    AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                                    AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                                    AND Status     = '1' )
                                    AND ISNULL(@cPrinter, '') <> ''
            BEGIN
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND ReportType = 'SORTLABEL'

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 63984
                  SET @cErrMsg = rdt.rdtgetmessage( 63984, @cLangCode, 'DSP') --DWNOTSetup
                  GOTO Step_3_Fail
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 63985
                  SET @cErrMsg = rdt.rdtgetmessage( 63985, @cLangCode, 'DSP') --TgetDB Not SET
                  GOTO Step_3_Fail
               END

               IF ISNULL(@cWaveKey, '') <> ''
               BEGIN
                  -- (ChewKP01) 
                  --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                  --VALUES('FlowThruSortationPrintLabel', 'SORTLABEL', '0', @cDataWindow, 3, @cWaveKey, @cUserName, @cBatchNo, @cPrinter, 1, @nMobile, @cTargetDB)
                  EXEC RDT.rdt_BuiltPrintJob                     
                        @nMobile,                    
                        @cStorer,                    
                        'SORTLABEL',                    
                        'FlowThruSortationPrintLabel',                    
                        @cDataWindow,                    
                        @cPrinter,                    
                        @cTargetDB,                    
                        @cLangCode,                    
                        @nErrNo  OUTPUT,                     
                        @cErrMsg OUTPUT,                    
                        @cWaveKey,
                        @cUserName,
                        @cBatchNo
               END
               ELSE
               BEGIN
                  -- (ChewKP01) 
                  --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                  --VALUES('FlowThruSortationPrintLabel', 'SORTLABEL', '0', @cDataWindow, 3, @cLoadKey, @cUserName, @cBatchNo, @cPrinter, 1, @nMobile, @cTargetDB)
                  EXEC RDT.rdt_BuiltPrintJob                     
                        @nMobile,                    
                        @cStorer,                    
                        'SORTLABEL',                    
                        'FlowThruSortationPrintLabel',                    
                        @cDataWindow,                    
                        @cPrinter,                    
                        @cTargetDB,                    
                        @cLangCode,                    
                        @nErrNo  OUTPUT,                     
                        @cErrMsg OUTPUT,                    
                        @cLoadKey,
                        @cUserName,
                        @cBatchNo
               END
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63986
                  SET @cErrMsg = rdt.rdtgetmessage( 63986, @cLangCode, 'DSP') --''InsertPRTFail''
                  GOTO Step_3_Fail
               END
            END
         END

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         SET @cV_OrderKey = ''
         SET @cV_Sku = ''

         SET @cCallSource2 = '2'
         GOTO ShowDistr
         ShowDistr2:
         GOTO Quit
      END  -- @cOption = '1'

      IF @cOption = '2'
      BEGIN
         SET @cCallSource = '5'
         GOTO Refresh_TotalQty
         Refresh_TotalQty5:

         SELECT @nTtlQty = ISNULL( SUM( Qty), 0)
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE BatchNo = @cBatchNo
         AND UserName  = @cUserName
         AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status <> '9'

         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0)   
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
      
         -- Reset this screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = '' -- SKU/UPC
         SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = ''  -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
         SET @cOutField06 = '0/0' --SKU QTY
         SET @cOutField07 = CAST( @nTtlQty AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5)) -- Total QTY
         SET @cOutField08 = @cLoadKey

         IF @cFlowThruSortationLockQty = '1'
            SET @cFieldAttr05 = 'O' 
         
         SET @cCallSource3 = '3'
         GOTO CheckPeiceScan
         CheckPeiceScan3:

         -- Back to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cCallSource = '6'
      GOTO Refresh_TotalQty
      Refresh_TotalQty6:

      SELECT @nTtlQty = ISNULL( SUM( Qty), 0)
      FROM rdt.rdtFlowThruSort WITH (NOLOCK)
      WHERE BatchNo = @cBatchNo
      AND UserName  = @cUserName
      AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND Status <> '9'

      IF ISNULL(@cWaveKey, '') <> ''
      BEGIN
         SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0) 
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
         INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
         WHERE WD.Wavekey = @cWaveKey
      END
      ELSE
      BEGIN
         SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0)   
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
      END
      
      -- Reset this screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = '' -- SKU/UPC
      SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = ''  -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
      SET @cOutField06 = '0/0' --SKU QTY
      SET @cOutField07 = CAST( @nTtlQty AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5)) -- Total QTY
      SET @cOutField08 = @cLoadKey

      IF @cFlowThruSortationLockQty = '1'
         SET @cFieldAttr05 = 'O' 
         
      SET @cCallSource3 = '4'
      GOTO CheckPeiceScan
      CheckPeiceScan4:

      -- Back to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''  -- Option
   END
END
GOTO Quit

Refresh_TotalQty:
BEGIN
   SELECT @nTotalQty = ISNULL(SUM(Qty), 0)
   FROM rdt.rdtFlowThruSort WITH (NOLOCK)
   WHERE BatchNo  = @cBatchNo
   AND UserName   = @cUserName
   AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
   AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
   AND Status     <> '9'

   IF @nTotalQty is NULL
      SELECT @nTotalQty = 0

   IF @cCallSource = '1'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty1
   END
   IF @cCallSource = '2'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty2
   END
   IF @cCallSource = '3'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty3
   END
   IF @cCallSource = '4'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty4
   END
   IF @cCallSource = '5'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty5
   END
   IF @cCallSource = '6'
   BEGIN
      SET @cCallSource = ''
      GOTO Refresh_TotalQty6
   END
END

/************************************************************************************
Step_4. Scn = 1713. Screen 4.
   Distribute
   Orderkey
   PKSlipNo
   Consignee/Company
   XXXX
   XXXX
   SKU
   XXXX
   Qty1
   XXXX
   Qty2
   XXXX
   Qty3
************************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cV_OrderKey = ISNULL(@cV_OrderKey, '')
      SET @cV_Sku = ISNULL(@cV_Sku, '')


      -- Show distribution screen
      SET @cCallSource2 = '1'
      GOTO ShowDistr
      ShowDistr1:

      -- No Order\sku for distribute - normally not happen
      IF Not EXISTS ( SELECT TOP 1 1
                     FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
                     WHERE BatchNo  = @cBatchNo
                     AND UserName   = @cUserName
                     AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                     AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                     AND Status     = '1' )
      BEGIN
         SET @cOutField01 = '' -- Clean up for menu option
         SET @cV_OrderKey = ''
         SET @cV_Sku = ''

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      end
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cV_OrderKey = ''
      SET @cV_Sku = ''
      SET @cOutField01 = '' -- Clean up for menu option

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit

--    Step_4_Fail:
END
GOTO Quit

ShowDistr:
BEGIN
      IF Not EXISTS ( SELECT TOP 1 1
                     FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
                     WHERE BatchNo  = @cBatchNo
                     AND UserName   = @cUserName
                     AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
                     AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
                     AND OrderKey   = @cV_OrderKey
                     AND SKU        > @cV_Sku
                     AND Status     = '1' )
      BEGIN
         -- no Sku retrieve - Next Order key or first order/distr
         SET @cV_Sku = ''
         SET @cTOrderKey = ''

         Refresh_Distr:
         SELECT TOP 1 @cTOrderKey = OrderKey
         FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
         WHERE BatchNo  = @cBatchNo
         AND UserName   = @cUserName
         AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND OrderKey   > @cV_OrderKey
         AND Status     = '1'
         Group by OrderKey
         ORDER BY OrderKey

         IF ISNULL(@cTOrderKey, '')  = ''
         BEGIN
             -- No more Order , GOTO first order/distr again
            SET @cV_OrderKey = ''
            GOTO  Refresh_Distr
         END
         ELSE
         BEGIN
             -- Get Order
            SET @cV_OrderKey = @cTOrderKey
         END
      END

      SELECT @n_TotalOrder = count (distinct OrderKey)
      FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
      WHERE BatchNo  = @cBatchNo
      AND UserName   = @cUserName
      AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND Status     = '1'

      SELECT @n_NoOrder = count (distinct OrderKey)
      FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
      WHERE BatchNo  = @cBatchNo
      AND UserName   = @cUserName
      AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND OrderKey   <= @cV_OrderKey
      AND Status     = '1'

      SELECT @n_TotalSKu = count (distinct SKU),
             @cPickSlipNo = MAX(PickSlipNo),
             @cConsigneeKey = MAX(ConsigneeKey),
             @cC_Company = MAX(C_Company)
      FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
      WHERE BatchNo  = @cBatchNo
      AND UserName   = @cUserName
      AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND OrderKey   = @cV_OrderKey
      AND Status     = '1'

      IF @n_TotalOrder IS null
         SET @n_TotalOrder = 0
      IF @n_NoOrder is NULL
         SET @n_NoOrder = 0
      IF @cPickSlipNo is NULL
         SET @cPickSlipNo = ''
      IF @cConsigneeKey is NULL
         SET @cConsigneeKey = ''
      IF @cC_Company is NULL
         SET @cC_Company = ''
      IF @n_TotalSKu is null
         SET @n_TotalSKu = 0

      IF @n_TotalSKu > 0
         SELECT @n_TotalSKu = CEILING(@n_TotalSKu / 3.0)

      SET @cSku1 = ''
      SET @cQty1 = ''
      SET @cSku2 = ''
      SET @cQty2 = ''
      SET @cSku3 = ''
      SET @cQty3 = ''

       -- Get SKU and Qty - 3 SKU per Page
       SET @cCallSource = '1'
       GOTO Get_Sku
       Get_Sku1:

      IF ISNULL(@cSku, '') <> ''
      BEGIN
         SET @cSku1 = @cSku
         SET @cQty1 = CAST(@nQty as NVARCHAR(5))
         SET @cV_Sku = @cSku

         -- Next SKU and Qty
         SET @cCallSource = '2'
         GOTO Get_Sku
         Get_Sku2:

         IF ISNULL(@cSku, '') <> ''
         BEGIN
            SET @cSku2 = @cSku
            SET @cQty2 = CAST(@nQty as NVARCHAR(5))
            SET @cV_Sku = @cSku

            -- Next SKU and Qty
            SET @cCallSource = '3'
            GOTO Get_Sku
            Get_Sku3:

            IF ISNULL(@cSku, '') <> ''
            BEGIN
               SET @cSku3 = @cSku
               SET @cQty3 = CAST(@nQty as NVARCHAR(5))
               SET @cV_Sku = @cSku
            END
         END
      END


      SELECT @n_SKuPage = CEILING(count (distinct SKU) / 3.0 )
      FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
      WHERE BatchNo  = @cBatchNo
      AND UserName   = @cUserName
      AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
      AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      AND OrderKey   = @cV_OrderKey
      AND SKU        <= @cV_Sku
      AND Status     = '1'

      SET @nSeqNo = 0
      IF ISNULL(@cLoadKey, '') <> ''
      BEGIN
         SELECT @cSeqNo = UserDefine02 
         FROM dbo.LoadPlanDetail WITH (NOLOCK)
         WHERE OrderKey = @cV_OrderKey
         
         IF rdt.rdtIsValidQty(@cSeqNo, 1) = 1
            SET @nSeqNo = CAST(@cSeqNo AS INT)
      END

      -- Screen mapping
      -- Output screen - distribute screen
      SET @cOutField01 = Right('00' + ISNULL(LTRIM(RTrim(Cast(@n_NoOrder as NVARCHAR(2)))), ''), 2)    -- No of distribution      99/99 -- (Vicky01)
      SET @cOutField02 = Right('00' + ISNULL(LTRIM(RTrim(Cast(@n_TotalOrder as NVARCHAR(2)))), ''), 2)   -- Total of distribution -- (Vicky01)
      SET @cOutField03 = @cV_OrderKey   -- OrderKey
      SET @cOutField04 = CASE WHEN @nSeqNo > 0 THEN '' ELSE 'PKSLIPNO: ' + @cPickSlipNo END -- PKSlipNo  -- (james02)
      SET @cOutField05 = @cConsigneeKey -- ConsigneeKey
      SET @cOutField06 = @cC_company     -- Consignee Company
      SET @cOutField07 = Right('00' + RTrim( Cast( @n_SKuPage as NVARCHAR(2))), 2)   -- Page No per order
      SET @cOutField08 = Right('00' + RTrim( Cast( @n_TotalSKu as NVARCHAR(2))), 2)   -- Total of Page per order
      SET @cOutField09 = @cSku1
      SET @cOutField10 = @cQty1
      SET @cOutField11 = @cSku2
      SET @cOutField12 = @cQty2
      SET @cOutField13 = @cSku3
      SET @cOutField14 = @cQty3
      SET @cOutField15 = CASE WHEN @nSeqNo > 0 THEN 'SEQ NO: ' + @cSeqNo ELSE '' END -- SeqNo (james02)
      -- Prepare next screen var

   -- back to caller
   IF @cCallSource2 = '1'
   BEGIN
      SET @cCallSource2 = ''
      GOTO ShowDistr1
   END
   IF @cCallSource2 = '2'
   BEGIN
      SET @cCallSource2 = ''
      GOTO ShowDistr2
   END
   IF @cCallSource2 = '3'
   BEGIN
      SET @cCallSource2 = ''
      GOTO ShowDistr3
   END
   IF @cCallSource2 = '4'
   BEGIN
      SET @cCallSource2 = ''
      GOTO ShowDistr4
   END
END

GET_SKU:
BEGIN
   SET @cSku = ''
   SET @nQty = 0

   SELECT TOP 1 @cSku  = SKU,
               @nQty   = Qty
   FROM rdt.rdtFlowThruSortDistr WITH (NOLOCK)
   WHERE BatchNo  = @cBatchNo
   AND UserName   = @cUserName
   AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
   AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
   AND OrderKey   = @cV_OrderKey
   AND SKU        > @cV_Sku         -- next SKU
   AND Status     = '1'
   Order by SKU

   IF @cSku IS NULL
      SET @cSku = ''
   IF @nQty IS NULL
      SET @nQty = 0

   IF @cCallSource = '1'
   BEGIN
      SET @cCallSource = ''
      GOTO GET_SKU1
   END
   IF @cCallSource = '2'
   BEGIN
      SET @cCallSource = ''
      GOTO GET_SKU2
   END
   IF @cCallSource = '3'
   BEGIN
      SET @cCallSource = ''
      GOTO GET_SKU3
   END
END

/************************************************************************************
Step_5. Scn = 1714. Screen 5.
   Finish distribute?

   1=Yes
   2=No

   Option   (field01)
************************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63975
         SET @cErrMsg = rdt.rdtgetmessage( 63975, @cLangCode, 'DSP') --Option needed
         GOTO Step_5_Fail
      END

      IF Not ( @cOption = '1' OR @cOption = '2' )
      BEGIN
         SET @nErrNo = 63976
         SET @cErrMsg = rdt.rdtgetmessage( 63976, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      --  GOTO screen 1711 step - 2
      IF @cOption = '1'
      BEGIN
         BEGIN TRAN

         -- Finish Distribute, Change status
         UPDATE rdt.rdtFlowThruSort WITH (RowLOCK)
         SET Status = '9'
         WHERE BatchNo  = @cBatchNo
         AND UserName   = @cUserName
         AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status     = '1'
         
         IF @@Error <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 63977
            SET @cErrMsg = rdt.rdtgetmessage( 63977, @cLangCode, 'DSP') -- 'UPD WSortFail'
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            IF @nErrNo = 1
               SET @cErrMsg =''
            GOTO Step_5_Fail
         END

         UPDATE rdt.rdtFlowThruSortDistr WITH (RowLOCK)
         SET Status = '9'
         WHERE BatchNo  = @cBatchNo
         AND UserName   = @cUserName
         AND WaveKey    = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey    = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status     = '1'
         
         IF @@Error <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 63978
            SET @cErrMsg = rdt.rdtgetmessage( 63978, @cLangCode, 'DSP') -- 'UPD WSortFail'
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            IF @nErrNo = 1
               SET @cErrMsg =''
            GOTO Step_5_Fail
         END

         COMMIT TRAN

         SET @cBatchNo = ''

         -- Reset this screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = '' -- SKU/UPC
         SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = ''  -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
         SET @cOutField06 = '0/0'   --SKU QTY
         SET @cOutField07 = '0/0' -- Total QTY
         SET @cOutField08 = @cLoadKey

         IF @cFlowThruSortationLockQty = '1'
            SET @cFieldAttr05 = 'O' 
         
         SET @cCallSource3 = '5'
         GOTO CheckPeiceScan
         CheckPeiceScan5:

         -- Go to next screen
         SET @nScn = 1711
         SET @nStep = 2
      END

      --  GOTO previous screen
      IF @cOption = '2'
      BEGIN
         SET @cOutField01 = ''  -- Option
         SET @cV_OrderKey = ''
         SET @cV_Sku = ''

         -- Get Previous screen and show
         SET @cCallSource2 = '3'
         GOTO ShowDistr
         ShowDistr3:

         -- Back to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''  -- Option
      SET @cV_OrderKey = ''
      SET @cV_Sku = ''

      SET @cCallSource2 = '4'
      GOTO ShowDistr
      ShowDistr4:
      -- Back to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''  -- Option
   END
END
GOTO Quit


/************************************************************************************
Step_6. Scn = 1715. Screen 6.
   Are you sure?

   1=Yes
   2=No

   Option   (field01)
************************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63975
         SET @cErrMsg = rdt.rdtgetmessage( 63975, @cLangCode, 'DSP') --Option needed
         GOTO Step_5_Fail
      END

      IF Not ( @cOption = '1' OR @cOption = '2' )
      BEGIN
         SET @nErrNo = 63976
         SET @cErrMsg = rdt.rdtgetmessage( 63976, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      IF @cOption = '1'
      BEGIN
         BEGIN TRAN

         -- Finish Distribute, Change status
         DELETE rdt.rdtFlowThruSort WITH (RowLOCK)
         WHERE UserName   = @cUserName
         AND WaveKey      = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey      = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status       = '0'
         
         IF @@Error <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 63979
            SET @cErrMsg = rdt.rdtgetmessage( 63979, @cLangCode, 'DSP') -- 'DEL WSortFail'
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            
            IF @nErrNo = 1
               SET @cErrMsg =''
            GOTO Step_2_Fail
         END

         COMMIT TRAN
         -- Commented (Vicky02)
         --DELETE rdt.RDTSessionData WITH (ROWLOCK) WHERE Mobile = @nMobile

         -- Reset this screen var
         SET @cOutField01 = '' -- WaveKey
         SET @cWaveKey = ''
         SET @cBatchno = ''

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

         -- Back to wave/load screen
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
      END
      
      IF @cOption = '2'
      BEGIN
         Go_Back_Screen2:
         SELECT @nTtlQty = ISNULL( SUM( Qty), 0)
         FROM rdt.rdtFlowThruSort WITH (NOLOCK)
         WHERE BatchNo = @cBatchNo
         AND UserName  = @cUserName
         AND WaveKey   = CASE WHEN ISNULL(@cWaveKey, '') <> '' THEN @cWaveKey ELSE WaveKey END
         AND LoadKey   = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         AND Status <> '9'

         IF ISNULL(@cWaveKey, '') <> ''
         BEGIN
            SELECT @nQtyToScan = ISNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0)  
            FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
            INNER JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Userdefine09 = WD.WaveKey AND ORDERS.ORDERKey = WD.OrderKey )
            INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = ORDERS.StorerKey AND OD.ORDERKey = ORDERS.OrderKey )
            WHERE WD.Wavekey = @cWaveKey
         END
         ELSE
         BEGIN
            SELECT @nQtyToScan = ISNULL( SUM( QtyAllocated + QtyPicked), 0)   
            FROM dbo.OrderDetail WITH (NOLOCK) 
            WHERE LoadKey = @cLoadKey
         END
      
         -- Reset this screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = '' -- SKU/UPC
         SET @cOutField03 = '' --SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = ''  -- SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = CASE WHEN @cFlowThruSortationPieceScaning = '1' THEN '1' ELSE '' END -- default QTY
         SET @cOutField06 = '0/0' --SKU QTY
         SET @cOutField07 = CAST( @nTtlQty AS NVARCHAR( 5)) + '/' + CAST( @nQtyToScan AS NVARCHAR( 5)) -- Total QTY
         SET @cOutField08 = @cLoadKey

         IF @cFlowThruSortationLockQty = '1'
            SET @cFieldAttr05 = 'O' 
         
         -- Back to SKU screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
         GOTO Quit
      END
   END
   
   IF @nInputKey = 0 -- Yes or Send
   BEGIN
      GOTO Go_Back_Screen2
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

      StorerKey      = @cStorer,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      Printer        = @cPrinter,

      V_SKU          = @cV_SKU,
      V_Orderkey     = @cV_OrderKey,
      V_LoadKey      = @cLoadKey, 
      V_String1      = @cWaveKey,
      V_String2      = @cBatchNo,

      V_String3      = @cFlowThruSortationPieceScaning,
      V_String4      = @cFlowThruSortationLockQty,
      V_String5      = @cLastSKU,
      
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