SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_870ExtStatSP01                                  */  
/* Purpose: Validate  SerialNo                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 14-Sep-2017 1.0  James      WMS2988.Created                          */
/* 20-Sep-2017 1.1  James      Add filter SKU when check BOM (james01)  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_870ExtStatSP01] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cSKU           NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cCheckSSCC     NVARCHAR( 1), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cLotNo         NVARCHAR( 20), 
   @nSerialNoQTY   INT           OUTPUT,
   @nPickQTY       INT           OUTPUT,
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @nBOM     INT,
      @nBOMQty  INT,
      @nSrNoQTY INT,
      @nPQTY    INT,
      @cZone         NVARCHAR( 10),
      @cPH_OrderKey  NVARCHAR( 10),
      @cPH_LoadKey   NVARCHAR( 10),
      @cPD_SKU       NVARCHAR( 20)


   SET @nSerialNoQTY = 0
   SET @nPickQTY = 0

   SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo 

   IF @nFunc = 870  
   BEGIN  
      IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
            SELECT @cSKU = V_SKU 
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile
      END

      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT PD.OrderKey, PD.SKU
         FROM dbo.PickDetail PD (NOLOCK) 
         JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
         WHERE RPL.PickslipNo = @cPickSlipNo    
         AND   (( ISNULL( @cSKU, '') = '') OR (PD.Sku = @cSKU))
      END
      ELSE
      BEGIN
         IF ISNULL( @cPH_OrderKey, '') <> ''
         BEGIN
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT PD.OrderKey, PD.SKU
            FROM dbo.PickHeader PH (NOLOCK)     
            JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
            WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND   (( ISNULL( @cSKU, '') = '') OR (PD.Sku = @cSKU))
         END
         ELSE
         BEGIN
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT PD.OrderKey, PD.SKU
            FROM dbo.PickHeader PH (NOLOCK)     
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
            WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND   (( ISNULL( @cSKU, '') = '') OR (PD.Sku = @cSKU))
         END
      END
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cPD_SKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @nPQTY = 0
         SET @nBOMQty = 0
         SET @nSrNoQTY = 0
         SELECT @nPQTY = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.OrderKey = @cOrderKey
         AND   PD.Storerkey = @cStorerKey
         AND   PD.SKU = @cPD_SKU
      
         -- Check if any sku in the orderkey not exists BOM table then it is not BOM sku
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   OrderKey = @cOrderKey
                     AND   PD.SKU = @cPD_SKU -- (james01)
                     AND   NOT EXISTS ( SELECT 1 FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
                                        WHERE PD.SKU = BOM.SKU
                                        AND   PD.StorerKey = BOM.StorerKey))
            SET @nBOM = 0
         ELSE
            SET @nBOM = 1

         IF @nBOM = 0
         BEGIN
            --SET @nPickQTY = @nPQTY
            SET @nPickQTY = @nPickQTY + @nPQTY 
            SET @nSerialNoQTY = @nSerialNoQTY + @nSrNoQTY
         END
         ELSE
         BEGIN
            SELECT @nBOMQty = ISNULL( SUM( BOM.Qty / BOM.ParentQty), 0)
            FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
            JOIN dbo.SKU SKU WITH (NOLOCK) ON 
               ( BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSKU = SKU.SKU)
            WHERE BOM.SKU = @cPD_SKU
            AND   ISNULL( SKU.SUSR4, '') <> ''
            AND   EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
                           WHERE PD.StorerKey = BOM.StorerKey 
                           AND PD.SKU = BOM.SKU 
                           AND PD.OrderKey = @cOrderKey
                           AND PD.StorerKey = @cStorerKey)


            SELECT @nSrNoQTY = COUNT( DISTINCT SR.SerialNo)
            FROM dbo.SerialNo SR WITH (NOLOCK)
            WHERE EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                           WHERE SR.OrderKey = PD.OrderKey
                           AND   SR.SKU = PD.SKU
                           AND   PD.StorerKey = @cStorerKey
                           AND   PD.OrderKey = @cOrderKey
                           AND   PD.SKU = @cPD_SKU)

            SET @nPickQTY = @nPickQTY + (@nPQTY * @nBOMQty)
            SET @nSerialNoQTY = @nSerialNoQTY + @nSrNoQTY
         END

      --insert into traceinfo (tracename, timein, col1, col2, col3, col4, STEP1, STEP2, STEP3) values 
      --('870', getdate(), @cStorerKey, @cPD_SKU, @nSerialNoQTY, @nPickQTY, @nPQTY, @nBOMQty, @nSrNoQTY)

         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cPD_SKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      SET @nSerialNoQTY = ISNULL( @nSerialNoQTY, 0)
      SET @nPickQTY = ISNULL( @nPickQTY, 0)
   END  
  
QUIT:  

 

GO