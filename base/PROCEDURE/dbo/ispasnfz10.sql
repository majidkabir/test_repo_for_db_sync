SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ10                                            */
/* Creation Date: 06-Mar-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-1261 - CN Logitech auto create order                       */
/*        : after finalize ASN                                             */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver  Purposes                                      */
/* 21-Jul-2017  NJOW01  1.0  WMS-2511 add B_Address1 mapping               */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length        */
/***************************************************************************/
CREATE PROC [dbo].[ispASNFZ10]
(     @c_Receiptkey  NVARCHAR(10)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''      
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT
         , @n_StartTranCount     INT

   DECLARE @c_DocType            NVARCHAR(1)
         , @c_OrderKey		       NVARCHAR(10)
         , @c_StorerKey		       NVARCHAR(15)
         , @c_Facility     	   	 NVARCHAR(10)
         , @c_ExternOrderkey     NVARCHAR(50)     --tlting_ext
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_ExternLineNo       NVARCHAR(20)
         , @c_Sku                NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @n_OriginalQty        INT
         , @n_OpenQty            INT
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_TariffKey          NVARCHAR(10)
         , @n_UnitPrice          FLOAT
         , @n_ExtRecCnt          INT

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = '0'
   SET @n_Continue = 1
   SET @n_StartTranCount = @@TRANCOUNT

   CREATE TABLE #TMP_ORD
      (  StorerKey          NVARCHAR(15)   NULL
      ,  ExternOrderKey     NVARCHAR(50)   NOT NULL   DEFAULT ('')
      ,  OrderDate          DATETIME       NULL       DEFAULT (GETDATE())
      ,  DeliveryDate       DATETIME       NULL       DEFAULT (GETDATE())
      ,  Priority           NVARCHAR(10)   NULL       DEFAULT ('5')
      ,  Consigneekey       NVARCHAR(15)   NULL       DEFAULT ('')
      ,  C_Contact1         NVARCHAR(30)   NULL
      ,  C_Contact2         NVARCHAR(30)   NULL
      ,  C_Company          NVARCHAR(45)   NULL
      ,  C_Address1         NVARCHAR(45)   NULL
      ,  C_Address2         NVARCHAR(45)   NULL
      ,  C_Address3         NVARCHAR(45)   NULL
      ,  C_Address4         NVARCHAR(45)   NULL
      ,  C_City             NVARCHAR(45)   NULL
      ,  C_State            NVARCHAR(45)   NULL
      ,  C_Zip              NVARCHAR(18)   NULL
      ,  C_Country          NVARCHAR(30)   NULL
      ,  C_ISOCntryCode     NVARCHAR(10)   NULL
      ,  C_Phone1           NVARCHAR(18)   NULL
      ,  C_Phone2           NVARCHAR(18)   NULL
      ,  C_Fax1             NVARCHAR(18)   NULL
      ,  C_Fax2             NVARCHAR(18)   NULL
      ,  C_Vat              NVARCHAR(18)   NULL
      ,  BuyerPO            NVARCHAR(20)   NULL
      ,  BillToKey          NVARCHAR(15)   NOT NULL  DEFAULT ('')
      ,  B_contact1         NVARCHAR(30)   NULL
      ,  B_Contact2         NVARCHAR(30)   NULL
      ,  B_Company          NVARCHAR(45)   NULL
      ,  B_Address1         NVARCHAR(45)   NULL
      ,  B_Address2         NVARCHAR(45)   NULL
      ,  B_Address3         NVARCHAR(45)   NULL
      ,  B_Address4         NVARCHAR(45)   NULL
      ,  B_City             NVARCHAR(45)   NULL
      ,  B_State            NVARCHAR(45)   NULL
      ,  B_Zip              NVARCHAR(18)   NULL
      ,  B_Country          NVARCHAR(30)   NULL
      ,  B_ISOCntryCode     NVARCHAR(10)   NULL
      ,  B_Phone1           NVARCHAR(18)   NULL
      ,  B_Phone2           NVARCHAR(18)   NULL
      ,  B_Fax1             NVARCHAR(18)   NULL
      ,  B_Fax2             NVARCHAR(18)   NULL
      ,  B_Vat              NVARCHAR(18)   NULL
      ,  IncoTerm           NVARCHAR(10)   NULL
      ,  PmtTerm            NVARCHAR(10)   NULL
      ,  OpenQty            INT            NULL       DEFAULT (0)
      ,  Status             NVARCHAR(10)   NULL       DEFAULT ('0')
      ,  DischargePlace     NVARCHAR(30)   NULL
      ,  DeliveryPlace      NVARCHAR(30)   NULL
      ,  IntermodalVehicle  NVARCHAR(30)   NOT NULL   DEFAULT ('')
      ,  CountryOfOrigin    NVARCHAR(30)   NULL
      ,  CountryDestination NVARCHAR(30)   NULL
      ,  UpdateSource       NVARCHAR(10)   NULL       DEFAULT ('0')
      ,  Type               NVARCHAR(10)   NOT NULL   DEFAULT ('0')
      ,  OrderGroup         NVARCHAR(20)   NULL       DEFAULT ('')
      ,  Door               NVARCHAR(10)   NULL       DEFAULT ('99')
      ,  Route              NVARCHAR(10)   NULL       DEFAULT ('99')
      ,  Stop               NVARCHAR(10)   NULL       DEFAULT ('99')
      ,  Notes              NVARCHAR(4000) NULL	
      ,  EffectiveDate      DATETIME       NULL       DEFAULT (GETDATE())
      ,  ContainerType      NVARCHAR(20)   NULL
      ,  ContainerQty       INT            NULL       DEFAULT (0)
      ,  BilledContainerQty INT            NULL       DEFAULT (0)
      ,  SOStatus           NVARCHAR(10)   NULL       DEFAULT ('0')
      ,  MBOLKey            NVARCHAR(10)   NULL       DEFAULT ('')
      ,  InvoiceNo          NVARCHAR(10)   NULL       DEFAULT ('')
      ,  InvoiceAmount      FLOAT          NULL       DEFAULT(0.00)
      ,  Salesman           NVARCHAR(30)   NULL       DEFAULT ('')
      ,  GrossWeight        FLOAT          NULL       DEFAULT(0.00)
      ,  Capacity           FLOAT          NULL       DEFAULT(0.00)
      ,  PrintFlag          NVARCHAR(1)    NULL       DEFAULT ('N')
      ,  LoadKey            NVARCHAR(10)   NULL       DEFAULT ('')
      ,  Rdd                NVARCHAR(30)   NULL       DEFAULT ('')
      ,  Notes2             NVARCHAR(4000) NULL	
      ,  SequenceNo         INT            NULL       DEFAULT (99999999)
      ,  Rds                NVARCHAR(1)    NULL       DEFAULT ('N')
      ,  SectionKey         NVARCHAR(10)   NULL
      ,  Facility           NVARCHAR(5)    NULL
      ,  PrintDocDate       DATETIME       NULL
      ,  LabelPrice         NVARCHAR(5)    NULL
      ,  POKey              NVARCHAR(10)   NULL       DEFAULT ('')
      ,  ExternPOKey        NVARCHAR(20)   NULL       DEFAULT ('')
      ,  XDockFlag          NVARCHAR(1)    NULL       DEFAULT ('0')
      ,  UserDefine01       NVARCHAR(20)   NULL       DEFAULT ('')
      ,  UserDefine02       NVARCHAR(20)   NULL       DEFAULT ('')
      ,  UserDefine03       NVARCHAR(20)   NULL       DEFAULT ('')
      ,  UserDefine04       NVARCHAR(20)   NULL       DEFAULT ('')
      ,  UserDefine05       NVARCHAR(20)   NULL       DEFAULT ('')
      ,  UserDefine06       DATETIME       NULL
      ,  UserDefine07       DATETIME       NULL
      ,  UserDefine08       NVARCHAR(10)   NULL       DEFAULT ('N')
      ,  UserDefine09       NVARCHAR(10)   NULL       DEFAULT ('')
      ,  UserDefine10       NVARCHAR(10)   NULL       DEFAULT ('')
      ,  Issued             NVARCHAR(1 )   NULL       DEFAULT ('Y')
      ,  DeliveryNote       NVARCHAR(10)   NULL
      ,  PODCust            DATETIME       NULL
      ,  PODArrive          DATETIME       NULL
      ,  PODReject          DATETIME       NULL
      ,  PODUser            NVARCHAR(18)   NULL       DEFAULT ('')
      ,  XDOCKPOKEY         NVARCHAR(20)   NULL
      ,  SpecialHandling    NVARCHAR(1)    NULL       DEFAULT ('N')
      ,  RoutingTool        NVARCHAR(30)   NULL
      ,  MarkforKey         NVARCHAR(15)   NULL       DEFAULT ('')
      ,  M_Contact1         NVARCHAR(30)   NULL
      ,  M_Contact2         NVARCHAR(30)   NULL
      ,  M_Company          NVARCHAR(45)   NULL
      ,  M_Address1         NVARCHAR(45)   NULL
      ,  M_Address2         NVARCHAR(45)   NULL
      ,  M_Address3         NVARCHAR(45)   NULL
      ,  M_Address4         NVARCHAR(45)   NULL
      ,  M_City             NVARCHAR(45)   NULL
      ,  M_State            NVARCHAR(45)   NULL
      ,  M_Zip              NVARCHAR(18)   NULL
      ,  M_Country          NVARCHAR(30)   NULL
      ,  M_ISOCntryCode     NVARCHAR(10)   NULL
      ,  M_Phone1           NVARCHAR(18)   NULL
      ,  M_Phone2           NVARCHAR(18)   NULL
      ,  M_Fax1             NVARCHAR(18)   NULL
      ,  M_Fax2             NVARCHAR(18)   NULL
      ,  M_Vat              NVARCHAR(18)   NULL
      ,  ShipperKey         NVARCHAR(15)   NULL       DEFAULT ('')
      )

   CREATE TABLE #TMP_ORDDTL
      (  OrderLineNumber   NVARCHAR(5)    NULL
      ,  ExternOrderkey    NVARCHAR(50)   NULL
      ,  ExternLineNo      NVARCHAR(20)   NULL
      ,  Storerkey         NVARCHAR(15)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Packkey           NVARCHAR(10)   NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  OriginalQty       INT            DEFAULT(0)
      ,  OpenQty           INT            DEFAULT(0)
      ,  Facility          NVARCHAR(5)    NULL
      ,  UnitPrice         FLOAT          DEFAULT(0)
      ,  Lot               NVARCHAR(10)   NULL
      ,  Lottable01        NVARCHAR(18)   NULL
      ,  Lottable02        NVARCHAR(18)   NULL
      ,  Lottable03        NVARCHAR(18)   NULL
      ,  Lottable04        DATETIME       NULL
      ,  Lottable05        DATETIME       NULL
      ,  Lottable08        NVARCHAR(30)   NULL      
      ,  Lottable11        NVARCHAR(30)   NULL            
      )

   SET @n_Cnt = 0
   SELECT @c_Storerkey      = RECEIPT.Storerkey
         ,@c_Facility       = RECEIPT.Facility
         ,@c_DocType        = RECEIPT.DocType
         ,@n_Cnt            = 1
   FROM RECEIPT WITH (NOLOCK)
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey

   IF @n_Cnt = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
           
   IF @c_DocType = 'R'
   BEGIN
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS(SELECT 1 
                 FROM RECEIPTDETAIL RD (NOLOCK)
                 JOIN PODETAIL POD (NOLOCK) ON RD.Pokey = POD.POKey AND RD.POLineNumber = POD.POLineNumber
                 WHERE POD.Facility <> @c_Facility
                 AND RD.Receiptkey = @c_Receiptkey)
   BEGIN
      GOTO QUIT_SP
   END
      
   --Construct order records
   IF @n_continue IN(1,2)
   BEGIN      	 
      INSERT INTO #TMP_ORDDTL
            (  OrderLineNumber
            ,  ExternOrderkey
            ,  ExternLineNo
            ,  Storerkey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  OriginalQty
            ,  OpenQty
            ,  Facility
            ,  UnitPrice
            ,  Lottable02
            ,  Lottable08
            ,  Lottable11
            )
      SELECT   RD.ReceiptLineNumber
            ,  RD.ExternReceiptkey
            ,  RD.ExternLineNo
            ,  RD.Storerkey
            ,  RD.Sku
            ,  RD.Packkey
            ,  RD.UOM
            ,  RD.QtyReceived
            ,  RD.QtyReceived
            ,  RH.Facility
            ,  POD.UnitPrice
            ,  RD.Lottable02
            ,  RD.Lottable08
            ,  RD.Lottable11
      FROM  RECEIPT RH WITH (NOLOCK)
      JOIN  RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)
      JOIN  PODETAIL POD WITH (NOLOCK) ON (RD.Pokey = POD.Pokey AND RD.POLineNumber = POD.POLineNumber)
      WHERE RH.ReceiptKey = @c_Receiptkey
      AND RD.QtyReceived > 0
   
      IF NOT EXISTS (SELECT 1
                     FROM #TMP_ORDDTL)
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
      
      SELECT @n_ExtRecCnt = COUNT(DISTINCT ExternReceiptkey)
      FROM RECEIPTDETAIL (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey
            
      INSERT INTO #TMP_ORD
      ( Storerkey
      ,  Type
      ,  ExternOrderkey
      ,  Consigneekey
      ,  C_Contact1
      ,  C_Contact2
      ,  C_Company
      ,  C_Address1
      ,  C_Address2
      ,  C_Address3
      ,  C_Address4
      ,  C_City
      ,  C_State
      ,  C_Zip
      ,  C_Country
      ,  C_ISOCntryCode
      ,  C_Phone1
      ,  C_Phone2
      ,  C_Fax1
      ,  C_Fax2
      ,  C_Vat
      ,  Facility
      ,  UserDefine06
      ,  Billtokey    
      ,  B_Contact1   
      ,  B_Company   
      ,  B_Address1  --NJOW01
      ,  UserDefine02   
      ,  Userdefine07  
      ,  Userdefine01  
      )
      SELECT
         @c_Storerkey
      ,  'LOGIUT'   
      ,  ExternOrderkey = CASE WHEN @n_ExtRecCnt > 1 THEN RECEIPT.Receiptkey ELSE ISNULL(RECEIPT.ExternReceiptkey,'') END
      ,  Consigneekey   = ISNULL(PO.Facility,'')
      ,  C_Contact1     = ''
      ,  C_Contact2     = ''
      ,  C_Company      = ''
      ,  C_Address1     = ''
      ,  C_Address2     = ''
      ,  C_Address3     = ''
      ,  C_Address4     = ''
      ,  C_City         = ''
      ,  C_State        = ''
      ,  C_Zip          = ''
      ,  C_Country      = ''
      ,  C_ISOCntryCode = ''
      ,  C_Phone1       = ''
      ,  C_Phone2       = ''
      ,  C_Fax1         = ''
      ,  C_Fax2         = '' 
      ,  C_Vat          = ''
      ,  Facility       = RECEIPT.Facility
      ,  UserDefine06   = PO.PODate
      ,  Billtokey      = PO.SellersReference
      ,  B_Contact1     = PO.OtherReference
      ,  B_Company      = PO.SellerName
      ,  B_Address1     = PO.SellerAddress1 --NJOW01
      ,  UserDefine02   = PO.POType
      ,  Userdefine07   = PO.LoadingDate
      ,  Userdefine01   = PO.Userdefine01
      FROM RECEIPT        WITH (NOLOCK)
      JOIN (SELECT TOP 1 RD.Receiptkey, PO.PODate, PO.SellersReference, PO.OtherReference,
                         PO.SellerName, PO.POType, PO.LoadingDate, PO.Userdefine01, POD.Facility, PO.SellerAddress1
            FROM PO (NOLOCK)
            JOIN PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
            JOIN RECEIPTDETAIL RD (NOLOCK) ON POD.POKey = RD.POKey AND POD.POLineNumber = RD.POLineNumber
            WHERE RD.Receiptkey = @c_Receiptkey) PO ON PO.Receiptkey = RECEIPT.Receiptkey
      WHERE RECEIPT.ReceiptKey = @c_Receiptkey
   
      IF @@ROWCOUNT = 0
      BEGIN
         GOTO QUIT_SP
      END
   END
   
   --Insert order to DB
   IF @n_continue IN(1,2)
   BEGIN
      EXECUTE nspg_GetKey
         'ORDER'
        , 10
        , @c_Orderkey   OUTPUT
        , @b_Success    OUTPUT
        , @n_Err        OUTPUT
        , @c_ErrMsg     OUTPUT
      
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
      
      INSERT INTO ORDERS
      (  OrderKey
      ,  StorerKey
      ,  ExternOrderKey
      ,  OrderDate
      ,  DeliveryDate
      ,  Priority
      ,  ConsigneeKey
      ,  C_contact1
      ,  C_Contact2
      ,  C_Company
      ,  C_Address1
      ,  C_Address2
      ,  C_Address3
      ,  C_Address4
      ,  C_City
      ,  C_State
      ,  C_Zip
      ,  C_Country
      ,  C_ISOCntryCode
      ,  C_Phone1
      ,  C_Phone2
      ,  C_Fax1
      ,  C_Fax2
      ,  C_Vat
      ,  BuyerPO
      ,  BillToKey
      ,  B_contact1
      ,  B_Contact2
      ,  B_Company
      ,  B_Address1
      ,  B_Address2
      ,  B_Address3
      ,  B_Address4
      ,  B_City
      ,  B_State
      ,  B_Zip
      ,  B_Country
      ,  B_ISOCntryCode
      ,  B_Phone1
      ,  B_Phone2
      ,  B_Fax1
      ,  B_Fax2
      ,  B_Vat
      ,  IncoTerm
      ,  PmtTerm
      ,  OpenQty
      ,  Status
      ,  DischargePlace
      ,  DeliveryPlace
      ,  IntermodalVehicle
      ,  CountryOfOrigin
      ,  CountryDestination
      ,  UpdateSource
      ,  Type
      ,  OrderGroup
      ,  Door
      ,  Route
      ,  Stop
      ,  Notes
      ,  EffectiveDate
      ,  ContainerType
      ,  ContainerQty
      ,  BilledContainerQty
      ,  SOStatus
      ,  MBOLKey
      ,  InvoiceNo
      ,  InvoiceAmount
      ,  Salesman
      ,  GrossWeight
      ,  Capacity
      ,  PrintFlag
      ,  LoadKey
      ,  Rdd
      ,  Notes2
      ,  SequenceNo
      ,  Rds
      ,  SectionKey
      ,  Facility
      ,  PrintDocDate
      ,  LabelPrice
      ,  POKey
      ,  ExternPOKey
      ,  XDockFlag
      ,  UserDefine01
      ,  UserDefine02
      ,  UserDefine03
      ,  UserDefine04
      ,  UserDefine05
      ,  UserDefine06
      ,  UserDefine07
      ,  UserDefine08
      ,  UserDefine09
      ,  UserDefine10
      ,  Issued
      ,  DeliveryNote
      ,  PODCust
      ,  PODArrive
      ,  PODReject
      ,  PODUser
      ,  xdockpokey
      ,  SpecialHandling
      ,  RoutingTool
      ,  MarkforKey
      ,  M_Contact1
      ,  M_Contact2
      ,  M_Company
      ,  M_Address1
      ,  M_Address2
      ,  M_Address3
      ,  M_Address4
      ,  M_City
      ,  M_State
      ,  M_Zip
      ,  M_Country
      ,  M_ISOCntryCode
      ,  M_Phone1
      ,  M_Phone2
      ,  M_Fax1
      ,  M_Fax2
      ,  M_vat
      ,  ShipperKey
      )
       SELECT
         @c_OrderKey
      ,  StorerKey
      ,  ExternOrderKey
      ,  OrderDate
      ,  DeliveryDate
      ,  Priority
      ,  Consigneekey
      ,  C_contact1
      ,  C_Contact2
      ,  C_Company
      ,  C_Address1
      ,  C_Address2
      ,  C_Address3
      ,  C_Address4
      ,  C_City
      ,  C_State
      ,  C_Zip
      ,  C_Country
      ,  C_ISOCntryCode
      ,  C_Phone1
      ,  C_Phone2
      ,  C_Fax1
      ,  C_Fax2
      ,  C_vat
      ,  BuyerPO
      ,  BillToKey
      ,  B_contact1
      ,  B_Contact2
      ,  B_Company
      ,  B_Address1
      ,  B_Address2
      ,  B_Address3
      ,  B_Address4
      ,  B_City
      ,  B_State
      ,  B_Zip
      ,  B_Country
      ,  B_ISOCntryCode
      ,  B_Phone1
      ,  B_Phone2
      ,  B_Fax1
      ,  B_Fax2
      ,  B_Vat
      ,  IncoTerm
      ,  PmtTerm
      ,  OpenQty
      ,  Status
      ,  DischargePlace
      ,  DeliveryPlace
      ,  IntermodalVehicle
      ,  CountryOfOrigin
      ,  CountryDestination
      ,  UpdateSource
      ,  Type
      ,  OrderGroup
      ,  Door
      ,  Route
      ,  Stop
      ,  Notes
      ,  EffectiveDate
      ,  ContainerType
      ,  ContainerQty
      ,  BilledContainerQty
      ,  SOStatus
      ,  MBOLKey
      ,  InvoiceNo
      ,  InvoiceAmount
      ,  Salesman
      ,  GrossWeight
      ,  Capacity
      ,  PrintFlag
      ,  LoadKey
      ,  Rdd
      ,  Notes2
      ,  SequenceNo
      ,  Rds
      ,  SectionKey
      ,  Facility
      ,  PrintDocDate
      ,  LabelPrice
      ,  POKey
      ,  ExternPOKey
      ,  XDockFlag
      ,  UserDefine01
      ,  UserDefine02
      ,  UserDefine03
      ,  UserDefine04
      ,  UserDefine05
      ,  UserDefine06
      ,  UserDefine07
      ,  UserDefine08
      ,  UserDefine09
      ,  UserDefine10
      ,  Issued
      ,  DeliveryNote
      ,  PODCust
      ,  PODArrive
      ,  PODReject
      ,  PODUser
      ,  XDOCKPOKEY
      ,  SpecialHandling
      ,  RoutingTool
      ,  MarkforKey
      ,  M_Contact1
      ,  M_Contact2
      ,  M_Company
      ,  M_Address1
      ,  M_Address2
      ,  M_Address3
      ,  M_Address4
      ,  M_City
      ,  M_State
      ,  M_Zip
      ,  M_Country
      ,  M_ISOCntryCode
      ,  M_Phone1
      ,  M_Phone2
      ,  M_Fax1
      ,  M_Fax2
      ,  M_vat
      ,  ShipperKey
      FROM #TMP_ORD
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg = 'INSERT INTO ORDERS Table Failed'
         GOTO QUIT_SP
      END
      
      DECLARE CUR_ORDDTL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
            ,ExternOrderkey
            ,ExternLineNo
            ,Storerkey
            ,Sku
            ,Packkey
            ,UOM
            ,OriginalQty
            ,OpenQty
            ,Lottable02
            ,Lottable08
            ,Lottable11
            ,UnitPrice
      FROM #TMP_ORDDTL
      ORDER BY OrderLineNumber
            ,  ExternLineNo
            ,  Sku
      
      OPEN CUR_ORDDTL
      
      FETCH NEXT FROM CUR_ORDDTL INTO @c_OrderLineNumber
                                    , @c_ExternOrderKey
                                    , @c_ExternLineNo
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @c_Packkey
                                    , @c_UOM
                                    , @n_OriginalQty
                                    , @n_OpenQty
                                    , @c_Lottable02
                                    , @c_Lottable08
                                    , @c_Lottable11
                                    , @n_UnitPrice
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_OrderLineNumber = ''
         BEGIN
            SELECT @c_OrderLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5),ISNULL(MAX(OrderLineNumber)+1,1)),5)
            FROM ORDERDETAIL WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey
         END
      
         SELECT TOP 1 @c_Facility = Facility
         FROM #TMP_ORD
      
         SET @c_Tariffkey = ''
         SELECT @c_Tariffkey = Tariffkey
         FROM TARIFFxFACILITY WITH (NOLOCK)
         WHERE Facility  = @c_Facility
         AND   Storerkey = @c_Storerkey
         AND   Sku       = @c_Sku
      
         IF @c_Tariffkey = ''
         BEGIN
            SELECT @c_Tariffkey = Tariffkey
            FROM SKU WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND   Sku       = @c_Sku
         END
      
         INSERT INTO ORDERDETAIL
            (  Orderkey
            ,  OrderLineNumber
            ,  ExternOrderKey
            ,  ExternLineNo
            ,  Storerkey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  OriginalQty
            ,  OpenQty
            ,  Lottable02
            ,  Lottable08
            ,  Lottable11
            ,  Tariffkey
            ,  Facility
            ,  UnitPrice
            )
         VALUES
            (  @c_Orderkey
            ,  @c_OrderLineNumber
            ,  @c_ExternOrderKey
            ,  @c_ExternLineNo
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @c_Packkey
            ,  @c_UOM
            ,  @n_OriginalQty
            ,  @n_OpenQty
            ,  @c_Lottable02
            ,  @c_Lottable08
            ,  @c_Lottable11
            ,  @c_Tariffkey
            ,  @c_Facility
            ,  @n_UnitPrice
            )
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'INSERT INTO ORDERDETAIL Table Failed'
            GOTO QUIT_SP
         END
      
         FETCH NEXT FROM CUR_ORDDTL INTO @c_OrderLineNumber
                                       , @c_ExternOrderKey
                                       , @c_ExternLineNo
                                       , @c_Storerkey
                                       , @c_Sku
                                       , @c_Packkey
                                       , @c_UOM
                                       , @n_OriginalQty
                                       , @n_OpenQty
                                       , @c_Lottable02
                                       , @c_Lottable08
                                       , @c_Lottable11                                       
                                       , @n_UnitPrice
      END
      CLOSE CUR_ORDDTL
      DEALLOCATE CUR_ORDDTL           
   END   

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_ORDDTL') in (0 , 1)
   BEGIN
      CLOSE CUR_ORDDTL
      DEALLOCATE CUR_ORDDTL
   END
      
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      --EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ10'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      RETURN
   END
END

GO