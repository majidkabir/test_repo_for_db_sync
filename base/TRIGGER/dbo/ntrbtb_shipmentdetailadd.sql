SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrBTB_ShipmentDetailAdd                                    */
/* Creation Date: 20-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-FEB-09 WAN01    1.1   WMS-15957-SG-CBF - BTB Form E Declaration */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrBTB_ShipmentDetailAdd]
ON  [dbo].[BTB_SHIPMENTDETAIL]
FOR INSERT
AS
BEGIN
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

         , @c_BTBShipItem     NVARCHAR(50) = ''       --(Wan01)
         , @c_CustomLotNo     NVARCHAR(20) = ''       --(Wan01)
         , @c_BTB_FTAKey      NVARCHAR(10) = ''       --(Wan01)
         
   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   
   IF EXISTS(SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT_TR
   END 

   SET @c_ShipmentKey = ''
   SELECT TOP 1 @c_ShipmentKey    = INS.BTB_ShipmentKey
               ,@c_ShipmentListNo = RTRIM(INS.BTB_ShipmentListNo)
               ,@c_Sku            = RTRIM(INS.Sku)
   FROM BTB_FTA WITH (NOLOCK)
   JOIN (SELECT FormType   = ISNULL(RTRIM(BTB_SHIPMENT.FormType),'')
               ,BTB_ShipmentKey    = INSERTED.BTB_ShipmentKey
               ,BTB_ShipmentListNo = INSERTED.BTB_ShipmentListNo
               ,FormNo     = ISNULL(RTRIM(INSERTED.FormNo),'')
               ,HSCode     = ISNULL(RTRIM(INSERTED.HSCode),'')
               ,Storerkey  = ISNULL(RTRIM(INSERTED.Storerkey),'')
               ,Sku        = ISNULL(RTRIM(INSERTED.Sku),'')
               ,QtyExported = ISNULL(SUM(INSERTED.QtyExported),0)
               ,INSERTED.BTBShipItem                                 --(Wan01)
               ,INSERTED.CustomLotNo                                 --(Wan01)
         FROM  INSERTED
         JOIN  BTB_SHIPMENT WITH (NOLOCK) ON (INSERTED.BTB_ShipmentKey = BTB_SHIPMENT.BTB_ShipmentKey)
         WHERE INSERTED.FormNo <> ''
         GROUP BY BTB_SHIPMENT.FormType
               ,  INSERTED.BTB_ShipmentKey
               ,  INSERTED.BTB_ShipmentListNo
               ,  INSERTED.FormNo
               ,  INSERTED.HSCode
               ,  INSERTED.Storerkey
               ,  INSERTED.Sku
               ,  INSERTED.BTBShipItem                               --(Wan01)
               ,  INSERTED.CustomLotNo                               --(Wan01)           
         ) INS    ON (BTB_FTA.FormNo   = INS.FormNo)
                  AND(BTB_FTA.FormType = INS.FormType)
                  AND(BTB_FTA.HSCode   = INS.HSCode)
                  AND(BTB_FTA.Storerkey= INS.Storerkey)
                  AND(BTB_FTA.Sku      = INS.Sku) 
                  AND(BTB_FTA.BTBShipItem = INS.BTBShipItem)         --(Wan01)
                  AND(BTB_FTA.CustomLotNo = INS.CustomLotNo)         --(Wan01)        
   WHERE BTB_FTA.QtyImported - BTB_FTA.QtyExported - INS.QtyExported < 0
 
   IF @c_ShipmentKey <> ''
   BEGIN 
      SET @n_Continue = 3
      SET @n_err=80010
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Shipmentdetail Total Exported Qty > BTBFTA Balance Qty. '
                   +'ShipmentKey: ' + @c_ShipmentKey+ ', '
                   +'ShipmentListNo: ' + @c_ShipmentListNo + ', '
                   +'Sku: ' + @c_Sku + ' (ntrBTB_ShipmentDetailAdd)'
      GOTO QUIT_TR
   END

   DECLARE CUR_SHPDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT BTB_SHIPMENT.FormType
         ,ISNULL(RTRIM(INSERTED.FormNo),'')
         ,ISNULL(RTRIM(INSERTED.HSCode),'')
         ,ISNULL(RTRIM(INSERTED.Storerkey),'')
         ,ISNULL(RTRIM(INSERTED.Sku),'')
         ,ISNULL(INSERTED.QtyExported,0) 
         ,INSERTED.BTBShipItem                                    --(Wan01)
         ,INSERTED.CustomLotNo                                    --(Wan01)
   FROM INSERTED                                               
   JOIN BTB_SHIPMENT WITH (NOLOCK) ON (INSERTED.BTB_ShipmentKey = BTB_SHIPMENT.BTB_ShipmentKey)
   WHERE INSERTED.FormNo <> ''
   
   OPEN CUR_SHPDET
   
   FETCH NEXT FROM CUR_SHPDET INTO @c_FormType
                                 , @c_FormNo
                                 , @c_HSCode
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @n_QtyExported
                                 , @c_BTBShipItem                 --(Wan01)
                                 , @c_CustomLotNo                 --(Wan01)
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_QtyExported > 0 
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
         AND   BTB_FTA.BTBShipItem = @c_BTBShipItem               --(Wan01)
         AND   BTB_FTA.CustomLotNo = @c_CustomLotNo               --(Wan01) 
         
         IF @c_BTB_FTAKey <> ''
         BEGIN
            UPDATE BTB_FTA 
            SET QtyExported = QtyExported + @n_QtyExported
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE BTB_FTA.BTB_FTAKey   = @c_BTB_FTAKey            --(Wan01)

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(5),@n_err)
               SET @n_err=80020
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_FTA. (ntrBTB_ShipmentDetailAdd)' 
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
                                    , @c_BTBShipItem              --(Wan01)
                                    , @c_CustomLotNo              --(Wan01)                
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ntrBTB_ShipmentDetailAdd'
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