SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_852ExtUpd02                                     */    
/* Purpose: Check if user login with printer                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author    Purposes                                   */    
/* 2021-07-06 1.0  yeekung    WMS17278 Created                          */																		 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_852ExtUpd02] (    
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10),  
   @cPickSlipNo  NVARCHAR( 10),  
   @cLoadKey     NVARCHAR( 10),  
   @cOrderKey    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20),  
   @cSKU         NVARCHAR( 20),  
   @nQTY         INT,            
   @cOption      NVARCHAR( 1),   
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT,  
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT
)    
AS    
    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cIDOrderKey NVARCHAR(10)  
          ,@cPQty       NVARCHAR(5)  
          ,@cMQty       NVARCHAR(5)  
          ,@cProductModel NVARCHAR(30)   
          ,@nOrderCount INT 
          ,@cUserName NVARCHAR(20)
          ,@cFacility NVARCHAR(20) 
  
   
   IF @nFunc = 852 -- Post pick audit (Pallet ID)  
   BEGIN  
      IF @nStep = 2-- SKU, QTY 
      BEGIN
         IF @nInputKey=0
         BEGIN
            SET @cReasonCode='SHORTAGE'
         END
      END
      IF @nStep = 4-- SKU, QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN    
           SELECT    @cUserName     = UserName,
                     @cFacility =Facility
           FROM rdt.RDTMOBREC (NOLOCK)
           WHERE mobile=@nMobile

           IF NOT EXISTS (SELECT 1 FROM codelkup (NOLOCK) 
                      WHERE listname='PPARCODE'
                      AND storerkey=@cStorerKey
                      AND code=@cReasonCode
                      AND Short='4')  
            BEGIN
               SET @nErrNo = 170251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid reasoncode
               GOTO Quit
            END


            DECLARE @tP TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT,loc NVARCHAR(20))  
            DECLARE @tC TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)  

            -- Get pickheader info  
            DECLARE @cExternOrderKey NVARCHAR( 20)  
            DECLARE @cZone           NVARCHAR( 18)  
            SELECT TOP 1  
               @cExternOrderKey = ExternOrderkey,   
               @cOrderKey = OrderKey,   
               @cZone = Zone  
            FROM dbo.PickHeader WITH (NOLOCK)  
            WHERE PickHeaderKey = @cPickSlipNo  
  
            -- Cross dock pick slip  
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'  
            BEGIN  
               INSERT INTO @tP (StorerKey, SKU, QTY,loc)  
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0),pd.loc  
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey  
               WHERE RKL.PickSlipNo = @cPickSlipNo  
               GROUP BY PD.StorerKey, PD.SKU ,pd.loc
            END  
  
            -- Discrete pick slip  
            ELSE IF @cOrderKey <> ''  
            BEGIN  
               INSERT INTO @tP (StorerKey, SKU, QTY,loc)  
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0),pd.loc  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
               WHERE PD.OrderKey = @cOrderKey  
               GROUP BY PD.StorerKey, PD.SKU,pd.loc  
            END  
  
            -- Conso pick slip  
            ELSE IF @cExternOrderKey <> ''  
            BEGIN  
               INSERT INTO @tP (StorerKey, SKU, QTY,loc)  
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0),pd.loc  
               FROM dbo.Orders O WITH (NOLOCK)  
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               WHERE O.LoadKey = @cExternOrderKey  
               GROUP BY PD.StorerKey, PD.SKU,pd.loc  
            END  
  
            INSERT INTO @tC (StorerKey, SKU, QTY)  
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)  
            FROM rdt.rdtPPA WITH (NOLOCK)   
            WHERE StorerKey = @cStorerkey  
               AND PickSlipNo = @cPickSlipNo  
            GROUP BY StorerKey, SKU 

            DECLARE @cCounter INT =0,
                    @coutfield01 NVARCHAR(20),
                    @coutfield02 NVARCHAR(20),
                    @coutfield03 NVARCHAR(20),
                    @coutfield04 NVARCHAR(20),
                    @coutfield05 NVARCHAR(20),
                    @coutfield06 NVARCHAR(20),
                    @coutfield07 NVARCHAR(20),
                    @coutfield08 NVARCHAR(20),
                    @coutfield09 NVARCHAR(20),
                    @coutfield10 NVARCHAR(20),
                    @coutfield11 NVARCHAR(20),
                    @coutfield12 NVARCHAR(20),
                    @nPD_Qty INT,
                    @cloc NVARCHAR(20)
          
                   -- Insert PalletDetail     
             DECLARE CUR_PPADetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
             SELECT P.sku,SUM(P.QTY-CASE WHEN ISNULL(C.QTY,'') ='' THEN 0 ELSE C.QTY END),p.loc
               FROM @tP P  
                  FULL OUTER JOIN @tC C ON (P.SKU = C.SKU)  
               WHERE P.SKU IS NULL  
                  OR C.SKU IS NULL  
                  OR P.QTY <> C.QTY
               GROUP BY P.sku,p.loc

            OPEN CUR_PPADetail    
            FETCH NEXT FROM CUR_PPADetail INTO  @cSKU, @nPD_Qty,@cloc
            WHILE @@FETCH_STATUS <> -1     
            BEGIN 
               IF @cCounter='0'
               BEGIN
                  SET @coutfield01=@cSKU
                  SET @coutfield02=@nPD_Qty
                  SET @coutfield03=@cloc
               END

               ELSE IF @cCounter='1'
               BEGIN
                  SET @coutfield04=@cSKU
                  SET @coutfield05=@nPD_Qty
                  SET @coutfield06=@cloc
               END

               ELSE IF @cCounter='2'
               BEGIN
                  SET @coutfield07=@cSKU
                  SET @coutfield08=@nPD_Qty
                  SET @coutfield09=@cloc
               END

               ELSE IF @cCounter='3'
               BEGIN
                  SET @coutfield10=@cSKU
                  SET @coutfield11=@nPD_Qty
                  SET @coutfield12=@cloc
               END
          
               EXEC RDT.rdt_STD_EventLog  
                  @cActionType = '3', -- Sign in function  
                  @cUserID     = @cUserName,  
                  @nMobileNo   = @nMobile,  
                  @nFunctionID = @nFunc,  
                  @cFacility   = @cFacility,  
                  @cStorerKey  = @cStorerkey,
                  @cReasonKey  = @cReasonCode,
                  @csku=@cSKU,
                  @cLocation=@cloc,
                  @cPickSlipNo=@cPickSlipNo,
                  @nQTY=@nPD_Qty

               SET @cCounter=@cCounter+1

               IF @cCounter=4
                  BREAK;
               
               

               FETCH NEXT FROM CUR_PPADetail INTO  @cSKU, @nPD_Qty,@cloc

            END

            CLOSE CUR_PPADetail          
            DEALLOCATE CUR_PPADetail 

            SELECT @cReasonCode=code 
            FROM codelkup (NOLOCK) 
            WHERE listname = 'PPARCODE' 
            AND storerkey=@cStorerKey

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung05) --  
              @coutfield01,   
              @coutfield02,
              @coutfield03,
              @coutfield04,
              @coutfield05,
              @coutfield06,
              @coutfield07,
              @coutfield08,
              @coutfield09,
              @coutfield10,
              @coutfield11,
              @coutfield12

            SET @nErrNo=0
         END
      END
 
   END  
     
Quit:    
   

GO