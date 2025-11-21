SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Copyright: IDS                                                             */    
/* Purpose: C4 Split Shipment when Loading  SOS#257863                        */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 2012-10-03 1.0  ChewKP      Created                                        */    
/* 2012-12-17 1.1  Audrey      SOS264232 - remove sectionkey           (ang01)*/ 
/* 2013-01-09 1.2  James       Bug fix on data truncation (james01)           */ 
/* 2013-04-30 1.3  CSCHONG     Add Lottable06-15 (CS01)                       */
/* 28-Jan-2019 1.4 TLTING_ext  enlarge externorderkey field length      */
/******************************************************************************/    
CREATE PROC [dbo].[isp_ScanToTruck_DropID_MBOLCreation]    
(    
   @cMBOLKey   NVARCHAR(10),    
   @cListTo    NVARCHAR(max) = '',    
   @cListCc    NVARCHAR(max) = '',    
   @nErrNo     INT          OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
 DECLARE    
     @cNewOrderKey     NVARCHAR(10)    
    ,@cCaseID          NVARCHAR(20)    
    ,@cOrderKey        NVARCHAR(10)    
    ,@cOrderLineNumber NVARCHAR(5)    
    ,@cMbolLineNumber  NVARCHAR(5)    
    ,@nQtyPicked       INT    
    ,@nContinue        INT    
    ,@nQtyAllocated    INT    
    ,@nStartTranCount  INT    
    ,@bSuccess         INT    
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
    ,@nWCS_RowRef      INT    
    ,@nTRK_RowRef      INT    
    ,@nOpenQty         INT    
    ,@nTotWeight       FLOAT    
    ,@nTotCube         FLOAT    
    ,@nTotCartons      FLOAT    
    ,@cOrdType         NVARCHAR(1)   
    ,@cLabelNo         NVARCHAR(20)   
    ,@cFacility        NVARCHAR( 5)    
    ,@b_success        INT  
    ,@cLoadLineNumber  NVARCHAR( 5)    
      
    ,@cConsigneeKey     NVARCHAR(15)  
    ,@cPrioriry         NVARCHAR(10)  
    ,@dOrderDate        datetime  
    ,@dDelivery_Date    datetime  
    ,@cOrderType        NVARCHAR(10)  
    ,@cDoor             NVARCHAR(10)  
    ,@cRoute            NVARCHAR(10)  
    ,@cDeliveryPlace    NVARCHAR(30)  
    ,@cExternOrderKey   NVARCHAR(50)    --tlting_ext
    ,@cCustomerName     NVARCHAR(45)  
    ,@cDropID           NVARCHAR(20)  
    ,@nNoOfOrdLines     INT  
    ,@cCompany          NVARCHAR(60)  
    
   -- Get LoadKey    
   DECLARE @cLoadKey NVARCHAR( 10)    
   DECLARE @tOrders TABLE (OrderKey NVARCHAR(10), OrdType NVARCHAR(1), LinkOrderKey NVARCHAR(10))    
   DECLARE @tMBOL TABLE(MBOLKey NVARCHAR(10))    
    
   SET @bDebug = '0'    
   SET @nContinue = 1    
   SET @nStartTranCount = @@TRANCOUNT    
   SET @nErrNo = 0  
    
   WHILE @@TRANCOUNT > 0    
      COMMIT TRAN    
    
   BEGIN TRAN    
    
   -- Loop each MBOL    
   DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT T.MBOLKey,    
          T.RefNo,  
          T.RowRef  
   FROM rdt.RDTScanToTruck T WITH (NOLOCK)    
   JOIN MBOL M WITH (NOLOCK) ON (T.MBOLKey = M.MBOLKey)    
   WHERE T.Status = '3'    
   AND T.MBOLKey = @cMBOLKey  
   AND ISNULL(T.RefNo,'') <> ''  
   --AND T.RefNo  = @cDropID  
   --AND   T.Door = @cDoor    
   --AND MBOL.PlaceOfLoading = @cDoor    
   ORDER BY T.RowRef    
    
   OPEN CUR_MBOL    
   FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @cDropID, @nTRK_RowRef  
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      IF NOT EXISTS(SELECT 1 FROM @tMBOL WHERE MBOLKey = @cMBOLKey)    
         INSERT INTO @tMBOL(MBOLKey) VALUES (@cMBOLKey)    
    
      -- Loop OrderDetail level    
      DECLARE CUR_PickDetail_Info CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.DropID, PD.OrderKey, PD.OrderLineNumber,    
            SUM(CASE WHEN PD.Status = '5' THEN PD.QTY ELSE 0 END) AS QtyPicked,    
            SUM(CASE WHEN PD.Status < '5' THEN PD.QTY ELSE 0 END) AS QtyAllocated    
         FROM PickDetail PD (NOLOCK)    
         WHERE PD.DropID = @cDropID  
         GROUP BY PD.DropID, PD.OrderKey, PD.OrderLineNumber    
    
      OPEN CUR_PickDetail_Info    
    
      FETCH NEXT FROM CUR_PickDetail_Info INTO @cDropID, @cOrderKey, @cOrderLineNumber, @nQtyPicked, @nQtyAllocated    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @cNewOrderKey = ''    
    
         SELECT TOP 1 @cNewOrderKey = ISNULL(O.OrderKey,'')    
         FROM dbo.Orders O WITH (NOLOCK)    
         --INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey    
         WHERE O.MbolKey = @cMBOLKey    
         AND O.UserDefine10 = @cOrderKey    
    
         -- Check IF There is Existing UserDefine10 in the OrderDetail    
         IF ISNULL(RTRIM(@cNewOrderKey),'') = ''    
         BEGIN    
            EXECUTE nspg_GetKey    
               'ORDER',    
               10,    
               @cNewOrderKey  OUTPUT,    
               @bSuccess    OUTPUT,    
               @nErrNo      OUTPUT,    
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
            C_Zip,           C_Country,       C_ISOCntryCode,     C_Phone1,    
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
            B_Company,        B_Address1,      B_Address2,        B_Address3,    
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
            CASE WHEN ISNULL(RTRIM(UserDefine10),'') = '' THEN @cOrderKey ELSE UserDefine10 END,       
            Issued,              DeliveryNote,     PODCust,    
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
               SET @nErrNo = 77801  
               SET @cErrMsg = 'INSERT INTO ORDERS Table Failed'    
               GOTO QUIT_WITH_ERROR    
            END    
    
            -- Split OrderInfo   
            INSERT INTO OrderInfo    
               (OrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10)    
            SELECT    
               @cNewOrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08, OrderInfo09, OrderInfo10    
            FROM OrderInfo WITH (NOLOCK)    
            WHERE OrderKey = @cOrderKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3    
               SET @nErrNo = 77802  
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
               SET @nErrNo = 77803  
               SET @cErrMsg = 'INSERT INTO MBOLDETAIL Table Failed'    
               GOTO QUIT_WITH_ERROR    
            END    
              
            -- Insert Into LoadPLanDetail    
            IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE OrderKey = @cNewOrderKey)    
            BEGIN    
               SET @cLoadKey = ''    
               SELECT @cLoadKey = LoadKey    
               FROM LoadPlanDetail WITH (NOLOCK)    
               WHERE OrderKey = @cNewOrderKey   
                 
               -- Create LoadPlan Header if is not exist  
               IF ISNULL(RTRIM(@cLoadKey),'') = ''  
               BEGIN  
                  EXECUTE nspg_GetKey    
                     'LOADKEY',    
                     10,    
                     @cLoadKey      OUTPUT,    
                     @b_success     OUTPUT,    
                     @nErrNo        OUTPUT,    
                     @cErrMsg       OUTPUT    
                   
                  IF @b_success <> 1    
                  BEGIN    
                     SELECT @nContinue = 3    
                     GOTO QUIT_WITH_ERROR    
                  END    
                         
                   SELECT TOP 1  @cFacility = Facility  
                                ,@cConsigneeKey   = ConsigneeKey  
                                ,@cExternOrderKey = ExternOrderKey  
                                ,@cCustomerName   = C_Company  
                                ,@dOrderDate      = OrderDate  
                                ,@dDelivery_Date  = DeliveryDate  
                                ,@cOrderType      = Type  
                                ,@cDoor           = Door  
                                ,@cRoute          = [Route]  
                                ,@cDeliveryPlace  = DeliveryPlace  
                   FROM Orders WITH (NOLOCK)     
                   WHERE OrderKey = @cOrderKey   
                      AND Status NOT IN ('9','CANC')    
                      AND ISNULL(Loadkey,'') = ''    
                     
                   -- Get Storer.Company for MBOLDetail.Description  
                   SET @cCompany = ''  
                   SELECT @cCompany = Company   
                   FROM dbo.Storer WITH (NOLOCK)  
                   WHERE StorerKey = @cConsigneeKey    
                     
                   IF @bDebug = '1'  
                   BEGIN  
                      SELECT @cLoadKey '@cLoadKey', @cNewOrderKey '@cNewOrderKey'  
                        
                      SELECT @cFacility       '@cFacility       '  
                           ,@cConsigneeKey   '@cConsigneeKey   '  
                           ,@cExternOrderKey '@cExternOrderKey '  
                           ,@cCustomerName   '@cCustomerName   '  
                           ,@dOrderDate      '@dOrderDate      '  
                           ,@dDelivery_Date  '@dDelivery_Date  '  
                           ,@cOrderType      '@cOrderType      '  
                           ,@cDoor           '@cDoor           '  
                           ,@cRoute          '@cRoute          '  
                           ,@cDeliveryPlace  '@cDeliveryPlace  '  
                   END  
    
                   -- Create loadplan            
                   INSERT INTO LoadPlan (LoadKey, Facility, MBOLKey)    
                   VALUES (@cLoadKey, @cFacility, @cMBOLKey)    
                       
                   SELECT @nErrNo = @@ERROR    
                          
                   IF @nErrNo <> 0     
                   BEGIN    
                     SELECT @nContinue = 3    
                     SET @nErrNo = 77804  
                     SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Insert Into LOADPLAN Failed. "    
                     GOTO QUIT_WITH_ERROR    
                   END    
                     
                   -- Update Orders LoadKey  
                   Update Orders  
                   SET LoadKey = @cLoadKey,  
                       TrafficCop = NULL    
                   WHERE OrderKey = @cNewOrderKey  
                     
                   SELECT @nErrNo = @@ERROR    
                          
                   IF @nErrNo <> 0     
                   BEGIN    
                     SELECT @nContinue = 3    
                     SET @nErrNo = 77805  
                     SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Update Orders Failed. "    
                     GOTO QUIT_WITH_ERROR    
                   END    
                     
                   -- Update Orderdetail LoadKey  
                   Update Orderdetail  
                   SET LoadKey = @cLoadKey,  
                       TrafficCop = NULL    
                   WHERE OrderKey = @cNewOrderKey  
                     
                   SELECT @nErrNo = @@ERROR    
                          
                  IF @nErrNo <> 0     
                   BEGIN    
                     SELECT @nContinue = 3    
                     SET @nErrNo = 77806  
                     SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Update Orders Failed. "    
                     GOTO QUIT_WITH_ERROR    
                   END    
                     
                   -- Update MBOLDetail   
                   Update MBOLDetail  
                   SET LoadKey = @cLoadKey,  
                       Description = SUBSTRING(RTRIM(@cCompany), 1, 30), -- description only nvarchar(30) (james01) 
                       TrafficCop = NULL     
                   WHERE OrderKey = @cNewOrderKey  
                   AND MBOLKey = @cMBOLKey  
                     
                   SELECT @nErrNo = @@ERROR    
                          
                   IF @nErrNo <> 0     
                   BEGIN    
                     SELECT @nContinue = 3    
                     SET @nErrNo = 77807  
                     SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Update MBOLDetail Failed. "    
                     GOTO QUIT_WITH_ERROR    
                   END    
               END   
    
               IF EXISTS ( SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE LOADKEY = @cLoadKey)  
               BEGIN  
                  IF @bDebug = '1'  
                  BEGIN  
                      PRINT 'Existing LoadPlanDetail:' + @cLoadKey  
                  END  
                    
                  -- Get max linenumber    
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
               END      
               ELSE  
               BEGIN  
                  SELECT @cLoadLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LoadLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
                  FROM dbo.LoadPlanDetail WITH (NOLOCK)    
                  WHERE LoadKey = @cLoadKey    
                    
                  IF @bDebug = '1'  
                  BEGIN  
                      PRINT 'New LoadPlanDetail:' + @cLoadKey  
                        
                      SELECT @cFacility       '@cFacility       '  
                           ,@cConsigneeKey   '@cConsigneeKey   '  
                           ,@cExternOrderKey '@cExternOrderKey '  
                           ,@cCustomerName   '@cCustomerName   '  
                           ,@dOrderDate      '@dOrderDate      '  
                           ,@dDelivery_Date  '@dDelivery_Date  '  
                           ,@cOrderType      '@cOrderType      '  
                           ,@cDoor           '@cDoor           '  
                           ,@cRoute          '@cRoute          '  
                           ,@cDeliveryPlace  '@cDeliveryPlace  '  
                        
                  END  
       
                  INSERT INTO LOADPLANDETAIL    
                     (LoadKey,            LoadLineNumber,    
                      OrderKey,           ConsigneeKey,    
                      Priority,           OrderDate,    
                      DeliveryDate,       Type,    
                      Door,               Stop,    
                      Route,              DeliveryPlace,    
                      Weight,             Cube,    
                      ExternOrderKey,     CustomerName,    
                      [STATUS])    
                  VALUES(  
                      @cLoadKey,          @cLoadLineNumber,    
                      @cNewOrderKey,      @cConsigneeKey,    
                      @cConsigneeKey,     @dOrderDate,    
                      @dDelivery_Date,    @cOrderType,    
                      @cDoor,             '',    
                      @cRoute,            @cDeliveryPlace,    
                      --Weight,             Cube,    
                      0,           0,    
                      @cExternOrderKey,   @cCustomerName,    
                      '5'  )  
                    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nContinue = 3    
                     SET @nErrNo = 77808  
                     SET @cErrMsg = 'Insert LOADPLANDETAIL Failed'    
                     GOTO QUIT_WITH_ERROR    
                  END    
                 
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
           ShippedQty,            AdjustedQty,      QtyPreAllocated,       QtyAllocated,    
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
			  Lottable07,            Lottable08,       Lottable09,            Lottable10,  
			  Lottable11,            Lottable12,       Lottable13,            Lottable14,
			  Lottable15,            FreeGoodQty,        
           GrossWeight,            Capacity,         LoadKey,             @cMBOLKey,    
           QtyToProcess,           MinShelfLife,     UserDefine01,        UserDefine02,    
           UserDefine03,           UserDefine04,     UserDefine05,        UserDefine06,    
           UserDefine07,           UserDefine08,     UserDefine09,        POkey,    
           ExternPOKey,              
           Userdefine10,  
           EnteredQTY=0,          
           ConsoOrderKey,          ExternConsoOrderKey,    ConsoOrderLineNo    
          FROM ORDERDETAIL o WITH (NOLOCK)    
          WHERE o.OrderKey = @cOrderKey    
          AND   o.OrderLineNumber = @cOrderLineNumber  
			 /*CS01 End*/   
          IF @@ERROR <> 0    
          BEGIN    
             SET @nContinue = 3    
             SET @nErrNo = 77809  
             SET @cErrMsg = 'INSERT INTO ORDERDETAIL Table Failed'    
             GOTO QUIT_WITH_ERROR    
          END    
         END -- if not exists in order line    
    
         
      UPDATE RKP    
         SET OrderKey = @cNewOrderKey    
      FROM RefKeyLookUp RKP    
      JOIN PICKDETAIL p WITH (NOLOCK) ON p.PickDetailkey = RKP.PickDetailkey    
      WHERE P.OrderKey = @cOrderKey    
      AND P.OrderLineNumber = @cOrderLineNumber    
      AND P.DropID = @cDropID  
      IF @@ERROR <> 0    
      BEGIN    
         SET @nContinue = 3    
         SET @nErrNo = 77810  
         SET @cErrMsg = 'Update RefKeyLookUp Table Failed'    
         GOTO QUIT_WITH_ERROR    
      END    
    
      UPDATE PICKDETAIL    
         SET OrderKey = @cNewOrderKey,    
             EditDate = GETDATE(),    
             TrafficCop = NULL    
      WHERE OrderKey = @cOrderKey    
      AND OrderLineNumber = @cOrderLineNumber    
      AND DropID = @cDropID  
      IF @@ERROR <> 0    
      BEGIN    
         SET @nContinue = 3    
         SET @nErrNo = 77811  
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
         SET @nContinue = 3    
         SET @nErrNo = 77812  
         SET @cErrMsg = 'Update ORDERDETAIL Table Failed'    
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
         SET @nErrNo = 77813  
         SET @cErrMsg = 'Update ORDERS Table Failed'    
         GOTO QUIT_WITH_ERROR    
      END    
    
      -- Updating Old OrderDetail    
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
         SET @nContinue = 3    
         SET @nErrNo = 77814  
         SET @cErrMsg = 'Update ORDERDETAIL Table Failed'    
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
          SET @nErrNo = 77815  
          SET @cErrMsg = 'Update ORDERS Table Failed'    
          GOTO QUIT_WITH_ERROR    
       END    
    
      IF NOT EXISTS(SELECT 1 FROM @tOrders WHERE OrderKey = @cNewOrderKey)    
         INSERT INTO @tOrders(OrderKey, OrdType, LinkOrderKey) VALUES (@cNewOrderKey, 'N', @cOrderKey)    
    
      IF NOT EXISTS(SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)    
         INSERT INTO @tOrders(OrderKey, OrdType, LinkOrderKey) VALUES (@cOrderKey, 'O', @cNewOrderKey)    
    
      -- Commit Tran by Carton    
      WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
    
      -- Start Another Tran    
      BEGIN TRAN    
    
      FETCH NEXT FROM CUR_PickDetail_Info INTO @cDropID, @cOrderKey, @cOrderLineNumber,    
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
      SET @nErrNo = 77816  
      SET @cErrMsg = 'Update rdtScantoTruckFailed'    
      GOTO QUIT_WITH_ERROR    
   END    
    
   WHILE @@TRANCOUNT > 0    
      COMMIT TRAN    
    
   FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @cDropID, @nTRK_RowRef  
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
    
      SELECT TOP 1    
         @cPickSlipNo = pd.PickSlipNo,    
         @nCartonNo = pd.CartonNo    
      FROM PackDetail pd WITH (NOLOCK)    
      WHERE pd.LabelNo = @cLabelNo    
    
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
         FROM PickDetail PD (NOLOCK)    
         INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)    
         WHERE PD.OrderKey = @cOrderKey  
         AND PD.DropID = @cDropID  
      END    
    
      -- Get carton cube    
      SET @nCube = 0    
      
      SELECT @nCube = (S.STDCUBE * PD.Qty)    
      FROM PickDetail PD (NOLOCK)    
      INNER JOIN SKU S WITH (NOLOCK) ON (S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU)    
      WHERE PD.OrderKey = @cOrderKey  
         AND PD.DropID = @cDropID  
           
      SET @nTotWeight  = @nTotWeight + @nWeight    
      SET @nTotCube    = @nTotCube   + @nCube    
      SET @nTotCartons = @nTotCartons + 1    
    
      -- Get NoOfOrdLines from OrderDetail  
      SET @nNoOfOrdLines = 0   
        
      SELECT @nNoOfOrdLines = COUNT(Orderlinenumber)   
      FROM OrderDetail WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
        
      UPDATE LoadPlanDetail SET    
         Weight = @nTotWeight,    
         Cube = @nTotCube,    
         EditDate = GETDATE(),    
         NoOfOrdLines = @nNoOfOrdLines,  
         TrafficCop = NULL    
      WHERE LoadKey = @cLoadKey    
        AND OrderKey = @cOrderKey    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nContinue = 3    
         SET @nErrNo = 77817  
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
         SET @nErrNo = 77818  
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
  
         -- Stamp MASTER in original orders  
         UPDATE Orders SET   
            RDD = 'MASTERORDER',   
            EditDate = GETDATE(),  
            Trafficcop = NULL    
         WHERE OrderKey = @cOrderKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nContinue = 3    
            SET @nErrNo = 77819  
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
            SET --SectionKey = 'Y',  (ang01)  
               EditDate = GETDATE(),    
               Trafficcop = NULL    
            WHERE OrderKey = @cNewOrderKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3   
               SET @nErrNo = 77820   
               SET @cErrMsg = 'Update Orders Failed'    
               GOTO QUIT_WITH_ERROR    
            END    
    
            UPDATE Orders    
            SET [SOStatus]  = 'MASTER',    
                [Status] = '9',   
                EditDate = GETDATE(),    
                Trafficcop = NULL    
            WHERE OrderKey = @cOrderKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3    
               SET @nErrNo = 77821  
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
               SET @nErrNo = 77822  
               SET @cErrMsg = 'Update MBOLDetail Failed'    
               GOTO QUIT_WITH_ERROR    
            END    
    
            --IF EXISTS( SELECT 1 FROM LoadPlanDetail WHERE OrderKey = @cOrderKey)    
            --   DELETE LoadPlanDetail WHERE OrderKey = @cOrderKey    
         END --IF @nQTY = 0    
         ELSE    
         BEGIN    
          UPDATE Orders    
            SET --SectionKey = 'N',  (ang01)  
               EditDate = GETDATE(),    
               Trafficcop = NULL    
            WHERE OrderKey = @cNewOrderKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3    
               SET @nErrNo = 77823  
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
    
   WHILE @@TRANCOUNT > 0    
      COMMIT TRAN    
    
QUIT_NORMAL:    
  
    
WHILE @@TRANCOUNT > 0    
   COMMIT TRAN    
    
WHILE @@TRANCOUNT < @nStartTranCount    
   BEGIN TRAN    
    
RETURN    
    
QUIT_WITH_ERROR:    
    
IF @@TRANCOUNT > @nStartTranCount    
   ROLLBACK TRAN    

RETURN    
END  

GO