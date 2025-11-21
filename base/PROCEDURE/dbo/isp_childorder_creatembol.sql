SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ChildOrder_CreateMBOL                             */
/* Creation Date: 05-DEC-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#294825- ANF Create MBOL                                    */
/*        :                                                                */
/*                                                                         */
/* Called By: w_populate_mbol_child_order  - Function "C"                  */
/*            (RCM @ MBOL Screen -> Child Order -> Create & Populate)      */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 14-MAY-2013  YTWan   1.1   Dummy PickslipNo to child order(Wan01)       */
/* 07-May-2014  TKLIM   1.1   Added Lottables 06-15                        */
/* 25-Feb-2015  Leong   1.2   SOS# 333519 - Prompt error for shipped CaseId*/
/* 06-Jan-2015  NJOW01  1.3   359849 - Child Order's Shipperkey Mapping    */
/* 08-Mar-2016  SPChin  1.4   SOS365643 - Bug Fixed                        */
/* 11-MAR-2021  Wan02   1.5   WMS-16026 - PB-Standardize TrackingNo        */  
/* 15-Mar-2021  WLChooi 1.6   WMS-16338 - Add Orderdetail.Channel and new  */
/*                                        logic for ANFQHW (WL01)          */
/* 15-Jul-2021  WLChooi 1.7   Fix Update Palletdetail with Storerkey (WL02)*/
/* 20-AUG-2021  Wan02   1.8   WMS-17787 - [CN] ANFQHW_WMS_MBOL_Creation CR */
/* 28-OCT-2021  Wan02   1.8   DevOps Combine Script.                       */
/***************************************************************************/
CREATE PROC [dbo].[isp_ChildOrder_CreateMBOL]
(     @c_MBOLKey     NVARCHAR(10)
  ,   @c_Orderkey    NVARCHAR(10)
  ,   @c_Store       NVARCHAR(30)
  ,   @c_Store_Child NVARCHAR(30) = ''       -- Wan01
  ,   @c_CaseID      NVARCHAR(20)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT
         , @n_Continue           INT
         , @n_StartTranCount     INT

   -- Get LoadKey
   DECLARE @n_OpenQty            INT
         , @n_QtyPicked          INT
         , @n_QtyAllocated       INT
         , @n_TotalPallets       INT
         , @n_TotalCartons       INT
         , @n_TotWeight          FLOAT
         , @n_TotCube            FLOAT
         , @n_LoadWeight         FLOAT
         , @n_LoadCube           FLOAT
         , @n_MBOLWeight         FLOAT
         , @n_MBOLCube           FLOAT
         , @c_PickdetailKey      NVARCHAR(10)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_COrderKey          NVARCHAR(10)
         , @c_COrderLineNumber   NVARCHAR(5)
         , @c_CLoadKey           NVARCHAR(10)
         , @c_CLoadLineNumber    NVARCHAR(5)
         , @c_MBOLLineNumber     NVARCHAR(5)
         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Consigneekey       NVARCHAR(30)         --(Wan02)
         , @c_C_contact1         NVARCHAR(30)
         , @c_C_Contact2         NVARCHAR(30)
         , @c_C_Company          NVARCHAR(45)
         , @c_C_Address1         NVARCHAR(45)
         , @c_C_Address2         NVARCHAR(45)
         , @c_C_Address3         NVARCHAR(45)
         , @c_C_Address4         NVARCHAR(45)
         , @c_C_City             NVARCHAR(45)
         , @c_C_State            NVARCHAR(45)
         , @c_C_Zip              NVARCHAR(18)
         , @c_C_Country          NVARCHAR(30)
         , @c_C_ISOCntryCode     NVARCHAR(10)
         , @c_C_Phone1           NVARCHAR(18)
         , @c_C_Phone2           NVARCHAR(18)
         , @c_C_Fax1             NVARCHAR(18)
         , @c_C_Fax2             NVARCHAR(18)
         , @c_C_Vat              NVARCHAR(18)
         , @c_Route              NVARCHAR(10)

         , @c_Doctype            NVARCHAR(20)
         , @c_CarrierCode        NVARCHAR(15)

         , @c_PickSlipNo         NVARCHAR(10)
         , @c_CPickSlipNo        NVARCHAR(10)
         , @n_CartonNo           INT

         , @n_CaseQtyPicked      INT            --(Wan01)
         , @n_CaseQtyPacked      INT            --(Wan01)
         , @n_CCartonNo          INT            --(Wan01)
         , @c_CPickSlipNoPrev    NVARCHAR(10)   --(Wan01)
         , @c_Sku                NVARCHAR(20)   --(Wan01)
         , @c_SkuPrev            NVARCHAR(20)   --(Wan01)
         
         , @c_MBOLCreateChildOrdChkPallet   NVARCHAR(50)   --WL01


   SET @b_Success        = 1
   SET @c_ErrMsg         = ''

   SET @b_Debug          = '0'
   SET @n_Continue       = 1
   SET @n_StartTranCount = @@TRANCOUNT

   SET @c_CLoadkey       = ''
   SET @c_C_contact1     = ''
   SET @c_C_Contact2     = ''
   SET @c_C_Company      = ''
   SET @c_C_Address1     = ''
   SET @c_C_Address2     = ''
   SET @c_C_Address3     = ''
   SET @c_C_Address4     = ''
   SET @c_C_City         = ''
   SET @c_C_State        = ''
   SET @c_C_Zip          = ''
   SET @c_C_Country      = ''
   SET @c_C_ISOCntryCode = ''
   SET @c_C_Phone1       = ''
   SET @c_C_Phone2       = ''
   SET @c_C_Fax1         = ''
   SET @c_C_Fax2         = ''
   SET @c_C_Vat          = ''


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --(Wan01) - START
   SET @n_CaseQtyPicked = 0
   SELECT @n_CaseQtyPicked = SUM(Qty)
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE CaseID = @c_CaseID

   SET @n_CaseQtyPacked = 0
   SELECT @n_CaseQtyPacked = SUM(Qty)
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE LabelNo = @c_CaseID

   IF @n_CaseQtyPicked <> @n_CaseQtyPacked
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 80001
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Parent Order#: ''' + RTRIM(@c_Orderkey)
                    + ''', Case ID: ''' + RTRIM(@c_CaseID)+ ''' pick & pack unmatch. (isp_ChildOrder_CreateMBOL)'
      GOTO QUIT_WITH_ERROR
   END
   --(Wan01) - END

   -- SOS# 333519(Start)
   IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK) WHERE CaseID = @c_CaseID AND Orderkey = @c_Orderkey
              AND (ShipFlag = 'Y' OR Status = '9'))
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 80200
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Parent Order#: ''' + RTRIM(@c_Orderkey)
                    + ''', Case ID: ''' + RTRIM(@c_CaseID)+ ''' shipped. (isp_ChildOrder_CreateMBOL)'
      GOTO QUIT_WITH_ERROR
   END
   -- SOS# 333519(End)

   BEGIN TRAN

   --Get Order Info
   SELECT @c_Facility   = Facility
         ,@c_Storerkey  = Storerkey
         ,@c_DocType    = ISNULL(RTRIM(Userdefine05),'')
         --,@c_CarrierCode= ISNULL(RTRIM(ShipperKey),'') --NJOW01 remarked
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
      
   --(Wan02) - START
   SET @c_Store_Child = ISNULL(@c_Store_Child,'')
   SET @c_Consigneekey = @c_Store
   
   IF @c_Store_Child <> ''
   BEGIN
      --IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL AS o WITH (NOLOCK) 
      --            JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
      --                                                   AND p.OrderLineNumber = o.OrderLineNumber
      --            WHERE o.Storerkey = @c_Storerkey AND p.CaseID = @c_CaseID
      --            GROUP BY p.CaseID
      --            HAVING COUNT(DISTINCT ISNULL(o.UserDefine02,'') + ISNULL(o.UserDefine09,'')) = 1
      --)
      --BEGIN
         SET @c_Consigneekey = @c_Store_Child
      --END
   END
   --(Wan02) - END
     
   --NJOW01
   SELECT @c_CarrierCode = ISNULL(RTRIM(SOD.Terms),'')
   FROM STORER  ST          WITH (NOLOCK)
   LEFT JOIN STORERSODEFAULT SOD WITH (NOLOCK) ON (ST.Storerkey = SOD.Storerkey)
   WHERE ST.Storerkey = @c_Consigneekey               --(Wan02)

   --WL01 S
   EXEC nspGetRight  
      @c_Facility  = @c_Facility,  
      @c_StorerKey = NULL,  
      @c_sku       = NULL,  
      @c_ConfigKey = 'MBOLCreateChildOrdChkPallet',  
      @b_Success   = @b_Success                     OUTPUT,  
      @c_authority = @c_MBOLCreateChildOrdChkPallet OUTPUT,  
      @n_err       = @n_err                         OUTPUT,  
      @c_errmsg    = @c_errmsg                      OUTPUT 
      
   IF @n_err <> 0  
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 80140 
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Execute nspGetRight Failed. (isp_ChildOrder_CreateMBOL)' 
      GOTO QUIT_WITH_ERROR
   END
   --WL01 E
   
   IF NOT EXISTS( SELECT 1
                  FROM MBOLDETAIL WITH (NOLOCK)
                  WHERE MBOLKey = @c_MBOLkey )
   BEGIN
      SET @c_COrderkey = ''
   END
   ELSE
   BEGIN
      --Create ORDER Base on Grouping Criteria
      SELECT @c_COrderkey = Orderkey
      FROM ORDERS WITH (NOLOCK)
      WHERE MBOLKey = @c_MBOLkey
      AND Storerkey = @c_Storerkey
      AND Consigneekey = @c_Consigneekey           --(Wan02)
      AND Shipperkey   = @c_CarrierCode
      AND Userdefine05 = @c_DocType
      AND Userdefine03 = @c_Store_Child            --(Wan02)
      AND Type    = 'CHDORD'
      AND Status  < '9'

      --Get MBOL's Loadkey
      SELECT TOP 1 @c_CLoadkey = ISNULL(RTRIM(COH.Loadkey),'')
      FROM MBOLDETAIL MBD WITH (NOLOCK)
      JOIN ORDERS     COH WITH (NOLOCK) ON (MBD.Orderkey = COH.Orderkey)
      WHERE MBD.MBOLKey = @c_MBOLkey
   END

   --CREATE ORDERS HEADER
   IF ISNULL(RTRIM(@c_COrderkey),'') = ''
   BEGIN
      EXECUTE nspg_GetKey
         'ORDER',
         10,
         @c_COrderkey  OUTPUT,
         @b_Success    OUTPUT,
         @n_Err        OUTPUT,
         @c_ErrMsg     OUTPUT

      IF NOT @b_Success = 1
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_WITH_ERROR
      END

      SELECT @c_C_contact1     = ISNULL(RTRIM(ST.contact1),'')
            ,@c_C_Contact2     = ISNULL(RTRIM(ST.Contact2),'')
            ,@c_C_Company      = ISNULL(RTRIM(ST.Company),'')
            ,@c_C_Address1     = ISNULL(RTRIM(ST.Address1),'')
            ,@c_C_Address2     = ISNULL(RTRIM(ST.Address2),'')
            ,@c_C_Address3     = ISNULL(RTRIM(ST.Address3),'')
            ,@c_C_Address4     = ISNULL(RTRIM(ST.Address4),'')
            ,@c_C_City         = ISNULL(RTRIM(ST.City),'')
            ,@c_C_State        = ISNULL(RTRIM(ST.State),'')
            ,@c_C_Zip          = ISNULL(RTRIM(ST.Zip),'')
            ,@c_C_Country      = ISNULL(RTRIM(ST.Country),'')
            ,@c_C_ISOCntryCode = ISNULL(RTRIM(ST.ISOCntryCode),'')
            ,@c_C_Phone1       = ISNULL(RTRIM(ST.Phone1),'')
            ,@c_C_Phone2       = ISNULL(RTRIM(ST.Phone2),'')
            ,@c_C_Fax1         = ISNULL(RTRIM(ST.Fax1),'')
            ,@c_C_Fax2         = ISNULL(RTRIM(ST.Fax2),'')
            ,@c_C_Vat          = ISNULL(RTRIM(ST.Vat),'')
            ,@c_Route          = CASE WHEN @c_MBOLCreateChildOrdChkPallet = '1' THEN ISNULL(RTRIM(SOD.[Route]),'99') ELSE SOD.[Route] END   --WL01
      FROM STORER  ST          WITH (NOLOCK)
      LEFT JOIN STORERSODEFAULT SOD WITH (NOLOCK) ON (ST.Storerkey = SOD.Storerkey)
      WHERE ST.Storerkey = @c_Consigneekey            --(Wan02)

      INSERT INTO ORDERS
      (
      OrderKey,         StorerKey,        ConsigneeKey,        C_contact1,
      C_Contact2,       C_Company,        C_Address1,          C_Address2,
      C_Address3,       C_Address4,       C_City,              C_State,
      C_Zip,            C_Country,        C_ISOCntryCode,      C_Phone1,
      C_Phone2,         C_Fax1,           C_Fax2,              C_Vat,
      Type,             OpenQty,          Status,              Route,
      Facility,         RDD,              UserDefine05,        ShipperKey,
      Loadkey,          MBOLKey,          UserDefine02,        UserDefine03   --(Wan02)
      )
      SELECT
      @c_COrderKey,     OH.StorerKey,     @c_Consigneekey,     @c_C_contact1, --(Wan02)
      @c_C_Contact2,    @c_C_Company,     @c_C_Address1,       @c_C_Address2,
      @c_C_Address3,    @c_C_Address4,    @c_C_City,           @c_C_State,
      @c_C_Zip,         @c_C_Country,     @c_C_ISOCntryCode,   @c_C_Phone1,
      @c_C_Phone2,      @c_C_Fax1,        @c_C_Fax2,           @c_C_Vat,
      'CHDORD',         OpenQty=0,        '5',                 @c_Route,
      OH.Facility,      'SplitOrder',     OH.UserDefine05,     @c_CarrierCode, --NJOW01  OH.ShipperKey,
      OH.LoadKey,        @c_MBOLKey,      @c_Store,            @c_Store_Child --(Wan02)       
/*
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
      DeliveryPlace,   IntermodalVehicle,CountryOfOrigin,   CountryDestination,
      UpdateSource,    [Type],          OrderGroup,         Door,
      [Route],         [Stop],          Notes,              EffectiveDate,
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
      @c_COrderKey,        OH.StorerKey,           '',                  OH.OrderDate,
      OH.DeliveryDate,     OH.Priority,            @c_Store,            C_contact1,
      C_Contact2,          C_Company,              C_Address1,          C_Address2,
      C_Address3,          C_Address4,             C_City,              C_State,
      C_Zip,               C_Country,              C_ISOCntryCode,      C_Phone1,
      C_Phone2,            C_Fax1,                 C_Fax2,              C_vat,
      OH.BuyerPO,          OH.BillToKey,           OH.B_contact1,       OH.B_Contact2,
      OH.B_Company,        OH.B_Address1, OH.B_Address2,       OH.B_Address3,
      OH.B_Address4,       OH.B_City,              OH.B_State,          OH.B_Zip,
      OH.B_Country,        OH.B_ISOCntryCode,      OH.B_Phone1,         OH.B_Phone2,
      OH.B_Fax1,           OH.B_Fax2,              OH.B_Vat,            OH.IncoTerm,
      OH.PmtTerm,          OpenQty=0,              Status = '5',        OH.DischargePlace,
      OH.DeliveryPlace,    OH.IntermodalVehicle,   OH.CountryOfOrigin,  OH.CountryDestination,
      OH.UpdateSource,     'CHDORD',               OH.OrderGroup,       OH.Door,
      SOD.Route,           OH.Stop,                OH.Notes,            OH.EffectiveDate,
      OH.ContainerType,    OH.ContainerQty,        OH.BilledContainerQty,OH.SOStatus,
      @c_MBOLKey,          OH.InvoiceNo,           OH.InvoiceAmount,    OH.Salesman,
      GrossWeight=0,       Capacity=0,             OH.PrintFlag,        OH.LoadKey,
      Rdd='SplitOrder',    OH.Notes2,              OH.SequenceNo,       OH.Rds,
      OH.SectionKey,       OH.Facility,            OH.PrintDocDate,     OH.LabelPrice,
      OH.POKey,            OH.ExternPOKey,         OH.XDockFlag,        OH.UserDefine01,
      OH.UserDefine02,     OH.UserDefine03,        OH.UserDefine04,     OH.UserDefine05,
      OH.UserDefine06,     OH.UserDefine07,        OH.UserDefine08,     OH.UserDefine09,
      OH.UserDefine10,     OH.Issued,              OH.DeliveryNote,     OH.PODCust,
      OH.PODArrive,        OH.PODReject,           OH.PODUser,          OH.XDOCKPOKEY,
      OH.SpecialHandling,  OH.RoutingTool,         OH.MarkforKey,       OH.M_Contact1,
      OH.M_Contact2,       OH.M_Company,           OH.M_Address1,       OH.M_Address2,
      OH.M_Address3,       OH.M_Address4,          OH.M_City,           OH.M_State,
      OH.M_Zip,            OH.M_Country,           OH.M_ISOCntryCode,   OH.M_Phone1,
      OH.M_Phone2,         OH.M_Fax1,              OH.M_Fax2,           OH.M_vat,
      OH.ShipperKey
*/
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.OrderKey = @c_OrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80000
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT ORDERS Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   DECLARE CUR_CASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickdetailKey= PD.PickdetailKey
         ,OrderLineNumber = OD.OrderLineNumber
         ,QtyAllocated = ISNULL(CASE WHEN PD.Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END,0)
         ,QtyPicked    = ISNULL(CASE WHEN PD.Status IN ('5','6','7','8')     THEN Qty ELSE 0 END,0)
   FROM ORDERDETAIL OD WITH (NOLOCK)
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                     AND(OD.OrderLineNumber = PD.OrderLineNumber)
   WHERE OD.Orderkey = @c_Orderkey
   AND   OD.UserDefine02 = @c_Store
   AND   ISNULL(OD.UserDefine09,'') = @c_Store_Child        --(Wan02)
   AND   PD.CaseID       = @c_CaseID
   ORDER BY OD.OrderLineNumber

   OPEN CUR_CASE

   FETCH NEXT FROM CUR_CASE INTO @c_PickdetailKey
                              ,  @c_OrderLineNumber
                              ,  @n_QtyAllocated
                              ,  @n_QtyPicked
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_COrderLineNumber = ''
      SELECT @c_COrderLineNumber = ISNULL(OrderLineNumber,'00000')
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_COrderkey
      AND   UserDefine09 = @c_Orderkey
      AND   UserDefine10 = @c_OrderLineNumber

      IF @c_COrderLineNumber = ''
      BEGIN
         SELECT @c_COrderLineNumber = ISNULL(MAX(OrderLineNumber),'00000')
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE OrderKey = @c_COrderKey

         SET @c_COrderLineNumber = RIGHT('0000' + CONVERT(NVARCHAR(5), CAST(@c_COrderLineNumber AS INT) + 1), 5)

         INSERT INTO ORDERDETAIL
         (
         OrderKey,              OrderLineNumber,  OrderDetailSysId,      ExternOrderKey,
         ExternLineNo,          Sku,              StorerKey,             ManufacturerSku,
         RetailSku,             AltSku,           OriginalQty,           OpenQty,
         ShippedQty,            AdjustedQty,      QtyPreAllocated,       QtyAllocated,
         QtyPicked,             UOM,              PackKey,               PickCode,
         CartonGroup,           Lot,              ID,                    Facility,
         [Status],              UnitPrice,        Tax01,                 Tax02,
         ExtendedPrice,         UpdateSource,     FreeGoodQty,
         Lottable01,            Lottable02,       Lottable03,            Lottable04,       Lottable05,
         Lottable06,            Lottable07,       Lottable08,            Lottable09,       Lottable10,
         Lottable11,            Lottable12,       Lottable13,            Lottable14,       Lottable15,
         GrossWeight,           Capacity,         LoadKey,               MBOLKey,
         QtyToProcess,          MinShelfLife,     UserDefine01,          UserDefine02,
         UserDefine03,          UserDefine04,     UserDefine05,          UserDefine06,
         UserDefine07,          UserDefine08,     UserDefine09,          UserDefine10,
         POkey,                 ExternPOKey,      EnteredQTY,            ConsoOrderKey,
         ExternConsoOrderKey,   ConsoOrderLineNo, Channel   --WL01
         )
         SELECT
         @c_COrderKey,          @c_COrderLineNumber,OrderDetailSysId,    ExternOrderKey,
         ExternLineNo,          Sku,              StorerKey,             ManufacturerSku,
         RetailSku,             AltSku,
         OriginalQty=(@n_QtyAllocated + @n_QtyPicked),
         OpenQty    =(@n_QtyAllocated + @n_QtyPicked),
         ShippedQty,            AdjustedQty=-0,    QtyPreAllocated=0,     @n_QtyAllocated,
         @n_QtyPicked,          UOM,              PackKey,               PickCode,
         CartonGroup,           Lot,              ID,                    Facility,
         [Status]='5',          UnitPrice,        Tax01,                 Tax02,
         ExtendedPrice,         UpdateSource,     FreeGoodQty,
         Lottable01,            Lottable02,       Lottable03,            Lottable04,       Lottable05,
         Lottable06,            Lottable07,       Lottable08,            Lottable09,       Lottable10,
         Lottable11,            Lottable12,       Lottable13,            Lottable14,       Lottable15,
         GrossWeight,           Capacity,         '',                    @c_MBOLKey,
         QtyToProcess,          MinShelfLife,     UserDefine01,          @c_Consigneekey,             --(Wan01)
         UserDefine03,          UserDefine04,     UserDefine05,          UserDefine06,
         UserDefine07,          UserDefine08,     Orderkey,              OrderLineNumber,
         POkey,                 ExternPOKey,      EnteredQTY=0,          ConsoOrderKey,
         ExternConsoOrderKey,   ConsoOrderLineNo, Channel   --WL01
         FROM ORDERDETAIL o WITH (NOLOCK)
         WHERE o.OrderKey = @c_OrderKey
         AND   o.OrderLineNumber = @c_OrderLineNumber

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 80005
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT ORDERDETAIL Table Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END

         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET  Status   = 5
            , EditDate = GETDATE()
            , EditWho  = SUSER_NAME()
            , TrafficCop= NULL
         WHERE OrderKey = @c_COrderkey
         AND   OrderLineNumber = @c_COrderLineNumber

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 80010
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update OrderDetail Table Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END
      END
      ELSE
      BEGIN

         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET  OriginalQty  = OriginalQty + (@n_QtyAllocated + @n_QtyPicked)
            , OpenQty      = OpenQty + (@n_QtyAllocated + @n_QtyPicked)
            , QtyAllocated = QtyAllocated + @n_QtyAllocated
            , QtyPicked    = QtyPicked + @n_QtyPicked
            ,[Status]      = '5'
            , EditDate = GETDATE()
            , EditWho  = SUSER_NAME()
            , TrafficCop= NULL
         WHERE OrderKey = @c_COrderkey
         AND   OrderLineNumber = @c_COrderLineNumber


         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 80015
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update OrderDetail Table Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END
      END

      --Handling Parent ORDERS - START
      UPDATE REFKEYLOOKUP WITH (ROWLOCK)
      SET Orderkey = @c_COrderkey
         ,OrderLineNumber = @c_COrderLineNumber
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
         ,ArchiveCop= NULL
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80020
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update RefKeyLookup Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      --ALLOCATE CHILD ORDERS - Change Parent Pickdetail to Child Pickdetail
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET Orderkey = @c_COrderkey
         ,OrderLineNumber = @c_COrderLineNumber
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
         ,TrafficCop= NULL
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80025
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PickDetail Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      -- Update Parent Orderdetail
      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET OriginalQty  = OriginalQty - (@n_QtyAllocated + @n_QtyPicked)
         ,OpenQty      = OpenQty - (@n_QtyAllocated + @n_QtyPicked)
         ,QtyAllocated = QtyAllocated - @n_QtyAllocated
         ,QtyPicked    = QtyPicked - @n_QtyPicked
         ,[Status]     = CASE WHEN (QtyPicked - @n_QtyPicked) > 0 THEN '5'
                              WHEN (QtyPicked - @n_QtyPicked) + (QtyAllocated - @n_QtyAllocated) = 0
                              THEN '0'
                              WHEN (OpenQty - (@n_QtyPicked + @n_QtyAllocated)) =
                                   (QtyPicked - @n_QtyPicked) + (QtyAllocated - @n_QtyAllocated)
                              THEN '2'
                              ELSE '1'
                         END
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
         ,TrafficCop= NULL
      WHERE OrderKey = @c_Orderkey
      AND   OrderLineNumber = @c_OrderLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80030
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update OrderDetail Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      --Handling Parent ORDERS - END

      FETCH NEXT FROM CUR_CASE INTO @c_PickdetailKey
                                 ,  @c_OrderLineNumber
                                 ,  @n_QtyAllocated
                                 ,  @n_QtyPicked
   END
   CLOSE CUR_CASE
   DEALLOCATE CUR_CASE

   -- Update Child Order
   SELECT @n_OpenQty = SUM(OpenQty)
         ,@n_QtyAllocated = SUM(QtyAllocated)
         ,@n_QtyPicked    = SUM(QtyPicked)
   FROM ORDERDETAIL WITH (NOLOCK)
   WHERE Orderkey = @c_COrderkey

   UPDATE ORDERS WITH (ROWLOCK)
   SET OpenQty  = @n_OpenQty
      ,[Status] = CASE WHEN @n_QtyPicked + @n_QtyAllocated = 0 THEN '0'
                       WHEN @n_OpenQty = @n_QtyPicked          THEN '5'
                       ELSE '4'
                       END
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()
      ,TrafficCop= NULL
   FROM ORDERS
   WHERE Orderkey = @c_COrderkey

   -- Update Parent Order
   SELECT @n_OpenQty = SUM(OpenQty)
         ,@n_QtyAllocated = SUM(QtyAllocated)
         ,@n_QtyPicked    = SUM(QtyPicked)
   FROM ORDERDETAIL WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   UPDATE ORDERS WITH (ROWLOCK)
   SET OpenQty = @n_OpenQty
      --(Wan01) Remain Parent Order Status, do not update - START
      --,[Status] = CASE WHEN @n_QtyPicked + @n_QtyAllocated = 0 THEN '0'
      --                 WHEN @n_OpenQty = @n_QtyPicked          THEN '5'
      --                 ELSE '4'
      --                 END
      --(Wan01) Remain Parent Order Status, do not update - END
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()
      ,TrafficCop= NULL
   FROM ORDERS
   WHERE Orderkey = @c_Orderkey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 80035
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update Orders Table Failed. (isp_ChildOrder_CreateMBOL)'
      GOTO QUIT_WITH_ERROR
   END

--   COMMIT TRAN
--
--   BEGIN TRAN
   --Get TotalWeight, TotalCube, TotalCarton, TotalPallet for Child Order
   SELECT @n_TotWeight = SUM(PD.Qty * SKU.StdGrossWgt)
         ,@n_TotCube   = SUM(PD.Qty * SKU.StdCube)
         ,@n_TotalCartons = COUNT (DISTINCT PD.CaseID)
   FROM PICKDETAIL PD  WITH (NOLOCK)
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                     AND(PD.Sku = SKU.SKU)
   WHERE PD.Orderkey = @c_COrderkey


   --CREATE NEW LOADPLAN
   IF @c_CLoadkey = ''
   BEGIN
      EXECUTE nspg_GetKey
         'LOADKEY',
         10,
         @c_CLoadkey OUTPUT,
         @b_Success  OUTPUT,
         @n_Err      OUTPUT,
         @c_ErrMsg   OUTPUT

      IF NOT @b_Success = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80040
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Get Loadkey Fail. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      INSERT INTO LOADPLAN
         (  LoadKey
         ,  Facility
         )
      VALUES
         (  @c_CLoadkey
         ,  @c_Facility
         )

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80045
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT LOADPLAN Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   IF EXISTS (SELECT 1
                  FROM LOADPLANDETAIL WITH (NOLOCK)
                  WHERE Loadkey = @c_CLoadkey
                  AND   Orderkey= @c_COrderkey)
   BEGIN
      --UPDATE NEW LOADPLAN
      UPDATE LOADPLANDETAIL WITH (ROWLOCK)
      SET   Weight = @n_TotWeight
        ,   Cube   = @n_TotCube
        ,   EditDate = GETDATE()
        ,   EditWho  = SUSER_NAME()
        ,   TrafficCop = NULL
      WHERE LoadKey = @c_CLoadKey
        AND OrderKey = @c_COrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80050
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update LoadPlanDetail Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      -- GET New Load Info
      SELECT @n_LoadWeight = SUM(PD.Qty * SKU.StdGrossWgt)
            ,@n_LoadCube   = SUM(PD.Qty * SKU.StdCube)
            ,@n_TotalPallets = COUNT (DISTINCT DPD.DropID)
      FROM LOADPLANDETAIL LPD  WITH (NOLOCK)
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
      JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                        AND(PD.Sku = SKU.SKU)
      JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID = DPD.ChildID)
      WHERE LPD.Loadkey = @c_CLoadkey

      --WL01 S
      IF @c_MBOLCreateChildOrdChkPallet = '1'
      BEGIN
         -- GET New Load Info
         SELECT @n_LoadWeight   = SUM(PD.Qty * SKU.StdGrossWgt)
               ,@n_LoadCube     = SUM(PD.Qty * SKU.StdCube)
               ,@n_TotalPallets = COUNT(DISTINCT PD.ID)
         FROM LOADPLANDETAIL LPD  WITH (NOLOCK) 
         JOIN PICKDETAIL PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
         JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                           AND(PD.Sku = SKU.SKU)
         JOIN PALLET      P WITH (NOLOCK) ON (PD.ID = P.Palletkey)
         --JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON (PLTD.Palletkey = P.Palletkey)
         --JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID = DPD.ChildID)
         WHERE LPD.Loadkey = @c_CLoadkey
      END
      --WL01 E
      
      UPDATE LOADPLAN WITH (ROWLOCK)
      SET   Weight = @n_LoadWeight
        ,   Cube   = @n_LoadCube
        ,   PalletCnt = @n_TotalPallets
        ,   EditDate = GETDATE()
        ,   EditWho  = SUSER_NAME()
        ,   TrafficCop = NULL
      WHERE LoadKey = @c_CLoadKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80055
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update LoadPlan Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END
   ELSE
   BEGIN
      --INSERT NEW LOADPLANDETAIL
      SELECT @c_CLoadLineNumber = ISNULL(MAX(LoadLineNumber),'00000')
      FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE LoadKey = @c_CLoadKey

      SET @c_CLoadLineNumber = RIGHT('0000' + CONVERT(NVARCHAR(5), CAST(@c_CLoadLineNumber AS INT) + 1), 5)

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
          @c_CLoadKey,        @c_CLoadLineNumber,
          @c_COrderKey,       @c_Consigneekey,              --(Wan02)
          Priority,           OrderDate,
          DeliveryDate,       Type,
          Door,               Stop,
          Route,              DeliveryPlace,
          @n_TotWeight,       @n_TotCube,
          ExternOrderKey,     CustomerName,
          NoOfOrdLines,       CaseCnt,
          [STATUS]='5'
      FROM dbo.LoadPlanDetail WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80060
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Insert LOADPLANDETAIL Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   UPDATE ORDERDETAIL WITH (ROWLOCK)
   SET Loadkey = @c_CLoadkey
     , EditDate = GETDATE()
     , EditWho  = SUSER_NAME()
     , TrafficCop = NULL
   WHERE OrderKey = @c_COrderkey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 80065
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update OrdetailDetail Failed. (isp_ChildOrder_CreateMBOL)'
      GOTO QUIT_WITH_ERROR
   END


   IF EXISTS (SELECT 1
                  FROM MBOLDETAIL WITH (NOLOCK)
                  WHERE MBOLKey = @c_MBOLKey
                  AND   Orderkey= @c_COrderkey)
   BEGIN
      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET  Weight = @n_TotWeight
        ,  Cube   = @n_TotCube
        ,  TotalCartons = @n_TotalCartons
        ,  EditDate = GETDATE()
        ,  EditWho  = SUSER_NAME()
        ,  TrafficCop = NULL
         WHERE MBOLKey = @c_MBOLKey
         AND OrderKey  = @c_COrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80070
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update MBOLDetail Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END
   ELSE
   BEGIN
      SET @c_MbolLineNumber = ''

      SELECT @c_MbolLineNumber = ISNULL(MAX(MbolLineNumber),'')
      FROM MBOLDETAIL WITH (NOLOCK)
      WHERE MbolKey = @c_MBOLKey

      IF ISNULL(RTRIM(@c_MbolLineNumber),'') = ''
      BEGIN
         SET @c_MbolLineNumber = '00001'
      END
      ELSE
      BEGIN
         SET @c_MbolLineNumber = RIGHT('0000' + CONVERT(NVARCHAR(5), CAST(@c_MbolLineNumber AS INT) + 1), 5)
      END

      INSERT INTO MBOLDETAIL
      (
       MbolKey,          MbolLineNumber,      ContainerKey,        OrderKey,
       PalletKey,        [Description],       GrossWeight,         Capacity,
       InvoiceNo,        UPSINum,             PCMNum,              ExternReason,
       InvoiceStatus,    InvoiceAmount,       OfficialReceipt,
       ITS,              LoadKey,             [Weight],            [Cube],
       OrderDate,        ExternOrderKey,      DeliveryDate,        DeliveryStatus,
       TotalCartons,     UserDefine01,        UserDefine02,        UserDefine03,
       UserDefine04,     UserDefine05,        UserDefine06,        UserDefine07,
       UserDefine08,     UserDefine09,        UserDefine10,        CtnCnt1,
       CtnCnt2,          CtnCnt3,             CtnCnt4,             CtnCnt5,
       TrafficCop)
      SELECT
       @c_MBOLKey,        @c_MbolLineNumber,  '',                  @c_COrderKey,
       '',               '',                  0,                   0,
       '',               '',                  '',                  '0',
       '0',              0,                   '',
       '',               @c_CLoadKey,         @n_TotWeight,        @n_TotCube,
       OrderDate,        ExternOrderKey,      DeliveryDate,        '',
       @n_TotalCartons,  '',                  '',   '',
       '',               '',                  '',                  '',
       '',               '',                  '',                  0,
       0,                0,                   0,                   0,
       '1'
      FROM ORDERS O WITH (NOLOCK)
      WHERE OrderKey = @c_COrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80075
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT MBOLDETAIL Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   SET @n_MBOLWeight = 0.00
   SET @n_MBOLCube   = 0.00
   SELECT @n_MBOLWeight = SUM(Weight)
         ,@n_MBOLCube   = SUM(Cube)
   FROM MBOLDETAIL WITH (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey

   UPDATE MBOL WITH (ROWLOCK)
   SET  Weight = @n_MBOLWeight
     ,  Cube   = @n_MBOLCube
     ,  EditDate = GETDATE()
     ,  EditWho  = SUSER_NAME()
     ,  TrafficCop = NULL
   WHERE MBOLKey = @c_MBOLKey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 80080
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update MBOL  Failed. (isp_ChildOrder_CreateMBOL)'
      GOTO QUIT_WITH_ERROR
   END

   --WL01
   IF @c_MBOLCreateChildOrdChkPallet = '1'
   BEGIN
      UPDATE PALLETDETAIL WITH (ROWLOCK)
      SET UserDefine01 = @c_MBOLKey
        , EditDate = GETDATE() 
        , EditWho  = SUSER_NAME()     
        , TrafficCop = NULL 
      WHERE CaseID = @c_CaseID AND StorerKey = @c_Storerkey   --WL02
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80085
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PALLETDETAIL Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END
   ELSE
   BEGIN
      UPDATE DROPIDDETAIL WITH (ROWLOCK)
      SET UserDefine01 = @c_MBOLKey
        , EditDate = GETDATE()
        , EditWho  = SUSER_NAME()
        , TrafficCop = NULL
      WHERE ChildID = @c_CaseID

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80085
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update DROPIDDETAIL Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   --(Wan01) PickSlip , Packing Handling - START
   SET @c_CPickSlipNo = ''
   SELECT @c_CPickSlipNo = PickHeaderKey
   FROM PICKHEADER WITH (NOLOCK)
   WHERE ExternOrderKey = @c_CLoadKey
   AND    Zone = 'LP'

   IF @c_CPickSlipNo = ''
   BEGIN
      EXECUTE nspg_GetKey
         'PICKSLIP'
      ,  9
      ,  @c_CPickSlipNo OUTPUT
      ,  @b_Success    OUTPUT
      ,  @n_err        OUTPUT
      ,  @c_errmsg     OUTPUT

      IF NOT @b_Success = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80090
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Get Loadkey Fail. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      SET @c_CPickSlipNo = 'P' + @c_CPickSlipNo

      INSERT INTO PICKHEADER
               (  PickHeaderKey
               ,  Orderkey
               ,  ExternOrderkey
               ,  Loadkey
               ,  PickType
               ,  Zone
               ,  TrafficCop
               )
      VALUES
               (  @c_CPickSlipNo
               ,  ''
               ,  @c_CLoadkey
               ,  @c_CLoadkey
               ,  '0'
               ,  'LP'
               ,  ''
               )

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 80095
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Insert PICKHEADER Failed (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END
   END

   --Get Parent PickslipNo & CartonNo - START
   SELECT @c_PickSlipNo = PH.PickHeaderkey
   FROM ORDERS     OH WITH (NOLOCK)
   JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Userdefine09 = PH.Wavekey)
                                    AND(OH.Loadkey = PH.ExternOrderkey)
                                    AND(PH.Zone = 'LP')
   WHERE OH.Orderkey = @c_Orderkey

   SELECT @n_CartonNo = CartonNo
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND   LabelNo    = @c_CaseID
   --Get Parent PickslipNo & CartonNo - END

   SET @c_CPickSlipNoPrev = ''
   SET @c_SkuPrev = ''

   DECLARE CUR_CASESKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickdetailKey= PD.PickdetailKey
      ,   Sku = PD.Sku
   FROM PICKDETAIL  PD WITH (NOLOCK)
   WHERE  PD.PickSlipNo = @c_PickSlipNo
   AND    PD.OrderKey   = @c_COrderKey
   AND    PD.CaseID     = @c_CaseID
   ORDER BY PD.Sku

   OPEN CUR_CASESKU

   FETCH NEXT FROM CUR_CASESKU INTO @c_PickdetailKey
                                  , @c_Sku

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE REFKEYLOOKUP WITH (ROWLOCK)
      SET PickSlipNo = @c_CPickSlipNo
         ,Loadkey    = @c_CLoadKey
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
         ,ArchiveCop= NULL
      WHERE  PickdetailKey = @c_PickdetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 80100
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update RefKeyLookup Table Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET  PickSlipNo = @c_CPickSlipNo
          ,EditWho = SUSER_NAME()
          ,EditDate= GETDATE()
          ,TrafficCop = NULL
      WHERE  PickdetailKey = @c_PickdetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 80105
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': UPDATE Pickdetail Failed. (isp_ChildOrder_CreateMBOL)'
         GOTO QUIT_WITH_ERROR
      END

      IF @c_CPickSlipNoPrev <> @c_CPickSlipNo
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_CPickSlipNo)
         BEGIN
            INSERT INTO PICKINGINFO (PickSlipNo, ScanIndate, ScanOutdate, PickerID, Trafficcop)
            VALUES (@c_CPickSlipNo, GETDATE(), GETDATE(), SUSER_NAME(), 'U')

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 80110
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Insert PICKINGINFO Failed. (isp_ChildOrder_CreateMBOL)'
               GOTO QUIT_WITH_ERROR
            END
         END

         IF NOT EXISTS (SELECT 1 FROM PACKHEADER WITH (NOLOCK)
                        WHERE PickSlipNo = @c_CPickSlipNo)
         BEGIN
            INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, [Status])
            VALUES( @c_CPickSlipNo, @c_Storerkey, '', @c_CLoadkey, '9' )

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 80115
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Insert PACKHEADER Failed. (isp_ChildOrder_CreateMBOL)'
               GOTO QUIT_WITH_ERROR
            END
         END
      END

      IF @c_Sku <> @c_SkuPrev
      BEGIN
         --Get Child PickSlip CartonNo - START
         SET @n_CCartonNo = 0
         SELECT @n_CCartonNo = CartonNo
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @c_CPickSlipNo
         AND   LabelNo    = @c_CaseID

         IF @n_CCartonNo = 0
         BEGIN
            SELECT @n_CCartonNo = ISNULL(MAX(CartonNo),0)
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @c_CPickSlipNo

            SET @n_CCartonNo = @n_CCartonNo + 1
         END
         --Get Child PickSlip CartonNo - END

         INSERT INTO PACKDETAIL
               (  PickSlipNo
               ,  CartonNo
               ,  LabelNo
               ,  LabelLine
               ,  Storerkey
               ,  Sku
               ,  Qty
               ,  DropID
               ,  RefNo
               ,  RefNo2
              -- ,  UPC                                     --10-SEP-2014
               ,  AddDate                                   --10-SEP-2014
               )
         SELECT   @c_CPickSlipNo
               ,  @n_CCartonNo
               ,  LabelNo
               ,  LabelLine
               ,  Storerkey
               ,  Sku
               ,  Qty
               ,  DropID
               ,  RefNo
               ,  @c_PickSlipNo + CONVERT(VARCHAR(5), @n_CartonNo)
              -- ,  CONVERT( NVARCHAR(20), AddDate, 120)    --10-SEP-2014
               ,  AddDate                                   --10-SEP-2014
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND   LabelNo    = @c_CaseID
         AND   Sku        = @c_Sku

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 80120
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT PACKDETAIL Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END

         IF NOT EXISTS (SELECT 1 FROM PACKINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_CPickSlipNo
                        AND   CartonNo = @n_CCartonNo)
         BEGIN
            INSERT INTO PACKINFO
               (  PickSlipNo
               ,  CartonNo
               ,  Weight
               ,  [Cube]
               ,  Qty
               ,  CartonType
               ,  RefNo
               ,  TrackingNo              --(Wan02)  
               )
            SELECT @c_CPickSlipNo
               ,  @n_CCartonNo
               ,  Weight
               ,  [Cube]
               ,  Qty
               ,  CartonType
               ,  RefNo
               ,  TrackingNo              --(Wan02)  
            FROM PACKINFO WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo   = @n_CartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 80125
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': INSERT PACKINFO Failed. (isp_ChildOrder_CreateMBOL)'
               GOTO QUIT_WITH_ERROR
            END

            -- Delete Parent Packdetail - START
            DELETE PACKINFO WITH (ROWLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo   = @n_CartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 80130
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete PACKINFO Failed. (isp_ChildOrder_CreateMBOL)'
               GOTO QUIT_WITH_ERROR
            END
            -- Delete Parent Packdetail - END
         END
         -- Delete Parent Packdetail - START
         DELETE PACKDETAIL WITH (ROWLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND   LabelNo    = @c_CaseID
         AND   Sku        = @c_Sku

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 80135
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete PACKDETAIL Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END
         -- Delete Parent Packdetail - END

      END

      SET @c_CPickSlipNoPrev = @c_CPickSlipNo
      SET @c_SkuPrev = @c_Sku

      FETCH NEXT FROM CUR_CASESKU INTO @c_PickdetailKey
                                     , @c_Sku
   END
   CLOSE CUR_CASESKU
   DEALLOCATE CUR_CASESKU

   --(Wan01) PickSlip , Packing Handling - END

QUIT_NORMAL:

WHILE @@TRANCOUNT > 0
   COMMIT TRAN

GOTO QUIT


QUIT_WITH_ERROR:
SET @b_Success = 0

IF @@TRANCOUNT > 0
   ROLLBACK TRAN

--RAISERROR (N'SQL Error: %s ErrorNo: %d.',16, 1) WITH SETERROR    -- SQL2012
RAISERROR (N'SQL Error: %s',16, 1, @c_errmsg) WITH SETERROR    -- SQL2012, SOS365643
QUIT:

   IF CURSOR_STATUS('LOCAL' , 'CUR_CASE') in (0 , 1)
   BEGIN
      CLOSE CUR_CASE
      DEALLOCATE CUR_CASE
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_CASESKU') in (0 , 1)
   BEGIN
      CLOSE CUR_CASESKU
      DEALLOCATE CUR_CASESKU
   END

   WHILE @@TRANCOUNT < @n_StartTranCount
      BEGIN TRAN

   RETURN
END

GO