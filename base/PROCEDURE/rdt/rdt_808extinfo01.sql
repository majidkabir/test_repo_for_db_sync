SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_808ExtInfo01                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-03-15 1.0  Ung        WMS-4247 Created                                */
/* 2022-03-15 1.1  Ung        WMS-18742 Add rdt_PTLCart_Assign_Totes03_Lottable*/
/******************************************************************************/

CREATE   PROC [RDT].[rdt_808ExtInfo01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cLight         NVARCHAR( 1),
   @cDPLKey        NVARCHAR( 10),
   @cCartID        NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cMethod        NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cToteID        NVARCHAR( 20),
   @nQTY           INT,
   @cNewToteID     NVARCHAR( 20),
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
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMethodSP SYSNAME
   DECLARE @cLoadKey  NVARCHAR(10)
   DECLARE @cErrMsg1  NVARCHAR(20)

   IF @nFunc = 808 -- PTLCart
   BEGIN
      IF @nAfterStep = 3 -- SKU
      BEGIN
         -- Get method info
         SET @cMethodSP = ''
         SELECT @cMethodSP = ISNULL( UDF01, '')
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'CartMethod'
            AND Code = @cMethod
            AND StorerKey = @cStorerKey

         -- Assign PickslipPosTote_Lottable
         IF @cMethodSP = 'rdt_PTLCart_Assign_PickslipPosTote_Lottable'
         BEGIN
            DECLARE @cPickSlipNo    NVARCHAR(10)
            DECLARE @cConsigneeKey  NVARCHAR(15)
            DECLARE @cZone          NVARCHAR(18)
            DECLARE @cOrderKey      NVARCHAR(10)
            DECLARE @cPickConfirmStatus NVARCHAR(1)
            DECLARE @cVASIndicator  NVARCHAR(1)
            DECLARE @cSKUInMultiLOC NVARCHAR(1)

            DECLARE @curPSNO        CURSOR
            DECLARE @curOrder       CURSOR

            -- Storer configure
            SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
            IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
               SET @cPickConfirmStatus = '5'  -- 5=Pick confirm

            SET @cVASIndicator = ''
            SET @cSKUInMultiLOC = ''

            -- Loop PickSlipNo
            SET @curPSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SourceKey
               FROM PTL.PTLTran WITH (NOLOCK)
               WHERE DeviceProfileLogKey = @cDPLKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND Lottable04 = @dLottable04
            OPEN @curPSNO
            FETCH NEXT FROM @curPSNO INTO @cPickSlipNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get PickHeader info
               SELECT
                  @cZone = Zone,
                  @cOrderKey = ISNULL( OrderKey, ''),
                  @cLoadKey = ExternOrderKey
               FROM PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               IF @cVASIndicator = ''
               BEGIN
                  -- XDock
                  IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  BEGIN
                     SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT DISTINCT O.OrderKey
                        FROM Orders O WITH (NOLOCK)
                           JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                           JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                        WHERE RKL.PickslipNo = @cPickSlipNo
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           AND PD.LOC = @cLOC
                           AND PD.Status < @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                  END

                  -- Conso
                  ELSE IF @cOrderKey = ''
                  BEGIN
                     SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT DISTINCT O.OrderKey
                        FROM LoadPlanDetail LPD WITH (NOLOCK)
                           JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                           JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                        WHERE LPD.Loadkey = @cLoadKey
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           AND PD.LOC = @cLOC
                           AND PD.Status < @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                  END

                  -- Discrete
                  ELSE
                  BEGIN
                     SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT DISTINCT O.OrderKey
                        FROM Orders O WITH (NOLOCK)
                           JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                        WHERE O.OrderKey = @cOrderKey
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           AND PD.LOC = @cLOC
                           AND PD.Status < '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                  END

                  OPEN @curOrder
                  FETCH NEXT FROM @curOrder INTO @cOrderKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Get order info
                     SELECT @cConsigneeKey = ConsigneeKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                     -- Check consignee SKU any VAS
                     IF EXISTS( SELECT 1
                        FROM ConsigneeSKU WITH (NOLOCK)
                        WHERE ConsigneeKey = @cConsigneeKey
                           AND StorerKey = @cStorerKey
                           AND SKU = @cSKU
                           AND (UDF01 <> '' OR UDF02 <> '' OR UDF03 <> '')) -- VAS
                     BEGIN
                        SET @cVASIndicator = 'Y'
                        GOTO Quit
                     END

                     FETCH NEXT FROM @curOrder INTO @cOrderKey
                  END
               END

               IF @cSKUInMultiLOC = ''
               BEGIN
                  -- XDock
                  IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  BEGIN
                     IF EXISTS( SELECT TOP 1 1
                        FROM Orders O WITH (NOLOCK)
                           JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                           JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                        WHERE RKL.PickslipNo = @cPickSlipNo
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           -- AND PD.LOC = @cLOC
                           AND PD.Status <= @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                        HAVING COUNT( DISTINCT PD.LOC) > 1)
                     BEGIN
                        SET @cSKUInMultiLOC = 'Y'
                     END
                  END

                  -- Conso
                  ELSE IF @cOrderKey = ''
                  BEGIN
                     IF EXISTS( SELECT TOP 1 1
                        FROM LoadPlanDetail LPD WITH (NOLOCK)
                           JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                           JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                        WHERE LPD.Loadkey = @cLoadKey
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           -- AND PD.LOC = @cLOC
                           AND PD.Status <= @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                        HAVING COUNT( DISTINCT PD.LOC) > 1)
                     BEGIN
                        SET @cSKUInMultiLOC = 'Y'
                     END
                  END

                  -- Discrete
                  ELSE
                  BEGIN
                     IF EXISTS( SELECT TOP 1 1
                        FROM Orders O WITH (NOLOCK)
                           JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                        WHERE O.OrderKey = @cOrderKey
                           AND PD.StorerKey = @cStorerKey
                           AND PD.SKU = @cSKU
                           -- AND PD.LOC = @cLOC
                           AND PD.Status <= @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC'
                           AND O.SOStatus <> 'CANC'
                        HAVING COUNT( DISTINCT PD.LOC) > 1)
                     BEGIN
                        SET @cSKUInMultiLOC = 'Y'
                     END
                  END
               END

               IF @cVASIndicator = 'Y' AND @cSKUInMultiLOC = 'Y'
                  BREAK

               FETCH NEXT FROM @curPSNO INTO @cPickSlipNo
            END

            -- VAS indicator
            IF @cVASIndicator = 'Y'
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 124351, @cLangCode, 'DSP') --[**]
               SET @cExtendedInfo = @cExtendedInfo + RTRIM( @cErrMsg1)
            END

            -- SKU in multi LOC
            IF @cSKUInMultiLOC = 'Y'
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 124352, @cLangCode, 'DSP') --[MULTI LOC]
               SET @cExtendedInfo = @cExtendedInfo + RTRIM( @cErrMsg1)
            END
         END
      END

      IF @nStep = 4 AND    -- Matrix
         @nAfterStep = 1   -- Cart ID
      BEGIN
         -- Get method info
         SET @cMethodSP = ''
         SELECT @cMethodSP = ISNULL( UDF01, '')
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'CartMethod'
            AND Code = @cMethod
            AND StorerKey = @cStorerKey

         -- rdt_PTLCart_Assign_BatchTotes
         IF @cMethodSP = 'rdt_PTLCart_Assign_Totes03_Lottable'
         BEGIN
            -- Get task info
            DECLARE @cFinalLOC NVARCHAR(10) = ''
            SELECT TOP 1 @cLoadKey = LoadKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
            SELECT TOP 1 
               @cFinalLOC = FinalLOC 
            FROM TaskDetail TD WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND TD.StorerKey = @cStorerKey
               AND TD.TaskType = 'CPK'
               AND TD.LoadKey = @cLoadKey

            -- Check short pick
            IF @cFinalLOC <> ''
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 124353, @cLangCode, 'DSP') --FINAL LOC: 
               SET @cErrMsg1 = RTRIM( @cErrMsg1) + @cFinalLOC

               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg1
            END
         END
      END
      
   END

Quit:

END

GO