SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_903ExtUOM01                                     */
/* Purpose: Get prefered UOM qty from consigneesku table                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2018-08-15  1.0  James      WMS-5770. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_903ExtUOM01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @cType            NVARCHAR( 10), 
   @cRefNo           NVARCHAR( 10),  
   @cPickSlipNo      NVARCHAR( 10),  
   @cLoadKey         NVARCHAR( 10),   
   @cOrderKey        NVARCHAR( 10),   
   @cDropID          NVARCHAR( 20),   
   @cSKU             NVARCHAR( 20),   
   @nQTY             INT,             
   @nRowRef          INT,            
   @cLottable01      NVARCHAR( 18),  
   @cLottable02      NVARCHAR( 18),  
   @cLottable03      NVARCHAR( 18),  
   @dLottable04      DATETIME,       
   @dLottable05      DATETIME,       
   @cLottable06      NVARCHAR( 30),  
   @cLottable07      NVARCHAR( 30),  
   @cLottable08      NVARCHAR( 30),  
   @cLottable09      NVARCHAR( 30),  
   @cLottable10      NVARCHAR( 30),  
   @cLottable11      NVARCHAR( 30),  
   @cLottable12      NVARCHAR( 30),  
   @dLottable13      DATETIME,       
   @dLottable14      DATETIME,       
   @dLottable15      DATETIME,       
   @cPUOM            NVARCHAR( 1),
   @nExtPUOM_Div     INT            OUTPUT,  
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTempExtPUOM_Div INT
   
   SET @nTempExtPUOM_Div = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         SELECT @nTempExtPUOM_Div = CS.CrossSkuqty 
         FROM dbo.ConsigneeSku CS WITH (NOLOCK)
         JOIN dbo.Orders OS WITH (NOLOCK) ON ( CS.Consigneekey = OS.Consigneekey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( CS.SKU = PD.SKU AND OS.Orderkey = PD.Orderkey)
         WHERE PD.DropID = @cDropID 
         AND PD.SKU = @cSKU 
         AND PD.Storerkey = @cStorerKey 
         AND PD.UOM = @cPUOM

         SET @nExtPUOM_Div = ISNULL( @nTempExtPUOM_Div, 0)
      END
   END

   GOTO Quit

   Quit:

GO