SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PalletLoading                                */
/* Copyright      : Unilever                                            */
/*                                                                      */
/* Purpose: Putaway to pack and hold                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-08-15 1.0  CYU027   UWP-12109 - Created                         */
/* 2024-10-08 1.1  Dennis   FCR-867 New work flow                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_PalletLoading] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc                  INT,
   @nScn                   INT,
   @nStep                  INT,
   @cLangCode              NVARCHAR( 3),
   @nInputKey              INT,
   @nMenu                  INT,
   @cStatus                NVARCHAR( 10),
   @cOrderKey              NVARCHAR( 10),
   @cLot                   NVARCHAR( 10),
   @cLoc                   NVARCHAR( 10),
   @cID                    NVARCHAR( 18),
   @cPackKey               NVARCHAR(10),

   @cStorerKey             NVARCHAR( 15),
   @cFacility              NVARCHAR( 5),
   @cUserName              NVARCHAR( 18),
   @cOption                NVARCHAR( 1),
   @cQty                   NVARCHAR( 10),
   @cQty_bal               NVARCHAR( 10),
   @cAltSku                NVARCHAR( 20),
   @cSku                   NVARCHAR( 20),
   @cSkuPallet1            NVARCHAR( 20),
   @cSkuPallet2            NVARCHAR( 20),
   @cSkuPallet3            NVARCHAR( 20),
   @cSkuPallet4            NVARCHAR( 20),
   @cSkuPallet5            NVARCHAR( 20),
   @cDefaultOptSCN1        NVARCHAR( 20),
   @cDefaultScanOrder      NVARCHAR( 20),
   @cPalletType            NVARCHAR( 20),

   @cSQL                   NVARCHAR(MAX),
   @cSQLParam              NVARCHAR(MAX),
   @nTranCount             INT,


   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @cOrderKey  = V_OrderKey,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cAltSku       = V_String1,
   @cDefaultOptSCN1 = V_String2,
   @cPalletType   = V_String3,
   @cQTY          = V_String4,
   @cSkuPallet1   = V_String11,
   @cSkuPallet2   = V_String12,
   @cSkuPallet3   = V_String13,
   @cSkuPallet4   = V_String14,
   @cSkuPallet5   = V_String15,


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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant  
DECLARE  
   @nStep_ScanOrder        INT,  @nScn_ScanOrder         INT,  
   @nStep_PalletType       INT,  @nScn_PalletType        INT,  
   @nStep_QTY              INT,  @nScn_QTY               INT,  
   @nStep_AddLP            INT,  @nScn_AddLP             INT,  
   @nStep_AddMoreLP        INT,  @nScn_AddMoreLP         INT
SELECT  
   @nStep_ScanOrder        = 5,  @nScn_ScanOrder        = 6424,  
   @nStep_PalletType       = 6,  @nScn_PalletType       = 6425,  
   @nStep_QTY              = 7,  @nScn_QTY              = 6426,  
   @nStep_AddLP            = 8,  @nScn_AddLP            = 6427,  
   @nStep_AddMoreLP        = 9,  @nScn_AddMoreLP        = 6428
  
-- Redirect to respective screen
   IF @nFunc = 1668
      BEGIN
         IF @nStep = 0 GOTO Step_0   -- Func = 1668. Menu
         IF @nStep = 1 GOTO Step_1   -- Scn  = 6420. Chose 1 or 2
         IF @nStep = 2 GOTO Step_2   -- Scn  = 6421. Order Number
         IF @nStep = 3 GOTO Step_3   -- Scn  = 6422. Chose Pallets
         IF @nStep = 4 GOTO Step_4   -- Scn  = 6423. Enter Quantity
         IF @nStep = 5 GOTO Step_5   -- Scn  = 6424. Scan Order
         IF @nStep = 6 GOTO Step_6   -- Scn  = 6425. Choose Pallet Type
         IF @nStep = 7 GOTO Step_7   -- Scn  = 6426. Qty
         IF @nStep = 8 GOTO Step_8   -- Scn  = 6427. Confirmation
         IF @nStep = 9 GOTO Step_9   -- Scn  = 6428. Add More LP
      END
   RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1668. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN

   SET @cDefaultOptSCN1 = rdt.RDTGetConfig( @nFunc, 'DefaultOptSCN1', @cStorerKey)
   IF @cDefaultOptSCN1 = '0'
      SET @cDefaultOptSCN1 = ''
   
   SET @cDefaultScanOrder = rdt.RDTGetConfig( @nFunc, 'ScanOrder', @cStorerKey)

   EXEC RDT.rdt_STD_EventLog
        @cActionType = '1', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerKey,
        @nStep       = @nStep

   -- Enable all fields
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

   SET @cOrderKey = ''
   IF @cDefaultScanOrder = '1'
   BEGIN
      SET @cOutField01 = ''
      SET @nScn = @nScn_ScanOrder
      SET @nStep = @nStep_ScanOrder
      GOTO Quit
   END
   -- Set the entry point
   SET @cOutField01 = @cDefaultOptSCN1
   SET @nScn = 6420
   SET @nStep = 1
END
   GOTO Quit


/********************************************************************************
Step 1. Scn = 3360
   1. Scan Order Number
      OPTION: (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cOption = @cInField01

         IF ( @cInField01 <> '1' )
         BEGIN
            SET @nErrNo = 221251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OPTION
            GOTO Step_1_Fail
         END

         IF @cInField01 = '1'
         BEGIN
            SET @cOutField01 = '' -- OrderKey
            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END

      END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '9', -- Sign Out function
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerKey,
           @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:

END
   GOTO Quit


/********************************************************************************
Step 2. Scn = 6421
   OrderKey             (field01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOrderKey = @cInField01

      IF ISNULL(@cOrderKey,'') = ''
      BEGIN
         SET @nErrNo = 221253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need OrderKey
         GOTO Step_2_Fail
      END

      SELECT
         @cStatus = STATUS
      FROM ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 221254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Order
         GOTO Step_2_Fail
      END

      -- Only order picked, can load pallet
      IF ISNULL(@cStatus,'') <> '5'
      BEGIN
         SET @nErrNo = 221255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order Picked
         GOTO Step_2_Fail
      END

      DECLARE @skuHU TABLE (Pallet NVARCHAR( 20), RowRef INT IDENTITY(1,1) NOT NULL)

      INSERT INTO @skuHU (Pallet)
      SELECT TOP 5
         ALTSKU FROM SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = @cStorerKey
        AND SKU.SKUGROUP = 'HU'
      ORDER BY ALTSKU

      SELECT @cSkuPallet1 = Pallet FROM @skuHU WHERE RowRef = 1
      SELECT @cSkuPallet2 = Pallet FROM @skuHU WHERE RowRef = 2
      SELECT @cSkuPallet3 = Pallet FROM @skuHU WHERE RowRef = 3
      SELECT @cSkuPallet4 = Pallet FROM @skuHU WHERE RowRef = 4
      SELECT @cSkuPallet5 = Pallet FROM @skuHU WHERE RowRef = 5

      IF ISNULL(@cSkuPallet1, '') = ''
      BEGIN
         SET @nErrNo = 221256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoPalletSKU'
         GOTO Step_1_Fail
      END

      IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
      IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
      IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
      IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
      IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5


      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen variable
      SET @cOrderKey = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOrderKey = ''
   END
END
   GOTO Quit


/********************************************************************************
Step 3. scn = 6422
      Chose Pallets
      Pallet 1       (field01)
      Pallet 2       (field02)
      Pallet 3       (field03)
      Pallet 4       (field04)
      Pallet 5       (field05)
      OPTION:        (field06 INPUT)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @dFlag int
      IF @cInField06 NOT IN ('1','2','3','4','5')
      BEGIN
         SET @dFlag = 1
      END
      ELSE
      BEGIN
         SET @cSql =
              'IF @cSkuPallet' + @cInField06 + ' <> '''' '
            + '  SET @cAltSku = @cSkuPallet' + @cInField06 +' '
            + 'ELSE '
            + '  SET @dFlag = 1'

         SET @cSQLParam =
                 '@cSkuPallet1      NVARCHAR( 60),      ' +
                 '@cSkuPallet2      NVARCHAR( 60),      ' +
                 '@cSkuPallet3      NVARCHAR( 60),      ' +
                 '@cSkuPallet4      NVARCHAR( 60),      ' +
                 '@cSkuPallet5      NVARCHAR( 60),      ' +
                 '@cAltSku          NVARCHAR( 20) OUTPUT,'+
                 '@dFlag            INT           OUTPUT'

         EXEC sp_ExecuteSQL @cSql, @cSQLParam,
              @cSkuPallet1, @cSkuPallet2,
              @cSkuPallet3, @cSkuPallet4,
              @cSkuPallet5, @cAltSku OUTPUT, @dFlag OUTPUT
      END

      IF @dFlag = 1
      BEGIN
         SET @nErrNo = 221257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidAltSKU
         GOTO Step_3_Fail
      END

      SET @cOutField01 = @cAltSku;
      SET @cOutField02 = '';
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cAltSku = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 6423
   Enter XXX Quantity:
   OPTION: (field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cQty = @cInField02

      IF ISNULL(@cQty, '') = ''
      BEGIN
         SET @nErrNo = 221259
         SET @cErrMsg = rdt.rdtgetmessage( 221259, @cLangCode, 'DSP') --NeedQty
         GOTO Step_4_Fail
      END

      IF @cQty <> '' AND RDT.rdtIsValidQTY( @cQty, 1) = 0 -- Check for zero qty
      BEGIN
         SET @nErrNo = 221258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Step_4_Fail
      END

      SELECT @cQty_bal = SUM(LLI.qty-LLI.qtyallocated-LLI.qtypicked),
             @cSku     = LLI.SKU,
             @cLoc     = LLI.Loc,
             @cPackKey = SKU.PACKKey
      FROM LOTxLOCxID LLI WITH(NOLOCK)
              INNER JOIN SKU WITH(NOLOCK) ON SKU.Sku = LLI.Sku
      WHERE SKU.ALTSKU = @cAltSku
        AND LLI.StorerKey = @cStorerKey
      GROUP BY LLI.SKU, LLI.Loc, SKU.PACKKey

      IF ISNULL(@cQty_bal,'0') = '0' OR (CAST(@cQty as INT) > CAST (@cQty_bal as INT))
      BEGIN
         SET @nErrNo = 221260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYUnavailable
         GOTO Step_4_Fail
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PalletLoading-- For rollback or commit only our own transaction

      /*-------------------------------------------------------------------------------

                                  OrderDetail

      -------------------------------------------------------------------------------*/
      DECLARE @cOrderLineNumber NVARCHAR(5)
      DECLARE @cExternLineNo NVARCHAR(20)
      DECLARE @cExternOrderKey NVARCHAR(50)


      -- Get next OrderLineNumber
      SELECT @cOrderLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( OrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5),
             @cExternLineNo = (CAST(ISNULL(MAX(ExternLineNo),0) AS INT)) +1,
             @cExternOrderKey = MAX(ExternOrderKey)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      INSERT INTO OrderDetail
      (OrderKey, OrderLineNumber,ExternOrderKey, ExternLineNo, StorerKey, SKU, OpenQty, QtyPicked, Enteredqty,
       UOM, LoadKey, PackKey, Facility, MBOLKey, Status)
      SELECT TOP 1
      @cOrderKey, @cOrderLineNumber,@cExternOrderKey,@cExternLineNo, StorerKey, @cSku, @cQty, 0, @cQty,
       'EA', LoadKey, @cPackKey, Facility, MBOLKey, '5'
         FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF @@ERROR <> 0
      BEGIN
         GOTO RollBackTran
      END


      /*-------------------------------------------------------------------------------
                                  PickDetail
      -------------------------------------------------------------------------------*/
      DECLARE @c_NewPickDetailKey     NVARCHAR(10) = ''
      DECLARE @b_success              INT
      DECLARE @nQtyNeedPicking        INT
      DECLARE @nLLIQty                INT
      DECLARE @nPickDetailQty         INT

      --START Picking
      SET @nQtyNeedPicking = @cQty

      WHILE ( @nQtyNeedPicking > 0)
      BEGIN

         EXECUTE dbo.nspg_GetKey
                 'PICKDETAILKEY',
                 10 ,
                 @c_NewPickDetailKey  OUTPUT,
                 @b_success        OUTPUT,
                 @nErrNo            OUTPUT,
                 @cErrMsg         OUTPUT

         IF @b_success <> 1
         BEGIN
            GOTO RollBackTran
         END

         SELECT TOP 1 @nLLIQty = LLI.qty-LLI.qtyallocated-LLI.qtypicked,
                      @cLoc     = LLI.Loc,
                      @cLot     = LLI.Lot,
                      @cID      = LLI.ID
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN SKU WITH (NOLOCK) ON SKU.Sku = LLI.Sku
         WHERE SKU.sku = @cSku
            AND LLI.StorerKey = @cStorerKey
         ORDER BY (LLI.qty-LLI.qtyallocated-LLI.qtypicked) DESC

         IF @@ERROR <> 0
         BEGIN
            GOTO RollBackTran
         END

         IF @nLLIQty < @nQtyNeedPicking
         BEGIN
            SET @nPickDetailQty = @nLLIQty
            SET @nQtyNeedPicking = @nQtyNeedPicking - @nLLIQty
         END
         ELSE
         BEGIN
            SET @nPickDetailQty = @nQtyNeedPicking
            SET @nQtyNeedPicking = 0
         END

         INSERT INTO PICKDETAIL
         (
             PickDetailKey       ,OrderKey         ,OrderLineNumber
            ,Lot                 ,Storerkey        ,Sku
            ,AltSku              ,UOM              ,UOMQty
            ,STATUS              ,PickHeaderKey    ,ID
            ,Loc                 ,PackKey          ,WaveKey
         )
         VALUES
         (
            @c_NewPickDetailKey  ,@cOrderKey          ,@cOrderLineNumber
           ,@cLot                ,@cStorerKey         ,@cSKU
           ,@cAltSku             ,'6'                 ,'1'
           ,'0'                  ,''                  ,@cID
           ,@cLoc                ,@cPackKey         ,''
         )
         IF @@ERROR <> 0
         BEGIN
            GOTO RollBackTran
         END


         UPDATE PICKDETAIL SET STATUS = '5' , qty = @nPickDetailQty WHERE PickDetailKey = @c_NewPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            GOTO RollBackTran
         END

      END

      COMMIT TRAN rdt_PalletLoading

      SET @cQty = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cQty = ''
      SET @cOutField06 = ''
   END

   IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
   IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
   IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
   IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
   IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5
   SET @nStep = @nStep - 1
   SET @nScn = @nScn -1
   GOTO Quit

   RollBackTran:
      SET @nErrNo = 221261
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TransacFailed
      ROLLBACK TRAN rdt_PalletLoading
   Step_4_Fail:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      GOTO Quit

END
GOTO QUIT
/********************************************************************************
Step 5.  Scn = 6424
         Scan Order Number
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOrderKey = @cInField01

      IF ISNULL(@cOrderKey,'') = ''
      BEGIN
         SET @nErrNo = 221253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need OrderKey
         GOTO Step_5_Fail
      END

      SELECT
         @cStatus = STATUS,
         @cOrderKey = OrderKey
      FROM ORDERS WITH (NOLOCK)
      WHERE (OrderKey = @cOrderKey or ExternOrderKey = @cOrderKey) 
      AND FACILITY = @cFacility AND StorerKey = @cStorerKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 221254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Order
         GOTO Step_5_Fail
      END

      -- Only order picked, can load pallet
      IF ISNULL(@cStatus,'') <> '5'
      BEGIN
         SET @nErrNo = 221255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order Picked
         GOTO Step_5_Fail
      END
      DELETE FROM @skuHU
      INSERT INTO @skuHU (Pallet)
      SELECT TOP 5
         ALTSKU FROM SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = @cStorerKey
        AND SKU.SKUGROUP = 'HU'
      ORDER BY ALTSKU

      SELECT @cSkuPallet1 = Pallet FROM @skuHU WHERE RowRef = 1
      SELECT @cSkuPallet2 = Pallet FROM @skuHU WHERE RowRef = 2
      SELECT @cSkuPallet3 = Pallet FROM @skuHU WHERE RowRef = 3
      SELECT @cSkuPallet4 = Pallet FROM @skuHU WHERE RowRef = 4
      SELECT @cSkuPallet5 = Pallet FROM @skuHU WHERE RowRef = 5

      IF ISNULL(@cSkuPallet1, '') = ''
      BEGIN
         SET @nErrNo = 221256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoPalletSKU'
         GOTO Step_6_Fail
      END

      IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
      IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
      IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
      IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
      IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5
      -- Go to next screen
      SET @nScn = @nScn_PalletType
      SET @nStep = @nStep_PalletType
      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '9', -- Sign Out function
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerKey,
           @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
      GOTO Quit
   END

   Step_5_Fail:
   BEGIN
      SET @cOrderKey = ''
      SET @cOutField01 = ''
   END

END
GOTO Quit
/********************************************************************************
Step 6.  Scn = 6425
         Option
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @cInField06 NOT IN ('1','2','3','4','5')
      BEGIN
         SET @dFlag = 1
      END
      ELSE
      BEGIN
         SET @cSql =
              'IF @cSkuPallet' + @cInField06 + ' <> '''' '
            + '  SET @cAltSku = @cSkuPallet' + @cInField06 +' '
            + 'ELSE '
            + '  SET @dFlag = 1'

         SET @cSQLParam =
                 '@cSkuPallet1      NVARCHAR( 60),      ' +
                 '@cSkuPallet2      NVARCHAR( 60),      ' +
                 '@cSkuPallet3      NVARCHAR( 60),      ' +
                 '@cSkuPallet4      NVARCHAR( 60),      ' +
                 '@cSkuPallet5      NVARCHAR( 60),      ' +
                 '@cAltSku          NVARCHAR( 20) OUTPUT,'+
                 '@dFlag            INT           OUTPUT'

         EXEC sp_ExecuteSQL @cSql, @cSQLParam,
              @cSkuPallet1, @cSkuPallet2,
              @cSkuPallet3, @cSkuPallet4,
              @cSkuPallet5, @cAltSku OUTPUT, @dFlag OUTPUT
      END

      IF @dFlag = 1
      BEGIN
         SET @nErrNo = 221257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidAltSKU
         GOTO Step_3_Fail
      END

      SET @cPalletType = @cAltSku

      IF EXISTS( SELECT 1 FROM PICKDETAIL WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND ALTSKU = @cPalletType)
      BEGIN
         SELECT @cOutField01 = SUM(QTY) FROM PICKDETAIL WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND ALTSKU = @cPalletType
         SET @cOutField02 = @cPalletType
         SET @cOutField03 = @cOrderKey

         SET @nScn = @nScn_AddMoreLP
         SET @nStep = @nStep_AddMoreLP
         GOTO Quit
      END

      SET @cOutField01 = ''
      -- Go to next screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn  = @nScn_ScanOrder
      SET @nStep = @nStep_ScanOrder
      SET @cOutField01 = '' 
      SET @cOrderKey = ''
   END

   Step_6_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 7.  Scn = 6426
         Qty
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cQty = @cInField01

      IF ISNULL(@cQty, '') = ''
      BEGIN
         SET @nErrNo = 221259
         SET @cErrMsg = rdt.rdtgetmessage( 221259, @cLangCode, 'DSP') --NeedQty
         GOTO Step_7_Fail
      END

      IF @cQty <> '' AND RDT.rdtIsValidQTY( @cQty, 1) = 0 -- Check for zero qty
      BEGIN
         SET @nErrNo = 221258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Step_7_Fail
      END

      SELECT @cQty_bal = SUM(LLI.qty-LLI.qtyallocated-LLI.qtypicked),
             @cSku     = LLI.SKU,
             @cLoc     = LLI.Loc,
             @cPackKey = SKU.PACKKey
      FROM LOTxLOCxID LLI WITH(NOLOCK)
      INNER JOIN SKU WITH(NOLOCK) ON SKU.Sku = LLI.Sku
      WHERE SKU.ALTSKU = @cPalletType
        AND LLI.StorerKey = @cStorerKey
      GROUP BY LLI.SKU, LLI.Loc, SKU.PACKKey

      IF ISNULL(@cQty_bal,'0') = '0' OR (CAST(@cQty as INT) > CAST (@cQty_bal as INT))
      BEGIN
         SET @nErrNo = 221260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYUnavailable
         GOTO Step_7_Fail
      END

      SET @cOutField01 = @cQTY
      SET @cOutField02 = @cPalletType
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = ''
      -- Go to next screen
      SET @nScn = @nScn_AddLP
      SET @nStep = @nStep_AddLP
      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      DELETE FROM @skuHU
      INSERT INTO @skuHU (Pallet)
      SELECT TOP 5
         ALTSKU FROM SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = @cStorerKey
        AND SKU.SKUGROUP = 'HU'
      ORDER BY ALTSKU

      SELECT @cSkuPallet1 = Pallet FROM @skuHU WHERE RowRef = 1
      SELECT @cSkuPallet2 = Pallet FROM @skuHU WHERE RowRef = 2
      SELECT @cSkuPallet3 = Pallet FROM @skuHU WHERE RowRef = 3
      SELECT @cSkuPallet4 = Pallet FROM @skuHU WHERE RowRef = 4
      SELECT @cSkuPallet5 = Pallet FROM @skuHU WHERE RowRef = 5

      IF ISNULL(@cSkuPallet1, '') = ''
      BEGIN
         SET @nErrNo = 221256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoPalletSKU'
         GOTO Step_7_Fail
      END

      IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
      IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
      IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
      IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
      IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5

      SET @nScn  = @nScn_PalletType
      SET @nStep = @nStep_PalletType
      SET @cPalletType = ''
      GOTO QUIT
   END

   Step_7_Fail:
   BEGIN
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 8. Scn = 6427
   Option
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField04
      IF @cOption = '1'
      BEGIN
         SELECT @cQty_bal = SUM(LLI.qty-LLI.qtyallocated-LLI.qtypicked),
            @cSku     = LLI.SKU,
            @cLoc     = LLI.Loc,
            @cPackKey = SKU.PACKKey
         FROM LOTxLOCxID LLI WITH(NOLOCK)
               INNER JOIN SKU WITH(NOLOCK) ON SKU.Sku = LLI.Sku
         WHERE SKU.ALTSKU = @cPalletType
         AND LLI.StorerKey = @cStorerKey
         GROUP BY LLI.SKU, LLI.Loc, SKU.PACKKey

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PalletLoading_Step_8-- For rollback or commit only our own transaction

         /*-------------------------------------------------------------------------------

                                    OrderDetail

         -------------------------------------------------------------------------------*/

         -- Get next OrderLineNumber
         SELECT @cOrderLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( OrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5),
               @cExternLineNo = (CAST(ISNULL(MAX(ExternLineNo),0) AS INT)) +1,
               @cExternOrderKey = MAX(ExternOrderKey)
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         INSERT INTO OrderDetail
         (OrderKey, OrderLineNumber,ExternOrderKey, ExternLineNo, StorerKey, SKU, OpenQty, QtyPicked, Enteredqty,
         UOM, LoadKey, PackKey, Facility, MBOLKey, Status)
         SELECT TOP 1
         @cOrderKey, @cOrderLineNumber,@cExternOrderKey,@cExternLineNo, StorerKey, @cSku, @cQty, 0, @cQty,
         'EA', LoadKey, @cPackKey, Facility, MBOLKey, '5'
            FROM OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN
            GOTO RollBackTran_Step_8
         END


         /*-------------------------------------------------------------------------------
                                    PickDetail
         -------------------------------------------------------------------------------*/
         --START Picking
         SET @nQtyNeedPicking = @cQty

         WHILE ( @nQtyNeedPicking > 0)
         BEGIN

            EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @c_NewPickDetailKey  OUTPUT,
                  @b_success        OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg         OUTPUT

            IF @b_success <> 1
            BEGIN
               GOTO RollBackTran_Step_8
            END

            SELECT TOP 1 @nLLIQty = LLI.qty-LLI.qtyallocated-LLI.qtypicked,
                        @cLoc     = LLI.Loc,
                        @cLot     = LLI.Lot,
                        @cID      = LLI.ID
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN SKU WITH (NOLOCK) ON SKU.Sku = LLI.Sku
            WHERE SKU.sku = @cSku
               AND LLI.StorerKey = @cStorerKey
            ORDER BY (LLI.qty-LLI.qtyallocated-LLI.qtypicked) DESC

            IF @@ERROR <> 0
            BEGIN
               GOTO RollBackTran_Step_8
            END

            IF @nLLIQty < @nQtyNeedPicking
            BEGIN
               SET @nPickDetailQty = @nLLIQty
               SET @nQtyNeedPicking = @nQtyNeedPicking - @nLLIQty
            END
            ELSE
            BEGIN
               SET @nPickDetailQty = @nQtyNeedPicking
               SET @nQtyNeedPicking = 0
            END

            INSERT INTO PICKDETAIL
            (
               PickDetailKey       ,OrderKey         ,OrderLineNumber
               ,Lot                 ,Storerkey        ,Sku
               ,AltSku              ,UOM              ,UOMQty
               ,STATUS              ,PickHeaderKey    ,ID
               ,Loc                 ,PackKey          ,WaveKey
            )
            VALUES
            (
            @c_NewPickDetailKey  ,@cOrderKey          ,@cOrderLineNumber
            ,@cLot                ,@cStorerKey         ,@cSKU
            ,@cPalletType         ,'6'                 ,'1'
            ,'0'                  ,''                  ,@cID
            ,@cLoc                ,@cPackKey         ,''
            )
            IF @@ERROR <> 0
            BEGIN
               GOTO RollBackTran_Step_8
            END


            UPDATE PICKDETAIL SET STATUS = '5' , qty = @nPickDetailQty WHERE PickDetailKey = @c_NewPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               GOTO RollBackTran_Step_8
            END

         END

         COMMIT TRAN rdt_PalletLoading_Step_8

         SET @cQty = ''
         SET @cPalletType = ''
         SET @cOrderKey = ''
         SET @cOutField01 = ''
         SET @nStep = @nStep_ScanOrder
         SET @nScn = @nScn_ScanOrder
         GOTO QUIT
      END
      ELSE IF @cOption = '9'
      BEGIN
         SET @cQTY = ''
         SET @cOutField01 = ''
         SET @nStep = @nStep_QTY
         SET @nScn = @nScn_QTY
         GOTO QUIT
      END
      ELSE
      BEGIN
         SET @nErrNo = 221251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO Step_8_Fail
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cQTY = ''
      SET @cOutField01 = ''
      SET @nStep = @nStep_QTY
      SET @nScn = @nScn_QTY
      GOTO QUIT
   END
   RollBackTran_Step_8:
      SET @nErrNo = 221261
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TransacFailed
      ROLLBACK TRAN rdt_PalletLoading
   Step_8_Fail:
   BEGIN
      SET @cOutField01 = ''
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      GOTO Quit
   END

END
GOTO QUIT
/********************************************************************************
Step 9.  Scn = 6428
         Option
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField04
      IF @cOption = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @nStep = @nStep_QTY
         SET @nScn = @nScn_QTY
         GOTO QUIT
      END
      ELSE IF @cOption = '9'
      BEGIN
         DELETE FROM @skuHU
         INSERT INTO @skuHU (Pallet)
         SELECT TOP 5
            ALTSKU FROM SKU WITH (NOLOCK)
         WHERE SKU.Storerkey = @cStorerKey
         AND SKU.SKUGROUP = 'HU'
         ORDER BY ALTSKU

         SELECT @cSkuPallet1 = Pallet FROM @skuHU WHERE RowRef = 1
         SELECT @cSkuPallet2 = Pallet FROM @skuHU WHERE RowRef = 2
         SELECT @cSkuPallet3 = Pallet FROM @skuHU WHERE RowRef = 3
         SELECT @cSkuPallet4 = Pallet FROM @skuHU WHERE RowRef = 4
         SELECT @cSkuPallet5 = Pallet FROM @skuHU WHERE RowRef = 5

         IF ISNULL(@cSkuPallet1, '') = ''
         BEGIN
            SET @nErrNo = 221256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoPalletSKU'
            GOTO Step_9_Fail
         END

         IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
         IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
         IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
         IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
         IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5
         SET @cPalletType = ''
         SET @nStep = @nStep_PalletType
         SET @nScn = @nScn_PalletType
         GOTO QUIT
      END
      ELSE
      BEGIN
         SET @nErrNo = 221251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO Step_9_Fail
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      DELETE FROM @skuHU
      INSERT INTO @skuHU (Pallet)
      SELECT TOP 5
         ALTSKU FROM SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = @cStorerKey
        AND SKU.SKUGROUP = 'HU'
      ORDER BY ALTSKU

      SELECT @cSkuPallet1 = Pallet FROM @skuHU WHERE RowRef = 1
      SELECT @cSkuPallet2 = Pallet FROM @skuHU WHERE RowRef = 2
      SELECT @cSkuPallet3 = Pallet FROM @skuHU WHERE RowRef = 3
      SELECT @cSkuPallet4 = Pallet FROM @skuHU WHERE RowRef = 4
      SELECT @cSkuPallet5 = Pallet FROM @skuHU WHERE RowRef = 5

      IF ISNULL(@cSkuPallet1, '') = ''
      BEGIN
         SET @nErrNo = 221256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoPalletSKU'
         GOTO Step_9_Fail
      END

      IF ISNULL(@cSkuPallet1,'') <> '' SET @cOutField01 = '1.'+@cSkuPallet1
      IF ISNULL(@cSkuPallet2,'') <> '' SET @cOutField02 = '2.'+@cSkuPallet2
      IF ISNULL(@cSkuPallet3,'') <> '' SET @cOutField03 = '3.'+@cSkuPallet3
      IF ISNULL(@cSkuPallet4,'') <> '' SET @cOutField04 = '4.'+@cSkuPallet4
      IF ISNULL(@cSkuPallet5,'') <> '' SET @cOutField05 = '5.'+@cSkuPallet5
      SET @cPalletType = ''
      SET @nStep = @nStep_PalletType
      SET @nScn = @nScn_PalletType
      GOTO QUIT
   END

   Step_9_Fail:
   BEGIN
      SET @cOutField01 = ''
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
        Func = @nFunc,
        Step = @nStep,
        Scn = @nScn,

        Facility  = @cFacility,
        StorerKey = @cStorerKey,
        V_OrderKey = @cOrderKey,
        -- UserName  = @cUserName,
        V_String1  = @cAltSku,
        V_String2  = @cDefaultOptSCN1,
        V_String3  = @cPalletType,
        V_String4  = @cQTY,
        V_String11 = @cSkuPallet1,
        V_String12 = @cSkuPallet2,
        V_String13 = @cSkuPallet3,
        V_String14 = @cSkuPallet4,
        V_String15 = @cSkuPallet5,


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