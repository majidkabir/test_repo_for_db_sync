SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_200001_10              */
/* Creation Date: 12-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into SO target table              */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore SO                */
/*                           @c_InParm1 =  '1'  SO update is allow      */
/*                           @c_InParm1 =  '2'  Insert new SO only      */
/*               ExplodeBOM  @c_InParm2 =  '0'  Turn Off                */
/*                           @c_InParm2 =  '1'  Turn On                 */
/*  Allow Insert TrackingNo  @c_InParm3 =  '0'  Turn Off                */
/*                           @c_InParm3 =  '1'  Turn On                 */
/*        Update Print Flag  @c_InParm4 =  '0'  Turn Off                */
/*                           @c_InParm4 =  '1'  Turn On                 */
/* Enable ExternLineNo*1000  @c_InParm5 =  '0'  Turn Off                */
/*                           @c_InParm5 =  '1'  Turn On                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo       INT
         , @c_Storerkey      NVARCHAR(15)
         , @c_ExternOrderKey NVARCHAR(50)
         , @c_splitOrder     NVARCHAR(10)
         , @c_Orderkey       NVARCHAR(10)
         , @c_SKU            NVARCHAR(20)
         , @n_Qty            INT
         , @c_UOM            NVARCHAR(10)
         , @c_Packkey        NVARCHAR(10)
         , @n_SUMQty         INT
         , @n_iNo            INT
         , @n_GetQty         INT
         , @n_CaseCnt        FLOAT
         , @c_TargetDBName   NVARCHAR(10)
         , @c_OrderGrp       NVARCHAR(20)
         , @c_LineNum        NVARCHAR(20)
         , @i                INT
         , @n_TtlLen         INT
         , @c_ttlMsg         NVARCHAR(250);

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID);

   SET @n_StartTCnt = @@TRANCOUNT;
   SET @c_TargetDBName = DB_NAME();

   DECLARE C_SO_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
        , ExternOrderkey
        , splitOrder
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   GROUP BY Storerkey
          , ExternOrderkey
          , splitOrder;

   OPEN C_SO_HDR;
   FETCH NEXT FROM C_SO_HDR
   INTO @c_Storerkey
      , @c_ExternOrderKey
      , @c_splitOrder;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN;

      SET @c_ttlMsg = N'';
      SET @c_Orderkey = N'';

      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo                 = @n_BatchNo
      AND   STG_Status                    = '1'
      AND   Storerkey                     = @c_Storerkey
      AND   ExternOrderkey                = @c_ExternOrderKey
      AND   ISNULL(RTRIM(splitOrder), '') = ISNULL(RTRIM(@c_splitOrder), '')
      ORDER BY STG_SeqNo ASC;


      SELECT @c_Orderkey = OrderKey
           , @c_OrderGrp = OrderGroup
      FROM dbo.V_ORDERS WITH (NOLOCK)
      WHERE ExternOrderKey = @c_ExternOrderKey
      AND   StorerKey        = @c_Storerkey;

      IF @b_Debug = 1
      BEGIN
         SELECT '@c_OrderKey : ' + @c_Orderkey;
         SELECT '@OrderGroup : ' + @c_OrderGrp;
      END;

      IF  @c_InParm1 = '1'
      AND @c_Orderkey <> ''
      BEGIN --SO  
         UPDATE Ord WITH (ROWLOCK)
         SET Ord.OrderDate = ISNULL(STG.OrderDate, GETDATE())
           , Ord.DeliveryDate = ISNULL(STG.DeliveryDate, GETDATE())
           , Ord.Priority = ISNULL(STG.Priority, '5')
           , Ord.ConsigneeKey = ISNULL(RTRIM(STG.Consigneekey), '')
           , Ord.C_contact1 = STG.C_Contact1
           , Ord.C_Contact2 = STG.C_Contact2
           , Ord.C_Company = STG.C_Company
           , Ord.C_Address1 = STG.C_Address1
           , Ord.C_Address2 = STG.C_Address2
           , Ord.C_Address3 = STG.C_Address3
           , Ord.C_Address4 = STG.C_Address4
           , Ord.C_City = STG.C_City
           , Ord.C_State = STG.C_State
           , Ord.C_Zip = STG.C_Zip
           , Ord.C_Country = STG.C_Country
           , Ord.C_ISOCntryCode = STG.C_ISOCntryCode
           , Ord.C_Phone1 = STG.C_Phone1
           , Ord.C_Phone2 = STG.C_Phone2
           , Ord.C_Fax1 = STG.C_Fax1
           , Ord.C_Fax2 = STG.C_Fax2
           , Ord.C_vat = STG.C_vat
           , Ord.BuyerPO = STG.BuyerPO
           , Ord.BillToKey = ISNULL(STG.BillToKey, '')
           , Ord.B_contact1 = STG.B_Contact1
           , Ord.B_Contact2 = STG.B_Contact2
           , Ord.B_Company = STG.B_Company
           , Ord.B_Address1 = STG.B_Address1
           , Ord.B_Address2 = STG.B_Address2
           , Ord.B_Address3 = STG.B_Address3
           , Ord.B_Address4 = STG.B_Address4
           , Ord.B_City = STG.B_City
           , Ord.B_State = STG.B_State
           , Ord.B_Zip = STG.B_Zip
           , Ord.B_Country = STG.B_Country
           , Ord.B_ISOCntryCode = STG.B_ISOCntryCode
           , Ord.B_Phone1 = STG.B_Phone1
           , Ord.B_Phone2 = STG.B_Phone2
           , Ord.B_Fax1 = STG.B_Fax1
           , Ord.B_Fax2 = STG.B_Fax2
           , Ord.B_Vat = STG.B_Vat
           , Ord.IncoTerm = STG.IncoTerm
           , Ord.PmtTerm = STG.PmtTerm
           , Ord.DischargePlace = STG.DischargePlace
           , Ord.DeliveryPlace = STG.DeliveryPlace
           , Ord.IntermodalVehicle = ISNULL(STG.IntermodalVehicle, '')
           , Ord.CountryOfOrigin = STG.CountryOfOrigin
           , Ord.CountryDestination = STG.CountryDestination
           , Ord.UpdateSource = ISNULL(STG.UpdateSource, '0')
           , Ord.Type = ISNULL(STG.Type, '0')
           , Ord.OrderGroup = ISNULL(STG.OrderGroup, '')
           , Ord.Door = ISNULL(STG.Door, '99')
           , Ord.Route = ISNULL(STG.Route, '99')
           , Ord.Stop = ISNULL(STG.Stop, '99')
           , Ord.Notes = CAST(STG.Notes AS NVARCHAR(255))
           , Ord.ContainerType = STG.ContainerType
           , Ord.ContainerQty = STG.ContainerQty
           , Ord.BilledContainerQty = ISNULL(STG.BilledContainerQty, 0)
           , Ord.InvoiceNo = ISNULL(STG.InvoiceNo, '')
           , Ord.InvoiceAmount = ISNULL(STG.InvoiceAmount, 0)
           , Ord.Salesman = ISNULL(STG.Salesman, '')
           , Ord.GrossWeight = ISNULL(STG.HGrossWeight, 0)
           , Ord.Capacity = ISNULL(STG.HCapacity, 0)
           , Ord.Rdd = ISNULL(STG.Rdd, '')
           , Ord.Notes2 = CAST(STG.Notes2 AS NVARCHAR(255))
           , Ord.SectionKey = STG.SectionKey
           , Ord.Facility = STG.Facility
           , Ord.LabelPrice = STG.LabelPrice
           , Ord.POKey = ISNULL(STG.POKey, '')
           , Ord.ExternPOKey = ISNULL(STG.ExternPOKey, '')
           , Ord.ShipperKey = ISNULL(STG.Shipperkey, '')
           , Ord.XDockFlag = ISNULL(STG.XDockFlag, '0')
           , Ord.UserDefine01 = ISNULL(STG.HUdef01, '')
           , Ord.UserDefine02 = ISNULL(STG.HUdef02, '')
           , Ord.UserDefine03 = ISNULL(STG.HUdef03, '')
           , Ord.UserDefine04 = ISNULL(STG.HUdef04, '')
           , Ord.UserDefine05 = ISNULL(STG.HUdef05, '')
           , Ord.UserDefine06 = STG.HUdef06
           , Ord.UserDefine07 = STG.HUdef07
           , Ord.UserDefine08 = ISNULL(STG.HUdef08, 'N')
           , Ord.UserDefine09 = ISNULL(STG.HUdef09, '')
           , Ord.UserDefine10 = ISNULL(STG.HUdef10, '')
           , Ord.Issued = STG.Issued
           , Ord.DeliveryNote = STG.DeliveryNote
           , Ord.xdockpokey = STG.xdockpokey
           , Ord.SpecialHandling = ISNULL(STG.SpecialHandling, '5')
           , Ord.RoutingTool = STG.RoutingTool
           , Ord.MarkforKey = ISNULL(STG.Markforkey, '')
           , Ord.M_Contact1 = ISNULL(STG.M_Contact1, '')
           , Ord.M_Contact2 = ISNULL(STG.M_Contact2, '')
           , Ord.M_Company = ISNULL(STG.M_Company, '')
           , Ord.M_Address1 = ISNULL(STG.M_Address1, '')
           , Ord.M_Address2 = ISNULL(STG.M_Address2, '')
           , Ord.M_Address3 = ISNULL(STG.M_Address3, '')
           , Ord.M_Address4 = ISNULL(STG.M_Address4, '')
           , Ord.M_City = ISNULL(STG.M_City, '')
           , Ord.M_State = ISNULL(STG.M_State, '')
           , Ord.M_Zip = ISNULL(STG.M_Zip, '')
           , Ord.M_Country = ISNULL(STG.M_Country, '')
           , Ord.M_ISOCntryCode = ISNULL(STG.M_ISOCntryCode, '')
           , Ord.M_Phone1 = ISNULL(STG.M_Phone1, '')
           , Ord.M_Phone2 = ISNULL(STG.M_Phone2, '')
           , Ord.M_Fax1 = ISNULL(STG.M_Fax1, '')
           , Ord.M_Fax2 = ISNULL(STG.M_Fax2, '')
           , Ord.M_vat = ISNULL(STG.M_Vat, '')
           , Ord.PrintFlag = CASE @c_InParm4 WHEN '1' THEN RTRIM(ISNULL(STG.PrintFlag, ''))
                                             ELSE ISNULL(Ord.PrintFlag, '')
                             END
           , Ord.MBOLKey = ISNULL(STG.mbolkey, '')
           , Ord.PODArrive = ISNULL(STG.PODArrive, '')
           , Ord.PODCust = ISNULL(STG.PODCust, '')
           , Ord.PODReject = ISNULL(STG.PODReject, '')
           , Ord.DocType = ISNULL(STG.DocType, 'N')
           , Ord.CurrencyCode = ISNULL(STG.CurrencyCode, 'N')
           , Ord.EditWho = @c_Username
           , Ord.EditDate = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS        Ord
         ON (
             STG.ExternOrderkey = Ord.ExternOrderKey
         AND STG.Storerkey  = Ord.StorerKey
         )
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         DELETE FROM dbo.ORDERDETAIL
         WHERE OrderKey = @c_Orderkey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE
      BEGIN

         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'Order'
                            , @fieldlength = 10
                            , @keystring = @c_Orderkey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_ErrMsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new Order Key from nspg_getkey. (isp_SCE_DL_GENERIC_SO_RULES_200001_10)';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         IF @b_Debug = 1
         BEGIN
            SELECT 'New @c_OrderKey : ' + @c_Orderkey;
         END;

         INSERT INTO dbo.ORDERS
         (
            OrderKey
          , StorerKey
          , ExternOrderKey
          , OrderDate
          , DeliveryDate
          , Priority
          , ConsigneeKey
          , C_contact1
          , C_Contact2
          , C_Company
          , C_Address1
          , C_Address2
          , C_Address3
          , C_Address4
          , C_City
          , C_State
          , C_Zip
          , C_Country
          , C_ISOCntryCode
          , C_Phone1
          , C_Phone2
          , C_Fax1
          , C_Fax2
          , C_vat
          , BuyerPO
          , BillToKey
          , B_contact1
          , B_Contact2
          , B_Company
          , B_Address1
          , B_Address2
          , B_Address3
          , B_Address4
          , B_City
          , B_State
          , B_Zip
          , B_Country
          , B_ISOCntryCode
          , B_Phone1
          , B_Phone2
          , B_Fax1
          , B_Fax2
          , B_Vat
          , IncoTerm
          , PmtTerm
          , Status
          , DischargePlace
          , DeliveryPlace
          , IntermodalVehicle
          , CountryOfOrigin
          , CountryDestination
          , UpdateSource
          , Type
          , OrderGroup
          , Door
          , Route
          , Stop
          , Notes
          , ContainerType
          , ContainerQty
          , BilledContainerQty
          , InvoiceNo
          , InvoiceAmount
          , Salesman
          , GrossWeight
          , Capacity
          , Rdd
          , Notes2
          , SectionKey
          , Facility
          , LabelPrice
          , POKey
          , ExternPOKey
          , ShipperKey
          , XDockFlag
          , UserDefine01
          , UserDefine02
          , UserDefine03
          , UserDefine04
          , UserDefine05
          , UserDefine06
          , UserDefine07
          , UserDefine08
          , UserDefine09
          , UserDefine10
          , Issued
          , DeliveryNote
          , xdockpokey
          , SpecialHandling
          , RoutingTool
          , MarkforKey
          , M_Contact1
          , M_Contact2
          , M_Company
          , M_Address1
          , M_Address2
          , M_Address3
          , M_Address4
          , M_City
          , M_State
          , M_Zip
          , M_Country
          , M_ISOCntryCode
          , M_Phone1
          , M_Phone2
          , M_Fax1
          , M_Fax2
          , M_vat
          , PrintFlag
          , MBOLKey
          , PODArrive
          , PODCust
          , PODReject
          , DocType
          , TrackingNo
          , CurrencyCode
          , ECOM_PRESALE_FLAG
          , ECOM_SINGLE_Flag
          , SOStatus
          , RTNTrackingNo
          , BizUnit
          , AddWho
          , EditWho
         )
         SELECT @c_Orderkey
              , STG.Storerkey
              , STG.ExternOrderkey
              , ISNULL(STG.OrderDate, GETDATE())
              , ISNULL(STG.DeliveryDate, GETDATE())
              , ISNULL(STG.Priority, '5')
              , ISNULL(RTRIM(STG.Consigneekey), '')
              , STG.C_Contact1
              , STG.C_Contact2
              , STG.C_Company
              , STG.C_Address1
              , STG.C_Address2
              , STG.C_Address3
              , STG.C_Address4
              , STG.C_City
              , STG.C_State
              , STG.C_Zip
              , STG.C_Country
              , STG.C_ISOCntryCode
              , STG.C_Phone1
              , STG.C_Phone2
              , STG.C_Fax1
              , STG.C_Fax2
              , STG.C_vat
              , STG.BuyerPO
              , ISNULL(STG.BillToKey, '')
              , STG.B_Contact1
              , STG.B_Contact2
              , STG.B_Company
              , STG.B_Address1
              , STG.B_Address2
              , STG.B_Address3
              , STG.B_Address4
              , STG.B_City
              , STG.B_State
              , STG.B_Zip
              , STG.B_Country
              , STG.B_ISOCntryCode
              , STG.B_Phone1
              , STG.B_Phone2
              , STG.B_Fax1
              , STG.B_Fax2
              , STG.B_Vat
              , STG.IncoTerm
              , STG.PmtTerm
              , '0'
              , STG.DischargePlace
              , STG.DeliveryPlace
              , ISNULL(STG.IntermodalVehicle, '')
              , STG.CountryOfOrigin
              , STG.CountryDestination
              , ISNULL(STG.UpdateSource, '0')
              , ISNULL(STG.Type, '0')
              , ISNULL(STG.OrderGroup, '')
              , ISNULL(STG.Door, '99')
              , ISNULL(STG.Route, '99')
              , ISNULL(STG.Stop, '99')
              , CAST(STG.Notes AS NVARCHAR(255))
              , STG.ContainerType
              , STG.ContainerQty
              , ISNULL(STG.BilledContainerQty, 0)
              , ISNULL(STG.InvoiceNo, '')
              , ISNULL(STG.InvoiceAmount, 0)
              , ISNULL(STG.Salesman, '')
              , ISNULL(STG.HGrossWeight, 0)
              , ISNULL(STG.HCapacity, 0)
              , ISNULL(STG.Rdd, '')
              , CAST(STG.Notes2 AS NVARCHAR(255))
              , STG.SectionKey
              , STG.Facility
              , STG.LabelPrice
              , ISNULL(STG.POKey, '')
              , ISNULL(STG.ExternPOKey, '')
              , ISNULL(STG.Shipperkey, '')
              , ISNULL(STG.XDockFlag, '0')
              , ISNULL(STG.HUdef01, '')
              , ISNULL(STG.HUdef02, '')
              , ISNULL(STG.HUdef03, '')
              , ISNULL(STG.HUdef04, '')
              , ISNULL(STG.HUdef05, '')
              , STG.HUdef06
              , STG.HUdef07
              , ISNULL(STG.HUdef08, 'N')
              , ISNULL(STG.HUdef09, '')
              , ISNULL(STG.HUdef10, '')
              , STG.Issued
              , STG.DeliveryNote
              , STG.xdockpokey
              , ISNULL(STG.SpecialHandling, '5')
              , STG.RoutingTool
              , ISNULL(STG.Markforkey, '')
              , STG.M_Contact1
              , STG.M_Contact2
              , STG.M_Company
              , STG.M_Address1
              , STG.M_Address2
              , STG.M_Address3
              , STG.M_Address4
              , STG.M_City
              , STG.M_State
              , STG.M_Zip
              , STG.M_Country
              , STG.M_ISOCntryCode
              , STG.M_Phone1
              , STG.M_Phone2
              , STG.M_Fax1
              , STG.M_Fax2
              , STG.M_Vat
              , CASE @c_InParm4 WHEN '1' THEN RTRIM(ISNULL(STG.PrintFlag, 'N'))
                                ELSE 'N'
                END
              , ISNULL(STG.mbolkey, '')
              , STG.PODArrive
              , STG.PODCust
              , STG.PODReject
              , ISNULL(STG.DocType, 'N')
              , CASE WHEN @c_InParm3 = '1'
                     AND  ISNULL(STG.TrackingNo, '') <> '' THEN STG.TrackingNo
                     ELSE ''
                END
              , STG.CurrencyCode
              , ISNULL(STG.ECOM_PRESALE_FLAG, '')
              , ISNULL(STG.ECOM_SINGLE_Flag, '')
              , ISNULL(STG.SOStatus, '0')
              , ISNULL(STG.RTNTrackingNo, '')
              , ISNULL(STG.BizUnit, '')
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
      SET OrderKey = @c_Orderkey
        , AddWho = @c_Username
        , Editdate = GETDATE()
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      IF EXISTS (
      SELECT 1
      FROM dbo.V_ORDERDETAIL WITH (NOLOCK)
      WHERE OrderKey = @c_Orderkey
      )
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 100002;
         SET @c_ErrMsg = 'Logic Error. Unable to insert the ORDERDETAIL. OrderKey(' + @c_Orderkey
                         + '). (isp_SCE_DL_GENERIC_SO_RULES_200001_10)';
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      SET @n_SUMQty = 0;
      SET @n_iNo = 0;

      DECLARE C_Detail_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , ISNULL(RTRIM(SKU), '')
           , ISNULL(OpenQty, 0)
           , ISNULL(RTRIM(Storerkey), '')
           , ISNULL(RTRIM(UOM), '')
           , ISNULL(RTRIM(Packkey), '')
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo                 = @n_BatchNo
      AND   STG_Status                    = '1'
      AND   Storerkey                     = @c_Storerkey
      AND   ExternOrderkey                = @c_ExternOrderKey
      AND   ISNULL(RTRIM(splitOrder), '') = ISNULL(RTRIM(@c_splitOrder), '');

      OPEN C_Detail_Record;
      FETCH NEXT FROM C_Detail_Record
      INTO @n_RowRefNo
         , @c_SKU
         , @n_Qty
         , @c_Storerkey
         , @c_UOM
         , @c_Packkey;

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN --C_detail_Record while            

         IF @c_UOM = ''
         OR @c_Packkey = ''
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'UOM or PackKey cannot be null or empty.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         SELECT @n_CaseCnt = CaseCnt
              , @n_GetQty  = CASE @c_UOM WHEN LTRIM(RTRIM(PackUOM1)) THEN CaseCnt * @n_Qty
                                         WHEN LTRIM(RTRIM(PackUOM2)) THEN InnerPack * @n_Qty
                                         WHEN LTRIM(RTRIM(PackUOM3)) THEN Qty * @n_Qty
                                         WHEN LTRIM(RTRIM(PackUOM4)) THEN Pallet * @n_Qty
                                         WHEN LTRIM(RTRIM(PackUOM8)) THEN OtherUnit1 * @n_Qty
                                         WHEN LTRIM(RTRIM(PackUOM9)) THEN OtherUnit2 * @n_Qty
                                         ELSE 0
                             END
         FROM dbo.V_PACK (NOLOCK)
         WHERE PackKey = @c_Packkey
         AND   (
                PackUOM1      = @c_UOM
             OR PackUOM2 = @c_UOM
             OR PackUOM3 = @c_UOM
             OR PackUOM4 = @c_UOM
             OR PackUOM5 = @c_UOM
             OR PackUOM6 = @c_UOM
             OR PackUOM7 = @c_UOM
             OR PackUOM8 = @c_UOM
             OR PackUOM9 = @c_UOM
         );

         IF @b_Debug = 1
         BEGIN
            SELECT 'Open Qty is  : ' + CONVERT(VARCHAR(10), @n_GetQty);
         END;

         /*CS01 End*/

         SET @n_SUMQty += @n_GetQty;
         SET @n_iNo += 1;

         IF @c_InParm2 = '1'
         BEGIN --explorebom   
            SET @i = 0;
            SET @n_TtlLen = 0;
            SET @c_LineNum = N'';
            SET @c_LineNum = CAST(@n_iNo AS NVARCHAR(20));
            SET @n_TtlLen = 5 - LEN(@c_LineNum);
            WHILE @i < (@n_TtlLen)
            BEGIN
               SET @c_LineNum += N'0';
               SET @i += 1;
            END;

            INSERT INTO dbo.ORDERDETAIL
            (
               OrderKey
             , OrderLineNumber
             , ExternOrderKey
             , ExternLineNo
             , Sku
             , StorerKey
             , ManufacturerSku
             , RetailSku
             , AltSku
             , OpenQty
             , UOM
             , PackKey
             , CartonGroup
             , Lot
             , ID
             , Facility
             , Status
             , UnitPrice
             , Tax01
             , Tax02
             , ExtendedPrice
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , Lottable05
             , Lottable06
             , Lottable07
             , Lottable08
             , Lottable09
             , Lottable10
             , Lottable11
             , Lottable12
             , Lottable13
             , Lottable14
             , Lottable15
             , GrossWeight
             , Capacity
             , MinShelfLife
             , UserDefine01
             , UserDefine02
             , UserDefine03
             , UserDefine04
             , UserDefine05
             , UserDefine06
             , UserDefine07
             , UserDefine08
             , UserDefine09
             , UserDefine10
             , POkey
             , ExternPOKey
             , Notes
             , Notes2
             , Channel
             , AddWho
             , EditWho
            )
            SELECT @c_Orderkey
                 , @c_LineNum + CASE WHEN LEN(t2.Sequence) = 1 THEN '0' + LTRIM(RTRIM(t2.Sequence))
                                     ELSE LTRIM(RTRIM(t2.Sequence))
                                END
                 , LEFT(ISNULL(t1.ExternOrderkey, ''), 20)
                 , (CASE @c_InParm5 WHEN '1' THEN CAST(CAST(ISNULL(t1.ExternLineNo, '0') AS FLOAT) * 1000 AS CHAR(10))
                                    ELSE ISNULL(t1.ExternLineNo, '')
                    END
                   )
                 , t2.ComponentSku
                 , ISNULL(@c_Storerkey, '')
                 , ISNULL(t3.MANUFACTURERSKU, '')
                 , ISNULL(t3.RETAILSKU, '')
                 , ISNULL(t3.ALTSKU, '')
                 , @n_GetQty
                 , @c_UOM
                 , @c_Packkey
                 , ISNULL(t1.CartonGroup, '')
                 , ISNULL(t1.Lot, '')
                 , ISNULL(t1.ID, '')
                 , ISNULL(t1.Facility, '')
                 , '0'
                 , ISNULL(t1.UnitPrice, 0)
                 , ISNULL(t1.Tax01, 0)
                 , ISNULL(t1.Tax02, 0)
                 , t1.ExtendedPrice
                 , ISNULL(t1.Lottable01, '')
                 , ISNULL(t1.Lottable02, '')
                 , ISNULL(t1.Lottable03, '')
                 , t1.Lottable04
                 , t1.Lottable05
                 , ISNULL(t1.Lottable06, '')
                 , ISNULL(t1.Lottable07, '')
                 , ISNULL(t1.Lottable08, '')
                 , ISNULL(t1.Lottable09, '')
                 , ISNULL(t1.Lottable10, '')
                 , ISNULL(t1.Lottable11, '')
                 , ISNULL(t1.Lottable11, '')
                 , t1.Lottable13
                 , t1.Lottable14
                 , t1.Lottable15
                 , ISNULL(t1.DGrossWeight, 0)
                 , ISNULL(t1.DCapacity, 0)
                 , ISNULL(t1.MinShelfLife, 0)
                 , t1.DUdef01
                 , t1.DUdef02
                 , t1.DUdef03
                 , t1.DUdef04
                 , t1.DUdef05
                 , t1.DUdef06
                 , t1.DUdef07
                 , t1.DUdef08
                 , t1.DUdef09
                 , t1.DUdef10
                 , t1.POKey
                 , t1.ExternPOKey
                 , t1.DNotes
                 , t1.DNotes2
                 , ISNULL(t1.Channel, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_SO_STG          AS t1 (NOLOCK)
            INNER JOIN dbo.V_BillOfMaterial AS t2 (NOLOCK)
            ON  t1.Storerkey     = t2.Storerkey
            AND t1.SKU          = t2.Sku
            JOIN dbo.V_SKU                  AS t3 (NOLOCK)
            ON  t2.Storerkey     = t3.StorerKey
            AND t2.ComponentSku = t3.Sku
            INNER JOIN dbo.V_SKU            AS t4 (NOLOCK)
            ON  t1.Storerkey     = t4.StorerKey
            AND t1.SKU          = t4.Sku
            WHERE t1.RowRefNo = @n_RowRefNo;
         END; --explorebom            
         ELSE
         BEGIN --B          


            INSERT INTO dbo.ORDERDETAIL
            (
               OrderKey
             , OrderLineNumber
             , ExternOrderKey
             , ExternLineNo
             , Sku
             , StorerKey
             , ManufacturerSku
             , RetailSku
             , AltSku
             , OpenQty
             , UOM
             , PackKey
             , CartonGroup
             , Lot
             , ID
             , Facility
             , Status
             , UnitPrice
             , Tax01
             , Tax02
             , ExtendedPrice
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , Lottable05
             , Lottable06
             , Lottable07
             , Lottable08
             , Lottable09
             , Lottable10
             , Lottable11
             , Lottable12
             , Lottable13
             , Lottable14
             , Lottable15
             , GrossWeight
             , Capacity
             , MinShelfLife
             , UserDefine01
             , UserDefine02
             , UserDefine03
             , UserDefine04
             , UserDefine05
             , UserDefine06
             , UserDefine07
             , UserDefine08
             , UserDefine09
             , UserDefine10
             , POkey
             , ExternPOKey
             , Notes
             , Notes2
             , Channel
             , AddWho
             , EditWho
            )
            SELECT @c_Orderkey
                 , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(10))
                 , LEFT(ISNULL(t1.ExternOrderkey, ''), 20)
                 , (CASE @c_InParm5 WHEN '1' THEN CAST(CAST(ISNULL(t1.ExternLineNo, '0') AS FLOAT) * 1000 AS CHAR(10))
                                    ELSE ISNULL(t1.ExternLineNo, '')
                    END
                   )
                 , ISNULL(@c_SKU, '')
                 , ISNULL(@c_Storerkey, '')
                 , ISNULL(t1.ManufacturerSku, '')
                 , ISNULL(t1.RetailSKU, '')
                 , ISNULL(t1.AltSKU, '')
                 , @n_GetQty
                 , @c_UOM
                 , @c_Packkey
                 , ISNULL(t1.CartonGroup, '')
                 , ISNULL(t1.Lot, '')
                 , ISNULL(t1.ID, '')
                 , ISNULL(t1.Facility, '')
                 , '0'
                 , ISNULL(t1.UnitPrice, 0)
                 , ISNULL(t1.Tax01, 0)
                 , ISNULL(t1.Tax02, 0)
                 , t1.ExtendedPrice
                 , ISNULL(t1.Lottable01, '')
                 , ISNULL(t1.Lottable02, '')
                 , ISNULL(t1.Lottable03, '')
                 , t1.Lottable04
                 , t1.Lottable05
                 , ISNULL(t1.Lottable06, '')
                 , ISNULL(t1.Lottable07, '')
                 , ISNULL(t1.Lottable08, '')
                 , ISNULL(t1.Lottable09, '')
                 , ISNULL(t1.Lottable10, '')
                 , ISNULL(t1.Lottable11, '')
                 , ISNULL(t1.Lottable12, '')
                 , t1.Lottable13
                 , t1.Lottable14
                 , t1.Lottable15
                 , ISNULL(t1.DGrossWeight, 0)
                 , ISNULL(t1.DCapacity, 0)
                 , ISNULL(t1.MinShelfLife, 0)
                 , t1.DUdef01
                 , t1.DUdef02
                 , t1.DUdef03
                 , t1.DUdef04
                 , t1.DUdef05
                 , t1.DUdef06
                 , t1.DUdef07
                 , t1.DUdef08
                 , t1.DUdef09
                 , t1.DUdef10
                 , t1.POKey
                 , t1.ExternPOKey
                 , t1.DNotes
                 , t1.DNotes2
                 , ISNULL(t1.Channel, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_SO_STG AS t1 (NOLOCK)
            INNER JOIN dbo.V_SKU   AS t2 (NOLOCK)
            ON  t1.Storerkey = t2.StorerKey
            AND t1.SKU      = t2.Sku
            INNER JOIN dbo.V_PACK  AS t3 (NOLOCK)
            ON t2.PACKKey   = t3.PackKey
            WHERE t1.RowRefNo = @n_RowRefNo;
         END; --B  

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_Detail_Record
         INTO @n_RowRefNo
            , @c_SKU
            , @n_Qty
            , @c_Storerkey
            , @c_UOM
            , @c_Packkey;
      END;

      CLOSE C_Detail_Record;
      DEALLOCATE C_Detail_Record;

      UPDATE dbo.ORDERS WITH (ROWLOCK)
      SET OpenQty = @n_SUMQty
        , EditDate = GETDATE()
      WHERE OrderKey = @c_Orderkey;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

      FETCH NEXT FROM C_SO_HDR
      INTO @c_Storerkey
         , @c_ExternOrderKey
         , @c_splitOrder;
   END;

   CLOSE C_SO_HDR;
   DEALLOCATE C_SO_HDR;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN;

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;
   END;
   ELSE
   BEGIN
      SET @b_Success = 1;
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN;
      END;
   END;
END;

GO