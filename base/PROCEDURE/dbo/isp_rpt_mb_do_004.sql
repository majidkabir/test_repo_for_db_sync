SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DO_004                                  */
/* Creation Date: 23-Nov-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19983 - TH-Aroma Create Invoice/Billing/Receipt Report  */
/*                                                                      */
/* Called By: RPT_MB_DO_004_1                                           */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 23-Nov-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 04-Jan-2023  WLChooi  1.1  WMS-21474 - Modify column (WL01)          */
/* 11-Jan-2023  WLChooi  1.2  WMS-21474 - Add OrderInfo06 (WL02)        */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_MB_DO_004]
(
   @c_Mbolkey       NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_Errmsg    NVARCHAR(255)
         , @n_Count     INT

   DECLARE @c_Orderkey   NVARCHAR(10)
         , @c_MarkForKey NVARCHAR(100)
         , @c_NoOfOrig   NVARCHAR(10)
         , @c_NoOfCopy   NVARCHAR(10)

   DECLARE @n_MaxLineno  INT = 0
         , @n_CurrentRec INT
         , @n_MaxRec     INT
         , @c_CopyType   NVARCHAR(250)
         , @n_PageGroup  INT
         , @c_ReportType NVARCHAR(10)
         , @c_Flag       NVARCHAR(1) = 'N'

   DECLARE @T_RPT_RAW AS TABLE
   (
      [OrderKey]       NVARCHAR(10)   NULL
    , [InvoiceNo]      NVARCHAR(20)   NULL
    , [UserDefine05]   NVARCHAR(20)   NULL
    , [ExternOrderKey] NVARCHAR(50)   NULL
    , [ConsigneeKey]   NVARCHAR(15)   NULL
    , [B_Company]      NVARCHAR(100)  NULL
    , [B_Address1]     NVARCHAR(100)  NULL
    , [B_Address2]     NVARCHAR(100)  NULL
    , [B_Address3]     NVARCHAR(100)  NULL
    , [B_Address4]     NVARCHAR(100)  NULL
    , [B_City]         NVARCHAR(100)  NULL
    , [B_State]        NVARCHAR(100)  NULL
    , [B_Zip]          NVARCHAR(100)  NULL
    , [B_Vat]          NVARCHAR(18)   NULL
    , [B_Phone]        NVARCHAR(150)  NULL   --WL01
    , [B_Contact1]     NVARCHAR(100)  NULL
    , [C_Company]      NVARCHAR(100)  NULL
    , [C_Addresses1]   NVARCHAR(500)  NULL
    , [C_Addresses2]   NVARCHAR(500)  NULL
    , [C_Phone]        NVARCHAR(100)  NULL
    , [UserDefine04]   NVARCHAR(40)   NULL
    , [OrderInfo02]    NVARCHAR(30)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [OrderInfo10]    NVARCHAR(30)   NULL
    , [OrderInfo09]    NVARCHAR(30)   NULL
    , [OrderInfo03]    NVARCHAR(30)   NULL
    , [OrderInfo04]    NVARCHAR(30)   NULL
    , [OrderInfo07]    NVARCHAR(30)   NULL
    , [OrderInfo08]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [M_Contact1]     NVARCHAR(100)  NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Salesman]       NVARCHAR(30)   NULL
    , [M_Company]      NVARCHAR(100)  NULL
    , [ExternLineNo]   NVARCHAR(20)   NULL
    , [Sku]            NVARCHAR(20)   NULL
    , [SKUDESCR]       NVARCHAR(250)  NULL
    , [UserDefine03]   NVARCHAR(18)   NULL
    , [ODUserDefine04] NVARCHAR(18)   NULL
    , [Tax01]          FLOAT(8)       NULL
    , [ExtendedPrice]  FLOAT(8)       NULL
    , [UnitPrice]      FLOAT(8)       NULL
    , [Notes]          NVARCHAR(4000) NULL
    , [Notes2]         NVARCHAR(4000) NULL
    , [M_Contact2]     NVARCHAR(100)  NULL
    , [MarkforKey]     NVARCHAR(15)   NULL
    , [MBOLKey]        NVARCHAR(10)   NULL
    , [CarrierCharges] FLOAT(8)       NULL
    , [Userdefine01]   NVARCHAR(50)   NULL
   )

   DECLARE @T_RPT_STG AS TABLE
   (
      [OrderKey]       NVARCHAR(10)   NULL
    , [InvoiceNo]      NVARCHAR(20)   NULL
    , [UserDefine05]   NVARCHAR(20)   NULL
    , [ExternOrderKey] NVARCHAR(50)   NULL
    , [ConsigneeKey]   NVARCHAR(15)   NULL
    , [B_Company]      NVARCHAR(100)  NULL
    , [B_Address1]     NVARCHAR(100)  NULL
    , [B_Address2]     NVARCHAR(100)  NULL
    , [B_Address3]     NVARCHAR(100)  NULL
    , [B_Address4]     NVARCHAR(100)  NULL
    , [B_City]         NVARCHAR(100)  NULL
    , [B_State]        NVARCHAR(100)  NULL
    , [B_Zip]          NVARCHAR(100)  NULL
    , [B_Vat]          NVARCHAR(18)   NULL
    , [B_Phone]        NVARCHAR(150)  NULL   --WL01
    , [B_Contact1]     NVARCHAR(100)  NULL
    , [C_Company]      NVARCHAR(100)  NULL
    , [C_Addresses1]   NVARCHAR(500)  NULL
    , [C_Addresses2]   NVARCHAR(500)  NULL
    , [C_Phone]        NVARCHAR(100)  NULL
    , [UserDefine04]   NVARCHAR(40)   NULL
    , [OrderInfo02]    NVARCHAR(30)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [OrderInfo10]    NVARCHAR(30)   NULL
    , [OrderInfo09]    NVARCHAR(30)   NULL
    , [OrderInfo03]    NVARCHAR(30)   NULL
    , [OrderInfo04]    NVARCHAR(30)   NULL
    , [OrderInfo07]    NVARCHAR(30)   NULL
    , [OrderInfo08]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [M_Contact1]     NVARCHAR(100)  NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Salesman]       NVARCHAR(30)   NULL
    , [M_Company]      NVARCHAR(100)  NULL
    , [ExternLineNo]   NVARCHAR(20)   NULL
    , [Sku]            NVARCHAR(20)   NULL
    , [SKUDESCR]       NVARCHAR(250)  NULL
    , [UserDefine03]   NVARCHAR(18)   NULL
    , [ODUserDefine04] NVARCHAR(18)   NULL
    , [Tax01]          FLOAT(8)       NULL
    , [ExtendedPrice]  FLOAT(8)       NULL
    , [UnitPrice]      FLOAT(8)       NULL
    , [Notes]          NVARCHAR(4000) NULL
    , [Notes2]         NVARCHAR(4000) NULL
    , [M_Contact2]     NVARCHAR(100)  NULL
    , [MarkforKey]     NVARCHAR(15)   NULL
    , [MBOLKey]        NVARCHAR(10)   NULL
    , [ReportType]     NVARCHAR(1)    NULL
    , [CopyType]       NVARCHAR(30)   NULL
    , [Copies]         INT            NULL
    , [CarrierCharges] FLOAT(8)       NULL
    , [Userdefine01]   NVARCHAR(50)   NULL
   )

   DECLARE @T_RPT_OUTPUT AS TABLE
   (
      [OrderKey]       NVARCHAR(10)   NULL
    , [InvoiceNo]      NVARCHAR(20)   NULL
    , [UserDefine05]   NVARCHAR(20)   NULL
    , [ExternOrderKey] NVARCHAR(50)   NULL
    , [ConsigneeKey]   NVARCHAR(15)   NULL
    , [B_Company]      NVARCHAR(100)  NULL
    , [B_Address1]     NVARCHAR(100)  NULL
    , [B_Address2]     NVARCHAR(100)  NULL
    , [B_Address3]     NVARCHAR(100)  NULL
    , [B_Address4]     NVARCHAR(100)  NULL
    , [B_City]         NVARCHAR(100)  NULL
    , [B_State]        NVARCHAR(100)  NULL
    , [B_Zip]          NVARCHAR(100)  NULL
    , [B_Vat]          NVARCHAR(18)   NULL
    , [B_Phone]        NVARCHAR(150)  NULL   --WL01
    , [B_Contact1]     NVARCHAR(100)  NULL
    , [C_Company]      NVARCHAR(100)  NULL
    , [C_Addresses1]   NVARCHAR(500)  NULL
    , [C_Addresses2]   NVARCHAR(500)  NULL
    , [C_Phone]        NVARCHAR(100)  NULL
    , [UserDefine04]   NVARCHAR(40)   NULL
    , [OrderInfo02]    NVARCHAR(30)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [OrderInfo10]    NVARCHAR(30)   NULL
    , [OrderInfo09]    NVARCHAR(30)   NULL
    , [OrderInfo03]    NVARCHAR(30)   NULL
    , [OrderInfo04]    NVARCHAR(30)   NULL
    , [OrderInfo07]    NVARCHAR(30)   NULL
    , [OrderInfo08]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [M_Contact1]     NVARCHAR(100)  NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Salesman]       NVARCHAR(30)   NULL
    , [M_Company]      NVARCHAR(100)  NULL
    , [ExternLineNo]   NVARCHAR(20)   NULL
    , [Sku]            NVARCHAR(20)   NULL
    , [SKUDESCR]       NVARCHAR(250)  NULL
    , [UserDefine03]   NVARCHAR(18)   NULL
    , [ODUserDefine04] NVARCHAR(18)   NULL
    , [Tax01]          FLOAT(8)       NULL
    , [ExtendedPrice]  FLOAT(8)       NULL
    , [UnitPrice]      FLOAT(8)       NULL
    , [Notes]          NVARCHAR(4000) NULL
    , [Notes2]         NVARCHAR(4000) NULL
    , [M_Contact2]     NVARCHAR(100)  NULL
    , [MarkforKey]     NVARCHAR(15)   NULL
    , [MBOLKey]        NVARCHAR(10)   NULL
    , [ReportType]     NVARCHAR(1)    NULL
    , [CopyTypeENG]    NVARCHAR(250)  NULL
    , [CopyTypeTHA]    NVARCHAR(250)  NULL
    , [PageGroup]      INT            NULL
    , [ReportTitleENG] NVARCHAR(250)  NULL
    , [ReportTitleTHA] NVARCHAR(250)  NULL
    , [AmountENG]      NVARCHAR(250)  NULL
    , [AmountTHA]      NVARCHAR(250)  NULL
    , [DummyLine]      NVARCHAR(10)   NULL
    , [CarrierCharges] FLOAT(8)       NULL
    , [Userdefine01]   NVARCHAR(50)   NULL
   )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''

   --Validation
   IF ISNULL(@c_Mbolkey,'') = '' 
      GOTO QUIT_SP

   SET @c_Orderkey = ''
   SET @c_MarkForKey = ''
   SET @c_NoOfCopy = ''
   SET @c_ReportType = ''
   SET @c_NoOfOrig = ''
   SET @c_NoOfCopy = ''
   SET @c_Flag = 'N'

   DECLARE CUR_LOOP_PRE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey
                 , MarkforKey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_Mbolkey

   OPEN CUR_LOOP_PRE

   FETCH NEXT FROM CUR_LOOP_PRE
   INTO @c_Orderkey
      , @c_MarkForKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @c_Flag = 'Y'
         GOTO NEXT_LOOP

      DECLARE CUR_SPLIT_PRE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LEFT(TRIM(FDS.ColValue), 1)
                    , SUBSTRING(TRIM(FDS.ColValue), 2, 1)
                    , RIGHT(TRIM(FDS.ColValue), 1)
      FROM dbo.fnc_DelimSplit('|', @c_MarkForKey) FDS
      WHERE LEFT(TRIM(FDS.ColValue), 1) IN ( 1, 2 )
      ORDER BY 1

      OPEN CUR_SPLIT_PRE

      FETCH NEXT FROM CUR_SPLIT_PRE
      INTO @c_ReportType
         , @c_NoOfOrig
         , @c_NoOfCopy

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @c_NoOfOrig > 0 OR @c_NoOfCopy > 0
            SET @c_Flag = 'Y'
            
         FETCH NEXT FROM CUR_SPLIT_PRE
         INTO @c_ReportType
            , @c_NoOfOrig
            , @c_NoOfCopy
      END
      CLOSE CUR_SPLIT_PRE
      DEALLOCATE CUR_SPLIT_PRE

      NEXT_LOOP:
      FETCH NEXT FROM CUR_LOOP_PRE
      INTO @c_Orderkey
         , @c_MarkForKey
   END
   CLOSE CUR_LOOP_PRE
   DEALLOCATE CUR_LOOP_PRE

   IF @c_Flag = 'N'
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_err = 65410
      SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Mbolkey# ' + @c_Mbolkey + ' no need to print invoice. (isp_RPT_MB_DO_004)'
      GOTO EXIT_SP
   END

   INSERT INTO @T_RPT_RAW
   SELECT OH.OrderKey
        , OH.InvoiceNo
        , OH.UserDefine05
        , OH.ExternOrderKey
        , TRIM(ISNULL(OH.ConsigneeKey, '')) AS ConsigneeKey
        , TRIM(ISNULL(OH.B_Company, '')) AS B_Company
        , TRIM(ISNULL(OH.B_Address1, '')) AS B_Address1
        , TRIM(ISNULL(OH.B_Address2, '')) AS B_Address2
        , TRIM(ISNULL(OH.B_Address3, '')) AS B_Address3
        , TRIM(ISNULL(OH.B_Address4, '')) AS B_Address4
        , TRIM(ISNULL(OH.B_City, '')) AS B_City
        , TRIM(ISNULL(OH.B_State, '')) AS B_State
        , TRIM(ISNULL(OH.B_Zip, '')) AS B_Zip
        , TRIM(ISNULL(OH.B_Vat, '')) AS B_Vat
        , TRIM(ISNULL(OH.B_Phone1, '')) + ',' + TRIM(ISNULL(OH.B_Fax1, '')) + ',' +   --WL01
          TRIM(ISNULL(OH.B_Phone2, '')) AS B_Phone   --WL01
        , TRIM(ISNULL(OH.B_contact1,'')) AS B_contact1
        , TRIM(ISNULL(OH.C_Company, '')) AS C_Company
        , TRIM(ISNULL(OH.C_Address1, '')) + ' ' + TRIM(ISNULL(OH.C_Address2, '')) AS C_Addresses1
        , TRIM(ISNULL(OH.C_Address3, '')) + ' ' + TRIM(ISNULL(OH.C_Address4, '')) + ' ' + TRIM(ISNULL(OH.C_City, ''))
          + ' ' + TRIM(ISNULL(OH.C_State, '')) + ' ' + TRIM(ISNULL(OH.C_Zip, '')) AS C_Addresses2   --WL01
        , TRIM(ISNULL(OH.C_Phone1, '')) + '.' + TRIM(ISNULL(OH.C_Phone2, '')) AS C_Phone
        , OH.UserDefine04
        , TRIM(ISNULL(OIF.OrderInfo02, '')) AS OrderInfo02
        , TRIM(ISNULL(OIF.OrderInfo01, '')) AS OrderInfo01
        , TRIM(ISNULL(OIF.OrderInfo10, '')) AS OrderInfo10
        , TRIM(ISNULL(OIF.OrderInfo09, '')) AS OrderInfo09
        , TRIM(ISNULL(OIF.OrderInfo03, '')) AS OrderInfo03
        , TRIM(ISNULL(OIF.OrderInfo06, '')) AS OrderInfo04   --WL02
        , TRIM(ISNULL(OIF.OrderInfo07, '')) AS OrderInfo07
        , TRIM(ISNULL(OIF.OrderInfo08, '')) AS OrderInfo08
        , ISNULL(OIF.PayableAmount, 0) AS PayableAmount
        , TRIM(ISNULL(OH.M_Contact1, '')) AS M_Contact1
        , OH.BuyerPO
        , OH.Salesman
        , TRIM(ISNULL(OH.M_Company, '')) AS M_Company
        , OD.ExternLineNo
        , OD.Sku
        , ISNULL(S.BUSR4,'') AS SKUDESCR
        , OD.UserDefine03
        , OD.UserDefine04 AS ODUserDefine04
        , OD.Tax01
        , OD.ExtendedPrice
        , OD.UnitPrice
        , TRIM(ISNULL(OH.Notes, '')) AS Notes
        , TRIM(ISNULL(OH.Notes2, '')) AS Notes2
        , TRIM(ISNULL(OH.M_Contact2, '')) AS M_Contact2
        , OH.MarkforKey
        , OH.MBOLKey
        , ISNULL(OIF.CarrierCharges,0)
        , OD.UserDefine01
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.StorerKey = OD.StorerKey
   LEFT JOIN OrderInfo OIF (NOLOCK) ON OH.OrderKey = OIF.OrderKey
   WHERE OH.MBOLKey = @c_Mbolkey

   SET @c_Orderkey = ''
   SET @c_MarkForKey = ''
   SET @c_NoOfCopy = ''
   SET @c_ReportType = ''
   SET @c_NoOfOrig = ''
   SET @c_NoOfCopy = ''

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey
                 , MarkforKey
   FROM @T_RPT_RAW TR

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_Orderkey
      , @c_MarkForKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.ORDERS
      SET PrintFlag = 'Y'
        , TrafficCop = NULL
        , EditDate = GETDATE()
        , EditWho = SUSER_SNAME()
      WHERE OrderKey = @c_Orderkey

      DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LEFT(TRIM(FDS.ColValue), 1)
                    , SUBSTRING(TRIM(FDS.ColValue), 2, 1)
                    , RIGHT(TRIM(FDS.ColValue), 1)
      FROM dbo.fnc_DelimSplit('|', @c_MarkForKey) FDS
      WHERE LEFT(TRIM(FDS.ColValue), 1) IN ( 1, 2 )
      ORDER BY 1

      OPEN CUR_SPLIT

      FETCH NEXT FROM CUR_SPLIT
      INTO @c_ReportType
         , @c_NoOfOrig
         , @c_NoOfCopy

      WHILE @@FETCH_STATUS = 0
      BEGIN
         WHILE @c_NoOfOrig > 0
         BEGIN
            INSERT INTO @T_RPT_STG (OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company
                                  , B_Address1, B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat
                                  , B_Phone, B_Contact1, C_Company, C_Addresses1, C_Addresses2, C_Phone, UserDefine04, OrderInfo02
                                  , OrderInfo01, OrderInfo10, OrderInfo09, OrderInfo03, OrderInfo04, OrderInfo07
                                  , OrderInfo08, PayableAmount, M_Contact1, BuyerPO, Salesman, M_Company, ExternLineNo
                                  , Sku, SKUDESCR, UserDefine03, ODUserDefine04, Tax01, ExtendedPrice, UnitPrice, Notes
                                  , Notes2, M_Contact2, MarkforKey, MBOLKey, ReportType, CopyType, Copies, CarrierCharges, Userdefine01)
            SELECT OrderKey
                 , InvoiceNo
                 , UserDefine05
                 , ExternOrderKey
                 , ConsigneeKey
                 , B_Company
                 , B_Address1
                 , B_Address2
                 , B_Address3
                 , B_Address4
                 , B_City
                 , B_State
                 , B_Zip
                 , B_Vat
                 , B_Phone
                 , B_Contact1
                 , C_Company
                 , C_Addresses1
                 , C_Addresses2
                 , C_Phone
                 , UserDefine04
                 , OrderInfo02
                 , OrderInfo01
                 , OrderInfo10
                 , OrderInfo09
                 , OrderInfo03
                 , OrderInfo04
                 , OrderInfo07
                 , OrderInfo08
                 , PayableAmount
                 , M_Contact1
                 , BuyerPO
                 , Salesman
                 , M_Company
                 , ExternLineNo
                 , Sku
                 , SKUDESCR
                 , UserDefine03
                 , ODUserDefine04
                 , Tax01
                 , ExtendedPrice
                 , UnitPrice
                 , Notes
                 , Notes2
                 , M_Contact2
                 , MarkforKey
                 , MBOLKey
                 , @c_ReportType
                 , 'Original'
                 , @c_NoOfOrig
                 , CarrierCharges
                 , Userdefine01
            FROM @T_RPT_RAW TR
            WHERE TR.OrderKey = @c_Orderkey

            SET @c_NoOfOrig = @c_NoOfOrig - 1
         END

         WHILE @c_NoOfCopy > 0
         BEGIN
            INSERT INTO @T_RPT_STG (OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company
                                  , B_Address1, B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat
                                  , B_Phone, B_Contact1, C_Company, C_Addresses1, C_Addresses2, C_Phone, UserDefine04, OrderInfo02
                                  , OrderInfo01, OrderInfo10, OrderInfo09, OrderInfo03, OrderInfo04, OrderInfo07
                                  , OrderInfo08, PayableAmount, M_Contact1, BuyerPO, Salesman, M_Company, ExternLineNo
                                  , Sku, SKUDESCR, UserDefine03, ODUserDefine04, Tax01, ExtendedPrice, UnitPrice, Notes
                                  , Notes2, M_Contact2, MarkforKey, MBOLKey, ReportType, CopyType, Copies, CarrierCharges, Userdefine01)
            SELECT OrderKey
                 , InvoiceNo
                 , UserDefine05
                 , ExternOrderKey
                 , ConsigneeKey
                 , B_Company
                 , B_Address1
                 , B_Address2
                 , B_Address3
                 , B_Address4
                 , B_City
                 , B_State
                 , B_Zip
                 , B_Vat
                 , B_Phone
                 , B_Contact1
                 , C_Company
                 , C_Addresses1
                 , C_Addresses2
                 , C_Phone
                 , UserDefine04
                 , OrderInfo02
                 , OrderInfo01
                 , OrderInfo10
                 , OrderInfo09
                 , OrderInfo03
                 , OrderInfo04
                 , OrderInfo07
                 , OrderInfo08
                 , PayableAmount
                 , M_Contact1
                 , BuyerPO
                 , Salesman
                 , M_Company
                 , ExternLineNo
                 , Sku
                 , SKUDESCR
                 , UserDefine03
                 , ODUserDefine04
                 , Tax01
                 , ExtendedPrice
                 , UnitPrice
                 , Notes
                 , Notes2
                 , M_Contact2
                 , MarkforKey
                 , MBOLKey
                 , @c_ReportType
                 , 'Copy'
                 , @c_NoOfCopy
                 , CarrierCharges
                 , Userdefine01
            FROM @T_RPT_RAW TR
            WHERE TR.OrderKey = @c_Orderkey

            SET @c_NoOfCopy = @c_NoOfCopy - 1
         END

         FETCH NEXT FROM CUR_SPLIT
         INTO @c_ReportType
            , @c_NoOfOrig
            , @c_NoOfCopy
      END
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT

      FETCH NEXT FROM CUR_LOOP
      INTO @c_Orderkey
         , @c_MarkForKey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   INSERT INTO @T_RPT_OUTPUT (OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company, B_Address1
                            , B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat, B_Phone, B_Contact1
                            , C_Company
                            , C_Addresses1, C_Addresses2, C_Phone, UserDefine04, OrderInfo02, OrderInfo01, OrderInfo10
                            , OrderInfo09, OrderInfo03, OrderInfo04, OrderInfo07, OrderInfo08, PayableAmount
                            , M_Contact1, BuyerPO, Salesman, M_Company, ExternLineNo, Sku, SKUDESCR, UserDefine03
                            , ODUserDefine04, Tax01, ExtendedPrice, UnitPrice, Notes, Notes2, M_Contact2, MarkforKey
                            , MBOLKey, ReportType, CopyTypeENG, CopyTypeTHA, PageGroup, ReportTitleENG, ReportTitleTHA
                            , AmountENG, AmountTHA, DummyLine, CarrierCharges, Userdefine01)
   SELECT OrderKey
        , InvoiceNo
        , UserDefine05
        , ExternOrderKey
        , ConsigneeKey
        , B_Company
        , B_Address1
        , B_Address2
        , B_Address3
        , B_Address4
        , B_City
        , B_State
        , B_Zip
        , B_Vat
        , B_Phone
        , B_Contact1
        , C_Company
        , C_Addresses1
        , C_Addresses2
        , C_Phone
        , UserDefine04
        , OrderInfo02
        , OrderInfo01
        , OrderInfo10
        , OrderInfo09
        , CASE WHEN ISNUMERIC(OrderInfo03) = 1 THEN CAST(FORMAT(CAST(OrderInfo03 AS FLOAT), '#,##0.00') AS NVARCHAR)
               ELSE OrderInfo03 END AS OrderInfo03
        , CASE WHEN ISNUMERIC(OrderInfo04) = 1 THEN CAST(FORMAT(CAST(OrderInfo04 AS FLOAT), '#,##0.00') AS NVARCHAR)
               ELSE OrderInfo04 END AS OrderInfo04
        , CASE WHEN ISNUMERIC(OrderInfo07) = 1 THEN CAST(FORMAT(CAST(OrderInfo07 AS FLOAT), '#,##0.00') AS NVARCHAR)
               ELSE OrderInfo07 END AS OrderInfo07
        , CASE WHEN ISNUMERIC(OrderInfo08) = 1 THEN CAST(FORMAT(CAST(OrderInfo08 AS FLOAT), '#,##0.00') AS NVARCHAR)
               ELSE OrderInfo08 END AS OrderInfo08
        , PayableAmount
        , M_Contact1
        , BuyerPO
        , Salesman
        , M_Company
        , ExternLineNo
        , Sku
        , SKUDESCR
        , UserDefine03
        , ODUserDefine04
        , Tax01
        , ExtendedPrice
        , UnitPrice
        , Notes
        , Notes2
        , M_Contact2
        , MarkforKey
        , MBOLKey
        , ReportType
        , CopyTypeENG = CopyType
        , CopyTypeTHA = CASE WHEN CopyType = N'Original' THEN N'ต้นฉบับ'
                             WHEN CopyType = N'Copy' THEN N'สำเนา'
                             ELSE N'' END
        --, (ROW_NUMBER() OVER (PARTITION BY OrderKey
        --                                 , ReportType
        --                                 , CopyType
        --                                 , ExternLineNo
        --                                 , Sku
        --                      ORDER BY OrderKey
        --                             , ReportType
        --                             , CASE WHEN CopyType = 'Original' THEN 1
        --                                    ELSE 2 END
        --                             , ExternLineNo
        --                             , Sku)) AS PageGroup
        , PageGroup = Copies
        , ReportTitleENG = CASE WHEN ReportType = '1' THEN N'Invoice/Tax Invoice/Delivery Note'
                                WHEN ReportType = '2' THEN N'Receipt'
                                WHEN ReportType = '3' THEN N'Billing Cover Sheet'
                                ELSE N'' END
        , ReportTitleTHA = CASE WHEN ReportType = '1' THEN N'ใบแจ้งหนี้/ใบกำกับภาษี/ใบส่งของ'
                                WHEN ReportType = '2' THEN N'ใบเสร็จรับเงิน'
                                WHEN ReportType = '3' THEN N'ใบวางบิล'
                                ELSE N'' END
        , AmountENG = '(' + dbo.fnc_NumberToWords(PayableAmount, '', 'Baht', 'Satang', '') + ')'
        , AmountTHA = '(' + dbo.fnc_NumberToThai(PayableAmount, N'บาท', N'สตางค์') + ')'
        , 'N'
        , CarrierCharges
        , Userdefine01
   FROM @T_RPT_STG

   DECLARE CUR_DUMMY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TR.OrderKey
        , TR.ReportType
        , TR.CopyTypeENG
        , TR.PageGroup
        , COUNT(1)
   FROM @T_RPT_OUTPUT TR
   GROUP BY TR.OrderKey
          , TR.ReportType
          , TR.CopyTypeENG
          , TR.PageGroup
   ORDER BY TR.OrderKey

   OPEN CUR_DUMMY

   FETCH NEXT FROM CUR_DUMMY
   INTO @c_Orderkey
      , @c_ReportType
      , @c_CopyType
      , @n_PageGroup
      , @n_MaxRec

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_MaxRec < @n_MaxLineno
      BEGIN
         SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

         WHILE (@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
         BEGIN
            INSERT INTO @T_RPT_OUTPUT (OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company
                                     , B_Address1, B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat
                                     , B_Phone, B_Contact1, C_Company, C_Addresses1, C_Addresses2, C_Phone, UserDefine04
                                     , OrderInfo02, OrderInfo01, OrderInfo10, OrderInfo09, OrderInfo03, OrderInfo04
                                     , OrderInfo07, OrderInfo08, PayableAmount, M_Contact1, BuyerPO, Salesman
                                     , M_Company, ExternLineNo, Sku, SKUDESCR, UserDefine03, ODUserDefine04, Tax01
                                     , ExtendedPrice, UnitPrice, Notes, Notes2, M_Contact2, MarkforKey, MBOLKey
                                     , ReportType, CopyTypeENG, CopyTypeTHA, PageGroup, ReportTitleENG, ReportTitleTHA
                                     , AmountENG, AmountTHA, DummyLine, CarrierCharges, Userdefine01)
            SELECT TOP 1 OrderKey
                       , InvoiceNo
                       , UserDefine05
                       , ExternOrderKey
                       , ConsigneeKey
                       , B_Company
                       , B_Address1
                       , B_Address2
                       , B_Address3
                       , B_Address4
                       , B_City
                       , B_State
                       , B_Zip
                       , B_Vat
                       , B_Phone
                       , B_Contact1
                       , C_Company
                       , C_Addresses1
                       , C_Addresses2
                       , C_Phone
                       , UserDefine04
                       , OrderInfo02
                       , OrderInfo01
                       , OrderInfo10
                       , OrderInfo09
                       , OrderInfo03
                       , OrderInfo04
                       , OrderInfo07
                       , OrderInfo08
                       , PayableAmount
                       , M_Contact1
                       , BuyerPO
                       , Salesman
                       , M_Company
                       , NULL
                       , NULL
                       , NULL
                       , NULL
                       , NULL
                       , NULL
                       , NULL
                       , NULL
                       , Notes
                       , Notes2
                       , M_Contact2
                       , MarkforKey
                       , MBOLKey
                       , ReportType
                       , CopyTypeENG
                       , CopyTypeTHA
                       , PageGroup
                       , ReportTitleENG
                       , ReportTitleTHA
                       , AmountENG
                       , AmountTHA
                       , 'Y'
                       , CarrierCharges
                       , NULL
            FROM @T_RPT_OUTPUT
            WHERE OrderKey = @c_Orderkey
            AND   CopyTypeENG = @c_CopyType
            AND   PageGroup = @n_PageGroup
            AND   ReportType = @c_ReportType

            SET @n_CurrentRec = @n_CurrentRec + 1
         END
      END
      ELSE
      BEGIN
         INSERT INTO @T_RPT_OUTPUT (OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company
                                     , B_Address1, B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat
                                     , B_Phone, B_Contact1, C_Company, C_Addresses1, C_Addresses2, C_Phone, UserDefine04
                                     , OrderInfo02, OrderInfo01, OrderInfo10, OrderInfo09, OrderInfo03, OrderInfo04
                                     , OrderInfo07, OrderInfo08, PayableAmount, M_Contact1, BuyerPO, Salesman
                                     , M_Company, ExternLineNo, Sku, SKUDESCR, UserDefine03, ODUserDefine04, Tax01
                                     , ExtendedPrice, UnitPrice, Notes, Notes2, M_Contact2, MarkforKey, MBOLKey
                                     , ReportType, CopyTypeENG, CopyTypeTHA, PageGroup, ReportTitleENG, ReportTitleTHA
                                     , AmountENG, AmountTHA, DummyLine, CarrierCharges, Userdefine01)
            SELECT TOP 1 OrderKey
                       , InvoiceNo
                       , UserDefine05
                       , ExternOrderKey
                       , ConsigneeKey
                       , B_Company
                       , B_Address1
                       , B_Address2
                       , B_Address3
                       , B_Address4
                       , B_City
                       , B_State
                       , B_Zip
                       , B_Vat
                       , B_Phone
                       , B_Contact1
                       , C_Company
                       , C_Addresses1
                       , C_Addresses2
                       , C_Phone
                       , UserDefine04
                       , OrderInfo02
                       , OrderInfo01
                       , OrderInfo10
                       , OrderInfo09
                       , OrderInfo03
                       , OrderInfo04
                       , OrderInfo07
                       , OrderInfo08
                       , PayableAmount
                       , M_Contact1
                       , BuyerPO
                       , Salesman
                       , M_Company
                       , NULL
                       , NULL
                       , N'ค่าขนส่ง | Freight'
                       , '1'
                       , 'Job'
                       , NULL
                       , NULL
                       , CarrierCharges
                       , Notes
                       , Notes2
                       , M_Contact2
                       , MarkforKey
                       , MBOLKey
                       , ReportType
                       , CopyTypeENG
                       , CopyTypeTHA
                       , PageGroup
                       , ReportTitleENG
                       , ReportTitleTHA
                       , AmountENG
                       , AmountTHA
                       , 'N'
                       , CarrierCharges
                       , NULL
            FROM @T_RPT_OUTPUT
            WHERE OrderKey = @c_Orderkey
            AND   CopyTypeENG = @c_CopyType
            AND   PageGroup = @n_PageGroup
            AND   ReportType = @c_ReportType
      END

      ;WITH CTE AS (SELECT TOP 1 *
                    FROM @T_RPT_OUTPUT TRO
                    WHERE TRO.OrderKey = @c_Orderkey
                    AND   TRO.CopyTypeENG = @c_CopyType
                    AND   TRO.PageGroup = @n_PageGroup
                    AND   TRO.ReportType = @c_ReportType
                    AND   TRO.DummyLine = 'Y')
      UPDATE CTE
      SET CTE.DummyLine = 'N'
        , CTE.SKUDESCR =  N'ค่าขนส่ง | Freight'
        , CTE.UserDefine03 = '1'
        , CTE.ODUserDefine04 = 'Job'
        , CTE.UnitPrice = CTE.CarrierCharges

      FETCH NEXT FROM CUR_DUMMY
      INTO @c_Orderkey
         , @c_ReportType
         , @c_CopyType
         , @n_PageGroup
         , @n_MaxRec
   END
   CLOSE CUR_DUMMY
   DEALLOCATE CUR_DUMMY

   QUIT_SP:
   SELECT OrderKey
        , InvoiceNo
        , UserDefine05
        , SUBSTRING(ExternOrderKey,CHARINDEX('-',ExternOrderKey)+1,50) AS ExternOrderKey  
        , ConsigneeKey
        , B_Company
        , B_Address1
        , B_Address2
        , B_Address3
        , B_Address4
        , B_City
        , B_State
        , B_Zip
        , B_Vat
        , B_Phone
        , C_Company
        , C_Addresses1 + ' ' + C_Addresses2 AS C_Addresses1
        , '' AS C_Addresses2   --CASE WHEN LEN(C_Addresses2) >= 57 THEN SUBSTRING(C_Addresses2, 1, 57) ELSE C_Addresses2 END AS C_Addresses2
        , '' AS C_Addresses2_EXT   --CASE WHEN LEN(C_Addresses2) >= 57 THEN SUBSTRING(C_Addresses2, 58, LEN(C_Addresses2) - 58 + 1) ELSE C_Phone END AS C_Addresses2_EXT
        , C_Phone
        , UserDefine04
        , OrderInfo02
        , OrderInfo01
        , OrderInfo10
        , OrderInfo09
        , OrderInfo03
        , OrderInfo04
        , OrderInfo07
        , OrderInfo08
        , PayableAmount
        , M_Contact1
        , BuyerPO
        , Salesman
        , M_Company
        , CASE WHEN ISNULL(SKU,'') = '' THEN NULL ELSE
         (ROW_NUMBER() OVER (PARTITION BY ExternOrderKey
                     , ReportType
                     , CopyTypeENG
                     , PageGroup
          ORDER BY ExternOrderKey
                 , ReportType
                 , CASE WHEN CopyTypeENG = 'Original' THEN 1
                        ELSE 2 END
                 , PageGroup
                 , DummyLine
                 , CASE WHEN ExternLineNo IS NULL THEN 20 ELSE 10 END
                 , CAST(ExternLineNo AS INT)
                 , Sku)) END AS ExternLineNo
        , Sku
        , SKUDESCR
        , UserDefine03
        , ODUserDefine04
        , Tax01
        , CASE WHEN ISNULL(ExtendedPrice,0) = 0.00 THEN NULL ELSE ExtendedPrice END AS ExtendedPrice
        , UnitPrice
        , Notes
        , Notes2
        , M_Contact2
        , MarkforKey
        , MBOLKey
        , ReportType
        , CopyTypeENG
        , CopyTypeTHA
        , PageGroup
        , ReportTitleENG
        , ReportTitleTHA
        , AmountENG
        , AmountTHA
        , DummyLine
        , 0 AS SplitPageGrp   --(ROW_NUMBER() OVER (PARTITION BY ExternOrderKey
          --                               , ReportType
          --                               , CopyTypeENG
          --                               , PageGroup
          --                    ORDER BY ExternOrderKey
          --                           , ReportType
          --                           , CASE WHEN CopyTypeENG = 'Original' THEN 1
          --                                  ELSE 2 END
          --                           , PageGroup
          --                           , DummyLine
          --                           , CASE WHEN ExternLineNo IS NULL THEN 20 ELSE 10 END
          --                           , CAST(ExternLineNo AS INT)
          --                           , Sku) - 1) / @n_MaxLineno + 1  AS SplitPageGrp
        , B_Contact1
        , CASE WHEN ISNULL(TRIM(Userdefine01),'0') IN ('0','0.00','') THEN NULL ELSE CAST(TRIM(Userdefine01) AS NVARCHAR) + '%' END AS Userdefine01
   FROM @T_RPT_OUTPUT
   ORDER BY ExternOrderKey
          , ReportType
          , CASE WHEN CopyTypeENG = 'Original' THEN 1
                 ELSE 2 END
          , PageGroup
          , DummyLine
          , CASE WHEN ExternLineNo IS NULL THEN 20 ELSE 10 END
          , CAST(ExternLineNo AS INT)
          , Sku

   EXIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT_PRE') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_SPLIT_PRE
      DEALLOCATE CUR_SPLIT_PRE
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP_PRE') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP_PRE
      DEALLOCATE CUR_LOOP_PRE
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_DUMMY') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_DUMMY
      DEALLOCATE CUR_DUMMY
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_MB_DO_004'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012  
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO