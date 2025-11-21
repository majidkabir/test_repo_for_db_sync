SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1837ExtUpd03                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2022-01-25  1.0  yeekung    WMS-18506 Created (dup rdt_1837ExtUpd02)*/  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1837ExtUpd03] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cCartonID      NVARCHAR( 20),   
   @cPalletID      NVARCHAR( 20),   
   @cLoadKey       NVARCHAR( 10),   
   @cLoc           NVARCHAR( 10),   
   @cOption        NVARCHAR( 1),   
   @tExtUpdate     VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cPickSlipNo    NVARCHAR( 10)  
   DECLARE @bSuccess       INT  
     
   IF @nStep IN (1, 2) -- Carton ID/Pallet ID  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF ISNULL( @cCartonID, '') <> ''  
         BEGIN  
            -- Check if all carton scanned to PPS loc ( carton moved to PPS loc after scan)  
            IF EXISTS (   
               SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)  
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)  
               WHERE PD.StorerKey = @cStorerKey  
                  AND   PD.QTY > 0  
                  AND   LPD.LoadKey = @cLoadKey  
                  AND   LOC.Facility = @cFacility  
                  AND   (LOC.LocationCategory NOT IN ('PACK&HOLD','PPS','Staging') OR PD.Status <> '5' OR PD.[Status] = '4'))  
               GOTO Quit  
  
            SELECT TOP 1 @cOrderKey = O.OrderKey  
            FROM dbo.ORDERS O WITH (NOLOCK)  
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey )  
            WHERE O.StorerKey = @cStorerKey  
            AND   LPD.LoadKey = @cLoadKey  
            ORDER BY 1  
                 
            -- Get PickSlipNo (discrete)    
            SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
            IF @cPickSlipNo = ''      
               SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey    
  
            -- Get PickSlipNo (conso)    
            IF @cPickSlipNo = ''     
            BEGIN    
               SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = ''    
               IF @cPickSlipNo = ''      
                  SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey AND OrderKey = ''    
            END    
  
            -- Check PickSlip    
            IF @cPickSlipNo = ''     
            BEGIN    
               SET @nErrNo = 181201    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlipNo    
               GOTO Quit    
            END   
              
            DECLARE @cPackCfm CURSOR  
            SET @cPackCfm = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT PH.PickSlipNo   
            FROM dbo.PackHeader PH WITH (NOLOCK)   
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = PH.OrderKey)  
            WHERE LPD.LoadKey = @cLoadKey  
            OPEN @cPackCfm  
            FETCH NEXT FROM @cPackCfm INTO @cPickSlipNo  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)   
                           WHERE PickSlipNo = @cPickSlipNo   
                           AND   [Status] = '0')  
               BEGIN  
                  -- Pack confirm  
                  UPDATE dbo.PackHeader SET   
                     [Status] = '9'  
                  WHERE PickSlipNo = @cPickSlipNo  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 181202  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail  
                     GOTO Quit  
                  END  
                    
                  -- Get storer config    
                  DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)    
                  EXECUTE nspGetRight      
                     @cFacility,    
                     @cStorerKey,      
                     '', --@c_sku      
                     'AssignPackLabelToOrdCfg',      
                     @bSuccess                 OUTPUT,      
                     @cAssignPackLabelToOrdCfg OUTPUT,      
                     @nErrNo                   OUTPUT,      
                     @cErrMsg                  OUTPUT      
  
                  IF @nErrNo <> 0  
                  BEGIN  
                     SET @nErrNo = 181203  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail  
                     GOTO Quit  
                  END  
    
                  IF @cAssignPackLabelToOrdCfg = '1'    
                  BEGIN                     
                     -- Update PickDetail, base on PackDetail.DropID    
                     EXEC isp_AssignPackLabelToOrderByLoad     
                        @cPickSlipNo    
                        ,@bSuccess OUTPUT    
                        ,@nErrNo   OUTPUT    
                        ,@cErrMsg  OUTPUT    
                  END    
               END  
                 
               FETCH NEXT FROM @cPackCfm INTO @cPickSlipNo  
            END  
         END  
  
         IF ISNULL( @cPalletID, '') <> ''  
         BEGIN  
            SELECT @cLoadKey = LoadKey  
            FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)  
            WHERE id=@cPalletID  
            AND STATUS='1'  
  
            IF NOT EXISTS (SELECT 1 from pallet (nolock)  
               where palletkey=@cPalletID  
               and storerkey=@cstorerkey)  
            BEGIN  
               INSERT INTO dbo.pallet(palletkey,storerkey)  
               values(@cPalletID,@cstorerkey)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 181204  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPalletFail  
                  GOTO Quit  
               END  
            END  
  
            DECLARE  @nPalletlineno  INT,  
                     @cSKU     NVARCHAR(20),  
                     @nQTY     INT  
    
    
            SELECT TOP 1 @nPalletlineno = CAST(palletlinenumber AS INT )+1  
            FROM palletdetail (nolock)  
            WHERE palletkey=@cPalletID  
            and storerkey=@cstorerkey  
            ORDER BY CAST(palletlinenumber AS INT ) DESC
  
            IF ISNULL(@nPalletlineno,'') in( 0,'')  
            BEGIN  
               SET @nPalletlineno= 1  
            END  
  
            SELECT @cSKU = PD.SKU,  
               @nQTY= SUM(PD.qty)  
            FROM dbo.PackHeader PH WITH (NOLOCK)   
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = PH.OrderKey)  
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.pickslipno=PD.pickslipno)  
            WHERE LPD.LoadKey = @cLoadKey  
            group by PD.SKU  
     
            INSERT INTO palletdetail (palletkey,storerkey,palletlinenumber,caseid,sku,qty)  
            VALUES(@cPalletID,@cstorerkey,@nPalletlineno,@cCartonID,@cSKU,@nQTY)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 181205  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPDFail  
               GOTO Quit  
            END  
         END  
      END  
   END  
  
  
   Quit:  
  
END

GO