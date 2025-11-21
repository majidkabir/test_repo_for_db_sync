SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1621ExtValid03                                  */
/* Purpose: Cluster Pick Extended Validate SP                           */
/*          If both carton & ea field enter with value, prompt error    */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-12-08  1.0  yeekung     WMS18523. Created                       */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1621ExtValid03] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFieldAttr13 NVARCHAR( 1), 
           @cFieldAttr15 NVARCHAR( 1),
           @cEAQty       NVARCHAR( 5), 
           @cCtnQty      NVARCHAR( 5), 
           @cPickSlipNo  NVARCHAR( 10), 
           @cUserName    NVARCHAR( 18), 
           @cDropID_SKU  NVARCHAR( 20), 
           @cCaseCount   NVARCHAR( 10), 
           @nSKUCnt      INT, 
           @cPrevSKU     NVARCHAR(20),
           @nSum_DropID  INT, 
           @nTtlQty      INT,
           @nEAQty       INT, 
           @nCtnQty      INT, 
           @nCaseCount   INT,
           @nSKUCOUNT    INT,
           @nSKUItemCount INT,
           @nTotalPackQty INT = 0

   
   DECLARE  @cUDF01   NVARCHAR(20),
            @cUDF02   NVARCHAR(20),
            @cUDF03   NVARCHAR(20)
   
   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 8
      BEGIN

         SELECT  @cEAQty= SUM(pickqty)
         FROM rdt.rdtpicklock (NOLOCK)
         where loadkey =@cLoadKey
            and dropid=@cDropID

         SELECT @cUDF01 = udf01,
                  @cUDF02 = udf02,
                  @cUDF03 = udf03
         from codelkup (NOLOCK)
         where listname='SKUMAXPACK'
            and code='SKU'
         and storerkey=@cstorerkey

         SET @cEAQty = CASE WHEN ISNULL(@cEAQty,'')='' THEN 0 ELSE @cEAQty END

         SET @nEAQty = @cEAQty

         SELECT @cPickSlipNo=pickheaderkey
         FROM PICKHEADER (NOLOCK)
         WHERE EXTERNORDERKEY=@cLoadKey
         
         
         SELECT  @nTotalPackQty= SUM(QTY)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)     
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)        
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
         WHERE PD.Storerkey = @cStorerkey
         and PD.dropid=@cDropID
         and LPD.LoadKey=@cLoadKey

         SET @nTotalPackQty = CASE WHEN ISNULL(@nTotalPackQty,'')='' THEN 0 ELSE @nTotalPackQty END

         SELECT @nSKUCOUNT=COUNt(distinct pd.sku) FROM pickdetail PD (NOLOCK) 
         WHERE dropid = @cDropID
            AND pd.StorerKey  = @cStorerKey
            AND Status = '5'
         GROUP BY pd.dropid 

         SELECT @nSKUItemCount=COUNt(distinct s.itemclass) FROM pickdetail PD (NOLOCK) 
         JOIN SKU (NOLOCK) S 
          ON PD.Sku=S.Sku 
          AND PD.Storerkey=s.StorerKey
         WHERE dropid = @cDropID
            AND pd.StorerKey  = @cStorerKey
            AND Status = '5'
         GROUP BY pd.dropid 

         IF (@nSKUCOUNT>CAST(@cUDF01 AS INT)) OR (@nSKUItemCount>CAST(@cUDF02 AS INT))
         BEGIN  
            SET @nErrNo = 185801   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SkuOverpacked'  
            GOTO QUIT  
         END  


         IF (@nEAQty>CAST(@cUDF03 AS INT))
         BEGIN  
            SET @nErrNo = 185802   
            SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SkuOverpacked'  
            GOTO QUIT  
         END                                 
      END   -- IF @nStep = 8
   END   -- IF @nInputKey = 1

QUIT:

GO