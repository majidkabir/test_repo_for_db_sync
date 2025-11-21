SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_839ExtUpd06                                           */
/* Copyright      : Maersk                                                    */ 
/* Purpose:Extended Update for Pick piece                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-12-01   Tony      1.0   WMS-24315 Created                             */
/* 2024-04-11   NLT013    2.0   UWP-18212 Need trigger EDI while short pick   */
/******************************************************************************/

CREATE       PROCEDURE [RDT].[rdt_839ExtUpd06]
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
   ,@cLOC            NVARCHAR( 10)          
   ,@cSKU            NVARCHAR( 20)          
   ,@nQTY            INT                    
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
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)  
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

         
   SET @nErrNo          = 0
   SET @cErrMSG         = ''
   
   IF @nFunc = 839
   BEGIN
      --Picking slip No Capture
      IF @nStep = 1
      BEGIN
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

    
      IF @nStep = 5 -- Close DropID or Short pick
      BEGIN
         IF @nInputKey = 1 AND @cOption IN ('1', '3') -- ENTER and close drop ID --NLT013 option = 1 is short pick, need trigger msg to WCS
         BEGIN
            -- Using drop ID, send tote to WCS
            IF @cDropID <> ''
            BEGIN
               --Trigger MSG to WCS 
               EXEC rdt.rdt_839SendMsgToWCS @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                  ,@cPickSlipNo
                  ,@cDropID
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      IF @nStep = 7 -- Confirm pick loc
      BEGIN
        IF @nInputKey = 0 --Esc
        BEGIN
           -- Using drop ID, send tote to WCS
           IF @cDropID <> ''
           BEGIN
              --Trigger MSG to WCS 
              EXEC rdt.rdt_839SendMsgToWCS @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                 ,@cPickSlipNo
                 ,@cDropID
                 ,@nErrNo       OUTPUT
                 ,@cErrMsg      OUTPUT
              IF @nErrNo <> 0
                 GOTO Quit
           END 
        END
      END

      IF @nStep = 8 -- Abort Picking
      BEGIN
        IF @nInputKey = 1 AND @cOption ='1' -- ENTER and close drop ID
        BEGIN
        -- Using drop ID, send tote to WCS
           IF @cDropID <> ''
           BEGIN
              --Trigger MSG to WCS 
              EXEC rdt.rdt_839SendMsgToWCS @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                 ,@cPickSlipNo
                 ,@cDropID
                 ,@nErrNo       OUTPUT
                 ,@cErrMsg      OUTPUT
              IF @nErrNo <> 0
                 GOTO Quit
           END 
        END
     END
   END

Quit:


END

GO