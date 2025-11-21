SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdtfnc_Scan_To_Van_MBOL_Creation                            */
/* Copyright      : IDS                                                         */
/*                                                                              */
/* Purpose: SOS#177894 - RDT Dynamic MBOL                                       */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date         Rev   Author   Purposes                                         */
/* 16-06-2010   1.0   KHLim    Created                                          */
/* 20-07-2010   1.1   Vicky    User Orders.UserDefine01 to determine ECOM       */
/*                             (Vicky01)                                        */
/* 21-07-2010   1.2   James    Bug fix (james01)                                */
/*                             add dbo to table                                 */
/* 22-07-2010   1.3   KHLim    Bug fix (KHLim01)                                */
/* 24-07-2010   1.4   Vicky    Insert Orderkey to rdtScanToTruck table (Vicky02)*/
/* 26-07-2010   1.5   KHLim    Allow scan same tote after MBOL shipped (KHLim02)*/
/*                             Add counter for tote scanned on 2nd screen       */
/* 27-07-2010   1.6   KHLim    validate Status of PackHeader by ToteNo (KHLim03)*/
/* 27-07-2010   1.7   Vicky    Fix Rowcount (Vicky03)                           */
/* 28-07-2010   1.8   Vicky    Checking of Close Tote should use PackDetail.QTY */
/*                             against PickDetail.Qty (Vicky04)                 */
/* 10-08-2010   1.9   KHLim    RefNo is blank in Store process (KHLim04)        */
/* 17-08-2010   2.0   Vicky    - Release PTS LOC when Tote is scanned           */
/*                             - Revamp SP to allow Multi P/S in a Tote         */
/*                             (Vicky05)                                        */
/* 28-08-2010   2.1   James    Cater for DPD Label (james02)                    */
/* 31-08-2010   2.2   Shong    Revise Tot Picked vs Total Pack Qty (shong01)    */
/* 14-10-2010   2.3   James    No filter on status when get Pick Qty (james03)  */
/* 25-10-2010   2.4   James    Cannot mix ordergroup (james04)                  */
/* 09-11-2010   2.5   James    Get route from orders.route instead of from      */
/*                             storersodefault (james05)                        */
/* 29-11-2010   2.6   James    Get loadkey from Orders table (james06)          */
/* 13-01-2011   2.7   James    Add in EventLog (james07)                        */
/* 18-01-2011   2.8   Leong    SOS# 202579 - Not allow same E-COMM Label exists */
/*                                           in multiple MBOL                   */
/* 14-02-2011   2.9   ChewKP   SOS# 202460 - Scan to van changes for C&C        */ 
/*                             (ChewKP01)                                       */ 
/* 18-02-2011   2.10  SPChin   SOS#205302 - Cater all user process into EventLog*/ 
/* 02-03-2011   2.11  James    SOS206353 - Nominated day delivery (james08)     */ 
/* 02-03-2011   2.12  James    Apply config on Nominated day delivery (james09) */ 
/* 27-04-2011   2.13  ChewKP   SOS#213701 Process changed for C&C (ChewKP02)    */ 
/* 27-04-2011   2.14  James    SOS212779 - Change to date scan instead of       */
/*                             day name (james10)                               */ 
/* 12-05-2011   2.15  James    SOS209446 - Standarize mboldetail insertion      */
/*                             with isp_InsertMBOLDetail (james11)              */
/* 05-01-2012   2.16  Ung      SOS229824 Fix scan tote no, data truncate error  */
/* 29-11-2012   2.17  ChewKP   SOS#262664 - Screen change and enhancement       */
/*                             (ChewKP03)                                       */   
/* 17-11-2014   2.18  James    SOS326139 - Add ExtendedUpdateSP (james12)       */
/* 17-12-2014   2.19  James    SOS328456 - Enhance nominated day delivery       */
/*                             logic (james13)                                  */
/* 29-12-2014   2.20  James    SOS329393 - Add Carrier screen (james14)         */
/*                                         Add config MBOLScanCarrier           */
/*                                         Add DecodeLabelNo                    */
/* 26-01-2015   2.21  James    SOS331117 - Store pallet id in rdtscantotruck    */
/*                             table (james15)                                  */
/* 02-02-2015   2.22  James    SOS332388 - Add ExtendedInfoSP (james16)         */
/* 09-03-2015   2.23  James    SOS335136 - Extra sack validation (james17)      */
/* 14-01-2016   2.24  James    Extend @cOption to NVARCHAR( 2) (james18)        */
/* 2016-09-30   2.25  Ung      Performance tuning                               */
/* 28-10-2016   2.26  James    Change isDate to rdtIsValidDate (james19)        */
/********************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_To_Van_MBOL_Creation] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cConsigneekey       NVARCHAR(15),
   @cOrderKey           NVARCHAR(10),
   @cLoadKey            NVARCHAR(10),
   @cPickSlipNo         NVARCHAR(10),
   @cMBOLKey            NVARCHAR(10),
   @cMBOLLineNumber     NVARCHAR(5),
   @cToteNo             NVARCHAR(32),-- (james01)/(james14)
   @cRoute              NVARCHAR(20),
   @cPlaceOfLoadingQualifier  NVARCHAR(10),
   @cStatus             NVARCHAR(1),
   @cStatusPH           NVARCHAR(1), -- (KHLim03)
   @cErrMsg1            NVARCHAR(14),
   @cErrMsg2            NVARCHAR(14),
   @cUserDef01          NVARCHAR(20), -- (Vicky01)
   @cPTSLoc             NVARCHAR(10), -- (Vicky05)
   @cPackOrderKey       NVARCHAR(10), -- (Vicky05)
   @cCtnType            NVARCHAR(10), -- KHLim02

   @nRcnt               INT,         -- (KHLim04)
   @nScanned            INT,         -- (KHLim02)
   @nTotalPackQTy       INT,
   @nTotalPickQTy       INT,
   @nPackQTy            INT,           -- (Vicky05)
   @cBarCode            NVARCHAR(28) ,  -- (james02)
   @cCDigit             NVARCHAR(1),       -- (james02)
   @nPickQty            INT,           -- (Shong01)
   @cDropIDType         NVARCHAR(10),   -- (Shong01)
   @cOrderGroup         NVARCHAR(20),   -- (james04)
   @cNOMIXORDGROUP      NVARCHAR(1),    -- (james04)
   @nCurScn             INT,           -- (james08)
   @nCurStep            INT,           -- (james08)
   @cDay                NVARCHAR(20),   -- (james08)
   @dDeliveryDate       DATETIME,      -- (james08)
   @cInput_Date         NVARCHAR(10),   -- (james10)
   @cCollection_Date    NVARCHAR(10),   -- (james10)
   @cOrdType            NVARCHAR(10),      -- (james10)
   @cOtherReference     NVARCHAR(30),      -- (ChewKP03)
   @cPalletID           NVARCHAR(20),      -- (ChewKP03)
   @cOption             NVARCHAR(2),       -- (ChewKP03)/(james18)
   @cContainerKey       NVARCHAR(10),      -- (ChewKP03)
   @bSuccess            INT,           -- (ChewKP03)
   @cContainerType      NVARCHAR(10),      -- (ChewKP03)
   @cPalletLoc          NVARCHAR(10),      -- (CheWKP03)
   @cPalletSKU          NVARCHAR(20),      -- (ChewKP03)
   --@cUserDefine02       NVARCHAR(60),      -- (ChewKP03)
   @cNSStore            NVARCHAR(15),      -- (ChewKP03)
   @cPalletClose        NVARCHAR(1),       -- (ChewKP03)
   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james12)
   @cSQL                NVARCHAR(1000),   -- (james12)
   @cSQLParam           NVARCHAR(1000),   -- (james12)

   @cNominatedDayDelivery  NVARCHAR( 20), -- (james13)
   @cCarrier               NVARCHAR( 10), -- (james14)
   @cMBOLScanCarrier       NVARCHAR( 1),  -- (james14)
   @cExtendedValidateSP    NVARCHAR( 20), -- (james14)
   @cExtendedInfoSP        NVARCHAR( 20), -- (james16)

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
   @cAuthority             NVARCHAR( 1),   -- (james11)
   @cExternOrderKey        NVARCHAR( 30),  -- (james11)
   @cCustomerName          NVARCHAR( 45),  -- (james11)
   @cInvoiceNo             NVARCHAR( 10),  -- (james11)
   @nTotalCartons          INT,        -- (james11)
   @nStdGrossWgt           INT,        -- (james11)
   @nStdCube               INT,        -- (james11)
   @n_err                  INT,        -- (james11)
   @c_errmsg               NVARCHAR(20),   -- (james11)
   @dDelivery_Date         DATETIME,   -- (james11)
   @dOrderDate             DATETIME    -- (james11)

-- (james14)
DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20)


-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @dDeliveryDate    = V_Lottable04,   -- (james08)
   @cConsigneekey    = V_ConsigneeKey,
   @cOrderKey        = V_OrderKey,
   @cLoadKey         = V_LoadKey,
   @cPickSlipNo      = V_PickSlipNo,
   @cMBOLKey         = V_String1,
   @cCarrier         = V_String2,   -- (james14)
   @cRoute           = V_String3,
   @cPlaceOfLoadingQualifier = V_String4,
   @cStatus          = V_String5,
   @nScanned         = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String6, 5), 0) = 1 THEN LEFT(V_String6, 5) ELSE 0 END, -- (KHLim02)
   @cStatusPH        = V_String7, -- (KHLim03)
   @cNOMIXORDGROUP   = V_String8, -- (james04)
   @cOrderGroup      = V_String9, -- (james04)
   @nCurScn          = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String10, 5), 0) = 1 THEN LEFT(V_String10, 5) ELSE 0 END, -- (james08)
   @nCurStep         = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String11, 5), 0) = 1 THEN LEFT(V_String11, 5) ELSE 0 END, -- (james08)
   @cDay             = V_String12,     -- (james08)
   @cToteNo          = V_String13 + V_String14,
   @cPalletID        = V_String15,
   @cNSStore         = V_String16,
   @cPalletClose     = V_String17,

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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile


-- Redirect to respective screen
IF @nFunc = 1643
BEGIN
   -- (ChewKP03)
   DECLARE  @nStepMBOLKey          INT,
            @nScnMBOLKey           INT,
            @nStepTote             INT,
            @nScnTote              INT,
            @nStepStore            INT,
            @nScnStore             INT,  
            @nStepPallet           INT,
            @nScnPallet            INT,
            @nStepCarrier          INT,
            @nScnCarrier           INT 

   
   SET @nStepMBOLKey            = 1           
   SET @nScnMBOLKey             = 2380
   
   SET @nStepTote               = 2           
   SET @nScnTote                = 2381

   SET @nStepPallet             = 4
   SET @nScnPallet              = 2383
      
   SET @nStepStore              = 5           
   SET @nScnStore               = 2384
   
   SET @nStepCarrier            = 6       -- (james14)
   SET @nScnCarrier             = 2385    -- (james14)
                 
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1643
   IF @nStep = 1 GOTO Step_1   -- Scn = 2380  MBOLKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 2381  Tote / Bag
   IF @nStep = 3 GOTO Step_3   -- Scn = 2382  Day
   IF @nStep = 4 GOTO Step_4   -- Scn = 2383  Pallet / Cage -- (ChewKP03)
   IF @nStep = 5 GOTO Step_5   -- Scn = 2384  Store         -- (ChewKP03)
   IF @nStep = 6 GOTO Step_6   -- Scn = 2385  Carrier       -- (james14)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1643)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2380
   SET @nStep = 1

   -- Get the default option in to tote screen
   SET @cNOMIXORDGROUP = rdt.RDTGetConfig( @nFunc, 'NOMIXORDGROUP', @cStorerKey)
   IF ISNULL(@cNOMIXORDGROUP, '') = ''
      SET @cNOMIXORDGROUP = ''


   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- initialise all variable
   SET @cConsigneekey    = ''
   SET @cOrderKey        = ''
   SET @cLoadKey         = ''
   SET @cMBOLKey         = ''
   SET @cPickSlipNo      = ''
   SET @cToteNo          = ''
   SET @cRoute           = ''
   SET @cPlaceOfLoadingQualifier  = ''
   SET @cStatus          = ''
   SET @nScanned         = 0 -- KHLim02
   SET @cPalletClose     = '0'

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2380
   MBOL (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = @cInField01

      -- Validate blank
      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SET @nErrNo = 69766
         SET @cErrMsg = rdt.rdtgetmessage( 69766, @cLangCode, 'DSP') --MBOL# req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKEY =  @cMBOLKey)-- (Vicky05)
      BEGIN
         SET @nErrNo = 69767
         SET @cErrMsg = rdt.rdtgetmessage( 69767, @cLangCode, 'DSP') --Invalid MBOL#
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- (james04)
      SELECT TOP 1 @cOrderGroup = O.OrderGroup
      FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.MbolDetail MBOLD WITH (NOLOCK) ON O.OrderKey = MBOLD.OrderKey
      WHERE MBOLD.MBOLKEY =  @cMBOLKey

      SELECT @cPlaceOfLoadingQualifier = PlaceOfLoadingQualifier,
             @cStatus                  = Status
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE MbolKey = @cMBOLKey

      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 69768
         SET @cErrMsg = rdt.rdtgetmessage( 69768, @cLangCode, 'DSP') --MBOL Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNULL(RTRIM(@cPlaceOfLoadingQualifier), '') = '' -- (Vicky05)
      BEGIN
         SET @nErrNo = 69769
         SET @cErrMsg = rdt.rdtgetmessage( 69769, @cLangCode, 'DSP') --RouteNotSetup
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      --prepare next screen variable
-- (ChewKP01)      
--      SET @cOutField01 = @cMBOLKey
--      SET @cOutField02 = @cPlaceOfLoadingQualifier
--      SET @cOutField03 = ''
--      SET @cOutField04 = ''
--      SET @cOutField05 = ''
--
--      SELECT @nScanned = COUNT(1)
--      FROM RDT.RDTScanToTruck WITH (NOLOCK) -- KHLim02
--      WHERE MBOLKey = @cMBOLKey
--
--      SET @cOutField04 = @nScanned -- KHLim02
--
--      SET @nScn = @nScn + 1
--      SET @nStep = @nStep + 1

      SET @cMBOLScanCarrier = '0'
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cToteNo         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 20), ' +
               '@cOrderkey       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo NOT IN (0, 1)
               GOTO Step_1_Fail

            IF @nErrNo = 1
               SET @cMBOLScanCarrier = '1'
         END
      END
      
      IF @cMBOLScanCarrier <> '1'
      BEGIN
         -- (ChewKP01)        
         SET @cRoute = ''

         SET @cOutField01 = ''

         SET @nScn = @nScnPallet
         SET @nStep = @nStepPallet
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = ''

         SET @nScn = @nScnCarrier
         SET @nStep = @nStepCarrier
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @cConsigneekey    = ''
      SET @cOrderKey        = ''
      SET @cLoadKey         = ''
      SET @cMBOLKey         = ''
      SET @cPickSlipNo      = ''
      SET @cToteNo          = ''
      SET @cRoute           = ''
      SET @cPlaceOfLoadingQualifier  = ''
      SET @cStatus          = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cMBOLKey = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2381
   MBOL  (Field01)
   ROUTE (Field02)
   TOTE  (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToteNo      = @cInField03
      SET @cOption      = @cInField05

      -- Validate blank
      IF @cToteNo = '' AND @cOption = '' -- (ChewKP03)
      BEGIN
         SET @nErrNo = 69770
         SET @cErrMsg = rdt.rdtgetmessage( 69770, @cLangCode, 'DSP') --Tote/Bag# req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- (james14)
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      IF ISNULL(@cToteNo, '') <> '' AND ISNULL(@cDecodeLabelNo, '') <> ''
      BEGIN
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cToteNo
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = @cMBOLKey
            ,@c_POKey      = @cCarrier    -- pass in parameter
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF ISNULL( @cErrMsg, '') <> '' 
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END
            
         SET @cToteNo = @c_oFieled01
      END

      -- Check if label scanned (james02)
      IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                 WHERE MbolKey = @cMBOLKey
                 AND RefNo = @cToteNo)
      BEGIN
         SET @nErrNo = 69783
         SET @cErrMsg = rdt.rdtgetmessage( 69783, @cLangCode, 'DSP') --Label Scanned
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletID AND Status = '3' ) 
      BEGIN
         SET @nErrNo = 69807
         SET @cErrMsg = rdt.rdtgetmessage( 69807, @cLangCode, 'DSP') --PalletClose
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END
      
      -- (ChewKP03)
      IF ISNULL(RTRIM(@cOption),'') <> '' 
      BEGIN
         IF @cOption = '1'
         BEGIN
            
            BEGIN TRAN
               
            Update dbo.Pallet WITH (ROWLOCK)
               SET Status  = '3'
            WHERE PalletKey = @cPalletID
            
            
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69802
               SET @cErrMsg = rdt.rdtgetmessage( 69802, @cLangCode, 'DSP') --UpdPalletFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            
            Update dbo.PalletDetail WITH (ROWLOCK)
               SET Status  = '3'
            WHERE PalletKey = @cPalletID
            
            
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69803
               SET @cErrMsg = rdt.rdtgetmessage( 69803, @cLangCode, 'DSP') --UpdPalletDetFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            
            COMMIT TRAN
            
            
            SET @cPalletClose = '1'
            
            IF @cPalletClose = '1' AND @cToteNo = ''
            BEGIN
               GOTO CLOSEPALLET_NEXTSTEP
            END
         END
         ELSE  -- (james18)
         BEGIN
            SET @nErrNo = 69813
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_2_Fail
         END                
      END

      -- (james17)
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended update
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cToteNo         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 20), ' +
               '@cOrderkey       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
         END
      END
      
      /* -------------------- E-COMM process -------------------- */
      IF @cPlaceOfLoadingQualifier = 'ECOMM'
      BEGIN
         SET @cCtnType = 'E-COMM' -- KHLim02

         SELECT TOP 1 @cPickSlipNo = ph.PickSlipNo -- (Vicky03)
         FROM dbo.PackDetail pd WITH (NOLOCK)
         JOIN dbo.PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo
         JOIN dbo.ORDERS SO WITH (NOLOCK) ON SO.OrderKey = ph.OrderKey AND SO.[Status] NOT IN ('9','CANC')
         -- JOIN dbo.Dropid DI WITH (NOLOCK) ON DI.Dropid = PD.DropID AND DI.Loadkey=SO.LoadKey
         WHERE pd.RefNo   = @cToteNo
         AND pd.StorerKey = @cStorerKey -- KHLim02
         ORDER BY ph.PickSlipNo DESC

         IF @@ROWCOUNT = 0
         BEGIN
            SET @cBarCode = SUBSTRING(@cToteNo, 2, 27)
            EXEC isp_CheckDigitsISO7064
               @cBarCode,
               @b_success OUTPUT,
               @cCDigit  OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 69782
               SET @cErrMsg = rdt.rdtgetmessage( 69782, @cLangCode, 'DSP') --CheckDigitFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END

            SET @cBarCode = @cBarCode + @cCDigit
            SELECT TOP 1 @cPickSlipNo = PickSlipNo -- (Vicky03)
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE RefNo   = @cBarCode

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 69771
               SET @cErrMsg = rdt.rdtgetmessage( 69771, @cLangCode, 'DSP') --BagNotExists
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               SET @cToteNo = SUBSTRING(@cToteNo, 2, 27) + @cCDigit

               -- Check if label scanned (james02)
               -- IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
               --            WHERE MbolKey = @cMBOLKey
               --            AND RefNo = @cToteNo)
               IF EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                          WHERE RefNo = @cToteNo) -- SOS# 202579
               BEGIN
                  SET @nErrNo = 69787
                  SET @cErrMsg = rdt.rdtgetmessage( 69787, @cLangCode, 'DSP') --Label Scanned
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_2_Fail
               END
            END
         END

         SELECT @cStatusPH    = Status,  -- (KHLim03)
                @cOrderKey     = OrderKey,
                @cLoadKey      = LoadKey,
                @cConsigneeKey = ConsigneeKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         -- (james04)
         IF @cNOMIXORDGROUP = '1'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                       WHERE OrderKey = @cOrderKey
                       AND   OrderGroup = @cOrderGroup)
            BEGIN
               SET @nErrNo = 69788
               SET @cErrMsg = rdt.rdtgetmessage( 69788, @cLangCode, 'DSP') --NOMIXORDGROUP
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
         END

         SELECT @cUserDef01    = ISNULL(RTRIM(UserDefine01), '')
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Orderkey = @cOrderKey

         IF ISNULL(RTRIM(@cUserDef01), '') = ''
         BEGIN
            SET @nErrNo = 69772
            SET @cErrMsg = rdt.rdtgetmessage( 69772, @cLangCode, 'DSP') --NotECOMMTote
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         -- (Vicky04) - Start
         SELECT @nTotalPackQTy = ISNULL(SUM(QTY), 0)
         FROM dbo.PackDetail WiTH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         SELECT @nTotalPickQTy= ISNULL(SUM(QTY), 0)
         FROM dbo.PickDetail WiTH (NOLOCK)
         WHERE Orderkey = @cOrderKey
--         AND   Status = '5'  -- (james03)
         -- (Vicky04) - End

         IF @nTotalPackQTy <> @nTotalPickQTy -- (Vicky04)
         BEGIN
            --ROLLBACK TRAN
            SET @nErrNo = 69773
            SET @cErrMsg = rdt.rdtgetmessage( 69773, @cLangCode, 'DSP') --TOTE Not Close
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         SET @cOrdType = ''
         SELECT @cOrdType = [Type] FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Orderkey = @cOrderKey
         
         SET @cNominatedDayDelivery = rdt.RDTGetConfig( @nFunc, 'NominatedDayDelivery', @cStorerKey)
         
         IF ISNULL( @cNominatedDayDelivery, '') NOT IN ('', '0')
         BEGIN

            IF LEN( RTRIM( @cNominatedDayDelivery)) > 1 AND 
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cNominatedDayDelivery AND type = 'P')
            BEGIN

               SET @cSQL = 'EXEC ' + RTRIM( @cNominatedDayDelivery) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @c_oFieled01 OUTPUT'
               SET @cSQLParam =
                  '@nMobile                   INT, '           +
                  '@nFunc                     INT, '           +
                  '@cLangCode                 NVARCHAR( 3), '  +
                  '@nStep                     INT, '           + 
                  '@nInputKey                 INT, '           + 
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@cMbolKey                  NVARCHAR( 10), ' +
                  '@cToteNo                   NVARCHAR( 20), ' +
                  '@cOption                   NVARCHAR( 1), '  +
                  '@cOrderkey                 NVARCHAR( 10), ' +
                  '@c_oFieled01               NVARCHAR( 20) OUTPUT ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @c_oFieled01 OUTPUT

               IF ISNULL( @c_oFieled01, '') <> ''
               BEGIN
                  SET @nCurScn = @nScn
                  SET @nCurStep = @nStep

                  SET @cOutField01 = UPPER(DATENAME(dw, CONVERT( DATETIME, @c_oFieled01, 103)))
                  SET @cOutField02 = ''
                  SET @cOutField03 = rdt.rdtFormatDate(@c_oFieled01)

                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  GOTO QUIT
               END
            END
            ELSE
            BEGIN
               -- If storer config setup and order type exists in codelkup then only show
               IF rdt.RDTGetConfig( @nFunc, 'NominatedDayDelivery', @cStorerKey) = 1 AND   -- (james09)
               EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK) WHERE ListName = 'ShowNomDay' AND Code = @cOrdType)
               BEGIN

                  -- If Orders.Delivery date is not blank/null then goto screen 3 (james08)
                  SELECT @dDeliveryDate = DeliveryDate 
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderKey
                     AND ISNULL(DeliveryDate, '') <> ''

                  IF ISNULL(@dDeliveryDate, '') <> ''
                  BEGIN
                     SET @nCurScn = @nScn
                     SET @nCurStep = @nStep

                     IF CONVERT(NVARCHAR( 8), @dDeliveryDate, 112) <= '19700102'
                     BEGIN
                        SET @cDay = 'STANDARD'
                        SET @cOutField03 = ''
                     END
                     ELSE
                     -- If less than or equal to current date, then value is current day
                     IF CONVERT(NVARCHAR( 8), @dDeliveryDate, 112) <= CONVERT(NVARCHAR( 8), GETDATE(), 112)
                     BEGIN
      --                  SET @cDay = 'TODAY' (james10)
                        SET @cDay = UPPER(DATENAME(dw, GETDATE()))
                        SET @cOutField03 = rdt.rdtFormatDate(GETDATE())
                     END
                     ELSE
                     BEGIN
                        SET @cDay = UPPER(DATENAME(dw, @dDeliveryDate))
                        SET @cOutField03 = rdt.rdtFormatDate(@dDeliveryDate)
                     END
                  END
                  
                  SET @cOutField01 = @cDay
                  SET @cOutField02 = ''

                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  GOTO QUIT
               END
            END
         END

         Continue_Ins_Ecomm_Orders:

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                        WHERE RefNo = @cToteNo
                        AND MBOLKey = @cMBOLKey
                        AND LoadKey = @cLoadKey
                        AND URNNo   = @cOrderKey)
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck AS STT WITH (NOLOCK)
                           WHERE RefNo = @cToteNo
                           AND EXISTS (SELECT 1 FROM dbo.MBOL AS MBL
                                       WHERE MBL.MBOLKey = STT.MBOLKey AND Status <> '9'))
            BEGIN
               BEGIN TRAN

               INSERT INTO RDT.RDTScanToTruck
               (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)
               VALUES (@cMBOLKey, @cLoadKey, CASE WHEN @cPlaceOfLoadingQualifier = 'ECOMM' THEN 'E-COMM' ELSE 'STORE' END, 
                       @cToteNo, @cOrderKey, '9', @cUserName, GETDATE(), @cUserName, GETDATE()) -- (Vicky02)

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 69774
                  SET @cErrMsg = rdt.rdtgetmessage( 69774, @cLangCode, 'DSP') --InsScn2TrkFail
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_2_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
                  /* SOS#205302 Start */
                  -- insert to Eventlog
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '16', -- Scan2Van
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerkey,
                    @cRefNo1       = @cMBOLKey,
                    @cRefNo2       = @cLoadKey,
                    @cRefNo3       = @cOrderKey
                  /* SOS#205302 End */
               END
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey)
         BEGIN
            SELECT @cMBOLLineNumber = RIGHT('0000' + RTRIM(CAST(ISNULL(CAST(MAX(MBOLLineNumber) as int), 0) + 1 as NVARCHAR(5))), 5)
            FROM   dbo.MBOLDETAIL (NOLOCK)
            WHERE  MBOLKey = @cMBOLKey

            BEGIN TRAN

--            INSERT INTO dbo.MBOLDETAIL
--            (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, EditWho)
--            VALUES (@cMBOLKey, @cMBOLLineNumber, @cOrderKey, @cLoadKey, '*' + RTRIM(sUser_sName()), 'rdt.' + RTRIM(sUser_sName()) )

            -- Auto populate Carton QTY from PackingInfo into MbolDetail CtnCnt1 if storerconfig setup is: 
            -- CAPTURE_PACKINFO = 1  and  MBOLSUMCTNCNT2TOTCTN = 2 or MBOLSUMCTNCNT2TOTCTN = 1
            SET @b_success = 0
            SET @cAuthority = '0'
            SET @nTotalCartons = 0
               
            EXECUTE nspGetRight null,           -- facility
                     @cStorerkey,              -- Storerkey
                     null,                      -- Sku
                     'CAPTURE_PACKINFO',        -- Configkey
                     @b_success    output,
                     @cAuthority  output, 
                     @n_err        output,
                     @c_errmsg     output

            IF @cAuthority = '1' AND @b_success = 1
            BEGIN
               SET @b_success = 0
               SET @cAuthority = '0'
               EXECUTE nspGetRight null,           -- facility
                        @cStorerkey,               -- Storerkey
                        null,                      -- Sku
                        'MBOLSUMCTNCNT2TOTCTN',    -- Configkey
                        @b_success    output,
                        @cAuthority  output, 
                        @n_err        output,
                        @c_errmsg     output

               IF (@cAuthority = '1' OR @cAuthority = '2') AND @b_success = 1
               BEGIN
                  SELECT @nTotalCartons = COUNT(Distinct CartonNo)
                  FROM PACKDETAIL WITH (NOLOCK)
                  JOIN PACKHEADER WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipno)
                  WHERE PACKHEADER.Orderkey = @cOrderkey
               END
            END

            SELECT @cExternOrderKey = '', @dDelivery_Date = '', @cCustomerName = '', @cInvoiceNo = ''
            SELECT @nStdGrossWgt = 0, @nStdCube = 0

            SELECT 
               @cExternOrderKey  = ExternOrderKey, 
               @dDelivery_Date   = DeliveryDate, 
               @cCustomerName    = C_Company, 
               @dOrderDate       = OrderDate, 
               @cInvoiceNo       = InvoiceNo 
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

            SELECT 
			      @nStdGrossWgt = SUM(OD.OpenQty * SKU.StdGrossWgt),  
			      @nStdCube = SUM(OD.OpenQty * SKU.StdCube) 
            FROM dbo.OrderDetail OD WITH (NOLOCK) 
            JOIN SKU SKU WITH (NOLOCK) ON (OD.SKU = SKU.SKU AND OD.StorerKey = SKU.StorerKey) 
            WHERE OD.StorerKey = @cStorerKey
               AND OD.OrderKey = @cOrderKey

            INSERT INTO MBOLDETAIL
               (MBOLKey,            MBOLLineNumber, 
                OrderKey,           LoadKey, 
                ExternOrderKey,     DeliveryDate, 
                Weight,             Cube,
                Description,        OrderDate,
                InvoiceNo,          
                AddWho,             EditWho,
                TotalCartons,       ctncnt1 )               
            VALUES
               (@cMBOLKey,          @cMBOLLineNumber,
                @cOrderKey,         @cLoadKey,
                @cExternOrderKey,   @dDelivery_Date, 
                @nStdGrossWgt,      @nStdCube,     
                @cCustomerName,     @dOrderDate,
                @cInvoiceNo,        
                '*' + RTRIM(sUser_sName()), 'rdt' + RTRIM(sUser_sName()), 
                @nTotalCartons,    @nTotalCartons )       

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69775
               SET @cErrMsg = rdt.rdtgetmessage( 69775, @cLangCode, 'DSP') --InsMBOLDetFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               -- (james12)
               SET @cExtendedUpdateSP = ''
               SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
               IF @cExtendedUpdateSP NOT IN ('0', '')
               BEGIN
                  SET @nErrNo = 0
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, ' + 
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                  SET @cSQLParam =    
                     '@nMobile                   INT, '           +
                     '@nFunc                     INT, '           +
                     '@cLangCode                 NVARCHAR( 3), '  +
                     '@nStep                     INT, '           +
                     '@nInputKey                 INT, '           + 
                     '@cStorerkey                NVARCHAR( 15), ' +
                     '@cMbolKey                  NVARCHAR( 10), ' +
                     '@cToteNo                   NVARCHAR( 20), ' +
                     '@cOption                   NVARCHAR( 10), ' +
                     '@cOrderkey                 NVARCHAR( 10), ' +
                     '@nErrNo                    INT           OUTPUT,  ' +
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
                     
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                       @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey,  
                       @nErrNo OUTPUT, @cErrMsg OUTPUT     
                       
                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 69810  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExtendUpd Fail'  
                     EXEC rdt.rdtSetFocusField @nMobile, 3
                     GOTO Step_2_Fail
                  END
                  ELSE
                     COMMIT TRAN
					/* SOS#205302 Start
               -- insert to Eventlog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '16', -- Scan2Van
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cRefNo1       = @cMBOLKey,
                  @cRefNo2       = @cLoadKey,
                  @cRefNo3       = @cOrderKey
               SOS#205302 End */
               END
            END
         END
      END
      ELSE IF @cPlaceOfLoadingQualifier = 'NS'   /* -------------------- NS process -------------------- */
      BEGIN
         
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                        WHERE RefNo = @cToteNo
                        AND MBOLKey = @cMBOLKey )
         BEGIN

            INSERT INTO RDT.RDTScanToTruck
            (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)
            VALUES (@cMBOLKey, '', '', @cToteNo, '', '9', @cUserName, GETDATE(), @cUserName, GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69808
               SET @cErrMsg = rdt.rdtgetmessage( 69808, @cLangCode, 'DSP') --InsScn2TrkFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            
         END
         
         
--         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cPalletID ) 
--         BEGIN
--            INSERT INTO DROPID (DropID, DropIDType, Status )
--            VALUES ( @cPalletID, 'NS', '0')
--            
--            IF @@ERROR <> 0 
--            BEGIN 
--               SET @nErrNo = 69805
--               SET @cErrMsg = rdt.rdtgetmessage( 69805, @cLangCode, 'DSP') --InsDropIDFail
--               EXEC rdt.rdtSetFocusField @nMobile, 3
--               GOTO Step_2_Fail
--            END
--            
--         END
         
--         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cPalletID AND ChildID = LEFT(RTRIM(@cToteNo),20) ) 
--         BEGIN
--            INSERT INTO DROPIDDetail (DropID, ChildID )
--            VALUES ( @cPalletID, LEFT(RTRIM(@cToteNo),20))
--            
--            IF @@ERROR <> 0 
--            BEGIN 
--               SET @nErrNo = 69806
--               SET @cErrMsg = rdt.rdtgetmessage( 69806, @cLangCode, 'DSP') --InsDropIDDetFail
--               EXEC rdt.rdtSetFocusField @nMobile, 3
--               GOTO Step_2_Fail
--            END
--            
--         END
      END
      ELSE
      BEGIN /* -------------------- STORE process -------------------- */
         SET @cCtnType = 'STORE' -- KHLim02

         
         --IF @nRcnt = 0
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE DropID = @cToteNo
                        AND StorerKey = @cStorerKey) -- (Vicky05)
         BEGIN
            SET @nErrNo = 69776
            SET @cErrMsg = rdt.rdtgetmessage( 69776, @cLangCode, 'DSP') --TOTENotExists
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         SET @cConsigneeKey = ''
         SELECT TOP 1 @cConsigneeKey = ORD.ConsigneeKey,
                      @cLoadkey = ORD.Loadkey,
                      @cOrderKey = ORD.OrderKey
         FROM dbo.ORDERS ORD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.Orderkey = ORD.Orderkey)
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
         JOIN dbo.DROPID DI WITH (NOLOCK) ON (DI.DropId = PD.DropID AND DI.Loadkey = ORD.LoadKey)
         WHERE PD.DropID = @cToteNo
         AND   PD.StorerKey = @cStorerKey
         AND   ORD.Route = @cPlaceOfLoadingQualifier
         AND   ORD.Status NOT IN ('9', 'CANC')
         -- (SHONGxx)
         IF ISNULL(RTRIM(@cConsigneeKey),'') = ''
         BEGIN
            SET @nErrNo = 69785
            SET @cErrMsg = rdt.rdtgetmessage( 69785, @cLangCode, 'DSP') --Invalid tote
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         -- (james04)
         IF @cNOMIXORDGROUP = '1'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                       WHERE OrderKey = @cOrderKey
                       AND   OrderGroup = @cOrderGroup)
            BEGIN
               SET @nErrNo = 69789
               SET @cErrMsg = rdt.rdtgetmessage( 69789, @cLangCode, 'DSP') --NOMIXORDGROUP
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
         END

--         SELECT @cRoute = [Route]
--         FROM dbo.StorerSODefault WITH (NOLOCK)
--         WHERE StorerKey = @cConsigneeKey

         -- (james05)
         SELECT TOP 1
                @cRoute = O.Route
         FROM dbo.ORDERS O WITH (NOLOCK)
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON
            (O.Orderkey = PH.Orderkey AND O.STORERKEY = PH.STORERKEY)
         JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN dbo.DROPID DROPID WITH (NOLOCK) ON (PD.DROPID = DROPID.DROPID)
         WHERE PD.Dropid =  @cToteNo
         AND PD.Storerkey = @cStorerkey
         AND O.USERDEFINE01 = ''
         AND O.Status NOT IN ('9', 'CANC')

         SET @cDropIDType = ''
         SELECT @cDropIDType = ISNULL(DropIDType,'')
         FROM   DROPID WITH (NOLOCK)
         WHERE  Dropid = @cToteNo

         -- (SHONGxx)
         -- Check the validity of tote scanned
         --IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
         --               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         --               JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         --               JOIN dbo.StorerSODefault SOD WITH (NOLOCK) ON O.ConsigneeKey = SOD.StorerKey
         --               WHERE O.StorerKey = @cStorerKey
         --                  AND O.Status NOT IN ('9', 'CANC')
         --                  AND SOD.Route = @cRoute
         --                  AND PD.DropID = @cToteNo)
         --BEGIN
         --   SET @nErrNo = 69785
         --   SET @cErrMsg = rdt.rdtgetmessage( 69785, @cLangCode, 'DSP') --Invalid tote
         --   EXEC rdt.rdtSetFocusField @nMobile, 3
         --   GOTO Step_2_Fail
         --END

         IF @cRoute <> @cPlaceOfLoadingQualifier
         BEGIN
            SET @nErrNo = 69777
            SET @cErrMsg = rdt.rdtgetmessage( 69777, @cLangCode, 'DSP') --Wrong Route
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         SET @nTotalPackQTy = 0
         SET @nTotalPickQTy = 0

         SET @nPackQTy=0

         SELECT @nPackQTy = SUM(PD.QTY)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
         JOIN dbo.Dropid DI WITH (NOLOCK) ON (DI.DropID = PD.DropID AND DI.Loadkey = PH.LoadKey)
         WHERE PD.DropID = @cToteNo

         SET @nPickQty = 0

         SELECT @nPickQty = ISNULL(SUM(PDT.QTY),0)
         FROM dbo.PickDetail PDT WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON PDT.OrderKey = O.OrderKey
         JOIN dbo.Dropid DI WITH (NOLOCK) ON DI.DropID = PDT.DropID AND DI.Loadkey = O.LoadKey
         --JOIN dbo.PackDetail PAD WITH (NOLOCK) ON PDT.DropID = PAD.RefNo2 AND PDT.SKU = PAD.SKU -- (ChewKP01) (ChewKP02)
         WHERE PDT.Status = '5'
         AND   PDT.DropID = @cToteNo
         AND   O.[Status] < '9'

         SET @nTotalPickQTy = @nTotalPickQTy + @nPickQty

         --IF @nPickQty=0
         --BEGIN
            SET @nPickQty=0
            SELECT @nPickQty = ISNULL(SUM(PDT.QTY),0)
            FROM dbo.PickDetail PDT WITH (NOLOCK)
            JOIN dbo.ORDERS O WITH (NOLOCK) ON PDT.OrderKey = O.OrderKey
            JOIN dbo.Dropid DI WITH (NOLOCK) ON DI.DropID = PDT.AltSKU AND DI.Loadkey = O.LoadKey
            --JOIN dbo.PackDetail PAD WITH (NOLOCK) ON PDT.DropID = PAD.RefNo2 AND PDT.SKU = PAD.SKU -- (ChewKP01) (ChewKP02)
            WHERE PDT.Status = '5'
            AND   PDT.AltSKU = @cToteNo
            AND   O.[Status] < '9'
         --END

         SET @nTotalPickQTy = @nTotalPickQTy + @nPickQty

         IF @nPackQTy <> @nTotalPickQTy
         BEGIN
            SET @nErrNo = 69784
            SET @cErrMsg = rdt.rdtgetmessage( 69784, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         SET @cOrdType = ''
         SELECT @cOrdType = [Type] FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Orderkey = @cOrderKey

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
                        WHERE RefNo = @cToteNo
                        AND MBOLKey = @cMBOLKey
                        AND LoadKey = @cLoadKey)
         BEGIN
            BEGIN TRAN

            INSERT INTO RDT.RDTScanToTruck
            (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)
            VALUES (@cMBOLKey, @cLoadKey, CASE WHEN @cPlaceOfLoadingQualifier = 'ECOMM' THEN 'E-COMM' ELSE 'STORE' END, 
                    @cToteNo, @cPalletID, '9', @cUserName, GETDATE(), @cUserName, GETDATE()) -- (james15)

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69779
               SET @cErrMsg = rdt.rdtgetmessage( 69779, @cLangCode, 'DSP') --InsScn2TrkFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
              COMMIT TRAN
              /* SOS#205302 Start */            
              -- insert to Eventlog
              EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '16', -- Scan2Van
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cRefNo1       = @cMBOLKey,
                 @cRefNo2       = @cLoadKey,
                 @cRefNo3       = @cOrderKey
              /* SOS#205302 End */
            END
         END

         -- Release Tote for Pieces Pick
         IF @cDropIDType = 'PIECE'
         BEGIN
--            UPDATE DROPID
--               SET STATUS = '9'
--            WHERE DropID = @cToteNo
--            AND   DropIDType = 'PIECE'
--            AND   STATUS < '9'
--            IF @@ERROR <> 0
--            BEGIN
--               SET @nErrNo = 69901
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'
--               EXEC rdt.rdtSetFocusField @nMobile, 3
--               GOTO Step_2_Fail
--            END
            EXEC [dbo].[nspInsertWCSRouting]
             @cStorerKey
            ,@cFacility
            ,@cToteNo
            ,'Scan2Van'
            ,'D'
            ,''
            ,@cUserName
            ,0
            ,@b_Success          OUTPUT
            ,@nErrNo             OUTPUT
            ,@cErrMsg            OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = @nErrNo
               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
               GOTO Step_2_Fail
            END

         END
         -- Insert MBOLDETAIL
         -- (SHONGxx)
         SET @cOrderKey = ''
         SET @cLoadKey = ''
         DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT ORD.Orderkey, ORD.LoadKey  -- (james06)
            FROM dbo.ORDERS ORD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.Orderkey = ORD.Orderkey)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.DropID = @cToteNo
            AND   PD.StorerKey = @cStorerKey
            AND   ORD.Status NOT IN ('9','CANC')
            AND   ORD.Route = @cPlaceOfLoadingQualifier
            AND   (ORD.MBOLKey = '' OR ORD.MBOLKey IS NULL)

            --FROM dbo.ORDERS ORD WITH (NOLOCK)
            --JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.Orderkey = ORD.Orderkey)
            --JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
            --WHERE PD.DropID = @cToteNo
            --AND   PD.StorerKey = @cStorerKey

         OPEN CUR_TOTE
         FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cLoadKey  -- (james06)
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey)
            BEGIN
               SELECT @cMBOLLineNumber = RIGHT('0000' + RTRIM(CAST(ISNULL(CAST(MAX(MBOLLineNumber) as int), 0) + 1 as NVARCHAR(5))), 5)
               FROM   dbo.MBOLDETAIL (NOLOCK)
               WHERE  MBOLKey = @cMBOLKey

               BEGIN TRAN

--               INSERT INTO dbo.MBOLDETAIL
--              (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, EditWho)
--               VALUES (@cMBOLKey, @cMBOLLineNumber, @cOrderKey, @cLoadKey, '*' + RTRIM(sUser_sName()), 'rdt.' + RTRIM(sUser_sName()) )

               -- Auto populate Carton QTY from PackingInfo into MbolDetail CtnCnt1 if storerconfig setup is: 
               -- CAPTURE_PACKINFO = 1  and  MBOLSUMCTNCNT2TOTCTN = 2 or MBOLSUMCTNCNT2TOTCTN = 1
               SET @b_success = 0
               SET @cAuthority = '0'
               SET @nTotalCartons = 0
                  
               EXECUTE nspGetRight null,           -- facility
                        @cStorerkey,              -- Storerkey
                        null,                      -- Sku
                        'CAPTURE_PACKINFO',        -- Configkey
                        @b_success    output,
                        @cAuthority  output, 
                        @n_err        output,
                        @c_errmsg     output

               IF @cAuthority = '1' AND @b_success = 1
               BEGIN
                  SET @b_success = 0
                  SET @cAuthority = '0'
                  EXECUTE nspGetRight null,           -- facility
                           @cStorerkey,              -- Storerkey
                           null,                      -- Sku
                           'MBOLSUMCTNCNT2TOTCTN',    -- Configkey
                           @b_success    output,
                           @cAuthority  output, 
                           @n_err        output,
                           @c_errmsg     output

                  IF (@cAuthority = '1' OR @cAuthority = '2') AND @b_success = 1
                  BEGIN
                     SELECT @nTotalCartons = COUNT(Distinct CartonNo)
                     FROM PACKDETAIL WITH (NOLOCK)
                     JOIN PACKHEADER WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipno)
                     WHERE PACKHEADER.Orderkey = @cOrderkey
                  END
               END

               SELECT @cExternOrderKey = '', @dDelivery_Date = '', @cCustomerName = '', @cInvoiceNo = ''
               SELECT @nStdGrossWgt = 0, @nStdCube = 0

               SELECT 
                  @cExternOrderKey  = ExternOrderKey, 
                  @dDelivery_Date   = DeliveryDate, 
                  @cCustomerName    = C_Company, 
                  @dOrderDate       = OrderDate, 
                  @cInvoiceNo       = InvoiceNo 
               FROM dbo.Orders WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey

               SELECT 
			         @nStdGrossWgt = SUM(OD.OpenQty * SKU.StdGrossWgt),  
			         @nStdCube = SUM(OD.OpenQty * SKU.StdCube) 
               FROM dbo.OrderDetail OD WITH (NOLOCK) 
               JOIN SKU SKU WITH (NOLOCK) ON (OD.SKU = SKU.SKU AND OD.StorerKey = SKU.StorerKey) 
               WHERE OD.StorerKey = @cStorerKey
                  AND OD.OrderKey = @cOrderKey

               INSERT INTO MBOLDETAIL
                  (MBOLKey,            MBOLLineNumber, 
                   OrderKey,           LoadKey, 
                   ExternOrderKey,     DeliveryDate, 
                   Weight,             Cube,
                   Description,        OrderDate,
                   InvoiceNo,          
                   AddWho,             EditWho,
                   TotalCartons,       ctncnt1 )               
               VALUES
                  (@cMBOLKey,          @cMBOLLineNumber,
                   @cOrderKey,         @cLoadKey,
                   @cExternOrderKey,   @dDelivery_Date, 
                   @nStdGrossWgt,      @nStdCube,     
                   @cCustomerName,     @dOrderDate,
                   @cInvoiceNo,        
                   '*' + RTRIM(sUser_sName()), 'rdt' + RTRIM(sUser_sName()), 
                   @nTotalCartons,    @nTotalCartons )       

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 69780
                  SET @cErrMsg = rdt.rdtgetmessage( 69780, @cLangCode, 'DSP') --InsMBOLDetFail
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_2_Fail
               END
               ELSE
               BEGIN
                  -- (james12)
                  SET @cExtendedUpdateSP = ''
                  SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
                  IF @cExtendedUpdateSP NOT IN ('0', '')
                  BEGIN
                     SET @nErrNo = 0
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, ' + 
                        ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                     SET @cSQLParam =    
                        '@nMobile                   INT, '           +
                        '@nFunc                     INT, '           +
                        '@cLangCode                 NVARCHAR( 3), '  +
                        '@nStep                     INT, '           +
                        '@nInputKey                 INT, '           + 
                        '@cStorerkey                NVARCHAR( 15), ' +
                        '@cMbolKey                  NVARCHAR( 10), ' +
                        '@cToteNo                   NVARCHAR( 20), ' +
                        '@cOption                   NVARCHAR( 10), ' +
                        '@cOrderkey                 NVARCHAR( 10), ' +
                        '@nErrNo                    INT           OUTPUT,  ' +
                        '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
                        
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                          @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey,  
                          @nErrNo OUTPUT, @cErrMsg OUTPUT     
                          
                     IF @nErrNo <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 69810  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExtendUpd Fail'  
                        EXEC rdt.rdtSetFocusField @nMobile, 3
                        GOTO Step_2_Fail
                     END
                     ELSE
                        COMMIT TRAN
						/* SOS#205302 Start
                  -- insert to Eventlog
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '16', -- Scan2Van
                     @cUserID       = @cUserName,
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerkey,
                     @cRefNo1       = @cMBOLKey,
                     @cRefNo2       = @cLoadKey,
                     @cRefNo3       = @cOrderKey
                  SOS#205302 End */
                  END
               END
            END

            FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cLoadKey  -- (james06)
         END
         CLOSE CUR_TOTE
         DEALLOCATE CUR_TOTE

         -- (Vicky05) - Start
         -- Release Full PTS Loc
         SELECT @cPTSLoc = DropLOC
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cToteNo

         IF ISNULL(RTRIM(@cPTSLoc), '') <> ''
         BEGIN
          IF EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)
                     WHERE LOC = @cPTSLoc AND LocFull = 'Y')
          BEGIN
               BEGIN TRAN

               UPDATE dbo.StoreToLocDetail WITH (ROWLOCK)
                 SET LocFull = 'N',
                     EditDate = GETDATE(),
                     EditWho = @cUserName
               WHERE LOC = @cPTSLoc
               AND   LocFull = 'Y'

               IF @@Error <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 69781
                  SET @cErrMsg = rdt.rdtgetmessage( 69781, @cLangCode, 'DSP') --UpdStoretoLocFail
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_2_Fail
               END
               ELSE
               BEGIN
                 COMMIT TRAN
               END
          END
         END
         -- (Vicky05) - End
      END

      -- Extended info sp (james16)
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended update
      IF @cExtendedInfoSP <> '' 
      BEGIN
         SET @cMBOLScanCarrier = '0'
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @c_oFieled01 OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cToteNo         NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 20), ' +
               '@cOrderkey       NVARCHAR( 10), ' +
               '@c_oFieled01     NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cMbolKey, @cToteNo, @cOption, @cOrderkey, @c_oFieled01 OUTPUT

            -- Prepare extended fields
            IF @c_oFieled01 <> '' SET @cOutField15 = @c_oFieled01
         END
      END
      
       -- Insert into Pallet, PalletDetail -- (ChewKP03) 
         BEGIN TRAN
         
         
         
         SET @cOtherReference = ''
         SET @cContainerKey   = ''
         
         IF @cPlaceOfLoadingQualifier = 'ECOMM'
         BEGIN
            SET @cOtherReference = 'ECOMM'
            --SET @cUserDefine02   = 'ECOMM'
         END
         ELSE IF @cPlaceOfLoadingQualifier = 'NS'
         BEGIN
            SET @cOtherReference = ''
            --SET @cUserDefine02   = ''
         END
         ELSE 
         BEGIN
            SET @cOtherReference = @cConsigneeKey
            --SET @cUserDefine02   = @cConsigneeKey
         END
         
--         SET @cContainerType = ''
--         SELECT @cContainerType = CASE WHEN UDF01 = 'INDIRECT' THEN UDF01
--                                  ELSE 'DIRECT'
--                                  END
--         FROM dbo.Codelkup WITH (NOLOCK)
--         WHERE LISTNAME = 'PLACEQUAL'
--         AND CODE = @cRoute
--         IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK) 
--                         WHERE MBOLKey = @cMBOLKey ) 
--         BEGIN
--            EXECUTE nspg_GetKey  
--             'ContainerKey',  
--             10,  
--             @cContainerKey  OUTPUT,  
--             @bSuccess    OUTPUT,  
--             @nErrNo      OUTPUT,  
--             @cErrMsg     OUTPUT  
--     
--            IF NOT @bSuccess = 1  
--            BEGIN  
--               GOTO Step_2_Fail  
--            END  
--            
--            INSERT INTO dbo.CONTAINER 
--            (ContainerKey, OtherReference, ContainerType, MBOLKey, Status)
--            VALUES 
--            (@cContainerKey, @cOtherReference, @cContainerType, @cMBOLKey, '0')
--            
--            IF @@ERROR <> 0 
--            BEGIN
--               ROLLBACK TRAN
--               SET @nErrNo = 69798
--               SET @cErrMsg = rdt.rdtgetmessage( 69798, @cLangCode, 'DSP') --InsContainerFail
--               EXEC rdt.rdtSetFocusField @nMobile, 3
--               GOTO Step_2_Fail
--            END
--         END
--         ELSE
--         BEGIN
--            SELECT @cContainerKey = ContainerKey
--            FROM dbo.Container WITH (NOLOCK)
--            WHERE MBOLKey = @cMBOLKey
--            
--         END
--         
--         IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)
--                         WHERE PalletKey = @cPalletID)
--         BEGIN                         
--            INSERT INTO dbo.ContainerDetail 
--            (ContainerKey, ContainerLinenumber, PalletKey)
--            VALUES 
--            (@cContainerKey, 0, @cPalletID)
--   
--            IF @@ERROR <> 0 
--            BEGIN
--               ROLLBACK TRAN
--               SET @nErrNo = 69799
--               SET @cErrMsg = rdt.rdtgetmessage( 69799, @cLangCode, 'DSP') --InsContainerDetFail
--               EXEC rdt.rdtSetFocusField @nMobile, 3
--               GOTO Step_2_Fail
--            END         
--         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                         WHERE PalletKey = @cPalletID)
         BEGIN                     
            IF @cPalletClose = '1'
            BEGIN    
               INSERT INTO dbo.Pallet 
               (PalletKey, StorerKey, Status)
               VALUES 
               (@cPalletID, @cStorerKey, '3')
            END
            ELSE
            BEGIN
                INSERT INTO dbo.Pallet 
               (PalletKey, StorerKey, Status)
               VALUES 
               (@cPalletID, @cStorerKey, '0')
            END
            
            IF @@ERROR <> 0 
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69800
               SET @cErrMsg = rdt.rdtgetmessage( 69800, @cLangCode, 'DSP') --InsPalletFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END         
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                         WHERE PalletKey = @cPalletID
                           AND UserDefine05 = @cToteNo )
         BEGIN                     
            SET @cPalletLoc = ''
            SET @cPalletLoc = rdt.RDTGetConfig( @nFunc, 'PalletLoc', @cStorerKey)
            
            IF @cPalletLoc = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69804
               SET @cErrMsg = rdt.rdtgetmessage( 69804, @cLangCode, 'DSP') --PalletLocNotSetup
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            
            SET @cPalletSKU = ''
            SET @cPalletSKU = rdt.RDTGetConfig( @nFunc, 'PalletSKU', @cStorerKey)
            
            IF @cPalletSKU = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69805
               SET @cErrMsg = rdt.rdtgetmessage( 69804, @cLangCode, 'DSP') --PalletSKUNotSetup
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END
            
            
            IF @cPalletClose = '1'
            BEGIN
               INSERT INTO dbo.PalletDetail
               (PalletKey, StorerKey, PalletLineNumber, Status, CaseID, UserDefine01, UserDefine02, UserDefine03, Loc, SKU, UserDefine04, UserDefine05)
               VALUES 
               (@cPalletID, @cStorerKey, '0', '3', '', @cPalletID, @cNSStore, @cMBOLKey, @cPalletLoc, @cPalletSKU, @cOtherReference, @cToteNo)
            END
            ELSE
            BEGIN
               INSERT INTO dbo.PalletDetail
               (PalletKey, StorerKey, PalletLineNumber, Status, CaseID, UserDefine01, UserDefine02, UserDefine03, Loc, SKU, UserDefine04, UserDefine05)
               VALUES 
               (@cPalletID, @cStorerKey, '0', '0', '', @cPalletID, @cNSStore, @cMBOLKey, @cPalletLoc, @cPalletSKU, @cOtherReference, @cToteNo)
            END
            
            IF @@ERROR <> 0 
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69801
               SET @cErrMsg = rdt.rdtgetmessage( 69801, @cLangCode, 'DSP') --InsPalletDetFail
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail
            END         
         END                  
         COMMIT TRAN
     
      

      --prepare next screen variable
      CLOSEPALLET_NEXTSTEP:
      IF @cPalletClose <> '1' -- (ChewKP03)
      BEGIN
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = @cPlaceOfLoadingQualifier
   
         
--         SELECT @nScanned = COUNT(1)
--         FROM RDT.RDTScanToTruck WITH (NOLOCK) -- KHLim02
--         WHERE MBOLKey = @cMBOLKey
         
         
         SELECT @nScanned = Count (Distinct PD.UserDefine05)
         FROM RDT.RDTScanToTruck RTS WITH (NOLOCK) -- KHLim02
         INNER JOIN PalletDetail PD WITH (NOLOCK) ON RTS.MBOLKey = PD.UserDefine03 
         WHERE RTS.MBOLKey = @cMBOLKey
         AND PD.PalletKey = @cPalletID
         
         
   
         SET @cOutField04 = @nScanned -- KHLim02
      END
      ELSE
      BEGIN
            
            SET @cOutField01 = ''
            SET @cPalletClose = '0'
            
            SET @nScn  = @nScnPallet  
            SET @nStep = @nStepPallet 
            
         
      END         
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      
-- (ChewKP03)      
--      SET @cOutField02 = ''
--      SET @cOutField04 = 0 -- KHLim02

      -- Go back to prev screen
--      SET @nScn  = @nScn - 1
--      SET @nStep = @nStep - 1

      SET @nScn  = @nScnPallet  -- (ChewKP03)
      SET @nStep = @nStepPallet -- (CheWKP03)
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToteNo = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2382
   Nominated Day (Field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cCollection_Date = @cOutField03

      -- Validate blank
      IF ISNULL(@cInField02, '') = ''
      BEGIN
         SET @nErrNo = 69790
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Day req
         GOTO Step_3_Fail
      END

      IF @cOutField01 = 'STANDARD'
      BEGIN
         IF @cInField02 <> '02011970'
         BEGIN
            SET @nErrNo = 69792
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Day
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- Validate weekday
   --      IF @cInField02 NOT IN -- (james10)
   --      ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY', 'TODAY')
         -- The value entered must equal Collection Date in the format ddmmyyyy
         IF rdt.rdtIsRegExMatch('^(0[1-9]|[12][0-9]|3[01])(0[1-9]|1[012])(19|20)\d\d$', @cInField02) = 0
         BEGIN
            SET @nErrNo = 69791
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Day
            GOTO Step_3_Fail
         END

         SET @cInput_Date = SUBSTRING(@cInField02, 1, 2) + '/' + 
                            SUBSTRING(@cInField02, 3, 2) + '/' + 
                            SUBSTRING(@cInField02, 5, 4)
         -- Validate date
         IF RDT.rdtIsValidDate( @cInput_Date) = 0
         BEGIN
            SET @nErrNo = 69793
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Day
            GOTO Step_3_Fail
         END

         -- Validate input vs output
         IF @cInput_Date <> @cCollection_Date
         BEGIN
            SET @nErrNo = 69792
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Day
            GOTO Step_3_Fail
         END
      END

      SET @nScn = @nCurScn
      SET @nStep = @nCurStep
      SET @cOutField03 = ''

      GOTO Continue_Ins_Ecomm_Orders
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = @cPlaceOfLoadingQualifier
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

--      SELECT @nScanned = COUNT(1)
--      FROM RDT.RDTScanToTruck WITH (NOLOCK) -- KHLim02
--      WHERE MBOLKey = @cMBOLKey
      
      -- (ChewKP03)
      SELECT @nScanned = Count (Distinct PD.UserDefine05)
      FROM RDT.RDTScanToTruck RTS WITH (NOLOCK) -- KHLim02
      INNER JOIN PalletDetail PD WITH (NOLOCK) ON RTS.MBOLKey = PD.UserDefine03
      WHERE RTS.MBOLKey = @cMBOLKey
      AND PD.PalletKey = @cPalletID

      SET @cOutField04 = @nScanned -- KHLim02

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField02 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 2383. 
   Pallet / Cage (Field01, Input)
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cPalletID = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cPalletID), '') = ''
      BEGIN
         SET @nErrNo = 69794
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID req
         GOTO Step_4_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) WHERE Status IN ('3','5','9') AND PalletKey = @cPalletID )
      BEGIN
         SET @nErrNo = 69795
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet
         GOTO Step_4_Fail
      END
      
      IF @cPlaceOfLoadingQualifier <> 'NS'
      BEGIN
         
         
         
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = @cRoute
         SET @cOutField03 = ''
         
         SET @nScanned = 0
         
         SELECT @nScanned = ISNULL(Count(Distinct PD.Userdefine05),0)
         FROM RDT.RDTScanToTruck RTS WITH (NOLOCK) -- KHLim02
         INNER JOIN PalletDetail PD WITH (NOLOCK) ON RTS.MBOLKey = PD.UserDefine03
         WHERE RTS.MBOLKey = @cMBOLKey
         AND PD.PalletKey = @cPalletID
   
         SET @cOutField04 = @nScanned -- KHLim02
         SET @cOutfield05 = '' 
         
         
         SET @nScn = @nScnTote
         SET @nStep = @nStepTote
         
         
         
         GOTO QUIT
         
         
      END
      ELSE
      BEGIN
         -- Prepare Next Screen Variable
   		SET @cOutField01 = ''
   		 
   		-- GOTO Next Screen
   		SET @nScn = @nScn + 1
   	   SET @nStep = @nStep + 1
   	   
   	   GOTO QUIT
      END
      
		
	    
	    
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
      
      -- Prepare Next Screen Variable
		SET @cOutField01 = ''
		 
		-- GOTO Next Screen
		SET @nScn = @nScnMBOLKey
	   SET @nStep = @nStepMBOLKey
      
   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cOutField01 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 1
      
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 2384
   Store (Field01, Input)
   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cNSStore  = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cNSStore), '') = ''
      BEGIN
         SET @nErrNo = 69796
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Store req
         GOTO Step_5_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cNSStore
                  And Type = '2' )
      BEGIN
         SET @nErrNo = 69797
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Store
         GOTO Step_5_Fail
      END
      
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = @cRoute
      SET @cOutField03 = ''
            
      SET @nScanned = 0
         
      SELECT @nScanned = ISNULL(Count(Distinct PD.UserDefine05),0)
      FROM RDT.RDTScanToTruck RTS WITH (NOLOCK) -- KHLim02
      INNER JOIN PalletDetail PD WITH (NOLOCK) ON RTS.MBOLKey = PD.UserDefine03
      WHERE RTS.MBOLKey = @cMBOLKey
      AND PD.PalletKey = @cPalletID
      
      SET @cOutField04 = @nScanned 
      SET @cOutfield05 = ''   
        
         
      SET @nScn = @nScnTote
      SET @nStep = @nStepTote
         
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
      
      -- Prepare Next Screen Variable
		SET @cOutField01 = ''
		 
		-- GOTO Next Screen
		SET @nScn = @nScnPallet
	   SET @nStep = @nStepPallet
      
   END
	GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 1
      
   END
END 
GOTO QUIT

/********************************************************************************
Step 6. screen = 2385
   MBOL     (Field01)
   Carrier  (Field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCarrier = @cInField02

      -- Validate blank
      IF ISNULL(RTRIM(@cCarrier), '') = ''
      BEGIN
         SET @nErrNo = 69811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CARRIER req
         GOTO Step_6_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   ListName = 'CarrierTyp'
                      And   Code = @cCarrier )
      BEGIN
         SET @nErrNo = 69812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv CARRIER
         GOTO Step_6_Fail
      END

      SET @cRoute = ''

      SET @cOutField01 = ''

      SET @nScn = @nScnPallet
      SET @nStep = @nStepPallet
   END

	IF @nInputKey = 0 
   BEGIN
      -- Init screen
      SET @nScn  = 2380
      SET @nStep = 1

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @cMBOLKey = ''
   END
	GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 2
      
   END
END
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       -- UserName      = @cUserName,

       V_Lottable04   = @dDeliveryDate,   -- (james08)
       V_ConsigneeKey = @cConsigneekey,
       V_OrderKey     = @cOrderKey,
       V_LoadKey      = @cLoadKey,
       V_PickSlipNo   = @cPickSlipNo,
       V_String1      = @cMBOLKey,
       V_String2      = @cCarrier,  -- (james14)
       V_String3      = @cRoute,
       V_String4      = @cPlaceOfLoadingQualifier,
       V_String5      = @cStatus,
       V_String6      = @nScanned, -- (KHLim02)
       V_String7      = @cStatusPH, -- (KHLim03)
       V_String8      = @cNOMIXORDGROUP,   -- (james04)
       V_String9      = @cOrderGroup, -- (james04)
       V_String10     = @nCurScn,      -- (james08)
       V_String11     = @nCurStep,     -- (james08)
       V_String12     = @cDay,         -- (james08)
       V_String13     = SUBSTRING( @cToteNo, 1, 20),           
       V_String14     = SUBSTRING( @cToteNo, 21, 20), 
       V_String15     = @cPalletID,
       V_String16     = @cNSStore,
       V_String17     = @cPalletClose,
   
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