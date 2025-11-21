SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_InsertLoadplanDetail                              */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: IDS                                                         */
/*                                                                         */
/* Purpose: Insert LoadPlan Detail                                         */
/*                                                                         */
/* Called By: nep_n_cst_policy_insert_loadplandetail                       */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 20-Sep-2010  Leong     1.1   SOS# 189712 - Ensure @cOrderStatus is not  */
/*                                            NULL                         */
/* 20-Jan-2014  SPChin    1.2   SOS# 300220 - Bug Fixed.                   */
/* 28-Feb-2014  Leong     1.3   SOS# 304913 - Delete detail where LoadKey  */
/*                                            is blank.                    */
/* 04-Oct-2016  Shong     1.4   Performance Tuning                         */
/* 29-Sep-2017  Leong     1.5   IN00478480 - Add Loadplan header check.    */
/* 27-Jul-2018  TLTING    1.5   Performance Tuning                         */
/* 28-Jan-2019  TLTING_ext 1.7  enlarge externorderkey field length        */
/* 13-Mar-2019  LZG       1.6   INC0600699 - Rollback entire transaction   */
/*                              when hit trigger error (ZG01)              */
/* 28-Feb-2022  Leong     1.8   JSM-54294 - SCE bug fix with               */
/*                              lsp_WaveGenLoadPlan (Wan02)                */
/***************************************************************************/

CREATE PROCEDURE [dbo].[isp_InsertLoadplanDetail]
   @cLoadKey          NVARCHAR(10),
   @cFacility         NVARCHAR(5),
   @cOrderKey         NVARCHAR(10),
   @cConsigneeKey     NVARCHAR(20) = '',
   @cPrioriry         NVARCHAR(10) = '9',
   @dOrderDate        DATETIME,
   @dDelivery_Date    DATETIME,
   @cOrderType        NVARCHAR(10) = '',
   @cDoor             NVARCHAR(10) = '',
   @cRoute            NVARCHAR(10) = '',
   @cDeliveryPlace    NVARCHAR(30) = '',
   @nStdGrossWgt      FLOAT = 0 ,
   @nStdCube          FLOAT = 0 ,
   @cExternOrderKey   NVARCHAR(50) = '',   --tlting_ext
   @cCustomerName     NVARCHAR(45) = '',
   @nTotOrderLines    INT = 0,
   @nNoOfCartons      INT = 0,
   @cOrderStatus      NVARCHAR(10) = '0',
   @b_Success         INT = 1        OUTPUT,
   @n_Err             INT = 0        OUTPUT,
   @c_ErrMsg          NVARCHAR(255) = '' OUTPUT
AS
BEGIN -- main
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
   SELECT @b_debug = 0

   DECLARE @n_Continue         INT
         , @n_StartTCnt        INT       -- Holds the current transaction count
         , @n_LineNo           INT
         , @cLoadLineNumber    NVARCHAR(5)
         , @c_Authority        NVARCHAR(1)
         , @cLoadplan_Facility NVARCHAR(5)
         , @n_Cnt              INT
   DECLARE @c_OrderLineNo NVARCHAR(5) = ''

   SELECT @b_success = 0, @n_Continue = 1

   EXECUTE nspGetRight NULL, -- facility
            NULL,            -- Storerkey
            NULL,            -- Sku
            'SINGLEFACILITYLOAD',        -- Configkey
            @b_success    OUTPUT,
            @c_Authority  OUTPUT,
            @n_Err        OUTPUT,
            @c_ErrMsg     OUTPUT

   IF @c_Authority = '1' AND @b_success = 1
   BEGIN
      SELECT @cLoadplan_Facility = ISNULL(Facility, '')
      FROM   LOADPLAN (NOLOCK)
      WHERE  LoadKey = @cLoadKey

      IF @cLoadplan_Facility <> @cFacility
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 72800
         SELECT @c_ErrMsg = 'Facility Mis-match for Order ' + RTRIM(@cOrderkey) + '.'
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2 -- IN00478480
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM LOADPLAN WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 72801
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err) + ' Loadplan header not found: ' + ISNULL(RTRIM(@cLoadKey),'') + '. (isp_InsertLoadplanDetail)'
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE ISNULL(RTRIM(OrderKey),'') = '' AND LoadKey = @cLoadKey)
      BEGIN
         BEGIN TRAN

         DELETE FROM LOADPLANDETAIL
          WHERE ISNULL(RTRIM(OrderKey),'') = ''
            AND LoadKey = @cLoadKey

         SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 72807
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Delete Failed On Table Loadplan Detail. (isp_InsertLoadplanDetail)'
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2 -- SOS# 304913
   BEGIN
      IF EXISTS(SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE ISNULL(RTRIM(LoadKey),'') = '' AND OrderKey = @cOrderKey)
      BEGIN
         BEGIN TRAN

         DELETE FROM LOADPLANDETAIL
          WHERE ISNULL(RTRIM(LoadKey),'') = ''
            AND OrderKey = @cOrderKey

         SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 72812
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Delete Failed On Table Loadplan Detail. (isp_InsertLoadplanDetail)'
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
      END
   END

   SELECT @n_StartTCnt = @@TRANCOUNT

   IF @n_Continue = 1 OR @n_Continue = 2  --SOS300220    -- ZG01 (Start)
   BEGIN
      BEGIN TRAN
      SELECT @cLoadLineNumber = RIGHT('0000' + RTRIM(CAST(ISNULL(CAST(MAX(LoadLineNumber) AS INT), 0) + 1 AS NVARCHAR(5))), 5)
      FROM   LOADPLANDETAIL (NOLOCK)
      WHERE  Loadkey = @cLoadKey

      IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cOrderKey)
      BEGIN
         INSERT INTO LOADPLANDETAIL
            (LoadKey,            LoadLineNumber,
             OrderKey,           ConsigneeKey,
             Priority,           OrderDate,
             DeliveryDate,       Type,
             Door,               Stop,
             Route,              DeliveryPlace,
             Weight,             Cube,
             ExternOrderKey,     CustomerName,
             NoOfOrdLines,       CaseCnt,
             Status,             AddWho)
         VALUES
            (@cLoadKey,          @cLoadLineNumber,
             @cOrderKey,         @cConsigneeKey,
             @cPrioriry,         @dOrderDate,
             @dDelivery_Date,    @cOrderType,
             @cDoor,             '',
             @cRoute,            @cDeliveryPlace,
             @nStdGrossWgt,      @nStdCube,
             @cExternOrderKey,   @cCustomerName,
             @nTotOrderLines,    @nNoOfCartons,
             ISNULL(RTRIM(@cOrderStatus),'0'), '*' + RTRIM(SUSER_SNAME()) )
           --@cOrderStatus,      '*' + RTRIM(SUSER_SNAME()) ) -- SOS# 189712

         SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 72810
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Insert Failed to Table Loadplan Detail. (isp_InsertLoadplanDetail)' + LTRIM(RTRIM(@c_ErrMsg))
         END
      END -- Loadplan Detail not exists
      ELSE
      BEGIN
         UPDATE LOADPLANDETAIL
         SET    Weight = @nStdGrossWgt,
                Cube   = @nStdCube,
                CaseCnt = @nNoOfCartons,
                EditWho = SUSER_SNAME(),
                EditDate = GETDATE(),
                TrafficCop = NULL
         WHERE  Loadkey = @cLoadKey
         AND    Orderkey = @cOrderKey

         SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 72811
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Update Failed on Table Loadplan Detail. (isp_InsertLoadplanDetail)' + LTRIM(RTRIM(@c_ErrMsg))
         END
      END
   END   --SOS300220

   --BEGIN TRAN

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      IF EXISTS ( SELECT 1 FROM OrderDetail (NOLOCK)
                  WHERE   OrderDetail.OrderKey = @cOrderKey
                  AND (LoadKey = '' OR LoadKey IS NULL)   )
      BEGIN
         DECLARE OrderDet_Load_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OrderDetail.orderkey, OrderDetail.Orderlinenumber
         FROM OrderDetail (NOLOCK)
         WHERE OrderDetail.OrderKey = @cOrderKey
         AND (LoadKey = '' OR LoadKey IS NULL)

         OPEN OrderDet_Load_Cur
         FETCH NEXT FROM OrderDet_Load_Cur INTO @cOrderKey, @c_OrderLineNo

         WHILE @@FETCH_STATUS = 0 AND (@n_Continue = 1 OR @n_Continue = 2)
         BEGIN
            UPDATE OrderDetail
            SET LoadKey = @cLoadKey,
                TrafficCop = NULL,
                EditWho = SUSER_SNAME(),
                EditDate = GETDATE()
            WHERE orderkey = @cOrderKey
            AND Orderlinenumber = @c_OrderLineNo

            SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT

            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SELECT @n_Continue = 3
               SELECT @n_Err = 72808
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Update Failed On Table Order Detail. (isp_InsertLoadplanDetail)'

            END
            FETCH NEXT FROM OrderDet_Load_Cur INTO  @cOrderKey, @c_OrderLineNo
         END
         CLOSE OrderDet_Load_Cur
         DEALLOCATE OrderDet_Load_Cur
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
         SET LoadKey = @cLoadKey,
             TrafficCop = NULL,
             EditWho = SUSER_SNAME(),
             EditDate = GETDATE()
       WHERE OrderKey = @cOrderKey
         AND (LoadKey = '' OR LoadKey IS NULL)

      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 72809
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Update Failed On Table Orders. (isp_InsertLoadplanDetail)'
      END
   END            -- ZG01 (End)

   -- WHILE @@TRANCOUNT > 0
   -- BEGIN
      -- COMMIT TRAN
   -- END

   /* #INCLUDE <TRMBOHU2.SQL> */

   /***** End Add by DLIM *****/
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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
      EXECUTE nsp_LogError @n_Err, @c_ErrMsg, 'isp_InsertLoadplanDetail'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      --RETURN --(Wan02)
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      --RETURN --(Wan02)
   END

   --(Wan02) - START
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan02) - END
END -- procedure

GO