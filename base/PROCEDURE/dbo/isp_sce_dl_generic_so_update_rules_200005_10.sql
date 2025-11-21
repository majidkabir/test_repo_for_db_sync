SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200005_10       */
/* Creation Date: 22-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform update into SO target table             */
/*                                                                      */
/*                                                                      */
/* Usage:   Update ECOM Order  @c_InParm1 =  '1' Turn On '0' Turn Off   */
/*  Update ECOM Order Address  @c_InParm2 =  '1' Turn On '0' Turn Off   */
/*         Update Tracking No  @c_InParm3 =  '1' Turn On '0' Turn Off   */
/*          Update UserDefine  @c_InParm4 =  '1' Turn On '0' Turn Off   */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 22-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200005_10] (
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
         BEGIN TRANSACTION

         UPDATE dbo.Orders
         SET Userdefine04  = CASE WHEN @c_InParm4 <> '1' OR ISNULL(Orders.UserDefine04, '') <> '' THEN Orders.Userdefine04 ELSE ISNULL(@c_HUdef04, Orders.UserDefine04) END
           , ShipperKey    = ISNULL(STG.ShipperKey,Orders.ShipperKey)
           , DeliveryPlace = ISNULL(STG.DeliveryPlace,Orders.DeliveryPlace)
           , C_Address1    = CASE WHEN ISNULL(@c_InParm2,'') = '1' THEN CASE WHEN ISNULL(STG.C_Address1,'') = '' THEN '' ELSE STG.C_Address1 END
                                  ELSE ISNULL(STG.C_Address1,Orders.C_Address1) END
           , C_Address2    = CASE WHEN ISNULL(@c_InParm2,'') = '1' THEN CASE WHEN ISNULL(STG.C_Address2,'') = '' THEN '' ELSE STG.C_Address2 END
                                  ELSE ISNULL(STG.C_Address2,Orders.C_Address2) END
           , C_Address3    = CASE WHEN ISNULL(@c_InParm2,'') = '1' THEN CASE WHEN ISNULL(STG.C_Address3,'') = '' THEN '' ELSE STG.C_Address3 END
                                  ELSE ISNULL(STG.C_Address3,Orders.C_Address3) END
           , C_Address4    = CASE WHEN ISNULL(@c_InParm2,'') = '1' THEN CASE WHEN ISNULL(STG.C_Address4,'') = '' THEN '' ELSE STG.C_Address4 END
                                  ELSE ISNULL(STG.C_Address4,Orders.C_Address4) END
           , C_City        = ISNULL(STG.C_City,Orders.C_City)
           , C_Contact1    = ISNULL(STG.C_Contact1,Orders.C_Contact1)
           , C_Phone1      = ISNULL(STG.C_Phone1,Orders.C_Phone1)
           , C_Phone2      = ISNULL(STG.C_Phone2,Orders.C_Phone2)
           , C_State       = ISNULL(STG.C_State,Orders.C_State)
           , C_Zip         = ISNULL(STG.C_Zip,Orders.C_Zip)
           , C_Company     = CASE WHEN ISNULL(STG.C_Company,'') = '' THEN Orders.C_Company ELSE STG.C_Company END
           , Notes         = CASE WHEN ISNULL(STG.Notes,'') = '' THEN Orders.Notes ELSE STG.Notes END
           , TrackingNo    = CASE WHEN @c_InParm3 <> '1' OR ISNULL(Orders.TrackingNo, '') <> '' THEN Orders.TrackingNo ELSE ISNULL(STG.trackingno, Orders.TrackingNo) END
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200005_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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