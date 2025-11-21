SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1807ExtInquiry01                                */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Lulu Extended Inquiry                                       */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2021-02-19  1.0  James    WMS-15661. Created                         */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1807ExtInquiry01] (    
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,     
   @cUserName       NVARCHAR( 18), 
   @cFacility       NVARCHAR( 5),  
   @cStorerKey      NVARCHAR( 15), 
   @cType           NVARCHAR( 10), 
   @cDropID         NVARCHAR( 20), 
   @cWaveKey        NVARCHAR( 10) OUTPUT, 
   @cLoadKey        NVARCHAR( 10) OUTPUT, 
   @cStore          NVARCHAR( 20) OUTPUT, 
   @cCartonStatus   NVARCHAR( 20) OUTPUT, 
   @cLastLoc        NVARCHAR( 10) OUTPUT, 
   @cOrderGroup     NVARCHAR( 20) OUTPUT, 
   @cSectionKey     NVARCHAR( 10) OUTPUT, 
   @cShipToCountry  NVARCHAR( 20) OUTPUT, 
   @cShipToCompany  NVARCHAR( 20) OUTPUT, 
   @cConsigneeKey   NVARCHAR( 15) OUTPUT, 
   @cSKU            NVARCHAR( 20) OUTPUT, 
   @nQTY            INT           OUTPUT, 
   @cUDF01          NVARCHAR( 20) OUTPUT, 
   @cUDF02          NVARCHAR( 20) OUTPUT, 
   @cUDF03          NVARCHAR( 20) OUTPUT, 
   @cUDF04          NVARCHAR( 20) OUTPUT, 
   @cUDF05          NVARCHAR( 20) OUTPUT, 
   @cDropIDType     NVARCHAR( 20) OUTPUT,
   @nLastSKU        INT           OUTPUT,
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cUserdefine05  NVARCHAR( 20)
   DECLARE @cToLoc         NVARCHAR( 10)
   DECLARE @cSourceKey     NVARCHAR( 30)
   DECLARE @cSourceType    NVARCHAR( 20)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cCartonType    NVARCHAR( 10) = ''
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cWaveKey = ''
         SET @cToLoc = ''
         SET @cLastLoc = ''
         SET @cCartonStatus = ''
         SET @cOrderKey = ''
         SET @cConsigneeKey = ''
         SET @cSectionKey = ''
         SET @cOrderGroup = ''
         
         SELECT @cWaveKey = WaveKey,
                @cToLoc = ToLoc, 
                @cSourceKey = SourceKey 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   TaskType = 'ASTRPT'
         AND   Caseid = @cDropID
         
         -- ASTRPT
         IF @@ROWCOUNT > 0
         BEGIN
            SET @cDropIDType = 'ASTRPT'
            SET @cCartonType = 'ASTRPT'
            
            SELECT @cLastLoc = PutAwayZone
            FROM dbo.LOC WITH (NOLOCK)
            WHERE Loc = @cToLoc
            AND   Facility = @cFacility

            IF @cSourceKey = ''
               SET @cSourceType = 'PTL'
            ELSE
               SET @cSourceType = 'RPF'

            IF @cSourceType = 'PTL'
            BEGIN
               SELECT TOP 1 @cLabelNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND DROPID = @cDropID
               ORDER BY 1 
               
               SELECT TOP 1 
                  @cOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID <> ''
               AND   DropID = @cLabelNo
               AND   [STATUS] = '5'
               ORDER BY EditDate DESC
            END
            ELSE
            BEGIN
               SELECT TOP 1 
                  @cOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = ''
               AND   TaskDetailKey = @cSourceKey
               AND   [Status] IN ('3', '5')
               ORDER BY EditDate DESC
            END
            
            SELECT @cStore = ShipperKey, 
                   @cSectionKey = SectionKey, 
                   @cUserdefine05 = UserDefine05,
                   @cLoadKey = LoadKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END

            GOTO Quit
         END
         
         SELECT TOP 1 @cOrderKey = OrderKey,
                      @cWaveKey = WaveKey
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   CaseID = ''
         AND   DropID = @cDropID
         ORDER BY WaveKey DESC
         
         -- UCC
         IF @@ROWCOUNT > 0
         BEGIN
            SET @cDropIDType = 'UCC'
            SET @cCartonType = 'UCC'

            SELECT TOP 1 @cLastLoc = LOC.PutawayZone
            FROM rdt.rdtPTLStationLogQueue PTL WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PTL.LOC = LOC.Loc)
            WHERE PTL.WaveKey = @cWaveKey
            ORDER BY 1
            
            SELECT @cLoadKey = LoadKey,
                   @cStore = ConsigneeKey,
                   @cUserdefine05 = UserDefine05, 
                   @cSectionKey = SectionKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END

            SELECT @cCartonStatus = Status      
            FROM dbo.UCC WITH (NOLOCK)       
            WHERE UCCNo = @cDropID       
              AND StorerKey = @cStorerKey      
      
            SELECT @cCartonStatus = [Description]      
            FROM dbo.Codelkup WITH (NOLOCK)      
            WHERE LISTNAME = 'UCCStatus'      
            AND   Code = @cCartonStatus   

            GOTO Quit
         END
         
         -- Label No
         SELECT TOP 1 
            @cPickSlipNo = PD.PickSlipNo,
            @cOrderKey = PH.OrderKey   
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.LabelNo = @cDropID
         ORDER BY 1

         IF @@ROWCOUNT > 0
         BEGIN
            SET @cDropIDType = 'OUTBOUND'
            SET @cCartonType = 'OUTBOUND'
            
            SELECT @cWaveKey = UserDefine09,
                   @cLoadKey = LoadKey,
                   @cStore = ConsigneeKey,
                   @cUserdefine05 = UserDefine05, 
                   @cSectionKey = SectionKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SELECT TOP 1 @cLastLoc = LOC.PutawayZone
            FROM rdt.rdtPTLStationLogQueue PTL WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PTL.LOC = LOC.Loc)
            WHERE PTL.WaveKey = @cWaveKey
            ORDER BY PTL.Station DESC

            SET @cCartonStatus = ''

            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END
            GOTO Quit
         END
            
      END
   END  

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- ASTRPT
         IF @cDropIDType = 'ASTRPT'
         BEGIN
            SELECT @cSKU = SKU,
                   @nQTY = Qty, 
                   @cSourceKey = SourceKey 
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   TaskType = 'ASTRPT'
            AND   Caseid = @cDropID

            IF @cSourceKey = ''
               SET @cSourceType = 'PTL'
            ELSE
               SET @cSourceType = 'RPF'

            IF @cSourceType = 'PTL'
            BEGIN
               SELECT TOP 1 
                  @cLabelNo = LabelNo, 
                  @cSKU = SKU, 
                  @nQTY = SUM( Qty)
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND DROPID = @cDropID
               GROUP BY LabelNo, SKU
               ORDER BY SKU
               
               SELECT TOP 1 
                  @cOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID <> ''
               AND   DropID = @cLabelNo
               AND   [STATUS] = '5'
               ORDER BY EditDate DESC
            END
            ELSE
            BEGIN
               SELECT TOP 1 
                  @cOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = ''
               AND   TaskDetailKey = @cSourceKey
               AND   [Status] IN ('3', '5')
               ORDER BY EditDate DESC

               SELECT TOP 1 
                  @cSKU = SKU, 
                  @nQTY = SUM( Qty)
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = ''
               AND   TaskDetailKey = @cSourceKey
               AND   [Status] IN ('3', '5')
               AND   OrderKey = @cOrderKey
               GROUP BY SKU
               ORDER BY Sku
            END
            
            SELECT @cStore = ShipperKey, 
                   @cSectionKey = SectionKey, 
                   @cUserdefine05 = UserDefine05,
                   @cLoadKey = LoadKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END
            SET @nLastSKU = 1
            GOTO Quit
         END
         
         -- UCC
         IF @cDropIDType = 'UCC' 
         BEGIN
            SELECT TOP 1 @cOrderKey = OrderKey,
                         @cWaveKey = WaveKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   CaseID = ''
            AND   DropID = @cDropID
            ORDER BY WaveKey DESC
            
            SELECT TOP 1 
               @cSKU = SKU,
               @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   CaseID = ''
            AND   DropID = @cDropID
            AND   WaveKey = @cWaveKey
            GROUP BY Sku
            ORDER BY Sku

            SELECT @cUserdefine05 = UserDefine05 
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END
            SET @nLastSKU = 1
            GOTO Quit
         END
         
         IF @cDropIDType = 'OUTBOUND'
         BEGIN
            SELECT TOP 1 
               @cPickSlipNo = PD.PickSlipNo,
               @cOrderKey = PH.OrderKey   
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.LabelNo = @cDropID
            ORDER BY 1
            
            SELECT TOP 1 
               @cSKU = SKU,
               @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cDropID
            GROUP BY SKU
            ORDER BY SKU
            
            SELECT @cUserdefine05 = UserDefine05 
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END
            SET @nLastSKU = 1
            GOTO Quit
         END
      END
   END
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cSKU = V_SKU
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile
         
         -- ASTRPT
         IF @cDropIDType = 'ASTRPT'
         BEGIN
            SET @nLastSKU = 0
            
            SELECT @cSourceKey = SourceKey 
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   TaskType = 'ASTRPT'
            AND   Caseid = @cDropID

            IF @cSourceKey = ''
               SET @cSourceType = 'PTL'
            ELSE
               SET @cSourceType = 'RPF'

            IF @cSourceType = 'PTL'
            BEGIN
               SELECT TOP 1 
                  @cLabelNo = LabelNo, 
                  @cSKU = SKU, 
                  @nQTY = SUM( Qty)
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND DROPID = @cDropID
               AND   SKU > @cSKU
               GROUP BY LabelNo, SKU
               ORDER BY SKU
               
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nLastSKU = 1
                  SET @nErrNo = -1
                  SET @cErrMsg = 'NO MORE SKU'
                  
                  GOTO Quit
               END
               ELSE
               BEGIN
                  SELECT TOP 1 
                     @cOrderKey = OrderKey
                  FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   CaseID <> ''
                  AND   DropID = @cLabelNo
                  AND   Sku = @cSKU
                  AND   [STATUS] = '5'
                  ORDER BY EditDate DESC
               END
            END
            ELSE
            BEGIN
               SELECT TOP 1 
                  @cOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = ''
               AND   TaskDetailKey = @cSourceKey
               AND   [Status] IN ('3', '5')
               ORDER BY EditDate DESC

               SELECT TOP 1 
                  @cSKU = SKU, 
                  @nQTY = SUM( Qty)
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = ''
               AND   TaskDetailKey = @cSourceKey
               AND   [Status] IN ('3', '5')
               AND   OrderKey = @cOrderKey
               AND   SKU > @cSKU
               GROUP BY SKU
               ORDER BY SKU

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nLastSKU = 1
                  SET @nErrNo = -1
                  SET @cErrMsg = 'NO MORE SKU'
                  
                  GOTO Quit
               END
            END
            
            SELECT @cStore = ShipperKey, 
                   @cSectionKey = SectionKey, 
                   @cUserdefine05 = UserDefine05,
                   @cLoadKey = LoadKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END

            GOTO Quit
         END
         
         -- UCC
         IF @cDropIDType = 'UCC'
         BEGIN
            SELECT TOP 1 @cOrderKey = OrderKey,
                         @cWaveKey = WaveKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   CaseID = ''
            AND   DropID = @cDropID
            ORDER BY WaveKey DESC
            
            SELECT TOP 1 
               @cSKU = SKU,
               @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   CaseID = ''
            AND   DropID = @cDropID
            AND   WaveKey = @cWaveKey
            AND   Sku > @cSKU
            GROUP BY Sku
            ORDER BY Sku

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nLastSKU = 1
               SET @nErrNo = -1
               SET @cErrMsg = 'NO MORE SKU'
                  
               GOTO Quit
            END
               
            SELECT @cUserdefine05 = UserDefine05 
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END

            GOTO Quit
         END
         
         -- OUTBOUND
         IF @cDropIDType = 'OUTBOUND'
         BEGIN
            SELECT TOP 1 
               @cPickSlipNo = PD.PickSlipNo,
               @cOrderKey = PH.OrderKey   
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.LabelNo = @cDropID
            ORDER BY 1
            
            SELECT TOP 1 
               @cSKU = SKU,
               @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cDropID
            AND   SKU > @cSKU
            GROUP BY SKU
            ORDER BY SKU

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nLastSKU = 1
               SET @nErrNo = -1
               SET @cErrMsg = 'NO MORE SKU'
                  
               GOTO Quit
            END

            SELECT @cUserdefine05 = UserDefine05 
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SET @cOrderGroup = CASE WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'R' THEN 'REPLEN'
                                    WHEN SUBSTRING( @cUserdefine05, 5, 1) = 'A' THEN @cSectionKey
                               ELSE '' END

            GOTO Quit

         END
      END
   END
   
   Quit:  
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cCartonType = ''
         BEGIN    
            SET @nErrNo = 172851    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Carton    
            GOTO Fail    
         END 
      END
   END
   Fail:
  
END    

GO