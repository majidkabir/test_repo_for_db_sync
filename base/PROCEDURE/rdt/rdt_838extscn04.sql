SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_838ExtScn04                                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose        : For Husqvarna                                          */
/*                                                                         */
/* Date        Rev   Author      Purposes                                  */
/* 2024-09-11  1.0   PXL009      Create for FCR-778 Violet Pack Changes    */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtScn04] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nScn         INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),

   @tExtScnData   VariableTable READONLY,

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT,
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT,
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT,
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT,
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT,
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 2. Prepare output fields, Step = 99 is a new screen
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT,
   @nErrNo             INT            OUTPUT,
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Screen constant
   DECLARE
      @nStep_PickSlipNo       INT,  @nScn_PickSlipNo     INT,
      @nStep_Statistic        INT,  @nScn_Statistic      INT,
      @nStep_ExtScn           INT,  @nScn_ExtScn04       INT,
      @nStep_SkuQty           INT

   SELECT
      @nStep_PickSlipNo       =  1,  @nScn_PickSlipNo     = 4650,
      @nStep_Statistic        =  2,  @nScn_Statistic      = 4651,
      @nStep_ExtScn           = 99,  @nScn_ExtScn04       = 6440,
      @nStep_SkuQty           =  3

   DECLARE
      --rdtmobrec
      @cUserName                       NVARCHAR( 18),
      @nMenu                           INT,
      @bDebugFlag                      BINARY = 0,
      @nMOBRECStep                     INT,
      @nMOBRECScn                      INT,

      @cOption                         NVARCHAR( 2),
      @cPickSlipNo                     NVARCHAR( 10),
      @cPackDtlDropID                  NVARCHAR( 20),
      @cFromDropID                     NVARCHAR( 20),
      @cShowPickSlipNo                 NVARCHAR( 1),
      @cOrderKey                       NVARCHAR( 10),
      @cOrderStorerKey                 NVARCHAR( 15),
      @cOrderConsigneeKey              NVARCHAR( 15),
      @cOrderC_Zip                     NVARCHAR( 18),
      @cPickingDropIdPalletType        NVARCHAR( 10) = N'CHEP',
      @cSerialNoCapture                NVARCHAR( 1),
      @nPickingDropIdWeight            FLOAT,
      @nPickingDropIdHeight            FLOAT,
      @nPickingDropIdCube              FLOAT,
      @cDefaultConsigneeKey            NVARCHAR( 15),

      @cCustomerPalletType             NVARCHAR( 10),
      @cCustomerPalletCube             NVARCHAR( 20),
      @cCustomerPalletHeight           NVARCHAR( 20),
      @cCustomerPalletWeight           NVARCHAR( 20),
      @cCustomerPalletMixBrands        NVARCHAR( 20),
      @cCustomerPalletProductGrouping  NVARCHAR( 18),
      @cCustomerOrderType              NVARCHAR( 10),

      @cDefaultOption                  NVARCHAR( 1),
      @cLabelNo                        NVARCHAR( 20),
      @cCustomNo                       NVARCHAR( 5),
      @cCustomID                       NVARCHAR( 20),
      @nCartonNo                       INT,
      @nCartonSKU                      INT,
      @nCartonQTY                      INT,
      @nTotalCarton                    INT,
      @nTotalPick                      INT,
      @nTotalPack                      INT,
      @nTotalShort                     INT,
      @nPackedQTY                      INT,

      @cAddPackValidtn                 NVARCHAR( 20),

      @nWarningNo                      INT,
      @cWarningMessage                 NVARCHAR( 60)

   DECLARE @tWarnings TABLE(
       [ID]             INT IDENTITY(1,1) NOT NULL,
       [Message]        NVARCHAR(60)      NOT NULL
   )

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT @nMOBRECStep      = [Step]
      ,@nMOBRECScn          = [Scn]
      ,@nMenu               = [Menu]
      ,@cUserName           = [UserName]
      ,@cPickSlipNo         = [V_PickSlipNo]
      ,@cFromDropID         = [V_String20]
      ,@cPackDtlDropID      = [V_String9]
      ,@cDefaultOption      = [V_String32]
      ,@cShowPickSlipNo     = [V_String15]
   FROM [rdt].[RDTMOBREC] WITH(NOLOCK)
   WHERE [Mobile] = @nMobile
   IF @@ROWCOUNT = 0
   BEGIN
      GOTO Quit
   END

   IF @nFunc = 838
   BEGIN

      SET @cAddPackValidtn = [rdt].[RDTGetConfig]( @nFunc, N'AddPackValidtn', @cStorerKey)
      SET @cDefaultConsigneeKey = [rdt].[RDTGetConfig]( @nFunc, N'AddPackValidtnDefCNEE', @cStorerKey)
      IF ISNULL(@cDefaultConsigneeKey, N'') = N'' OR @cDefaultConsigneeKey = N'0'
      BEGIN
         SET @cDefaultConsigneeKey = N'0000000001'
      END

      -- From PickSlipNo screen
      IF @nMOBRECStep = @nStep_PickSlipNo
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cAddPackValidtn <> N'1'
            BEGIN
               GOTO Quit
            END

            -- screen mapping
            SET @cPickSlipNo     = @cInField01
            SET @cFromDropID     = @cInField02
            SET @cPackDtlDropID  = @cInField03

            SELECT TOP 1 @cOrderKey = OrderKey
            FROM [dbo].[PickDetail] (NOLOCK)
            WHERE [StorerKey]  = @cStorerKey 
               AND [DropID] = @cFromDropID

            -- Get info
            SELECT  @nPickingDropIdHeight  = MAX(ISNULL(CAST([LOTATTR].[Lottable11] AS FLOAT),0))
            FROM [dbo].[PickDetail]    WITH (NOLOCK)
               INNER JOIN [dbo].[SKU]  WITH (NOLOCK) ON  [PickDetail].[Storerkey] = [SKU].[Storerkey]
                  AND [PickDetail].[Sku] = [SKU].[Sku]
               LEFT  JOIN [dbo].[LOTATTRIBUTE] LOTATTR WITH (NOLOCK) ON [LOTATTR].[LOT] = [PickDetail].[LOT]
                  AND [LOTATTR].[SKU] = [PickDetail].[SKU]
                  AND [LOTATTR].[StorerKey] = [PickDetail].[StorerKey]
            WHERE  [PickDetail].[StorerKey]  = @cStorerKey
               AND [PickDetail].[DropID]     = @cFromDropID
               AND [PickDetail].[Status]     <= N'5'

            ;WITH [Packed] AS
            (
               SELECT [SKU], SUM([Qty]) AS [PackedQTY]
               FROM [dbo].[PackDetail]  WITH (NOLOCK)
               WHERE [RefNo2]       =  @cFromDropID
                  AND [DropID]      <> @cPackDtlDropID
                  AND [StorerKey]   =  @cStorerKey
               GROUP BY [SKU]
            ), 
            [Pick] AS 
            (
               SELECT [Sku], SUM([Qty]) AS [Qty]
               FROM [dbo].[PickDetail]    WITH (NOLOCK)
               WHERE  [PickDetail].[StorerKey]  = @cStorerKey
                  AND [PickDetail].[DropID]     = @cFromDropID
                  AND [PickDetail].[Status]     <= N'5'
               GROUP BY [Sku]
            )
            SELECT  @nPickingDropIdWeight  = SUM([SKU].[STDGROSSWGT] * ([Pick].[Qty] - ISNULL([Packed].[PackedQTY], 0)))
               ,@nPickingDropIdCube    = SUM([PACK].[WidthUOM3] * [PACK].[LengthUOM3] * [PACK].[HeightUOM3] * ([Pick].[Qty] - ISNULL([Packed].[PackedQTY], 0)))
            FROM [Pick]
               INNER JOIN [dbo].[SKU]  WITH (NOLOCK) ON  [SKU].[Storerkey] = @cStorerKey AND [Pick].[Sku] = [SKU].[Sku]
               INNER JOIN [dbo].[PACK] WITH (NOLOCK) ON  [SKU].[PACKKey] = [PACK].[PackKey]
               LEFT  JOIN [Packed]                   ON  [Pick].[Sku] = [Packed].[SKU]

            SELECT @cOrderStorerKey = [Storerkey]
               ,@cOrderConsigneeKey = [ConsigneeKey]
               ,@cOrderC_Zip        = [C_Zip]
            FROM [dbo].[ORDERS] WITH (NOLOCK)
            WHERE [Orderkey] = @cOrderKey
            IF @@ROWCOUNT = 0
            BEGIN
               GOTO Quit
            END

            SELECT @cCustomerPalletType         = [Pallet]
               ,@cCustomerPalletCube            = [SUSR1]
               ,@cCustomerPalletHeight          = [SUSR2]
               ,@cCustomerPalletWeight          = [SUSR3]
               ,@cCustomerPalletMixBrands       = [SUSR4]
               ,@cCustomerPalletProductGrouping = [CreditLimit]
            FROM [dbo].[STORER] WITH (NOLOCK)
            WHERE [Address1] = @cOrderConsigneeKey
               AND [ConsigneeFor] = @cOrderStorerKey
               AND [Zip] = @cOrderC_Zip
               AND [Type] = 2

            SELECT @cCustomerPalletType         = CASE WHEN ISNULL(@cCustomerPalletType, N'')            = N'' THEN [Pallet]      ELSE @cCustomerPalletType            END
               ,@cCustomerPalletCube            = CASE WHEN ISNULL(@cCustomerPalletCube, N'')            = N'' THEN [SUSR1]       ELSE @cCustomerPalletCube            END
               ,@cCustomerPalletHeight          = CASE WHEN ISNULL(@cCustomerPalletHeight, N'')          = N'' THEN [SUSR2]       ELSE @cCustomerPalletHeight          END
               ,@cCustomerPalletWeight          = CASE WHEN ISNULL(@cCustomerPalletWeight, N'')          = N'' THEN [SUSR3]       ELSE @cCustomerPalletWeight          END
               ,@cCustomerPalletMixBrands       = CASE WHEN ISNULL(@cCustomerPalletMixBrands, N'')       = N'' THEN [SUSR4]       ELSE @cCustomerPalletMixBrands       END
               ,@cCustomerPalletProductGrouping = CASE WHEN ISNULL(@cCustomerPalletProductGrouping, N'') = N'' THEN [CreditLimit] ELSE @cCustomerPalletProductGrouping END
            FROM [dbo].[STORER] WITH (NOLOCK)
            WHERE [StorerKey] = @cDefaultConsigneeKey
               AND [ConsigneeFor] = @cStorerKey
               AND [Type] = 2

            SELECT @cCustomerOrderType = [Ordertype] FROM [dbo].[StorerSODefault] WITH(NOLOCK) WHERE [StorerKey] = @cOrderConsigneeKey
            IF ISNULL(@cCustomerOrderType, N'') = N''
            BEGIN
               SELECT @cCustomerOrderType = [Ordertype] FROM [dbo].[StorerSODefault] WITH(NOLOCK) WHERE [StorerKey] = @cDefaultConsigneeKey
            END

            -- check pallet type
            IF ISNULL(@cCustomerPalletType, N'') <> N'' AND @cPickingDropIdPalletType <> @cCustomerPalletType
            BEGIN
               SET @nWarningNo = 223301
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- check height limit
            IF ISNULL(@cCustomerPalletHeight, N'') <> N'' AND CAST(@cCustomerPalletHeight AS FLOAT) < @nPickingDropIdHeight
            BEGIN
               SET @nWarningNo = 223302
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- check weight limit
            IF ISNULL(@cCustomerPalletWeight, N'') <> N'' AND CAST(@cCustomerPalletWeight AS FLOAT) < @nPickingDropIdWeight
            BEGIN
               SET @nWarningNo = 223303
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- check pallet cube
            IF ISNULL(@cCustomerPalletCube, N'') <> N'' AND CAST(@cCustomerPalletCube AS FLOAT) < @nPickingDropIdCube
            BEGIN
               SET @nWarningNo = 223304
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- S/N scan
            IF EXISTS(
               SELECT 1 
               FROM [PickDetail]    WITH (NOLOCK)
                  INNER JOIN [SKU]  WITH (NOLOCK) ON  [PickDetail].[Storerkey] = [SKU].[Storerkey]  AND [PickDetail].[Sku] = [SKU].[Sku]
               WHERE  [PickDetail].[StorerKey]  = @cStorerKey
                  AND [PickDetail].[DropID]     = @cFromDropID
                  AND [PickDetail].[Status]     <= N'5'
                  AND [SKU].[SerialNoCapture] IN (N'1', N'3')
            )
            BEGIN
               SET @nWarningNo = 223305
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- VAS
            IF ISNULL(@cCustomerOrderType, N'') = N'Y'
            BEGIN
               SET @nWarningNo = 223306
               SET @cWarningMessage = [RDT].[rdtGetMessageLong]( @nWarningNo, @cLangCode, N'DSP')
               INSERT INTO @tWarnings([Message])
               VALUES (@cWarningMessage)
            END

            -- IF NOT EXISTS(SELECT 1 FROM @tWarnings)
            -- BEGIN
            --    GOTO Quit
            -- END

            SET @cOutField01  = @cPackDtlDropID
            SET @cOutField02  = @cCustomerPalletType
            SET @cOutField03  = @cCustomerPalletHeight
            SET @cOutField04  = @cCustomerPalletCube
            SET @cOutField05  = N''
            SET @cOutField06  = N''
            SET @cOutField07  = N''
            SET @cOutField08  = N''
            SET @cOutField09  = N''
            SET @cOutField10  = N''
            SELECT @cOutField05  = [Message] FROM @tWarnings WHERE [ID] = 1
            SELECT @cOutField06  = [Message] FROM @tWarnings WHERE [ID] = 2
            SELECT @cOutField07  = [Message] FROM @tWarnings WHERE [ID] = 3
            SELECT @cOutField08  = [Message] FROM @tWarnings WHERE [ID] = 4
            SELECT @cOutField09  = [Message] FROM @tWarnings WHERE [ID] = 5
            SELECT @cOutField10  = [Message] FROM @tWarnings WHERE [ID] = 6

            SET @nAfterScn    = @nScn_ExtScn04
            SET @nAfterStep   = @nStep_ExtScn
            GOTO Quit
         END
      END
      
      IF @nMOBRECStep = @nStep_Statistic
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cInField09 = N'1'
            BEGIN
               IF @cAddPackValidtn <> N'1'
               BEGIN
                  GOTO Quit
               END

               SELECT TOP 1 @cOrderKey = OrderKey
               FROM [dbo].[PickDetail] (NOLOCK)
               WHERE [StorerKey]  = @cStorerKey 
                  AND [DropID] = @cFromDropID

               SELECT @cOrderStorerKey = [Storerkey]
                  ,@cOrderConsigneeKey = [ConsigneeKey]
                  ,@cOrderC_Zip        = [C_Zip]
               FROM [dbo].[ORDERS] WITH (NOLOCK)
               WHERE [Orderkey] = @cOrderKey
               IF @@ROWCOUNT = 0
               BEGIN
                  GOTO Quit
               END

               SELECT @cCustomerPalletType   = [Pallet]
               FROM [dbo].[STORER] WITH (NOLOCK)
               WHERE [StorerKey] = @cOrderConsigneeKey
                  AND [ConsigneeFor] = @cOrderStorerKey
                  AND [Zip] = @cOrderC_Zip
                  AND [Type] = 2

               SELECT @cCustomerPalletType   = CASE WHEN ISNULL(@cCustomerPalletType, N'') = N'' THEN [Pallet] ELSE @cCustomerPalletType END
               FROM [dbo].[STORER] WITH (NOLOCK)
               WHERE [StorerKey] = @cDefaultConsigneeKey
                  AND [ConsigneeFor] = @cStorerKey
                  AND [Type] = 2

               IF NOT EXISTS (SELECT 1 FROM [dbo].[PALLET] (NOLOCK) WHERE [PalletKey] = @cPackDtlDropID)
               BEGIN
                  INSERT [dbo].[PALLET] ([PalletKey],[StorerKey],[Status],[EffectiveDate],[AddDate],[AddWho],[EditDate],[EditWho],[TrafficCop],[ArchiveCop],[TimeStamp],[Length],[Width],[Height],[GrossWgt],[PalletType])
                  VALUES(@cPackDtlDropID, @cStorerKey,NULL,GETDATE(),GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),NULL,NULL,NULL,0,0,0,0,@cCustomerPalletType)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 223307
                     SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') --INS PALLET Fail
                     GOTO Quit
                  END
               END
            END
         END
      END

      IF @nMOBRECStep = @nStep_ExtScn
      BEGIN
         IF @nMOBRECScn = @nScn_ExtScn04
         BEGIN
            IF @nInputKey = 0 --ESC
            BEGIN
               -- Go to PickSlipNo screen,Scn = 4650, Step = 1
               SET @nAfterScn    = @nScn_PickSlipNo
               SET @nAfterStep   = @nStep_PickSlipNo
               SET @cOutField01 = CASE WHEN @cShowPickSlipNo = '1' THEN @cPickSlipNo ELSE N'' END
               SET @cOutField02  = N''
               SET @cOutField03  = N''
               SET @cOutField04  = N''
               SET @cOutField05  = N''
               SET @cOutField06  = N''
               SET @cOutField07  = N''
               SET @cOutField08  = N''
               SET @cOutField09  = N''
               SET @cOutField10  = N''
               IF @cOutField01 <> ''
                  EXEC [rdt].[rdtSetFocusField] @nMobile, 2  -- focus FromDropID
               ELSE
                  EXEC [rdt].[rdtSetFocusField] @nMobile, 1  -- focus PickSlipNo

               GOTO Quit
            END --inputkey 0
            ELSE IF @nInputKey = 1
            BEGIN
               SET @nCartonNo    = 0
               SET @cLabelNo     = N''
               SET @cCustomNo    = N''
               SET @cCustomID    = N''
               SET @nCartonSKU   = 0
               SET @nCartonQTY   = 0
               SET @nTotalCarton = 0
               SET @nTotalPick   = 0
               SET @nTotalPack   = 0
               SET @nTotalShort  = 0

               -- Get task
               EXEC [rdt].[rdt_Pack_GetStat] @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, N'NEXT'
                  ,@cPickSlipNo
                  ,@cFromDropID
                  ,@cPackDtlDropID
                  ,@nCartonNo    OUTPUT
                  ,@cLabelNo     OUTPUT
                  ,@cCustomNo    OUTPUT
                  ,@cCustomID    OUTPUT
                  ,@nCartonSKU   OUTPUT
                  ,@nCartonQTY   OUTPUT
                  ,@nTotalCarton OUTPUT
                  ,@nTotalPick   OUTPUT
                  ,@nTotalPack   OUTPUT
                  ,@nTotalShort  OUTPUT
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               -- Go to Statistic screen, Scn = 4651,, Step = 2
               -- Prepare next screen var
               SET @nAfterScn    = @nScn_Statistic
               SET @nAfterStep   = @nStep_Statistic
               SET @cOutField01  = @cPickSlipNo
               SET @cOutField02  = CAST( @nTotalPick AS NVARCHAR(8))
               SET @cOutField03  = CAST( @nTotalPack AS NVARCHAR(8))
               SET @cOutField04  = CAST( @nTotalShort AS NVARCHAR(8))
               SET @cOutField05  = RTRIM( @cCustomNo) + N'/' + CAST( @nTotalCarton AS NVARCHAR(5))
               SET @cOutField06  = @cCustomID
               SET @cOutField07  = CAST( @nCartonSKU AS NVARCHAR(5))
               SET @cOutField08  = CAST( @nCartonQTY AS NVARCHAR(5))
               SET @cOutField09  = @cDefaultOption
               SET @cOutField10  = N''
               GOTO Quit
            END

            GOTO Quit
         END
      END

   END

   GOTO Quit

Quit:

END

GO