SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/          
/* Store procedure: rdt_1641ExtValidSP17                                      */          
/* Purpose: Validate Pallet DropID                                            */          
/*                                                                            */          
/* Modifications log:                                                         */          
/*                                                                            */          
/* Date       Rev  Author     Purposes                                        */          
/* 2021-11-05 1.0  Chermaine  WMS-18186 Created                               */        
/* 2022-04-25 1.1  YeeKung    Performance Tune (yeekung01)                    */   
/* 2022-05-20 1.2  YeeKung    WMS-19685 Modify validation(yeekung02)          */
/* 2022-12-01 1.3  YeeKung    WMS-21215 Add validation(yeekung03)             */
/******************************************************************************/          
          
CREATE   PROC [RDT].[rdt_1641ExtValidSP17] (         
   @nMobile      INT,          
   @nFunc        INT,          
   @cLangCode    NVARCHAR(3),          
   @nStep        INT,          
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR(15),          
   @cDropID      NVARCHAR(20),          
   @cUCCNo       NVARCHAR(20),          
   @cPrevLoadKey NVARCHAR(10),          
   @cParam1      NVARCHAR(20),          
   @cParam2      NVARCHAR(20),          
   @cParam3      NVARCHAR(20),          
   @cParam4      NVARCHAR(20),          
   @cParam5      NVARCHAR(20),          
   @nErrNo       INT          OUTPUT,          
   @cErrMsg      NVARCHAR(20) OUTPUT          
)          
AS          
          
SET NOCOUNT ON          
SET QUOTED_IDENTIFIER OFF          
SET ANSI_NULLS OFF          
          
IF @nFunc = 1641          
BEGIN          
   DECLARE @cPickSlipNo       NVARCHAR( 10),          
           @cOrderKey         NVARCHAR( 10),           
           @cRoute            NVARCHAR( 30),          
           @cDocType          NVARCHAR( 1),        
           @cMVat             NVARCHAR( 18),        
           @cOdrCountry       NVARCHAR( 30),        
           @cStrCountry       NVARCHAR( 30),        
           @cShipperKey       NVARCHAR( 15),        
           @cSalesMan         NVARCHAR( 30),        
           @cPlatform         NVARCHAR( 30),         
           @nCartonNo         INT,            
           @nDebug            INT,
           @cOrderGroup       NVARCHAR(20),
           @cAccomPlatform    NVARCHAR( 30),
           @cBID              NVARCHAR(20)
                   
   SET @nDebug = 0          
             
          
--if suser_sname() = 'wmsgt'          
--set @nDebug = 1          
          
   SET @nErrNo = 0          
            
   IF @nStep = 3 -- UCC          
   BEGIN          
    IF @nInputKey = 1 -- ENTER          
      BEGIN           
         SELECT         
            @cPickSlipNo = PD.PickSlipNo,        
            @cOrderkey = PH.OrderKey,        
            @cDocType = Doctype,        
            @cMVat = O.M_vat,        
            @cOdrCountry = O.C_Country,        
            @nCartonNo = PD.CartonNo,        
            @cRoute = O.Route,        
            @cShipperKey = O.ShipperKey,        
            @cSalesMan = O.Salesman,        
            @cPlatform = ISNULL(C.Long,''),
            @cOrderGroup = O.ordergroup,
            @cAccomPlatform = OI.Platform,
            @cBID       = O.userdefine10 --(yeekung03)
         From PackDetail PD WITH (NOLOCK)         
         JOIN PackHeader PH WITH (NOLOCK) ON (PH.StorerKey = PD.StorerKey AND PH.PickSlipNo = PD.PickSlipNo)        
         JOIN Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND O.OrderKey = PH.OrderKey)     
         LEFT JOIN OrderInfo OI WITH (NOLOCK) ON ( OI.OrderKey = O.OrderKey)   --(yeekung02)
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON (C.StorerKey = O.StorerKey AND C.LISTNAME = 'COURIERLBL' AND C.Code = O.Salesman)        
         WHERE PH.Storerkey = @cStorerKey              
         AND PD.DropID = @cUCCNo      
         AND PD.DropID <> ''      
         AND PH.Status = '9'        
              
         IF @@ROWCOUNT = 0        
         BEGIN        
            SELECT         
               @cPickSlipNo = PD.PickSlipNo,        
               @cOrderkey = PH.OrderKey,        
               @cDocType = Doctype,        
               @cMVat = O.M_vat,        
               @cOdrCountry = O.C_Country,        
               @nCartonNo = PD.CartonNo,        
               @cRoute = O.Route,        
               @cShipperKey = O.ShipperKey,        
               @cSalesMan = O.Salesman,        
               @cPlatform = ISNULL(C.Long,''),
               @cOrderGroup = O.ordergroup,
               @cAccomPlatform = OI.Platform,
               @cBID       = O.userdefine10 --(yeekung03)
            From PackDetail PD WITH (NOLOCK)         
            JOIN PackHeader PH WITH (NOLOCK) ON (PH.StorerKey = PD.StorerKey AND PH.PickSlipNo = PD.PickSlipNo)        
            JOIN Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND O.OrderKey = PH.OrderKey)        
            LEFT JOIN OrderInfo OI WITH (NOLOCK) ON ( OI.OrderKey = O.OrderKey)    --(yeekung02)
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON (C.StorerKey = O.StorerKey AND C.LISTNAME = 'COURIERLBL' AND C.Code = O.Salesman)        
            WHERE PH.Storerkey = @cStorerKey         
            AND PD.Refno = @cUCCNo    
            AND PD.Refno <> ''    
            AND PH.Status = '9'        
    
            IF @@ROWCOUNT = 0        
            BEGIN        
               SET @nErrNo = 178501          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Ucc        
               GOTO Quit        
            END        
         END        
                
         IF NOT EXISTS (SELECT 1 FROM PackHeader WHERE Storerkey = @cStorerKey AND pickslipNo = @cPickSlipNo AND Status = '9' )          
         BEGIN        
            SET @nErrNo = 178502          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pack Not Done        
            GOTO Quit        
         END        
                    
         IF EXISTS (SELECT * FROM PalletDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND caseID = @cUCCNo)        
         BEGIN        
            SET @nErrNo = 178503          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scanned UCC        
            GOTO Quit          
         END        
                 
         IF @cDocType = 'N' --B2b        
         BEGIN        
            IF @cMVat = 'PPA'        
            BEGIN        
            --IF NOT EXISTS (SELECT 1         
            --               FROM rdt.rdtPPA WITH (NOLOCK)         
            --               WHERE storerkey = @cStorerKey         
            --               AND DropID = @cUCCNo         
            --               HAVING sum(PQty) = sum(cQty))         
               IF (EXISTS (SELECT 1             
                              FROM PackDetail PD WITH (NOLOCK)             
                              LEFT JOIN RDT.RDTPPA R (NOLOCK) ON PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU          
                              WHERE PD.StorerKey = @cStorerKey             
                              AND PD.DropID = @cUCCNo             
                              AND Qty <> ISNULL(R.CQty,0))  )          
                  OR (EXISTS (SELECT 1 FROM RDT.RDTPPA R WITH (NOLOCK)          
                                 WHERE R.StorerKey = @cStorerKey          
                                 AND R.DropID = @cUCCNo          
                                 AND CQty > 0          
                                 AND NOT EXISTS (SELECT 1 FROM PackDetail PD WITH (NOLOCK)          
                                                WHERE PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU)))          
               BEGIN        
                  SET @nErrNo = 178504          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid PPA        
                  GOTO Quit         
               END        
            END        
                  
            SELECT @cStrCountry = Country FROM storer (NOLOCK) WHERE StorerKey = @cStorerKey        
            IF @cOdrCountry <> @cStrCountry        
            BEGIN        
               IF NOT EXISTS (SELECT 1         
                           FROM PackInfo WITH (NOLOCK)         
                           WHERE pickslipNo = @cPickSlipNo        
                           AND CartonNo = @nCartonNo        
                           AND CUBE > 0         
                           AND WEIGHT > 0)        
               BEGIN        
                  SET @nErrNo = 178505          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidPckInfo        
                  GOTO Quit         
               END        
            END        
                      
            IF EXISTS (SELECT 1            
                     FROM palletDetail PltD WITH (NOLOCK)            
                     JOIN PackDetail PD WITH (NOLOCK) ON (PD.StorerKey = PltD.StorerKey AND PD.DropID = PltD.caseID)            
                     JOIN PackHeader PH WITH (NOLOCK) ON (PD.StorerKey = PH.storerKey AND PH.PickSlipNo = PD.PickSlipNo)            
                     JOIN Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey)            
                     WHERE PltD.Palletkey = @cDropID            
                     AND PltD.StorerKey = @cStorerKey            
                     AND (O.C_Country <> @cOdrCountry            
                     OR O.Route <> @cRoute
                     OR O.Userdefine10 <> @cBID) --(yeekung03)         
                     AND PltD.caseID <> '')                                
            BEGIN        
               SET @nErrNo = 178506          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Batch           
               GOTO Quit        
            END                  
         END        
                 
         IF @cDocType = 'E' --B2C        
         BEGIN        
            IF @cOrderGroup <> 'aCommerce' --(yeekung02)
            BEGIN
               IF EXISTS (SELECT 1    
                        FROM palletDetail PltD WITH (NOLOCK)    
                        JOIN PackDetail PD WITH (NOLOCK) ON (PD.StorerKey = PltD.StorerKey AND PD.Refno = PltD.caseID)    
                        JOIN PackHeader PH WITH (NOLOCK) ON (PD.StorerKey = PH.storerKey AND PH.PickSlipNo = PD.PickSlipNo)    
                        JOIN Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey)    
                        LEFT JOIN codelkup C WITH (NOLOCK) ON (C.code = O.Salesman AND C.Storerkey = C.Storerkey AND C.ListName = 'COURIERLBL')    
                        WHERE PltD.Palletkey = @cDropID    
                        AND PltD.StorerKey = @cStorerKey    
                        AND (LEFT(o.C_Country,2)<> LEFT(@cOdrCountry,2) 
                             OR O.ShipperKey <> @cShipperKey    
                             OR C.Long <> @cPlatform)    
                        AND ISNULL(PltD.caseID,'') <> '')           	           
               BEGIN
            	   SET @nErrNo = 178507  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Batch   
                  GOTO Quit
               END
            END
            ELSE 
            BEGIN
               IF EXISTS (SELECT 1    
                        FROM palletDetail PltD WITH (NOLOCK)        
                        JOIN PackDetail PD WITH (NOLOCK) ON (PD.StorerKey = PltD.StorerKey AND PD.Refno = PltD.caseID)        
                        JOIN PackHeader PH WITH (NOLOCK) ON (PD.StorerKey = PH.storerKey AND PH.PickSlipNo = PD.PickSlipNo)        
                        JOIN Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey)    
                        LEFT JOIN OrderInfo OI WITH (NOLOCK) ON ( O.OrderKey=OI.OrderKey)    
                        WHERE PltD.Palletkey = @cDropID        
                        AND PltD.StorerKey = @cStorerKey        
                        AND ( LEFT(o.C_Country,2)  <> LEFT(@cOdrCountry,2)     
                             OR O.ShipperKey <> @cShipperKey        
                             OR ISNULL(OI.Platform,'') <> @cAccomPlatform)        
                        AND ISNULL(PltD.caseID,'') <> '')  --(yeekung02)
               BEGIN
            	   SET @nErrNo = 178508  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Batch   
                  GOTO Quit
               END
            END       
         END        
      END        
   END          
END          
          
Quit:  


GO