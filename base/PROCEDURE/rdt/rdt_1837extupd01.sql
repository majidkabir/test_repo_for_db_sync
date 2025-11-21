SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1837ExtUpd01                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-04-08  1.0  James       WMS-12735. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1837ExtUpd01] (
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

            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   LoadKey = @cLoadKey
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
               SET @nErrNo = 150801  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlipNo  
               GOTO Quit  
            END 
            
            DECLARE @cPackCfm CURSOR
            SET @cPackCfm = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
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
                     SET @nErrNo = 150802
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
                     GOTO Quit
                  END
               END
               
               FETCH NEXT FROM @cPackCfm INTO @cPickSlipNo
            END
         END
      END
   END


   Quit:

END

GO