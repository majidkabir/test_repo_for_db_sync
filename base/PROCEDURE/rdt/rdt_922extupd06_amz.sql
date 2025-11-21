SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************************************/
/* Store procedure: rdt_922ExtUpd06_AMZ                                                            */
/* Copyright      : Maersk                                                                         */
/* Customer       : AMZ                                                                            */
/*                                                                                                 */
/* Purpose: Scanned carton split to different order, to enable partial ship feature                */
/*                                                                                                 */
/* Date       Rev    Author     Purposes                                                           */
/* 2024-10-18 1.0    VJI011     none packing process enhancement for AMZ                           */
/* 2024-10-18 1.1.0  NLT013     UWP-27868 Open qty is wrong                                        */
/***************************************************************************************************/

CREATE       PROC [RDT].[rdt_922ExtUpd06_AMZ] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3),
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 922 -- Scan to truck (by label no)
   BEGIN
      IF @nStep = 2 -- LabelNo/DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cMBOLKey <> ''
            BEGIN
               DECLARE @n_Err       INT
               DECLARE @c_ErrMsg    NVARCHAR( 250)
               DECLARE @b_Success   INT
               DECLARE @cFacility   NVARCHAR(5)

               DECLARE @cChildOrderKey  NVARCHAR( 10)
               DECLARE @cParentOrderKey NVARCHAR( 10)
               DECLARE @cExternOrderKey NVARCHAR( 50)
               DECLARE @cOrderLineNumber NVARCHAR( 5)
               DECLARE @cStatus         NVARCHAR( 10)
               DECLARE @nQtyAllocated   INT
               DECLARE @nQtyPicked      INT
               DECLARE @nQty            INT

               -- Get session info
               SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_922ExtUpd06_AMZ -- For rollback or commit only our own transaction

               /***********************************************************************************************
                Orders, OrderInfo, OrderDetail, PickDetail, RefKeyLookup, LoadPlanDetail, MBOLDetail
               ***********************************************************************************************/
               -- Loop parent PickDetail (could be multiple orders)
               DECLARE @curPD CURSOR 
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT O.ExternOrderKey, PD.OrderKey, PD.OrderLineNumber, PD.Status, SUM( PD.QTY)
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.StorerKey = @cStorerKey
                     AND O.Facility = @cFacility
                     --AND PD.CaseID = @cLabelNo
                     AND PD.Status = '5'
                     AND PD.DROPID = @cLabelNo      --only check dropid for AMZ
                  GROUP BY O.ExternOrderKey, PD.OrderKey, PD.OrderLineNumber, PD.SKU, PD.Status
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cExternOrderKey, @cParentOrderKey, @cOrderLineNumber, @cStatus, @nQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @nQtyAllocated = CASE WHEN @cStatus < '5' THEN @nQTY ELSE 0 END
                  SET @nQtyPicked    = CASE WHEN @cStatus = '5' THEN @nQTY ELSE 0 END

                  -- Find child order
                  SET @cChildOrderKey = ''
                  SELECT @cChildOrderKey = OrderKey
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND Facility = @cFacility
                     AND ExternOrderKey = @cExternOrderKey  -- Same as parent
                     AND MBOLKey = @cMBOLKey                -- Parent don't have MBOLKey. Child MBOL is auto created thru REFNO lookup SP
                     AND Status <= '5'                      -- Not yet ship
                     AND SOStatus NOT IN ('CANC', 'CLOSED') -- Not cancel or close

                  -- Top up / create child order
                  IF @cChildOrderKey = ''
                  BEGIN
                     -- Get new OrderKey
                     EXECUTE nspg_GetKey
                        'ORDER',
                        10,
                        @cChildOrderKey   OUTPUT,
                        @b_Success        OUTPUT,
                        @n_Err            OUTPUT,
                        @c_ErrMsg         OUTPUT
                     IF @b_Success <> 1
                     BEGIN
                        SET @nErrNo = 212001
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --nspg_GetKey Fail
                        GOTO RollbackTran
                     END

                     INSERT INTO dbo.Orders (
                        OrderKey,         StorerKey,           ExternOrderKey,      OrderDate,
                        DeliveryDate,     Priority,            ConsigneeKey,        C_contact1,
                        C_Contact2,       C_Company,           C_Address1,          C_Address2,
                        C_Address3,       C_Address4,          C_City,              C_State,
                        C_Zip,            C_Country,           C_ISOCntryCode,      C_Phone1,
                        C_Phone2,         C_Fax1,              C_Fax2,              C_vat,
                        BuyerPO,          BillToKey,           B_contact1,          B_Contact2,
                        B_Company,        B_Address1,          B_Address2,          B_Address3,
                        B_Address4,       B_City,              B_State,             B_Zip,
                        B_Country,        B_ISOCntryCode,      B_Phone1,            B_Phone2,
                        B_Fax1,           B_Fax2,              B_Vat,               IncoTerm,
                        PmtTerm,          OpenQty,             [Status],            DischargePlace,
                        DeliveryPlace,    IntermodalVehicle,   CountryOfOrigin,     CountryDestination,
                        UpdateSource,     [Type],              OrderGroup,          Door,
                        [Route],          [Stop],              Notes,               EffectiveDate,
                        ContainerType,    ContainerQty,        BilledContainerQty,  SOStatus,
                        MBOLKey,          InvoiceNo,           InvoiceAmount,       Salesman,
                        GrossWeight,      Capacity,            PrintFlag,           LoadKey,
                        Rdd,              Notes2,              SequenceNo,          Rds,
                        SectionKey,       Facility,            PrintDocDate,        LabelPrice,
                        POKey,            ExternPOKey,         XDockFlag,           UserDefine01,
                        UserDefine02,     UserDefine03,        UserDefine04,        UserDefine05,
                        UserDefine06,     UserDefine07,        UserDefine08,        UserDefine09,
                        UserDefine10,     Issued,              DeliveryNote,        PODCust,
                        PODArrive,        PODReject,           PODUser,             xdockpokey,
                        SpecialHandling,  RoutingTool,         MarkforKey,          M_Contact1,
                        M_Contact2,       M_Company,           M_Address1,          M_Address2,
                        M_Address3,       M_Address4,          M_City,              M_State,
                        M_Zip,            M_Country,           M_ISOCntryCode,      M_Phone1,
                        M_Phone2,         M_Fax1,              M_Fax2,              M_vat,
                        ShipperKey,       DocType,             TrackingNo,          ECOM_PRESALE_FLAG,
                        ECOM_SINGLE_Flag, CurrencyCode,        RTNTrackingNo,       BizUnit,
                        HashValue,        ECOM_OAID,           ECOM_Platform)
                     SELECT
                        @cChildOrderKey,  StorerKey,           ExternOrderKey,      OrderDate,
                        DeliveryDate,     Priority,            ConsigneeKey,        C_contact1,
                        C_Contact2,       C_Company,           C_Address1,          C_Address2,
                        C_Address3,       C_Address4,          C_City,              C_State,
                        C_Zip,            C_Country,           C_ISOCntryCode,      C_Phone1,
                        C_Phone2,         C_Fax1,              C_Fax2,              C_vat,
                        BuyerPO,          BillToKey,           B_contact1,          B_Contact2,
                        B_Company,        B_Address1,          B_Address2,          B_Address3,
                        B_Address4,       B_City,              B_State,             B_Zip,
                        B_Country,        B_ISOCntryCode,      B_Phone1,            B_Phone2,
                        B_Fax1,           B_Fax2,              B_Vat,               IncoTerm,
                        PmtTerm,          OpenQty=@nQty,       [Status]='5',        DischargePlace,
                        DeliveryPlace,    IntermodalVehicle,   CountryOfOrigin,     CountryDestination,
                        UpdateSource,     [Type],              OrderGroup,          Door,
                        [Route],          [Stop],              Notes,               EffectiveDate,
                        ContainerType,    ContainerQty,        BilledContainerQty,  SOStatus,
                        @cMBOLKey,        InvoiceNo,           InvoiceAmount,       Salesman,
                        GrossWeight=0,    Capacity=0,          PrintFlag,           LoadKey,
                        Rdd='SplitOrder', Notes2,              SequenceNo,          Rds,
                        SectionKey,       Facility,            PrintDocDate,        LabelPrice,
                        POKey,            ExternPOKey,         XDockFlag,           UserDefine01,
                        UserDefine02,     UserDefine03,        UserDefine04,        UserDefine05,
                        UserDefine06,     UserDefine07,        UserDefine08,        UserDefine09,
                        UserDefine10,     Issued,              DeliveryNote,        PODCust,
                        PODArrive,        PODReject,           PODUser,             XDOCKPOKEY,
                        SpecialHandling,  RoutingTool,         MarkforKey,          M_Contact1,
                        M_Contact2,       M_Company,           M_Address1,          M_Address2,
                        M_Address3,       M_Address4,          M_City,              M_State,
                        M_Zip,            M_Country,           M_ISOCntryCode,      M_Phone1,
                        M_Phone2,         M_Fax1,              M_Fax2,              M_vat,
                        ShipperKey,       DocType,             TrackingNo,          ECOM_PRESALE_FLAG,
                        ECOM_SINGLE_Flag, CurrencyCode,        RTNTrackingNo,       BizUnit,
                        HashValue,        ECOM_OAID,           ECOM_Platform
                     FROM dbo.Orders WITH (NOLOCK)
                     WHERE OrderKey = @cParentOrderKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 212002
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS Order Fail
                        GOTO RollbackTran
                     END

                     -- OrderInfo
                     INSERT INTO dbo.OrderInfo (
                        OrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10, 
                        EcomOrderId, ReferenceId, StoreName, Platform, InvoiceType, PmtDate, InsuredAmount, CarrierCharges, OtherCharges, PayableAmount,
                        DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty, CourierTimeStamp)
                     SELECT
                        @cChildOrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10,
                        EcomOrderId, ReferenceId, StoreName, Platform, InvoiceType, PmtDate, InsuredAmount, CarrierCharges, OtherCharges, PayableAmount,
                        DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty, CourierTimeStamp
                     FROM dbo.OrderInfo WITH (NOLOCK)
                     WHERE OrderKey = @cParentOrderKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 212003
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS OrdInfFail
                        GOTO RollbackTran
                     END
                     
                     -- MBOLDetail
                     IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cChildOrderKey)
                     BEGIN
                        INSERT INTO dbo.MBOLDetail 
                           (MBOLKey, MBOLLineNumber, OrderKey)
                        VALUES 
                           (@cMBOLKey, '00000', @cChildOrderKey)
                        IF @@ERROR <> 0  
                        BEGIN
                           SET @nErrNo = 212004
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS MBDtl Fail
                           GOTO RollbackTran
                        END 
                     END
                  END

                  -- Top up / create child OrderDetail
                  IF NOT EXISTS( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) WHERE OrderKey = @cChildOrderKey AND OrderLineNumber = @cOrderLineNumber)  
                  BEGIN
                     INSERT INTO dbo.OrderDetail (  
                        OrderKey,            OrderLineNumber,  OrderDetailSysId,    ExternOrderKey,  
                        ExternLineNo,        Sku,              StorerKey,           ManufacturerSku,  
                        RetailSku,           AltSku,           OriginalQty,         OpenQty,  
                        ShippedQty,          AdjustedQty,      QtyPreAllocated,     QtyAllocated,  
                        QtyPicked,           UOM,              PackKey,             PickCode,  
                        CartonGroup,         Lot,              ID,                  Facility,  
                        [Status],            UnitPrice,        Tax01,               Tax02,  
                        ExtendedPrice,       UpdateSource,     Lottable01,          Lottable02,  
                        Lottable03,          Lottable04,       Lottable05,          FreeGoodQty,  
                        GrossWeight,         Capacity,         LoadKey,             MBOLKey,  
                        QtyToProcess,        MinShelfLife,     UserDefine01,        UserDefine02,  
                        UserDefine03,        UserDefine04,     UserDefine05,        UserDefine06,  
                        UserDefine07,        UserDefine08,     UserDefine09,        POkey,  
                        ExternPOKey,         UserDefine10,     EnteredQTY,          ConsoOrderKey,  
                        ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,          Lottable07,            
                        Lottable08,          Lottable09,       Lottable10,          Lottable11,
                        Lottable12,          Lottable13,       Lottable14,          Lottable15,  
                        Notes,               Notes2,           Channel,             HashValue, 
                        SalesChannel)  
                     SELECT  
                        @cChildOrderKey,     OrderLineNumber,  OrderDetailSysId,    ExternOrderKey,  
                        ExternLineNo,        Sku,              StorerKey,           ManufacturerSku,  
                        RetailSku,           AltSku,           OriginalQty=@nQty,   OpenQty=@nQty,  
                        ShippedQty,          AdjustedQty=0,    QtyPreAllocated=0,   @nQtyAllocated,  
                        @nQtyPicked,         UOM,              PackKey,             PickCode,  
                        CartonGroup,         Lot,              ID,                  Facility,  
                        [Status]='5',        UnitPrice,        Tax01,               Tax02,  
                        ExtendedPrice,       UpdateSource,     Lottable01,          Lottable02,  
                        Lottable03,          Lottable04,       Lottable05,          FreeGoodQty,  
                        GrossWeight,         Capacity,         LoadKey,             @cMBOLKey,  
                        QtyToProcess,        MinShelfLife,     UserDefine01,        UserDefine02,  
                        UserDefine03,        UserDefine04,     UserDefine05,        UserDefine06,  
                        UserDefine07,        UserDefine08,     UserDefine09,        POkey,  
                        ExternPOKey,         UserDefine10,     EnteredQTY=0,        ConsoOrderKey,       
                        ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,          Lottable07,            
                        Lottable08,          Lottable09,       Lottable10,          Lottable11,
                        Lottable12,          Lottable13,       Lottable14,          Lottable15,        
                        Notes,               Notes2,           Channel,             HashValue, 
                        SalesChannel
                     FROM dbo.OrderDetail WITH (NOLOCK)  
                     WHERE OrderKey = @cParentOrderKey  
                        AND OrderLineNumber = @cOrderLineNumber  
                     IF @@ERROR <> 0  
                     BEGIN
                        SET @nErrNo = 212007
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS OrdDtlFail
                        GOTO RollbackTran
                     END
                  END
                  ELSE
                  BEGIN
                     UPDATE dbo.OrderDetail SET 
                        OriginalQty  =  OriginalQty + @nQTY,  
                        OpenQty      =  OpenQty + @nQTY,  
                        QtyPicked    =  QtyPicked + @nQtyPicked, 
                        QtyAllocated =  QtyAllocated + @nQtyAllocated,  
                        Status       =  '5',  
                        EditDate = GETDATE(),  
                        EditWho = SUSER_SNAME(), 
                        TrafficCop   = NULL  
                     WHERE OrderKey = @cChildOrderKey  
                        AND OrderLineNumber = @cOrderLineNumber  
                     IF @@ERROR <> 0  
                     BEGIN
                        SET @nErrNo = 212008
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --UPD OrdDtlFail
                        GOTO RollbackTran
                     END
                  END

              --Reset OpenQty and Status for child order
              DECLARE @nChildTotalQty INT
              SELECT @nChildTotalQty = SUM(OpenQty)
              FROM dbo.OrderDetail WITH(NOLOCK)
              WHERE OrderKey = @cChildOrderKey  
                 AND StorerKey = @cStorerKey

               UPDATE dbo.ORDERS WITH(ROWLOCK)
               SET 
                  OpenQty      = @nChildTotalQty, 
                  Status         = '5',
                  EditDate     = GETDATE(),  
                  EditWho = SUSER_SNAME(), 
                  TrafficCop   = NULL  
               WHERE OrderKey = @cChildOrderKey  
               AND StorerKey = @cStorerKey

               UPDATE dbo.OrderDetail WITH(ROWLOCK)
               SET
                  Status         = '5',
                  EditDate     = GETDATE(),  
                  EditWho = SUSER_SNAME(), 
                  TrafficCop   = NULL  
               WHERE OrderKey = @cChildOrderKey  
                  AND StorerKey = @cStorerKey
                  
                  -- Reduce parent OrderDetail
                  UPDATE dbo.OrderDetail SET
                     OriginalQty  = OriginalQty - @nQTY,  
                     OpenQty      = OpenQty - @nQTY,  
                     QtyPicked    = QtyPicked - @nQtyPicked, 
                     QtyAllocated = QtyAllocated - @nQtyAllocated, 
                     /*
                     Status       = 
                        -- Reference ntrOrderDetailUpdate but not exactly follow (for e.g. without the ship part, as parent order does not ship)
                        CASE   
                           -- 0=Open (alloc + pick) = 0
                           WHEN (QtyAllocated - @nQtyAllocated) + (QtyPicked - @nQtyPicked) = 0 THEN '0'
                           
                           -- 1=Partially allocated (open > alloc and pick = 0)
                           WHEN (OpenQty - @nQTY) > (QtyAllocated - @nQtyAllocated) AND (QtyPicked - @nQtyPicked) = 0 THEN '1'

                           -- 2=Fully allocated (open = alloc and pick = 0)
                           WHEN (OpenQty - @nQTY) = (QtyAllocated - @nQtyAllocated) AND (QtyPicked - @nQtyPicked) = 0 THEN '2'
                           
                           -- 3=Picking in progress (alloc > 0 and pick > 0)
                           WHEN (QtyAllocated - @nQtyAllocated) > 0 AND (QtyPicked - @nQtyPicked) > 0 THEN '3'          
                           
                           -- 5=Fully picked (alloc = 0 and pick > 0)
                           WHEN (QtyAllocated - @nQtyAllocated) = 0 AND (QtyPicked - @nQtyPicked) > 0 THEN '5'
                           ELSE Status
                        END,
                     */ 
                     EditDate = GETDATE(),  
                     TrafficCop = NULL 
                  WHERE OrderKey = @cParentOrderKey
                     AND OrderLineNumber = @cOrderLineNumber
                  IF @@ERROR <> 0  
                  BEGIN
                     SET @nErrNo = 212009
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --UPD Order Fail
                     GOTO RollbackTran
                  END

              --Reset OpenQty for parent order
              DECLARE @nParentTotalQty INT
              SELECT @nParentTotalQty = SUM(OpenQty)
              FROM dbo.OrderDetail WITH(NOLOCK)
              WHERE OrderKey = @cParentOrderKey  
                 AND StorerKey = @cStorerKey

               UPDATE dbo.ORDERS WITH(ROWLOCK)
               SET 
                  OpenQty      = @nParentTotalQty, 
                  EditDate     = GETDATE(),  
                  EditWho = SUSER_SNAME(), 
                  TrafficCop   = NULL  
               WHERE OrderKey = @cParentOrderKey  
                  AND StorerKey = @cStorerKey
                  
                  -- Change RefKeyLookUp (from parent to child)
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE OrderKey = @cParentOrderKey AND OrderLineNumber = @cOrderLineNumber)
                  BEGIN
                     UPDATE dbo.RefKeyLookUp SET
                        OrderKey = @cChildOrderKey, 
                        EditDate = GETDATE() 
                     FROM dbo.RefKeyLookUp RKL  
                        JOIN dbo.PicKDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                     WHERE PD.OrderKey = @cParentOrderKey  
                        AND PD.OrderLineNumber = @cOrderLineNumber  
                        --AND PD.CaseID = @cLabelNo  
                        AND PD.Status = '5'
                        AND PD.DROPID = @cLabelNo       --only check dropid for AMZ
                     IF @@ERROR <> 0  
                     BEGIN
                        SET @nErrNo = 212010
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --UPD RKL Fail
                        GOTO RollbackTran
                     END 
                  END
                  
                  -- Change PickDetail (from parent to child)
                  UPDATE dbo.PickDetail SET
                     OrderKey = @cChildOrderKey, 
                     EditDate = GETDATE(),  
                     TrafficCop = NULL 
                  WHERE OrderKey = @cParentOrderKey  
                     AND OrderLineNumber = @cOrderLineNumber
                     --AND CaseID = @cLabelNo
                     AND Status = '5'
                     AND DROPID = @cLabelNo     --only check dropid for AMZ
                  IF @@ERROR <> 0  
                  BEGIN
                     SET @nErrNo = 212011
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --UPD OrdDtlFail
                     GOTO RollbackTran
                  END
                  
                  FETCH NEXT FROM @curPD INTO @cExternOrderKey, @cParentOrderKey, @cOrderLineNumber, @cStatus, @nQTY
               END
               
               /***********************************************************************************************
                PackHeader, PackDetail, PackDetailInfo, PackSerialNo, PackInfo
               ***********************************************************************************************/
               DECLARE @cParentPickSlipNo    NVARCHAR( 10) = ''
               DECLARE @cChildPickSlipNo     NVARCHAR( 10) = ''
               DECLARE @cParentPackOrderKey  NVARCHAR( 10)
               DECLARE @cParentConsigneeKey  NVARCHAR( 15)
               DECLARE @cParentPackLoadKey   NVARCHAR( 10)
               DECLARE @cChildLoadKey        NVARCHAR( 10)
               DECLARE @nCartonNo            INT
               
               -- Get PickSlip
               SELECT TOP 1 
                   @cParentPickSlipNo = PH.PickSlipNo, 
                   @cParentPackOrderKey = PH.OrderKey, 
                   @cParentPackLoadKey = PH.LoadKey, 
                   @cParentConsigneeKey = PH.ConsigneeKey, 
                   @nCartonNo = CartonNo
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PH.StorerKey = @cStorerKey 
                  AND PD.LabelNo = @cLabelNo
               
               -- Packing found
               IF @@ROWCOUNT > 0
               BEGIN
                  -- Discrete pack
                  IF @cParentPackOrderKey <> ''
                  BEGIN
                     -- Not generate new Load for discrete pack. Reuse parent LoadKey
                     SET @cChildLoadKey = @cParentPackLoadKey

                     -- Get child pickslip
                     SELECT @cChildPickSlipNo = PickSlipNo
                     FROM dbo.PackHeader WITH (NOLOCK) 
                     WHERE OrderKey = @cChildOrderKey
                  END
                  
                  -- Conso pack (by consignee). 1 load 1 consignee
                  ELSE IF @cParentPackLoadKey <> ''
                  BEGIN
                     -- Find any new LoadKey created for the carton
                     SET @cChildLoadKey = ''
                     SELECT TOP 1
                        @cChildLoadKey = O.LoadKey
                     FROM dbo.Orders O WITH (NOLOCK)
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.StorerKey = @cStorerKey
                        AND O.Facility = @cFacility
                        --AND PD.CaseID = @cLabelNo
                        AND PD.Status = '5'
                        AND PD.DROPID = @cLabelNo       --only check dropid for AMZ
                        AND O.LoadKey <> @cParentPackLoadKey

                     IF @cChildLoadKey = ''
                     BEGIN
                        -- Get new LoadKey
                        EXECUTE nspg_GetKey
                           'LoadKey',
                           10,
                           @cChildLoadKey OUTPUT,
                           @b_Success     OUTPUT,
                           @n_Err         OUTPUT,
                           @c_ErrMsg      OUTPUT
                        IF @b_Success <> 1
                        BEGIN
                           SET @nErrNo = 212012
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --nspg_GetKey Fail
                           GOTO RollbackTran
                        END
                        
                        INSERT INTO dbo.LoadPlan (
                           LoadKey,                CaseCnt,                   PalletCnt,              Weight,
                           Cube,                   CustCnt,                   Status,                 TruckSize,
                           SuperOrderFlag,         SectionKey,                CarrierKey,             Route,
                           TrfRoom,                DummyRoute,                MBOLKey,                OrderCnt,
                           facility,               PROCESSFLAG,               Return_Weight,          Return_Cube,
                           Vehicle_Type,           Driver,                    Delivery_Zone,          Truck_Type,
                           Load_Userdef1,          Load_Userdef2,             weightlimit,            volumelimit,
                           AllocatedCube,          AllocatedWeight,           AllocatedCaseCnt,       AllocatedPalletCnt,
                           AllocatedOrderCnt,      AllocatedCustCnt,          lpuserdefdate01,        FinalizeFlag,
                           UserDefine01,           UserDefine02,              UserDefine03,           UserDefine04,
                           UserDefine05,           UserDefine06,              UserDefine07,           UserDefine08,
                           UserDefine09,           UserDefine10,              ExternLoadKey,          CtnTyp1,
                           CtnTyp2,                CtnTyp3,                   CtnTyp4,                CtnTyp5,
                           CtnCnt1,                CtnCnt2,                   CtnCnt3,                CtnCnt4,
                           CtnCnt5,                TotCtnWeight,              TotCtnCube,             CartonGroup,
                           Priority,               DispatchPalletPickMethod,  DispatchCasePickMethod, DispatchPiecePickMethod,
                           LoadPickMethod,         MBOLGroupMethod,           DefaultStrategykey,     BookingNo,
                           OTM_DispatchDate,       PickupDate)
                        SELECT
                           @cChildLoadKey,         CaseCnt=0,                 PalletCnt=0,            Weight=0,
                           Cube=0,                 CustCnt=0,                 Status='0',             TruckSize,
                           SuperOrderFlag,         SectionKey,                CarrierKey,             Route,
                           TrfRoom,                DummyRoute,                @cMBOLKey,              OrderCnt=0,
                           facility,               PROCESSFLAG,               Return_Weight,          Return_Cube,
                           Vehicle_Type,           Driver,                    Delivery_Zone,          Truck_Type,
                           Load_Userdef1,          Load_Userdef2,             weightlimit,            volumelimit,
                           AllocatedCube=0,        AllocatedWeight=0,         AllocatedCaseCnt=0,     AllocatedPalletCnt=0,
                           AllocatedOrderCnt=0,    AllocatedCustCnt=0,        lpuserdefdate01,        FinalizeFlag,
                           UserDefine01,           UserDefine02,              UserDefine03,           UserDefine04,
                           UserDefine05,           UserDefine06,              UserDefine07,           UserDefine08,
                           UserDefine09,           UserDefine10,              ExternLoadKey,          CtnTyp1=0,
                           CtnTyp2=0,              CtnTyp3=0,                 CtnTyp4=0,              CtnTyp5=0,
                           CtnCnt1=0,              CtnCnt2=0,                 CtnCnt3=0,              CtnCnt4=0,
                           CtnCnt5=0,              TotCtnWeight=0,            TotCtnCube=0,           CartonGroup,
                           Priority,               DispatchPalletPickMethod,  DispatchCasePickMethod, DispatchPiecePickMethod,
                           LoadPickMethod,         MBOLGroupMethod,           DefaultStrategykey,     BookingNo,
                           OTM_DispatchDate,       PickupDate
                        FROM dbo.LoadPlan WITH (NOLOCK)
                        WHERE LoadKey = @cParentPackLoadKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 212013
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS Load Fail
                           GOTO RollbackTran
                        END
                     
                        -- LoadPlanDetail
                        DECLARE @curOrder CURSOR 
                        SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                           SELECT DISTINCT O.OrderKey
                           FROM dbo.Orders O WITH (NOLOCK)
                              JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                           WHERE O.StorerKey = @cStorerKey
                              AND O.Facility = @cFacility
                              --AND PD.CaseID = @cLabelNo
                              AND PD.Status = '5'
                              AND PD.DROPID = @cLabelNo     --only check dropid for AMZ
                        OPEN @curOrder
                        FETCH NEXT FROM @curOrder INTO @cChildOrderKey
                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                           IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cChildLoadKey AND OrderKey = @cChildOrderKey)
                           BEGIN
                              -- Get max linenumber  
                              DECLARE @cLoadLineNumber NVARCHAR( 5)  
                              SELECT @cLoadLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LoadLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
                              FROM dbo.LoadPlanDetail WITH (NOLOCK)  
                              WHERE LoadKey = @cChildLoadKey
                              
                              INSERT INTO dbo.LoadPlanDetail (
                                 LoadKey,          LoadLineNumber,      OrderKey,         ExternOrderKey, 
                                 ConsigneeKey,     CustomerName,        Priority,         OrderDate, 
                                 DeliveryDate,     DeliveryPlace,       Type,             Door, 
                                 Stop,             Route,               Weight,           Cube, 
                                 Status,           CaseCnt,             NoOfOrdLines,     Rdd, 
                                 UserDefine01,     UserDefine02,        UserDefine03,     UserDefine04, 
                                 UserDefine05,     UserDefine06,        UserDefine07,     UserDefine08, 
                                 UserDefine09,     UserDefine10,        ExternLoadKey,    ExternLineNo)
                              SELECT                                    
                                 @cChildLoadKey,   @cLoadLineNumber,    @cChildOrderKey,  ExternOrderKey,  
                                 ConsigneeKey,     CustomerName,        Priority,         OrderDate, 
                                 DeliveryDate,     DeliveryPlace,       Type,             Door, 
                                 Stop,             Route,               Weight=0,         Cube=0, 
                                 Status='5',       CaseCnt,             NoOfOrdLines,     Rdd, 
                                 UserDefine01,     UserDefine02,        UserDefine03,     UserDefine04, 
                                 UserDefine05,     UserDefine06,        UserDefine07,     UserDefine08, 
                                 UserDefine09,     UserDefine10,        ExternLoadKey,    ExternLineNo
                              FROM dbo.LoadPlanDetail WITH (NOLOCK)  
                              WHERE OrderKey = @cParentOrderKey
                              IF @@ERROR <> 0
                              BEGIN
                                 SET @nErrNo = 212014
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode, 'DSP') --INS LPDtl Fail
                                 GOTO RollbackTran
                              END
                           END
                           FETCH NEXT FROM @curOrder INTO @cChildOrderKey
                        END
                     END

                     SET @cChildOrderKey = ''

                     -- Get child pickslip
                     SELECT @cChildPickSlipNo = PickSlipNo
                     FROM dbo.PackHeader WITH (NOLOCK) 
                     WHERE LoadKey = @cChildLoadKey
                  END
                  
                  -- Create child PackHeader
                  IF @cChildPickSlipNo = ''
                  BEGIN
                     EXECUTE dbo.nspg_GetKey  
                        'PICKSLIP',  
                        9,  
                        @cChildPickSlipNo OUTPUT,  
                        @b_Success        OUTPUT,  
                        @n_Err            OUTPUT,  
                        @c_ErrMsg         OUTPUT
                     IF @b_Success <> 1  
                     BEGIN
                        SET @nErrNo = 212015
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey Fail
                        GOTO RollBackTran
                     END
                 
                     SET @cChildPickSlipNo = 'P' + @cChildPickSlipNo
                  
                     INSERT INTO dbo.PackHeader (
                        PickSlipNo,       StorerKey,        Route,            OrderKey,
                        OrderRefNo,       LoadKey,          ConsigneeKey,     Status,
                        TTLCNTS,          CtnTyp1,          CtnTyp2,          CtnTyp3,
                        CtnTyp4,          CtnTyp5,          CtnCnt1,          CtnCnt2,
                        CtnCnt3,          CtnCnt4,          CtnCnt5,          TotCtnWeight,
                        TotCtnCube,       CartonGroup,      ConsoOrderKey,    ManifestPrinted,
                        TaskBatchNo,      ComputerName,     PackStatus,       EstimateTotalCtn)
                     SELECT 
                        @cChildPickSlipNo,StorerKey,        Route,            @cChildOrderKey,
                        OrderRefNo,       @cChildLoadKey,   ConsigneeKey,     Status,
                        TTLCNTS=0,        CtnTyp1='',       CtnTyp2='',       CtnTyp3='',
                        CtnTyp4='',       CtnTyp5='',       CtnCnt1=0,        CtnCnt2=0,
                        CtnCnt3=0,        CtnCnt4=0,        CtnCnt5=0,        TotCtnWeight=0,
                        TotCtnCube=0,     CartonGroup,      ConsoOrderKey,    ManifestPrinted,
                        TaskBatchNo,      ComputerName,     PackStatus,       EstimateTotalCtn
                     FROM dbo.PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @cParentPickSlipNo
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 212016
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PHdr Fail
                        GOTO RollBackTran
                     END
                  END
                  
                  -- Change PackDetail (from parent to child)
                  UPDATE dbo.PackDetail SET
                     PickSlipNo = @cChildPickSlipNo, 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME(), 
                     ArchiveCop = NULL
                  WHERE PickSlipNo = @cParentPickSlipNo
                     AND LabelNo = @cLabelNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 212017
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDtl Fail
                     GOTO RollBackTran
                  END
                  
                  -- Change PackInfo (from parent to child)
                  UPDATE dbo.PackInfo SET
                     PickSlipNo = @cChildPickSlipNo, 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME(), 
                     TrafficCop = NULL
                  WHERE PickSlipNo = @cParentPickSlipNo
                     AND CartonNo = @nCartonNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 212018
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PInf Fail
                     GOTO RollBackTran
                  END
                  
                  -- Change PackSerialNo (from parent to child)
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.PackSerialNo WITH (NOLOCK) WHERE PickSlipNo = @cParentPickSlipNo AND CartonNo = @nCartonNo)
                  BEGIN
                     UPDATE dbo.PackSerialNo SET
                        PickSlipNo = @cChildPickSlipNo, 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME(), 
                        TrafficCop = NULL
                     WHERE PickSlipNo = @cParentPickSlipNo
                        AND CartonNo = @nCartonNo
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 212019
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKSNo Fail
                        GOTO RollBackTran
                     END
                  END

                  -- Change PackDetailInfo (from parent to child)
                  IF EXISTS( SELECT TOP 1 1 FROM dbo.PackDetailInfo WITH (NOLOCK) WHERE PickSlipNo = @cParentPickSlipNo AND CartonNo = @nCartonNo)
                  BEGIN
                     UPDATE dbo.PackDetailInfo SET
                        PickSlipNo = @cChildPickSlipNo, 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME(), 
                        TrafficCop = NULL
                     WHERE PickSlipNo = @cParentPickSlipNo
                        AND CartonNo = @nCartonNo
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 212020
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInf Fail
                        GOTO RollBackTran
                     END
                  END
               END

                --Update Orderkey back to rdtScanToTruck table
                DECLARE @cUpdOrderkey NVARCHAR(50)
                SELECT TOP 1 @cUpdOrderkey = PD.OrderKey
                FROM PICKDETAIL PD WITH (NOLOCK)
                WHERE PD.Storerkey = @cStorerKey AND PD.Status <> '9' AND PD.DropID = @cLabelNo
                IF ISNULL(@cUpdOrderkey, '') <> ''
                BEGIN
                  UPDATE RDT.rdtScanToTruck
                  SET OrderKey = @cUpdOrderkey
                  WHERE URNNo = @cLabelNo AND MBOLKey = @cMBOLKey
                  IF @@ERROR <> 0
                  BEGIN
                    SET @nErrNo = 212020
                    SET @cErrMsg = 'UPD SCANTT Fail' --UPD PDInf Fail
                    GOTO RollBackTran
                  END
                END
               
               COMMIT TRAN rdt_922ExtUpd06_AMZ -- Only commit change made here
            END
         END
      END

   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_922ExtUpd06_AMZ -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO