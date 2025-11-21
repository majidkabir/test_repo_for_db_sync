SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_839DataCap01                                    */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 2022-04-16 1.0  YeeKung     WMS-19311 Created                        */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839DataCap01] (  
    @nMobile         INT                   
   ,@nFunc           INT                   
   ,@cLangCode       NVARCHAR( 3)          
   ,@nStep           INT                   
   ,@nInputKey       INT                   
   ,@cFacility       NVARCHAR( 5)          
   ,@cStorerKey      NVARCHAR( 15)         
   ,@cPickSlipNo     NVARCHAR( 10)         
   ,@cPickZone       NVARCHAR( 10)         
   ,@cDropID         NVARCHAR( 20)         
   ,@cLOC            NVARCHAR( 10)         
   ,@cSKU            NVARCHAR( 20)         
   ,@nQTY            INT                   
   ,@cOption         NVARCHAR( 1)          
   ,@cLottableCode   NVARCHAR( 30)         
   ,@cLottable01     NVARCHAR( 18)         
   ,@cLottable02     NVARCHAR( 18)  
   ,@cLottable03     NVARCHAR( 18)         
   ,@dLottable04     DATETIME              
   ,@dLottable05     DATETIME              
   ,@cLottable06     NVARCHAR( 30)         
   ,@cLottable07     NVARCHAR( 30)         
   ,@cLottable08     NVARCHAR( 30)         
   ,@cLottable09     NVARCHAR( 30)         
   ,@cLottable10     NVARCHAR( 30)         
   ,@cLottable11     NVARCHAR( 30)         
   ,@cLottable12     NVARCHAR( 30)         
   ,@dLottable13     DATETIME              
   ,@dLottable14     DATETIME              
   ,@dLottable15     DATETIME              
   ,@cPackData1      NVARCHAR( 30)  OUTPUT 
   ,@cPackData2      NVARCHAR( 30)  OUTPUT 
   ,@cPackData3      NVARCHAR( 30)  OUTPUT 
   ,@cPackLabel1     NVARCHAR( 20)  OUTPUT 
   ,@cPackLabel2     NVARCHAR( 20)  OUTPUT 
   ,@cPackLabel3     NVARCHAR( 20)  OUTPUT 
   ,@cPackAttr1      NVARCHAR( 1)   OUTPUT 
   ,@cPackAttr2      NVARCHAR( 1)   OUTPUT 
   ,@cPackAttr3      NVARCHAR( 1)   OUTPUT 
   ,@cDataCapture    NVARCHAR( 1)   OUTPUT 
   ,@nErrNo          INT            OUTPUT 
   ,@cErrMsg         NVARCHAR( 20)  OUTPUT 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount   INT  
   DECLARE @cOrderKey   NVARCHAR( 10) = ''  
   DECLARE @cLoadKey    NVARCHAR( 10) = ''  
   DECLARE @cZone       NVARCHAR( 18) = ''  
   DECLARE @cPrevPackData1 NVARCHAR( 30) = ''  
   DECLARE @cPickStatus NVARCHAR(1)  
   DECLARE @cCountyCode NVARCHAR(20)
   DECLARE @cDocType   NVARCHAR(20)
  
   -- Storer config  
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)  
  
   -- Get PickHeader info  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  


   IF ISNULL(@cLoadKey,'') <>'' and ISNULL(@cOrderKey,'')=''
   BEGIN
      -- Get orderkey
      SELECT @cOrderKey = OrderKey
      FROM dbo.orders WITH (NOLOCK)  
      WHERE loadkey = @cLoadKey
         AND storerkey=@cstorerkey
   END

   IF ISNULL(@cOrderKey,'')=''
   BEGIN
      
      -- Get orderkey
      SELECT @cOrderKey = OrderKey
      FROM dbo.pickdetail WITH (NOLOCK)  
      WHERE pickslipno = @cPickSlipNo
         AND storerkey=@cstorerkey
   END


  
   SET @cPackData1 = ''  
   SET @cPackData2 = ''  
   SET @cPackData3 = ''  

   SET @nRowCount = @@ROWCOUNT  

   SELECT @cDocType= doctype
   FROM ORDERS (NOLOCK)
   WHERE orderkey=@cOrderkey
   AND storerkey=@cstorerkey


   IF @cDocType = 'E'
      SET @cDataCapture = '0' -- Auto default, don't need to capture  
   ELSE 
   BEGIN  
      SELECT @cCountyCode= ISOCntryCode
      FROM Storer (Nolock)
      where storerkey=@cStorerkey
      
      IF EXISTS (SELECT 1
               FROM ORDERS (NOLOCK)
               WHERE Orderkey=@cOrderkey
               AND C_Country = @cCountyCode) 
      BEGIN
         SET @cDataCapture = '0'
      END
      ELSE
      BEGIN

         SET @cDataCapture = '1' -- need to capture  

         IF EXISTS(SELECT 1
                          FROM SKU (NOLOCK)
                          WHERE SKU =@cSKU
                          AND Storerkey=@cStorerkey
                          AND ISNULL(CountryOfOrigin,'')='')
         BEGIN
            SET @cPackData1 = '' -- PackData changed, force key-in  
         END
         ELSE
         BEGIN
            SELECT @cPackData1=CountryOfOrigin
            FROM SKU (NOLOCK)
            WHERE SKU =@cSKU
            AND Storerkey=@cStorerkey
         END

         SET @cPackAttr1=''
         SET @cPackAttr2='O'
         SET @cPackAttr3='O'
  
         SET @cPackLabel1='COO:'--(yeekung01)  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1   
      END
   END  
END  

GO