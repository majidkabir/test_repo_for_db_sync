SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Copyright: IDS                                                             */  
/* Purpose: SkipJack Split Shipment when Loading  SOS#227562                  */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2012-01-10 1.0  Shong      Created                                         */  
/* 2012-02-09 1.1  ChewKP     Filter By Door (ChewKP01)                       */  
/* 2012-02-22 1.2  Ung        Many bug fix                                    */  
/*                            Update weight, cube, carton                     */  
/*                            Cancel original order after split               */  
/* 2012-04-08 1.3  Shong      Update RefKeyLookup with Split PickDetail       */  
/* 2012-04-08 1.4  Ung        Stamp OrderDetail.MBOLKey                       */  
/*                            Stamp OrderDetail.Status                        */  
/*                            Stamp MBOLDetail.Weight, Cube, TotalCartons = 1 */  
/*                            Update CartonShipmentDetail                     */  
/* 2012-04-11 1.5  Shong      Replace Cursor With While 1=1                   */  
/* 2012-04-15 1.6  Shong      Review Script                                   */  
/* 2012-04-22 1.7  Shong      SOS#242344 Missing Consoorderline, Wrong Orig   */  
/*                            EnteredQty                                      */  
/* 2012-04-23 1.8  Shong      SOS#242352 QtyPicked not tally with PickDetail  */  
/* 2012-04-24 1.9  Ung        Add email alert                                 */  
/* 2012-04-26 2.0  Shong      Update ORDERS.SectionKey as Last Order Flag     */  
/* 2012-04-27 2.1  Ung        Fix old and new OrderDetail QTY calc (ung01)    */  
/* 2012-05-02 2.3  Shong      Use SectionKey as Last Order for Split Shipment */  
/* 2012-05-17 2.4  Shong      USE RDD column as SplitOrder Indicator          */  
/* 2012-05-23 2.5  Shong      Performance Tuning                              */  
/* 2012-05-30 2.6  Ung        Add split OrderInfo (ung02)                     */  
/* 2012-06-05 2.7  Ung        Original empty order stamp status = 9 (ung03)   */  
/* 2012-06-29 2.8  Shong      Remain Original OrderKey (UserDefine10) is Not  */  
/*                            Blank.                                          */  
/* 2012-08-15 2.9  Ung        SOS253288 Stamp MASTER in original orders       */  
/* 2012-08-22 3.0  ChewKP     SOS#254067 - Split Order by Lane (ChewKP02)     */  
/* 2012-11-21 3.1  James      SOS#263202 - Add precheck for orders integrity  */  
/*                            (james01)                                       */  
/* 2012-12-10 3.2  ChewKP     SOS#264269 - Do not split Order again when it   */
/*                            had been split (ChewKP03)                       */
/* 2014-04-29 3.3  CSCHONG    Add Lottable06-15 (CS01)                        */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_CreateMBOL_WCS_Sortation]  
(  
   @cJOBNo NVARCHAR(10),  
   @cListTo    NVARCHAR(max) = '',  
   @cListCc    NVARCHAR(max) = ''  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
 DECLARE  
     @cMBOLKey         NVARCHAR(10)  
    ,@cStartCarton     NVARCHAR(40)  
    ,@cEndCarton       NVARCHAR(40)  
    ,@cNewOrderKey     NVARCHAR(10)  
    ,@cCaseID          NVARCHAR(20)  
    ,@cOrderKey        NVARCHAR(10)  
    ,@cOrderLineNumber NVARCHAR(5)  
    ,@cMbolLineNumber  NVARCHAR(5)  
    ,@nQtyPicked       INT  
    ,@nContinue        INT  
    ,@nQtyAllocated    INT  
    ,@nStartTranCount  INT  
    ,@bSuccess         INT  
    ,@nErr             INT  
    ,@cErrMsg          NVARCHAR(255)  
    ,@cDoor            NVARCHAR(10)  
    ,@bDebug           NVARCHAR(1)  
    ,@nWeight          FLOAT  
    ,@nCube            FLOAT  
    ,@cNewLoadKey      NVARCHAR(10)  
    ,@cNewMBOLKey      NVARCHAR(10)  
    ,@cPickSlipNo      NVARCHAR(10)  
    ,@cCartonType      NVARCHAR(10)  
    ,@cStorerKey       NVARCHAR(15)  
    ,@nCartonNo        INT  
    ,@nQTY             INT  
    ,@nSeqNoStart      INT  
    ,@nSeqNoEnd        INT  
    ,@nWCS_RowRef      INT  
    ,@nTRK_RowRef      INT  
    ,@nOpenQty         INT  
    ,@nTotWeight       FLOAT  
    ,@nTotCube         FLOAT  
    ,@nTotCartons      FLOAT  
    ,@cOrdType         NVARCHAR(1)  
    ,@cLaneNo          NVARCHAR(10)  
  
   -- Get LoadKey  
   DECLARE @cLoadKey NVARCHAR( 10)  
  
   DECLARE @tOrders TABLE (OrderKey NVARCHAR(10), OrdType NVARCHAR(1), LinkOrderKey NVARCHAR(10))  
  
   DECLARE @tMBOL TABLE(MBOLKey NVARCHAR(10))  
  
   DECLARE @c_NewLineChar NVARCHAR(2)  
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) 
  
   DECLARE @nT_OriginalQTY    INT,  
           @nT_OpenQty        INT,  
           @nT_QtyPicked      INT,  
           @nT_QtyAllocated   INT,  
           @nP_OriginalQTY    INT,  
           @nP_OpenQty        INT,  
           @nP_QtyPicked      INT,  
           @nP_QtyAllocated   INT  
  
   SET @bDebug = '0'  
  
   IF @bDebug = '1'  
   BEGIN  
     SELECT @cJOBNo '@cJOBNo'  
   END  
  
   SET @nErr = 0  
   SET @cErrMsg = ''  
   EXEC isp_CreateMBOL_WCS_Sortation_Check @cJOBNo, @cListTo, @cListCc, @nErr OUTPUT, @cErrMsg OUTPUT -- james01  
   IF @nErr <> 0  
   BEGIN  
      SET @nContinue = 3  
      GOTO QUIT_WITH_ERROR  
   END  
  
   SET @nContinue = 1  
   SET @nStartTranCount = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   BEGIN TRAN  
  
   -- (ChewKP01)  
   SELECT @cDoor = Short  
   FROM CodelKup WITH (NOLOCK)  
   WHERE ListName = 'SPLTSHPMNT'  
   AND Code = @cJOBNo  
  
--   -- UPDATE IDS_Vehicle to indicate Job is currently Running  
--   UPDATE IDS_VEHICLE WITH (ROWLOCK)  
--   SET UserDefine01 = '1'  
--   WHERE VehicleNumber = @cDoor  
  
 -- Loop each MBOL  
 DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT T.MBOLKey,  
       (SELECT SeqNo FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.RefNo)) AS SeqNoStart,  
       (SELECT SeqNo FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.URNNo)) AS SeqNoEnd,  
       T.RowRef  ,  
       (SELECT LP_LaneNumber FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.RefNo)) AS LaneNumber -- (ChewKP02)  
    FROM rdt.RDTScanToTruck T WITH (NOLOCK)  
    JOIN MBOL WITH (NOLOCK) ON (T.MBOLKey = MBOL.MBOLKey)  
    WHERE T.Status = '3'  
    AND   T.Door = @cDoor  
    --AND MBOL.PlaceOfLoading = @cDoor  
    ORDER BY T.RowRef  
  
 OPEN CUR_MBOL  
 FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @nSeqNoStart, @nSeqNoEnd, @nTRK_RowRef, @cLaneNo -- (ChewKP02)  
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
      -- Protect from WCS bad data  
      IF @nSeqNoStart IS NULL OR @nSeqNoEnd IS NULL  
      BEGIN  
         FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @nSeqNoStart, @nSeqNoEnd, @nTRK_RowRef, @cLaneNo -- (ChewKP02)  
         CONTINUE  
      END  
  
      IF NOT EXISTS(SELECT 1 FROM @tMBOL WHERE MBOLKey = @cMBOLKey)  
         INSERT INTO @tMBOL(MBOLKey) VALUES (@cMBOLKey)  
  
      -- Loop OrderDetail level  
      DECLARE CUR_PickDetail_Info CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.CaseID, PD.OrderKey, PD.OrderLineNumber,  
            SUM(CASE WHEN PD.Status = '5' THEN PD.QTY ELSE 0 END) AS QtyPicked,  
            SUM(CASE WHEN PD.Status < '5' THEN PD.QTY ELSE 0 END) AS QtyAllocated  
         FROM PickDetail PD (NOLOCK)  
            JOIN WCS_Sortation WCS WITH (NOLOCK) ON (WCS.LabelNo = PD.CaseID)  
            JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber) -- (ChewKP03)
         WHERE WCS.SeqNo BETWEEN @nSeqNoStart AND @nSeqNoEnd  
            AND WCS.Status <> '9'  
            AND WCS.LP_LaneNumber = @cLaneNo -- (ChewKP02)  
            AND ISNULL(OD.UserDefine10,'') = '' -- (ChewKP03)
         GROUP BY PD.CaseID, PD.OrderKey, PD.OrderLineNumber  
  
      OPEN CUR_PickDetail_Info  
  
      FETCH NEXT FROM CUR_PickDetail_Info INTO @cCaseID, @cOrderKey, @cOrderLineNumber, @nQtyPicked, @nQtyAllocated  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @cNewOrderKey = ''  
  
         SELECT TOP 1 @cNewOrderKey = ISNULL(O.OrderKey,'')  
         FROM dbo.Orders O WITH (NOLOCK)  
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
         WHERE O.MbolKey = @cMBOLKey  
         AND OD.UserDefine10 = @cOrderKey  
  
--         IF NOT EXISTS ( SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK)  
--                         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
--                         WHERE O.MbolKey = @cMBOLKey  
--                         AND OD.UserDefine10 = @cOrderKey  
--           )  
  
         -- Check IF There is Existing UserDefine10 in the OrderDetail  
         IF ISNULL(RTRIM(@cNewOrderKey),'') = ''  
         BEGIN  
  
            EXECUTE nspg_GetKey  
               'ORDER',  
               10,  
               @cNewOrderKey  OUTPUT,  
               @bSuccess    OUTPUT,  
               @nErr        OUTPUT,  
               @cErrMsg     OUTPUT  
  
            IF NOT @bSuccess = 1  
            BEGIN  
               SET @nContinue = 3  
               GOTO QUIT_WITH_ERROR  
            END  
  
           INSERT INTO ORDERS  
           (  
            OrderKey,        StorerKey,       ExternOrderKey,     OrderDate,  
            DeliveryDate,    Priority,        ConsigneeKey,       C_contact1,  
            C_Contact2,      C_Company,       C_Address1,         C_Address2,  
            C_Address3,      C_Address4,      C_City,             C_State,  
            C_Zip,           C_Country,  C_ISOCntryCode,     C_Phone1,  
            C_Phone2,        C_Fax1,          C_Fax2,             C_vat,  
            BuyerPO,         BillToKey,       B_contact1,         B_Contact2,  
            B_Company,       B_Address1,      B_Address2,         B_Address3,  
            B_Address4,      B_City,          B_State,            B_Zip,  
            B_Country,       B_ISOCntryCode,  B_Phone1,           B_Phone2,  
            B_Fax1,          B_Fax2,          B_Vat,              IncoTerm,  
            PmtTerm,         OpenQty,         [Status],           DischargePlace,  
            DeliveryPlace,   IntermodalVehicle,   CountryOfOrigin, CountryDestination,  
            UpdateSource,    [Type],          OrderGroup,        Door,  
            [Route],         [Stop],          Notes,             EffectiveDate,  
            ContainerType,   ContainerQty,    BilledContainerQty, SOStatus,  
            MBOLKey,         InvoiceNo,       InvoiceAmount,      Salesman,  
            GrossWeight,     Capacity,        PrintFlag,          LoadKey,  
            Rdd,             Notes2,          SequenceNo,         Rds,  
            SectionKey,      Facility,        PrintDocDate,       LabelPrice,  
            POKey,           ExternPOKey,     XDockFlag,          UserDefine01,  
            UserDefine02,    UserDefine03,    UserDefine04,       UserDefine05,  
            UserDefine06,    UserDefine07,    UserDefine08,       UserDefine09,  
            UserDefine10,    Issued,          DeliveryNote,       PODCust,  
            PODArrive,       PODReject,       PODUser,            xdockpokey,  
            SpecialHandling, RoutingTool,     MarkforKey,         M_Contact1,  
            M_Contact2,      M_Company,       M_Address1,         M_Address2,  
            M_Address3,      M_Address4,      M_City,             M_State,  
            M_Zip,           M_Country,       M_ISOCntryCode,     M_Phone1,  
            M_Phone2,        M_Fax1,          M_Fax2,             M_vat,  
            ShipperKey        )  
           SELECT  
            @cNewOrderKey,    StorerKey,       ExternOrderKey,    OrderDate,  
            DeliveryDate,     Priority,        ConsigneeKey,      C_contact1,  
            C_Contact2,       C_Company,       C_Address1,        C_Address2,  
            C_Address3,       C_Address4,      C_City,            C_State,  
            C_Zip,            C_Country,       C_ISOCntryCode,    C_Phone1,  
            C_Phone2,         C_Fax1,          C_Fax2,            C_vat,  
            BuyerPO,          BillToKey,       B_contact1,        B_Contact2,  
            B_Company,        B_Address1,      B_Address2,   B_Address3,  
            B_Address4,       B_City,          B_State,           B_Zip,  
            B_Country,        B_ISOCntryCode,  B_Phone1,          B_Phone2,  
            B_Fax1,           B_Fax2,          B_Vat,             IncoTerm,  
            PmtTerm,          OpenQty=0,           [Status]='5',        DischargePlace,  
            DeliveryPlace,    IntermodalVehicle,   CountryOfOrigin,     CountryDestination,  
            UpdateSource,     [Type],              OrderGroup,          Door,  
            [Route],          [Stop],              Notes,               EffectiveDate,  
            ContainerType,    ContainerQty,        BilledContainerQty,  SOStatus,  
            @cMBOLKey,        InvoiceNo,           InvoiceAmount,    Salesman,  
            GrossWeight=0,    Capacity=0,          PrintFlag,        LoadKey,  
            Rdd='SplitOrder', Notes2,              SequenceNo,       Rds,  
            SectionKey,       Facility,            PrintDocDate,     LabelPrice,  
            POKey,            ExternPOKey,         XDockFlag,        UserDefine01,  
            UserDefine02,     UserDefine03,        UserDefine04,     UserDefine05,  
            UserDefine06,     UserDefine07,        UserDefine08,     UserDefine09,  
            UserDefine10,     Issued,              DeliveryNote,     PODCust,  
            PODArrive,        PODReject,           PODUser,          XDOCKPOKEY,  
            SpecialHandling,  RoutingTool,         MarkforKey,       M_Contact1,  
            M_Contact2,       M_Company,           M_Address1,       M_Address2,  
            M_Address3,       M_Address4,          M_City,           M_State,  
            M_Zip,            M_Country,           M_ISOCntryCode,   M_Phone1,  
            M_Phone2,         M_Fax1,              M_Fax2,           M_vat,  
            ShipperKey  
           FROM ORDERS WITH (NOLOCK)  
           WHERE OrderKey = @cOrderKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'INSERT INTO ORDERS Table Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
            -- Split OrderInfo (ung02)  
            INSERT INTO OrderInfo  
               (OrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10)  
            SELECT  
               @cNewOrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10  
            FROM OrderInfo WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'INSERT INTO OrderInfo Table Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
            SET @cMbolLineNumber = ''  
  
            SELECT @cMbolLineNumber = ISNULL(MAX(MbolLineNumber),'')  
            FROM MBOLDETAIL WITH (NOLOCK)  
            WHERE MbolKey = @cMBOLKey  
  
            IF ISNULL(RTRIM(@cMbolLineNumber),'') = ''  
            BEGIN  
               SET @cMbolLineNumber = '00001'  
            END  
            ELSE  
            BEGIN  
               SET @cMbolLineNumber = RIGHT('0000' + CONVERT(NVARCHAR(5), CAST(@cMbolLineNumber AS INT) + 1), 5)  
            END  
  
  
            INSERT INTO MBOLDETAIL  
            (  
             MbolKey,          MbolLineNumber,      ContainerKey,        OrderKey,  
             PalletKey,        [Description],       GrossWeight,         Capacity,  
             InvoiceNo,        UPSINum,             PCMNum,             ExternReason,  
             InvoiceStatus,    InvoiceAmount,       OfficialReceipt,  
             ITS,              LoadKey,             [Weight],            [Cube],  
             OrderDate,        ExternOrderKey,      DeliveryDate,        DeliveryStatus,  
             TotalCartons,     UserDefine01,        UserDefine02,        UserDefine03,  
             UserDefine04,     UserDefine05,        UserDefine06,        UserDefine07,  
             UserDefine08,     UserDefine09,        UserDefine10,        CtnCnt1,  
             CtnCnt2,          CtnCnt3,             CtnCnt4,             CtnCnt5,  
             TrafficCop)  
            SELECT  
            @cMBOLKey,        @cMbolLineNumber,    '',                  @cNewOrderKey,  
            '',               '',                  0,                   0,  
            '',               '',                  '',                  '0',  
            '0',              0,                   '',  
            '',               LoadKey,             0,                   0,  
            OrderDate,        ExternOrderKey,      DeliveryDate,        '',  
            0,                '',                  '',   '',  
            '',               '',                  '',                  '',  
            '',               '',                  @cOrderKey,          0,  
            0,                0,                   0,                   0,  
            '1'  
            FROM ORDERS O WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'INSERT INTO MBOLDETAIL Table Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
  
            -- Insert Into LoadPLanDetail  
            IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE OrderKey = @cNewOrderKey)  
            BEGIN  
  
               SET @cLoadKey = ''  
               SELECT @cLoadKey = LoadKey  
               FROM LoadPlanDetail WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
  
               -- Get max linenumber  
               DECLARE @cLoadLineNumber NVARCHAR( 5)  
               SELECT @cLoadLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LoadLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
               FROM dbo.LoadPlanDetail WITH (NOLOCK)  
               WHERE LoadKey = @cLoadKey  
  
               INSERT INTO LOADPLANDETAIL  
                  (LoadKey,            LoadLineNumber,  
                   OrderKey,           ConsigneeKey,  
                   Priority,           OrderDate,  
                   DeliveryDate,       Type,  
                   Door,               Stop,  
                   Route,              DeliveryPlace,  
                   Weight,             Cube,  
                   ExternOrderKey,     CustomerName,  
                   NoOfOrdLines,       CaseCnt,  
                   [STATUS])  
               SELECT  
                   LoadKey,            @cLoadLineNumber,  
                   @cNewOrderKey,      ConsigneeKey,  
                   Priority,           OrderDate,  
                   DeliveryDate,       Type,  
                   Door,               Stop,  
                   Route,              DeliveryPlace,  
                   --Weight,             Cube,  
                   WEIGHT=0,           Cube=0,  
                   ExternOrderKey,     CustomerName,  
                   NoOfOrdLines,       CaseCnt,  
                   [STATUS]='5'  
               FROM dbo.LoadPlanDetail WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nContinue = 3  
          SET @cErrMsg = 'Insert LOADPLANDETAIL Failed'  
                  GOTO QUIT_WITH_ERROR  
               END  
            END  -- Not Exist LOADPLANDETAIL  
       END -- Order# NOT Exists in MBOLDetail  
  
       IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL WITH (NOLOCK)  
                     WHERE OrderKey = @cNewOrderKey  
                       AND OrderLineNumber = @cOrderLineNumber)  
       BEGIN  
		    /*CS01 start*/
          INSERT INTO ORDERDETAIL  
          (  
           OrderKey,              OrderLineNumber,  OrderDetailSysId,      ExternOrderKey,  
           ExternLineNo,          Sku,              StorerKey,             ManufacturerSku,  
           RetailSku,             AltSku,           OriginalQty,           OpenQty,  
           ShippedQty,           AdjustedQty,       QtyPreAllocated,       QtyAllocated,  
           QtyPicked,             UOM,              PackKey,               PickCode,  
           CartonGroup,           Lot,              ID,                    Facility,  
           [Status],              UnitPrice,        Tax01,                 Tax02,  
           ExtendedPrice,         UpdateSource,     Lottable01,            Lottable02,  
           Lottable03,            Lottable04,       Lottable05,            Lottable06,
			  Lottable07,            Lottable08,       Lottable09,            Lottable10,
			  Lottable11,            Lottable12,       Lottable13,            Lottable14,
			  Lottable15,            FreeGoodQty,  
           GrossWeight,           Capacity,         LoadKey,               MBOLKey,  
           QtyToProcess,          MinShelfLife,     UserDefine01,          UserDefine02,  
           UserDefine03,          UserDefine04,     UserDefine05,          UserDefine06,  
           UserDefine07,          UserDefine08,     UserDefine09,          POkey,  
           ExternPOKey,           UserDefine10,     EnteredQTY,            ConsoOrderKey,  
           ExternConsoOrderKey,   ConsoOrderLineNo  
          )  
          SELECT  
           @cNewOrderKey,          OrderLineNumber,  OrderDetailSysId,    ExternOrderKey,  
           ExternLineNo,           Sku,              StorerKey,           ManufacturerSku,  
           RetailSku,              AltSku,  
           OriginalQty=(@nQtyAllocated + @nQtyPicked),  
           OpenQty=(@nQtyAllocated + @nQtyPicked),  
           ShippedQty,             AdjustedQty=0,    QtyPreAllocated=0,   @nQtyAllocated,  
           @nQtyPicked,            UOM,              PackKey,             PickCode,  
           CartonGroup,            Lot,              ID,                  Facility,  
           [Status]='5',           UnitPrice,        Tax01,               Tax02,  
           ExtendedPrice,          UpdateSource,     Lottable01,          Lottable02,  
           Lottable03,             Lottable04,       Lottable05,          Lottable06,
			  Lottable07,             Lottable08,       Lottable09,          Lottable10,
			  Lottable11,             Lottable12,       Lottable13,          Lottable14,
			  Lottable15,             FreeGoodQty,  
           GrossWeight,            Capacity,         LoadKey,             @cMBOLKey,  
           QtyToProcess,           MinShelfLife,     UserDefine01,        UserDefine02,  
           UserDefine03,           UserDefine04,     UserDefine05,        UserDefine06,  
           UserDefine07,           UserDefine08,     UserDefine09,        POkey,  
           ExternPOKey,  
           CASE WHEN ISNULL(RTRIM(UserDefine10),'') = '' THEN @cOrderKey ELSE UserDefine10 END,      -- Shong 29-06-2012  
           EnteredQTY=0,        --(ung01)  
           ConsoOrderKey,          ExternConsoOrderKey,    ConsoOrderLineNo  
          FROM ORDERDETAIL o WITH (NOLOCK)  
          WHERE o.OrderKey = @cOrderKey  
          AND   o.OrderLineNumber = @cOrderLineNumber  
			  /*CS01 start*/
          IF @@ERROR <> 0  
          BEGIN  
             SET @nContinue = 3  
             SET @cErrMsg = 'INSERT INTO ORDERDETAIL Table Failed'  
             GOTO QUIT_WITH_ERROR  
          END  
       END -- if not exists in order line  
  
      -- Added By Shong On 08-Apr-2012  
      UPDATE RKP  
         SET OrderKey = @cNewOrderKey  
      FROM RefKeyLookUp RKP  
      JOIN PICKDETAIL p WITH (NOLOCK) ON p.PickDetailkey = RKP.PickDetailkey  
      WHERE P.OrderKey = @cOrderKey  
      AND P.OrderLineNumber = @cOrderLineNumber  
      AND P.CaseID = @cCaseID  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update RefKeyLookUp Table Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      UPDATE PICKDETAIL  
         SET OrderKey = @cNewOrderKey,  
             EditDate = GETDATE(),  
             TrafficCop = NULL  
      WHERE OrderKey = @cOrderKey  
      AND OrderLineNumber = @cOrderLineNumber  
      AND CaseID = @cCaseID  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update PICKDETAIL Table Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      UPDATE ORDERDETAIL  
         SET OriginalQty  =  (SOStatus.QtyPicked + SOStatus.QtyAllocated),  
             OpenQty      =  (SOStatus.QtyPicked + SOStatus.QtyAllocated),  
             QtyPicked    =  SOStatus.QtyPicked,  
      QtyAllocated =  SOStatus.QtyAllocated,  
             STATUS       =  '5',  
             EnteredQty   =  0,  
             EditDate = GETDATE(),  
             TrafficCop = NULL  
      FROM ORDERDETAIL  
      JOIN (SELECT P.OrderKey, P.OrderLineNumber,  
                   SUM(CASE WHEN P.Status IN ('0','1','2','3','4') THEN P.Qty ELSE 0 END) AS QtyAllocated,  
                   SUM(CASE WHEN P.Status IN ('5','6','7','8') THEN P.Qty ELSE 0 END) AS QtyPicked,  
                   SUM(CASE WHEN P.Status = '9' THEN P.Qty ELSE 0 END) AS ShippedQty  
            FROM PICKDETAIL P WITH (NOLOCK)  
            WHERE P.OrderKey = @cNewOrderKey AND  
                  P.OrderLineNumber = @cOrderLineNumber  
            GROUP BY P.OrderKey, P.OrderLineNumber) AS SOStatus  
                  ON SOStatus.OrderKey = OrderDetail.OrderKey  
                  AND SOStatus.OrderLineNumber = OrderDetail.OrderLineNumber  
      WHERE ORDERDETAIL.OrderKey = @cNewOrderKey  
      AND   ORDERDETAIL.OrderLineNumber = @cOrderLineNumber  
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @nT_OriginalQTY = ORDERDETAIL.OriginalQTY,  
                @nT_OpenQty = ORDERDETAIL.OpenQty,  
                @nT_QtyPicked = ORDERDETAIL.QtyPicked,  
                @nT_QtyAllocated = ORDERDETAIL.QtyAllocated,  
                @nP_OriginalQTY = SOStatus.QtyPicked + SOStatus.QtyAllocated,  
                @nP_OpenQty = SOStatus.QtyPicked + SOStatus.QtyAllocated,  
                @nP_QtyPicked = SOStatus.QtyPicked,  
                @nP_QtyAllocated = SOStatus.QtyAllocated  
         FROM ORDERDETAIL WITH (NOLOCK)  
         JOIN (SELECT P.OrderKey, P.OrderLineNumber,  
                      SUM(CASE WHEN P.Status IN ('0','1','2','3','4') THEN P.Qty ELSE 0 END) AS QtyAllocated,  
                      SUM(CASE WHEN P.Status IN ('5','6','7','8') THEN P.Qty ELSE 0 END) AS QtyPicked,  
                      SUM(CASE WHEN P.Status = '9' THEN P.Qty ELSE 0 END) AS ShippedQty  
               FROM PICKDETAIL P WITH (NOLOCK)  
               WHERE P.OrderKey = @cNewOrderKey AND  
                     P.OrderLineNumber = @cOrderLineNumber  
               GROUP BY P.OrderKey, P.OrderLineNumber) AS SOStatus  
                     ON SOStatus.OrderKey = OrderDetail.OrderKey  
                     AND SOStatus.OrderLineNumber = OrderDetail.OrderLineNumber  
         WHERE ORDERDETAIL.OrderKey = @cNewOrderKey  
         AND   ORDERDETAIL.OrderLineNumber = @cOrderLineNumber  
  
         SET @nContinue = 3  
         SET @cErrMsg = '1 - Update ORDERDETAIL Table Failed.' + @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + 'MBOL/NewOrd/OrdLine#: ' + @cMBOLKey + '/' + @cNewOrderKey + '/' + @cOrderLineNumber + @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + 'O-OriginalQTY/OpenQty/QtyAllocated/QtyPicked: ' + CAST(@nT_OriginalQTY AS NVARCHAR(3)) + '/' + CAST(@nT_OpenQty AS NVARCHAR(3))+ '/' + CAST(@nT_QtyAllocated AS NVARCHAR(3))+ '/' + CAST(@nT_QtyPicked AS NVARCHAR(3))+ @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + 'P-OriginalQTY/OpenQty/QtyAllocated/QtyPicked: ' + CAST(@nP_OriginalQTY AS NVARCHAR(3)) + '/' + CAST(@nP_OpenQty AS NVARCHAR(3))+ '/' + CAST(@nP_QtyAllocated AS NVARCHAR(3))+ '/' + CAST(@nP_QtyPicked AS NVARCHAR(3))+ @c_NewLineChar  
         GOTO QUIT_WITH_ERROR  
      END  
  
      SET @nOpenQty = 0  
  
      SELECT @nOpenQty = SUM(OD.OpenQty)  
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      WHERE OD.OrderKey = @cNewOrderKey  
  
      UPDATE OH  
         SET OpenQty    = @nOpenQty,  
             [Status]   = '5',  
             EditDate = GETDATE(),  
             TrafficCop = NULL  
      FROM ORDERS OH  
      WHERE OrderKey = @cNewOrderKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update ORDERS Table Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      -- Updating Old OrderDetail  
/*  
      UPDATE ORDERDETAIL  
         SET OpenQty      = CASE WHEN OpenQty - (@nQtyPicked + @nQtyAllocated) <  
                                     (SOStatus.QtyPicked + SOStatus.QtyAllocated + SOStatus.ShippedQty)  
                                    THEN (SOStatus.QtyPicked + SOStatus.QtyAllocated)  
                                 ELSE OpenQty - (@nQtyPicked + @nQtyAllocated)  
                            END,  
             QtyPicked    = SOStatus.QtyPicked,  
             QtyAllocated = SOStatus.QtyAllocated,  
             TrafficCop   = NULL  
      FROM ORDERDETAIL  
      JOIN (SELECT P.OrderKey, P.OrderLineNumber,  
                   SUM(CASE WHEN P.Status IN ('0','1','2','3','4') THEN P.Qty ELSE 0 END) AS QtyAllocated,  
                   SUM(CASE WHEN P.Status IN ('5','6','7','8') THEN P.Qty ELSE 0 END) AS QtyPicked,  
                   SUM(CASE WHEN P.Status = '9' THEN P.Qty ELSE 0 END) AS ShippedQty  
            FROM PICKDETAIL P WITH (NOLOCK)  
            WHERE P.OrderKey = @cOrderKey AND  
                  P.OrderLineNumber = @cOrderLineNumber  
            GROUP BY P.OrderKey, P.OrderLineNumber) AS SOStatus  
                  ON SOStatus.OrderKey = OrderDetail.OrderKey  
                  AND SOStatus.OrderLineNumber = OrderDetail.OrderLineNumber  
       WHERE ORDERDETAIL.OrderKey = @cOrderKey  
       AND   ORDERDETAIL.OrderLineNumber = @cOrderLineNumber  
*/  
      -- (ung01)  
      UPDATE ORDERDETAIL  
         SET OriginalQTY  = OriginalQTY - (@nQtyPicked + @nQtyAllocated),  
             OpenQty      = OpenQty - (@nQtyPicked + @nQtyAllocated),  
             QtyPicked    = QtyPicked - @nQtyPicked,  
             QtyAllocated = QtyAllocated - @nQtyAllocated,  
             [Status]     = CASE WHEN (QtyPicked - @nQtyPicked) > 0 THEN '5'  
                                 WHEN (QtyPicked - @nQtyPicked) + (QtyAllocated - @nQtyAllocated) = 0  
                   THEN '0'  
                                 WHEN (OpenQty - (@nQtyPicked + @nQtyAllocated)) =  
                                      (QtyPicked - @nQtyPicked) + (QtyAllocated - @nQtyAllocated)  
                                      THEN '2'  
                                 ELSE '1'  
                            END,  
             EditDate = GETDATE(),  
             TrafficCop   = NULL  
      FROM ORDERDETAIL  
      WHERE ORDERDETAIL.OrderKey = @cOrderKey  
      AND   ORDERDETAIL.OrderLineNumber = @cOrderLineNumber  
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @nT_OriginalQTY = OriginalQTY,  
                @nT_OpenQty = OpenQty,  
                @nT_QtyPicked = QtyPicked,  
                @nT_QtyAllocated = QtyAllocated  
         FROM ORDERDETAIL WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         AND   OrderLineNumber = @cOrderLineNumber  
  
         SET @nContinue = 3  
         SET @cErrMsg = '2 - Update ORDERDETAIL Table Failed.' + @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + 'MBOL/Ord/OrdLine#: ' + @cMBOLKey + '/' + @cOrderKey + '/' + @cOrderLineNumber + @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + 'OriginalQTY/OpenQty/QtyAllocated/QtyPicked: ' + CAST(@nT_OriginalQTY AS NVARCHAR(3)) + '/' + CAST(@nT_OpenQty AS NVARCHAR(3))+ '/' + CAST(@nT_QtyAllocated AS NVARCHAR(3))+ '/' + CAST(@nT_QtyPicked AS NVARCHAR(3))+ @c_NewLineChar  
         SET @cErrMsg = RTRIM(@cErrMsg) + '@nQtyAllocated/@nQtyPicked: ' + CAST(@nQtyAllocated AS NVARCHAR(3)) + '/' + CAST(@nQtyPicked AS NVARCHAR(3))  
         GOTO QUIT_WITH_ERROR  
      END  
  
      SET @nOpenQty = 0  
      SELECT @nOpenQty = SUM(OD.OpenQty)  
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      WHERE OD.OrderKey = @cOrderKey  
  
      UPDATE ORDERS  
         SET OpenQty = @nOpenQty,  
             EditDate = GETDATE(),  
             TrafficCop = NULL  
       WHERE OrderKey = @cOrderKey  
       IF @@ERROR <> 0  
       BEGIN  
          SET @nContinue = 3  
          SET @cErrMsg = 'Update ORDERS Table Failed'  
          GOTO QUIT_WITH_ERROR  
       END  
  
      IF NOT EXISTS(SELECT 1 FROM @tOrders WHERE OrderKey = @cNewOrderKey)  
         INSERT INTO @tOrders(OrderKey, OrdType, LinkOrderKey) VALUES (@cNewOrderKey, 'N', @cOrderKey)  
  
      IF NOT EXISTS(SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)  
         INSERT INTO @tOrders(OrderKey, OrdType, LinkOrderKey) VALUES (@cOrderKey, 'O', @cNewOrderKey)  
  
      -- Update case as processed  
      UPDATE WCS_Sortation WITH (ROWLOCK) SET  
         Status = '9' --9=Processed  
      WHERE LabelNo = @cCaseID  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update WCS_Sortation Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      -- Commit Tran by Carton  
      WHILE @@TRANCOUNT > 0  
         COMMIT TRAN  
  
      -- Start Another Tran  
      BEGIN TRAN  
  
      FETCH NEXT FROM CUR_PickDetail_Info INTO @cCaseID, @cOrderKey, @cOrderLineNumber,  
                     @nQtyPicked, @nQtyAllocated  
   END  
   CLOSE CUR_PickDetail_Info  
   DEALLOCATE CUR_PickDetail_Info  
  
   UPDATE rdt.RDTScanToTruck  
      SET [Status] = '9'  
   WHERE RowRef = @nTRK_RowRef  
   AND   [Status] = '3'  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nContinue = 3  
      SET @cErrMsg = 'Update rdtScantoTruckFailed'  
      GOTO QUIT_WITH_ERROR  
   END  
  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
 END  --While CUR_MBOL  
      /*--------------------------------------------------------------------------------------------------  
  
                                             Update weight, cube, carton  
  
      --------------------------------------------------------------------------------------------------*/  
  BEGIN TRAN  
  
   -- Loop LabelNo  
   DECLARE CUR_ModifyOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT OrderKey, OrdType  
    FROM @tOrders  
  
   OPEN CUR_ModifyOrders  
   FETCH NEXT FROM CUR_ModifyOrders INTO @cOrderKey, @cOrdType  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @nTotWeight  = 0  
      SET @nTotCube    = 0  
      SET @nTotCartons = 0  
  
      SET @cMBOLKey = ''  
      SET @cLoadKey = ''  
      SELECT  
         @cStorerKey = ISNULL(O.StorerKey,''),  
         @cLoadKey = O.LoadKey,  
         @cMBOLKey = O.MBOLKey  
      FROM Orders O WITH (NOLOCK)  
      WHERE O.OrderKey = @cOrderKey  
  
      DECLARE CUR_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT CaseID  
      FROM PICKDETAIL p WITH (NOLOCK)  
      WHERE p.OrderKey = @cOrderKey  
  
      OPEN  CUR_Carton  
  
      FETCH NEXT FROM CUR_Carton INTO @cCaseID  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT TOP 1  
             @cPickSlipNo = pd.PickSlipNo,  
             @nCartonNo = pd.CartonNo  
       FROM PackDetail pd WITH (NOLOCK)  
       WHERE pd.LabelNo = @cCaseID  
  
         SET @nWeight = 0  
         SET @cCartonType = ''  
         SELECT @cCartonType = CartonType,  
                @nWeight = [Weight]  
         FROM PackInfo WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
           AND CartonNo = @nCartonNo  
  
         -- Get carton weight  
         IF @nWeight = 0  
         BEGIN  
            SELECT @nWeight = ISNULL( SUM( PD.QTY * SKU.StdGrossWgt), 0)  
            FROM PackDetail PD (NOLOCK)  
            INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)  
            WHERE PD.LabelNo = @cCaseID  
         END  
  
         -- Get carton cube  
         SET @nCube = 0  
         SELECT @nCube = ISNULL(C.Cube,0)  
         FROM dbo.Cartonization C WITH (NOLOCK)  
         INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)  
         WHERE C.CartonType = @cCartonType  
            AND S.StorerKey = @cStorerKey  
  
         SET @nTotWeight  = @nTotWeight + @nWeight  
         SET @nTotCube    = @nTotCube   + @nCube  
         SET @nTotCartons = @nTotCartons + 1  
  
         -- Update CartonShipmentDetail  
         UPDATE CartonShipmentDetail SET  
            OrderKey = @cOrderKey,  
            Loadkey  = @cLoadKey,  
            MBOLKey  = @cMBOLKey  
         WHERE UCCLabelNo = @cCaseID  
            AND StorerKey = @cStorerKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nContinue = 3  
            SET @cErrMsg = 'Update CartonShipmentDetail Failed'  
            GOTO QUIT_WITH_ERROR  
         END  
  
         FETCH NEXT FROM CUR_Carton INTO @cCaseID  
      END  -- While  
      CLOSE CUR_Carton  
      DEALLOCATE CUR_Carton  
  
      UPDATE LoadPlanDetail SET  
         Weight = @nTotWeight,  
         Cube = @nTotCube,  
         EditDate = GETDATE(),  
         TrafficCop = NULL  
      WHERE LoadKey = @cLoadKey  
        AND OrderKey = @cOrderKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update LoadPlanDetail Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      -- Add to new MBOLDetail  
      -- Conso order with 1 carton split into multi orders. Can't calculate carton count, weight, cube. Stamp as 1  
  
      UPDATE MBOLDetail SET  
       Weight = CASE WHEN @nTotWeight = 0 THEN 1 ELSE @nTotWeight END,  
         Cube   = CASE WHEN @nTotCube = 0 THEN 1 ELSE @nTotCube END,  
         TotalCartons = @nTotCartons,  
         EditDate = GETDATE(),  
         TrafficCop = NULL  
      WHERE MBOLKey = @cMBOLKey  
         AND OrderKey = @cOrderKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update MBOLDetail Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      /*--------------------------------------------------------------------------------------------------  
  
                                            Cancel original orders, after splitted  
  
      --------------------------------------------------------------------------------------------------*/  
      IF @cOrdType = 'O'  
      BEGIN  
       SET @nQTY = 0  
  
         SELECT @nQTY = ISNULL( SUM(Qty), 0)  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         AND   STATUS < '9'  
  
         -- SOS253288 Stamp MASTER in original orders  
         UPDATE Orders SET  
            RDD = 'MASTERORDER',  
            EditDate = GETDATE(),  
            Trafficcop = NULL  
         WHERE OrderKey = @cOrderKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nContinue = 3  
            SET @cErrMsg = 'Update Orders Failed'  
            GOTO QUIT_WITH_ERROR  
         END  
  
         SET @cNewOrderKey = ''  
         SELECT @cNewOrderKey = LinkOrderKey  
         FROM @tOrders  
         WHERE OrderKey = @cOrderKey  
  
         IF @nQTY = 0  
         BEGIN  
            UPDATE Orders  
            SET SectionKey = 'Y',  
               EditDate = GETDATE(),  
               Trafficcop = NULL  
            WHERE OrderKey = @cNewOrderKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'Update Orders Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
            UPDATE Orders  
            SET [SOStatus]  = 'MASTER',  
                [Status] = '9', --(ung03)  
                EditDate = GETDATE(),  
                Trafficcop = NULL  
            WHERE OrderKey = @cOrderKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'Update Orders Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
            UPDATE OrderDetail SET  
               Status = '0',  
               EditDate = GETDATE(),  
               Trafficcop = NULL  
            WHERE OrderKey = @cOrderKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'Update MBOLDetail Failed'  
               GOTO QUIT_WITH_ERROR  
            END  
  
            --IF EXISTS( SELECT 1 FROM LoadPlanDetail WHERE OrderKey = @cOrderKey)  
            --   DELETE LoadPlanDetail WHERE OrderKey = @cOrderKey  
         END --IF @nQTY = 0  
         ELSE  
         BEGIN  
          UPDATE Orders  
            SET SectionKey = 'N',  
               EditDate = GETDATE(),  
               Trafficcop = NULL  
            WHERE OrderKey = @cNewOrderKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nContinue = 3  
               SET @cErrMsg = 'Update Orders Failed'  
              GOTO QUIT_WITH_ERROR  
            END  
  
         END  
      END  
  
      WHILE @@TRANCOUNT > 0  
         COMMIT TRAN  
  
      BEGIN TRAN  
  
      FETCH NEXT FROM CUR_ModifyOrders INTO @cOrderKey, @cOrdType  
   END  -- While CUR_ModifyOrders  
   CLOSE CUR_ModifyOrders  
   DEALLOCATE CUR_ModifyOrders  
  
  
   BEGIN TRAN  
  
   -- Added by SHONG on 23-May-2012  
   -- Calculate MBOL Carton Count  
   DECLARE @tPack TABLE  
      (PickSlipNo NVARCHAR(10),  
       LabelNo    NVARCHAR(20),  
       CartonNo   INT,  
       [WEIGHT]   REAL,  
       [CUBE]     REAL)  
  
  
   DECLARE CUR_MBOLKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT MBOLKey FROM @tMBOL  
  
   OPEN CUR_MBOLKEY  
   FETCH NEXT FROM CUR_MBOLKEY INTO @cMBOLKey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      INSERT INTO @tPack (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE])  
      SELECT DISTINCT P.PickSlipNo, PD.LabelNo, PD.CartonNo,0, 0  
      FROM   PICKDETAIL p WITH (NOLOCK)  
      JOIN   PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = P.PickSlipNo  
                              AND PD.DropID = P.DropID  
      JOIN  MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = P.OrderKey  
      WHERE MD.MbolKey = @cMBOLKey  
  
      UPDATE TP  
         SET [WEIGHT]  = pi1.[Weight],  
             TP.[CUBE] = CASE WHEN pi1.[CUBE] < 1.00 THEN 1.00 ELSE pi1.[CUBE] END  
      FROM @tPack TP  
      JOIN PackInfo pi1 WITH (NOLOCK) ON pi1.PickSlipNo = TP.PickSlipNo AND pi1.CartonNo = TP.CartonNo  
  
      IF EXISTS(SELECT 1 FROM @tPack WHERE [WEIGHT]=0)  
      BEGIN  
         UPDATE TP  
            SET TP.[WEIGHT]  = TWeight.[WEIGHT],  
                TP.[CUBE] = CASE WHEN TP.[CUBE] < 1.00 THEN 1.00 ELSE TP.[CUBE] END  
         FROM @tPack TP  
         JOIN (SELECT PD.PickSlipNo, PD.CartonNo, SUM(S.STDGROSSWGT * PD.Qty) AS [WEIGHT]  
               FROM PACKDETAIL PD WITH (NOLOCK)  
               JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU  
               JOIN @tPack TP2 ON TP2.PickSlipNo = PD.PickSlipNo AND TP2.CartonNo = PD.CartonNo  
               GROUP BY PD.PickSlipNo, PD.CartonNo) AS TWeight ON TP.PickSlipNo = TWeight.PickSlipNo  
                        AND TP.CartonNo = TWeight.CartonNo  
         WHERE TP.[WEIGHT] = 0  
  
      END  
  
      UPDATE MBOL  
         SET [Weight]  =  PK.WEIGHT,  
             MBOL.[Cube] = PK.Cube,  
             MBOL.CaseCnt = PK.CaseCnt,  
             EditDate = GETDATE(),  
             TrafficCop=NULL  
      FROM MBOL  
      JOIN (SELECT @cMBOLKey AS MBOLKEY, SUM(WEIGHT) AS Weight, SUM(CUBE) AS Cube, COUNT(*) AS CaseCnt  
            FROM @tPack) AS PK ON MBOL.MbolKey = PK.MbolKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nContinue = 3  
         SET @cErrMsg = 'Update MBOL Failed'  
         GOTO QUIT_WITH_ERROR  
      END  
  
      DELETE FROM @tPack  
  
      FETCH NEXT FROM CUR_MBOLKEY INTO @cMBOLKey  
   END  
   CLOSE CUR_MBOLKEY  
   DEALLOCATE CUR_MBOLKEY  
  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
QUIT_NORMAL:  
  
-- UPDATE IDS_Vehicle to indicate Job is Completed  
-- UPDATE IDS_VEHICLE WITH (ROWLOCK)  
--   SET UserDefine01 = ''  
--WHERE VehicleNumber = @cDoor  
  
  
WHILE @@TRANCOUNT > 0  
   COMMIT TRAN  
  
WHILE @@TRANCOUNT < @nStartTranCount  
   BEGIN TRAN  
  
RETURN  
  
QUIT_WITH_ERROR:  
  
  
IF @@TRANCOUNT > @nStartTranCount  
   ROLLBACK TRAN  
  
  
IF @cListTo <> '' OR @cListCc <> ''  
BEGIN  
   DECLARE @cSubject NVARCHAR(255)  
   DECLARE @cBody    NVARCHAR(MAX)  
   SET @cSubject = 'Split orders job ' + CAST( @cJOBNo AS NVARCHAR(10)) +   
      ' failed @ ' + @@servername +   
      ' IP=' + Cast( (select local_net_address from sys.dm_exec_connections where session_id = @@SPID) as NVARCHAR(20)) + ')'  
   SET @cBody = CAST( @nErr AS NVARCHAR( 10)) + ':' + @cErrMsg  
  
   EXEC msdb.dbo.sp_send_dbmail  
      @recipients      = @cListTo,  
      @copy_recipients = @cListCc,  
      @subject         = @cSubject,  
      @body            = @cErrMsg  
END  
  
RAISERROR (N'SQL Error: %s ErrorNo: %d.',10, 1, @cErrMsg, @nErr);  
  
RETURN  
END

GO