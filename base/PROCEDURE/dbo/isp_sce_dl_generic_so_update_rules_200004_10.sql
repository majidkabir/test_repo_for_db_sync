SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200004_10       */
/* Creation Date: 22-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform update into SO target table             */
/*                                                                      */
/*                                                                      */
/* Usage:      Update ODUDF02  @c_InParm1 =  '1' Turn On '0' Turn Off   */
/*               Update ODUDF  @c_InParm2 =  '1' Turn On '0' Turn Off   */
/*      Update By OrderLineNo  @c_InParm3 =  '1' Turn On '0' Turn Off   */
/*        Check Consignee SKU  @c_InParm4 =  '1' Turn On '0' Turn Off   */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.1                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 22-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 31-Jan-2023  WLChooi   1.1   WMS-21495 - Missing userdefine02 (WL01) */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200004_10] (
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
         , @n_ODShelfLife    INT
         , @c_UDF01          NVARCHAR(50)
         , @c_ConsigneeSKU   NVARCHAR(50)
         , @d_UDF01          DATETIME
         , @n_ShelfLife      INT

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

         UPDATE dbo.OrderDetail
         SET Userdefine02 = ISNULL(STG.DUdef02,'')
           , EditDate      = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.ExternLineNo = OD.ExternLineNo
                                               AND STG.SKU = OD.SKU)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
         AND ORDERS.[Status] = '9'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      IF @c_InParm2 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.OrderDetail
         SET Userdefine01 = CASE WHEN STG.DUdef01 IS NOT NULL THEN ISNULL(STG.DUdef01,'') ELSE OD.Userdefine01 END
           , Userdefine02 = CASE WHEN STG.DUdef02 IS NOT NULL THEN ISNULL(STG.DUdef02,'') ELSE OD.Userdefine02 END   --WL01
           , Userdefine03 = CASE WHEN STG.DUdef03 IS NOT NULL THEN ISNULL(STG.DUdef03,'') ELSE OD.Userdefine03 END
           , Userdefine04 = CASE WHEN STG.DUdef04 IS NOT NULL THEN ISNULL(STG.DUdef04,'') ELSE OD.Userdefine04 END
           , Userdefine05 = CASE WHEN STG.DUdef05 IS NOT NULL THEN ISNULL(STG.DUdef05,'') ELSE OD.Userdefine05 END
           , Userdefine06 = CASE WHEN STG.DUdef06 IS NOT NULL THEN ISNULL(STG.DUdef06,'') ELSE OD.Userdefine06 END
           , Userdefine07 = CASE WHEN STG.DUdef07 IS NOT NULL THEN ISNULL(STG.DUdef07,'') ELSE OD.Userdefine07 END
           , Userdefine08 = CASE WHEN STG.DUdef08 IS NOT NULL THEN ISNULL(STG.DUdef08,'') ELSE OD.Userdefine08 END
           , Userdefine09 = CASE WHEN STG.DUdef09 IS NOT NULL THEN ISNULL(STG.DUdef09,'') ELSE OD.Userdefine09 END
           , Userdefine10 = CASE WHEN STG.DUdef10 IS NOT NULL THEN ISNULL(STG.DUdef10,'') ELSE OD.Userdefine10 END
           , EditDate      = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.ExternLineNo = OD.ExternLineNo
                                               AND STG.SKU = OD.SKU)
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

      IF @c_InParm3 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.OrderDetail
         SET Userdefine01 = CASE WHEN STG.DUdef01 IS NOT NULL THEN ISNULL(STG.DUdef01,'') ELSE OD.Userdefine01 END
           , Userdefine02 = CASE WHEN STG.DUdef02 IS NOT NULL THEN ISNULL(STG.DUdef02,'') ELSE OD.Userdefine02 END   --WL01
           , Userdefine03 = CASE WHEN STG.DUdef03 IS NOT NULL THEN ISNULL(STG.DUdef03,'') ELSE OD.Userdefine03 END
           , Userdefine04 = CASE WHEN STG.DUdef04 IS NOT NULL THEN ISNULL(STG.DUdef04,'') ELSE OD.Userdefine04 END
           , Userdefine05 = CASE WHEN STG.DUdef05 IS NOT NULL THEN ISNULL(STG.DUdef05,'') ELSE OD.Userdefine05 END
           , Userdefine06 = CASE WHEN STG.DUdef06 IS NOT NULL THEN ISNULL(STG.DUdef06,'') ELSE OD.Userdefine06 END
           , Userdefine07 = CASE WHEN STG.DUdef07 IS NOT NULL THEN ISNULL(STG.DUdef07,'') ELSE OD.Userdefine07 END
           , Userdefine08 = CASE WHEN STG.DUdef08 IS NOT NULL THEN ISNULL(STG.DUdef08,'') ELSE OD.Userdefine08 END
           , Userdefine09 = CASE WHEN STG.DUdef09 IS NOT NULL THEN ISNULL(STG.DUdef09,'') ELSE OD.Userdefine09 END
           , Userdefine10 = CASE WHEN STG.DUdef10 IS NOT NULL THEN ISNULL(STG.DUdef10,'') ELSE OD.Userdefine10 END
           , EditDate      = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.OrderLineNumber = OD.OrderLineNumber
                                               AND STG.SKU = OD.SKU)
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

      IF @c_InParm5 = '1'
      BEGIN
         SET @n_ODShelfLife = 0
         SET @c_UDF01 = N''

         SELECT TOP 1 @n_ODShelfLife = OD.MinShelfLife
         FROM dbo.ORDERS  OH WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
         WHERE OD.Storerkey = @c_Storerkey AND OD.sku = @c_SKU
         AND   OH.Consigneekey = @c_Consigneekey

         IF ISNULL(@n_ODShelfLife, 0) > 0
         BEGIN
            SELECT @c_UDF01 = UDF01
            FROM dbo.Consigneesku CS WITH (NOLOCK)
            WHERE CS.Storerkey = @c_Storerkey AND CS.sku = @c_SKU
            AND   CS.Consigneekey = @c_Consigneekey
            AND   CS.Active      = 'Y'

            IF ISNULL(@c_UDF01, '') <> ''
            BEGIN
               SET @d_UDF01 = CAST(@c_UDF01 AS DATETIME)

               SET @n_ShelfLife = DATEDIFF(DAY, GETDATE(), @d_UDF01)
            END
            ELSE
            BEGIN
               SET @n_ShelfLife = 0
            END

            BEGIN TRANSACTION

            UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
            SET MinShelfLife = @n_ShelfLife
            WHERE STG_BatchNo = @n_BatchNo
            AND ExternOrderkey = @c_ExternOrderKey
            AND Storerkey = @c_Storerkey
            AND Consigneekey = @c_Consigneekey
            AND SKU = @c_SKU

            IF @@ERROR <> 0
            BEGIN      
               ROLLBACK TRAN
               GOTO QUIT
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END

            BEGIN TRANSACTION

            UPDATE dbo.OrderDetail
            SET MinShelfLife  = ISNULL(STG.MinShelfLife, 0)
              , EditDate      = GETDATE()
            FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
            JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.ExternLineNo = OD.ExternLineNo
                                                  AND STG.SKU = OD.SKU)
            WHERE STG.STG_BatchNo = @n_BatchNo
            AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
            AND STG.Consigneekey = @c_Consigneekey AND STG.SKU = @c_SKU

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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200004_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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