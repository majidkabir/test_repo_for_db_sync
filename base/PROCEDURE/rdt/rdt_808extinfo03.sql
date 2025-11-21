SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_808ExtInfo03                                          */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2019-05-06 1.0  James      WMS8585. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_808ExtInfo03] (  
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
   DECLARE @cUserName NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
  
   IF @nFunc = 808 -- PTLCart  
   BEGIN  
      IF 3 IN ( @nAfterStep, @nStep) -- SKU  
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
            DECLARE @cOrderKey      NVARCHAR(10)  
            DECLARE @cLoadKey       NVARCHAR(10)  
            DECLARE @cPickConfirmStatus NVARCHAR(1)  
            DECLARE @cZone          NVARCHAR( 18)
            DECLARE @cPSType        NVARCHAR( 10)
                 
            -- Storer configure  
            SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
            IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress  
               SET @cPickConfirmStatus = '5'  -- 5=Pick confirm  

            --SELECT TOP 1 @cPickSlipNo = PickSlipNo
            --FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            --WHERE CartID = @cCartID
            --AND   Method = @cMethod
            --AND ( PickZone = @cPickZone OR PickZone = '')
            --ORDER BY 1

            SELECT TOP 1 @cPickSlipNo = PickSlipNo
            FROM PTL.PTLTRAN PTL WITH (NOLOCK) 
            JOIN rdt.rdtPTLCartLog CART WITH (NOLOCK) ON 
               ( PTL.DeviceID = CART.CartID and PTL.SourceKey = CART.PickslipNo and PTL.DeviceProfileLogKey = CART.DeviceProfileLogKey)
            WHERE PTL.StorerKey = @cStorerKey
            AND   PTL.SKU = @cSKU
            AND   PTL.LOC = @cLOC
            AND   PTL.Status = '0'
            AND   CART.CartID = @cCartID
            AND   CART.AddWho = @cUserName
            AND   CART.Method = @cMethod
            ORDER BY 1
            --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, step2) values 
            --('808', getdate(), @cStorerKey, @cSKU, @cLOC, @cCartID, @cUserName, @cMethod, @cPickSlipNo)
            -- Get PickHeader info
            SELECT 
               @cZone = Zone, 
               @cOrderKey = ISNULL( OrderKey, ''), 
               @cLoadKey = ExternOrderKey
            FROM PickHeader WITH (NOLOCK) 
            WHERE PickHeaderKey = @cPickSlipNo
      
            -- Get PickSlip type
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
               SET @cPSType = 'XD'
            ELSE IF @cOrderKey = ''
               SET @cPSType = 'CONSO'
            ELSE
               SET @cPSType = 'DISCRETE'

            -- Check PickDetail tally PTLTran
            IF @cPSType = 'DISCRETE'
               SELECT TOP 1 @cLottable02 = LA.Lottable02
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)
               WHERE PD.OrderKey = @cOrderKey
               AND   PD.StorerKey = @cStorerKey
               AND   PD.SKU = @cSKU
               AND   PD.LOC = @cLOC
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.Status <> '4'
               AND   PD.QTY > 0
               ORDER BY LA.Lottable04, LA.Lottable05
               --insert into traceinfo (tracename, timein, STEP1, col1, col2, col3, col4, col5) values
               --('898', getdate(), @cLottable02, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @cPickConfirmStatus)

            IF @cPSType = 'CONSO'
               SELECT TOP 1 @cLottable02 = LA.Lottable02
               FROM LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)
               WHERE LPD.Loadkey = @cLoadKey
               AND   PD.StorerKey = @cStorerKey
               AND   PD.SKU = @cSKU
               AND   PD.LOC = @cLOC
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.Status <> '4'
               AND   PD.QTY > 0
               ORDER BY LA.Lottable04, LA.Lottable05
   
            IF @cPSType = 'XD'
               SELECT TOP 1 @cLottable02 = LA.Lottable02
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON ( RKL.PickDetailKey = PD.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)
               WHERE RKL.PickslipNo = @cPickSlipNo
               AND   PD.StorerKey = @cStorerKey
               AND   PD.SKU = @cSKU
               AND   PD.LOC = @cLOC
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.Status <> '4'
               AND   PD.QTY > 0
               ORDER BY LA.Lottable04, LA.Lottable05


               SET @cExtendedInfo = @cLottable02

         END  
      END  
   END  
     
Quit:  
  
END  

GO