SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_840DecodeSP06                                         */  
/* Copyright: MAERSK                                                          */  
/*                                                                            */  
/* Purpose: Decode SKU, Return OrderKey                                       */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2025-02-13  James     1.0   FCR-2690. Created                              */  
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840DecodeSP06] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,  
   @nInputKey    INT,  
   @cStorerKey   NVARCHAR( 15),  
   @cBarcode     NVARCHAR( 2000),  
   @cDropID      NVARCHAR( 20),  
   @cOrderKey    NVARCHAR( 18)  OUTPUT,  
   @cSKU         NVARCHAR( 20)  OUTPUT,  
   @cTrackingNo  NVARCHAR( 20)  OUTPUT,  
   @cLottable01  NVARCHAR( 18)  OUTPUT,  
   @cLottable02  NVARCHAR( 18)  OUTPUT,  
   @cLottable03  NVARCHAR( 18)  OUTPUT,  
   @cLottable04  DATETIME  OUTPUT,  
   @cLottable05  DATETIME  OUTPUT,  
   @cLottable06  NVARCHAR( 30)  OUTPUT,  
   @cLottable07  NVARCHAR( 30)  OUTPUT,  
   @cLottable08  NVARCHAR( 30)  OUTPUT,  
   @cLottable09  NVARCHAR( 30)  OUTPUT,  
   @cLottable10  NVARCHAR( 30)  OUTPUT,  
   @cLottable11  NVARCHAR( 30)  OUTPUT,  
   @cLottable12  NVARCHAR( 30)  OUTPUT,  
   @cLottable13  DATETIME  OUTPUT,  
   @cLottable14  DATETIME  OUTPUT,  
   @cLottable15  DATETIME  OUTPUT,   
   @cSerialNo    NVARCHAR( 30)  OUTPUT,      
   @nSerialQTY   INT            OUTPUT,                                 
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT,  
   @cPickSlipNo  NVARCHAR( 10)  OUTPUT  
    
  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cTempSKU          NVARCHAR( 30)  
   DECLARE @cTempLottable06   NVARCHAR( 30)  
   DECLARE @cSKUStatus        NVARCHAR( 10) = ''  
   DECLARE @bSuccess          INT  
   DECLARE @cTempOrderKey     NVARCHAR( 10)  
   DECLARE @curORD            CURSOR  
   DECLARE @nPickQty          INT  
   DECLARE @nPackQty          INT  
  
   IF @nStep = 3 -- SKU  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SET @cSKU = ''  
         SET @cTempSKU = LEFT( @cBarcode, 30)  
  
         EXEC [RDT].[rdt_GETSKU]  
            @cStorerKey  = @cStorerkey,      
            @cSKU        = @cTempSKU      OUTPUT,      
            @bSuccess    = @bSuccess      OUTPUT,      
            @nErr        = @nErrNo        OUTPUT,      
            @cErrMsg     = @cErrMsg       OUTPUT,    
            @cSKUStatus  = @cSKUStatus      
  
         SET @curORD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT DISTINCT OrderKey  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cTempSKU  
         AND   [Status] <> '4'  
         AND   [Status] < '9'  
         AND   DropID = @cDropID  
         ORDER BY 1  
         OPEN @curORD  
         FETCH NEXT FROM @curORD INTO @cTempOrderKey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            SET @nPickQty = 0  
            SELECT @nPickQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE Storerkey = @cStorerKey  
            AND   OrderKey = @cTempOrderKey  
            AND   SKU = @cTempSKU  
            AND   [Status] <> '4'  
            AND   [Status] < '9'  
            AND   DropID = @cDropID  
  
            SET @nPackQty = 0  
            SELECT @nPackQty = ISNULL( SUM( PD.Qty), 0)  
            FROM dbo.PACKDETAIL PD WITH (NOLOCK)  
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)  
            WHERE PH.Storerkey = @cStorerKey  
            AND   PH.OrderKey = @cTempOrderKey  
            AND   PD.SKU = @cTempSKU  
  
            IF @nPickQty > @nPackQty  
               BREAK  
  
            FETCH NEXT FROM @curORD INTO @cTempOrderKey  
         END  
  
         IF ISNULL( @cTempOrderKey, '') <> ''  
         BEGIN  
            SET @cSKU = @cTempSKU  
            SET @cOrderKey = @cTempOrderKey  
            SELECT @cPickSlipNo = PickHeaderKey  
            FROM dbo.PICKHEADER WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
         END  
      END  
   END  
  
Quit:  
  
END  
GO