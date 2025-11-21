SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/***************************************************************************/      
/* Store procedure: rdt_727Inquiry10                                       */      
/*                                                                         */  
/* Purpose:                                                                */  
/* -Scan sku, display suggested floor + qty limit                          */  
/*                                                                         */      
/* Modifications log:                                                      */     
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */      
/* 2021-09-01 1.0  James    WMS-17819. Created                             */    
/***************************************************************************/     
  
CREATE PROC [RDT].[rdt_727Inquiry10] (      
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
  
   DECLARE @cSKU     NVARCHAR(20)  
   DECLARE @n1stFloorQty   INT
   DECLARE @nLimitQty      INT 
   DECLARE @cSuggestFloor  NVARCHAR( 10)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @nSKUCnt        INT
   DECLARE @cSKUDescr      NVARCHAR( 20)
   DECLARE @bSuccess       INT
   
   SET @nErrNo = 0   
        
   IF @nStep IN ( 2, 3)   
   BEGIN  
      IF @nStep = 3
      BEGIN
         SELECT @cParam1 = I_Field12
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile
      END
      --SET @cSKU = @cParam1   
  
      IF @cParam1 = ''  
      BEGIN  
         SET @nErrNo = 175151   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Required  
         GOTO QUIT   
      END  

      EXEC RDT.rdt_GetSKUCNT          
         @cStorerKey  = @cStorerKey          
        ,@cSKU        = @cParam1          
        ,@nSKUCnt     = @nSKUCnt   OUTPUT          
        ,@bSuccess    = @bSuccess  OUTPUT          
        ,@nErr        = @nErrNo    OUTPUT          
        ,@cErrMsg     = @cErrMsg   OUTPUT  
        ,@cSKUStatus  = 'ACTIVE'

      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 175152  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
         GOTO QUIT  
      END  

      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 175153  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcode  
         GOTO QUIT  
      END  

      EXEC [RDT].[rdt_GETSKU]  
         @cStorerKey  = @cStorerKey  
        ,@cSKU        = @cParam1       OUTPUT  
        ,@bSuccess    = @bSuccess      OUTPUT  
        ,@nErr        = @nErrNo        OUTPUT  
        ,@cErrMsg     = @cErrMsg       OUTPUT 

      SET @cSKU = @cParam1
      
      SELECT @cSKUDescr = DESCR
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Sku = @cSKU
   END  

   SELECT @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @n1stFloorQty = 0
   SELECT @n1stFloorQty = ISNULL( SUM( Qty - QtyAllocated - QtyPicked), 0)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.Sku = @cSKU
   AND   LOC.Facility = @cFacility
   AND   LOC.[Floor] = '1'
   AND   LOC.HOSTWHCODE = '001'
   AND   LOC.[Status] = 'OK'

   SET @nLimitQty = 0
   SELECT @nLimitQty = CAST( Short AS INT) 
   FROM dbo.CODELKUP CLK WITH (NOLOCK) 
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( CLK.Code = SKU.BUSR7 AND CLK.Storerkey = SKU.StorerKey) 
   WHERE CLK.ListName = 'PAQTYLIMT' 
   AND   SKU.SKU = @cSKU 
   and   SKU.Storerkey = @cStorerKey

   SET @cSuggestFloor = ''
   IF @n1stFloorQty < @nLimitQty
      SET @cSuggestFloor = '1F'
   ELSE
      SET @cSuggestFloor = '2,3F'
      
   SET @c_oFieled01 = 'SKU: '  
   SET @c_oFieled02 = @cSKU
   SET @c_oFieled03 = SUBSTRING( @cSKUDescr, 1, 20)  
   SET @c_oFieled04 = SUBSTRING( @cSKUDescr, 21, 20)  
   SET @c_oFieled05 = '1st Floor Qty: ' + CAST( @n1stFloorQty AS NVARCHAR( 5)) 
   SET @c_oFieled06 = 'Limit Qty    : ' + CAST( @nLimitQty AS NVARCHAR( 5))  
   SET @c_oFieled07 = 'Suggest Floor: ' + @cSuggestFloor  

   IF @nStep = 3
      SET @c_oFieled12 = ''
      
   SET @nNextPage = -1  
     
QUIT:  

GO