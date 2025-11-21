SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_Pick_Consolidation                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick consolidation                                          */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 17-Mar-2014 1.0  James    SOS304122 - Created                        */
/* 10-Nov-2014 1.1  James    Perfomance tuning (james01)                */
/* 05-Jan-2015 1.2  James    Set focus on orderkey field (james02)      */
/* 30-Sep-2016 1.3  Ung      Performance tuning                         */
/* 12-Nov-2018 1.4  TungGH   Performance                                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pick_Consolidation] (
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

DECLARE
   @cSQL          NVARCHAR(1000),     
   @cSQLParam     NVARCHAR(1000)    
   
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

   @cOrderKey           NVARCHAR( 10),
   @cPickZone           NVARCHAR( 10),
   @cFinalLOC           NVARCHAR( 10),
   @cPrinter            NVARCHAR( 10),
   @cPrinter_Paper      NVARCHAR( 10), 
   @nPickZone_Cnt       INT, 
   @nTranCount          INT, 
   @nQty_Picked         INT, 
   @nQty_Packed         INT, 
   @cPickSlipNo         NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cWaveKey            NVARCHAR( 10),
   @cShipperKey         NVARCHAR( 15),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),     
   @cExtendedInfo       NVARCHAR( 20),     


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
   @cPrinter_Paper   = Printer_Paper, 

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cOrderKey        = V_OrderKey, 
   @cLOC             = V_LOC, 
   @cSKU             = V_SKU,

   @cPickZone        = V_String1, 
   @cFinalLOC        = V_String2, 
   
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

IF @nFunc = 544
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0    -- Menu. Func = 544
   IF @nStep = 1  GOTO Step_1    -- Scn = 3790. ORDERKEY, PICKZONE
   IF @nStep = 2  GOTO Step_2    -- Scn = 3791. SUGGESTED LOC, FINAL LOC
   IF @nStep = 3  GOTO Step_3    -- Scn = 3792. MESSAGE
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 544. Screen 0.
********************************************************************************/
Step_0:
BEGIN
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

   -- Prev next screen var
   SET @cOrderKey = ''
   SET @cPickZone = ''

   SET @cOutField01 = ''
   SET @cOutField02 = ''

   SET @nScn = 3790
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1  -- orderkey (james01)
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 3790. Screen 1.
   Order Key   (field01)   - Input field
   Pick Zone   (field02)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOrderKey = @cInField01   
      SET @cPickZone = @cInField02   
      
      -- Validate blank
      IF ISNULL(@cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 85901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDERS needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_OrderKey_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   OrderKey = @cOrderKey)
      BEGIN
         SET @nErrNo = 85902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID ORDERS
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_OrderKey_Fail
      END

/*
      IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   OrderKey = @cOrderKey
                      AND   [Status] >= '5')
      BEGIN
         SET @nErrNo = 85903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER PACKED
         GOTO Step_1_OrderKey_Fail
      END
*/

      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cWaveKey = ''

      SELECT @cLoadKey = LoadKey, 
             @cWaveKey = UserDefine09  
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey

      SELECT @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

      IF ISNULL( @cPickSlipNo, '') = ''
      BEGIN
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey  
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE ExternOrderKey = @cLoadKey
      END

      IF ISNULL( @cPickSlipNo, '') = ''
      BEGIN
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey  
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE WaveKey = @cWaveKey
      END

      IF ISNULL( @cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 85914
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO PICKSLIP
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_OrderKey_Fail
      END

      SET @nQty_Picked = 0
      SET @nQty_Packed = 0
/*    -- (james01)
      IF ISNULL( @cWaveKey, '') <> '' 
         SELECT @nQty_Picked = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
         WHERE O.StorerKey = @cStorerKey
         AND   O.UserDefine09 = @cWaveKey
         AND   O.Status >= '1'
         AND   O.Status < '9'

      IF @nQty_Picked = 0 
         SELECT @nQty_Picked = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
         WHERE O.StorerKey = @cStorerKey
         AND   O.LoadKey = @cLoadKey
         AND   O.Status >= '1'
         AND   O.Status < '9'
*/
      IF ISNULL( @cWaveKey, '') <> '' 
         SELECT @nQty_Picked = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
         WHERE O.StorerKey = @cStorerKey
         AND   O.UserDefine09 = @cWaveKey
         AND   O.Status >= '1'
         AND   O.Status < '9'
      ELSE
         SELECT @nQty_Picked = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
         WHERE O.StorerKey = @cStorerKey
         AND   O.LoadKey = @cLoadKey
         AND   O.Status >= '1'
         AND   O.Status < '9'
         
      SELECT @nQty_Packed = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   StorerKey = @cStorerKey

      IF @nQty_Packed >= @nQty_Picked
      BEGIN
         SET @nErrNo = 85903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER PACKED
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_OrderKey_Fail
      END

      -- Check if this Orders + PkZone picked
      IF EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                  AND   [Status] = '9')
      BEGIN
         SET @nErrNo = 85915
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER PICKED 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_PickZone_Fail
      END

      -- Validate blank
      IF ISNULL(@cPickZone, '') = ''
      BEGIN
         SET @nErrNo = 85904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PICKZONE REQ
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_PickZone_Fail
      END

      SET @nPickZone_Cnt = 0
      SELECT @nPickZone_Cnt = COUNT( DISTINCT LOC.PickZone)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.OrderKey = @cOrderKey
      -- AND   LOC.PickZone = @cPickZone

      -- 1 orders must have 2 diff pickzone
      IF @nPickZone_Cnt <=1 
      BEGIN
         SET @nErrNo = 85905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV ORD 4 ZONE 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_PickZone_Fail
      END

      -- 0 = Initial
      -- 3 = In progress
      -- 5 = Order + PKZone scanned
      -- 9 = Order fully scanned
      -- Check if orders + pkzone scanned b4
      IF EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                  AND   PickZone = @cPickZone
                  AND   [Status] = '5') -- PickZone Scanned  
      BEGIN
         SET @nErrNo = 85916
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKZone PICK 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_PickZone_Fail
      END

      -- Check if PKZone exists within orders
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                      JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
                      WHERE PD.StorerKey = @cStorerKey
                      AND   PD.OrderKey = @cOrderKey
                      AND   LOC.PickZone = @cPickZone)
      BEGIN
         SET @nErrNo = 85917
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID PKZone 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_PickZone_Fail
      END

      -- 1st orderkey detected then get the 1st empty loc 
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtPickConsoLog WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
      BEGIN
         -- Look for LOC not in LotxLocxID 1st
         SELECT TOP 1 @cLOC = LOC.LOC 
         FROM dbo.LOC LOC WITH (NOLOCK, INDEX=IX_LOC_Facility) -- (james01)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationCategory = 'SORTING'
         AND   NOT EXISTS ( SELECT 1 FROM LotxLocxID LLI WITH (NOLOCK) WHERE LOC.LOC = LLI.LOC)
         AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) 
                            WHERE rpc.Status < '9'
                            AND   LOC.LOC = rpc.LOC)

         -- Then look for empty LOC in LotxLocxID
         IF ISNULL( @cLOC, '') = ''
            SELECT TOP 1 @cLOC = LOC.LOC 
            FROM dbo.LOC LOC WITH (NOLOCK, INDEX=IX_LOC_Facility) 
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationCategory = 'SORTING'
            GROUP BY LOC.LOC
            HAVING SUM( Qty - QtyAllocated - QtyPicked) = 0 -- (james01)
            --AND   (Qty - QtyAllocated - QtyPicked - QtyReplen) = 0
            -- Not in use by other orders
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) 
                             WHERE rpc.Status < '9'
                              AND  LOC.LOC = rpc.LOC)

         IF ISNULL( @cLOC, '') = ''
         BEGIN
            SET @nErrNo = 85906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO SUGGEST LOC 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_PickZone_Fail
         END

         SELECT TOP 1 @cSKU = PD.SKU 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.OrderKey = @cOrderKey
         AND   LOC.PickZone = @cPickZone
         AND NOT EXISTS (SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) WHERE PD.OrderKey = rpc.OrderKey AND PD.SKU = rpc.SKU AND rpc.Status < '9')
         ORDER BY 1
         
      END
      ELSE
      BEGIN
         SELECT TOP 1 @cLOC = LOC 
         FROM rdt.rdtPickConsoLog WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   [Status] < '9'

         SELECT TOP 1 @cSKU = PD.SKU 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.OrderKey = @cOrderKey
         AND   LOC.PickZone = @cPickZone
         AND NOT EXISTS (SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) WHERE PD.OrderKey = rpc.OrderKey AND PD.SKU = rpc.SKU AND rpc.Status < '9')
         ORDER BY 1
      END

      SET @nTranCount = @@TRANCOUNT  
         
      BEGIN TRAN  
      SAVE TRAN rdtPickConsoLog_Insert  

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog WITH (NOLOCK) 
                      WHERE OrderKey = @cOrderKey
                      AND   PickZone = @cPickZone)
      BEGIN
         INSERT INTO rdt.rdtPickConsoLog (Orderkey, PickZone, SKU, LOC, [Status], AddWho, AddDate, Mobile) VALUES 
         (@cOrderKey, @cPickZone, @cSKU, @cLOC, '1', sUser_sName(), GETDATE(), @nMobile)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_Insert
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_Insert  

            SET @nErrNo = 85907 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLOG FAIL 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END
      END

      WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
         COMMIT TRAN rdtPickConsoLog_Insert  
            
      -- Prep next screen var
      SET @cOutField01 = @cOrderKey    -- ORDERS
      SET @cOutField02 = @cPickZone    -- PICK ZONE
      SET @cOutField03 = @cLOC         -- SUGGESTED LOC 
      SET @cOutField04 = ''            -- FINAL LOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1


   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Delete all temp record which not confirm
      DELETE FROM rdt.rdtPickConsoLog 
      WHERE OrderKey = @cOrderKey
      AND   [Status] < '5'

      -- Reset this screen var
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cOutField02 = ''
      SET @cOrderKey = ''
      SET @cPickZone = ''

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

   Step_1_OrderKey_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''
      SET @cOutField02 = @cPickZone

      SET @cOrderKey = ''
--      EXEC rdt.rdtSetFocusField @nMobile, 1   -- OrderKey
   END

   Step_1_PickZone_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = ''

      SET @cPickZone = ''
--      EXEC rdt.rdtSetFocusField @nMobile, 2   -- Pick Zone
   END
   
   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cPickZone

--      EXEC rdt.rdtSetFocusField @nMobile, 1   -- OrderKey
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 3791. Screen 2.
   ORDERKEY          (field01)   
   PICKZONE          (field02)   
   SUGGESTED LOC     (field03)   
   FINAL LOC         (field04)   - Input field
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField04

      IF ISNULL(@cFinalLOC, '') = ''
      BEGIN
         SET @nErrNo = 85908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Final LOC req'
         GOTO Step_2_Fail
      END      

      IF @cFinalLOC <> @cLOC
      BEGIN
         SET @nErrNo = 85909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC NOT MATCH'
         GOTO Step_2_Fail
      END      

      -- Status 1 = Init; 3 = In progress ; 5 = Complete pick  ; 9 = LOC release
      SET @nTranCount = @@TRANCOUNT  
         
      BEGIN TRAN  
      SAVE TRAN rdtPickConsoLog_UPD  

      UPDATE rdt.rdtPickConsoLog WITH (ROWLOCK) SET 
         Status = '3'
      WHERE OrderKey = @cOrderKey
      AND   PickZone = @cPickZone
      AND   LOC = @cLOC
      AND   [Status] = '1'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN rdtPickConsoLog_UPD
         WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
            COMMIT TRAN rdtPickConsoLog_UPD  

         SET @nErrNo = 85910 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLOG FAIL 
         GOTO Step_2_Fail
      END

      -- Decide where to go
      -- If it is not the last piece of the goods then show screen 1
      -- If it is last piece then show screen 3
--      IF EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) 
--                  WHERE NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
--                                     WHERE rpc.OrderKey = PD.OrderKey
--                                     AND   rpc.SKU = PD.SKU)
--                  AND [Status] = '3')
      -- If still have other pickzone not yet go thru this process then show screen 1 else screen 3
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC 
                  WHERE OrderKey = @cOrderKey
                  AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog rpc WITH (NOLOCK) 
                                     WHERE rpc.OrderKey = PD.OrderKey
                                     AND   rpc.PickZone  = LOC.PickZone)  )
      BEGIN
         UPDATE dbo.Orders WITH (ROWLOCK) SET 
            Door = @cFinalLOC 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_UPD
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_UPD  

            SET @nErrNo = 85911 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DOOR FAIL 
            GOTO Step_2_Fail
         END

         -- Confirm pick for this zone
         UPDATE rdt.rdtPickConsoLog WITH (ROWLOCK) SET 
            Status = '5'
         WHERE OrderKey = @cOrderKey
         AND   PickZone = @cPickZone
         AND   LOC = @cLOC
         AND   [Status] = '3'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_UPD
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_UPD  

            SET @nErrNo = 85912 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLOG FAIL 
            GOTO Step_2_Fail
         END

         -- Print label
         -- Print only if rdt report is setup 
         IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)                     
                    WHERE StorerKey = @cStorerKey                    
                    AND   ReportType = 'SHIPPLABEL')
         BEGIN
            -- Only print once
            IF NOT EXISTS ( SELECT 1 
                            FROM rdt.rdtPickConsoLog WITH (NOLOCK) 
                            WHERE OrderKey = @cOrderKey
                            AND   LabelPrinted = '1')
            BEGIN
               SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),     
                      @cShipperKey = ISNULL(RTRIM(ShipperKey), '')    
               FROM dbo.Orders WITH (NOLOCK)    
               WHERE Storerkey = @cStorerkey
               AND   Orderkey = @cOrderkey    

               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
               FROM RDT.RDTReport WITH (NOLOCK)  
               WHERE StorerKey = @cStorerkey  
               AND ReportType = 'SHIPPLABEL'   

               SET @cExtendedInfo = ''
               
               -- Extended info   
               SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
               IF @cExtendedInfoSP = '0'    
                  SET @cExtendedInfoSP = ''    
               IF @cExtendedInfoSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cOrderKey, @cPickZone, @cSuggestedLOC, @cFinalLoc, @cExtendedInfo OUTPUT'    
                     SET @cSQLParam =   
                        '@nMobile         INT,       '     +
                        '@nFunc           INT,       '     +
                        '@cLangCode       NVARCHAR( 3),  ' +
                        '@nStep           INT,       '     + 
                        '@nInputKey       INT,       '     +
                        '@cStorerKey      NVARCHAR( 15), ' +
                        '@cOrderKey       NVARCHAR( 10), ' +    
                        '@cPickZone       NVARCHAR( 10), ' +    
                        '@cSuggestedLOC   NVARCHAR( 10), ' +    
                        '@cFinalLoc       NVARCHAR( 10), ' +      
                        '@cExtendedInfo   NVARCHAR( 20) OUTPUT ' 
                         
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cOrderKey, @cPickZone, @cLOC, @cFinalLoc, @cExtendedInfo OUTPUT 
                  END    
               END    
               
               
               SET @nErrNo = 0                    
               EXEC RDT.rdt_BuiltPrintJob                     
                  @nMobile,                    
                  @cStorerKey,                    
                  'SHIPPLABEL',                    
                  'PRINT_SHIPLABEL',                    
                  @cDataWindow,                    
                  @cPrinter,                    
                  @cTargetDB,                    
                  @cLangCode,                    
                  @nErrNo  OUTPUT,                     
                  @cErrMsg OUTPUT,                    
                  @cLoadKey,                    
                  @cOrderKey, 
                  @cShipperKey,
                  @cExtendedInfo 

               IF @nErrNo <> 0                    
               BEGIN                    
                  ROLLBACK TRAN rdtPickConsoLog_UPD
                  WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
                     COMMIT TRAN rdtPickConsoLog_UPD  

--                  SET @nErrNo = 85918 
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PRT LABEL FAIL 
                  GOTO Step_2_Fail
               END
               ELSE
               BEGIN
                  -- Update LabelPrinted flag
                  UPDATE rdt.rdtPickConsoLog WITH (ROWLOCK) SET 
                     LabelPrinted = '1'
                  WHERE OrderKey = @cOrderKey
                  AND   [Status] = '5'
                  AND   LabelPrinted = '0'

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN rdtPickConsoLog_UPD
                     WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
                        COMMIT TRAN rdtPickConsoLog_UPD  

                     SET @nErrNo = 85920 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PRT LABEL FAIL 
                     GOTO Step_2_Fail
                  END
               END
            END   
         END

         -- Print report
         -- Print only if rdt report is setup 
         IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)                     
                    WHERE StorerKey = @cStorerKey                    
                    AND   ReportType = 'DELNOTES')
         BEGIN
            -- Only print once
            IF NOT EXISTS ( SELECT 1 
                            FROM rdt.rdtPickConsoLog WITH (NOLOCK) 
                            WHERE OrderKey = @cOrderKey
                            AND   ReportPrinted = '1')
            BEGIN
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
               FROM RDT.RDTReport WITH (NOLOCK)  
               WHERE StorerKey = @cStorerkey  
               AND ReportType = 'DELNOTES'   
                   
               SET @nErrNo = 0                    
               EXEC RDT.rdt_BuiltPrintJob                     
                  @nMobile,                    
                  @cStorerKey,                    
                  'DELNOTES',                    
                  'PRINT_DELIVERYNOTES',                    
                  @cDataWindow,                    
                  @cPrinter_Paper,                    
                  @cTargetDB,                    
                  @cLangCode,                    
                  @nErrNo  OUTPUT,                     
                  @cErrMsg OUTPUT,                    
                  @cOrderKey, 
                  ''

               IF @nErrNo <> 0                    
               BEGIN                    
                  ROLLBACK TRAN rdtPickConsoLog_UPD
                  WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
                     COMMIT TRAN rdtPickConsoLog_UPD  

--                  SET @nErrNo = 85919 
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PRINT RPT FAIL 
                  GOTO Step_2_Fail
               END   
               ELSE
               BEGIN
                  -- Update ReportPrinted flag
                  UPDATE rdt.rdtPickConsoLog WITH (ROWLOCK) SET 
                     ReportPrinted = '1'
                  WHERE OrderKey = @cOrderKey
                  AND   [Status] = '5'
                  AND   ReportPrinted = '0'

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN rdtPickConsoLog_UPD
                     WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
                        COMMIT TRAN rdtPickConsoLog_UPD  

                     SET @nErrNo = 85921 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PRT RPT FAIL 
                     GOTO Step_2_Fail
                  END
               END
            END
         END
         
         -- Prepare prev screen variable
         SET @cOrderKey = ''
         SET @cPickZone = ''

         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- Go back screen 1
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         EXEC rdt.rdtSetFocusField @nMobile, 1  -- orderkey (james02)
      END
      ELSE
      BEGIN
         -- Confirm all picking when it is last PKZone
         UPDATE rdt.rdtPickConsoLog WITH (ROWLOCK) SET 
            Status = '9'
         WHERE OrderKey = @cOrderKey
         AND   LOC = @cLOC

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_UPD
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_UPD  

            SET @nErrNo = 85913 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLOG FAIL 
            GOTO Step_2_Fail
         END

         SET @cOutField01 = @cOrderKey

         -- Go to screen 3
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
         COMMIT TRAN rdtPickConsoLog_UPD 
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Delete all temp record which not confirm
      DELETE FROM rdt.rdtPickConsoLog 
      WHERE OrderKey = @cOrderKey
      AND   [Status] < '5'

      -- Prepare prev screen variable
      SET @cOrderKey = ''
      SET @cPickZone = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- Go back screen 1
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1  -- orderkey (james02)
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cLOC
      SET @cOutField04 = ''
   END
END
GOTO Quit

/************************************************************************************
Step_3. Scn = 3792. Screen 3.
   Message
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey IN ( 1, 0) -- Yes or No
   BEGIN
      -- Prepare prev screen variable
      SET @cOrderKey = ''
      SET @cPickZone = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- Go back screen 1
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      EXEC rdt.rdtSetFocusField @nMobile, 1  -- orderkey (james02)
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
      Printer_Paper  = @cPrinter_Paper,
      
      V_OrderKey     = @cOrderKey, 
      V_LOC          = @cLOC, 
      V_SKU          = @cSKU,

      V_String1      = @cPickZone,
      V_String2      = @cFinalLOC,
      
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