SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_727Inquiry15                                       */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2022-05-05 1.0  ChewKP     WMS-19608 Created                            */  
/***************************************************************************/  

CREATE PROC [RDT].[rdt_727Inquiry15] (  
  @nMobile      INT,    
   @nFunc        INT,    
   @nStep        INT,    
   @cLangCode    NVARCHAR(3),    
   @cStorerKey   NVARCHAR(15),    
   @cOption      NVARCHAR(1),    
   @cParam1      NVARCHAR(20),    
   @cParam2      NVARCHAR(20),    
   @cParam3      NVARCHAR(20),    
   @cParam4      NVARCHAR(20),    
   @cParam5      NVARCHAR(20),    
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
   @nErrNo       INT          OUTPUT,    
   @cErrMsg      NVARCHAR(20) OUTPUT    
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  

     
   DECLARE @cLabel_LOC   NVARCHAR( 20)  
   DECLARE @cLabel_Total NVARCHAR( 20)  
   DECLARE @cLabel_Page  NVARCHAR( 20)  
  
   DECLARE @cFacility   NVARCHAR( 5)  
   DECLARE @cID         NVARCHAR( 18)  
   DECLARE @cLOC        NVARCHAR( 10)  
  


   DECLARE @nPage       INT  
   DECLARE @nTotalPage  INT  
   
   DECLARE @cCartonNo      NVARCHAR( 20)  
          ,@cConsigneeKey  NVARCHAR( 15)
          ,@cCCompany      NVARCHAR(100)
          ,@cLoadKey       NVARCHAR( 10)
		    ,@nTotalCount    INT
		    ,@nCartonCount   INT
          
  
   SET @nErrNo = 0  
  
   -- Get session info  
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
       
  
   IF @nFunc = 727 -- General inquiry  
   BEGIN  
      IF @nStep = 2 -- Inquiry sub module, input screen  
      BEGIN  
         -- Parameter mapping  
         SET @cCartonNo = @cParam1  
         SET @cLoadKey = @cParam3

		   IF ISNULL(@cCartonNo,'' ) = '' AND ISNULL(@cLoadKey,'' ) = ''
		   BEGIN  
            SET @nErrNo = 186301  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need 1 InputValue 
            GOTO Quit  
         END  
  
         IF ISNULL(@cCartonNo,'') <> ''
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
                            WHERE PD.StorerKey = @cStorerKey
                            AND PD.CaseID = @cCartonNo
                            AND PD.Status = '5'
                            AND LOC.LocationCategory = 'PPS')
            BEGIN
               SET @nErrNo = 186302  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartonID
               GOTO Quit  
            END
            
            SET @cLoadKey = ''
            SELECT Top 1 @cLoadKey = O.LoadKey FROM dbo.PickDetail PD WITH (NOLOCK)
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
            WHERE PD.StorerKey = @cStorerKey
            AND PD.CaseID = @cCartonNo
            AND PD.Status = '5'
            AND LOC.LocationCategory = 'PPS'
            
         END
         
         IF ISNULL(@cLoadKey,'') <> ''
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND LoadKey = @cLoadKey)
            BEGIN
               SET @nErrNo = 186303 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoadKey
               GOTO Quit  
            END
            
         END
         
         --- Get Count Data
         SET @nTotalCount = 0 
         SET @nCartonCount = 0 
         SET @cConsigneeKey = ''
         SET @cCCompany = ''
         
         SELECT @nTotalCount   = Count(Distinct PD.CaseID) 
               ,@cConsigneeKey = O.ConsigneeKey
               ,@cCCompany     = O.C_Company
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
         WHERE PD.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
		 GROUP BY O.ConsigneeKey, O.C_Company
         
         SELECT @nCartonCount = Count(Distinct PD.CaseID) FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
         WHERE PD.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey
         AND PD.Status = '5'
         AND LOC.LocationCategory = 'PPS'
         
                 
         
         -- Get counter  
         SET @nPage = 1  
         

         SET @c_oFieled01 = 'LOADKEY : ' + @cLoadKey  
         SET @c_oFieled02 = 'CONSIGNEEKEY : '
         SET @c_oFieled03 = @cConsigneeKey
         SET @c_oFieled04 = SUBSTRING( @cCCompany, 1, 20)  
         SET @c_oFieled05 = SUBSTRING( @cCCompany, 21, 20) 
         SET @c_oFieled06 = ''  
         SET @c_oFieled07 = 'TTL PPS     : ' + CAST(@nCartonCount AS NVARCHAR(5))
         SET @c_oFieled08 = 'TTL CARTON  : ' + CAST(@nTotalCount AS NVARCHAR(5))      
         SET @c_oFieled09 = '' 
         SET @c_oFieled10 = ''
   
         
         
    
       
      END  
     
     
   END  
  
   Quit:  
  
END  

GO