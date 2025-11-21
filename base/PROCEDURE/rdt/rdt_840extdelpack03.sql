SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtDelPack03                                 */
/* Purpose: Perform additional clean up besides std sp                  */
/*          1. Clear carton track data                                  */
/*          2. Reassign tracking no by calling sql job                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-08-23 1.0  James      WMS2684. Created                          */
/* 2020-07-13 1.1  James      WMS-13919 Update orders status (james01)  */
/* 2021-04-16 1.1  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james02)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtDelPack03] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cOption     NVARCHAR( 1), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @cPickDetailKey NVARCHAR( 10), 
           @cCaseID        NVARCHAR( 20), 
           @cUserDefine04  NVARCHAR( 20), 
           @cShipperKey    NVARCHAR( 15),
           @cOrderLineNumber  NVARCHAR( 5),
           @cNewStatus     NVARCHAR( 10),
           @cOrdType       NVARCHAR( 10),
           @bSuccess       INT,
           @nLetter        INT,
           @nRowRef        INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtDelPack03

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   OrderKey = @cOrderKey
                   AND   [Status] < '9')
   BEGIN
      SET @nErrNo = 1
      GOTO Quit
   END

   SET @nLetter = 0

   -- Get the original assigned tracking no
   --SELECT @cUserDefine04 = UserDefine04
   SELECT @cUserDefine04 = TrackingNo  -- (james02)
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   -- If it is Letter service then only need clear the tracking no
   IF EXISTS (
              SELECT 1  
              FROM dbo.Orders O WITH (NOLOCK) 
              WHERE O.StorerKey = @cStorerKey
              AND   O.OrderKey = @cOrderKey
              AND   EXISTS ( SELECT 1 
              FROM dbo.CodeLkup CLK WITH (NOLOCK) 
              WHERE O.StorerKey = CLK.StorerKey
              AND   O.ShipperKey = CLK.Code
              AND   CLK.ListName = 'HMCourier' 
              AND   CLK.Short = 'YTC'
              AND   CLK.Long = 'Letter'))
   BEGIN
      SET @nLetter = 1
   END

   IF @nLetter = 1
   BEGIN
      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT RowRef 
      FROM dbo.CartonTrack CT
      WHERE CT.LabelNo = @cOrderKey
      AND   CT.KeyName = 'HM'
      AND   CT.CarrierRef2 = 'GET'
      AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE PD.StorerKey = @cStorerKey
                     AND   CT.LabelNo = PD.OrderKey
                     AND   CT.TrackingNo = PD.CaseID
                     AND   PD.Status <= '5')
      OPEN CUR_DEL
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Clear carton track data
         UPDATE dbo.CartonTrack WITH (ROWLOCK) SET 
            LabelNo = '', 
            CarrierRef2 = ''
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 114151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ctntrk fail
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL
            GOTO RollBackTran
         END  

         FETCH NEXT FROM CUR_DEL INTO @nRowRef
      END
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL
   END

   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT PickDetailKey, OrderLineNumber
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   [Status] <= '5'
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey, @cOrderLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Clear pickdetail case id and reset back to allocated status
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         [Status] = '0',
         CaseID = ''
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 114152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Clr case fail
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD         
         GOTO RollBackTran
      END   

      FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey, @cOrderLineNumber
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   IF @nLetter = 1
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   OrderKey = @cOrderKey
                  AND   Type = 'COD')
      BEGIN
         SELECT @cShipperKey = Code 
         FROM dbo.CodeLkup WITH (NOLOCK) 
         WHERE StorerKey = 'HM' 
         AND   ListName = 'HMCourier' 
         AND   Short = 'YTC'
         AND   Long = 'COD'

         UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
            [Status] = '2',
            ShipperKey = @cShipperKey,
            --UserDefine04 = '',
            TrackingNo = '',  -- (james02)
            TrafficCop = NULL
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   [Status] = '5'

         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 114153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd shippe fail
            GOTO RollBackTran
         END  
      END
      ELSE
      BEGIN
         SELECT @cShipperKey = Code 
         FROM dbo.CodeLkup WITH (NOLOCK) 
         WHERE StorerKey = 'HM' 
         AND   ListName = 'HMCourier' 
         AND   Short = 'YTC'
         AND   Long = 'Normal'

         UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
            [Status] = '2',
            ShipperKey = @cShipperKey,
            --UserDefine04 = '',
            TrackingNo = '',     -- (james02)
            TrafficCop = NULL
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   [Status] = '5'

         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 114154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd shippe fail
            GOTO RollBackTran
         END  
      END

      -- No need run schedule job as it read unallocated orders only. Here manually run the assignment job
      -- EXEC isp_DWStart_SQLJob 'JP-BEJ - Assign Courrier Tracking Number', 'Y'
      IF EXISTS (
         SELECT 1
         FROM dbo.ORDERS O WITH (NOLOCK)  
         WHERE O.OrderKey = @cOrderKey
         AND   O.ShipperKey IS NOT NULL AND O.ShipperKey <> '' 
         --AND   O.UserDefine04 = '' 
         AND   O.TrackingNo = '' -- (james02)
         AND   O.[Status] = '2' 
         AND   O.SOStatus = '0'
         AND  EXISTS(SELECT 1 FROM dbo.CODELKUP AS clk WITH (NOLOCK)  
                     WHERE  clk.Storerkey = O.StorerKey   
                     AND   clk.Short = O.Shipperkey  
                     AND   clk.Notes = O.Facility   
                     AND   clk.LISTNAME = 'AsgnTNo'  
                     AND   clk.code2 = '1'  
                     AND   clk.UDF01 = CASE WHEN ISNULL(clk.UDF01,'') <> '' THEN ISNULL(o.UserDefine02,'') ELSE clk.UDF01 END  
                     AND   clk.UDF02 = CASE WHEN ISNULL(clk.UDF02,'') <> '' THEN ISNULL(o.UserDefine03,'') ELSE clk.UDF02 END     
                     AND   clk.UDF03 = CASE WHEN ISNULL(clk.UDF03,'') <> '' THEN ISNULL(o.[Type], '') ELSE clk.UDF03 END))
      BEGIN
         EXEC dbo.ispAsgnTNo
            @c_OrderKey = @cOrderKey,
            @c_LoadKey = '', 
            @b_Success = 1,
            @n_Err     = @nErrNo OUTPUT,
            @c_ErrMsg  = @cErrMsg OUTPUT,
            @b_debug   = 0

         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 114155
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Asgn Trk Fail
            GOTO RollBackTran
         END  
      END
   END

   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT OrderLineNumber
   FROM dbo.OrderDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   [Status] < '9'
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cOrderLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Update orderdetail back to allocated state
      UPDATE dbo.OrderDetail WITH (ROWLOCK) SET 
         [Status] = CASE WHEN ( QtyAllocated > 0) AND ( QtyPicked > 0)  AND ( QtyAllocated <> QtyPicked) THEN '3'
                         WHEN ( OpenQty + FreeGoodQty) = ( QtyAllocated + QtyPicked + ShippedQty) THEN '2'
                         WHEN ((OpenQty + FreeGoodQty) <> QtyAllocated + QtyPicked)
                          AND ( QtyAllocated + QtyPicked) > 0 
                          AND ( ShippedQty = 0) THEN '1'
                         WHEN ( QtyAllocated + ShippedQty + QtyPicked = 0) THEN '0' END,
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      AND   OrderLineNumber = @cOrderLineNumber

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 114156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ordtl err
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD         
         GOTO RollBackTran
      END  

      FETCH NEXT FROM CUR_UPD INTO @cOrderLineNumber
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   SELECT @cNewStatus = [Status], @cOrdType = Type
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   
   SET @cNewStatus = ''
   EXECUTE dbo.ispGetOrderStatus 
      @c_OrderKey    = @cOrderKey
     ,@c_StorerKey   = @cStorerKey
     ,@c_OrdType     = @cOrdType
     ,@c_NewStatus   = @cNewStatus  OUTPUT
     ,@b_Success     = @bSuccess    OUTPUT
     ,@n_err         = @nErrNo      OUTPUT
     ,@c_errmsg      = @cErrMsg     OUTPUT

   IF @cNewStatus = ''
   BEGIN    
      SET @nErrNo = 114157
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get status err
      GOTO RollBackTran
   END  

   -- (james01)
   IF @cNewStatus = '3'
      SET @cNewStatus = '2'
      
   UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
      [Status] = @cNewStatus,
      TrafficCop = NULL
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF @@ERROR <> 0    
   BEGIN    
      SET @nErrNo = 114158
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd orders err
      GOTO RollBackTran
   END  

   DECLARE CUR_DelPIK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT DISTINCT PickHeaderKey
   FROM dbo.PickHeader WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
   OPEN CUR_DelPIK
   FETCH NEXT FROM CUR_DelPIK INTO @cPickSlipNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.PickingInfo WITH (ROWLOCK) SET 
         ScanOutDate = NULL
      WHERE PickSlipNo = @cPickSlipNo
      AND   ScanOutDate <> NULL

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 114159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pkinfo err
         CLOSE CUR_DelPIK
         DEALLOCATE CUR_DelPIK
         GOTO RollBackTran
      END  

      FETCH NEXT FROM CUR_DelPIK INTO @cPickSlipNo
   END
   CLOSE CUR_DelPIK
   DEALLOCATE CUR_DelPIK

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtDelPack03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_840ExtDelPack03

GO