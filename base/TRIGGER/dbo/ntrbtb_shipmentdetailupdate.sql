SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrBTB_ShipmentDetailUpdate                                 */
/* Creation Date: 20-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 08-NOV-2017 Wan01    1.1   WMS-3321 - Triple - Back to Back FTA Entry*/
/* 2021-FEB-09 WAN02    1.2   WMS-15957-SG-CBF - BTB Form E Declaration */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrBTB_ShipmentDetailUpdate]
ON  [dbo].[BTB_SHIPMENTDETAIL]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(250)

   DECLARE @c_FormType        NVARCHAR(10)
         , @c_ShipmentKey     NVARCHAR(10)
         , @c_ShipmentListNo  NVARCHAR(10)
         , @c_ShipmentLineNo  NVARCHAR(5)
         , @c_FormNo          NVARCHAR(40)
         , @c_HSCode          NVARCHAR(20)
         , @c_Storerkey       NVARCHAR(15)     
         , @c_Sku             NVARCHAR(20)
         , @n_QtyExported     INT
         , @c_BTBSHIPItem     NVARCHAR(50)                                                         --(Wan01)

         , @c_FormNo_DEL      NVARCHAR(40)
         , @c_HSCode_DEL      NVARCHAR(20)
         , @c_Sku_DEL         NVARCHAR(20)
         , @n_QtyExported_DEL INT         
         , @c_BTBSHIPItem_DEL NVARCHAR(50)                                                         --(Wan01)  

         , @c_CustomLotNo     NVARCHAR(20) = ''                                                    --(Wan02)
         , @c_CustomLotNo_DEL NVARCHAR(20) = ''                                                    --(Wan02)
         , @c_BTB_FTAKey      NVARCHAR(10) = ''                                                    --(Wan02)  

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1

   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_continue = 4 
      GOTO QUIT_TR
   END

   IF NOT UPDATE(EditDate) 
   BEGIN
      UPDATE BTB_SHIPMENTDETAIL WITH (ROWLOCK)
      SET EditWho = SUSER_SNAME()
         ,EditDate= GETDATE()
         ,TrafficCop = NULL
      FROM BTB_SHIPMENTDETAIL
      JOIN INSERTED ON (BTB_SHIPMENTDETAIL.BTB_ShipmentKey = INSERTED.BTB_ShipmentKey)
                    AND(BTB_SHIPMENTDETAIL.BTB_ShipmentListNo = INSERTED.BTB_ShipmentListNo)
                    AND(BTB_SHIPMENTDETAIL.BTB_ShipmentLineNo = INSERTED.BTB_ShipmentLineNo)

      SET @n_err = @@ERROR 
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=80010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_SHIPMENTDETAIL. (ntrBTB_ShipmentDetailUpdate)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_TR
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_continue = 4 
      GOTO QUIT_TR
   END
 
   SET @c_ShipmentKey = ''  
   SELECT TOP 1 @c_ShipmentKey    = UPD.BTB_ShipmentKey
               ,@c_ShipmentListNo = RTRIM(UPD.BTB_ShipmentListNo)
               ,@c_Sku            = RTRIM(UPD.Sku)
               ,@c_BTBSHIPItem    = RTRIM(UPD.BTBSHIPItem)                                         --(Wan01)
   FROM BTB_FTA WITH (NOLOCK)
   JOIN (SELECT FormType = ISNULL(RTRIM(BTB_SHIPMENT.FormType),'')
               ,BTB_ShipmentKey    = INSERTED.BTB_ShipmentKey
               ,BTB_ShipmentListNo = INSERTED.BTB_ShipmentListNo
               ,FormNo   = ISNULL(RTRIM(INSERTED.FormNo),'')
               ,HSCode   = ISNULL(RTRIM(INSERTED.HSCode),'')
               ,Storerkey= ISNULL(RTRIM(INSERTED.Storerkey),'')
               ,Sku      = ISNULL(RTRIM(INSERTED.Sku),'')
               ,QtyExported = ISNULL(SUM(INSERTED.QtyExported),0) -- - CASE WHEN DELETED.FormNo = '' THEN 0 ELSE DELETED.QtyExported END),0)
               ,BTBSHIPItem = INSERTED.BTBSHIPItem                                                 --(Wan01)
               ,CustomLotNo = INSERTED.CustomLotNo                                                 --(Wan02)                 
         FROM INSERTED 
         JOIN DELETED  ON (INSERTED.BTB_ShipmentKey = DELETED.BTB_ShipmentKey)
                        AND(INSERTED.BTB_ShipmentListNo = DELETED.BTB_ShipmentListNo)
                        AND(INSERTED.BTB_ShipmentLineNo = DELETED.BTB_ShipmentLineNo)
         JOIN BTB_SHIPMENT WITH (NOLOCK) ON (INSERTED.BTB_ShipmentKey = BTB_SHIPMENT.BTB_ShipmentKey)
         WHERE INSERTED.FormNo <> DELETED.FormNo 
         GROUP BY BTB_SHIPMENT.FormType
               ,  INSERTED.BTB_ShipmentKey
               ,  INSERTED.BTB_ShipmentListNo
               ,  INSERTED.FormNo
               ,  INSERTED.HSCode
               ,  INSERTED.Storerkey
               ,  INSERTED.Sku
               ,  INSERTED.BTBSHIPItem                                                             --(Wan01)
               ,  INSERTED.CustomLotNo                                                             --(Wan02)               
         ) UPD ON (BTB_FTA.FormNo   = UPD.FormNo)
               AND(BTB_FTA.FormType = UPD.FormType)
               AND(BTB_FTA.HSCode   = UPD.HSCode)
               AND(BTB_FTA.Storerkey= UPD.Storerkey)
               AND(BTB_FTA.Sku      = UPD.Sku)
               AND(BTB_FTA.BTBSHIPItem= UPD.BTBSHIPItem)                                           --(Wan01)
               AND(BTB_FTA.CustomLotNo= UPD.CustomLotNo)                                           --(Wan02)
   WHERE BTB_FTA.QtyImported - BTB_FTA.QtyExported - UPD.QtyExported < 0

   IF @c_ShipmentKey <> ''  
   BEGIN 
      SET @n_Continue = 3
      SET @n_err=80020
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Shipmentdetail Total Exported Qty > BTBFTA Balance Qty. '
                   +'ShipmentKey: ' + @c_ShipmentKey+ ', '
                   +'ShipmentListNo: ' + @c_ShipmentListNo + ', '
                   +'Sku: ' + @c_Sku + ' (ntrBTB_ShipmentDetailUpdate)'
      GOTO QUIT_TR
   END

   DECLARE CUR_SHPDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT BTB_SHIPMENT.FormType
         ,ISNULL(RTRIM(INSERTED.FormNo),'')
         ,ISNULL(RTRIM(INSERTED.HSCode),'')
         ,ISNULL(RTRIM(INSERTED.Storerkey),'')
         ,ISNULL(RTRIM(INSERTED.Sku),'')
         ,ISNULL(INSERTED.QtyExported,0) 
         ,ISNULL(RTRIM(DELETED.FormNo),'')
         ,ISNULL(RTRIM(DELETED.HSCode),'')
         ,ISNULL(RTRIM(DELETED.Sku),'')
         ,ISNULL(DELETED.QtyExported,0) 
         ,INSERTED.BTBSHIPItem                                                                     --(Wan01)
         ,DELETED.BTBSHIPItem                                                                      --(Wan01)
         ,INSERTED.CustomLotNo                                                                     --(Wan02)
         ,DELETED.CustomLotNo                                                                      --(Wan02)         
   FROM INSERTED  
   JOIN DELETED  ON (INSERTED.BTB_ShipmentKey = DELETED.BTB_ShipmentKey)
                 AND(INSERTED.BTB_ShipmentListNo = DELETED.BTB_ShipmentListNo)
                 AND(INSERTED.BTB_ShipmentLineNo = DELETED.BTB_ShipmentLineNo)
   JOIN BTB_SHIPMENT WITH (NOLOCK) ON (BTB_SHIPMENT.BTB_ShipmentKey = INSERTED.BTB_ShipmentKey)
   OPEN CUR_SHPDET
   
   FETCH NEXT FROM CUR_SHPDET INTO @c_FormType
                                 , @c_FormNo
                                 , @c_HSCode
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @n_QtyExported
                                 , @c_FormNo_DEL
                                 , @c_HSCode_DEL
                                 , @c_Sku_DEL
                                 , @n_QtyExported_DEL
                                 , @c_BTBSHIPItem                                                  --(Wan01)
                                 , @c_BTBSHIPItem_DEL                                              --(Wan01)
                                 , @c_CustomLotNo                                                  --(Wan02)
                                 , @c_CustomLotNo_DEL                                              --(Wan02)

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- After populated, Shipmentdetail is save w/o form #
      --IF @n_QtyExported <> @n_QtyExported_DEL AND @n_QtyExported_DEL > 0                         --(Wan01)  
      IF @c_FormNo_DEL <> '' AND  @n_QtyExported_DEL > 0                                           --(Wan01)                     
      BEGIN
         --(Wan02) - START
         SET @c_BTB_FTAKey = ''
         SELECT TOP 1 @c_BTB_FTAKey = BTB_FTAKey
         FROM BTB_FTA WITH (NOLOCK) 
         WHERE BTB_FTA.FormNo   = @c_FormNo_DEL 
         AND   BTB_FTA.FormType = @c_FormType 
         AND   BTB_FTA.HSCode   = @c_HSCode_DEL 
         AND   BTB_FTA.Storerkey= @c_Storerkey
         AND   BTB_FTA.Sku      = @c_Sku_DEL 
         AND   BTB_FTA.BTBSHIPItem = @c_BTBSHIPItem_DEL                                             --(Wan02)
         AND   BTB_FTA.CustomLotNo = @c_CustomLotNo_DEL                                             --(Wan02) 
         
         IF @c_BTB_FTAKey <> ''
         BEGIN
            UPDATE BTB_FTA WITH (ROWLOCK)
            SET QtyExported = QtyExported - @n_QtyExported_DEL
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE BTB_FTA.BTB_FTAKey = @c_BTB_FTAKey 

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(5),@n_err)
               SET @n_err=80030
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_FTA. (ntrBTB_ShipmentDetailUpdate)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_TR
            END
         END
      END

      --IF @n_QtyExported <> @n_QtyExported_DEL AND @n_QtyExported > 0                             --(Wan01)                           
      IF @c_FormNo <> '' AND @n_QtyExported > 0                                                    --(Wan01)   
      BEGIN
         
         --(Wan02) - START
         SET @c_BTB_FTAKey = ''
         SELECT TOP 1 @c_BTB_FTAKey = BTB_FTAKey
         FROM BTB_FTA WITH (NOLOCK) 
         WHERE BTB_FTA.FormNo   = @c_FormNo 
         AND   BTB_FTA.FormType = @c_FormType 
         AND   BTB_FTA.HSCode   = @c_HSCode 
         AND   BTB_FTA.Storerkey= @c_Storerkey 
         AND   BTB_FTA.Sku      = @c_Sku 
         AND   BTB_FTA.BTBShipItem = @c_BTBShipItem                                                --(Wan02)
         AND   BTB_FTA.CustomLotNo = @c_CustomLotNo                                                --(Wan02) 
         
         IF @c_BTB_FTAKey <> ''
         BEGIN
            UPDATE BTB_FTA 
            SET QtyExported = QtyExported + @n_QtyExported  
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE BTB_FTA.BTB_FTAKey = @c_BTB_FTAKey 

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(5),@n_err)
               SET @n_err=80040
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_FTA. (ntrBTB_ShipmentDetailUpdate)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_TR
            END
         END
         --(Wan02) - END
      END

      FETCH NEXT FROM CUR_SHPDET INTO @c_FormType
                                    , @c_FormNo
                                    , @c_HSCode
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @n_QtyExported
                                    , @c_FormNo_DEL
                                    , @c_HSCode_DEL
                                    , @c_Sku_DEL
                                    , @n_QtyExported_DEL
                                    , @c_BTBSHIPItem                                               --(Wan01)
                                    , @c_BTBSHIPItem_DEL                                           --(Wan01)
                                    , @c_CustomLotNo                                               --(Wan02)
                                    , @c_CustomLotNo_DEL                                           --(Wan02)

   END
   CLOSE CUR_SHPDET
   DEALLOCATE CUR_SHPDET 

QUIT_TR:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_SHPDET') in (0 , 1)  
   BEGIN
      CLOSE CUR_SHPDET
      DEALLOCATE CUR_SHPDET
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ntrBTB_ShipmentDetailUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO