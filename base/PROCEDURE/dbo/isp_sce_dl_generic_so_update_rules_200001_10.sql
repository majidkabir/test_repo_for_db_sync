SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200001_10       */
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
/*         Update Order Group  @c_InParm2 =  '1' Turn On '0' Turn Off   */
/*           Update InvoiceNo  @c_InParm3 =  '1,2' Turn On '0' Turn Off */
/*    Update TBL Order Header  @c_InParm4 =  '1' Turn On '0' Turn Off   */
/*          Update UserDefine  @c_InParm5 =  '1' Turn On '0' Turn Off   */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200001_10] (
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
         IF ISNULL(TRIM(@c_Orderkey),'') <> ''
         BEGIN
            IF @c_InParm2 <> '1' AND @c_InParm3 = '0' AND @c_InParm4 <> '1'
            BEGIN
               UPDATE dbo.Orders
               SET DeliveryDate        = ISNULL(STG.DeliveryDate, @d_deliverydate)
                 , RoutingTool         = ISNULL(STG.RoutingTool, @c_RoutingTool)
                 , IntermodalVehicle   = ISNULL(STG.IntermodalVehicle, @c_IntermodalVehicle)
                 , ShipperKey          = ISNULL(STG.ShipperKey, @c_ShipperKey)
                 , Stop                = ISNULL(STG.Stop, Orders.Stop)
                 , Doctype             = ISNULL(STG.Doctype, Orders.Doctype)
                 , UserDefine01        = ISNULL(STG.HUdef01, Orders.UserDefine01)
                 , UserDefine02        = ISNULL(STG.HUdef02, Orders.UserDefine02)
                 , UserDefine03        = ISNULL(STG.HUdef03, Orders.UserDefine03)
                 , Userdefine04        = CASE WHEN @c_InParm5 <> '1' OR ISNULL(Orders.UserDefine04, '') <> '' THEN Orders.Userdefine04 ELSE ISNULL(@c_HUdef04, Orders.UserDefine04) END
                 , UserDefine05        = ISNULL(STG.HUdef05, Orders.UserDefine05)
                 , UserDefine06        = ISNULL(STG.HUdef06, Orders.UserDefine06)
                 , Userdefine07        = CASE WHEN @c_InParm5 = '1' THEN ISNULL(STG.HUdef07, Orders.Userdefine07) ELSE Orders.Userdefine07 END
                 , Userdefine08        = CASE WHEN @c_InParm5 = '1' THEN ISNULL(STG.HUdef08, Orders.Userdefine08) ELSE Orders.Userdefine08 END
                 , Userdefine09        = CASE WHEN @c_InParm5 = '1' THEN ISNULL(STG.HUdef09, Orders.Userdefine09) ELSE Orders.Userdefine09 END
                 , Userdefine10        = CASE WHEN @c_InParm5 = '1' THEN ISNULL(STG.HUdef10, Orders.Userdefine10) ELSE Orders.Userdefine10 END
                 , GrossWeight         = ISNULL(STG.HGrossWeight, Orders.GrossWeight)
                 , Capacity            = ISNULL(STG.HCapacity, Orders.Capacity)
                 , Editdate            =  GETDATE()
               FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
               JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey)
               WHERE ISNULL(Orders.OrderGroup,'') = (CASE WHEN RTRIM(ISNULL(@c_OrderGroup, '')) = '' THEN ISNULL(Orders.OrderGroup, '') ELSE RTRIM(ISNULL(@c_OrderGroup, '')) END)
               AND  STG.STG_BatchNo   = @n_BatchNo
               AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey
            END
            ELSE
            BEGIN
               IF @c_InParm5 <> '1'
               BEGIN
                  SET @c_Condition = N' AND Orders.Status = ''0'''
               END
               ELSE
               BEGIN
                  SET @c_Condition = N' AND Orders.Status <= ''5'''
               END

               SET @c_ExecStatements = ''
               SET @c_ExecArguments = ''

               SET @c_ExecStatements = N' UPDATE dbo.Orders '
                                     + N' SET DeliveryDate        = ISNULL(STG.DeliveryDate, @d_deliverydate) '
                                     + N'   , OrderGroup          = CASE WHEN @c_InParm2 = ''1'' THEN ISNULL(STG.OrderGroup, '''') ELSE Orders.Ordergroup END '
                                     + N'   , RoutingTool         = ISNULL(STG.RoutingTool, @c_RoutingTool) '
                                     + N'   , IntermodalVehicle   = CASE WHEN @c_InParm4 <> ''1'' THEN ISNULL(STG.IntermodalVehicle, @c_IntermodalVehicle) ELSE Orders.IntermodalVehicle END '
                                     + N'   , ShipperKey          = ISNULL(STG.ShipperKey, @c_ShipperKey) '
                                     + N'   , UserDefine01        = ISNULL(STG.HUdef01, Orders.UserDefine01) '
                                     + N'   , UserDefine02        = ISNULL(STG.HUdef02, Orders.UserDefine02) '
                                     + N'   , UserDefine03        = ISNULL(STG.HUdef03, Orders.UserDefine03) '
                                     + N'   , Userdefine04        = CASE WHEN @c_InParm5 <> ''1'' OR ISNULL(Orders.UserDefine04, '''') <> ''''  '
                                     + N'                                THEN Orders.Userdefine04 ELSE ISNULL(@c_HUdef04, Orders.UserDefine04) END '
                                     + N'   , UserDefine05        = ISNULL(STG.HUdef05, Orders.UserDefine05) '
                                     + N'   , UserDefine06        = ISNULL(STG.HUdef06, Orders.UserDefine06) '
                                     + N'   , Userdefine07        = CASE WHEN @c_InParm5 = ''1'' THEN ISNULL(STG.HUdef07, Orders.Userdefine07) ELSE Orders.Userdefine07 END '
                                     + N'   , Userdefine08        = CASE WHEN @c_InParm5 = ''1'' THEN ISNULL(STG.HUdef08, Orders.Userdefine08) ELSE Orders.Userdefine08 END '
                                     + N'   , Userdefine09        = CASE WHEN @c_InParm5 = ''1'' THEN ISNULL(STG.HUdef09, Orders.Userdefine09) ELSE Orders.Userdefine09 END '
                                     + N'   , Userdefine10        = CASE WHEN @c_InParm5 = ''1'' THEN ISNULL(STG.HUdef10, Orders.Userdefine10) ELSE Orders.Userdefine10 END '
                                     + N'   , Stop                = ISNULL(STG.Stop, Orders.Stop) '
                                     + N'   , Doctype             = ISNULL(STG.Doctype, Orders.Doctype) '
                                     + N'   , GrossWeight         = ISNULL(STG.HGrossWeight, Orders.GrossWeight) '
                                     + N'   , Capacity            = ISNULL(STG.HCapacity, Orders.Capacity) '
                                     + N'   , Editdate            = GETDATE() '
                                     + N' FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK) '
                                     + N' JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey) '
                                     + N' WHERE STG.STG_BatchNo   = @n_BatchNo '
                                     + N' AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey '

               SET @c_ExecStatements = @c_ExecStatements + @c_Condition

               SET @c_ExecArguments = N'  @d_DeliveryDate         DATETIME' 
                                    + N', @c_RoutingTool          NVARCHAR(30) '
                                    + N', @c_IntermodalVehicle    NVARCHAR(30) '
                                    + N', @c_ShipperKey           NVARCHAR(15)' 
                                    + N', @c_HUdef04              NVARCHAR(20)' 
                                    + N', @n_BatchNo              INT'
                                    + N', @c_ExternOrderkey       NVARCHAR(50)'
                                    + N', @c_Storerkey            NVARCHAR(15)'
                                    + N', @c_InParm1              NVARCHAR(60)'
                                    + N', @c_InParm2              NVARCHAR(60)'
                                    + N', @c_InParm3              NVARCHAR(60)'
                                    + N', @c_InParm4              NVARCHAR(60)'
                                    + N', @c_InParm5              NVARCHAR(60)'

               EXEC sp_executesql   @c_ExecStatements
                                  , @c_ExecArguments
                                  , @d_DeliveryDate      
                                  , @c_RoutingTool       
                                  , @c_IntermodalVehicle 
                                  , @c_ShipperKey        
                                  , @c_HUdef04           
                                  , @n_BatchNo           
                                  , @c_ExternOrderkey    
                                  , @c_Storerkey         
                                  , @c_InParm1           
                                  , @c_InParm2           
                                  , @c_InParm3           
                                  , @c_InParm4           
                                  , @c_InParm5   
            END
         END

         IF @c_InParm3 >= '1'
         BEGIN
            BEGIN TRANSACTION

            IF @c_InParm3 = '1'
            BEGIN
               SET @c_Condition = N' AND Orders.Status <= ''5'''
            END
            ELSE IF @c_InParm3 = '2'
            BEGIN
               SET @c_Condition = N' AND Orders.Status <= ''9'''
            END

            SET @c_ExecStatements = ''
            SET @c_ExecArguments = ''

            SET @c_ExecStatements = N' UPDATE dbo.Orders '
                                  + N' SET InvoiceNo  = @c_InvoiceNo '
                                  + N'   , Editdate   = GETDATE() '
                                  + N' FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK) '
                                  + N' JOIN dbo.Orders Orders WITH (NOLOCK) ON (STG.OrderKey = Orders.OrderKey AND STG.Storerkey = Orders.StorerKey) '
                                  + N' WHERE STG.STG_BatchNo   = @n_BatchNo '
                                  + N' AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey '

            SET @c_ExecStatements = @c_ExecStatements + @c_Condition

            SET @c_ExecArguments = N'  @c_InvoiceNo            NVARCHAR(20) '
                                 + N', @n_BatchNo              INT'
                                 + N', @c_ExternOrderkey       NVARCHAR(50)'
                                 + N', @c_Storerkey            NVARCHAR(15)'
                                 + N', @c_InParm1              NVARCHAR(60)'
                                 + N', @c_InParm2              NVARCHAR(60)'
                                 + N', @c_InParm3              NVARCHAR(60)'
                                 + N', @c_InParm4              NVARCHAR(60)'
                                 + N', @c_InParm5              NVARCHAR(60)'

            EXEC sp_executesql   @c_ExecStatements
                                , @c_ExecArguments
                                , @d_DeliveryDate      
                                , @c_RoutingTool       
                                , @c_IntermodalVehicle 
                                , @c_ShipperKey        
                                , @c_HUdef04           
                                , @n_BatchNo          
                                , @c_ExternOrderkey    
                                , @c_Storerkey         
                                , @c_InParm1           
                                , @c_InParm2           
                                , @c_InParm3           
                                , @c_InParm4           
                                , @c_InParm5  

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
         END

         BEGIN TRANSACTION

         SET @c_ExecStatements = ''
         SET @c_ExecArguments = ''
         
         SET @c_ExecStatements = N' UPDATE dbo.OrderDetail '
                               + N' SET UserDefine03  = STG.DUdef03 '
                               + N'   , Editdate      = GETDATE() '
                               + N' FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK) '
                               + N' JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (STG.Orderkey = OD.Orderkey AND STG.ExternLineNo = OD.ExternLineNo '
                               + N'                                       AND STG.Storerkey = OD.Storerkey AND STG.SKU = OD.SKU) '
                               + N' WHERE STG.STG_BatchNo   = @n_BatchNo '
                               + N' AND STG.ExternOrderkey = @c_ExternOrderkey AND STG.Storerkey = @c_Storerkey '
                               + N' AND OD.Status = ''0'' '
                               + N' AND STG.DUdef03 in (''ADJUST'',''DAMAGED'',''NEXP'',''SHIP'',''SORT'',''WOFF'')  '
         
         SET @c_ExecStatements = @c_ExecStatements + @c_Condition
         
         SET @c_ExecArguments = N'  @n_BatchNo              INT'
                              + N', @c_ExternOrderkey       NVARCHAR(50)'
                              + N', @c_Storerkey            NVARCHAR(15)'
                              + N', @c_InParm1              NVARCHAR(60)'
                              + N', @c_InParm2              NVARCHAR(60)'
                              + N', @c_InParm3              NVARCHAR(60)'
                              + N', @c_InParm4              NVARCHAR(60)'
                              + N', @c_InParm5              NVARCHAR(60)'
         
         EXEC sp_executesql   @c_ExecStatements
                             , @c_ExecArguments
                             , @n_BatchNo          
                             , @c_ExternOrderkey    
                             , @c_Storerkey         
                             , @c_InParm1           
                             , @c_InParm2           
                             , @c_InParm3           
                             , @c_InParm4           
                             , @c_InParm5  
         
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_UPDATE_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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