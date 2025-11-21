SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispACSO01                                             */
/* Creation Date: 23-DEC-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#297738 - FBR297738_TH- WMS Auto Create Shipment Order      */
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
/* Date         Author  Ver   Purposes                                     */
/* 20-JAN-2014  YTWan   1.1   Remove "PRINT @c_SQL" statement (Wan01)      */
/* 2014-01-20   YTWan   1.2   SOS#298639 - Washington - Finalize by        */
/*                            Receipt Line. Add Default parameters         */
/*                            @c_ReceiptLineNumber.(Wan01)                 */
/* 2014-10-03   SPChin  1.3   SOS322314 Bug Fixed                          */
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length        */
/***************************************************************************/
CREATE PROC [dbo].[ispACSO01]
(     @c_Receiptkey  NVARCHAR(10)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''       --(Wan01)
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

         , @c_SQL                NVARCHAR(MAX)
         , @c_SQLParm            NVARCHAR(MAX)
         , @c_SQL2               NVARCHAR(MAX)

   DECLARE @c_RecType            NVARCHAR(10)
         , @c_CreateOrderInASN   NVARCHAR(10)

   DECLARE @c_OrderKey				NVARCHAR(10)
         , @c_StorerKey				NVARCHAR(15)
         , @c_ExternOrderKey		NVARCHAR(50)   --tlting_ext
         , @c_Contact1   		   NVARCHAR(30)
         , @c_Contact2			   NVARCHAR(30)
         , @c_Company				NVARCHAR(45)
         , @c_Address1			   NVARCHAR(45)
         , @c_Address2  			NVARCHAR(45)
         , @c_Address3        	NVARCHAR(45)
         , @c_Address4        	NVARCHAR(45)
         , @c_City					NVARCHAR(45)
         , @c_State           	NVARCHAR(45)
         , @c_Zip					   NVARCHAR(30)
         , @c_Country         	NVARCHAR(30)
         , @c_ISOCntryCode    	NVARCHAR(45)
         , @c_Phone1          	NVARCHAR(45)
         , @c_Phone2          	NVARCHAR(45)
         , @c_Fax1            	NVARCHAR(45)
         , @c_Fax2            	NVARCHAR(45)
         , @c_vat             	NVARCHAR(45)
         , @c_Facility     		NVARCHAR(10)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_ExternLineNo       NVARCHAR(20)
         , @c_Sku                NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @n_OriginalQty        INT
         , @n_OpenQty            INT
         , @c_Lot                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME
         , @dt_Lottable05        DATETIME
         , @c_TariffKey          NVARCHAR(10)

         , @c_Col                NVARCHAR(30)
         , @c_FromTable          NVARCHAR(30)
         , @c_FromCol            NVARCHAR(30)
         , @n_FromColType        INT
         , @c_ToTable            NVARCHAR(30)
         , @c_ToCol              NVARCHAR(30)
         , @n_ToColType          INT
         , @c_FromValue          NVARCHAR(MAX)
         , @c_Where              NVARCHAR(MAX)

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = '0'
   SET @n_Continue = 1
   SET @n_StartTranCount = @@TRANCOUNT


   CREATE TABLE #TMP_ORD
      (  StorerKey          NVARCHAR(15)   NULL
      ,  ExternOrderKey     NVARCHAR(30)   NOT NULL   DEFAULT ('')
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
      ,  Notes              NVARCHAR(4000) NULL	--SOS322314
      ,  EffectiveDate      DATETIME       NULL       DEFAULT (GETDATE())
      ,  ContainerType      NVARCHAR(20)   NULL
      ,  ContainerQty       INT            NULL       DEFAULT (0)
      ,  BilledContainerQty INT            NULL       DEFAULT (0)
      ,  SOStatus           NVARCHAR(10)   NULL
      ,  MBOLKey            NVARCHAR(10)   NULL       DEFAULT ('')
      ,  InvoiceNo          NVARCHAR(10)   NULL       DEFAULT ('')
      ,  InvoiceAmount      FLOAT          NULL       DEFAULT(0.00)
      ,  Salesman           NVARCHAR(30)   NULL       DEFAULT ('')
      ,  GrossWeight        FLOAT          NULL       DEFAULT(0.00)
      ,  Capacity           FLOAT          NULL       DEFAULT(0.00)
      ,  PrintFlag          NVARCHAR(1)    NULL       DEFAULT ('N')
      ,  LoadKey            NVARCHAR(10)   NULL       DEFAULT ('')
      ,  Rdd                NVARCHAR(30)   NULL       DEFAULT ('')
      ,  Notes2             NVARCHAR(4000) NULL	--SOS322314
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
      ,  ExternOrderkey    NVARCHAR(20)   NULL
      ,  ExternLineNo      NVARCHAR(20)   NULL
      ,  Storerkey         NVARCHAR(15)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Packkey           NVARCHAR(10)   NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  OriginalQty       INT            DEFAULT(0)
      ,  OpenQty           INT            DEFAULT(0)
      ,  Facility          NVARCHAR(5)    NULL
      ,  Lot               NVARCHAR(10)   NULL
      ,  Lottable01        NVARCHAR(18)   NULL
      ,  Lottable02        NVARCHAR(18)   NULL
      ,  Lottable03        NVARCHAR(18)   NULL
      ,  Lottable04        DATETIME       NULL
      ,  Lottable05        DATETIME       NULL

      )

   SET @n_Cnt = 0
   SELECT @c_Storerkey      = RECEIPT.Storerkey
         ,@c_ExternOrderkey = ISNULL(RECEIPT.ExternReceiptKey,'')
         ,@c_RecType        = RECEIPT.RecType
         ,@n_Cnt            = 1
   FROM RECEIPT WITH (NOLOCK)
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey
   AND   RECEIPT.ASNStatus  = '9'

   EXEC nspGetRight
         @c_Facility  = NULL
       , @c_StorerKey = @c_StorerKey
       , @c_sku       = NULL
       , @c_ConfigKey = 'CreateOrderInASN'
       , @b_Success   = @b_Success             OUTPUT
       , @c_authority = @c_CreateOrderInASN    OUTPUT
       , @n_err       = @n_err                 OUTPUT
       , @c_errmsg    = @c_errmsg              OUTPUT

   IF @c_CreateOrderInASN = '1'
   BEGIN
      IF @n_Cnt = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      IF @c_RecType = 'GRN'
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

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
            ,  Lot
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05

            )
      SELECT   RD.ReceiptLineNumber
            ,  RH.ExternReceiptkey
            ,  RD.ExternLineNo
            ,  RD.Storerkey
            ,  RD.Sku
            ,  RD.Packkey
            ,  RD.UOM
            ,  RD.QtyReceived
            ,  RD.QtyReceived
            ,  ''
            ,  ISNULL(RD.ToLot,'')
            ,  RD.Lottable01
            ,  RD.Lottable02
            ,  RD.Lottable03
            ,  RD.Lottable04
            ,  RD.Lottable05
      FROM  RECEIPT RH WITH (NOLOCK)
      JOIN  RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)
      WHERE RH.ReceiptKey = @c_Receiptkey

      IF NOT EXISTS (SELECT 1
                     FROM #TMP_ORDDTL)
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      INSERT INTO #TMP_ORD
      ( Storerkey
      ,  ExternOrderkey
      ,  OrderDate
      ,  DeliveryDate
      ,  Priority
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
      ,  BuyerPO
      ,  Status
      ,  DischargePlace
      ,  DeliveryPlace
      ,  SOStatus
      ,  Facility
      )
      SELECT
         @c_Storerkey
      ,  ExternOrderkey = ISNULL(RECEIPT.ExternReceiptkey,'')
      ,  OrderDate      = GETDATE()
      ,  DeliveryDate   = DATEADD(DAY, 1, GETDATE())
      ,  Priority       = '1'
      ,  Consigneekey   = ISNULL(FACILITY.UserDefine08,'')
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
      ,  BuyerPO        = RECEIPT.ReceiptKey
      ,  Status         = '0'
      ,  DischargePlace = ISNULL(RECEIPT.Facility,'')
      ,  DeliveryPlace  = ISNULL(FACILITY.UserDefine08,'')
      ,  SOStatus       = '0'
      ,  Facility       = RECEIPT.Facility
      FROM RECEIPT        WITH (NOLOCK)
      JOIN FACILITY       WITH (NOLOCK) ON (RECEIPT.Facility = FACILITY.Facility)
      WHERE RECEIPT.ReceiptKey = @c_Receiptkey

      IF @@ROWCOUNT = 0
      BEGIN
         GOTO QUIT_SP
      END

      SET @c_FromTable = 'RECEIPT'
      SET @c_Where     = ' WHERE ReceiptKey = @c_Receiptkey'
   END
   ELSE
   BEGIN
      IF @c_RecType = 'NORMAL'
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

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
            ,  Lot
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
            )
      SELECT ''
            ,''
            ,''
            ,RD.Storerkey
            ,RD.Sku
            ,RD.Packkey
            ,RD.UOM
            ,RD.QtyReceived
            ,RD.QtyReceived
            ,''
            ,ITR.Lot
            ,LA.Lottable01
            ,LA.Lottable02
            ,LA.Lottable03
            ,LA.Lottable04
            ,LA.Lottable05
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      JOIN ITRN ITR         WITH (NOLOCK) ON (RD.ReceiptKey + RD.ReceiptLineNumber = ITR.SourceKey)
                                          AND(ITR.TranType = 'DP')
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (ITR.Lot = LA.Lot)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.QtyReceived > 0

      IF NOT EXISTS (SELECT 1
                     FROM #TMP_ORDDTL)
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      INSERT INTO #TMP_ORD
      (  StorerKey
      ,  ExternOrderkey
      ,  OrderDate
      ,  Priority
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
      ,  BuyerPO
      ,  BillToKey
      ,  B_Contact1
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
      ,  ContainerType
      ,  ContainerQty
      ,  BilledContainerQty
      ,  InvoiceNo
      ,  InvoiceAmount
      ,  Salesman
      ,  PrintFlag
      ,  Rdd
      ,  Notes2
      ,  SequenceNo
      ,  Rds
      ,  SectionKey
      ,  Facility
      ,  LabelPrice
      )
      SELECT
         @c_Storerkey
      ,  ExternOrderkey    = ISNULL(ORDERS.ExternOrderkey,'')
      ,  OrderDate         = ISNULL(ORDERS.OrderDate,'')
      ,  Priority          = ISNULL(ORDERS.Priority,'')
      ,  Consigneekey      = ISNULL(ORDERS.Consigneekey,'')
      ,  C_Contact1        = ISNULL(CS.Contact1, ORDERS.C_Contact1)
      ,  C_Contact2        = ISNULL(CS.Contact2, ORDERS.C_Contact2)
      ,  C_Company         = ISNULL(CS.Company,  ORDERS.C_Company)
      ,  C_Address1        = ISNULL(CS.Address1, ORDERS.C_Address1)
      ,  C_Address2        = ISNULL(CS.Address2, ORDERS.C_Address2)
      ,  C_Address3        = ISNULL(CS.Address3, ORDERS.C_Address3)
      ,  C_Address4        = ISNULL(CS.Address4, ORDERS.C_Address4)
      ,  C_City            = ISNULL(CS.City,     ORDERS.C_City)
      ,  C_State           = ISNULL(CS.State,    ORDERS.C_State)
      ,  C_Zip             = ISNULL(CS.Zip,      ORDERS.C_Zip)
      ,  C_Country         = ISNULL(CS.Country,  ORDERS.C_Country)
      ,  C_ISOCntryCode    = ISNULL(CS.ISOCntryCode, ORDERS.C_ISOCntryCode)
      ,  C_Phone1          = ISNULL(CS.Phone1,   ORDERS.C_Phone1)
      ,  C_Phone2          = ISNULL(CS.Phone2,   ORDERS.C_Phone2)
      ,  C_Fax1            = ISNULL(CS.Fax1,     ORDERS.C_Fax1)
      ,  C_Fax2            = ISNULL(CS.Fax2,     ORDERS.C_Fax2)
      ,  C_Vat             = ISNULL(CS.Vat,      ORDERS.C_Vat)
      ,  BuyerPO           = ISNULL(ORDERS.BuyerPO,'')
      ,  BillToKey         = ISNULL(ORDERS.BillToKey,'')
      ,  B_Contact1        = ISNULL(ORDERS.B_Contact1,'')
      ,  B_Contact2        = ISNULL(ORDERS.B_Contact2,'')
      ,  B_Company         = ISNULL(ORDERS.B_Company,'')
      ,  B_Address1        = ISNULL(ORDERS.B_Address1,'')
      ,  B_Address2        = ISNULL(ORDERS.B_Address2,'')
      ,  B_Address3        = ISNULL(ORDERS.B_Address3,'')
      ,  B_Address4        = ISNULL(ORDERS.B_Address4,'')
      ,  B_City            = ISNULL(ORDERS.B_City,'')
      ,  B_State           = ISNULL(ORDERS.B_State,'')
      ,  B_Zip             = ISNULL(ORDERS.B_Zip,'')
      ,  B_Country         = ISNULL(ORDERS.B_Country,'')
      ,  B_ISOCntryCode    = ISNULL(ORDERS.B_ISOCntryCode,'')
      ,  B_Phone1          = ISNULL(ORDERS.B_Phone1,'')
      ,  B_Phone2          = ISNULL(ORDERS.B_Phone2,'')
      ,  B_Fax1            = ISNULL(ORDERS.B_Fax1,'')
      ,  B_Fax2            = ISNULL(ORDERS.B_Fax2,'')
      ,  B_Vat             = ISNULL(ORDERS.B_Vat ,'')
      ,  IncoTerm          = ISNULL(ORDERS.IncoTerm ,'')
      ,  PmtTerm           = ISNULL(ORDERS.PmtTerm ,'')
      ,  DischargePlace    = ISNULL(ORDERS.DischargePlace,'')
      ,  DeliveryPlace     = ISNULL(ORDERS.DeliveryPlace,'')
      ,  IntermodalVehicle = ISNULL(ORDERS.IntermodalVehicle,'')
      ,  CountryOfOrigin   = ISNULL(ORDERS.CountryOfOrigin,'')
      ,  CountryDestination= ISNULL(ORDERS.CountryDestination,'')
      ,  UpdateSource      = ISNULL(ORDERS.UpdateSource,'')
      ,  Type              = 'RD'
      ,  OrderGroup        = ISNULL(ORDERS.OrderGroup,'')
      ,  Door              = ISNULL(ORDERS.Door,'')
      ,  Route             = ISNULL(ORDERS.Route,'')
      ,  Stop              = ISNULL(ORDERS.Stop,'')
      ,  Notes             = ISNULL(ORDERS.Notes,'')
      ,  ContainerType     = ISNULL(ORDERS.ContainerType,'')
      ,  ContainerQty      = ISNULL(ORDERS.ContainerQty,0)
      ,  BilledContainerQty= ISNULL(ORDERS.BilledContainerQty,0)
      ,  InvoiceNo         = ISNULL(ORDERS.ContainerType,'')
      ,  InvoiceAmount     = ISNULL(ORDERS.InvoiceAmount,0)
      ,  Salesman          = ISNULL(ORDERS.Salesman,'')
      ,  PrintFlag         = ISNULL(ORDERS.PrintFlag,'')
      ,  Rdd               = ISNULL(ORDERS.Rdd,'')
      ,  Notes2            = ISNULL(ORDERS.Notes2,'')
      ,  SequenceNo        = ISNULL(ORDERS.SequenceNo,'')
      ,  Rds               = ISNULL(ORDERS.Rds,'')
      ,  SectionKey        = ISNULL(ORDERS.SectionKey,'')
      ,  Facility          = ISNULL(ORDERS.Facility,'')
      ,  LabelPrice        = ISNULL(ORDERS.LabelPrice,0)
      FROM ORDERS WITH (NOLOCK)
      LEFT JOIN STORER  CS WITH (NOLOCK) ON (ORDERS.Consigneekey = CS.Storerkey)
      WHERE ExternOrderkey = @c_ExternOrderkey

      IF @@ROWCOUNT = 0
      BEGIN
         GOTO QUIT_SP
      END

      SET @c_FromTable = 'ORDERS'
      SET @c_Where     = ' WHERE ExternOrderkey = @c_ExternOrderkey'
   END


   DECLARE CUR_H_COLMAP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(UDF01,'')
         ,ISNULL(UDF02,'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'ASN2SOMAP'
   AND   Storerkey= @c_Storerkey
   AND   Short    = 'H'

   OPEN CUR_H_COLMAP

   FETCH NEXT FROM CUR_H_COLMAP INTO @c_FromCol
                                    ,@c_ToCol

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Cnt = 0
      SELECT @n_FromColType = C.xType
            ,@n_Cnt         = 1
      FROM dbo.SysObjects O WITH (NOLOCK)
      JOIN dbo.SysColumns C WITH (NOLOCK) ON (O.Id = C.Id)
      WHERE O.Name = @c_FromTable
      AND   C.Name = @c_FromCol

      IF @n_Cnt = 0
      BEGIN
         GOTO NEXT_REC
      END

      SET @n_Cnt = 0
      SELECT @n_ToColType = C.xType
            ,@n_Cnt         = 1
      FROM dbo.SysObjects O WITH (NOLOCK)
      JOIN dbo.SysColumns C WITH (NOLOCK) ON (O.Id = C.Id)
      WHERE O.Name = 'ORDERS'
      AND   C.Name = @c_ToCol

      IF @n_Cnt = 0
      BEGIN
         GOTO NEXT_REC
      END

      SET @c_SQL = N'SELECT @c_FromValue = CASE @n_FromColType'
                 +                       ' WHEN 61 THEN CONVERT( NVARCHAR(30), ' + @c_FromCol + ', 121)'
                 +                       ' ELSE CONVERT( NVARCHAR(MAX), ' + @c_FromCol + ') END'
                 +                       ' FROM ' + @c_FromTable + ' WITH (NOLOCK)'
                 + @c_Where

      SET @c_SQLParm =  N'@n_FromColType     INT'
                     +  ',@c_ReceiptKey      NVARCHAR(10)'
                     +  ',@c_ExternOrderkey  NVARCHAR(50)'
                     +  ',@c_FromValue       NVARCHAR(MAX) OUTPUT'

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParm
                        ,@n_FromColType
                        ,@c_ReceiptKey
                        ,@c_ExternOrderkey
                        ,@c_FromValue        OUTPUT

      SET @c_SQL = N'UPDATE #TMP_ORD SET ' + @c_ToCol + ' = '

      IF @n_ToColType IN ( 35,39,175,231,239 )
      BEGIN
         --SET @c_SQL = @c_SQL + N'''' + @c_FromValue + ''''	--SOS322314
         SET @c_SQL = @c_SQL + 'N''' + @c_FromValue + ''''		--SOS322314
      END
      ELSE IF @n_ToColType = 61 AND IsDate( @c_FromValue ) = 1
      BEGIN
         SET @c_SQL = @c_SQL + 'CONVERT( DATETIME, N''' + @c_FromValue + ''')'
      END
      ELSE IF @n_ToColType = 56 AND IsNumeric( @c_FromValue ) = 1
      BEGIN
         SET @c_SQL = @c_SQL + 'CONVERT( INT, N''' + @c_FromValue + ''')'
      END
      ELSE IF  @n_ToColType IN ( 59,60,62,106,108 ) AND IsNumeric( @c_FromValue ) = 1
      BEGIN
         SET @c_SQL = @c_SQL + 'CONVERT( FLOAT, N''' + @c_FromValue + ''')'
      END
      ELSE
      BEGIN
         SET @c_SQL = @c_SQL + @c_ToCol

         SET @c_SQL2    = N'SELECT @c_FromValue = ' + @c_ToCol + ' FROM #TMP_ORD '
         SET @c_SQLParm =  N'@c_FromValue     NVARCHAR(MAX) OUTPUT'
         EXEC sp_ExecuteSQL @c_SQL2
                           ,@c_SQLParm
                           ,@c_FromValue OUTPUT

      END

      IF @c_ToCol IN ('ConsigneeKey', 'BillToKey', 'MarkForKey')
      BEGIN
         SET @c_Col = CASE @c_ToCol WHEN 'ConsigneeKey' THEN 'c_'
                                    WHEN 'BillToKey'    THEN 'b_'
                                    WHEN 'MarkForKey'   THEN 'm_'
                                    ELSE ''
                                    END

         SELECT @c_Company       = ISNULL(RTRIM(Company),'')
               ,@c_Address1      = ISNULL(RTRIM(Address1),'')
               ,@c_Address2      = ISNULL(RTRIM(Address2),'')
               ,@c_Address3      = ISNULL(RTRIM(Address3),'')
               ,@c_Address4      = ISNULL(RTRIM(Address4),'')
               ,@c_city          = ISNULL(RTRIM(city),'')
               ,@c_state         = ISNULL(RTRIM(state),'')
               ,@c_zip           = ISNULL(RTRIM(zip),'')
               ,@c_Country       = ISNULL(RTRIM(country),'')
               ,@c_Isocntrycode  = ISNULL(RTRIM(Isocntrycode),'')
               ,@c_Contact1      = ISNULL(RTRIM(Contact1),'')
               ,@c_Contact2      = ISNULL(RTRIM(Contact2),'')
               ,@c_Phone1        = ISNULL(RTRIM(Phone1),'')
               ,@c_Phone2        = ISNULL(RTRIM(Phone2),'')
               ,@c_Fax1          = ISNULL(RTRIM(Fax1),'')
               ,@c_Fax2          = ISNULL(RTRIM(Fax2),'')
               ,@c_Vat           = ISNULL(RTRIM(Vat),'')
         FROM STORER WITH (NOLOCK)
         WHERE Storerkey = @c_FromValue

         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Company  = N''' + @c_Company  + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Address1 = N''' + @c_Address1 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Address2 = N''' + @c_Address2 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Address3 = N''' + @c_Address3 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Address4 = N''' + @c_Address4 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'City = N'''     + @c_City + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Zip  = N'''     + @c_Zip + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'State = N'''    + @c_State + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Country = N'''  + @c_Country + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Isocntrycode = N''' + @c_Isocntrycode + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Contact1 = N''' + @c_Contact1 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Contact2 = N''' + @c_Contact2 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Phone1 = N'''   + @c_Phone1 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Phone2 = N'''   + @c_Phone2 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Fax1 = N'''     + @c_Fax1 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Fax2 = N'''     + @c_Fax2 + ''''
         SET @c_SQL = @c_SQL + ', ' + @c_Col + 'Vat  = N'''     + @c_Vat  + ''''
      END

      EXEC sp_ExecuteSQL @c_SQL

      --PRINT @c_SQL       --(Wan01)
      NEXT_REC:
      FETCH NEXT FROM CUR_H_COLMAP INTO @c_FromCol
                                       ,@c_ToCol
   END
   CLOSE CUR_H_COLMAP
   DEALLOCATE CUR_H_COLMAP

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
      GOTO NEXT_REC
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
         ,Lot
         ,Lottable01
         ,Lottable02
         ,Lottable03
         ,Lottable04
         ,Lottable05
   FROM #TMP_ORDDTL
   ORDER BY OrderLineNumber
         ,  ExternLineNo

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
                                 , @c_Lot
                                 , @c_Lottable01
                                 , @c_Lottable02
                                 , @c_Lottable03
                                 , @dt_Lottable04
                                 , @dt_Lottable05

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_OrderLineNumber = ''
      BEGIN
         SELECT @c_OrderLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5),ISNULL(MAX(OrderLineNumber)+1,1)),5)
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END

      SELECT @c_Facility = Facility
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
         ,  Lot
         ,  Lottable01
         ,  Lottable02
         ,  Lottable03
         ,  Lottable04
         ,  Lottable05
         ,  Tariffkey
         ,  Facility
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
         ,  @c_Lot
         ,  @c_Lottable01
         ,  @c_Lottable02
         ,  @c_Lottable03
         ,  @dt_Lottable04
         ,  @dt_Lottable05
         ,  @c_Tariffkey
         ,  @c_Facility
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
                                    , @c_Lot
                                    , @c_Lottable01
                                    , @c_Lottable02
                                    , @c_Lottable03
                                    , @dt_Lottable04
                                    , @dt_Lottable05
   END
   CLOSE CUR_ORDDTL
   DEALLOCATE CUR_ORDDTL

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
      --EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispACSO01'
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