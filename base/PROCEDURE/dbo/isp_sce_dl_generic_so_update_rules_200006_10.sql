SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200006_10       */
/* Creation Date: 22-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19670 - Perform update into SO target table             */
/*                                                                      */
/*                                                                      */
/* Usage:       Update ORDDET  @c_InParm1 =  '1' Turn On '0' Turn Off   */
/*           Update B_Address  @c_InParm2 =  '1' Turn On '0' Turn Off   */
/*         Update ExternPOKey  @c_InParm3 =  '1' Turn On '0' Turn Off   */
/*           Update M_Address  @c_InParm4 =  '1' Turn On '0' Turn Off   */
/*           Update Lottables  @c_InParm5 =  '1' Turn On '0' Turn Off   */
/*           LottableXX = ''   -> No update LottableXX                  */
/*           LottableXX = '$$' -> Update LottableXX to blank            */
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
/* 09-Jan-2023  WLChooi   1.1   WMS-21495 - Update Lottables (WL01)     */
/* 13-Feb-2023  WLChooi   1.2   Bug Fix for WMS-21495 - Update by Order */
/*                              Line Number (WL02)                      */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200006_10] (
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

         UPDATE dbo.OrderDetail
         SET Lottable01 = ISNULL(STG.Lottable01, '')
           , UnitPrice  = ISNULL(STG.Unitprice, OD.UnitPrice)
           , EditDate   = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.ExternLineNo = OD.ExternLineNo
                                               AND STG.SKU = OD.SKU)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
         AND OD.[Status] = '0'

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

         UPDATE dbo.ORDERS
         SET B_Company      = CASE WHEN ISNULL(STG.B_Company, '') = '' THEN Orders.B_Company ELSE STG.B_Company END
           , B_Address1     = ISNULL(STG.B_Address1, Orders.B_Address1)
           , B_Address2     = ISNULL(STG.B_Address2, Orders.B_Address2)
           , B_Address3     = ISNULL(STG.B_Address3, Orders.B_Address3)
           , B_Address4     = ISNULL(STG.B_Address4, Orders.B_Address4)
           , B_City         = ISNULL(STG.B_City, Orders.B_City)
           , B_Contact1     = ISNULL(STG.B_Contact1, Orders.B_Contact1)
           , B_Contact2     = ISNULL(STG.B_Contact1, Orders.B_Contact2)
           , B_Phone1       = ISNULL(STG.B_Phone1, Orders.B_Phone1)
           , B_Phone2       = ISNULL(STG.B_Phone2, Orders.B_Phone2)
           , B_State        = ISNULL(STG.B_State, Orders.B_State)
           , B_Zip          = ISNULL(STG.B_Zip, Orders.B_Zip)
           , B_Country      = ISNULL(STG.B_Country, Orders.B_Country)
           , B_ISOCntryCode = ISNULL(STG.B_ISOCntryCode, Orders.B_ISOCntryCode)
           , EditDate       = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
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
         SET ExternPOKey = ISNULL(STG.ExternPOKey, Orders.ExternPOKey)
           , EditDate   = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.OrderKey = OD.OrderKey AND STG.ExternLineNo = OD.ExternLineNo
                                               AND STG.SKU = OD.SKU)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey

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
         SET M_Company      = CASE WHEN ISNULL(STG.M_Company, '') = '' THEN Orders.M_Company ELSE STG.M_Company END
           , M_Address1     = CASE WHEN ISNULL(STG.M_Address1, '') = '' THEN Orders.M_Address1 ELSE STG.M_Address1 END
           , M_Address2     = CASE WHEN ISNULL(STG.M_Address2, '') = '' THEN Orders.M_Address1 ELSE STG.M_Address2 END
           , M_Address3     = CASE WHEN ISNULL(STG.M_Address3, '') = '' THEN Orders.M_Address1 ELSE STG.M_Address3 END
           , M_Address4     = CASE WHEN ISNULL(STG.M_Address4, '') = '' THEN Orders.M_Address1 ELSE STG.M_Address4 END
           , M_City         = CASE WHEN ISNULL(STG.M_City, '') = '' THEN Orders.M_City ELSE STG.M_City END
           , M_Contact1     = CASE WHEN ISNULL(STG.M_Contact1, '') = '' THEN Orders.M_Contact1 ELSE STG.M_Contact1 END
           , M_Contact2     = CASE WHEN ISNULL(STG.M_Contact2, '') = '' THEN Orders.M_Contact2 ELSE STG.M_Contact2 END
           , M_Phone1       = CASE WHEN ISNULL(STG.M_Phone1, '') = '' THEN Orders.M_Phone1 ELSE STG.M_Phone1 END
           , M_Phone2       = CASE WHEN ISNULL(STG.M_Phone2, '') = '' THEN Orders.M_Phone2 ELSE STG.M_Phone2 END
           , M_State        = CASE WHEN ISNULL(STG.M_State, '') = '' THEN Orders.M_State ELSE STG.M_State END
           , M_Zip          = CASE WHEN ISNULL(STG.M_Zip, '') = '' THEN Orders.M_Zip ELSE STG.M_Zip END
           , M_Country      = CASE WHEN ISNULL(STG.M_Country, '') = '' THEN Orders.M_Country ELSE STG.M_Country END
           , M_ISOCntryCode = CASE WHEN ISNULL(STG.M_ISOCntryCode,'') = '' THEN Orders.M_ISOCntryCode ELSE STG.M_ISOCntryCode END
           , EditDate       = GETDATE()
         FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
         AND ORDERS.[Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
         
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END
      
      --WL01 S
      IF @c_InParm5 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.ORDERDETAIL
         SET Lottable01 = CASE WHEN ISNULL(STG.Lottable01, '') = '' THEN ORDERDETAIL.Lottable01
                               WHEN STG.Lottable01 = '$$' THEN ''
                               ELSE STG.Lottable01 END
           , Lottable02 = CASE WHEN ISNULL(STG.Lottable02, '') = '' THEN ORDERDETAIL.Lottable02
                               WHEN STG.Lottable02 = '$$' THEN ''
                               ELSE STG.Lottable02 END
           , Lottable03 = CASE WHEN ISNULL(STG.Lottable03, '') = '' THEN ORDERDETAIL.Lottable03
                               WHEN STG.Lottable03 = '$$' THEN ''
                               ELSE STG.Lottable03 END
           , Lottable04 = CASE WHEN STG.Lottable04 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable04 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable04 > '1900-01-01 00:00:00.000' THEN STG.Lottable04 END
                               ELSE ORDERDETAIL.Lottable04 END
           , Lottable05 = CASE WHEN STG.Lottable05 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable05 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable05 > '1900-01-01 00:00:00.000' THEN STG.Lottable05 END
                               ELSE ORDERDETAIL.Lottable05 END
           , Lottable06 = CASE WHEN ISNULL(STG.Lottable06, '') = '' THEN ORDERDETAIL.Lottable06
                               WHEN STG.Lottable06 = '$$' THEN ''
                               ELSE STG.Lottable06 END
           , Lottable07 = CASE WHEN ISNULL(STG.Lottable07, '') = '' THEN ORDERDETAIL.Lottable07
                               WHEN STG.Lottable07 = '$$' THEN ''
                               ELSE STG.Lottable07 END
           , Lottable08 = CASE WHEN ISNULL(STG.Lottable08, '') = '' THEN ORDERDETAIL.Lottable08
                               WHEN STG.Lottable08 = '$$' THEN ''
                               ELSE STG.Lottable08 END
           , Lottable09 = CASE WHEN ISNULL(STG.Lottable09, '') = '' THEN ORDERDETAIL.Lottable09
                               WHEN STG.Lottable09 = '$$' THEN ''
                               ELSE STG.Lottable09 END
           , Lottable10 = CASE WHEN ISNULL(STG.Lottable10, '') = '' THEN ORDERDETAIL.Lottable10
                               WHEN STG.Lottable10 = '$$' THEN ''
                               ELSE STG.Lottable10 END
           , Lottable11 = CASE WHEN ISNULL(STG.Lottable11, '') = '' THEN ORDERDETAIL.Lottable11
                               WHEN STG.Lottable11 = '$$' THEN ''
                               ELSE STG.Lottable11 END
           , Lottable12 = CASE WHEN ISNULL(STG.Lottable12, '') = '' THEN ORDERDETAIL.Lottable12
                               WHEN STG.Lottable12 = '$$' THEN ''
                               ELSE STG.Lottable12 END
           , Lottable13 = CASE WHEN STG.Lottable13 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable13 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable13 > '1900-01-01 00:00:00.000' THEN STG.Lottable13 END
                               ELSE ORDERDETAIL.Lottable13 END
           , Lottable14 = CASE WHEN STG.Lottable14 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable14 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable14 > '1900-01-01 00:00:00.000' THEN STG.Lottable14 END
                               ELSE ORDERDETAIL.Lottable14 END
           , Lottable15 = CASE WHEN STG.Lottable15 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable15 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable15 > '1900-01-01 00:00:00.000' THEN STG.Lottable15 END
                               ELSE ORDERDETAIL.Lottable15 END
           , EditWho = SUSER_SNAME()
           , EditDate = GETDATE()
         FROM SCE_DL_SO_STG STG WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON (STG.OrderKey = ORDERS.OrderKey AND STG.Storerkey = ORDERS.StorerKey)
         JOIN dbo.ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = STG.OrderKey) AND (ORDERDETAIL.OrderLineNumber = STG.OrderLineNumber)   --WL02
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
         AND ORDERS.[Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END
      --WL01 E

      UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE STG_BatchNo = @n_BatchNo
      AND ExternOrderkey = @c_ExternOrderkey AND Storerkey = @c_Storerkey

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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200006_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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