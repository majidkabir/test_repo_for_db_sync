SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_InsertAllocShortageLog                         */
/* Creation Date: 17-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                         */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 21-Jul-2017  TLTING   1.1  SET Option                                */
/************************************************************************/

CREATE PROC [dbo].[isp_InsertAllocShortageLog] 
  ( 
   @cLoadKey  NVARCHAR(10) = '', 
   @cWaveKey  NVARCHAR(10) = '',
   @cOrderKey NVARCHAR(10) = '' 
   ) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cOrderLineNumber NVARCHAR(5),
           @cSKU             NVARCHAR(20),
           @nOriginalQty         INT,
           @nAllocatedQty    INT,
           @nQtyOnHand       INT,
           @nQtyOnHold       INT,
           @nQtyRcptInProgress INT,
           @nBackToStep        INT,
           @cStorerKey         NVARCHAR(15) 
           
   IF LEN(@cOrderKey) = 0
   BEGIN
      IF LEN(@cLoadKey) > 0 
      BEGIN
         DECLARE CUR_LOADPLANDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OrderKey FROM LoadPlanDetail lpd (NOLOCK)
            WHERE LoadKey = @cLoadKey  
         
         OPEN CUR_LOADPLANDETAIL 
         FETCH NEXT FROM CUR_LOADPLANDETAIL INTO @cOrderKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @nBackToStep = 1
            GOTO StartProcessOrder 
            
            GET_NEXT_LOAD_ORDER:
            FETCH NEXT FROM CUR_LOADPLANDETAIL INTO @cOrderKey
         END
         CLOSE CUR_LOADPLANDETAIL
         DEALLOCATE CUR_LOADPLANDETAIL
      END
      IF LEN(@cWaveKey) > 0 
      BEGIN
         DECLARE CUR_WAVEPLANDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OrderKey FROM WaveDetail lpd (NOLOCK)
            WHERE WaveKey = @cWaveKey  
         
         OPEN CUR_WAVEDETAIL 
         FETCH NEXT FROM CUR_WAVEDETAIL INTO @cOrderKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @nBackToStep = 2
            GOTO StartProcessOrder 
            
            GET_NEXT_WAVE_ORDER:
            FETCH NEXT FROM CUR_WAVEDETAIL INTO @cOrderKey
         END
         CLOSE CUR_WAVEDETAIL
         DEALLOCATE CUR_WAVEDETAIL
      END      
   END
   
   StartProcessOrder:
   IF LEN(@cOrderKey) > 0 
   BEGIN
      DECLARE cur_OrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT o.OrderLineNumber, o.StorerKey, o.SKU, o.OriginalQty 
         FROM ORDERDETAIL o WITH (NOLOCK) 
         WHERE o.OrderKey = @cOrderKey
         
      OPEN cur_OrderLine 
      
      FETCH NEXT FROM cur_OrderLine INTO @cOrderLineNumber, @cStorerKey, @cSKU, @nOriginalQty 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @nAllocatedQty = ISNULL(SUM(Qty),0) 
         FROM PICKDETAIL p (NOLOCK)
         WHERE OrderKey = @cOrderKey 
         AND   OrderLineNumber = @cOrderLineNumber
         
         IF @nOriginalQty>@nAllocatedQty
         BEGIN
            SELECT @nQtyOnHand = SUM(Qty - QtyAllocated - QtyPicked)
            FROM   SKUxLOC WITH (NOLOCK)
            WHERE  StorerKey = @cStorerKey 
            AND    SKU = @cSKU
            
            SELECT @nQtyOnHold = SUM(LOTxLOCxID.QTY)  
            FROM   LOTxLOCxID(NOLOCK)
            JOIN   LOC(NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
            JOIN   ID(NOLOCK) ON LOTxLOCxID.ID = ID.ID 
            JOIN   LOT(NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT 
            WHERE (ID.STATUS = 'HOLD'
             OR LOC.STATUS = 'HOLD'
             OR LOC.LocationFlag IN ('HOLD','DAMAGE')    
             OR LOT.Status = 'HOLD') AND LOTxLOCxID.StorerKey = @cStorerKey AND LOTxLOCxID.Sku = @cSKU 
     
            IF EXISTS(SELECT 1 FROM AllocShortageLog asl WITH (NOLOCK) 
                      WHERE asl.OrderKey = @cOrderKey 
                      AND   asl.OrderLineNumber = @cOrderLineNumber)
            BEGIN 
               DELETE FROM AllocShortageLog  
               WHERE OrderKey = @cOrderKey 
               AND   OrderLineNumber = @cOrderLineNumber     
            END
            INSERT INTO AllocShortageLog
            (  OrderKey,          OrderLineNumber,          StorerKey,
               SKU,               OrderedQty,               AllocatedQty,
               QtyOnHand,         QtyOnHold,                QtyReceiptInProgress
            )
            VALUES
            (
               @cOrderKey,
               @cOrderLineNumber,
               @cStorerKey,
               @cSKU,
               @nOriginalQty,
               ISNULL(@nAllocatedQty,0),
               ISNULL(@nQtyOnHand,0),
               ISNULL(@nQtyOnHold,0),
               0
            )
         END
                    
            
         FETCH NEXT FROM cur_OrderLine INTO @cOrderLineNumber, @cStorerKey, @cSKU, @nOriginalQty
      END
      CLOSE cur_OrderLine
      DEALLOCATE cur_OrderLine 
   END
   IF @nBackToStep = 1
   BEGIN
      SET @nBackToStep = 0 
      GOTO GET_NEXT_LOAD_ORDER
   END
   IF @nBackToStep = 2
   BEGIN
      SET @nBackToStep = 0 
      GOTO GET_NEXT_WAVE_ORDER
   END       
   
END -- Stored Procedure 

GO