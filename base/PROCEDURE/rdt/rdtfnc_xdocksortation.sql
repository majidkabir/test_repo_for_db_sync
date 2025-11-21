SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_XDockSortation                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: XDock Sortation (SOS85928)                                  */
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
/* 30-Sep-2016 1.3  Ung      Performance tuning                         */  
/************************************************************************/

CREATE  PROC [RDT].[rdtfnc_XDockSortation] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
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
   @c_errmsg        NVARCHAR( 250),

   @nSKUCnt         INT
  
-- RDT.RDTMobRec variables
DECLARE
   @nFunc           INT,
   @nScn            INT,
   @nStep           INT,
   @cLangCode       NVARCHAR( 3),
   @nInputKey       INT,
   @nMenu           INT,

   @cStorer         NVARCHAR( 15),
   @cUserName       NVARCHAR( 18),
   @cFacility       NVARCHAR( 5),
   @cLOC            NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cSKUDescr       NVARCHAR( 60),

   @cLoadKey        NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cOrderLineNo    NVARCHAR( 5),
   @cConsigneekey   NVARCHAR( 15),
   @cOrdCompany     NVARCHAR( 20),
   @nAllocPickQTY   INT,
   @nTotScanQTY     INT,
   @nScanQTY        INT,
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorer          = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLOC             = V_LOC,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,

   @cLoadKey         = V_String1,
   @cOrderKey        = V_String2,
   @cOrderLineNo     = V_String3,
   @cConsigneeKey  = V_String4,
   @cOrdCompany      = V_String5,
   @nAllocPickQTY    = CASE WHEN rdt.rdtIsValidQTY( V_String6, 0) = 1 THEN V_String6 ELSE 0 END,
   @nTotScanQTY      = CASE WHEN rdt.rdtIsValidQTY( V_String7, 0) = 1 THEN V_String7 ELSE 0 END,
   @nScanQTY         = CASE WHEN rdt.rdtIsValidQTY( V_String8, 0) = 1 THEN V_String8 ELSE 0 END,   

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1570
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0 -- Menu. Func = 1570
   IF @nStep = 1  GOTO Step_1 -- Scn = 1571. LOADKEY
   IF @nStep = 2  GOTO Step_2 -- Scn = 1572. SKU/UPC, SKUDesc, QTY ALLOC+PICK, QTY SCAN, ORDERKEY, CONSIGNEE, COMPANY
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1570. Screen 0.
********************************************************************************/
Step_0:
BEGIN
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

      SET @nScn = 1571
      SET @nStep = 1
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 1571. Screen 1.
   LOADKEY (field01)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01

       -- Retain the key-in value
       SET @cOutField01 = @cLoadKey

      -- Validate Loadkey
      IF @cLoadKey = '' OR @cLoadKey IS NULL
      BEGIN
         SET @nErrNo = 63551
         SET @cErrMsg = rdt.rdtgetmessage( 63551, @cLangCode, 'DSP') -- 'LOADKEY needed'
--          SET @nErrNo = 0 
--          EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg 
--          IF @nErrNo = 1 
--          BEGIN
--             SET @cErrMsg = ''
--          END    
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT TOP 1 LoadKey
                     FROM dbo.LOADPLAN (NOLOCK)
                     WHERE LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 63552
         SET @cErrMsg = rdt.rdtgetmessage( 63552, @cLangCode, 'DSP') -- 'Bad LOADKEY'
--          SET @nErrNo = 0 
--          EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
--          IF @nErrNo = 1 
--             SET @cErrMsg = ''
         GOTO Step_1_Fail
      END
      
      -- Check if Load fully distributed      
      IF NOT EXISTS( SELECT TOP 1 OD.OrderKey
                     FROM dbo.LOADPLANDETAIL LPD (NOLOCK)
                     INNER JOIN dbo.ORDERDETAIL OD (NOLOCK)
                        ON (LPD.LoadKey = OD.LoadKey AND LPD.OrderKey = OD.OrderKey)
                     WHERE LPD.LoadKey = @cLoadKey
                     AND OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
                     AND OD.QtyAllocated + OD.QtyPicked > 0 )
      BEGIN
         SET @nErrNo = 63553
         SET @cErrMsg = rdt.rdtgetmessage( 63553, @cLangCode, 'DSP') -- 'LoadFullyDistr'
--          SET @nErrNo = 0 
--          EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
--          IF @nErrNo = 1 
--             SET @cErrMsg =''
         GOTO Step_1_Fail
      END 

      -- Prepare next screen var
      SET @cOutField01 = '' -- SKU/UPC
      SET @cOutField02 = '' -- SKUDesc1
      SET @cOutField03 = '' -- SKUDesc2
      SET @cOutField04 = '' -- Qty Alloc + Pick
      SET @cOutField05 = '' -- Qty Scan
      SET @cOutField06 = '' -- OrderKey
      SET @cOutField07 = '' -- CongsineeKey
      SET @cOutField08 = '' -- C_Company

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- SKU/UPC
      SET @cOutField02 = '' -- SKUDesc1
      SET @cOutField03 = '' -- SKUDesc2
      SET @cOutField04 = '' -- Qty Alloc + Pick
      SET @cOutField05 = '' -- Qty Scan
      SET @cOutField06 = '' -- OrderKey
      SET @cOutField07 = '' -- CongsineeKey
      SET @cOutField08 = '' -- C_Company

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Loadkey
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 1572. Screen 2.
   SKU/UPC      (field01) - Input field   QTY SCAN  (field05)
   SKUDesc1     (field02)                 ORDERKEY  (field06)
   SKUDesc2     (field03)                 CONSIGNEE (field07)
   QTY ALLOC+PK (field04)                 COMPANY   (field08)
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN    
      -- Screen mapping    
      SET @cSKU = @cInField01

       -- Retain the key-in value
       SET @cOutField01 = @cSKU

      -- Validate SKU
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 63554
         SET @cErrMsg = rdt.rdtgetmessage( 63554, @cLangCode, 'DSP') -- 'SKU required'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''

         GOTO Step_2_Fail
      END

      -- SKU can be barcode in SKU.AltSKU / RetailSKU / ManifacturerSKU / UPC    
      -- Get SKU/UPC
      SELECT 
         @nSKUCnt = COUNT( DISTINCT A.SKU), 
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM 
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU.SKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU.AltSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU.RetailSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU.ManufacturerSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorer AND UPC.UPC = @cSKU
      ) A

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63555
         SET @cErrMsg = rdt.rdtgetmessage( 63555, @cLangCode, 'DSP') -- 'Invalid SKU'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''

         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63556
         SET @cErrMsg = rdt.rdtgetmessage( 63556 , @cLangCode, 'DSP') -- 'MultiSKUBarcod'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''

         GOTO Step_2_Fail
      END      

      SELECT @cSKUDescr = DESCR
      FROM dbo.SKU (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   SKU = @cSKU
      
      SELECT
         @nAllocPickQTY = SUM(QtyAllocated + QtyPicked),
         @nTotScanQTY   = SUM(QtyToProcess)
      FROM dbo.LOADPLANDETAIL LPD (NOLOCK)
      INNER JOIN dbo.ORDERDETAIL OD (NOLOCK)
         ON (LPD.LoadKey = OD.LoadKey AND LPD.OrderKey = OD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
      AND   OD.StorerKey = @cStorer
      AND   OD.SKU = @cSKU
      GROUP BY LPD.LoadKey, OD.StorerKey, OD.SKU
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 63557
         SET @cErrMsg = rdt.rdtgetmessage( 63557 , @cLangCode, 'DSP') -- 'SKU NotOnLoad'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''

         GOTO Step_2_Fail
      END

      -- Get data
      SELECT TOP 1 
         @cOrderKey     = OD.OrderKey,
         @cOrderLineNo  = OD.OrderLineNumber,
         @cConsigneeKey = OH.ConsigneeKey, 
         @cOrdCompany   = OH.C_Company,
         @nScanQTY      = OD.QtyToProcess
      FROM dbo.ORDERS OH (NOLOCK)
      INNER JOIN dbo.ORDERDETAIL OD (NOLOCK)
         ON (OH.OrderKey = OD.OrderKey)
      INNER JOIN dbo.LOADPLANDETAIL LPD (NOLOCK)
         ON (LPD.LoadKey = OD.LoadKey AND LPD.OrderKey = OD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
      AND   OD.StorerKey = @cStorer
      AND   OD.SKU = @cSKU
      AND   OD.QtyAllocated + OD.QtyPicked > OD.QtyToProcess
      ORDER BY OH.Priority, OH.OrderKey, OD.OrderLineNumber -- offset by Order.Priority in ascending seq

      -- If there is no more OrderDetail line
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 63558
         SET @cErrMsg = rdt.rdtgetmessage( 63558 , @cLangCode, 'DSP') -- 'Over scanned'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''
         GOTO REFRESH_QTY
      END

      -- Update Qty
      BEGIN TRAN 

      -- 25-Oct-2007 1.1  Shong    Using TrafficCop with updateing Order Det
      UPDATE dbo.ORDERDETAIL WITH (ROWLOCK)
      SET   QtyToProcess = QtyToProcess + 1, TrafficCop = NULL 
      WHERE OrderKey = @cOrderKey
      AND OrderLineNumber = @cOrderLineNo
      AND SKU = @cSKU
      AND QtyToProcess = @nScanQTY -- If update by other user, fail and refresh qty 

      IF @@ROWCOUNT = 1
         COMMIT TRAN
      ELSE
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 63559
         SET @cErrMsg = rdt.rdtgetmessage( 63559, @cLangCode, 'DSP') -- 'UPD ODtl Fail'
         SET @nErrNo = 0 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         IF @nErrNo = 1 
            SET @cErrMsg =''
         GOTO REFRESH_QTY
      END

      -- Refresh QTY
      REFRESH_QTY:     
      SELECT
         @nAllocPickQTY = SUM(QtyAllocated + QtyPicked),
         @nTotScanQTY   = SUM(QtyToProcess)
      FROM dbo.LOADPLANDETAIL LPD (NOLOCK)
      INNER JOIN dbo.ORDERDETAIL OD (NOLOCK)
         ON (LPD.LoadKey = OD.LoadKey AND LPD.OrderKey = OD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
      AND   OD.StorerKey = @cStorer
      AND   OD.SKU = @cSKU
      GROUP BY LPD.LoadKey, OD.StorerKey, OD.SKU

      -- If error, clear 
      IF @nErrNo <> 0
      BEGIN
         SET @cOrderKey     = ''
         SET @cConsigneekey = ''
         SET @cOrdCompany   = ''
      END

      -- Retain the key-in value
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)
      SET @cOutField04 = CAST( @nAllocPickQTY AS NVARCHAR( 5))
      SET @cOutField05 = CAST( @nTotScanQTY AS NVARCHAR( 5))
      SET @cOutField06 = @cOrderKey
      SET @cOutField07 = @cConsigneekey
      SET @cOutField08 = @cOrdCompany
      
      -- Prepare next screen var
      SET @cOutField01 = ''

      -- Loop at current screen
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- LoadKey

      -- Back to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- SKU/UPC
      SET @cOutField02 = '' -- SKUDesc1
      SET @cOutField03 = '' -- SKUDesc2
      SET @cOutField04 = '' -- Qty Alloc + Pick
      SET @cOutField05 = '' -- Qty Scan
      SET @cOutField06 = '' -- OrderKey
      SET @cOutField07 = '' -- CongsineeKey
      SET @cOutField08 = '' -- C_Company
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
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
      
      V_LOC          = @cLOC,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
   
      V_String1      = @cLoadKey,
      V_String2      = @cOrderKey,
      V_String3      = @cOrderLineNo,
      V_String4      = @cConsigneeKey,
      V_String5      = @cOrdCompany,
      V_String6      = @nAllocPickQTY, 
      V_String7      = @nTotScanQTY,
      V_String8      = @nScanQTY, 

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
      I_Field15 = '',  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile  
END

GO