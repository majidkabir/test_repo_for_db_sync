SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200002_10       */
/* Creation Date: 22-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform update into SO target table             */
/*                                                                      */
/*                                                                      */
/* Usage:        Search Field  @c_InParm1 =  '2' Ignore & Insert New    */
/*                                           '1' Allow UPDATE           */
/*                                           '0' Reject UPDATE          */
/*        Update Order Header  @c_InParm2 =  '0' Turn Off               */
/*                                           '1' Turn On (Status = 0)   */
/*                                           '2' Turn On (Status < 9)   */
/*              Language Code  @c_InParm3 =  'ENG'                      */
/*    Update TBL Order Header  @c_InParm4 =  '1' Turn On '0' Turn Off   */
/*               Update Route  @c_InParm5 =  '1' Turn On '0' Turn Off   */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 22-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 31-Jan-2023  WLChooi   1.1   WMS-21495 - Modify Logic (WL01)         */
/* 02-Mar-2023  WLChooi   1.2   Do not update UDF if blank (WL02)       */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200002_10] (
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_Condition      NVARCHAR(250)

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo           INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_ExternOrderKey     NVARCHAR(50)
         , @c_Loadkey            NVARCHAR(10)
         , @c_OrderGroup         NVARCHAR(20)
         , @c_InvoiceNo          NVARCHAR(20)
         , @c_HUDEF04            NVARCHAR(20)
         , @c_Consigneekey       NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_Orderkey           NVARCHAR(10)
         , @c_RoutingTool        NVARCHAR(30)
         , @d_DeliveryDate       DATETIME
         , @c_IntermodalVehicle  NVARCHAR(30)
         , @c_Shipperkey         NVARCHAR(15)

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
   WHERE SPName = OBJECT_NAME(@@PROCID)

   SET @n_StartTCnt = @@TRANCOUNT

   DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
                 , ExternOrderkey
                 , Loadkey
                 , OrderGroup
                 , InvoiceNo
                 , HUdef04
                 , Consigneekey
                 , SKU
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'

   OPEN CUR_CHECK

   FETCH NEXT FROM CUR_CHECK INTO @c_Storerkey, @c_ExternOrderKey, @c_Loadkey, @c_OrderGroup
                                , @c_InvoiceNo, @c_HUDEF04, @c_Consigneekey, @c_SKU

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Orderkey          = ''
      SET @c_RoutingTool       = ''
      SET @d_DeliveryDate      = ''
      SET @c_IntermodalVehicle = ''
      SET @c_Shipperkey        = ''

      SELECT @c_Orderkey            = OH.Orderkey
           , @c_RoutingTool         = OH.RoutingTool
           , @d_DeliveryDate        = OH.DeliveryDate
           , @c_IntermodalVehicle   = OH.IntermodalVehicle
           , @c_Shipperkey          = OH.ShipperKey
      FROM ORDERS OH (NOLOCK) 
      WHERE OH.ExternOrderKey = @c_ExternOrderKey
      AND OH.StorerKey = @c_Storerkey

      IF @c_InParm1 = '1'
      BEGIN
         IF @c_InParm2 = '0'   --WL01
         BEGIN
            BEGIN TRANSACTION

            UPDATE dbo.Orders
            SET C_Company     = CASE WHEN ISNULL(STG.C_Company, '') = '' THEN Orders.C_Company ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Company, @c_InParm3) END
              , C_Address1    = CASE WHEN ISNULL(STG.C_Address1, '') = '' THEN Orders.C_Address1 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Address1, @c_InParm3) END
              , C_Address2    = CASE WHEN ISNULL(STG.C_Address2, '') = '' THEN Orders.C_Address2 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Address2, @c_InParm3) END
              , C_Address3    = CASE WHEN ISNULL(STG.C_Address3, '') = '' THEN Orders.C_Address3 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Address3, @c_InParm3) END
              , C_Address4    = CASE WHEN ISNULL(STG.C_Address4, '') = '' THEN Orders.C_Address4 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Address4, @c_InParm3) END
              , C_City        = CASE WHEN ISNULL(STG.C_City, '') = '' THEN Orders.C_City ELSE master.dbo.fn_UNICODE2ANSI(STG.C_City, @c_InParm3) END
              , C_Country     = CASE WHEN ISNULL(STG.C_Country, '') = '' THEN Orders.C_Country ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Country, @c_InParm3) END
              , C_Contact1    = CASE WHEN ISNULL(STG.C_Contact1, '') = '' THEN Orders.C_Contact1 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Contact1, @c_InParm3) END
              , C_Contact2    = CASE WHEN ISNULL(STG.C_Contact2, '') = '' THEN Orders.C_Contact2 ELSE master.dbo.fn_UNICODE2ANSI(STG.C_Contact2, @c_InParm3) END
              , C_Phone1      = CASE WHEN ISNULL(STG.C_Phone1, '') = '' THEN Orders.C_Phone1 ELSE STG.C_Phone1 END
              , C_Phone2      = CASE WHEN ISNULL(STG.C_Phone2, '') = '' THEN Orders.C_Phone2 ELSE STG.C_Phone2 END
              , C_State       = CASE WHEN ISNULL(STG.C_State, '') = '' THEN Orders.C_State ELSE STG.C_State END
              , C_Zip         = CASE WHEN ISNULL(STG.C_Zip, '') = '' THEN Orders.C_Zip ELSE STG.C_Zip END
              , Stop          = ISNULL(STG.Stop, Orders.Stop)
              , Doctype       = ISNULL(STG.Doctype, Orders.Doctype)
              , EditDate      = GETDATE()
            FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
            JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey)
            WHERE STG.STG_BatchNo = @n_BatchNo
            AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
            AND ORDERS.[Status] = '0'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
         END
      END
      ELSE
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.Orders
         SET Userdefine06        = CASE WHEN ISNULL(STG.HUdef06, '1900/01/01') = '1900/01/01' THEN Orders.Userdefine06 ELSE STG.HUdef06 END   --WL02
           , DeliveryDate        = ISNULL(STG.DeliveryDate, @d_deliverydate)
           , RoutingTool         = ISNULL(STG.RoutingTool, @c_RoutingTool)
           , IntermodalVehicle   = ISNULL(STG.IntermodalVehicle, @c_IntermodalVehicle)
           , ShipperKey          = ISNULL(STG.ShipperKey, @c_ShipperKey)
           , Stop                = ISNULL(STG.Stop, Orders.Stop)
           , Doctype             = ISNULL(STG.Doctype, Orders.Doctype)
           , TrafficCop          = NULL
           , EditDate            = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.Loadkey = Orders.LoadKey AND STG.Storerkey = Orders.StorerKey)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.Loadkey = @c_Loadkey AND STG.Storerkey = @c_Storerkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      IF @c_InParm2 IN ('1','2') AND @c_InParm4 <> '1'   --WL01
      BEGIN
         BEGIN TRANSACTION

         --WL01 S
         IF @c_InParm2 = '1'
         BEGIN
            UPDATE dbo.ORDERS
            SET Userdefine01  = CASE WHEN ISNULL(STG.HUdef01, '') = '' THEN Orders.Userdefine01 ELSE STG.HUdef01 END   --WL02
              , Userdefine02  = CASE WHEN ISNULL(STG.HUdef02, '') = '' THEN Orders.Userdefine02 ELSE STG.HUdef02 END   --WL02
              , Userdefine03  = CASE WHEN ISNULL(STG.HUdef03, '') = '' THEN Orders.Userdefine03 ELSE STG.HUdef03 END   --WL02
              , Userdefine04  = CASE WHEN ISNULL(STG.HUdef04, '') = '' THEN Orders.Userdefine04 ELSE STG.HUdef04 END   --WL02
              , Userdefine05  = CASE WHEN ISNULL(STG.HUdef05, '') = '' THEN Orders.Userdefine05 ELSE STG.HUdef05 END   --WL02
              , OrderDate     = ISNULL(STG.OrderDate, Orders.OrderDate)
              , OrderGroup    = ISNULL(STG.OrderGroup, '')
              , Notes         = ISNULL(STG.Notes, '')
              , Notes2        = ISNULL(STG.Notes2, '')
              , ShipperKey    = ISNULL(STG.ShipperKey, '')
              , C_Company     = CASE WHEN ISNULL(STG.C_Company, '') = '' THEN Orders.C_Company ELSE STG.C_Company END
              , C_Address1    = CASE WHEN ISNULL(@c_InParm5, '') = '0' THEN CASE WHEN ISNULL(STG.C_Address1,'') = '' THEN '' ELSE STG.C_Address1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address1,'') = '' THEN Orders.C_Address1 ELSE STG.C_Address1 END END
              , C_Address2    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address2,'') = '' THEN '' ELSE STG.C_Address2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address2,'') = '' THEN Orders.C_Address2 ELSE STG.C_Address2 END END
              , C_Address3    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address3,'') = '' THEN '' ELSE STG.C_Address3 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address3,'') = '' THEN Orders.C_Address3 ELSE STG.C_Address3 END END
              , C_Address4    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address4,'') = '' THEN '' ELSE STG.C_Address4 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address4,'') = '' THEN Orders.C_Address4 ELSE STG.C_Address4 END END
              , C_City        = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_City,'') = '' THEN '' ELSE STG.C_City END
                                      ELSE CASE WHEN ISNULL(STG.C_City,'') = '' THEN Orders.C_City ELSE STG.C_City END END
              , C_Country     = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Country,'') = '' THEN '' ELSE STG.C_Country END
                                      ELSE CASE WHEN ISNULL(STG.C_Country,'') = '' THEN Orders.C_Country ELSE STG.C_Country END END
              , C_Contact1    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Contact1,'') = '' THEN '' ELSE STG.C_Contact1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Contact1,'') = '' THEN Orders.C_Contact1 ELSE STG.C_Contact1 END END 
              , C_Contact2    = CASE WHEN ISNULL(@c_InParm5,'') <> '1' THEN CASE WHEN ISNULL(STG.C_Contact2,'') = '' THEN '' ELSE STG.C_Contact2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Contact2,'') = '' THEN Orders.C_Contact2 ELSE STG.C_Contact2 END END   
              , C_Phone1      = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Phone1,'') = '' THEN '' ELSE STG.C_Phone1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Phone1,'') = '' THEN Orders.C_Phone1 ELSE STG.C_Phone1 END END   
              , C_Phone2      = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Phone2,'') = '' THEN '' ELSE STG.C_Phone2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Phone2,'') = '' THEN Orders.C_Phone2 ELSE STG.C_Phone2 END END      
              , C_State       = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_State,'') = '' THEN '' ELSE STG.C_State END
                                      ELSE CASE WHEN ISNULL(STG.C_State,'') = '' THEN Orders.C_State ELSE STG.C_State END END        
              , C_Zip         = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Zip,'') = '' THEN '' ELSE STG.C_Zip END
                                      ELSE CASE WHEN ISNULL(STG.C_Zip,'') = '' THEN Orders.C_Zip ELSE STG.C_Zip END END
              , Route         = CASE WHEN ISNULL(@c_InParm5,'') = '1' THEN CASE WHEN ISNULL(STG.Route,'') = '' THEN Orders.Route ELSE ISNULL(STG.Route,Orders.Route) END
                                      ELSE ISNULL(STG.Route,Orders.Route) END
              , Stop          = ISNULL(STG.Stop, Orders.Stop)
              , Doctype       = ISNULL(STG.Doctype, Orders.Doctype)
              , EditDate      = GETDATE()
            FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
            JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey)
            WHERE STG.STG_BatchNo = @n_BatchNo
            AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
            AND ORDERS.[Status] = '0'
         END
         ELSE
         BEGIN
            UPDATE dbo.ORDERS
            SET Userdefine01  = CASE WHEN ISNULL(STG.HUdef01, '') = '' THEN Orders.Userdefine01 ELSE STG.HUdef01 END   --WL02
              , Userdefine02  = CASE WHEN ISNULL(STG.HUdef02, '') = '' THEN Orders.Userdefine02 ELSE STG.HUdef02 END   --WL02
              , Userdefine03  = CASE WHEN ISNULL(STG.HUdef03, '') = '' THEN Orders.Userdefine03 ELSE STG.HUdef03 END   --WL02
              , Userdefine04  = CASE WHEN ISNULL(STG.HUdef04, '') = '' THEN Orders.Userdefine04 ELSE STG.HUdef04 END   --WL02
              , Userdefine05  = CASE WHEN ISNULL(STG.HUdef05, '') = '' THEN Orders.Userdefine05 ELSE STG.HUdef05 END   --WL02
              , OrderDate     = ISNULL(STG.OrderDate, Orders.OrderDate)
              , OrderGroup    = ISNULL(STG.OrderGroup, '')
              , Notes         = ISNULL(STG.Notes, '')
              , Notes2        = ISNULL(STG.Notes2, '')
              , ShipperKey    = ISNULL(STG.ShipperKey, '')
              , C_Company     = CASE WHEN ISNULL(STG.C_Company, '') = '' THEN Orders.C_Company ELSE STG.C_Company END
              , C_Address1    = CASE WHEN ISNULL(@c_InParm5, '') = '0' THEN CASE WHEN ISNULL(STG.C_Address1,'') = '' THEN '' ELSE STG.C_Address1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address1,'') = '' THEN Orders.C_Address1 ELSE STG.C_Address1 END END
              , C_Address2    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address2,'') = '' THEN '' ELSE STG.C_Address2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address2,'') = '' THEN Orders.C_Address2 ELSE STG.C_Address2 END END
              , C_Address3    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address3,'') = '' THEN '' ELSE STG.C_Address3 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address3,'') = '' THEN Orders.C_Address3 ELSE STG.C_Address3 END END
              , C_Address4    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Address4,'') = '' THEN '' ELSE STG.C_Address4 END
                                      ELSE CASE WHEN ISNULL(STG.C_Address4,'') = '' THEN Orders.C_Address4 ELSE STG.C_Address4 END END
              , C_City        = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_City,'') = '' THEN '' ELSE STG.C_City END
                                      ELSE CASE WHEN ISNULL(STG.C_City,'') = '' THEN Orders.C_City ELSE STG.C_City END END
              , C_Country     = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Country,'') = '' THEN '' ELSE STG.C_Country END
                                      ELSE CASE WHEN ISNULL(STG.C_Country,'') = '' THEN Orders.C_Country ELSE STG.C_Country END END
              , C_Contact1    = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Contact1,'') = '' THEN '' ELSE STG.C_Contact1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Contact1,'') = '' THEN Orders.C_Contact1 ELSE STG.C_Contact1 END END 
              , C_Contact2    = CASE WHEN ISNULL(@c_InParm5,'') <> '1' THEN CASE WHEN ISNULL(STG.C_Contact2,'') = '' THEN '' ELSE STG.C_Contact2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Contact2,'') = '' THEN Orders.C_Contact2 ELSE STG.C_Contact2 END END   
              , C_Phone1      = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Phone1,'') = '' THEN '' ELSE STG.C_Phone1 END
                                      ELSE CASE WHEN ISNULL(STG.C_Phone1,'') = '' THEN Orders.C_Phone1 ELSE STG.C_Phone1 END END   
              , C_Phone2      = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Phone2,'') = '' THEN '' ELSE STG.C_Phone2 END
                                      ELSE CASE WHEN ISNULL(STG.C_Phone2,'') = '' THEN Orders.C_Phone2 ELSE STG.C_Phone2 END END      
              , C_State       = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_State,'') = '' THEN '' ELSE STG.C_State END
                                      ELSE CASE WHEN ISNULL(STG.C_State,'') = '' THEN Orders.C_State ELSE STG.C_State END END        
              , C_Zip         = CASE WHEN ISNULL(@c_InParm5,'') = '0' THEN CASE WHEN ISNULL(STG.C_Zip,'') = '' THEN '' ELSE STG.C_Zip END
                                      ELSE CASE WHEN ISNULL(STG.C_Zip,'') = '' THEN Orders.C_Zip ELSE STG.C_Zip END END
              , Route         = CASE WHEN ISNULL(@c_InParm5,'') = '1' THEN CASE WHEN ISNULL(STG.Route,'') = '' THEN Orders.Route ELSE ISNULL(STG.Route,Orders.Route) END
                                      ELSE ISNULL(STG.Route,Orders.Route) END
              , Stop          = ISNULL(STG.Stop, Orders.Stop)
              , Doctype       = ISNULL(STG.Doctype, Orders.Doctype)
              , EditDate      = GETDATE()
            FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
            JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey)
            WHERE STG.STG_BatchNo = @n_BatchNo
            AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
            AND ORDERS.[Status] < '9'
         END
         --WL01 E

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      IF @c_InParm4 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.ORDERS
         SET Notes               = ISNULL(STG.Notes, '')
           , Notes2              = ISNULL(STG.Notes2, '')
           , IntermodalVehicle   = CASE WHEN ISNULL(STG.IntermodalVehicle,'') = '' THEN '' ELSE STG.IntermodalVehicle END
           , DischargePlace      = CASE WHEN ISNULL(STG.dischargeplace,'') = '' THEN '' ELSE STG.dischargeplace END
           , Door                = CASE WHEN ISNULL(STG.Door,'') = '' THEN '' ELSE STG.Door END
           , Stop                = ISNULL(STG.Stop, Orders.Stop)
           , Doctype             = ISNULL(STG.Doctype, Orders.Doctype)
           , EditDate            = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
         AND ORDERS.[Status] <= '5'
         

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      FETCH NEXT FROM CUR_CHECK INTO @c_Storerkey, @c_ExternOrderKey, @c_Loadkey, @c_OrderGroup
                                   , @c_InvoiceNo, @c_HUDEF04, @c_Consigneekey, @c_SKU
   END
   CLOSE CUR_CHECK
   DEALLOCATE CUR_CHECK

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_CHECK') IN (0 , 1)
   BEGIN
      CLOSE CUR_CHECK
      DEALLOCATE CUR_CHECK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN
END

GO