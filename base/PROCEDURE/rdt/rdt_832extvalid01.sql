SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832ExtValid01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-10-07  1.0  James       WMS-10774 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_832ExtValid01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @tExtVal        VariableTable READONLY,
   @cDoc1Value     NVARCHAR( 20),
   @cCartonID      NVARCHAR( 20),
   @cCartonSKU     NVARCHAR( 20),
   @nCartonQTY     INT,
   @cPackInfo      NVARCHAR( 4),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cPackInfoRefNo NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey  NVARCHAR( 10)
   DECLARE @cLoadKey   NVARCHAR( 10)
   DECLARE @cZone      NVARCHAR( 10)
   DECLARE @cPSType    NVARCHAR( 10)
   DECLARE @cSQL       NVARCHAR( MAX)  
   DECLARE @cSQLParam  NVARCHAR( MAX)  
   DECLARE @cSKU       NVARCHAR( 20)
   DECLARE @cUPCUOM    NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''  
   DECLARE @nSum_Qty2Pick  INT
   DECLARE @fCaseCnt   FLOAT


   -- Get pick filter  
   SELECT @cPickFilter = ISNULL( Long, '')  
   FROM CodeLKUP WITH (NOLOCK)   
   WHERE ListName = 'PickFilter'  
      AND Code = @nFunc   
      AND StorerKey = @cStorerKey  
      AND Code2 = @cFacility  

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus IN ( '', '0')
      SET @cPickConfirmStatus = '5' -- Not setup, default picked status = '5'

   IF @nStep = 1  -- Doc
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cPSType = ''
         SET @cPickSlipNo = @cDoc1Value

         SELECT @cZone = Zone, 
                @cLoadKey = ExternOrderKey,
                @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)     
         WHERE PickHeaderKey = @cPickSlipNo
      
         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            ORDER BY 1

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 144851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKSlip
               GOTO Quit
            END
            ELSE
               SET @cPSType = 'CUSTOM'
         END  

         IF @cPSType = ''
         BEGIN
            -- Get PickSlip type
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
               SET @cPSType = 'XD'
            ELSE IF @cOrderKey = ''
               SET @cPSType = 'CONSO'
            ELSE 
               SET @cPSType = 'DISCRETE'
         END

         -- conso picklist   
         If @cPSType = 'XD' 
         BEGIN    
            SET @cSQL =   
               ' SELECT @nSum_Qty2Pick = ISNULL( SUM( Qty), 0) ' +   
               ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +   
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) ' +   
               ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +   
               ' AND   PD.StorerKey = @cStorerKey ' +
               ' AND   PD.Status < @cPickConfirmStatus ' +
               ' AND   PD.Status <> ''4'' ' +   
                CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
         END
         -- Discrete PickSlip
         ELSE IF @cPSType = 'DISCRETE' 
         BEGIN
            SET @cSQL =   
               ' SELECT @nSum_Qty2Pick = ISNULL( SUM( Qty), 0) ' +   
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
               ' WHERE PD.OrderKey = @cOrderKey ' + 
               ' AND   PD.StorerKey = @cStorerKey ' +
               ' AND   PD.Status < @cPickConfirmStatus ' +
               ' AND   PD.Status <> ''4'' ' +   
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
         END
         -- CONSO PickSlip
         ELSE IF @cPSType = 'CONSO' 
         BEGIN
            SET @cSQL =   
               ' SELECT @nSum_Qty2Pick = ISNULL( SUM( Qty), 0) ' +   
               ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
               ' WHERE LPD.LoadKey = @cLoadKey ' +
               ' AND   PD.StorerKey = @cStorerKey ' +
               ' AND   PD.Status < @cPickConfirmStatus ' +
               ' AND   PD.Status <> ''4'' ' +   
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
         END
         -- Custom PickSlip
         ELSE
         BEGIN
            SET @cSQL =   
               ' SELECT @nSum_Qty2Pick = ISNULL( SUM( Qty), 0) ' +   
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
               ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
               ' AND   PD.StorerKey = @cStorerKey ' +
               ' AND   PD.Status < @cPickConfirmStatus ' +
               ' AND   PD.Status <> ''4'' ' +   
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
         END

         SET @nSum_Qty2Pick = 0

         SET @cSQLParam =   
            ' @cStorerKey  NVARCHAR( 15), ' +   
            ' @cLoadKey    NVARCHAR( 10), ' +   
            ' @cOrderKey   NVARCHAR( 10), ' + 
            ' @cPickSlipNo NVARCHAR( 10), ' + 
            ' @cPickConfirmStatus   NVARCHAR( 1), ' +
            ' @nSum_Qty2Pick        INT   OUTPUT'
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam  
            ,@cStorerKey  
            ,@cLoadKey   
            ,@cOrderKey 
            ,@cPickSlipNo
            ,@cPickConfirmStatus
            ,@nSum_Qty2Pick   OUTPUT

         IF @nSum_Qty2Pick = 0
         BEGIN
            SET @nErrNo = 144852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing 2 Pack
            GOTO Quit
         END
      END
   END

   IF @nStep = 2 -- Carton ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT TOP 1 
            @cUPCUOM = UOM, 
            @cSKU = SKU
         FROM dbo.UPC UPC WITH (NOLOCK, INDEX(PK_UPC)) 
         WHERE UPC = @cCartonID
         AND StorerKey = @cStorerKey            
         ORDER BY 1

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 144853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UPC
            GOTO Quit
         END

         SELECT @fCaseCnt = CaseCnt
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.Sku = @cSKU
         AND   PackUOM1 = @cUPCUOM

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 144854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UOM
            GOTO Quit
         END

         IF @fCaseCnt = 0
         BEGIN
            SET @nErrNo = 144855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CaseCnt
            GOTO Quit
         END
      END
   END

   Quit:

END

GO