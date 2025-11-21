SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_957ExtUpd02                                           */
/* Copyright      : Maersk                                                    */ 
/* Purpose:Extended Puma                                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.   Purposes                                     */
/* 2024-07-16   JHU151    1.0    FCR-428 Created                              */
/* 2024-09-09   PXL009    1.1    FCR-770 Tote closure                         */
/* 2024-10-24   PXL009    1.1.1  FCR-770 UOM = 7 requested to be added        */
/*                                  when inserting the value WSTOTECFMlb.     */
/******************************************************************************/

CREATE       PROCEDURE [RDT].[rdt_957ExtUpd02]
    @nMobile         INT          
   ,@nFunc           INT          
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT          
   ,@nInputKey       INT          
   ,@cFacility       NVARCHAR( 5) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cSuggID         NVARCHAR( 18)
   ,@cSuggSKU        NVARCHAR( 20)
   ,@nSuggQTY        INT          
   ,@cOption         NVARCHAR( 1) 
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME     
   ,@dLottable05     DATETIME     
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME     
   ,@dLottable14     DATETIME     
   ,@dLottable15     DATETIME     
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT   
   DECLARE @nExists  INT
   DECLARE @cShort   NVARCHAR(20)

   DECLARE @cLoadKey       NVARCHAR( 10) = ''
   DECLARE @cOrderKey      NVARCHAR( 10) = ''
   DECLARE @cZone          NVARCHAR( 18) = ''
   DECLARE @curOrder       CURSOR
   DECLARE @cActUCCNo      NVARCHAR( 40) = ''
   DECLARE @cActDropID     NVARCHAR( 40) = ''
   DECLARE @cActCaseID     NVARCHAR( 40) = ''
   DECLARE @curPickDetail  CURSOR
   DECLARE @cUOM           NVARCHAR( 10) = ''

   DECLARE
      @cStoredProcedure  NVARCHAR(50),
      @cCCTaskType       NVARCHAR(60),
      @cHoldType         NVARCHAR(60),
      @cSQL              NVARCHAR(MAX),
      @cSQLParam         NVARCHAR(MAX),
      @cLOC              NVARCHAR(10), 
      @cLot              NVARCHAR(10),
      @cID               NVARCHAR(20),
      @cSKU              NVARCHAR(20),
      @cReasonCode       NVARCHAR(20),
      @b_Success         INT,
      @n_err             INT,
      @cPickDetailKey    NVARCHAR(50) = '',
      @c_errmsg          NVARCHAR(250)
         
   SET @nErrNo          = 0
   SET @cErrMSG         = ''
   
   
   IF @nFunc = 957
   BEGIN
      IF @nStep = 1 -- PickZone
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            
            /*
               The auto scan-in at parent module, sometimes does not trigger update Orders.Status = 3
               
               Exceed base, scan-in backgroup (ntrPickingInfoAdd or isp_ScanInPickslip):
                  insert PickingInfo, with pickslip, date and picker, whether trigger update Orders.Status = 3
                     if cross dock pickslip, not trigger 
                     if discrete pickslip, trigger
                     if conso pickslip , trigger
                     if customize pickslip, not trigger 
                     
                     Note: Cross dock and customize pickslip, works on Order line level, not at order level

                  Update PickingInfo, with date and picker, does not trigger Orders.Status = 3
            */
            
            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo
      
            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
               SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT DISTINCT O.OrderKey
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND O.Status < '3'

            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
               SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT OrderKey
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                     AND Status < '3'
               
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
               SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT DISTINCT O.OrderKey
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                     JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
                     AND O.Status < '3'
            
            -- Custom PickSlip
            ELSE
               SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT DISTINCT O.OrderKey
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND O.Status < '3'
            
            -- Loop orders
            OPEN @curOrder
            FETCH NEXT FROM @curOrder INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update order 
               UPDATE dbo.Orders SET
                  Status = '3', -- In-progress
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE OrderKey = @cOrderKey
               SET @nErrNo = @@ERROR 
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 
                  GOTO Quit
               END
               FETCH NEXT FROM @curOrder INTO @cOrderKey
            END
         END
      END
      
      IF @nStep = 3
      BEGIN
         -- 
         IF @nInputKey = 1
         BEGIN
            /*--------------------------------------------------------------------------------------------------
                                                         Innobec
            --------------------------------------------------------------------------------------------------*/
            IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'Innobec') = '1'
            BEGIN

               SET @cLOC = @cSuggLOC
               SET @cID = @cSuggID
               SET @cSKU = @cSuggSKU

               SELECT @cActUCCNo = I_Field05
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Get PickHeader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo
         
               -- Cross dock PickSlip
               IF @cZone IN ('XD', 'LB', 'LP')
                  SET @curPickDetail = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT PD.OrderKey,PD.DropID,PD.CaseID,PD.UOM
                     FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                     WHERE RKL.PickSlipNo = @cPickSlipNo
                        AND PD.LOC = @cLOC
                        AND PD.SKU = @cSKU
                        AND PD.ID = @cID
                        AND PD.QTY > 0
                        AND (PD.Status = '3' OR PD.Status = '5')
               -- Discrete PickSlip
               ELSE IF @cOrderKey <> ''
                  SET @curPickDetail = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT PD.OrderKey,PD.DropID,PD.CaseID,PD.UOM
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     WHERE PD.OrderKey = @cOrderKey
                        AND PD.LOC = @cLOC
                        AND PD.SKU = @cSKU
                        AND PD.ID = @cID
                        AND PD.Qty > 0
                        AND (PD.Status = '3' OR PD.Status = '5')
               -- Conso PickSlip
               ELSE IF @cLoadKey <> ''
                  SET @curPickDetail = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT PD.OrderKey,PD.DropID,PD.CaseID,PD.UOM
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                     WHERE LPD.LoadKey = @cLoadKey
                        AND PD.LOC = @cLOC
                        AND PD.SKU = @cSKU
                        AND PD.ID = @cID
                        AND PD.Qty > 0
                        AND (PD.Status = '3' OR PD.Status = '5')
               -- Custom PickSlip
               ELSE
                  SET @curPickDetail = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT PD.OrderKey,PD.DropID,PD.CaseID,PD.UOM
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     WHERE PD.PickSlipNo = @cPickSlipNo
                        AND PD.LOC = @cLOC
                        AND PD.SKU = @cSKU
                        AND PD.ID = @cID
                        AND PD.Qty > 0
                        AND (PD.Status = '3' OR PD.Status = '5')
               
               -- Loop Pick Detail
               OPEN @curPickDetail
               FETCH NEXT FROM @curPickDetail INTO @cOrderKey,@cActDropID,@cActCaseID,@cUOM
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @cUOM = '7' AND @cActDropID <> ''
                  BEGIN
                     EXEC dbo.ispGenTransmitLog2
                        @c_TableName      = 'WSTOTECFMlb',
                        @c_Key1           = @cOrderKey,
                        @c_Key2           = @cActDropID,
                        @c_Key3           = @cStorerKey,
                        @c_TransmitBatch  = '',
                        @b_success        = @bSuccess    OUTPUT,
                        @n_err            = @nErrNo      OUTPUT,
                        @c_errmsg         = @cErrMsg     OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 223451
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
                        GOTO Quit
                     END
                  END

                  IF @cUOM = '2' AND @cActCaseID <> ''
                  BEGIN
                     EXEC dbo.ispGenTransmitLog2
                        @c_TableName      = 'WSBOXCFMlb',
                        @c_Key1           = @cOrderKey,
                        @c_Key2           = @cActCaseID,
                        @c_Key3           = @cStorerKey,
                        @c_TransmitBatch  = '',
                        @b_success        = @bSuccess    OUTPUT,
                        @n_err            = @nErrNo      OUTPUT,
                        @c_errmsg         = @cErrMsg     OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 223452
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
                        GOTO Quit
                     END
                  END

                  FETCH NEXT FROM @curPickDetail INTO @cOrderKey,@cActDropID,@cActCaseID,@cUOM
               END
            END
         END
      END

      IF @nStep = 5
      BEGIN
         -- Short pick
         IF @nInputKey = 1
         BEGIN                     
            -- Short
            IF @cOption = '1'
            BEGIN
               SELECT 
                  @cReasonCode = Code2,
                  @cCCTaskType = UDF01,-- CC task type
                  @cHoldType = UDF02 -- Hold type
               FROM codelkup 
               WHERE listname = 'RDTREASON'
               AND code = @nFunc
               AND storerkey = @cStorerKey

               SET @cLoc = @cSuggLOC
               SET @cID = @cSuggID
               SET @cSKU = @cSuggSKU

               SET @cStoredProcedure = rdt.rdtGetConfig( @nFunc, 'ActRDTreason', @cStorerKey)
               IF @cStoredProcedure = '0'
                  SET @cStoredProcedure = ''
                     
               IF @cStoredProcedure <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cStoredProcedure AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cStoredProcedure) +
                           ' @nMobile, @nFunc, @cStorerKey, ' +
                           ' @cSKU, @cLOC, @cLot, @cID, @cReasonCode, ' +                      
                           ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                           ' @nMobile         INT                      ' +
                           ',@nFunc           INT                      ' +
                           ',@cStorerKey      NVARCHAR( 15)            ' +
                           ',@cSKU            NVARCHAR( 20)            ' +
                           ',@cLOC            NVARCHAR( 10)            ' +
                           ',@cLot            NVARCHAR( 10)            ' +
                           ',@cID             NVARCHAR( 20)            ' +
                           ',@cReasonCode     NVARCHAR( 20)            ' +                          
                           ',@nErrNo          INT           OUTPUT     ' +
                           ',@cErrMsg         NVARCHAR(250) OUTPUT  '

                     SELECT TOP 1
                           @cOrderKey = OrderKey,
                           @cLoadKey = ExternOrderKey,
                           @cZone = Zone
                     FROM dbo.PickHeader WITH (NOLOCK)
                     WHERE PickHeaderKey = @cPickSlipNo

                     WHILE (1=1)
                     BEGIN
                        -- Cross dock PickSlip
                        IF @cZone IN ('XD', 'LB', 'LP')
                        BEGIN
                           SELECT TOP 1
                              @cPickDetailKey = PD.PickDetailKey,
                              @cLot = Lot,
                              @cID = ID
                           FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                              JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                           WHERE RKL.PickSlipNo = @cPickSlipNo
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                    (@nFunc = 839  AND PD.status = '4')
                                    OR 
                                    (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                    )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE IF @cOrderKey <> ''
                        BEGIN
                           SELECT TOP 1
                              @cPickDetailKey = PD.PickDetailKey,
                              @cLot = Lot,
                              @cID = ID
                           FROM dbo.PickDetail PD WITH (NOLOCK)
                              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE PD.OrderKey = @cOrderKey
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                    (@nFunc = 839  AND PD.status = '4')
                                    OR 
                                    (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                    )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE IF @cLoadKey <> ''
                        BEGIN
                           
                           SELECT TOP 1
                                 @cPickDetailKey = PD.PickDetailKey,
                                 @cLot = Lot,
                                 @cID = ID
                           FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                              JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE LPD.LoadKey = @cLoadKey
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                 (@nFunc = 839  AND PD.status = '4')
                                 OR 
                                 (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                 )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE
                        BEGIN
                           SELECT TOP 1
                                 @cPickDetailKey = PD.PickDetailKey,
                                 @cLot = Lot,
                                 @cID = ID
                           FROM dbo.PickDetail PD WITH (NOLOCK)
                           JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE PD.PickSlipNo = @cPickSlipNo
                           AND PD.LOC = @cLOC
                           AND PD.SKU = @cSKU
                           AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                 (@nFunc = 839  AND PD.status = '4')
                                 OR 
                                 (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                 )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END


                        IF @@ROWCOUNT = 0
                        BEGIN
                           BREAK
                        END
                        
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                              @nMobile, @nFunc, @cStorerKey,
                              @cSKU, @cLOC, @cLot, @cID, @cReasonCode,
                              @nErrNo OUTPUT, @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                              GOTO Quit

                     END
                  END
               END
            END
         END
      END
   END
Quit:


END

GO