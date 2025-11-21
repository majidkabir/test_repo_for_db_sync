SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_727Inquiry05                                       */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author   Purposes                                       */      
/* 2018-09-26 1.0  ChewKP   WMS-5803 Created                               */    
/* 2019-06-28 1.1  James    WMS-9394 Add more info to ctn count (james01)  */    
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_727Inquiry05] (      
 @nMobile    INT,             
 @nFunc      INT,             
 @nStep      INT,              
 @cLangCode  NVARCHAR( 3),    
 @cStorerKey NVARCHAR( 15),    
 @cOption    NVARCHAR( 1),    
 @cParam1    NVARCHAR(20),     
 @cParam2    NVARCHAR(20),     
 @cParam3    NVARCHAR(20),     
 @cParam4    NVARCHAR(20),     
 @cParam5    NVARCHAR(20),     
 @c_oFieled01  NVARCHAR(20) OUTPUT,  
 @c_oFieled02  NVARCHAR(20) OUTPUT,  
 @c_oFieled03  NVARCHAR(20) OUTPUT,  
 @c_oFieled04  NVARCHAR(20) OUTPUT,  
 @c_oFieled05  NVARCHAR(20) OUTPUT,  
 @c_oFieled06  NVARCHAR(20) OUTPUT,  
 @c_oFieled07  NVARCHAR(20) OUTPUT,  
 @c_oFieled08  NVARCHAR(20) OUTPUT,  
 @c_oFieled09  NVARCHAR(20) OUTPUT,  
 @c_oFieled10  NVARCHAR(20) OUTPUT,  
 @c_oFieled11  NVARCHAR(20) OUTPUT,  
 @c_oFieled12  NVARCHAR(20) OUTPUT,  
 @nNextPage    INT          OUTPUT,  
 @nErrNo     INT OUTPUT,      
 @cErrMsg    NVARCHAR( 20) OUTPUT  
)      
AS      
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF       
      
   DECLARE 
          @cSKU        NVARCHAR(20)  
         ,@cDropID     NVARCHAR(20) 
         ,@nRemainQty  INT
         ,@nTTLQty     INT
      
   DECLARE @nSKUCnt     INT  
          ,@b_Success   INT  
          ,@cLabelNo    NVARCHAR(20) 
          ,@cPickSlipNo NVARCHAR(10)
          ,@cPlatform   NVARCHAR(4000) 
          ,@cUserDefine03 NVARCHAR(20) 
          ,@cOrderKey   NVARCHAR(10)
          ,@cShipFlag   NVARCHAR(1)
          ,@nCartonCount INT
          ,@cCartonCount   NVARCHAR( 20)
          ,@cSeq           NVARCHAR( 30)
          ,@cTtl_Seq       NVARCHAR( 60)
            
      
            
SET @nErrNo = 0   
  
  
IF @cOption = '2'   
BEGIN            
   --IF @nStep = 2 OR @nStep = 3 OR @nStep = 4   
   --BEGIN  
        
      IF @nStep = 2   
      BEGIN  
         SET @cDropID     = @cParam1   
         --SET @cUPC        = @cParam3  
           
         IF @cDropID = ''  
         BEGIN  
            SET @nErrNo = 129501  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq  
            GOTO QUIT   
         END  
           
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                         WHERE StorerKey = @cStorerKey
                         AND DropID = @cDropID   )  
         BEGIN  
            SET @nErrNo = 129502  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID  
            GOTO QUIT   
         END  
         
         SELECT @cSKU = SKU
               ,@nTTLQty = SUM(Qty) 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID 
         GROUP BY SKU 
         
         SELECT @nRemainQty = SUM(Qty) 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID 
         AND Status = '3'
           
         SET @c_oFieled01 = 'DROPID :'  
         SET @c_oFieled02 = @cDropID   
         SET @c_oFieled03 = 'SKU :'
         SET @c_oFieled04 = @cSKU  
         SET @c_oFieled05 = ''  
         SET @c_oFieled06 = 'TOTAL QTY: ' 
         SET @c_oFieled07 = @nTTLQty  
         SET @c_oFieled08 = 'REMAIN QTY: ' 
         SET @c_oFieled09 = @nRemainQty
         SET @c_oFieled10 = ''  
           
         SET @nNextPage = 0  
           
      END  
  
   --END  
END

IF @cOption = '3' 
BEGIN
   IF @nStep = 2   
   BEGIN  
      SET @cLabelNo     = @cParam1   
      --SET @cUPC        = @cParam3  
        
      IF @cLabelNo = ''  
      BEGIN  
         SET @nErrNo = 129503  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonIDReq  
         GOTO QUIT   
      END  
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cLabelNo )  
      BEGIN  
         SET @nErrNo = 129504  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartonID 
         GOTO QUIT   
      END  
      

      
      SELECT TOP 1 @cOrderKey = OrderKey 
                  ,@cPickSlipNo = PickSlipNo 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cLabelNo 
      AND Status < '5'
      ORDER BY Editdate DESC
      
      SELECT @cShipFlag = Ecom_Single_Flag 
            ,@cUserDefine03 = UserDefine03
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE Orderkey = @cOrderKey
      
      SELECT @cPlatform = Notes2 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE Listname  = 'UAEPLCN'
      AND Long = @cUserDefine03 
      AND StorerKey = @cStorerKey 
      
      SELECT @nCartonCount = Count (DISTINCT DropID )
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND PickSlipNo = @cPickSlipNo  
      AND ISNULL(DropID,'')  <> '' 

      SELECT @cDropID =ISNULL(MAX(CASE WHEN DD.ChildId=@cLabelNo THEN DD.Dropid END),'XX'),
             @cSeq = ISNULL(MAX(CASE WHEN DD.ChildId=@cLabelNo THEN DD.UserDefine01 END),'X'),
             @cTtl_Seq = Count (DISTINCT DD.ChildId )
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      LEFT JOIN dbo.DropidDetail DD WITH (NOLOCK) ON DD.ChildID=PD.DropID
      LEFT JOIN dbo.Dropid D WITH (NOLOCK) ON D.Dropid = DD.Dropid
      WHERE PD.StorerKey = @cStorerKey 
      AND PD.PickSlipNo = @cPickSlipNo  
      AND ISNULL(PD.DropID,'')  <> '' 
      AND D.Status='0'


      SET @cCartonCount = RIGHT( '0' + SUBSTRING( @cDropID, 14, 1), 2) + '/' + RTRIM( @cSeq) + '/' + RTRIM( @cTtl_Seq) + '/' + CAST( @nCartonCount AS NVARCHAR( 5))

      SET @c_oFieled01 = 'Carton ID :'    
      SET @c_oFieled02 = @cLabelNo     
      SET @c_oFieled03 = 'SINGLE FLAG :' + @cShipFlag   
      SET @c_oFieled04 = 'BATCH NO:'
      SET @c_oFieled05 = @cPickSlipNo  
      SET @c_oFieled06 = 'PLATFORM:'    
      SET @c_oFieled07 = @cPlatform
      SET @c_oFieled08 = ''  
      SET @c_oFieled09 = 'CARTON COUNT:'   
      SET @c_oFieled10 = @cCartonCount    
        
      SET @nNextPage = 0  
        
   END  
END  
QUIT:  
          

        

GO