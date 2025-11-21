SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_957ExtUpd01                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Set Orders.Status = 3                                             */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-12-08   Ung       1.0   WMS-24353 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_957ExtUpd01]
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

   IF @nFunc = 957 -- Pick case
   BEGIN      
      IF @nStep = 1 -- PickZone
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cLoadKey  NVARCHAR( 10) = ''
            DECLARE @cOrderKey NVARCHAR( 10) = ''
            DECLARE @cZone     NVARCHAR( 18) = ''
            DECLARE @curOrder  CURSOR
            
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
   END

Quit:

END

GO