SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*********************************************************************************/
/* Store procedure: rdtfnc_PostPickAudit_RefNo                                   */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: PPA                                                                  */
/*                                                                               */
/* Date       Rev  Author   Purposes                                             */
/* 2016-10-06 1.0  James    WMS344 Created                                       */
/* 2018-10-22 1.1  Gan      Performance tuning                                   */
/* 2023-05-24 1.1  James    WMS-22527 Add DisableQTYField (james01)              */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_PostPickAudit_RefNo] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_Success      INT,
   @n_Err          INT,
   @c_ErrMsg       NVARCHAR( 250),

   @cChkFacility   NVARCHAR( 5),
   @nTranCount     INT,
   @bSuccess       INT,
   @cBarcode       NVARCHAR( 60),
   @cOption        NVARCHAR( 1),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)

-- Session variable
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,
   @cUserName    NVARCHAR( 18),
   @cPrinter     NVARCHAR( 10),
   @cStorerGroup NVARCHAR( 20),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cID          NVARCHAR( 18),

   @cPUOM        NVARCHAR(  1),
   @cSKU         NVARCHAR( 20),
   @cSKUDesc     NVARCHAR( 60),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @cUserDefine01       NVARCHAR( 60),
   @cUserDefine02       NVARCHAR( 60),
   @cUserDefine03       NVARCHAR( 60),
   @cUserDefine04       NVARCHAR( 60),
   @cUserDefine05       NVARCHAR( 60),
   @cDecodeSP           NVARCHAR( 20),
   @cOrderKey           NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),
   @cUPC                NVARCHAR( 30),
   @cStore              NVARCHAR( 15),
   @cUOM                NVARCHAR( 10),
   @cPPADefaultQTY      NVARCHAR( 5),
   @cDisAllowOverAllocQty NVARCHAR( 5),

   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @nTTL_SKU            INT,
   @nTTL_PPAQTY         INT,
   @nTTL_PPASKU         INT,
   @nTTL_ORDQTY         INT,
   @nTTL_SHPQTY         INT,
   @nTTL_SHPSKU         INT,
   @nTTL_Qty            INT,
   @nPPPAQTY            INT,
   @nMPPAQTY            INT,
   @nPORDQTY            INT,
   @nMORDQTY            INT,
   @nTTL_AllocatedQty   INT,
   @nRowRef             INT,

   @cDisableQTYField    NVARCHAR( 1),
   @cDisableQTYFieldSP  NVARCHAR(20),
   @tVarDisableQTYField VARIABLETABLE,
   
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

   @cStorerGroup = StorerGroup,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cStorerKey  = V_StorerKey,
   @cStore      = V_ConsigneeKey,
   @cPUOM       = V_UOM,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,
   @nQTY        = V_QTY,
   @cOrderKey   = V_OrderKey,
   @cPickSlipNo = V_PickSlipNo,

   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @nPUOM_Div  = V_PUOM_Div,
   @nPQTY      = V_PQTY,
   @nMQTY      = V_MQTY,

   @nQTY        = V_Integer1,
   @nTTL_PPAQTY = V_Integer2,

   @cRefNo              = V_String1,
   @cMUOM_Desc          = V_String2,
   @cPUOM_Desc          = V_String3,
   @cDisableQTYField    = V_String4,
   @cDisableQTYFieldSP  = V_String5,
  -- @nPUOM_Div           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
  -- @nPQTY               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
  -- @nMQTY               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
  -- @nQTY                = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,
  -- @nTTL_PPAQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,
   @cDecodeSP           = V_String9,
   --@cMUOM_Desc          = V_String10,
   --@cPUOM_Desc          = V_String11,
   --@nPUOM_Div           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
   --@nPQTY               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 7), 0) = 1 THEN LEFT( V_String13, 7) ELSE 0 END,
   --@nMQTY               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 7), 0) = 1 THEN LEFT( V_String14, 7) ELSE 0 END,
   @cPPADefaultQTY      = V_String15,
   @cDisAllowOverAllocQty = V_String16,


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

   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06 = FieldAttr06,
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08 = FieldAttr08,
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10 = FieldAttr10,
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12 = FieldAttr12,
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14 = FieldAttr14,
   @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 905
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 905. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 4730. REFNO
   IF @nStep = 2 GOTO Step_2   -- Scn = 4731. INFO
   IF @nStep = 3 GOTO Step_3   -- Scn = 4732. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 4733. QTY
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 905. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cPPADefaultQTY = rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorerKey)
   IF rdt.rdtIsValidQty( @cPPADefaultQTY, 0) = 0
      SET @cPPADefaultQTY = '0'

   SET @cDisAllowOverAllocQty = rdt.RDTGetConfig( @nFunc, 'DisAllowOverAllocQty', @cStorerKey)
   IF rdt.rdtIsValidQty( @cDisAllowOverAllocQty, 0) = 0
      SET @cDisAllowOverAllocQty = '0'

   -- (james01)
   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)

   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)
   IF @cDisableQTYFieldSP = '0'
      SET @cDisableQTYFieldSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Prepare next screen var
   SET @cOutField01 = '' -- REFNO

   SET @cRefNo = ''

   -- Set the entry point
   SET @nScn = 4730
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4730. REFNO screen
   REFNO        (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField01
      SET @cBarcode = @cInField01

      -- Check ref no
      IF ISNULL( @cRefNo, '') = ''
      BEGIN
         SET @nErrNo = 104751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value required
         GOTO Step_1_Fail
      END

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

            SET @cRefNo = @cUserDefine01
      END

      -- Customize decode
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
            ' @cRefNo         OUTPUT, @cStore         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
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
            ' @cRefNo         NVARCHAR( 20)  OUTPUT, ' +
            ' @cStore         NVARCHAR( 15)  OUTPUT, ' +
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
            @cRefNo        OUTPUT, @cStore         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
            @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
            @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
            @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
            @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
            @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      -- Validate externorderkey
      IF NOT EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ExternOrderKey = @cRefNo
                      AND   [Status] < '9')
      BEGIN
         SET @nErrNo = 104752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Refno
         GOTO Step_1_Fail
      END

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN Step1_Update

      -- 1 externorderkey can have 1 or more orders associated
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT OrderKey FROM OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   [Status] < '9'
      AND   QtyAllocated > 0
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         -- Generate pickslip no
         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            EXECUTE nspg_GetKey
                @KeyName      = 'PICKSLIP'
               ,@fieldlength  = 9
               ,@keystring    = @cPickSlipNo OUTPUT
               ,@b_Success    = @bSuccess    OUTPUT
               ,@n_err        = @nErrNo      OUTPUT
               ,@c_errmsg     = @cErrMsg     OUTPUT

            IF @bSuccess <> 1
            BEGIN
               ROLLBACK TRAN Step1_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               SET @nErrNo = 104764
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetPKSlip Fail'
               GOTO Step_1_Fail
            END

            SET @cPickSlipNo = 'P' + @cPickSlipNo

            INSERT INTO dbo.PICKHEADER
              (PickHeaderKey ,OrderKey, Zone)
            VALUES
              (@cPickSlipNo, @cOrderKey, '3')

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN Step1_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               SET @nErrNo = 104765
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan In Fail'
               GOTO Step_1_Fail
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
            VALUES
            (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN Step1_Update
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN

               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               SET @nErrNo = 104762
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan In Fail'
               GOTO Step_1_Fail
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      COMMIT TRAN Step1_Update
      WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN

      SELECT TOP 1 @cStore = O.ConsigneeKey
      FROM dbo.OrderDetail OD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE OD.StorerKey = @cStorerKey
      AND   OD.ExternOrderKey = @cRefNo
      AND   OD.Status < '9'

      SELECT @nTTL_SHPSKU = COUNT( DISTINCT SKU),
             @nTTL_SHPQTY = ISNULL( SUM( ShippedQty), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status = '9'

      SELECT @nTTL_SKU = COUNT( DISTINCT SKU),
             @nTTL_Qty = ISNULL( SUM( QtyAllocated), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status < '9'
      AND   QtyAllocated > 0  -- Show only SKU which was allocated

      SELECT @nTTL_PPAQTY = ISNULL( SUM( CQTY), 0),
             @nTTL_PPASKU = COUNT( DISTINCT SKU)
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   RefKey = @cRefNo

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cStore
      SET @cOutField03 = RTRIM( CAST( @nTTL_SKU + @nTTL_SHPSKU AS NVARCHAR( 3))) + '/' + RTRIM( CAST( @nTTL_PPASKU AS NVARCHAR( 3)))
      SET @cOutField04 = RTRIM( CAST( @nTTL_Qty + @nTTL_SHPQTY AS NVARCHAR( 5))) + '/' + RTRIM( CAST( @nTTL_PPAQTY AS NVARCHAR( 5)))
      SET @cOutField05 = RTRIM( CAST( @nTTL_SHPQTY AS NVARCHAR( 5)))

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- ReceiptKey

      SET @cRefNo = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4731. Info screen
   RefNo      (field01)
   Ship To    (field02)
   SKU CKD    (field03)
   QTY CKD    (field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''

      -- Go to SKU screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- REFNO

      SET @cRefNo = ''

      -- Go to REFNO screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 4732. SKU screen
   SKU       (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUPC = LEFT( @cInField01, 30) -- SKU
      SET @cBarcode = @cInField01

      -- Validate compulsary field
      IF @cBarcode = '' OR @cBarcode IS NULL
      BEGIN
         SET @nErrNo = 104753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is require
         GOTO Step_3_Fail
      END

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

         IF @nErrNo <> 0
            GOTO Step_3_Fail

         SET @cSKU = @cUPC
      END

      -- Customize decode
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
            ' @cRefNo         OUTPUT, @cStore         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
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
            ' @cRefNo         NVARCHAR( 20)  OUTPUT, ' +
            ' @cStore         NVARCHAR( 15)  OUTPUT, ' +
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
            @cRefNo        OUTPUT, @cStore         OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
            @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
            @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
            @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
            @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
            @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail

         SET @cSKU = @cUPC
      END

      -- Get SKU
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0
      SELECT
         @nSKUCnt = COUNT( DISTINCT A.SKU),
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cUPC
      ) A

      -- Check SKU
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 104754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_3_Fail
      END

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 104755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Step_3_Fail
      END

      IF NOT EXISTS ( SELECT 1
                      FROM dbo.OrderDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ExternOrderKey = @cRefNo
                      AND   Status < '9'
                      AND   SKU = @cSKU)
      BEGIN
         SET @nErrNo = 104756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT IN ORD
         GOTO Step_3_Fail
      END

      IF NOT EXISTS ( SELECT 1
                      FROM dbo.OrderDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ExternOrderKey = @cRefNo
                      AND   Status < '9'
                      AND   SKU = @cSKU
                      GROUP BY SKU
                      HAVING ISNULL( SUM( QtyAllocated), 0) > 0)
      BEGIN
         SET @nErrNo = 104766
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT ALLOC
         GOTO Step_3_Fail
      END

      SELECT @nTTL_PPAQTY = ISNULL( SUM( CQTY), 0)
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   RefKey = @cRefNo
      AND   SKU = @cSKU

      SELECT @nTTL_ORDQTY = ISNULL( SUM( OriginalQTY), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status < '9'
      AND   SKU = @cSKU

      -- Disable QTY field
      IF @cDisableQTYFieldSP <> ''
      BEGIN
         IF @cDisableQTYFieldSP = '1'
         BEGIN
            SET @cDisableQTYField = @cDisableQTYFieldSP
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cSKU, @nQty, ' +
               ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQTY           INT          , ' +
                '@tVarDisableQTYField VariableTable READONLY, ' +
               ' @cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
               ' @nErrNo             INT            OUTPUT, ' +
               ' @cErrMsg            NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cSKU, @nQty, 
                  @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
      
      -- Get SKU info
      SELECT
         @cSKUDesc = IsNULL( DescR, ''),
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
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nMPPAQTY = @nTTL_PPAQTY
         SET @nMORDQTY = @nTTL_ORDQTY
         SET @cFieldAttr07 = 'O' -- @nPQTY
         SET @cFieldAttr09 = 'O' -- @nPPPAQTY
         SET @cFieldAttr11 = 'O' -- @nPORDQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nPPPAQTY = @nTTL_PPAQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMPPAQTY = @nTTL_PPAQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPORDQTY = @nTTL_ORDQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMORDQTY = @nTTL_ORDQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @cFieldAttr07 = '' -- @nPQTY
         SET @cFieldAttr09 = '' -- @nPPPAQTY
         SET @cFieldAttr11 = '' -- @nPORDQTY
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField04 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField05 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField06 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField07 = CASE WHEN @nPQTY = 0 OR @cFieldAttr07 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField08 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 5)) END -- MQTY
      SET @cOutField09 = CASE WHEN @nPPPAQTY = 0 OR @cFieldAttr09 = 'O' THEN '' ELSE CAST( @nPPPAQTY AS NVARCHAR( 5)) END -- PPPAQTY
      SET @cOutField10 = CASE WHEN @nMPPAQTY = 0 THEN '' ELSE CAST( @nMPPAQTY AS NVARCHAR( 5)) END -- MPPAQTY
      SET @cOutField11 = CASE WHEN @nPORDQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPORDQTY AS NVARCHAR( 5)) END -- PORDQTY
      SET @cOutField12 = CASE WHEN @nMORDQTY = 0 THEN '' ELSE CAST( @nMORDQTY AS NVARCHAR( 5)) END -- MORDQTY


      IF @cFieldAttr07 = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY
         SET @cOutField07 = CASE WHEN ISNULL( @cPPADefaultQTY, '0') = 0 THEN '' ELSE @cPPADefaultQTY END
         
         -- Enable/Diable field
         SET @cFieldAttr07 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END
      END
      ELSE
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- MQTY
         SET @cOutField08 = CASE WHEN ISNULL( @cPPADefaultQTY, '0') = 0 THEN '' ELSE @cPPADefaultQTY END
      END

      -- Enable/Disable field
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END
         
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @nTTL_SHPSKU = COUNT( DISTINCT SKU),
             @nTTL_SHPQTY = ISNULL( SUM( ShippedQty), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status = '9'

      SELECT @nTTL_SKU = COUNT( DISTINCT SKU),
             @nTTL_Qty = ISNULL( SUM( QtyAllocated), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status < '9'
      AND   QtyAllocated > 0  -- Show only SKU which was allocated

      SELECT @nTTL_PPAQTY = ISNULL( SUM( CQTY), 0),
             @nTTL_PPASKU = COUNT( DISTINCT SKU)
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   RefKey = @cRefNo

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cStore
      SET @cOutField03 = RTRIM( CAST( @nTTL_SKU + @nTTL_SHPSKU AS NVARCHAR( 3))) + '/' + RTRIM( CAST( @nTTL_PPASKU AS NVARCHAR( 3)))
      SET @cOutField04 = RTRIM( CAST( @nTTL_Qty + @nTTL_SHPQTY AS NVARCHAR( 5))) + '/' + RTRIM( CAST( @nTTL_PPAQTY AS NVARCHAR( 5)))
      SET @cOutField05 = RTRIM( CAST( @nTTL_SHPQTY AS NVARCHAR( 5)))

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cUPC = ''    -- SKU
      SET @cBarcode = ''

      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 4733. QTY screen
   SKU       (field01)
   SKU desc  (field02)
   SKU desc  (field03)
   UOM ratio (field05)
   PUOM      (field06)
   MUOM      (field07)
   PQTY      (field08, input)
   MQTY      (field09, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END
      SET @cMQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END

      -- Retain value
      SET @cOutField07 = CASE WHEN @cFieldAttr07 = 'O' THEN @cFieldAttr07 ELSE @cFieldAttr07 END -- PQTY
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cFieldAttr08 ELSE @cFieldAttr08 END -- MQTY

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 104757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY
         GOTO Step_4_Fail
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 104758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- MQTY
         GOTO Step_4_Fail
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      SELECT @nTTL_AllocatedQty = ISNULL( SUM( QtyAllocated), 0)
      FROM dbo.OrderDetail OD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE OD.StorerKey = @cStorerKey
      AND   OD.ExternOrderKey = @cRefNo
      AND   OD.Status < '9'
      AND   OD.SKU = @cSKU

      IF @cDisAllowOverAllocQty = '1' AND
         (@nQTY + @nTTL_PPAQTY) > @nTTL_AllocatedQty
      BEGIN
         SET @nErrNo = 104759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --> Allocated QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- MQTY
         GOTO Step_4_Fail
      END

      -- Get UOM
      SELECT @cUOM = PackUOM3
      FROM dbo.SKU WITH (NOLOCK)
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      SELECT @nRowRef = RowRef
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   RefKey = @cRefNo
      AND   SKU = @cSKU

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN Step4_Update

      IF ISNULL( @nRowRef, '') = ''
      BEGIN
         INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
         VALUES (@cRefNo, '', '', '', @cStorerKey, @cSKU, @cSKUDesc, @nTTL_AllocatedQty, @nQTY, '0', @cUserName, GETDATE(), 1, 1, '', '')

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN Step4_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

            SET @nErrNo = 104760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail INS PPA
            GOTO Step_4_Fail
         END
      END
      ELSE
      BEGIN
         -- Update PPA
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nQTY,
            NoOfCheck = NoOfCheck + 1
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN Step4_Update
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

            SET @nErrNo = 104761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PPA
            GOTO Step_4_Fail
         END
      END

      SET @nTTL_PPAQTY = 0
      SELECT @nTTL_PPAQTY = ISNULL( SUM( CQTY), 0)
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE RefKey = @cRefNo

      SET @nTTL_AllocatedQty = 0
      SELECT @nTTL_AllocatedQty = ISNULL( SUM( QtyAllocated), 0)
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ExternOrderKey = @cRefNo
      AND   Status < '9'

      -- If all sku qtyallocated has been scanned then proceed with scan out
      IF @nTTL_PPAQTY >= @nTTL_AllocatedQty
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT OrderKey
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ExternOrderKey = @cRefNo
         AND   Status < '9'
         AND   QtyAllocated > 0  -- all orders with at least 1 qty allocated then need scan out
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cPickSlipNo = ''
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   ISNULL( ScanOutDate, '') = '')
            BEGIN
               UPDATE dbo.PickingInfo WITH (ROWLOCK) SET
                  ScanOutDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN Step4_Update
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN

                  CLOSE CUR_LOOP
                  DEALLOCATE CUR_LOOP
                  SET @nErrNo = 104763
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PPA
                  GOTO Step_4_Fail
               END
            END

            FETCH NEXT FROM CUR_LOOP INTO @cOrderKey
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END

      COMMIT TRAN Step4_Update
      WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Receiving
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cID           = @cID,
         @cSKU          = @cSKU,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cRefNo1       = @cRefNo,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nStep         = @nStep


      -- Go back to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField06 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''

      -- Enable field (james01)
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = ''

      -- Go back to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField05 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField06 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField07 = ''            -- @nPQTY
      SET @cOutField08 = ''            -- @nMQTY

      IF @cFieldAttr07 = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY
         SET @cOutField07 = CASE WHEN ISNULL( @cPPADefaultQTY, '0') = 0 THEN '' ELSE @cPPADefaultQTY END
      END
      ELSE
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- MQTY
         SET @cOutField08 = CASE WHEN ISNULL( @cPPADefaultQTY, '0') = 0 THEN '' ELSE @cPPADefaultQTY END
      END
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility     = @cFacility,
      Printer      = @cPrinter,

      V_StorerKey    = @cStorerKey,
      V_ConsigneeKey = @cStore,
      V_UOM          = @cPUOM,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDesc,
      V_OrderKey     = @cOrderKey,
      V_PickSlipNo   = @cPickSlipNo,

      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      V_Lottable06   = @cLottable06,
      V_Lottable07   = @cLottable07,
      V_Lottable08   = @cLottable08,
      V_Lottable09   = @cLottable09,
      V_Lottable10   = @cLottable10,
      V_Lottable11   = @cLottable11,
      V_Lottable12   = @cLottable12,
      V_Lottable13   = @dLottable13,
      V_Lottable14   = @dLottable14,
      V_Lottable15   = @dLottable15,

      V_PUOM_Div  = @nPUOM_Div,
      V_PQTY      = @nPQTY,
      V_MQTY      = @nMQTY,

      V_Integer1  = @nQTY,
      V_Integer2  = @nTTL_PPAQTY,

      V_String1   = @cRefNo,
      V_String4   = @cDisableQTYField,
      V_String5   = @cDisableQTYFieldSP,
      --V_String2   = @cMUOM_Desc,
      --V_String3   = @cPUOM_Desc,
      --V_String4   = @nPUOM_Div ,
      --V_String5   = @nPQTY,
      --V_String6   = @nMQTY,
      --V_String7   = @nQTY,
      --V_String8   = @nTTL_PPAQTY,
      V_String9   = @cDecodeSP,

      V_String10  = @cMUOM_Desc,
      V_String11  = @cPUOM_Desc,
      --V_String12  = @nPUOM_Div ,
      --V_String13  = @nPQTY,
      --V_String14  = @nMQTY,
      V_String15  = @cPPADefaultQTY,
      V_String16  = @cDisAllowOverAllocQty,

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