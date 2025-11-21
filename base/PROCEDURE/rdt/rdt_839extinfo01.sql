SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtInfo01                                    */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-02-26 1.0  ChewKP     WMS-4542 Created                          */  
/* 2019-06-20 1.1  James      WMS-9209 Add display pickzone qty(james01)*/  
/* 2021-01-07 1.2  Pakyuen    INC1381639 enhance performance (py01)     */  
/* 2021-04-15 1.3  SeongYaik  Bug Fix for PUMA FN839, Error when        */  
/*                            @nPZ_PickedQty exceeded 3 digits (SY01)   */ 
/* 2022-04-20 1.4  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839ExtInfo01] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,  
   @nAfterStep   INT,  
   @nInputKey    INT,  
   @cFacility    NVARCHAR( 5) ,  
   @cStorerKey   NVARCHAR( 15),  
   @cType        NVARCHAR( 10),  
   @cPickSlipNo  NVARCHAR( 10),  
   @cPickZone    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20),  
   @cLOC         NVARCHAR( 10),  
   @cSKU         NVARCHAR( 20),  
   @nQTY         INT,  
   @nActQty      INT,  
   @nSuggQTY     INT,
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),   
   @cExtendedInfo NVARCHAR(20) OUTPUT,  
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
IF @nFunc = 839  
BEGIN  
  
    DECLARE @nSumQty INT  
           ,@cDropIDShort NVARCHAR(4)  
           ,@cActQTY      NVARCHAR(5)  
           ,@nPZ_PickedQty INT  
           ,@nPZ_TotalQty  INT  
           ,@cOrderKey    NVARCHAR( 10)  
           ,@cLoadKey     NVARCHAR( 10)  
           ,@cZone        NVARCHAR( 18)  
           ,@cPickConfirmStatus NVARCHAR( 1)  
  
  
    SET @nErrNo          = 0  
    SET @cErrMSG         = ''  
  
    -- Get storer config  
    SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
    IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
    IF @nAfterStep = 3  
    BEGIN  
         -- Get PickHeader info  
         SELECT TOP 1  
            @cOrderKey = OrderKey,  
            @cLoadKey = ExternOrderKey,  
            @cZone = Zone  
         FROM dbo.PickHeader WITH (NOLOCK)  
         WHERE PickHeaderKey = @cPickSlipNo  
  
         -- Cross dock PickSlip  
         IF ISNULL( @cZone, '') IN ('XD', 'LB', 'LP')  
         BEGIN  
            SELECT @nPZ_TotalQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status <> '4'  
  
            SELECT @nPZ_PickedQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status = @cPickConfirmStatus  
  
            SELECT @nSumQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND   PD.DropID = @cDropID  
            AND   PD.Status <> '4'  
         END  
         -- Discrete PickSlip  
         ELSE IF ISNULL( @cOrderKey, '') <> ''  
         BEGIN  
     SELECT @nPZ_TotalQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status <> '4'  
  
            SELECT @nPZ_PickedQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status = @cPickConfirmStatus  
  
            SELECT @nSumQty = ISNULL( SUM( Qty),0)  
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
            AND   DropID = @cDropID  
            AND   Status <> '4'  
         END  
  
         -- Conso PickSlip  
         ELSE IF ISNULL( @cLoadKey, '') <> ''  
         BEGIN  
            SELECT @nPZ_TotalQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status <> '4'  
            AND   PD.Status <= '5' -- py01  
  
            SELECT @nPZ_PickedQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status = @cPickConfirmStatus  
  
            SELECT @nSumQty = ISNULL( SUM( PD.Qty),0)  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            WHERE LPD.LoadKey = @cLoadKey  
            AND   PD.DropID = @cDropID  
            AND   PD.Status <> '4'  
            AND   PD.Status <= '5' -- py01  
         END  
  
         -- Custom PickSlip  
         ELSE  
         BEGIN  
            SELECT @nPZ_TotalQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status <> '4'  
  
            SELECT @nPZ_PickedQty = ISNULL( SUM( PD.QTY), 0)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
            AND   LOC.PickZone = @cPickZone  
            AND   PD.Status = @cPickConfirmStatus  
  
            SELECT @nSumQty = ISNULL( SUM( Qty),0)  
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   PickSlipNo = @cPickSlipNo  
            AND   DropID = @cDropID  
            AND   Status <> '4'  
         END  
  
  
      --SELECT @nSumQty = ISNULL(SUM(Qty),0)  
      --FROM dbo.PickDetail WITH (NOLOCK)  
      --WHERE StorerKey = @cStorerKey  
      --AND PickSlipNo = @cPickSlipNo  
      --AND DropID = @cDropID  
  
      SET @cDropIDShort = RIGHT(@cDropID,4)  
  
  
      SET @nSumQty = @nSumQty + @nActQty  
  
      SET @nPZ_PickedQty = @nPZ_PickedQty + @nActQty  
  
      IF ISNULL( @cPickZone, '') <> ''  
         SET @cExtendedInfo = @cDropIDShort +  '/' + LEFT( CAST( @nSumQty AS NVARCHAR(4)) + SPACE( 4), 4) +  
                              ' ' +  
                              CAST( @nPZ_PickedQty AS NVARCHAR( 4)) + '/' + CAST( @nPZ_TotalQty AS NVARCHAR( 4))  --SY01  
      ELSE  
         SET @cExtendedInfo = @cDropIDShort +  '/' + LEFT( CAST( @nSumQty AS NVARCHAR(4)) + SPACE( 4), 4)  
  
  
    END  
  
END  
  
QUIT:

GO