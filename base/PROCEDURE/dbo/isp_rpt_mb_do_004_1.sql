SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DO_004_1                                */
/* Creation Date: 23-Nov-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19983 - TH-Aroma Create Invoice/Billing/Receipt Report  */
/*                                                                      */
/* Called By: RPT_MB_DO_004_2                                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 23-Nov-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_MB_DO_004_1]
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

   DECLARE @n_MaxLineno  INT = 6
         , @n_CurrentRec INT
         , @n_MaxRec     INT
         , @c_CopyType   NVARCHAR(250)
         , @n_PageGroup  INT
         , @c_ReportType NVARCHAR(10)

   DECLARE @T_RPT_RAW AS TABLE
   (
      [RowID]          INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , [OrderKey]       NVARCHAR(10)   NULL
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
    , [B_Phone]        NVARCHAR(50)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Notes]          NVARCHAR(4000) NULL
    , [MarkforKey]     NVARCHAR(15)   NULL
    , [MBOLKey]        NVARCHAR(10)   NULL
    , [UserDefine04]   NVARCHAR(50)   NULL
   )

   DECLARE @T_RPT_STG AS TABLE
   (
      [RowID]          INT NOT NULL
    , [OrderKey]       NVARCHAR(10)   NULL
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
    , [B_Phone]        NVARCHAR(50)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Notes]          NVARCHAR(4000) NULL
    , [MarkforKey]     NVARCHAR(15)   NULL
    , [MBOLKey]        NVARCHAR(10)   NULL
    , [ReportType]     NVARCHAR(1)    NULL
    , [CopyType]       NVARCHAR(30)   NULL
    , [Copies]         INT            NULL
    , [UserDefine04]   NVARCHAR(50)   NULL
   )

   DECLARE @T_RPT_OUTPUT AS TABLE
   (
      [RowID]          INT NOT NULL
    , [OrderKey]       NVARCHAR(10)   NULL
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
    , [B_Phone]        NVARCHAR(50)   NULL
    , [OrderInfo01]    NVARCHAR(30)   NULL
    , [PayableAmount]  FLOAT          NULL
    , [BuyerPO]        NVARCHAR(20)   NULL
    , [Notes]          NVARCHAR(4000) NULL
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
    , [UserDefine04]   NVARCHAR(50)   NULL
   )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''

   IF ISNULL(@c_Mbolkey,'') = '' 
      GOTO QUIT_SP

   INSERT INTO @T_RPT_RAW
   SELECT DISTINCT 
          OH.OrderKey
        , OH.InvoiceNo
        , OH.UserDefine05
        , OH.ExternOrderKey
        , OH.ConsigneeKey
        , TRIM(ISNULL(OH.B_Company, '')) AS B_Company
        , TRIM(ISNULL(OH.B_Address1, '')) AS B_Address1
        , TRIM(ISNULL(OH.B_Address2, '')) AS B_Address2
        , TRIM(ISNULL(OH.B_Address3, '')) AS B_Address3
        , TRIM(ISNULL(OH.B_Address4, '')) AS B_Address4
        , TRIM(ISNULL(OH.B_State, '')) AS B_State
        , TRIM(ISNULL(OH.B_City, '')) AS B_City
        , TRIM(ISNULL(OH.B_Zip, '')) AS B_Zip
        , TRIM(ISNULL(OH.B_Vat, '')) AS B_Vat
        , TRIM(ISNULL(OH.B_Phone1, '')) + '.' + TRIM(ISNULL(OH.B_Phone2, '')) AS B_Phone
        , TRIM(ISNULL(OIF.OrderInfo01, '')) AS OrderInfo01
        , ISNULL(OIF.PayableAmount, 0) AS PayableAmount
        , OH.BuyerPO
        , TRIM(ISNULL(OH.Notes, '')) AS Notes
        , OH.MarkforKey
        , OH.MBOLKey
        , OH.UserDefine04
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   LEFT JOIN OrderInfo OIF (NOLOCK) ON OH.OrderKey = OIF.OrderKey
   WHERE OH.MBOLKey = @c_Mbolkey

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
      DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LEFT(TRIM(FDS.ColValue), 1)
                    , SUBSTRING(TRIM(FDS.ColValue), 2, 1)
                    , RIGHT(TRIM(FDS.ColValue), 1)
      FROM dbo.fnc_DelimSplit('|', @c_MarkForKey) FDS
      WHERE LEFT(TRIM(FDS.ColValue), 1) IN ( 3 )
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
            INSERT INTO @T_RPT_STG (RowID, OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company, B_Address1
                                  , B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat, B_Phone, OrderInfo01
                                  , PayableAmount, BuyerPO, Notes, MarkforKey, MBOLKey, ReportType, CopyType, Copies, UserDefine04)
            SELECT RowID
                 , OrderKey
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
                 , OrderInfo01
                 , PayableAmount
                 , BuyerPO
                 , Notes
                 , MarkforKey
                 , MBOLKey
                 , @c_ReportType
                 , 'Original'
                 , @c_NoOfOrig
                 , UserDefine04
            FROM @T_RPT_RAW TR
            WHERE TR.OrderKey = @c_Orderkey

            SET @c_NoOfOrig = @c_NoOfOrig - 1
         END

         WHILE @c_NoOfCopy > 0
         BEGIN
            INSERT INTO @T_RPT_STG (RowID, OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company, B_Address1
                                  , B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat, B_Phone, OrderInfo01
                                  , PayableAmount, BuyerPO, Notes, MarkforKey, MBOLKey, ReportType, CopyType, Copies, UserDefine04)
            SELECT RowID
                 , OrderKey
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
                 , OrderInfo01
                 , PayableAmount
                 , BuyerPO
                 , Notes
                 , MarkforKey
                 , MBOLKey
                 , @c_ReportType
                 , 'Copy'
                 , @c_NoOfCopy
                 , UserDefine04
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

   INSERT INTO @T_RPT_OUTPUT (RowID, OrderKey, InvoiceNo, UserDefine05, ExternOrderKey, ConsigneeKey, B_Company, B_Address1
                            , B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Vat, B_Phone, OrderInfo01
                            , PayableAmount, BuyerPO, Notes, MarkforKey, MBOLKey, ReportType, CopyTypeENG, CopyTypeTHA
                            , PageGroup, ReportTitleENG, ReportTitleTHA, AmountENG, AmountTHA, DummyLine, UserDefine04)
   SELECT RowID
        , OrderKey
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
        , OrderInfo01
        , PayableAmount
        , BuyerPO
        , Notes
        , MarkforKey
        , MBOLKey
        , ReportType
        , CopyTypeENG = CopyType
        , CopyTypeTHA = CASE WHEN CopyType = N'Original' THEN N'ต้นฉบับ'
                             WHEN CopyType = N'Copy' THEN N'สำเนา'
                             ELSE N'' END
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
        , UserDefine04
   FROM @T_RPT_STG

   QUIT_SP:
   SELECT ROW_NUMBER() OVER (PARTITION BY ExternOrderKey
                                        , ReportType
                                        , CopyTypeENG
                                        , PageGroup
                             ORDER BY OrderKey
                                    , ReportType
                                    , CASE WHEN CopyTypeENG = 'Original' THEN 1
                                           ELSE 2 END
                                    , PageGroup
                                    , DummyLine) AS RowID
        , OrderKey
        , InvoiceNo
        , UserDefine05
        , SUBSTRING(ExternOrderKey,CHARINDEX('-',ExternOrderKey)+1,50) AS ExternOrderKey  
        , ConsigneeKey
        , B_Company
        , B_Address1 + ' ' + B_Address2 + ' ' + B_Address3 + ' ' + 
          B_City + ' ' + B_State + ' ' + B_Zip AS B_Addresses
        , B_Phone
        , B_Vat
        , OrderInfo01
        , PayableAmount
        , BuyerPO
        , Notes
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
        , UserDefine04
   FROM @T_RPT_OUTPUT
   ORDER BY OrderKey
          , ReportType
          , CASE WHEN CopyTypeENG = 'Original' THEN 1
                 ELSE 2 END
          , PageGroup
          , DummyLine

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

END -- procedure

GO