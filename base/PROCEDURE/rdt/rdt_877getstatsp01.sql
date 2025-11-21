SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_877GetStatSP01                                  */    
/* Copyright: LF Logistics                                              */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-05-17 1.0  Ung      WMS-4846 Created                            */    
/* 2018-08-20 1.1  Grick    Replace PD.Notes with PD.DropID (G01)       */  
/* 2018-10-10 1.2  Ung      WMS-6576 Add inner                          */  
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_877GetStatSP01] (    
   @nMobile    INT,    
   @nFunc      INT,     
   @cLangCode  NVARCHAR( 3),    
   @cUserName  NVARCHAR( 18),    
   @cFacility  NVARCHAR( 5),    
   @cStorerkey NVARCHAR( 15),    
   @cOrderKey  NVARCHAR( 15),    
   @nScan      INT           OUTPUT,    
   @nTotal     INT           OUTPUT, 
   @cBarcode   NVARCHAR(MAX) = ''

) AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   /*----------------------------------------------------------------------------------------------
                                             Inner barcode
   ----------------------------------------------------------------------------------------------*/
   IF LEN( @cBarcode) = 41
   BEGIN
      -- Calc scanned case ID    
      SET @nScan = 0    
      SELECT @nScan = COUNT( DISTINCT PD.Notes)   --G01    
      FROM PickDetail PD WITH (NOLOCK)     
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE PD.OrderKey = @cOrderKey     
         AND PD.Status <> '4' --Short    
         AND PD.QTY > 0    
         AND PD.UOM = '6'
         AND PD.QTY % CAST( Pack.InnerPack AS INT) = 0 -- Full inner    
         AND PD.DropID <> '' -- Scanned    
       
      -- Get order QTY    
      SET @nTotal = 0    
      SELECT @nTotal = ISNULL( SUM( A.InnerCount), 0)    
      FROM     
      (    
         SELECT PD.QTY / Pack.InnerPack AS InnerCount    
         FROM PickDetail PD WITH (NOLOCK)     
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)    
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.Status <> '4' --Short    
            AND PD.QTY > 0    
            AND PD.UOM = '6'
            AND PD.QTY % CAST( Pack.InnerPack AS INT) = 0 -- Full inner    
            AND PD.DropID = '' -- Not yet scan    
            AND SKU.SKUGroup = 'REG'    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'ORIGIN' AND Code = LA.Lottable03 AND StorerKey = @cStorerKey) -- L03 = country of origin    
      ) A    
       
      -- Calc total Case ID    
      SET @nTotal = @nTotal + @nScan    
   END
   
   
   /*----------------------------------------------------------------------------------------------
                                             Case barcode
   ----------------------------------------------------------------------------------------------*/
   --IF LEN( @cBarcode) = 45
   ELSE
   BEGIN
      -- Calc scanned case ID    
      SET @nScan = 0    
      SELECT @nScan = COUNT( DISTINCT PD.Notes)   --G01    
      FROM PickDetail PD WITH (NOLOCK)     
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE PD.OrderKey = @cOrderKey     
         AND PD.Status <> '4' --Short    
         AND PD.QTY > 0    
         AND PD.UOM IN ('1', '2')
         AND PD.QTY % CAST( Pack.CaseCnt AS INT) = 0 -- Full case    
         AND PD.DropID <> '' -- Scanned    
       
      -- Get order QTY    
      SET @nTotal = 0    
      SELECT @nTotal = ISNULL( SUM( A.CartonCount), 0)    
      FROM     
      (    
         SELECT PD.QTY / Pack.CaseCnt AS CartonCount    
         FROM PickDetail PD WITH (NOLOCK)     
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)    
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.Status <> '4' --Short    
            AND PD.QTY > 0    
            AND PD.UOM IN ('1', '2')
            AND PD.QTY % CAST( Pack.CaseCnt AS INT) = 0 -- Full case    
            AND PD.DropID = '' -- Not yet scan    
            AND SKU.SKUGroup = 'REG'    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'ORIGIN' AND Code = LA.Lottable03 AND StorerKey = @cStorerKey) -- L03 = country of origin    
      ) A    
       
      -- Calc total Case ID    
      SET @nTotal = @nTotal + @nScan    
   END
   
   
   /*----------------------------------------------------------------------------------------------
                                             Pallet barcode
   ----------------------------------------------------------------------------------------------*/
   /*
   ELSE
   BEGIN
      -- Calc scanned case ID    
      SET @nScan = 0    
      SELECT @nScan = COUNT( DISTINCT PD.Notes)   --G01    
      FROM PickDetail PD WITH (NOLOCK)     
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE PD.OrderKey = @cOrderKey     
         AND PD.Status <> '4' --Short    
         AND PD.QTY > 0    
         AND PD.UOM = 1
         AND PD.QTY % CAST( Pack.Pallet AS INT) = 0 -- Full pallet    
         AND PD.DropID <> '' -- Scanned    
       
      -- Get order QTY    
      SET @nTotal = 0    
      SELECT @nTotal = ISNULL( SUM( A.PalletCount), 0)    
      FROM     
      (    
         SELECT PD.QTY / Pack.CaseCnt AS PalletCount    
         FROM PickDetail PD WITH (NOLOCK)     
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)    
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.Status <> '4' --Short    
            AND PD.QTY > 0    
            AND PD.UOM = 1
            AND PD.QTY % CAST( Pack.Pallet AS INT) = 0 -- Full pallet    
            AND PD.DropID = '' -- Not yet scan    
            AND SKU.SKUGroup = 'REG'    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID    
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'ORIGIN' AND Code = LA.Lottable03 AND StorerKey = @cStorerKey) -- L03 = country of origin    
      ) A    
       
      -- Calc total Case ID    
      SET @nTotal = @nTotal + @nScan
   END
   */
   
Quit: 


GO