SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_BatchPickSortation_GetStat                      */
/*                                                                      */
/* Purpose: Get qty to display for batch picking sortation              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-07-17 1.0  James      Created                                   */
/* 2018-09-24 1.1  James      WMS7751-Remove OD.loadkey (james01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_BatchPickSortation_GetStat] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLoadKey         NVARCHAR( 10),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20), 
   @nQty             INT,          
   @cSeqNo           NVARCHAR( 20)  OUTPUT,  -- LPD.UserDefine02
   @nExpQTY          INT            OUTPUT,  -- Ttl expected qty for the sku + loadkey
   @nSKUExpQTY       INT            OUTPUT,  -- Ttl expected qty for the sku + orders (LPD.UserDefine02)
   @nTtlScanQty      INT            OUTPUT,  -- Ttl scanned qty for the load (regardless of sku)
   @nTtlExpQty       INT            OUTPUT,  -- Ttl expected qty for the load (regardless of sku)
   @nTtlSKUInLoad    INT            OUTPUT   -- Ttl no. of orders for the sku + loadkey
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cOrderKey      NVARCHAR( 10), 
           @nOrd_QTY       INT, 
           @nSKURequired   INT 
   
   SET @nExpQTY = 0
   SET @nTtlScanQty = 0
   SET @nTtlExpQty = 0
   
   -- Expected qty to scan, based on SKU + Loadkey
   SELECT @nExpQTY = ISNULL( SUM( ( QtyAllocated + QtyPicked) - QtyToProcess), 0)
   FROM dbo.OrderDetail WITH (NOLOCK) 
   WHERE LoadKey = @cLoadKey
   AND   SKU = @cSKU
   AND   StorerKey = @cStorerKey

   -- Total scanned vs Total required to scan, ny Loadkey
   SELECT @nTtlExpQty = ISNULL( SUM( QtyAllocated + QtyPicked), 0),  
          @nTtlScanQty = ISNULL( SUM( QtyToProcess), 0)
   FROM dbo.OrderDetail WITH (NOLOCK) 
   WHERE LoadKey = @cLoadKey
   AND   StorerKey = @cStorerKey
   
   -- Get the total no of orders where the sku resides within the loadkey
   SELECT @nTtlSKUInLoad = COUNT( DISTINCT OrderKey)
   FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU
   AND   LoadKey = @cLoadKey
   AND   (QtyAllocated + QtyPicked) > QtyToProcess
   AND   (QtyAllocated + QtyPicked) > 0

   SET @nTtlSKUInLoad = 0
   SET @nSKURequired = @nQty
   IF @nSKURequired > 0
   BEGIN
      -- Get the total no of orders where the sku resides within the loadkey
      DECLARE @curTtlSKUInLoad CURSOR
      SET @curTtlSKUInLoad = CURSOR FOR 
      SELECT OrderKey, ISNULL( SUM( (QtyAllocated + QtyPicked) - QtyToProcess), 0) 
      FROM dbo.OrderDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
      AND   LoadKey = @cLoadKey
      AND   (QtyAllocated + QtyPicked) > QtyToProcess
      AND   (QtyAllocated + QtyPicked) > 0
      GROUP BY OrderKey
      OPEN @curTtlSKUInLoad
      FETCH NEXT FROM @curTtlSKUInLoad INTO @cOrderKey, @nOrd_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nSKURequired > 0
         BEGIN
            SET @nTtlSKUInLoad = @nTtlSKUInLoad + 1
            SET @nSKURequired = @nSKURequired - @nOrd_QTY
            
            IF @nSKURequired <= 0
               BREAK
         END
         FETCH NEXT FROM @curTtlSKUInLoad INTO @cOrderKey, @nOrd_QTY
      END
      CLOSE @curTtlSKUInLoad
      DEALLOCATE @curTtlSKUInLoad

      -- Get the orders seq in loadplan
      SELECT TOP 1 @cSeqNo = LPD.UserDefine02 
      FROM dbo.LoadplanDetail LPD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON LPD.OrderKey = O.OrderKey
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
      WHERE OD.StorerKey = @cStorerKey
      AND   OD.SKU = @cSKU
      AND   O.LoadKey = @cLoadKey
      AND   (OD.QtyAllocated + OD.QtyPicked) > OD.QtyToProcess
      AND   (OD.QtyAllocated + OD.QtyPicked) > 0
      AND   LPD.UserDefine02 > @cSeqNo
      ORDER BY LPD.UserDefine02

      IF ISNULL(@cSeqNo, '') = ''
      BEGIN
         SET @cSeqNo = ''
         GOTO Quit
      END
   END
  
   -- Get the ttl sku qty for sku + orderkey + loadkey
   SELECT @nSKUExpQTY = ISNULL( SUM( (OD.QtyAllocated + OD.QtyPicked) - OD.QtyToProcess), 0)
   FROM dbo.LoadplanDetail LPD WITH (NOLOCK)
   JOIN dbo.Orders O WITH (NOLOCK) ON LPD.OrderKey = O.OrderKey
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   WHERE OD.StorerKey = @cStorerKey
   AND   OD.SKU = @cSKU
   AND   O.LoadKey = @cLoadKey
   AND   LPD.UserDefine02 = @cSeqNo

   IF @nQty < @nSKUExpQTY
      SET @nSKUExpQTY = @nQty
      
   Quit:
END

GO