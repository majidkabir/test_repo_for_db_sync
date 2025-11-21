SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_DeletePickSlip                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Delete Pickslip when status < '3'                           */
/*          Delete records from PickHeader                              */
/*                                                                      */
/* Called By: nep_n_cst_policy_del_pickslip                             */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver. Purposes                                    */
/* 25-Oct-2007  Vicky       IDSUS - Operation printed Conso + Discrete  */
/*                          all together, so when delete pickslip both  */
/*                          kind of tickets has to be deleted as well   */
/*                          (Vicky01)                                   */
/* 03-Nov-2009  NJOW01 1.1  141396 - Delete Orders and Pick Slip From   */
/*                          LoadPlan Detail                             */
/* 08-Jun-2011  Leong  1.2  SOS# 217857 - Cater for multiple pickslip   */
/*                                        per orders                    */
/* 13-Dec-2018  TLTING01 1.3 Missing nolock                             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_DeletePickSlip]
   @c_LoadKey  NVARCHAR(10),
   @c_OrderKey NVARCHAR(10) = '',    --NJOW01
   @b_Success  Int = 1        OUTPUT,
   @n_err      Int = 0        OUTPUT,
   @c_errmsg   NVARCHAR(255) = '' OUTPUT,
   @d_debug    Int = 0
AS
BEGIN -- main
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     Int
         , @n_StartCnt     Int
         , @c_Status       NVARCHAR(1)
         , @c_PickSlipType NVARCHAR(10) -- Vicky01
         , @c_PickOrderKey NVARCHAR(10) -- SOS# 217857

   SELECT @n_Continue = 1, @n_StartCnt = @@TRANCOUNT

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_OrderKey),'') = ''     --NJOW01
      BEGIN
         SELECT @c_Status = Status
         FROM  LoadPlan WITH (NOLOCK)
         WHERE LoadKey = @c_LoadKey

         IF @c_Status > '3'
         BEGIN
            SELECT @n_Continue=3
            SELECT @n_err=72100
            SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete rejected. Load Status Is NOT NORMAL/ALLOCATED (isp_DeletePickSlip).'
         END
      END
      ELSE
      BEGIN
         --NJOW01
         SELECT @c_Status = Status
         FROM  LoadPlanDetail WITH (NOLOCK)
         WHERE LoadKey = @c_LoadKey
         AND Orderkey = @c_OrderKey

         IF @c_Status > '2'
         BEGIN
            SELECT @n_Continue=3
            SELECT @n_err=72110
            SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete rejected. Load Order Status Is NOT NORMAL/ALLOCATED (isp_DeletePickSlip).'
         END
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- NJOW01
      IF ISNULL(RTRIM(@c_OrderKey),'') = ''
      BEGIN
         IF ( SELECT COUNT(*)
              FROM PickHeader WITH (NOLOCK)
              JOIN PACKHEADER WITH (NOLOCK) ON (PickHeader.Pickheaderkey = PACKHEADER.Pickslipno)
              JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)
              WHERE PickHeader.ExternOrderKey = @c_LoadKey ) > 0
         BEGIN
            SELECT @n_Continue=3
            SELECT @n_err=72120
            SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Some Orders already Pack. To remove the Pickslip, you need to unpack the orders and do un-allocation (isp_DeletePickSlip).'
         END
      END
      ELSE
      BEGIN
         IF ( SELECT COUNT(*)
              FROM PickHeader WITH (NOLOCK)
              JOIN PACKHEADER WITH (NOLOCK) ON (PickHeader.Pickheaderkey = PACKHEADER.Pickslipno)
              JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)
              WHERE PickHeader.ExternOrderKey = @c_LoadKey
              AND PickHeader.Orderkey = @c_OrderKey ) > 0
          BEGIN
             SELECT @n_Continue=3
             SELECT @n_err=72130
             SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Some Orders already Pack. To remove the Pickslip, you need to unpack the orders and do un-allocation (isp_DeletePickSlip).'
           END
       END
   END

   /************************************************************************/
   /*SOS# 217857 (Start)                                                   */
   /************************************************************************/
   CREATE TABLE #PH
         ( PickHeaderKey  NVARCHAR(18) NULL
         , OrderKey       NVARCHAR(10) NULL
         , ExternOrderKey NVARCHAR(20) NULL
         , Zone           NVARCHAR(18) NULL )

   INSERT INTO #PH (PickHeaderKey, OrderKey, ExternOrderKey, Zone)
   SELECT PickHeaderKey, OrderKey, ExternOrderKey, Zone
   FROM PickHeader WITH (NOLOCK)
   WHERE ExternOrderKey = @c_LoadKey

   SET @c_PickOrderKey = ''
   SET @c_PickSlipType = ''

   DECLARE Cur_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OrderKey, Zone
      FROM #PH WITH (NOLOCK)
      WHERE ExternOrderKey = @c_LoadKey
      ORDER BY OrderKey, Zone

   OPEN Cur_PickSlip
   FETCH NEXT FROM Cur_PickSlip INTO @c_PickOrderKey, @c_PickSlipType

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      INSERT INTO #PH (PickHeaderKey, OrderKey, ExternOrderKey, Zone)
      SELECT PickHeaderKey, OrderKey, @c_LoadKey, Zone
      FROM PickHeader WITH (NOLOCK)
      WHERE OrderKey = @c_PickOrderKey
      AND Zone <> @c_PickSlipType

      FETCH NEXT FROM Cur_PickSlip INTO @c_PickOrderKey, @c_PickSlipType
   END
   CLOSE Cur_PickSlip
   DEALLOCATE Cur_PickSlip

   -- -- Vicky01 (Start)
   -- IF @n_Continue = 1 OR @n_Continue = 2
   -- BEGIN
   --    IF ISNULL(RTRIM(@c_OrderKey),'') = ''     --NJOW01
   --    BEGIN
   --       SELECT @c_PickSlipType = ZONE
   --       FROM   PickHeader WITH (NOLOCK)
   --       WHERE  ExternOrderKey = @c_LoadKey
   --    END
   --    ELSE
   --    BEGIN
   --       --NJOW01
   --       SELECT @c_PickSlipType = ZONE
   --       FROM   PickHeader WITH (NOLOCK)
   --       WHERE  ExternOrderKey = @c_LoadKey
   --       AND Orderkey = @c_OrderKey
   --    END
   -- END
   -- -- Vicky01 (End)
   /************************************************************************/
   /*SOS# 217857 (End)                                                     */
   /************************************************************************/

   IF (@n_Continue = 1 OR @n_Continue = 2) AND ISNULL(RTRIM(@c_OrderKey),'') = ''  --NJOW01
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM #PH WITH (NOLOCK)
                     WHERE ExternOrderKey = @c_LoadKey)
      BEGIN
         SELECT @n_Continue=3
         SELECT @n_err=72210
         SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete rejected. No PickHeader record found (isp_DeletePickSlip).'
      END
      ELSE
      BEGIN -- #PH Record Exists
         SET @c_PickSlipType = ''
         DECLARE Cur_DelPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR -- SOS# 217857
            SELECT DISTINCT ExternOrderKey, Zone
            FROM #PH WITH (NOLOCK)
            WHERE ExternOrderKey = @c_LoadKey
            ORDER BY ExternOrderKey, Zone

         OPEN Cur_DelPickSlip
         FETCH NEXT FROM Cur_DelPickSlip INTO @c_LoadKey, @c_PickSlipType

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- batch, by load#
            IF EXISTS (SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND @c_PickSlipType <> 'C') -- Vicky01
            BEGIN
               IF ( SELECT COUNT(DISTINCT LoadplanDetail.Status)
                    FROM  LoadplanDetail WITH (NOLOCK)
                    WHERE LoadKey = @c_LoadKey
                    AND   Status > '2' ) > 0
               BEGIN
                  SELECT @n_Continue=3
                  SELECT @n_err=72140
                  SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Unable to delete Consolidated Pickslip. Not all orders are in NORMAL/ALLOCATED status (isp_DeletePickSlip).'
               END
               ELSE
               BEGIN
                  IF @n_Continue = 1 OR @n_Continue = 2
                  BEGIN
                     BEGIN TRAN
                     DELETE PickHeader
                     WHERE  ExternOrderKey = @c_LoadKey
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue=3
                        SELECT @n_err=72150
                        SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Failed on PickHeader (isp_DeletePickSlip).'
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
            END
            -- by order#
            ELSE IF EXISTS ( SELECT 1 FROM PickHeader WITH (NOLOCK)
                             JOIN  OrderDetail OD WITH (NOLOCK) ON OD.Orderkey = PickHeader.Orderkey
                             WHERE OD.LoadKey = @c_LoadKey )
            BEGIN
               IF @c_PickSlipType <> 'C' -- Vicky01
               BEGIN
                     --tlting01
                  IF EXISTS ( SELECT 1 FROM OrderDetail WITH (NOLOCK)
                              JOIN ORDERS (NOLOCK) ON Orders.Orderkey = OrderDetail.Orderkey
                              WHERE OrderDetail.LoadKey = @c_LoadKey
                              AND   Orders.Status > '2' )
                  BEGIN
                     SELECT @n_Continue=3
                     SELECT @n_err=72160
                     SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete rejected. Order Status Is NOT NORMAL/ALLOCATED (isp_DeletePickSlip).'
                  END
                  ELSE
                  BEGIN
                     IF @n_Continue = 1 OR @n_Continue = 2
                     BEGIN
                        BEGIN TRAN
                        DELETE PickHeader
                        FROM   PickHeader
                        JOIN   OrderDetail (NOLOCK) ON OrderDetail.Orderkey = PickHeader.Orderkey
                        WHERE  OrderDetail.LoadKey = @c_LoadKey
                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_Continue=3
                           SELECT @n_err=72170
                           SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Failed on PickHeader - by Orderkey (isp_DeletePickSlip).'
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
                  END -- By Order - Status < 2
               END -- Vicky01
               -- Vicky01 (Start)
               ELSE IF EXISTS (SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND @c_PickSlipType = 'C')
               BEGIN
               IF ( SELECT COUNT(DISTINCT LoadplanDetail.Status)
                    FROM  LoadplanDetail WITH (NOLOCK)
                    WHERE LoadKey = @c_LoadKey
                    AND   Status > '2' ) > 0
               BEGIN
                  SELECT @n_Continue=3
                  SELECT @n_err=72180
                  SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Unable to delete Consolidated Pickslip. Not all orders are in NORMAL/ALLOCATED status (isp_DeletePickSlip).'
               END
               ELSE
               BEGIN
                  IF @n_Continue = 1 OR @n_Continue = 2
                  BEGIN
                     BEGIN TRAN
                     DELETE PickHeader
                     WHERE  ExternOrderKey = @c_LoadKey
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue=3
                        SELECT @n_err=72190
                        SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Failed on PickHeader (isp_DeletePickSlip).'
                        ROLLBACK TRAN
                     END
                     ELSE
                     BEGIN
                        WHILE @@TRANCOUNT > 0
                        BEGIN
                           COMMIT TRAN
                        END
                     END

                     IF EXISTS ( SELECT DISTINCT 1
                                 FROM ORDERS WITH (NOLOCK)
                                 JOIN PickHeader WITH (NOLOCK) ON (ORDERS.OrderKey = PickHeader.OrderKey)
                                 WHERE ORDERS.LoadKey = @c_LoadKey
                                 AND PickHeader.Zone = 'D' )
                     BEGIN
                        BEGIN TRAN
                        DELETE PickHeader
                        FROM   PickHeader
                        JOIN   OrderDetail (NOLOCK) ON OrderDetail.Orderkey = PickHeader.Orderkey  --tlting01
                        WHERE  OrderDetail.LoadKey = @c_LoadKey
                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_Continue=3
                           SELECT @n_err=72200
                           SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Failed on PickHeader (isp_DeletePickSlip).'
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
               END
               END
               -- Vicky01 (End)
            END
            -- ELSE
            -- BEGIN
            --    SELECT @n_Continue=3
            --    SELECT @n_err=72210
            --    SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete rejected. No PickHeader record found (isp_DeletePickSlip).'
            -- END
            FETCH NEXT FROM Cur_DelPickSlip INTO @c_LoadKey, @c_PickSlipType
         END
         CLOSE Cur_DelPickSlip
         DEALLOCATE Cur_DelPickSlip
      END   -- #PH Record Exists
   END

   IF (@n_Continue = 1 OR @n_Continue = 2) AND ISNULL(RTRIM(@c_OrderKey),'') <> ''  --NJOW01
   BEGIN
      BEGIN TRAN
      DELETE PickHeader
      WHERE  ExternOrderKey = @c_LoadKey
      AND Orderkey = @c_OrderKey
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue=3
         SELECT @n_err=72220
         SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Failed on PickHeader (isp_DeletePickSlip).'
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

   DROP TABLE #PH

   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartCnt
         BEGIN
            COMMIT TRAN
         END
      END
      SELECT @b_Success = -1 --NJOW01
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_DeletePickSlip'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1   --NJOW01
      WHILE @@TRANCOUNT > @n_StartCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- main

GO