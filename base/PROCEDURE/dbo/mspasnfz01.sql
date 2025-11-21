SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: mspASNFZ01                                            */
/* Creation Date: 2024-07-15                                               */
/* Copyright: Maersk                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: UWP-18703-XDOCKCreateSO                                        */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: V2                                                             */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 2024-07-15  SSA      1.0   Created.                                     */
/* 2024-07-17  SSA01    1.1   Added OB staging location filtering while    */
/*                            creating XDOCKSO and ADDED facility filtering*/
/*                            while fetching details from XDOCX ASN.       */
/* 2024-07-17  SSA02    1.2   Updated @n_Batch with default value(1) while */
/*                                                  creating orderkey      */
/* 2024-07-17  SSA03    1.3   Updated size for the  @c_ExternReceiptkey    */
/*                            ,added lottable03 mapping and added step for */
/*                            XDOCK ASN allocation                         */
/* 2024-07-17  SSA04    1.4   Added @c_ExternPOKey in orders , orderdetail */
/*                            for ASN auto allocation,substring            */
/*                            sellerrefernce value to pass 15 characters   */
/*                            to storre into BillToKey                     */
/* 2024-08-23  Wan01    1.5   UWP-23194- XDock and Delayed XDock Allocation*/
/*                            control                                      */
/* 2024-08-13  SSA06    1.6   Added ORDERDETAIL.ID = RECEIPTDETAIL.TOID    */
/*                            mapping                                      */
/* 2025-03-03  SSA07    1.7   UWP-30752 - seller order naming convention   */
/***************************************************************************/
CREATE   PROC [dbo].[mspASNFZ01]
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

   DECLARE @b_Debug              INT   = 0
         , @n_Cnt                INT   = 0
         , @n_Continue           INT   = 1
         , @n_StartTranCount     INT   = @@TRANCOUNT

   DECLARE @n_OrderCnt           INT            = 0
         , @c_ASNStatus          NVARCHAR(10)   = '0'
         , @c_DocType            NVARCHAR(1)    = ''
         , @c_OrderKey           NVARCHAR(10)   = ''
         , @c_StorerKey          NVARCHAR(15)   = ''
         , @c_Facility           NVARCHAR(10)   = ''
         , @c_ExternOrderkey     NVARCHAR(50)   = ''
         , @c_RecType            NVARCHAR(10)   = ''                      --(Wan01)
         , @c_OrderLineNumber    NVARCHAR(5)    = ''
         , @c_ExternLineNo       NVARCHAR(20)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_Packkey            NVARCHAR(10)   = ''
         , @c_UOM                NVARCHAR(10)   = ''
         , @n_OriginalQty        INT            = 0
         , @n_OpenQty            INT            = 0
         , @c_Lottable02         NVARCHAR(18)   = ''
         , @c_Lottable08         NVARCHAR(30)   = ''
         , @c_Lottable11         NVARCHAR(30)   = ''
         , @c_TariffKey          NVARCHAR(10)   = ''
         , @c_Lottable03         NVARCHAR(18)   = ''
         , @c_POKey              NVARCHAR(10)   = ''
         , @c_POLineNumber       NVARCHAR(10)   = ''
         , @c_ExternReceiptkey   NVARCHAR(50)   = ''           --(SSA03)
         , @c_Consigneekey       NVARCHAR(15)  = ''            --(SSA03)
         , @c_DeliveryDate       DATETIME
         , @c_Door               NVARCHAR(10)  = ''
         , @c_ExternPOKey        NVARCHAR(20)  = ''            --(SSA04)
         , @c_Id                 NVARCHAR(36)                  --(SSA06)
         , @CUR_RECDET           CURSOR

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''

   CREATE TABLE #TMP_ORD
      (  RowID              INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  Orderkey           NVARCHAR(10)   NOT NULL   DEFAULT('')
      ,  Receiptkey         NVARCHAR(10)   NOT NULL   DEFAULT('')
      ,  StorerKey          NVARCHAR(15)   NULL
      ,  ExternOrderKey     NVARCHAR(50)   NOT NULL   DEFAULT ('')
      ,  OrderDate          DATETIME       NULL       DEFAULT (GETDATE())
      ,  DeliveryDate       DATETIME       NULL       DEFAULT (GETDATE())
      ,  [Priority]         NVARCHAR(10)   NULL       DEFAULT ('5')
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
      ,  [Status]           NVARCHAR(10)   NULL       DEFAULT ('0')
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
      (  Orderkey          NVARCHAR(10)   NOT NULL   DEFAULT('')     -- (SSA01)
	    ,  Receiptkey        NVARCHAR(10)   NOT NULL
      ,  POkey             NVARCHAR(10)   NULL
      ,  POLineNumber      NVARCHAR(10)   NULL
      ,  ExternOrderkey    NVARCHAR(50)   NULL
      ,  ExternLineNo      NVARCHAR(20)   NULL
      ,  Storerkey         NVARCHAR(15)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Packkey           NVARCHAR(10)   NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  OriginalQty       INT            DEFAULT(0)
      ,  OpenQty           INT            DEFAULT(0)
      ,  UnitPrice         FLOAT          DEFAULT(0)
      ,  Lot               NVARCHAR(10)   NULL
      ,  Lottable01        NVARCHAR(18)   NULL
      ,  Lottable02        NVARCHAR(18)   NULL
      ,  Lottable03        NVARCHAR(18)   NULL
      ,  Lottable04        DATETIME       NULL
      ,  Lottable05        DATETIME       NULL
      ,  Lottable08        NVARCHAR(30)   NULL
      ,  Lottable11        NVARCHAR(30)   NULL
      ,  Userdefine02      NVARCHAR(18)   NULL  DEFAULT('')    --(SSA03)
      ,  UserDefine06      DATETIME       NULL
      ,  PutawayLoc        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExternPOKey       NVARCHAR(20)   NULL  DEFAULT('')
      ,  ID                NVARCHAR(36)   NULL                 --(SSA06)
      )

   SET @n_Cnt = 0
   SELECT @c_Storerkey      = RECEIPT.Storerkey
         ,@c_Facility       = RECEIPT.Facility
         ,@c_DocType        = RECEIPT.DocType
         ,@n_Cnt            = 1
         ,@c_ASNStatus      = RECEIPT.ASNStatus
         ,@c_RecType        = RECEIPT.RECType                  --(Wan01)
   FROM RECEIPT WITH (NOLOCK)
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey

   IF @n_Cnt = 0
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_ReceiptLineNumber <> '' AND @c_ASNStatus <> '9'
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_DocType <> 'X'
   BEGIN
      GOTO QUIT_SP
   END

   IF NOT EXISTS( SELECT 1
                  FROM RECEIPTDETAIL RD (NOLOCK)
                  JOIN PODETAIL POD (NOLOCK) ON RD.Pokey = POD.POKey AND RD.POLineNumber = POD.POLineNumber
                  WHERE POD.Facility = @c_Facility
                  AND RD.Receiptkey = @c_Receiptkey)
   BEGIN
      GOTO QUIT_SP
   END
   --Construct order records
   IF @n_continue IN(1,2)
   BEGIN
      --creating cursor for receiptdetail
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.ReceiptKey
            ,  ISNULL(RD.POKey,'')
            ,  ISNULL(RD.POLineNumber,'')
            ,  RD.ExternReceiptkey
            ,  RD.ExternLineNo
            ,  RD.Storerkey
            ,  RD.Sku
            ,  RD.Packkey
            ,  RD.UOM
            ,  RD.QtyReceived
            ,  RD.QtyReceived
            ,  RD.Lottable03                                   -- (SSA03)
            ,  RD.Lottable02
            ,  RD.Lottable08
            ,  RD.Lottable11
            ,  Consigneekey = ISNULL(RD.Userdefine02,'')
            ,  DeliveryDate = ISNULL(RD.UserDefine06,'1900-01-01')
            ,  Door         = ISNULL(RD.PutawayLoc  ,'')
            ,  RD.ExternPOKey                                  --(SSA04)
            ,  RD.ToId                                         --(SSA06)
         FROM  RECEIPT RH WITH (NOLOCK)
         JOIN  RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)
         JOIN  PODETAIL POD WITH (NOLOCK) ON (RD.Pokey = POD.Pokey)
                                          AND (RD.POLineNumber = POD.POLineNumber)
                                          AND (RH.FACILITY = POD.FACILITY)              --(SSA01)
         WHERE RH.ReceiptKey = @c_Receiptkey
         AND RD.QtyExpected > 0
         ORDER BY ISNULL(RD.Userdefine02,'')
               ,  ISNULL(RD.UserDefine06,'1900-01-01')
               ,  ISNULL(RD.PutawayLoc  ,'')
               ,  RD.ReceiptLineNumber

         OPEN CUR_RECDET

         FETCH NEXT FROM CUR_RECDET INTO @c_Receiptkey, @c_POKey, @c_POLineNumber, @c_ExternReceiptkey,@c_ExternLineNo,@c_Storerkey,
         @c_Sku, @c_Packkey, @c_UOM, @n_OriginalQty,@n_OpenQty,@c_Lottable03,@c_Lottable02, @c_Lottable08, @c_Lottable11, @c_Consigneekey,    -- (SSA03)
         @c_DeliveryDate,@c_Door,@c_ExternPOKey,@c_Id                                                                                         -- (SSA04),(SSA06)

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN
            ---- (SSA01) start -----
            IF EXISTS (SELECT 1
                     FROM #TMP_ORD WHERE Consigneekey = @c_Consigneekey and DeliveryDate = @c_DeliveryDate and Door = @c_Door)
            BEGIN
			        SELECT @c_Orderkey = orderkey
			        FROM #TMP_ORD WHERE Consigneekey = @c_Consigneekey and DeliveryDate = @c_DeliveryDate and Door = @c_Door
            END
            ELSE
            BEGIN
               SET @c_Orderkey = ''
               EXECUTE nspg_GetKey
               @KeyName = 'ORDER'
               , @fieldlength = 10
               , @keystring = @c_Orderkey   OUTPUT
               , @b_Success = @b_Success    OUTPUT
               , @n_Err     = @n_Err        OUTPUT
               , @c_ErrMsg  = @c_ErrMsg     OUTPUT
               , @n_Batch   = 1                                  --(SSA02)

               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO QUIT_SP
               END

               INSERT INTO #TMP_ORD
               (  OrderKey
               ,  Storerkey
               ,  Type
               ,  Door
               ,  DeliveryDate
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
               ,  Billtokey
               ,  B_Contact1
               ,  B_Company
               ,  B_Address1
               ,  Userdefine01
               ,  UserDefine02
               ,  Userdefine06
               ,  Userdefine07
               ,  ExternPOKey
               )
               SELECT
                  @c_Orderkey
               ,  @c_Storerkey
               ,  'XDOCK'
               ,  Door           = @c_Door
               ,  DeliveryDate   = @c_DeliveryDate
               ,  ExternOrderkey = @c_ExternReceiptkey
               ,  Consigneekey   = @c_Consigneekey
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
               ,  Facility       = @c_Facility
               ,  Billtokey      = SubString(PO.SellersReference,0,15)                               --(SSA04)
               ,  B_Contact1     = PO.OtherReference
               ,  B_Company      = PO.SellerName
               ,  B_Address1     = PO.SellerAddress1
               ,  Userdefine01   = PO.Userdefine01
               ,  UserDefine02   = PO.POType
               ,  UserDefine06   = PO.PODate
               ,  Userdefine07   = PO.LoadingDate
               ,  ExternPOKey    = @c_ExternPOKey                                                    --(SSA04)
               FROM  PO  (NOLOCK)
               WHERE PO.Pokey = @c_POKey
           END
		        INSERT INTO #TMP_ORDDTL
            (  OrderKey
			      ,  ReceiptKey
            ,  POKey
            ,  POLineNumber
            ,  ExternOrderkey
            ,  ExternLineNo
            ,  Storerkey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  OriginalQty
            ,  OpenQty
            ,  Lottable03
            ,  Lottable02
            ,  Lottable08
            ,  Lottable11
            ,  Userdefine02
            ,  UserDefine06
            ,  PutawayLoc
            ,  ExternPOKey
            ,  ID                                                                                                                    -- (SSA04),(SSA06)
            ) values (@c_Orderkey,@c_Receiptkey, @c_POKey, @c_POLineNumber, @c_ExternReceiptkey,@c_ExternLineNo,@c_Storerkey,
            @c_Sku, @c_Packkey, @c_UOM, @n_OriginalQty,@n_OpenQty,@c_Lottable03,@c_Lottable02, @c_Lottable08, @c_Lottable11,                      -- (SSA03)
            @c_Consigneekey,@c_DeliveryDate,@c_Door,@c_ExternPOKey,@c_Id)                                                                         -- (SSA04),(SSA06)

            FETCH NEXT FROM CUR_RECDET INTO @c_Receiptkey, @c_POKey, @c_POLineNumber, @c_ExternReceiptkey,@c_ExternLineNo,@c_Storerkey,
            @c_Sku, @c_Packkey, @c_UOM, @n_OriginalQty,@n_OpenQty,@c_Lottable03,@c_Lottable02, @c_Lottable08, @c_Lottable11, @c_Consigneekey,     -- (SSA03)
            @c_DeliveryDate,@c_Door,@c_ExternPOKey,@c_Id                                                                                          -- (SSA04),(SSA06)
         -- (SSA01) end ---
         END
         CLOSE CUR_RECDET
         DEALLOCATE CUR_RECDET
         --Updating externorderkey in the orders table
         --(SSA07) start--
         SELECT @n_OrderCnt = COUNT(DISTINCT ExternOrderkey) FROM #TMP_ORD
         IF @n_OrderCnt > 1
         BEGIN
            UPDATE #TMP_ORD set ExternOrderkey = @c_Receiptkey
         END
         --(SSA07) end--
         IF NOT EXISTS (SELECT 1
                     FROM #TMP_ORD)
         BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
         END
   END

   --Insert order to DB
   IF @n_continue IN(1,2)
   BEGIN

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
         Orderkey
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
      ,  [Status]
      ,  DischargePlace
      ,  DeliveryPlace
      ,  IntermodalVehicle
      ,  CountryOfOrigin
      ,  CountryDestination
      ,  UpdateSource
      ,  [Type]
      ,  OrderGroup
      ,  Door
      ,  [Route]
      ,  [Stop]
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
      ORDER BY RowID

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68010
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),@n_Err)
                       + ': INSERT INTO ORDERS Table Failed. (mspASNFZ01)'
         GOTO QUIT_SP
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
            ,  Lottable03                                                           -- (SSA03)
            ,  ExternPOKey                                                          -- (SSA04)
            ,  ID                                                                   -- (SSA06)
            )
      SELECT td.Orderkey                                                            -- (SSA01)
            ,OrderLineNumber =  RIGHT('00000' + CONVERT(NVARCHAR(5),
                                 ROW_NUMBER() OVER ( PARTITION BY td.Orderkey       -- (SSA01)
                                                   ORDER BY td.ExternLineNo
                                                            ,td.Sku)),5)
            ,td.ExternOrderkey
            ,td.ExternLineNo
            ,td.Storerkey
            ,td.Sku
            ,td.Packkey
            ,td.UOM
            ,td.OriginalQty
            ,td.OpenQty
            ,td.Lottable02
            ,td.Lottable08
            ,td.Lottable11
            ,Tariffkey =  CASE WHEN tf.Tariffkey NOT IN ('',NULL)
                          THEN tf.Tariffkey ELSE ISNULL(s.Tariffkey,'')
                          END
            ,td.Lottable03                                                           -- (SSA03)
            ,td.ExternPOKey                                                          -- (SSA04)
            ,td.ID                                                                   -- (SSA06)
      FROM #TMP_ORDDTL td
      JOIN dbo.SKU s (NOLOCK) ON  td.Storerkey = s.Storerkey
                              AND td.Sku = s.Sku
      LEFT OUTER JOIN TARIFFxFACILITY tf (NOLOCK) ON  tf.Facility = @c_Facility       -- (SSA03)
                                                  AND td.Storerkey = tf.Storerkey
                                                  AND td.Sku = tf.Sku
      ORDER BY td.ExternLineNo
            ,  td.Sku
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),@n_Err)
                       + ': INSERT INTO ORDERDETAIL Table Failed. (mspASNFZ01)'
         GOTO QUIT_SP
      END

      IF @c_RecType = 'XDELAY'                                                      --(Wan01) - START
      BEGIN
         GOTO QUIT_SP
      END                                                                           --(Wan01) - END
      -- Adding for XDOCK ASN allocation     (SSA03)
       EXEC [WM].[lsp_XDockAllocation_Wrapper]
       @c_ReceiptKey = @c_ReceiptKey,
       @b_Success    = @b_Success   OUTPUT,
       @n_Err        = @n_err       OUTPUT,
       @c_ErrMsg     = @c_errmsg  OUTPUT,
       @c_UserName   = ''

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 68021
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),@n_Err)
                       + ': XDOCK ASN Allocation Failed. (mspASNFZ01)'
         GOTO QUIT_SP
      END
   END

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      SET @b_success = 1
   END
   RETURN
END

GO