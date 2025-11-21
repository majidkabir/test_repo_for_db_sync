SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrBTB_ShipmentDetailDelete                                 */
/* Creation Date: 20-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-FEB-09 WAN01    1.1   WMS-15957-SG-CBF - BTB Form E Declaration */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrBTB_ShipmentDetailDelete]
ON  [dbo].[BTB_SHIPMENTDETAIL]
FOR DELETE
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

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT_TR
   END

   DECLARE CUR_SHPDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT BTB_SHIPMENT.FormType
         ,ISNULL(RTRIM(DELETED.FormNo),'')
         ,ISNULL(RTRIM(DELETED.HSCode),'')
         ,ISNULL(RTRIM(DELETED.Storerkey),'')
         ,ISNULL(RTRIM(DELETED.Sku),'')
         ,ISNULL(DELETED.QtyExported,0) 
         ,DELETED.BTBShipItem                                     --(Wan01)
         ,DELETED.CustomLotNo                                     --(Wan01)       
   FROM DELETED WITH (NOLOCK)
   JOIN BTB_SHIPMENT WITH (NOLOCK) ON (DELETED.BTB_ShipmentKey = BTB_SHIPMENT.BTB_ShipmentKey)
   WHERE DELETED.FormNo <> ''
   
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
      --(Wan01) - START
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
         SET QtyExported = QtyExported - @n_QtyExported
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
         WHERE BTB_FTA.BTB_FTAKey   = @c_BTB_FTAKey            --(Wan01)

         SET @n_err = @@ERROR 
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_errmsg = CONVERT(CHAR(5),@n_err)
            SET @n_err=80010
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_FTA. (ntrBTB_ShipmentDetailDelete)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT_TR
         END
      END
      --(Wan01) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ntrBTB_ShipmentDetailDelete'
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